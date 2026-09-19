--!strict
-- MinigameService: o alerta de vírus do Círculo e o minigame de sintaxe (PLANEJAMENTO 3.8.3, 5.5).
-- Alerta com fusível → terminal aberto vira minigame de 9 palavras e 15 s → acerto limpa; erro ou tempo
-- esgotado destrói a próxima câmera da ordem. A palavra infectada (answerIndex) fica só no servidor (5.9).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Enums = require(Shared.Enums)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local NightSession = require(script.Parent.NightSession)
local RadarService = require(script.Parent.RadarService)
local CircleAI = require(script.Parent.ai.CircleAI)

type Session = NightSession.NightSession

local Task = NightSession.Task
local CIRCLE_TASK = "ai_circle"

local MinigameService = {}

local function fireAlert(session: Session)
    local alert = session.state.virusAlert
    session:fire(
        Enums.Remote.VirusAlert,
        { active = alert ~= nil, remaining = if alert then alert.remaining else nil } :: Types.VirusAlertPayload
    )
end

local function fireMinigame(session: Session)
    local current = session.state.minigame
    if current then
        session:fire(
            Enums.Remote.MinigameStart,
            { words = current.words, seconds = current.remaining } :: Types.MinigameStartPayload
        )
    end
end

-- 3.8.3: o fusível acabou sem o terminal ser aberto; o vírus destrói uma câmera sozinho
local function fuseExpired(session: Session)
    session.scheduler:remove(Task.CircleFuse)
    session.state.virusAlert = nil
    fireAlert(session)
    local camera = RadarService.killNextCamera(session)
    if camera then
        session:alert(string.format(Strings.Terminal.alertNodeDestroyed, camera), Enums.EchoKind.Err)
    end
end

-- O Círculo passou no teste (3.8.3). Só dispara sem alerta nem minigame pendente e com o terminal fechado.
function MinigameService.startAlert(session: Session): boolean
    local s = session.state
    if s.virusAlert or s.minigame or s.terminalOpen then
        return false
    end
    local C = GameConfig.Circle
    s.virusAlert = { remaining = C.alertFuseSeconds }
    fireAlert(session)
    session.scheduler:every(Task.CircleFuse, C.fuseTickSeconds, function()
        local alert = s.virusAlert
        if not alert then
            session.scheduler:remove(Task.CircleFuse)
            return
        end
        alert.remaining -= C.fuseTickSeconds
        if alert.remaining <= 0 then
            fuseExpired(session)
        else
            fireAlert(session)
        end
    end)
    return true
end

-- 8 palavras normais (podem repetir, como no original) e 1 infectada numa posição sorteada (3.8.3)
local function pickWords(session: Session): ({ string }, number)
    local C = GameConfig.Circle
    local normal = Strings.Minigame.normalWords
    local infected = Strings.Minigame.errorWords
    local words: { string } = {}
    for _ = 1, C.minigameWordCount - 1 do
        table.insert(words, normal[session.rng:NextInteger(1, #normal)])
    end
    local answerIndex = session.rng:NextInteger(1, C.minigameWordCount)
    table.insert(words, answerIndex, infected[session.rng:NextInteger(1, #infected)])
    return words, answerIndex
end

-- Fim do minigame. Acertando ou errando, o terminal fecha (3.8.3); erro e tempo esgotado custam uma câmera.
local function resolve(session: Session, success: boolean, timeout: boolean)
    local s = session.state
    if not s.minigame then
        return
    end
    s.minigame = nil
    session.scheduler:remove(Task.MinigameTimer)
    local camera = if success then nil else RadarService.killNextCamera(session)
    local M = Strings.Minigame
    if success then
        session:echo(M.ok, Enums.EchoKind.Ok)
    else
        session:echo(if timeout then M.timeout else M.err, Enums.EchoKind.Err)
    end
    s.terminalOpen = false
    session:closePuzzle()
    session:fire(
        Enums.Remote.MinigameResult,
        { success = success, cameraKilled = camera, timeout = timeout } :: Types.MinigameResultPayload
    )
end

-- Terminal aberto com alerta ativo: o alarme para e o minigame toma o lugar do prompt (3.8.3, 3.11)
local function startMinigame(session: Session)
    local s = session.state
    local C = GameConfig.Circle
    session.scheduler:remove(Task.CircleFuse)
    s.virusAlert = nil
    fireAlert(session)
    local words, answerIndex = pickWords(session)
    s.minigame = { words = words, answerIndex = answerIndex, remaining = C.minigameSeconds }
    fireMinigame(session)
    session.scheduler:every(Task.MinigameTimer, C.minigameTickSeconds, function()
        local current = s.minigame
        if not current then
            session.scheduler:remove(Task.MinigameTimer)
            return
        end
        current.remaining -= C.minigameTickSeconds
        if current.remaining <= 0 then
            resolve(session, false, true)
        end
    end)
end

-- Chamado depois de SetTerminalOpen { open = true }. Minigame em andamento (o jogador fechou e reabriu o
-- terminal) é reenviado com o tempo que resta; o relógio dele não para com o terminal fechado.
function MinigameService.onTerminalOpened(session: Session)
    local s = session.state
    if not s.terminalOpen then
        return
    end
    if s.minigame then
        fireMinigame(session)
    elseif s.virusAlert then
        startMinigame(session)
    end
end

-- MinigamePick { index } (5.6): minigame ativo, terminal aberto, índice dentro da lista
function MinigameService.pick(session: Session, index: number)
    local s = session.state
    local current = s.minigame
    if not current or not s.terminalOpen then
        return
    end
    if index < 1 or index > #current.words then
        return
    end
    resolve(session, index == current.answerIndex, false)
end

-- Cria o Círculo da noite e registra o tick dele na sessão. Chamar antes de session:start().
function MinigameService.attach(session: Session)
    local circle = CircleAI.new(session.levels.circle, session.rng, function()
        return not session:inDawnGrace()
    end, function()
        return MinigameService.startAlert(session)
    end)
    session.state.ai[Enums.Enemy.Circle] = circle
    session:addAITask(CIRCLE_TASK, GameConfig.Circle.tickSeconds, function()
        circle:tick()
    end)
end

return MinigameService
