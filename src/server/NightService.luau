--!strict
-- NightService: cria/destrói NightSessions por jogador e encaminha os Remotes cliente→servidor (PLANEJAMENTO 5.5).
-- Fase 1: o save vive em memória. A Fase 7 troca por SaveService/DataStore (3.14, 5.10) sem mudar o resto.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Enums = require(Shared.Enums)
local Remotes = require(Shared.Remotes)
local LogicGates = require(Shared.LogicGates)
local Types = require(Shared.Types)
local NightSession = require(script.Parent.NightSession)
local RateLimiter = require(script.Parent.RateLimiter)
local RadarService = require(script.Parent.RadarService)
local FirewallService = require(script.Parent.FirewallService)
local TerminalService = require(script.Parent.TerminalService)

local SAVE_VERSION = 1

local NightService = {}

local sessions: { [Player]: NightSession.NightSession } = {}
local saves: { [Player]: Types.SaveData } = {}
local toggleDoorLimiter = RateLimiter.new(GameConfig.Doors.maxTogglesPerSecond)
local tabletLimiter = RateLimiter.new(GameConfig.Tablet.maxTogglesPerSecond)
local terminalLimiter = RateLimiter.new(GameConfig.Terminal.maxTogglesPerSecond)

local function log(...: any)
    if GameConfig.Debug.logSession then
        print("[NightService]", ...)
    end
end

-- Save inicial (3.14)
local function defaultSave(): Types.SaveData
    return {
        version = SAVE_VERSION,
        currentNight = 1,
        maxNightUnlocked = 1,
        tutorialDone = false,
        stats = {
            nightsWon = 0,
            deaths = 0,
            deathsBy = { square = 0, triangle = 0, hexagon = 0 },
            bestTimeAlive = 0,
        },
        settings = {
            masterVolume = 1,
            showCommandPalette = true,
        },
    }
end

local function sendSave(player: Player)
    local save = saves[player]
    if save then
        Remotes.get(Enums.Remote.SaveLoaded):FireClient(player, { save = save } :: Types.SaveLoadedPayload)
    end
end

local function endSession(player: Player)
    local session = sessions[player]
    if not session then
        return
    end
    sessions[player] = nil
    session:destroy()
end

local function onSessionEnded(player: Player, night: number, result: Types.Phase, enemy: Types.Enemy?)
    local save = saves[player]
    if save then
        if result == Enums.Phase.Won then
            -- Vencer salva N+1 (3.1); 8 = venceu a 7 (3.14)
            save.stats.nightsWon += 1
            save.currentNight = night + 1
            save.maxNightUnlocked = math.max(save.maxNightUnlocked, night + 1)
        else
            -- Morrer salva só estatísticas (3.10)
            save.stats.deaths += 1
            if enemy then
                save.stats.deathsBy[enemy] = (save.stats.deathsBy[enemy] or 0) + 1
            end
        end
        sendSave(player)
    end
    endSession(player)
end

-- StartNight { night }: valida tipo, faixa e progresso no save do servidor (5.6, 5.9)
local function onStartNight(player: Player, payload: unknown)
    if typeof(payload) ~= "table" then
        return
    end
    -- cast justificado: o payload vem do cliente e é validado campo a campo
    local night = (payload :: any).night
    if typeof(night) ~= "number" or night ~= math.floor(night) then
        return
    end
    local save = saves[player]
    if not save then
        return
    end
    if GameConfig.Nights[night] == nil then
        return
    end
    if night > save.maxNightUnlocked then
        return
    end
    if sessions[player] then
        return -- já está numa noite
    end

    save.currentNight = night
    local session = NightSession.new({ player }, night)
    sessions[player] = session
    session.ended:Connect(function(result, enemy)
        onSessionEnded(player, night, result, enemy)
    end)
    FirewallService.attach(session) -- Hexágono, firewall e puzzle (Fase 5a)
    log(`{player.Name} começou a noite {night}`)
    session:start()
end

-- ToggleDoor { side }: só com sessão viva, lado válido e dentro do rate limit (5.9)
local function onToggleDoor(player: Player, payload: unknown)
    local session = sessions[player]
    if not session then
        return
    end
    if typeof(payload) ~= "table" then
        return
    end
    -- cast justificado: o payload vem do cliente e é validado campo a campo
    local side = (payload :: any).side
    if side ~= Enums.Side.Left and side ~= Enums.Side.Right then
        return
    end
    if not toggleDoorLimiter:allow(player) then
        return
    end
    session:toggleDoor(side)
