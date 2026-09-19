--!strict
-- SaveService: o save de cada jogador no DataStore (PLANEJAMENTO 3.14, 5.10).
-- Load com uma tentativa por item de Save.retryDelays; se todas falharem, o jogador fica em "modo sem save":
-- joga normalmente, o menu avisa, e nada é gravado. Writes numa fila por jogador que respeita o intervalo
-- mínimo entre writes na mesma chave. Migração: preenche campos ausentes com o default e sobe a versão.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Types = require(Shared.Types)

type Entry = {
    data: Types.SaveData,
    available: boolean, -- false = modo sem save
    loaded: boolean,
    dirty: boolean,
    saving: boolean,
    leaving: boolean,
    lastWrite: number,
}

local SaveService = {}

local entries: { [Player]: Entry } = {}
local store: DataStore? = nil

-- Save inicial (3.14). A Noite 0 é o começo: New Game abre o tutorial e só depois libera a Noite 1.
function SaveService.defaultSave(): Types.SaveData
    return {
        version = GameConfig.Save.version,
        currentNight = 0,
        maxNightUnlocked = 0,
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

-- Copia de `raw` só os campos conhecidos e do tipo certo; o que faltar vem do default (5.10).
-- any justificado: o valor vem do DataStore e pode ter qualquer forma (versão antiga, dado corrompido).
local function merge(defaults: any, raw: any): any
    if typeof(raw) ~= "table" then
        return defaults
    end
    local out = {}
    for key, default in defaults do
        local value = raw[key]
        if typeof(default) == "table" then
            out[key] = merge(default, value)
        elseif typeof(value) == typeof(default) then
            out[key] = value
        else
            out[key] = default
        end
    end
    return out
end

local function migrate(raw: any): Types.SaveData
    -- v0 → v1: o formato é o mesmo; o merge só completa o que faltar. Versões futuras entram aqui, em ordem.
    local data: Types.SaveData = merge(SaveService.defaultSave(), raw)
    data.version = GameConfig.Save.version
    local lastNight = #GameConfig.Nights
    data.currentNight = math.clamp(math.floor(data.currentNight), 0, lastNight)
    data.maxNightUnlocked = math.clamp(math.floor(data.maxNightUnlocked), 0, lastNight + 1)
    data.settings.masterVolume = math.clamp(data.settings.masterVolume, 0, 1)
    return data
end

local function keyOf(player: Player): string
    return tostring(player.UserId)
end

-- Tenta uma operação com as esperas de Save.retryDelays entre as tentativas
local function withRetries(label: string, player: Player, operation: () -> any): (boolean, any)
    local delays = GameConfig.Save.retryDelays
    local lastError: any = nil
    for attempt, delay in delays do
        local ok, result = pcall(operation)
        if ok then
            return true, result
        end
        lastError = result
        warn(`[SaveService] {label} de {player.Name} falhou ({attempt}/{#delays}): {result}`)
        if attempt < #delays then
            task.wait(delay)
        end
    end
    return false, lastError
end

local function write(player: Player, entry: Entry): boolean
    local ds = store
    if not ds then
        return false
    end
    local ok = withRetries("gravação", player, function()
        return ds:SetAsync(keyOf(player), entry.data, { player.UserId })
    end)
    return ok
end

-- Carrega o save (pode demorar: faz chamadas de rede). O jogo nunca trava: sem DataStore, segue sem save.
function SaveService.load(player: Player)
    local entry: Entry = {
        data = SaveService.defaultSave(),
        available = false,
        loaded = false,
        dirty = false,
        saving = false,
        leaving = false,
        lastWrite = -math.huge,
    }
    entries[player] = entry
    local ds = store
    if ds then
        local ok, raw = withRetries("leitura", player, function()
            return ds:GetAsync(keyOf(player))
        end)
        if ok then
            entry.data = migrate(raw) -- raw nil = jogador novo: vira o default
            entry.available = true
        end
    end
    if not entry.available then
        warn(`[SaveService] {player.Name} está em modo sem save; o progresso não será gravado`)
    end
    entry.loaded = true
    if entry.leaving then
        entries[player] = nil -- saiu antes do load terminar: não há o que gravar
    end
end

function SaveService.get(player: Player): Types.SaveData?
    local entry = entries[player]
    return if entry and entry.loaded then entry.data else nil
end

function SaveService.isAvailable(player: Player): boolean
    local entry = entries[player]
    return entry ~= nil and entry.available
end

-- Pede uma gravação. Se já há uma em andamento, a próxima sai depois dela, respeitando o intervalo mínimo.
function SaveService.requestSave(player: Player)
    local entry = entries[player]
    if not entry or not entry.loaded then
        return
    end
    if not entry.available then
        if entry.leaving then
            entries[player] = nil
        end
        return
    end
    entry.dirty = true
    if entry.saving then
        return
    end
    entry.saving = true
    task.spawn(function()
        while entry.dirty do
            local wait = entry.lastWrite + GameConfig.Save.minSecondsBetweenWrites - os.clock()
            if wait > 0 then
                task.wait(wait)
            end
            entry.dirty = false
            entry.lastWrite = os.clock()
            write(player, entry)
        end
        entry.saving = false
        if entry.leaving then
            entries[player] = nil
        end
    end)
end

-- O jogador saiu: grava uma última vez e esquece
function SaveService.release(player: Player)
    local entry = entries[player]
    if not entry then
        return
    end
    entry.leaving = true
    if entry.loaded then
        SaveService.requestSave(player)
    end
end

function SaveService.init()
    local ok, result = pcall(function()
        return DataStoreService:GetDataStore(GameConfig.Save.storeName)
    end)
    if ok then
        store = result
    else
        warn(`[SaveService] DataStore indisponível: {result}`)
    end

    -- Servidor fechando (5.10): grava todo mundo e espera as gravações acabarem, dentro do prazo do Roblox
    game:BindToClose(function()
        for player, entry in entries do
            if entry.loaded and entry.available then
                SaveService.requestSave(player)
            end
        end
        local deadline = os.clock() + GameConfig.Save.closeTimeoutSeconds
        while os.clock() < deadline do
            local pending = false
            for _, entry in entries do
                if entry.saving then
                    pending = true
                end
            end
            if not pending then
                return
            end
            task.wait(0.1)
        end
    end)
end

return SaveService
