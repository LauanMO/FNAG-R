--!strict
-- Strings: todos os textos do jogo (PLANEJAMENTO Apêndice B). Textos em português; comandos em inglês.
-- Números de balanceamento citados nos textos vêm do GameConfig, para o manual nunca mentir.
-- Tutorial e listas de palavras do minigame entram nas Fases 5b e 7.
-- Nenhum módulo escreve texto de jogo inline (Apêndice C.8).

local GameConfig = require(script.Parent.GameConfig)

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
    footer = "© 2026 Arthur", -- ajustar créditos do time
    saveUnavailable = "Save indisponível — progresso não será salvo",
})

-- Configurações do menu (Fase 6)
Strings.Settings = table.freeze({
    title = "CONFIGURAÇÕES",
    volume = "VOLUME: %d%%",
    volumeDown = "−",
    volumeUp = "+",
    back = "VOLTAR",
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
    glitchChars = "!@#$%^&*?<>/\\|", -- clock_glitch: 8 destes, trocando a cada 0.18s
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

-- B.1
Strings.Terminal = table.freeze({
    boot1 = "GEOMETRY OS v1.0 ONLINE...",
    boot2 = "Sistemas estabilizados. Aguardando comando.",
    prompt = "root@office:~$",
    send = "ENVIAR",
    close = "FECHAR",
    hudButton = "TERMINAL",
    helpPrefix = "Comandos: ",
    notFound = "command not found",
    repaired = "[OK] %s restored.",
    notCorrupted = "[WARN] %s is not currently corrupted.",
    puzzleOpening = "Opening logic-gate repair console...",
    firewallFull = "Firewall already at maximum.",
    consoleCooldown = "Console em cooldown. Aguarde.",
    generatorStart = "Iniciando protocolo de override do gerador...",
    generatorOk = "[OK] Gerador forçado. Bateria restaurada para %d%%.",
    generatorPunished = "[AVISO] Sobrecarga detectada! Bateria descarregada para %d%%.",
    generatorSpent = "[ERRO] Override já utilizado nesta noite.",
    statusFirewall = "Firewall: %d/%d",
    statusPower = "Energia: %d%%",
    statusSystemsOk = "Sistemas: ALL OK",
    statusSystemsHeader = "Sistemas:",
    statusSystemLine = "  [!] %s",
    statusNodesOk = "Nodes: OK",
    statusNodesDead = "Nodes mortos: %s",
    statusGeneratorLeft = "Gerador: %d uso",
    statusGeneratorUsed = "Gerador: usado",
    alertCorrupted = "[ALERT] %s corrupted by HEXAGON",
    alertLayerLost = "[ALERT] Firewall layer lost. %d/%d remaining.",
    alertIntrusion = "[CRITICAL] INTRUSION IN PROGRESS. Restore firewall.",
    alertNodeDestroyed = "[ALERT] Node %s destroyed by CIRCLE.",
})

-- B.1: minigame de sintaxe do Círculo. Regra das listas: palavras normais parecem nomes de módulo de
-- sistema; as infectadas misturam vocabulário de sistema com algo orgânico/perturbador. Nunca deixe uma
-- infectada ser plausível como sistema (Eye_Tracker está no limite, de propósito).
Strings.Minigame = table.freeze({
    title = "SISTEMA CORROMPIDO. SELECIONE A ANOMALIA:",
    timer = "%ds",
    ok = "[OK] Vírus expurgado. Sistemas nominais.",
    err = "[ERR] Sintaxe válida detectada. Node de vídeo destruído.",
    timeout = "[ERR] Tempo esgotado. O vírus destruiu um node de vídeo.",
    blocked = "[bloqueado — resolva a anomalia]",
    normalWords = table.freeze({
        "Function_Door",
        "Central_Connection",
        "Terminal_Overdrive",
        "System_Boot",
        "Camera_Feed",
        "Audio_Link",
        "Security_Breach",
        "Power_Grid",
        "Ventilation_Control",
        "Mainframe_Access",
        "Data_Log",
        "Motion_Sensor",
        "Node_Sync",
        "Firewall_Layer",
        "Door_Servo",
        "Clock_Daemon",
        "Radar_Pulse",
        "Battery_Monitor",
        "Access_Token",
        "Kernel_Patch",
    }),
    errorWords = table.freeze({
        "Banana_Core",
        "Pizza_Protocol",
        "Teeth_Render",
        "Glitch_Entity",
        "Smile_Format",
        "Eye_Tracker",
        "Meat_Syntax",
        "Blood_String",
        "Shadow_Byte",
        "Laugh_Buffer",
        "Skin_Compile",
        "Hunger_Loop",
        "Whisper_Socket",
        "Bone_Index",
        "Wet_Pointer",
    }),
})

-- B.2
Strings.Puzzle = table.freeze({
    title = "PAINEL DE CIRCUITO LÓGICO — RESTAURAÇÃO DE FIREWALL",
    instruction = "Identifique a porta lógica que gera a tabela-verdade abaixo.",
    header = "A | B | OUT",
    row = "%d | %d | %d",
    option = "%s(a, b)",
    correct = "[OK] %s bate com a tabela. +1 camada de Firewall.",
    wrong = "[ERR] %s não bate. Punição: -%d%% energia. Tente novamente.",
    wrongNoPenalty = "[ERR] %s não bate. Tente novamente.", -- Noite 0 (3.12)
    cancel = "CANCELAR ✕",
})

-- B.3. Cada página: título e parágrafos.
local P = GameConfig.Power
Strings.Manual = table.freeze({
    header = "MANUAL DE PROCEDIMENTOS — Vol. 1",
    prev = "◀ ANTERIOR",
    nextPage = "PRÓXIMA ▶",
    pageOf = "%d / %d",
    close = "FECHAR",
    hudButton = "MANUAL",
    pages = table.freeze({
        table.freeze({
            title = "PROCEDIMENTOS DE EMERGÊNCIA",
            body = table.freeze({
                "Se algum sistema for corrompido pelo vírus, abra o TERMINAL e digite o comando exato da página "
                    .. "correspondente. Comandos só funcionam enquanto o sistema estiver corrompido.",
                "O sistema informa corrupções no painel superior ([!] nome_do_sistema).",
            }),
        }),
        table.freeze({
            title = "CÓDIGOS DE REPARO — I",
            body = table.freeze({
                "fix camera — Recompila o feed da câmera principal. (camera_offline)",
                "unjam door_left — Libera o motor travado da porta esquerda. (door_left_jammed)",
                "unjam door_right — Libera o motor travado da porta direita. (door_right_jammed)",
            }),
        }),
        table.freeze({
            title = "CÓDIGOS DE REPARO — II",
            body = table.freeze({
                "sync clock — Ressincroniza o cronômetro do sistema. (clock_glitch)",
                "seal power_leak — Fecha o vazamento no gerador. (power_leak)",
                "Nota: uma porta travada congela no estado em que está. Se estava fechada, continua consumindo energia.",
            }),
        }),
        table.freeze({
            title = "FIREWALL — RESTAURAÇÃO",
            body = table.freeze({
                string.format(
                    "Para subir +1 camada de Firewall, digite restore_firewall no Terminal e resolva o circuito "
                        .. "lógico exibido. Erros custam %d%% de energia.",
                    P.puzzlePenalty
                ),
                string.format(
                    "Se o Firewall chegar a zero, uma INTRUSÃO começa. Você tem %d segundos para restaurar uma camada.",
                    GameConfig.Hexagon.intrusionSeconds
                ),
            }),
        }),
        table.freeze({
            title = "PROTOCOLO DE BLACKOUT",
            body = table.freeze({
                string.format(
                    "Quando a energia zera, as portas abrem e as luzes apagam. O tablet e o terminal funcionam por "
                        .. "%d segundos na bateria interna.",
                    GameConfig.Blackout.tabletBatterySeconds
                ),
                string.format(
                    "Comando de emergência: reset generator — restaura a energia para %d%%. Uso único por noite.",
                    P.generatorResetTo
                ),
                string.format(
                    "ATENÇÃO: usado com a energia acima de %d%%, o sistema entende como sobrecarga e REDUZ a energia "
                        .. "para %d%%.",
                    P.generatorResetTo,
                    P.generatorResetTo
                ),
                "O gerador não fecha as portas. Feche-as você.",
            }),
        }),
    }),
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