end

-- SetTabletOpen { open }: sessão viva, booleano e dentro do rate limit; a sessão decide se abre (5.6)
local function onSetTabletOpen(player: Player, payload: unknown)
    local session = sessions[player]
    if not session or typeof(payload) ~= "table" then
        return
    end
    -- cast justificado: o payload vem do cliente e é validado campo a campo
    local open = (payload :: any).open
    if typeof(open) ~= "boolean" then
        return
    end
    if not tabletLimiter:allow(player) then
        return
    end
    session:setTablet(open)
end

-- RequestPing {}: o RadarService confere tablet aberto e ping livre; o cooldown já limita a taxa (5.9)
local function onRequestPing(player: Player)
    local session = sessions[player]
    if session then
        RadarService.requestPing(session)
    end
end

-- Lê um booleano `open` do payload do cliente (SetTabletOpen, SetTerminalOpen)
local function readOpen(payload: unknown): boolean?
    if typeof(payload) ~= "table" then
        return nil
    end
    -- cast justificado: o payload vem do cliente e é validado campo a campo
    local open = (payload :: any).open
    return if typeof(open) == "boolean" then open else nil
end

-- SetTerminalOpen { open } (5.6): a sessão decide se o terminal está disponível
local function onSetTerminalOpen(player: Player, payload: unknown)
    local session = sessions[player]
    local open = readOpen(payload)
    if not session or open == nil or not terminalLimiter:allow(player) then
        return
    end
    session:setTerminal(open)
end

-- TerminalCommand { text }: toda a validação fica no TerminalService (5.6, 5.9)
local function onTerminalCommand(player: Player, payload: unknown)
    local session = sessions[player]
    if session then
        TerminalService.handle(session, player, payload)
    end
end

-- PuzzlePick { gate }: nome de porta lógica conhecido; o FirewallService confere se está entre as opções
local function onPuzzlePick(player: Player, payload: unknown)
    local session = sessions[player]
    if not session or typeof(payload) ~= "table" then
        return
    end
    -- cast justificado: o payload vem do cliente e é validado campo a campo
    local gate = (payload :: any).gate
    if typeof(gate) ~= "string" or not LogicGates.isGate(gate) then
        return
    end
    FirewallService.puzzlePick(session, gate)
end

local function onPuzzleCancel(player: Player)
    local session = sessions[player]
    if session then
        FirewallService.cancelPuzzle(session)
    end
end

local function onPlayerAdded(player: Player)
    saves[player] = defaultSave()
    sendSave(player)
end

local function onPlayerRemoving(player: Player)
    endSession(player)
    saves[player] = nil
    toggleDoorLimiter:forget(player)
    tabletLimiter:forget(player)
    terminalLimiter:forget(player)
    TerminalService.forget(player)
end

function NightService.init()
    Players.PlayerAdded:Connect(onPlayerAdded)
    for _, player in Players:GetPlayers() do
        onPlayerAdded(player) -- quem entrou antes do Connect (comum em Studio)
    end
    Players.PlayerRemoving:Connect(onPlayerRemoving)

    -- O SaveLoaded do PlayerAdded pode chegar antes dos scripts do cliente existirem; o cliente pede de novo.
    Remotes.get(Enums.Remote.ClientReady).OnServerEvent:Connect(function(player: Player)
        sendSave(player)
    end)
    Remotes.get(Enums.Remote.StartNight).OnServerEvent:Connect(onStartNight)
    Remotes.get(Enums.Remote.ToggleDoor).OnServerEvent:Connect(onToggleDoor)
    Remotes.get(Enums.Remote.SetTabletOpen).OnServerEvent:Connect(onSetTabletOpen)
    Remotes.get(Enums.Remote.RequestPing).OnServerEvent:Connect(onRequestPing)
    Remotes.get(Enums.Remote.SetTerminalOpen).OnServerEvent:Connect(onSetTerminalOpen)
    Remotes.get(Enums.Remote.TerminalCommand).OnServerEvent:Connect(onTerminalCommand)
    Remotes.get(Enums.Remote.PuzzlePick).OnServerEvent:Connect(onPuzzlePick)
    Remotes.get(Enums.Remote.PuzzleCancel).OnServerEvent:Connect(onPuzzleCancel)
    Remotes.get(Enums.Remote.ReturnToMenu).OnServerEvent:Connect(function(player: Player)
        endSession(player)
    end)
end

return NightService
