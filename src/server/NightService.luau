--!strict
-- NightService: cria/destrói NightSessions por jogador e encaminha os Remotes cliente→servidor (PLANEJAMENTO 5.5).
-- Fase 1: o save vive em memória. A Fase 7 troca por SaveService/DataStore (3.14, 5.10) sem mudar o resto.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Enums = require(Shared.Enums)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local NightSession = require(script.Parent.NightSession)

local SAVE_VERSION = 1

local NightService = {}

local sessions: { [Player]: NightSession.NightSession } = {}
local saves: { [Player]: Types.SaveData } = {}

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
    log(`{player.Name} começou a noite {night}`)
    session:start()
end

local function onPlayerAdded(player: Player)
    saves[player] = defaultSave()
    sendSave(player)
end

local function onPlayerRemoving(player: Player)
    endSession(player)
    saves[player] = nil
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
    Remotes.get(Enums.Remote.ReturnToMenu).OnServerEvent:Connect(function(player: Player)
        endSession(player)
    end)
end

return NightService
