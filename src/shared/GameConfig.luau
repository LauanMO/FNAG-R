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
        batteryTickSeconds = 1, -- resolução do contador da bateria
        aiTickMultiplier = 0.5,
    },
    Doors = {
        closeSeconds = 0.6,
        openSeconds = 0.8,
        maxTogglesPerSecond = 10, -- rate limit de ToggleDoor por jogador (5.9)
    },
    Camera = {
        maxYawDegrees = 60, -- arco de −60° a +60° (3.4)
        smoothing = 10, -- quanto maior, mais rápido a câmera alcança o alvo
        mouseDeadzone = 0.15, -- fração central da tela em que o mouse não gira a câmera
    },
    Tablet = {
        maxTogglesPerSecond = 10, -- rate limit de SetTabletOpen por jogador (5.9)
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
        fuseTickSeconds = 1, -- resolução da contagem do fusível
        minigameTickSeconds = 1, -- resolução do timer do minigame
    },
    Hexagon = {
        tickSeconds = 25,
        maxLayers = 5,
        intrusionSeconds = 20,
        intrusionTickSeconds = 1, -- resolução da contagem da intrusão
        restoreCooldownSeconds = 10,
        systems = { "camera_offline", "door_left_jammed", "door_right_jammed", "clock_glitch", "power_leak" },
    },
    Patrol = {
        square = { tickSeconds = 5, side = "left" :: "left", path = { "CAM1", "CAM2", "DOOR_L" } },
        triangle = { tickSeconds = 8, side = "right" :: "right", path = { "CAM1", "CAM3", "DOOR_R" } },
    },
    Terminal = {
        maxCommandsPerSecond = 5,
        maxInputLength = 64, -- TerminalCommand acima disso é ignorado (5.6)
        maxTogglesPerSecond = 10, -- rate limit de SetTerminalOpen (5.9)
    },
    Puzzle = {
        closeAfterCorrectSeconds = 1.2, -- painel fecha depois do acerto (3.8.4)
        newTableAfterWrongSeconds = 1.4, -- nova tabela depois do erro (3.8.4)
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
        -- SoundId lógico (Enums.Cue) → asset id. A Fase 6 revisa todos; estes são placeholders da
        -- biblioteca licenciada do Roblox (ProSoundEffects), escolhidos pelo nome, sem audição.
        ids = {
            door_close = "rbxassetid://9114153584", -- Door Slide Open Close 1
            door_open = "rbxassetid://9114153848", -- Door Slide Open Close 3
            door_jammed = "rbxassetid://9113085764", -- Alarm Buzzer 5
            blackout = "rbxassetid://9117871125", -- Power Down 1
            enemy_arrival_left = "rbxassetid://9118240078", -- Robot Footsteps Large Metal Clunks Heavy 1
            enemy_arrival_right = "rbxassetid://9118240078", -- idem (o lado vem da âncora posicional)
            door_impact = "rbxassetid://9118270361", -- Robot Impact Metal Body Bangs Slams 1
            jumpscare_square = "rbxassetid://9126160991", -- Video Static Distortion Short And Long Burst
            jumpscare_triangle = "rbxassetid://9117060042", -- Nasa Static Burst 2
            tablet_open = "rbxassetid://15675059323", -- Roblox_UI_Bright_Click (oficial)
            tablet_close = "rbxassetid://15675032796", -- Roblox_UI_Small_Click (oficial)
            ping_send = "rbxassetid://9125981410", -- Spaceship Sonar Low And High Pitch Tonal
            ping_result = "rbxassetid://9117060349", -- Nasa Transmission Beep 2
            terminal_open = "rbxassetid://9117060347", -- Nasa Transmission Beep 1
            terminal_key = "rbxassetid://15675032796", -- Roblox_UI_Small_Click (oficial)
            terminal_ok = "rbxassetid://15675059323", -- Roblox_UI_Bright_Click (oficial)
            terminal_err = "rbxassetid://9113085764", -- Alarm Buzzer 5
            firewall_break = "rbxassetid://9126001142", -- Static Squeaky Bursts Sharp Electric Charge
            firewall_restore = "rbxassetid://9119816522", -- Synth Power Up Multi Tone Wind Ups Rise 3
            intrusion_alarm = "rbxassetid://9113086365", -- Alarm Buzzer 1 (loop)
            puzzle_ok = "rbxassetid://15675059323", -- Roblox_UI_Bright_Click (oficial)
            puzzle_err = "rbxassetid://9113085764", -- Alarm Buzzer 5
            generator_reset = "rbxassetid://9117882503", -- Power Up Accelerating Motors 1
            jumpscare_hexagon = "rbxassetid://9126001417", -- Static Squeaky Bursts Sharp Electric Charge
            virus_alert = "rbxassetid://9125557781", -- Fire Alarm High School Harsh Rhythmic Buzzer (loop)
        } :: { [string]: string },
        arrivalDuckAmount = 0.6,
        arrivalDuckSeconds = 1.5,
        rollOffMaxDistance = 40, -- alcance dos sons posicionais, em studs (5.13)
    },
    Debug = {
        timeScale = 1, -- 5 = noite de 72s para testar. Só tem efeito em Studio (5.9).
        deterministicSeed = nil :: number?, -- número = RNG reproduzível. Só em Studio.
        logAI = false, -- imprime cada sorteio das IAs (Fase 3)
        logSession = true, -- imprime boot, fases e fim de noite no Output
        deadCamerasAtStart = {} :: { string }, -- ex.: { "CAM1" } para testar "em nó cego". Só em Studio.
        levelOverrides = { circle = 20 } :: { [string]: number }, -- ex.: { hexagon = 20 } para testar a Fase 5. Só em Studio.
    },
}

-- Congela recursivamente: ninguém altera config em runtime; balancear é editar este arquivo.
-- t: any justificado — percorre qualquer sub-tabela genericamente. O congelamento é in-place,
-- então o módulo devolve a própria GameConfig e quem a importa mantém o tipo preciso de cada campo.
local function deepFreeze(t: any)
    for _, child in t do
        if typeof(child) == "table" and not table.isfrozen(child) then
            deepFreeze(child)
        end
    end
    table.freeze(t)
end

deepFreeze(GameConfig)

return GameConfig
