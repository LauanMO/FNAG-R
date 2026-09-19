--!strict
-- TutorialController: a Noite 0 no cliente (PLANEJAMENTO 3.12, B.6). Mostra as falas do TutorialStep com efeito
-- de máquina de escrever (clique pula), e reporta ao servidor o que só o cliente enxerga: "clique para
-- continuar", olhar para os dois lados e chegar à página 2 do manual (TutorialAdvance).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local TutorialGui = require(script.Parent.ui.TutorialGui)
local OfficeCamera = require(script.Parent.OfficeCamera)
local NotebookController = require(script.Parent.NotebookController)
local Overlay = require(script.Parent.Overlay)

-- Disposições da caixa (TutorialGui)
local INTRO_POSITION = UDim2.fromScale(0.5, 0.97)
local INTRO_ANCHOR = Vector2.new(0.5, 1)
local INTRO_SIZE = UDim2.fromScale(0.9, 0.22)
local HINT_POSITION = UDim2.fromScale(0.5, 0.005)
local HINT_ANCHOR = Vector2.new(0.5, 0)
local HINT_SIZE = UDim2.fromScale(0.6, 0.18)

local W = Enums.TutorialWait

local TutorialController = {}

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local ui = TutorialGui.build(playerGui)

local active = false
local step = 0
local lines: { string } = {}
local lineIndex = 0
local waitFor = ""
local typing = false
local advanced = false -- já avisou o servidor neste passo
local token = 0 -- invalida o fade-in pendente
local typeConn: RBXScriptConnection? = nil
local lookConn: RBXScriptConnection? = nil

local function disconnect(connection: RBXScriptConnection?)
    if connection then
        connection:Disconnect()
    end
end

local function updateHint()
    local moreLines = lineIndex < #lines
    ui.hint.Visible = not typing and not advanced and (moreLines or waitFor == W.Click)
end

local function finishTyping()
    disconnect(typeConn)
    typeConn = nil
    ui.text.MaxVisibleGraphemes = -1
    typing = false
    updateHint()
end

-- 3.12: máquina de escrever, Tutorial.typewriterSeconds por caractere
local function showLine(index: number)
    disconnect(typeConn)
    lineIndex = index
    local line = lines[index]
    ui.text.Text = line
    ui.text.MaxVisibleGraphemes = 0
    typing = true
    updateHint()
    local total = utf8.len(line) or #line
    local elapsed = 0
    typeConn = RunService.RenderStepped:Connect(function(dt: number)
        elapsed += dt
        local shown = math.floor(elapsed / GameConfig.Tutorial.typewriterSeconds)
        if shown >= total then
            finishTyping()
        else
            ui.text.MaxVisibleGraphemes = shown
        end
    end)
end

local function advance()
    if advanced then
        return
    end
    advanced = true
    updateHint()
    Remotes.get(Enums.Remote.TutorialAdvance):FireServer({ step = step } :: Types.TutorialAdvancePayload)
end

-- Clique na caixa: completa a fala, passa para a próxima, ou continua o roteiro
local function onBoxActivated()
    if not active or step == 0 then
        return
    end
    if typing then
        finishTyping()
    elseif lineIndex < #lines then
        showLine(lineIndex + 1)
    elseif waitFor == W.Click then
        advance()
    end
end

-- 3.12, passo 2: girar a câmera pelo menos Tutorial.lookDegrees para cada lado
local function startLookTracking()
    disconnect(lookConn)
    local seenLeft = false
    local seenRight = false
    local threshold = GameConfig.Tutorial.lookDegrees
    lookConn = RunService.RenderStepped:Connect(function()
        local yaw = OfficeCamera.getYawDegrees()
        seenLeft = seenLeft or yaw <= -threshold
        seenRight = seenRight or yaw >= threshold
        if seenLeft and seenRight then
            disconnect(lookConn)
            lookConn = nil
            advance()
        end
    end)
end

local function setFigureTransparency(value: number)
    for _, part in ui.figureParts do
        part.BackgroundTransparency = value
    end
end

local function fadeInFigure(seconds: number)
    setFigureTransparency(1)
    local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    for _, part in ui.figureParts do
        TweenService:Create(part, info, { BackgroundTransparency = TutorialGui.figureTransparency }):Play()
    end
end

local function setLayout(intro: boolean)
    ui.intro.Visible = intro
    ui.box.Position = if intro then INTRO_POSITION else HINT_POSITION
    ui.box.AnchorPoint = if intro then INTRO_ANCHOR else HINT_ANCHOR
    ui.box.Size = if intro then INTRO_SIZE else HINT_SIZE
end

-- Com o manual aberto a caixa some: ela cobriria o título da página que o jogador precisa ler
local function refreshVisibility()
    ui.box.Visible = active and step > 0 and Overlay.current() ~= Enums.Overlay.Notebook
end

local function reset()
    token += 1
    disconnect(typeConn)
    typeConn = nil
    disconnect(lookConn)
    lookConn = nil
    step = 0
    lines = {}
    lineIndex = 0
    waitFor = ""
    typing = false
    advanced = false
    ui.intro.Visible = false
    ui.box.Visible = false
    ui.gui.Enabled = false
end

local function onStep(payload: Types.TutorialStepPayload)
    if not active then
        return
    end
    token += 1
    local mine = token
    disconnect(lookConn)
    lookConn = nil
    step = payload.step
    lines = payload.lines
    waitFor = payload.waitFor
    advanced = false
    ui.gui.Enabled = true
    ui.text.Text = ""
    if step == 1 then
        -- Abertura (3.12, passo 1): a figura aparece devagar e só então começa a falar
        setLayout(true)
        refreshVisibility()
        local seconds = GameConfig.Tutorial.figureFadeSeconds
        fadeInFigure(seconds)
        task.delay(seconds, function()
            if mine == token then
                showLine(1)
            end
        end)
    else
        setLayout(false)
        refreshVisibility()
        showLine(1)
    end
    if waitFor == W.Look then
        startLookTracking()
    end
end

function TutorialController.init()
    ui.box.Activated:Connect(onBoxActivated)
    Overlay.changed:Connect(refreshVisibility)
    NotebookController.pageShown:Connect(function(page: number)
        if active and waitFor == W.NotebookPage2 and page == 2 then
            advance()
        end
    end)
    Remotes.get(Enums.Remote.TutorialStep).OnClientEvent:Connect(onStep)
    Remotes.get(Enums.Remote.NightStarted).OnClientEvent:Connect(function(payload: Types.NightStartedPayload)
        reset()
        active = payload.night == Enums.Night.Tutorial
    end)
    Remotes.get(Enums.Remote.NightPhase).OnClientEvent:Connect(function(payload: Types.NightPhasePayload)
        if payload.phase == Enums.Phase.Won or payload.phase == Enums.Phase.Lost then
            active = false
            reset()
        end
    end)
end

return TutorialController
