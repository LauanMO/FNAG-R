--!strict
-- TutorialService: a Noite 0 roteirizada (PLANEJAMENTO 3.12, B.6). Sem RNG, sem relógio e sem dreno: uma
-- sequência de passos; cada um manda falas ao cliente (TutorialStep) e espera uma condição.
-- Condições da sala (porta, ping, reparo, puzzle) são conferidas aqui a cada Tutorial.pollSeconds; olhar em
-- volta, chegar à página 2 do manual e "clique para continuar" vêm do cliente (TutorialAdvance), validados
-- contra o passo atual.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Enums = require(Shared.Enums)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local NightSession = require(script.Parent.NightSession)
local FirewallService = require(script.Parent.FirewallService)

type Session = NightSession.NightSession
type Step = {
    lines: { number }, -- índices em Strings.Tutorial.lines (B.6)
    wait: string, -- Enums.TutorialWait
    enter: ((Session) -> ())?, -- o que o roteiro faz ao começar o passo
}

local W = Enums.TutorialWait
local POLL_TASK = "tutorial"

-- Esperas que só o cliente enxerga; as outras o servidor confere sozinho
local CLIENT_WAITS: { [string]: boolean } = {
    [W.Click] = true,
    [W.Look] = true,
    [W.NotebookPage2] = true,
}

local TutorialService = {}

-- 3.12, passo 4: um Quadrado falso no corredor esquerdo, só para o ping mostrar algo
local function fakeEnemyInCorridor(session: Session)
    session.state.scriptedNodes = { [Enums.Node.CAM2] = true }
end

local function fakeEnemyArrives(session: Session)
    session.state.scriptedNodes = { [Enums.Node.DoorLeft] = true }
    session:fireCue(Enums.Side.Left, Enums.EnemyCue.Arrival)
    session:setEnemyVisual(Enums.Side.Left, true)
end

local function fakeEnemyRepelled(session: Session)
    session.state.scriptedNodes = {}
    session:fireCue(Enums.Side.Left, Enums.EnemyCue.Repelled)
    session:setEnemyVisual(Enums.Side.Left, false)
end

-- 3.12, passo 6: a corrupção é de verdade; o jogador conserta pelo terminal
local function jamRightDoor(session: Session)
    FirewallService.corruptSystem(session, Enums.System.DoorRightJammed)
end

-- 3.12, passo 7: rompe só a camada, sem corromper outro sistema
local function breakOneLayer(session: Session)
    FirewallService.breakLayer(session, false)
end

-- Os 8 passos de 3.12, divididos em sub-passos de uma espera cada
local STEPS: { Step } = {
    { lines = { 1, 2, 3, 4 }, wait = W.Click }, -- 1 abertura
    { lines = { 5 }, wait = W.Look }, -- 2 olhar
    { lines = { 6 }, wait = W.Click },
    { lines = { 7 }, wait = W.DoorLeftClosed }, -- 3 portas
    { lines = { 8 }, wait = W.Click },
    { lines = { 9 }, wait = W.DoorLeftOpen },
    { lines = { 10 }, wait = W.Ping, enter = fakeEnemyInCorridor }, -- 4 radar
    { lines = { 11 }, wait = W.Click },
    { lines = { 12 }, wait = W.DoorLeftClosed, enter = fakeEnemyArrives },
    { lines = { 13 }, wait = W.DoorLeftOpen, enter = fakeEnemyRepelled },
    { lines = { 14 }, wait = W.NotebookPage2 }, -- 5 manual
    { lines = { 15, 16 }, wait = W.RepairDoorRight, enter = jamRightDoor }, -- 6 terminal
    { lines = { 17 }, wait = W.Click },
    { lines = { 18 }, wait = W.Puzzle, enter = breakOneLayer }, -- 7 firewall
    { lines = { 19 }, wait = W.Click },
    { lines = { 20, 21 }, wait = W.Click }, -- 8 encerramento
}

local function enterStep(session: Session, index: number)
    local step = STEPS[index]
    session.state.tutorial = { step = index, waitFor = step.wait, baseline = session.state.pingCount }
    local enter = step.enter
    if enter then
        enter(session)
    end
    local lines: { string } = {}
    for _, n in step.lines do
        table.insert(lines, Strings.Tutorial.lines[n])
    end
    session:fire(
        Enums.Remote.TutorialStep,
        { step = index, lines = lines, waitFor = step.wait } :: Types.TutorialStepPayload
    )
end

local function nextStep(session: Session)
    local tutorial = session.state.tutorial
    if not tutorial then
        return
    end
    if tutorial.step >= #STEPS then
        session.state.tutorial = nil
        session:win() -- 3.12: fim da Noite 0; vencer libera a Noite 1 (NightService)
        return
    end
    enterStep(session, tutorial.step + 1)
end

local function conditionMet(session: Session, tutorial: Types.TutorialState): boolean
    local s = session.state
    local wait = tutorial.waitFor
    if wait == W.DoorLeftClosed then
        return s.doors.left.closed
    elseif wait == W.DoorLeftOpen then
        return not s.doors.left.closed
    elseif wait == W.Ping then
        return s.pingCount > tutorial.baseline
    elseif wait == W.RepairDoorRight then
        return not s.corrupted[Enums.System.DoorRightJammed]
    elseif wait == W.Puzzle then
        return s.firewallLayers >= GameConfig.Hexagon.maxLayers
    end
    return false -- esperas do cliente chegam por advance()
end

local function poll(session: Session)
    local tutorial = session.state.tutorial
    if not tutorial then
        enterStep(session, 1) -- o primeiro poll acontece logo depois do boot
    elseif conditionMet(session, tutorial) then
        nextStep(session)
    end
end

-- TutorialAdvance { step } (5.6): só na Noite 0, só no passo atual e só para esperas do cliente
function TutorialService.advance(session: Session, payload: unknown)
    local tutorial = session.state.tutorial
    if not tutorial or typeof(payload) ~= "table" then
        return
    end
    -- cast justificado: o payload vem do cliente e é validado campo a campo
    local step = (payload :: any).step
    if step ~= tutorial.step or not CLIENT_WAITS[tutorial.waitFor] then
        return
    end
    nextStep(session)
end

-- Liga o roteiro numa sessão da Noite 0. Chamar antes de session:start().
function TutorialService.attach(session: Session)
    session:addAITask(POLL_TASK, GameConfig.Tutorial.pollSeconds, function()
        poll(session)
    end)
end

return TutorialService
