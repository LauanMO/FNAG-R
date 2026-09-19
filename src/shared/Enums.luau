--!strict
-- Enums: nomes canônicos de fases, lados, inimigos, sistemas, nós, fontes de energia, cues e Remotes
-- (PLANEJAMENTO 5.1). Os conjuntos pequenos usam tipos literais para o --!strict pegar erro de digitação.

local Enums = {}

Enums.Phase = table.freeze({
    Boot = "boot" :: "boot",
    Running = "running" :: "running",
    Blackout = "blackout" :: "blackout",
    Won = "won" :: "won",
    Lost = "lost" :: "lost",
})

Enums.Side = table.freeze({
    Left = "left" :: "left",
    Right = "right" :: "right",
})

-- Noites especiais (3.1, 3.12, 3.13). As normais são 1..#GameConfig.Nights.
Enums.Night = table.freeze({
    Tutorial = 0,
    Custom = -1, -- Custom Night: níveis escolhidos pelo jogador
})

-- O que cada passo da Noite 0 espera (3.12). Click, Look e NotebookPage2 são reportados pelo cliente.
Enums.TutorialWait = table.freeze({
    Click = "click",
    Look = "look",
    DoorLeftClosed = "door_left_closed",
    DoorLeftOpen = "door_left_open",
    Ping = "ping",
    NotebookPage2 = "notebook_page2",
    RepairDoorRight = "repair_door_right",
    Puzzle = "puzzle",
})

Enums.Enemy = table.freeze({
    Square = "square" :: "square",
    Triangle = "triangle" :: "triangle",
    Circle = "circle" :: "circle",
    Hexagon = "hexagon" :: "hexagon",
})

-- Fontes de dreno de energia (3.2). A lista ativa vai no PowerChanged e vira as barrinhas do HUD.
Enums.PowerSource = table.freeze({
    Base = "base" :: "base",
    DoorLeft = "door_left" :: "door_left",
    DoorRight = "door_right" :: "door_right",
    Tablet = "tablet" :: "tablet",
    Leak = "leak" :: "leak",
})

-- Sistemas que o Hexágono corrompe (3.8.4). Os nomes aparecem no HUD e no terminal.
Enums.System = table.freeze({
    CameraOffline = "camera_offline",
    DoorLeftJammed = "door_left_jammed",
    DoorRightJammed = "door_right_jammed",
    ClockGlitch = "clock_glitch",
    PowerLeak = "power_leak",
})

-- Nós do Global Security Node Map (3.5)
Enums.Node = table.freeze({
    CAM1 = "CAM1",
    CAM2 = "CAM2",
    CAM3 = "CAM3",
    CAM4 = "CAM4",
    DoorLeft = "DOOR_L",
    DoorRight = "DOOR_R",
    Office = "OFFICE",
})

-- Ordem fixa dos nós para varreduras (radar) e listas
Enums.NodeList = table.freeze({
    Enums.Node.CAM1,
    Enums.Node.CAM2,
    Enums.Node.CAM3,
    Enums.Node.CAM4,
    Enums.Node.DoorLeft,
    Enums.Node.DoorRight,
    Enums.Node.Office,
})

-- Estado de um nó no PingResult (3.5c)
Enums.NodeState = table.freeze({
    Clear = "clear" :: "clear",
    Anomaly = "anomaly" :: "anomaly",
    Dead = "dead" :: "dead",
})

Enums.ServerStatus = table.freeze({
    Ok = "ok" :: "ok",
    Anomalous = "anomalous" :: "anomalous",
})

-- Tipo de linha no terminal (3.6): cor e som no cliente; "clear" limpa a tela
Enums.EchoKind = table.freeze({
    Ok = "ok" :: "ok",
    Info = "info" :: "info",
    Err = "err" :: "err",
    Echo = "echo" :: "echo",
    Clear = "clear" :: "clear",
})

-- Por que o firewall mudou: o cliente escolhe o som (vidro quebrando / restauração)
Enums.FirewallCause = table.freeze({
    Init = "init" :: "init",
    Break = "break" :: "break",
    Restore = "restore" :: "restore",
})

-- Telas cheias do cliente; só uma aberta por vez (Overlay.luau)
Enums.Overlay = table.freeze({
    Tablet = "tablet",
    Terminal = "terminal",
    Notebook = "notebook",
})

