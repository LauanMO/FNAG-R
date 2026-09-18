--!strict
-- NightSession: todo o estado de uma noite e seu ciclo de vida (PLANEJAMENTO 5.4).
-- Fase 1: boot, relógio, energia, blackout (só estado + eventos), vitória e derrota.
-- Portas físicas entram na Fase 2; IAs nas Fases 3 e 5. Tudo que muda estado dispara o Remote correspondente (5.6).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Enums = require(Shared.Enums)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)
local Scheduler = require(script.Parent.Scheduler)

local NightSession = {}
NightSession.__index = NightSession

type Fields = {
    state: Types.NightState,
    levels: Types.NightLevels,
    scheduler: Scheduler.Scheduler,
    rng: Random,
    hourSeconds: number,
    -- ("won" | "lost", inimigo?) — NightService escuta para atualizar o save e destruir a sessão
    ended: Signal.Signal<Types.Phase, Types.Enemy?>,
    destroyed: boolean,
}

export type NightSession = typeof(setmetatable({} :: Fields, NightSession))

-- Debug.timeScale e deterministicSeed só têm efeito em Studio (5.9)
local function debugTimeScale(): number
    return if RunService:IsStudio() then GameConfig.Debug.timeScale else 1
end

local function makeRng(): Random
    local seed = GameConfig.Debug.deterministicSeed
    if RunService:IsStudio() and seed ~= nil then
        return Random.new(seed)
    end
    return Random.new()
end

local function log(...: any)
    if GameConfig.Debug.logSession then
        print("[NightSession]", ...)
    end
end

local function isOver(phase: Types.Phase): boolean
    return phase == Enums.Phase.Won or phase == Enums.Phase.Lost
end

function NightSession.new(players: { Player }, night: number): NightSession
    local levels = GameConfig.Nights[night]
    assert(levels ~= nil, `NightSession: noite inválida ({night})`)

    local state: Types.NightState = {
        night = night,
        players = players,
        phase = Enums.Phase.Boot,
        hour = 0,
        secondsIntoHour = 0,
        power = GameConfig.Power.max,
        doors = {
            left = { closed = false, jammed = false },
            right = { closed = false, jammed = false },
        },
        tabletOpen = false,
        terminalOpen = false,
        firewallLayers = GameConfig.Hexagon.maxLayers,
        corrupted = {},
        deadCameras = {},
        intrusionRemaining = nil,
        generatorUsesLeft = GameConfig.Power.generatorUsesPerNight,
        tabletBatteryRemaining = nil,
        virusAlert = nil,
        minigame = nil,
        puzzle = nil,
        restoreCooldown = 0,
        ai = {},
    }

    local self: NightSession = setmetatable(
        {
            state = state,
            levels = levels,
            scheduler = Scheduler.new(debugTimeScale()),
            rng = makeRng(),
            hourSeconds = GameConfig.Night.durationSeconds / GameConfig.Night.hours,
            ended = Signal.new(),
            destroyed = false,
        } :: Fields,
        NightSession
    )
    return self
end

-- payload: any — cada Remote tem seu tipo em Types (5.6); FireClient aceita qualquer tabela
function NightSession.fire(self: NightSession, remoteName: string, payload: any)
    local remote = Remotes.get(remoteName)
    for _, player in self.state.players do
        remote:FireClient(player, payload)
    end
end

function NightSession.setPhase(self: NightSession, phase: Types.Phase)
    self.state.phase = phase
    self:fire(Enums.Remote.NightPhase, { phase = phase } :: Types.NightPhasePayload)
end

-- Dreno total por segundo e a lista de fontes ativas (3.2). A lista vira as barrinhas de consumo do HUD.
function NightSession.computeDrain(self: NightSession): (number, { Types.PowerSource })
    local P = GameConfig.Power
    local s = self.state
    local rate = P.drainBase
    local sources: { Types.PowerSource } = { Enums.PowerSource.Base }
    if s.doors.left.closed then
        rate += P.drainPerDoor
        table.insert(sources, Enums.PowerSource.DoorLeft)
    end
    if s.doors.right.closed then
        rate += P.drainPerDoor
        table.insert(sources, Enums.PowerSource.DoorRight)
    end
    if s.tabletOpen then
        rate += P.drainTablet
        table.insert(sources, Enums.PowerSource.Tablet)
    end
    if s.corrupted[Enums.System.PowerLeak] then
        rate += P.drainLeak
        table.insert(sources, Enums.PowerSource.Leak)
    end
    return rate, sources
end

function NightSession.firePower(self: NightSession)
    local rate, sources = self:computeDrain()
    self:fire(
        Enums.Remote.PowerChanged,
        {
            power = self.state.power,
            drainRate = rate,
            sources = sources,
        } :: Types.PowerChangedPayload
    )
end

function NightSession.start(self: NightSession)
    local s = self.state
    log(`noite {s.night} — boot ({GameConfig.Night.bootSeconds}s, timeScale {self.scheduler.timeScale})`)
    self:fire(Enums.Remote.NightStarted, { night = s.night, config = self.levels } :: Types.NightStartedPayload)
    self:setPhase(Enums.Phase.Boot)
    self:fire(Enums.Remote.HourChanged, { hour = s.hour } :: Types.HourChangedPayload)
    self:firePower()
    -- Relógio, energia e IAs só começam depois do boot (3.1)
    self.scheduler:after("boot", GameConfig.Night.bootSeconds, function()
        self:beginRunning()
    end)
