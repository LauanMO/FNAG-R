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
    cameraDead = "NODE CAM %s DESTRUÍDO",
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
Strings.EnemyName = table.freeze({
    square = "QUADRADO AZUL",
    triangle = "TRIÂNGULO VERMELHO",
    circle = "CÍRCULO AMARELO",
    hexagon = "HEXÁGONO CIANO",
})

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

return table.freeze(Strings)
