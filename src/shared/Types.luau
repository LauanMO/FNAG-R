--!strict
-- Types: tipos compartilhados entre servidor e cliente (PLANEJAMENTO 5.4, 5.6, 3.14).
-- Só declarações; nenhum código roda aqui.

export type Phase = "boot" | "running" | "blackout" | "won" | "lost"
export type Side = "left" | "right"
export type Enemy = "square" | "triangle" | "circle" | "hexagon"
export type PowerSource = "base" | "door_left" | "door_right" | "tablet" | "leak"

export type DoorState = { closed: boolean, jammed: boolean }

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
    puzzle: { gate: string, options: { string } }?,
    restoreCooldown: number,
    -- Fases 3 e 5: PatrolAI, CircleAI, HexagonAI. `any` até as classes existirem.
    ai: { [string]: any },
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
export type StartNightPayload = { night: number }

-- Servidor → Cliente
export type SaveLoadedPayload = { save: SaveData }
export type NightStartedPayload = { night: number, config: NightLevels }
export type NightPhasePayload = { phase: Phase }
export type HourChangedPayload = { hour: number }
export type PowerChangedPayload = { power: number, drainRate: number, sources: { PowerSource } }
export type DoorStateChangedPayload = { side: Side, closed: boolean, jammed: boolean, accepted: boolean }
export type BlackoutStartedPayload = { tabletBatterySeconds: number }
export type NightWonPayload = { night: number, nextNight: number }
export type JumpscarePayload = { enemy: Enemy }

return {}
