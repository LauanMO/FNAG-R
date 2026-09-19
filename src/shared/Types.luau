--!strict
-- Types: tipos compartilhados entre servidor e cliente (PLANEJAMENTO 5.4, 5.6, 3.14).
-- Só declarações; nenhum código roda aqui.

export type Phase = "boot" | "running" | "blackout" | "won" | "lost"
export type Side = "left" | "right"
export type Enemy = "square" | "triangle" | "circle" | "hexagon"
export type PowerSource = "base" | "door_left" | "door_right" | "tablet" | "leak"
export type Interact = "door_left" | "door_right" | "terminal" | "notebook" | "tablet"
export type EnemyCue = "arrival" | "repelled" | "footstep"
export type NodeState = "clear" | "anomaly" | "dead"
export type ServerStatus = "ok" | "anomalous" -- CAM 4: tráfego anômalo = vírus do Círculo pendente
export type EchoKind = "ok" | "info" | "err" | "echo" | "clear" -- "clear" limpa a tela do terminal
export type FirewallCause = "init" | "break" | "restore"
export type TerminalLine = { text: string, kind: EchoKind }

export type DoorState = { closed: boolean, jammed: boolean }

-- Custom Night (3.13): um nível 0..20 por IA
export type CustomLevels = { square: number, triangle: number, circle: number, hexagon: number }

-- Noite 0 (3.12): passo atual, o que ele espera e a contagem de pings quando começou
export type TutorialState = { step: number, waitFor: string, baseline: number }

-- Métricas de playtest (7.8), impressas no fim da noite com Debug.logMetrics
export type NightMetrics = {
    doorCloses: { [string]: number }, -- lado → quantas vezes fechou
    doorClosedSeconds: { [string]: number }, -- lado → tempo total fechada
    doorClosedSince: { [string]: number }, -- lado → quando fechou (Scheduler.elapsed), se está fechada
    commands: number,
    commandsNotFound: number,
    minigameErrors: number,
    puzzleErrors: number,
    blackoutAt: number?, -- segundos de noite quando a energia zerou
}

-- Uma linha de GameConfig.Nights (7.4)
export type NightLevels = {
    square: number,
    triangle: number,
    circle: number,
    hexagon: number,
    arrivalCueVolume: number,
    sonar: boolean,
}

-- Todo o estado de uma noite (5.4). Vive só no servidor, dentro de NightSession.
export type NightState = {
    night: number,
    players: { Player },
    phase: Phase,
    hour: number, -- 0..6
    secondsIntoHour: number,
    power: number, -- 0..100 (float; o HUD mostra inteiro)
    doors: { left: DoorState, right: DoorState },
    tabletOpen: boolean,
    terminalOpen: boolean,
    firewallLayers: number,
    corrupted: { [string]: boolean }, -- Enums.System → true
    deadCameras: { [string]: boolean }, -- Enums.Node → true
    intrusionRemaining: number?,
    generatorUsesLeft: number,
    tabletBatteryRemaining: number?, -- só em blackout
    virusAlert: { remaining: number }?,
    minigame: { words: { string }, answerIndex: number, remaining: number }?,
    puzzle: { gate: string, options: { string }, locked: boolean }?, -- locked: nova tabela a caminho após erro
    restoreCooldown: number,
    pingBusy: boolean, -- do RequestPing até PingCooldownOver (3.5a)
    pingCount: number, -- pings resolvidos nesta noite (tutorial e métricas)
    scriptedNodes: { [string]: boolean }, -- anomalias falsas do tutorial que o radar enxerga (3.12)
    tutorial: TutorialState?,
    metrics: NightMetrics,
    -- PatrolAI (Fase 3), HexagonAI (5a), CircleAI (5b). `any`: classes de módulos diferentes, só para debug.
    ai: { [string]: any },
}