-- Cues de áudio (3.11). O asset real de cada um fica em GameConfig.Audio.ids.
Enums.Cue = table.freeze({
    AmbientHum = "ambient_hum",
    AmbientLowPower = "ambient_low_power",
    DoorClose = "door_close",
    DoorOpen = "door_open",
    DoorJammed = "door_jammed",
    DoorImpact = "door_impact",
    EnemyArrivalLeft = "enemy_arrival_left",
    EnemyArrivalRight = "enemy_arrival_right",
    PingSend = "ping_send",
    PingResult = "ping_result",
    TabletOpen = "tablet_open",
    TabletClose = "tablet_close",
    TerminalOpen = "terminal_open",
    TerminalKey = "terminal_key",
    TerminalOk = "terminal_ok",
    TerminalErr = "terminal_err",
    VirusAlert = "virus_alert",
    FirewallBreak = "firewall_break",
    FirewallRestore = "firewall_restore",
    IntrusionAlarm = "intrusion_alarm",
    PuzzleOk = "puzzle_ok",
    PuzzleErr = "puzzle_err",
    Blackout = "blackout",
    GeneratorReset = "generator_reset",
    JumpscareSquare = "jumpscare_square",
    JumpscareTriangle = "jumpscare_triangle",
    JumpscareHexagon = "jumpscare_hexagon",
    Dawn = "dawn",
    MenuGlitch = "menu_glitch",
})

-- Tipo de cue enviado em EnemyAudioCue (5.6)
Enums.EnemyCue = table.freeze({
    Arrival = "arrival" :: "arrival",
    Repelled = "repelled" :: "repelled",
    Footstep = "footstep" :: "footstep",
})

-- Instâncias da sala whitebox (3.4): contrato entre OfficeBuilder (servidor) e os controllers (cliente)
Enums.Office = table.freeze({
    Model = "Office",
    CameraAnchor = "CameraAnchor",
    Doors = "Doors",
    Corridors = "Corridors",
    -- cast justificado: indexado por Types.Side em runtime
    DoorModel = table.freeze({ left = "Left", right = "Right" } :: { [string]: string }),
    Door = "Door",
    Button = "Button",
    SoundAnchor = "SoundAnchor",
    Monitor = "Monitor",
    Silhouette = "Silhouette",
    Lights = "Lights",
    WallClock = "WallClock",
    WallClockLabel = "Label",
})

-- Atributos gravados nas partes da sala
Enums.Attribute = table.freeze({
    Side = "Side", -- "left" | "right" em Door e Button
    OpenY = "OpenY", -- Y da porta aberta (dentro da parede)
    ClosedY = "ClosedY", -- Y da porta fechada
    Interact = "Interact", -- Enums.Interact nas partes clicáveis
    VisibleTransparency = "VisibleTransparency", -- silhuetas: transparência quando visíveis
})

-- O que um clique/toque em objeto da sala significa (5.11)
Enums.Interact = table.freeze({
    DoorLeft = "door_left" :: "door_left",
    DoorRight = "door_right" :: "door_right",
    Terminal = "terminal" :: "terminal",
    Notebook = "notebook" :: "notebook",
    Tablet = "tablet" :: "tablet",
})

-- Contrato completo de Remotes (5.6). Remotes.luau cria um RemoteEvent por nome.
Enums.Remote = table.freeze({
    -- Cliente → Servidor (intenções)
    ClientReady = "ClientReady",
    StartNight = "StartNight",
    ReturnToMenu = "ReturnToMenu",
    ToggleDoor = "ToggleDoor",
    SetTabletOpen = "SetTabletOpen",
    RequestPing = "RequestPing",
    TerminalCommand = "TerminalCommand",
    SetTerminalOpen = "SetTerminalOpen",
    MinigamePick = "MinigamePick",
    PuzzlePick = "PuzzlePick",
    PuzzleCancel = "PuzzleCancel",
    TutorialAdvance = "TutorialAdvance",
    UpdateSettings = "UpdateSettings",
    -- Servidor → Cliente (estado/eventos)
    SaveLoaded = "SaveLoaded",
    NightStarted = "NightStarted",
    NightPhase = "NightPhase",
    HourChanged = "HourChanged",
    PowerChanged = "PowerChanged",
    DoorStateChanged = "DoorStateChanged",
    TabletState = "TabletState",
    PingStarted = "PingStarted",
    PingResult = "PingResult",
    PingCooldownOver = "PingCooldownOver",
    EnemyAudioCue = "EnemyAudioCue",
    EnemyVisual = "EnemyVisual",
    VirusAlert = "VirusAlert",
    MinigameStart = "MinigameStart",
    MinigameResult = "MinigameResult",
    CameraDead = "CameraDead",
    FirewallChanged = "FirewallChanged",
    SystemCorrupted = "SystemCorrupted",
    SystemRepaired = "SystemRepaired",
    IntrusionState = "IntrusionState",
    PuzzleStart = "PuzzleStart",
    PuzzleResult = "PuzzleResult",
    PuzzleClosed = "PuzzleClosed",
    TerminalEcho = "TerminalEcho",
    TerminalPalette = "TerminalPalette",
    BlackoutStarted = "BlackoutStarted",
    BlackoutEnded = "BlackoutEnded",
    TabletBatteryDead = "TabletBatteryDead",
    GeneratorUsed = "GeneratorUsed",
    Jumpscare = "Jumpscare",
    NightWon = "NightWon",
    TutorialStep = "TutorialStep",
})

return table.freeze(Enums)
