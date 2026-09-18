--!strict
-- Strings: todos os textos do jogo (PLANEJAMENTO Apêndice B). Textos em português; comandos em inglês.
-- Fase 1: boot, menu, HUD e telas de fim. Terminal, manual, tutorial e listas de palavras entram nas Fases 5 e 7.
-- Nenhum módulo escreve texto de jogo inline (Apêndice C.8).

local Strings = {}

Strings.Boot = table.freeze({
    initializing = "INICIALIZANDO SIMULAÇÃO_",
})

-- B.8
Strings.Menu = table.freeze({
    title = "Five Nights at Geometry",
    newGame = "New Game",
    continueGame = "Continue",
    continueNight = "Continue — Noite %d",
    tutorial = "Tutorial",
    customNight = "Custom Night",
    settings = "Configurações",
    comingSoon = "%s (em breve)",
    footer = "© 2026 Arthur", -- ajustar créditos do time
    saveUnavailable = "Save indisponível — progresso não será salvo",
})

-- B.4
Strings.HUD = table.freeze({
    night = "NOITE %d",
    nightTutorial = "NOITE 0 — TUTORIAL",
    nightCustom = "CUSTOM NIGHT",
    power = "ENERGIA: %d%%",
    firewall = "FIREWALL: ",
    corruptedSystem = "[!] %s",
    virusAlert = "ANOMALIA DETECTADA — ABRIR TERMINAL",
    intrusion = "INTRUSÃO EM CURSO — RESTAURE O FIREWALL — %ds",
    doorJammed = "MOTOR TRAVADO — ver manual",
    generatorAvailable = "GERADOR: %d uso",
    generatorUsed = "GERADOR: usado",
    cameraDead = "NODE %s DESTRUÍDO",
    blackout = "BLACKOUT",
    blackoutBattery = "BLACKOUT — bateria do tablet: %ds",
    tabletOffline = "TABLET OFFLINE — fix camera",
    doorLeftButton = "◀ PORTA",
    doorRightButton = "PORTA ▶",
})

-- B.7
Strings.EndScreens = table.freeze({
    nightComplete = "NOITE %d CONCLUÍDA",
    simulationOver = "SIMULAÇÃO ENCERRADA",
    criticalFailure = "FALHA CRÍTICA — NOITE %d",
    anomaly = "anomalia: %s",
    retry = "TENTAR DE NOVO",
    menu = "MENU",
    firewallBreached = "FIREWALL BREACHED",
})

-- Nome dos inimigos nas telas de fim (B.7), indexado por Enums.Enemy
-- cast justificado: indexado por Types.Enemy em runtime
Strings.EnemyName = table.freeze({
    square = "QUADRADO AZUL",
    triangle = "TRIÂNGULO VERMELHO",
    circle = "CÍRCULO AMARELO",
    hexagon = "HEXÁGONO CIANO",
} :: { [string]: string })

-- B.5
Strings.Tablet = table.freeze({
    title = "GLOBAL SECURITY NODE MAP v2.4",
    pingButton = "▶ EMITIR PING RADAR GLOBAL",
    close = "FECHAR",
    hudButton = "TABLET",
    statusIdle = "SISTEMA EM ESPERA...",
    statusSending = "ENVIANDO PING RADAR PARA TODOS OS NODES...",
    statusResult = "SCAN COMPLETO. %d ANOMALIA(S).",
    statusResultBlind = "SCAN COMPLETO. %d ANOMALIA(S) (%d EM NÓ CEGO).",
    statusClear = "SCAN COMPLETO. NENHUMA ANOMALIA VISÍVEL.",
    statusLost = "SINAL PERDIDO. RECOMENDA-SE NOVO PING.",
    anomaly = "ANOMALIA",
    dead = "DEAD",
    anomalousTraffic = "TRÁFEGO ANÔMALO",
    footerFirewall = "FIREWALL: %s",
    footerPower = "⚡ %d%%",
})

-- Nomes dos nós no mapa (B.5). cast justificado: indexado por Enums.Node em runtime
Strings.NodeName = table.freeze({
    CAM1 = "CAM 1 — PALCO",
    CAM2 = "CAM 2 — CORR. ESQ",
    CAM3 = "CAM 3 — CORR. DIR",
    CAM4 = "CAM 4 — SERVIDORES",
    DOOR_L = "DOOR L",
    DOOR_R = "DOOR R",
    OFFICE = "ESCRITÓRIO",
} :: { [string]: string })

-- Nome curto para mensagens do HUD ("NODE CAM 1 DESTRUÍDO")
Strings.NodeShort = table.freeze({
    CAM1 = "CAM 1",
    CAM2 = "CAM 2",
    CAM3 = "CAM 3",
    CAM4 = "CAM 4",
    DOOR_L = "DOOR L",
    DOOR_R = "DOOR R",
    OFFICE = "ESCRITÓRIO",
} :: { [string]: string })

-- Relógio (B.4): 0 → "12:00 AM", 1..6 → "1:00 AM" .. "6:00 AM"
function Strings.clock(hour: number): string
    local display = if hour == 0 then 12 else hour
    return string.format("%d:00 AM", display)
end

function Strings.nightLabel(night: number): string
    if night == 0 then
        return Strings.HUD.nightTutorial
    end
    return string.format(Strings.HUD.night, night)
end

-- Firewall (B.4): ▮ por camada íntegra, ▯ por camada rompida
function Strings.firewallBar(layers: number, max: number): string
    return string.rep("▮", math.max(0, layers)) .. string.rep("▯", math.max(0, max - layers))
end

return table.freeze(Strings)