-- O que uma IA enxerga da sessão (5.7). Interface estrutural: as IAs não fazem require de NightSession
-- (evitaria um ciclo) e ficam testáveis com um host falso.
export type AIHost = {
    rng: Random,
    state: NightState,
    fireCue: (self: AIHost, side: Side, cue: EnemyCue) -> (),
    setEnemyVisual: (self: AIHost, side: Side, visible: boolean) -> (),
    lose: (self: AIHost, enemy: Enemy) -> (),
    inDawnGrace: (self: AIHost) -> boolean,
}

-- Dados persistidos por jogador (3.14)
export type SaveData = {
    version: number,
    currentNight: number, -- noite que o [Continue] abre
    maxNightUnlocked: number, -- maior noite alcançada (0 a 8; 8 = venceu a 7)
    tutorialDone: boolean,
    stats: {
        nightsWon: number,
        deaths: number,
        deathsBy: { [string]: number }, -- Enums.Enemy → contagem
        bestTimeAlive: number, -- segundos, para o futuro
    },
    settings: {
        masterVolume: number,
        showCommandPalette: boolean,
    },
}

-- Payloads dos Remotes (5.6). O servidor valida tipo e faixa de tudo que recebe (5.9).
-- Cliente → Servidor
-- newGame: New Game (zera a noite atual e começa pelo tutorial). custom: Custom Night (ignora night).
export type StartNightPayload = { night: number, newGame: boolean?, custom: CustomLevels? }
export type TutorialAdvancePayload = { step: number }
export type ToggleDoorPayload = { side: Side }
export type SetTabletOpenPayload = { open: boolean }
export type SetTerminalOpenPayload = { open: boolean }
export type TerminalCommandPayload = { text: string }
export type PuzzlePickPayload = { gate: string }
export type MinigamePickPayload = { index: number }
export type UpdateSettingsPayload = { masterVolume: number } -- 0..1

-- Servidor → Cliente
export type SaveLoadedPayload = { save: SaveData, available: boolean } -- available = false: modo sem save
export type NightStartedPayload = { night: number, config: NightLevels }
export type NightPhasePayload = { phase: Phase }
export type HourChangedPayload = { hour: number }
export type PowerChangedPayload = { power: number, drainRate: number, sources: { PowerSource } }
export type DoorStateChangedPayload = { side: Side, closed: boolean, jammed: boolean, accepted: boolean }
export type EnemyAudioCuePayload = { side: Side, cue: EnemyCue, volume: number }
export type EnemyVisualPayload = { side: Side, visible: boolean }
export type TabletStatePayload = { open: boolean, available: boolean, batteryRemaining: number? }
export type PingResultPayload = {
    nodes: { [string]: NodeState },
    anomalies: number, -- nós com anomalia, inclusive os cegos
    blind: number, -- desses, quantos estão em nó morto
    serverStatus: ServerStatus,
}
export type CameraDeadPayload = { camera: string }
export type FirewallChangedPayload = { layers: number, max: number, cause: FirewallCause }
-- SystemCorrupted e SystemRepaired: o sistema que mudou e a lista completa dos corrompidos (5.6)
export type SystemChangedPayload = { system: string, corrupted: { string } }
export type IntrusionStatePayload = { active: boolean, remaining: number? }
export type TerminalEchoPayload = TerminalLine
export type TerminalPalettePayload = { commands: { string } }
export type PuzzleStartPayload = { truthTable: { { number } }, options: { string } }
export type PuzzleResultPayload = { correct: boolean, gate: string, layers: number, penalty: number }
export type GeneratorUsedPayload = { punished: boolean, power: number, usesLeft: number }
export type VirusAlertPayload = { active: boolean, remaining: number? }
export type MinigameStartPayload = { words: { string }, seconds: number } -- seconds = tempo que resta
export type MinigameResultPayload = { success: boolean, cameraKilled: string?, timeout: boolean }
export type BlackoutStartedPayload = { tabletBatterySeconds: number }
export type NightWonPayload = { night: number, nextNight: number }
export type JumpscarePayload = { enemy: Enemy }
export type TutorialStepPayload = { step: number, lines: { string }, waitFor: string }

return {}
