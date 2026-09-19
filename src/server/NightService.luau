--!strict
-- NightService: cria/destrói NightSessions por jogador, aplica a progressão e encaminha os Remotes
-- cliente→servidor (PLANEJAMENTO 5.5). O save vive no SaveService (3.14, 5.10).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
local MinigameService = require(script.Parent.MinigameService)
local TutorialService = require(script.Parent.TutorialService)
local SaveService = require(script.Parent.SaveService)

local LAST_NIGHT = #GameConfig.Nights -- 7: o índice 0 (tutorial) fica fora do comprimento
local CUSTOM_ENEMIES = { "square", "triangle", "circle", "hexagon" }

local NightService = {}

local sessions: { [Player]: NightSession.NightSession } = {}
local toggleDoorLimiter = RateLimiter.new(GameConfig.Doors.maxTogglesPerSecond)
local tabletLimiter = RateLimiter.new(GameConfig.Tablet.maxTogglesPerSecond)
local terminalLimiter = RateLimiter.new(GameConfig.Terminal.maxTogglesPerSecond)
local settingsLimiter = RateLimiter.new(GameConfig.Settings.maxUpdatesPerSecond)

local function log(...: any)
    if GameConfig.Debug.logSession then
        print("[NightService]", ...)
    end
end

local function sendSave(player: Player)
    local save = SaveService.get(player)
    if save then
        Remotes.get(Enums.Remote.SaveLoaded)
            :FireClient(player, { save = save, available = SaveService.isAvailable(player) } :: Types.SaveLoadedPayload)
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

-- Até onde o jogador pode ir: o save manda; em Studio, Debug.unlockAllNights libera tudo
local function unlockedUpTo(save: Types.SaveData): number
    if RunService:IsStudio() and GameConfig.Debug.unlockAllNights then
        return LAST_NIGHT + 1
    end
    return save.maxNightUnlocked
end

-- Progressão (3.1, 3.10, 3.13, 3.14). Vencer libera a próxima; morrer só conta nas estatísticas.
local function onSessionEnded(
    player: Player,
    session: NightSession.NightSession,
    result: Types.Phase,
    enemy: Types.Enemy?
)
    local save = SaveService.get(player)
    local night = session.state.night
    if save then
        if result == Enums.Phase.Won then
            if night == Enums.Night.Tutorial then
                -- Rever o tutorial pelo menu não mexe na noite de quem já está mais adiante
                save.tutorialDone = true
                save.currentNight = math.max(save.currentNight, 1)
                save.maxNightUnlocked = math.max(save.maxNightUnlocked, 1)
            else
                save.stats.nightsWon += 1
                if night ~= Enums.Night.Custom then
                    save.currentNight = math.min(night + 1, LAST_NIGHT) -- depois da 7, Continue reabre a 7
                    save.maxNightUnlocked = math.max(save.maxNightUnlocked, night + 1) -- 8 = venceu a 7
                end
            end
        else
            save.stats.deaths += 1
            if enemy then
                save.stats.deathsBy[enemy] = (save.stats.deathsBy[enemy] or 0) + 1
            end
        end
        save.stats.bestTimeAlive = math.max(save.stats.bestTimeAlive, math.floor(session:secondsSurvived()))
        sendSave(player)
        SaveService.requestSave(player)
    end
    endSession(player)
end

-- Custom Night (3.13, 5.6): os quatro níveis, inteiros de 0 a CustomNight.maxLevel
local function readCustomLevels(raw: unknown): Types.CustomLevels?
    if typeof(raw) ~= "table" then
        return nil
    end
    -- cast justificado: o payload vem do cliente e é validado campo a campo
    local fields = raw :: any
    local levels: { [string]: number } = {}
    for _, name in CUSTOM_ENEMIES do
        local value = fields[name]
        if typeof(value) ~= "number" or value ~= math.floor(value) then
            return nil
        end
        if value < 0 or value > GameConfig.CustomNight.maxLevel then
            return nil
        end
        levels[name] = value
    end
    return { square = levels.square, triangle = levels.triangle, circle = levels.circle, hexagon = levels.hexagon }
end

-- StartNight { night, newGame?, custom? } (5.6, 5.9): tudo conferido contra o save do servidor
local function onStartNight(player: Player, payload: unknown)
    if typeof(payload) ~= "table" or sessions[player] then
        return
    end
    local save = SaveService.get(player)
    if not save then
        return -- o save ainda está carregando
    end
    -- cast justificado: o payload vem do cliente e é validado campo a campo
    local fields = payload :: any
    local night: number
    local custom: Types.CustomLevels? = nil
    if fields.custom ~= nil then
        custom = readCustomLevels(fields.custom)
        if not custom or unlockedUpTo(save) <= LAST_NIGHT then
            return -- Custom Night só depois de vencer a última noite
        end
        night = Enums.Night.Custom
    else
        local requested = fields.night
        if typeof(requested) ~= "number" or requested ~= math.floor(requested) then
            return
        end
        if GameConfig.Nights[requested] == nil or requested > unlockedUpTo(save) then
            return
        end
        night = requested
        if fields.newGame == true then
            if night ~= Enums.Night.Tutorial then
                return
            end
            save.currentNight = Enums.Night.Tutorial -- New Game recomeça pelo tutorial (3.1)
        end
    end

    local session = NightSession.new({ player }, night, custom)
    sessions[player] = session
    session.ended:Connect(function(result, enemy)
        onSessionEnded(player, session, result, enemy)
    end)
    FirewallService.attach(session) -- Hexágono, firewall e puzzle (Fase 5a)
    MinigameService.attach(session) -- Círculo e minigame (Fase 5b)
    if night == Enums.Night.Tutorial then
        TutorialService.attach(session) -- Noite 0 roteirizada (Fase 7)
    end
    log(`{player.Name} começou a noite {night}`)
    session:start()
