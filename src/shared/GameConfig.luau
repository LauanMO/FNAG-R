--!strict
-- GameConfig: a única fonte de números do jogo (PLANEJAMENTO 2.5; valores da seção 7).
-- Ao mudar um valor aqui, mude a seção 7 do PLANEJAMENTO_ROBLOX.md — ou vice-versa, mas sempre os dois.
-- Nenhum outro módulo hardcoda número de jogo (Apêndice C.7).

local GameConfig = {
    Night = {
        durationSeconds = 360,
        hours = 6, -- 12 AM → 6 AM
        bootSeconds = 3,
        graceBeforeDawn = 2,
        clockTickSeconds = 1, -- resolução do relógio; 1 hora de jogo = durationSeconds / hours
    },
    Power = {
        max = 100,
        tickSeconds = 1,
        drainBase = 0.12,
        drainPerDoor = 0.20,
        drainTablet = 0.08,
        drainLeak = 0.15,
        puzzlePenalty = 5,
        generatorResetTo = 50,
        generatorUsesPerNight = 1,
        lowPowerWarn = 20,
        lowPowerCritical = 10,
    },
    Blackout = {
        lightsFadeSeconds = 3,
        tabletBatterySeconds = 15,
        aiTickMultiplier = 0.5,
    },
    Doors = {
        closeSeconds = 0.6,
        openSeconds = 0.8,
    },
    Radar = {
        pingProcessSeconds = 1.0,
        pingShowSeconds = 6,
        pingCooldownSeconds = 3,
        cameraBreakOrder = { "CAM1", "CAM4", "CAM2", "CAM3" },
    },
    Circle = {
        tickSeconds = 15,
        alertFuseSeconds = 30,
        minigameSeconds = 15,
        minigameWordCount = 9,
    },
    Hexagon = {
        tickSeconds = 25,
        maxLayers = 5,
        intrusionSeconds = 20,
        restoreCooldownSeconds = 10,
        systems = { "camera_offline", "door_left_jammed", "door_right_jammed", "clock_glitch", "power_leak" },
    },
    Patrol = {
        square = { tickSeconds = 5, side = "left" :: "left", path = { "CAM1", "CAM2", "DOOR_L" } },
        triangle = { tickSeconds = 8, side = "right" :: "right", path = { "CAM1", "CAM3", "DOOR_R" } },
    },
    Terminal = {
        maxCommandsPerSecond = 5,
    },
    -- Níveis por noite (7.4). Índice = noite (0 = tutorial, 1-7). "custom" é montada em runtime na Fase 7.
    Nights = {
        [0] = { square = 0, triangle = 0, circle = 0, hexagon = 0, arrivalCueVolume = 1.0, sonar = false },
        [1] = { square = 3, triangle = 2, circle = 0, hexagon = 0, arrivalCueVolume = 1.0, sonar = false },
        [2] = { square = 5, triangle = 3, circle = 2, hexagon = 0, arrivalCueVolume = 1.0, sonar = false },
        [3] = { square = 6, triangle = 5, circle = 3, hexagon = 2, arrivalCueVolume = 0.9, sonar = false },
        [4] = { square = 8, triangle = 7, circle = 4, hexagon = 4, arrivalCueVolume = 0.8, sonar = false },
        [5] = { square = 10, triangle = 9, circle = 6, hexagon = 5, arrivalCueVolume = 0.7, sonar = false },
        [6] = { square = 13, triangle = 11, circle = 8, hexagon = 6, arrivalCueVolume = 0.6, sonar = true },
        [7] = { square = 16, triangle = 14, circle = 10, hexagon = 8, arrivalCueVolume = 0.5, sonar = true },
    },
    Audio = {
        -- SoundId lógico (Enums.Cue) → asset id. Preencher na Fase 6.
        ids = {} :: { [string]: string },
        arrivalDuckAmount = 0.6,
        arrivalDuckSeconds = 1.5,
    },
    Debug = {
        timeScale = 1, -- 5 = noite de 72s para testar. Só tem efeito em Studio (5.9).
        deterministicSeed = nil :: number?, -- número = RNG reproduzível. Só em Studio.
        logAI = false, -- imprime cada sorteio das IAs (Fase 3)
        logSession = true, -- imprime boot, fases e fim de noite no Output
    },
}

-- Congela recursivamente: ninguém altera config em runtime; balancear é editar este arquivo.
local function deepFreeze<T>(value: T): T
    -- cast justificado: percorre qualquer tabela genericamente para congelar as sub-tabelas
    local t = value :: any
    for _, child in t do
        if typeof(child) == "table" and not table.isfrozen(child) then
            deepFreeze(child)
        end
    end
    return table.freeze(t) :: T
end

return deepFreeze(GameConfig)