end

function NightSession.beginRunning(self: NightSession)
    if self.destroyed then
        return
    end
    log("running")
    self:setPhase(Enums.Phase.Running)
    self.scheduler:every("clock", GameConfig.Night.clockTickSeconds, function()
        self:tickClock()
    end)
    self.scheduler:every("power", GameConfig.Power.tickSeconds, function()
        self:tickPower()
    end)
end

-- O relógio continua rodando no blackout: dá para ganhar na sorte (3.1)
function NightSession.tickClock(self: NightSession)
    local s = self.state
    s.secondsIntoHour += GameConfig.Night.clockTickSeconds
    if s.secondsIntoHour < self.hourSeconds then
        return
    end
    s.secondsIntoHour -= self.hourSeconds
    s.hour += 1
    self:fire(Enums.Remote.HourChanged, { hour = s.hour } :: Types.HourChangedPayload)
    log(`hora {s.hour} — energia {math.floor(s.power)}%`)
    if s.hour >= GameConfig.Night.hours then
        self:win()
    end
end

function NightSession.tickPower(self: NightSession)
    local s = self.state
    if s.phase ~= Enums.Phase.Running then
        return -- em blackout não há o que drenar; nas fases finais não há tick
    end
    local rate = self:computeDrain()
    s.power = math.max(0, s.power - rate * GameConfig.Power.tickSeconds)
    self:firePower()
    if s.power <= 0 then
        self:enterBlackout()
    end
end

-- 3.9. Fase 1: só estado e eventos. Luzes e portas físicas vêm na Fase 2; ticks das IAs pela metade na Fase 3.
function NightSession.enterBlackout(self: NightSession)
    local s = self.state
    if s.phase ~= Enums.Phase.Running then
        return
    end
    log("blackout")
    self:setPhase(Enums.Phase.Blackout)
    -- As portas perdem a trava magnética e abrem sozinhas
    s.doors.left.closed = false
    s.doors.right.closed = false
    self:fire(
        Enums.Remote.DoorStateChanged,
        {
            side = Enums.Side.Left,
            closed = false,
            jammed = s.doors.left.jammed,
            accepted = true,
        } :: Types.DoorStateChangedPayload
    )
    self:fire(
        Enums.Remote.DoorStateChanged,
        {
            side = Enums.Side.Right,
            closed = false,
            jammed = s.doors.right.jammed,
            accepted = true,
        } :: Types.DoorStateChangedPayload
    )
    s.tabletBatteryRemaining = GameConfig.Blackout.tabletBatterySeconds
    self:fire(
        Enums.Remote.BlackoutStarted,
        {
            tabletBatterySeconds = GameConfig.Blackout.tabletBatterySeconds,
        } :: Types.BlackoutStartedPayload
    )
end

-- 3.3 / 5.8: alterna a porta. Nega fora de "running" (boot, blackout) ou com a porta travada pelo Hexágono.
-- A resposta sempre carrega o estado completo da porta; accepted=false manda o cliente reverter a predição.
function NightSession.toggleDoor(self: NightSession, side: Types.Side)
    local s = self.state
    local door = if side == Enums.Side.Left then s.doors.left else s.doors.right
    local accepted = s.phase == Enums.Phase.Running and not door.jammed
    if accepted then
        door.closed = not door.closed
    end
    self:fire(
        Enums.Remote.DoorStateChanged,
        {
            side = side,
            closed = door.closed,
            jammed = door.jammed,
            accepted = accepted,
        } :: Types.DoorStateChangedPayload
    )
    if accepted then
        self:firePower() -- o dreno mudou; as barrinhas do HUD refletem na hora (3.2)
    end
end

function NightSession.win(self: NightSession)
    local s = self.state
    if isOver(s.phase) then
        return
    end
    log(`vitória — noite {s.night}, energia final {math.floor(s.power)}%`)
    self.scheduler:destroy() -- nada sobrevive à sessão (5.3)
    self:setPhase(Enums.Phase.Won)
    self:fire(Enums.Remote.NightWon, { night = s.night, nextNight = s.night + 1 } :: Types.NightWonPayload)
    self.ended:Fire(Enums.Phase.Won, nil)
end

function NightSession.lose(self: NightSession, enemy: Types.Enemy)
    local s = self.state
    if isOver(s.phase) then
        return
    end
    log(`derrota — noite {s.night}, anomalia {enemy}, hora {s.hour}`)
    self.scheduler:destroy()
    self:setPhase(Enums.Phase.Lost)
    self:fire(Enums.Remote.Jumpscare, { enemy = enemy } :: Types.JumpscarePayload)
    self.ended:Fire(Enums.Phase.Lost, enemy)
end

function NightSession.destroy(self: NightSession)
    if self.destroyed then
        return
    end
    self.destroyed = true
    self.scheduler:destroy()
    self.ended:Destroy()
end

return NightSession