end

-- ToggleDoor { side }: só com sessão viva, lado válido e dentro do rate limit (5.9)
local function onToggleDoor(player: Player, payload: unknown)
    local session = sessions[player]
    if not session or typeof(payload) ~= "table" then
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

-- Lê um booleano `open` do payload do cliente (SetTabletOpen, SetTerminalOpen)
local function readOpen(payload: unknown): boolean?
    if typeof(payload) ~= "table" then
        return nil
    end
    -- cast justificado: o payload vem do cliente e é validado campo a campo
    local open = (payload :: any).open
    return if typeof(open) == "boolean" then open else nil
end

-- SetTabletOpen { open }: sessão viva, booleano e dentro do rate limit; a sessão decide se abre (5.6)
local function onSetTabletOpen(player: Player, payload: unknown)
    local session = sessions[player]
    local open = readOpen(payload)
    if not session or open == nil or not tabletLimiter:allow(player) then
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

-- SetTerminalOpen { open } (5.6): a sessão decide se o terminal está disponível
local function onSetTerminalOpen(player: Player, payload: unknown)
    local session = sessions[player]
    local open = readOpen(payload)
    if not session or open == nil or not terminalLimiter:allow(player) then
        return
    end
    session:setTerminal(open)
    if open then
        MinigameService.onTerminalOpened(session) -- alerta ativo vira minigame (3.8.3)
    end
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

-- MinigamePick { index }: inteiro; o MinigameService confere a faixa contra as palavras da rodada (5.6)
local function onMinigamePick(player: Player, payload: unknown)
    local session = sessions[player]
    if not session or typeof(payload) ~= "table" then
        return
    end
    -- cast justificado: o payload vem do cliente e é validado campo a campo
    local index = (payload :: any).index
    if typeof(index) ~= "number" or index ~= math.floor(index) then
        return
    end
    MinigameService.pick(session, index)
end

-- TutorialAdvance { step } (5.6): só na Noite 0; o TutorialService confere o passo
local function onTutorialAdvance(player: Player, payload: unknown)
    local session = sessions[player]
    if session and session.state.night == Enums.Night.Tutorial then
        TutorialService.advance(session, payload)
    end
end

-- UpdateSettings { masterVolume } (Fase 6): número entre 0 e 1; vai para o save na próxima gravação
local function onUpdateSettings(player: Player, payload: unknown)
    local save = SaveService.get(player)
    if not save or typeof(payload) ~= "table" or not settingsLimiter:allow(player) then
        return
    end
    -- cast justificado: o payload vem do cliente e é validado campo a campo
    local volume = (payload :: any).masterVolume
    if typeof(volume) ~= "number" or volume ~= volume then -- volume ~= volume: rejeita NaN
        return
    end
    save.settings.masterVolume = math.clamp(volume, 0, 1)
end

local function onPlayerAdded(player: Player)
    -- O load faz chamadas de rede; o menu fica esperando o SaveLoaded
    task.spawn(function()
        SaveService.load(player)
        if player.Parent then
            sendSave(player)
        end
    end)
end

local function onPlayerRemoving(player: Player)
    endSession(player)
    SaveService.release(player)
    toggleDoorLimiter:forget(player)
    tabletLimiter:forget(player)
    terminalLimiter:forget(player)
    settingsLimiter:forget(player)
    TerminalService.forget(player)
end

function NightService.init()
    SaveService.init()
    Players.PlayerAdded:Connect(onPlayerAdded)
    for _, player in Players:GetPlayers() do
        onPlayerAdded(player) -- quem entrou antes do Connect (comum em Studio)
    end
    Players.PlayerRemoving:Connect(onPlayerRemoving)

    -- O SaveLoaded pode chegar antes dos scripts do cliente existirem; o cliente pede de novo.
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
    Remotes.get(Enums.Remote.MinigamePick).OnServerEvent:Connect(onMinigamePick)
    Remotes.get(Enums.Remote.TutorialAdvance).OnServerEvent:Connect(onTutorialAdvance)
    Remotes.get(Enums.Remote.UpdateSettings).OnServerEvent:Connect(onUpdateSettings)
    Remotes.get(Enums.Remote.ReturnToMenu).OnServerEvent:Connect(function(player: Player)
        endSession(player)
    end)
end

return NightService
