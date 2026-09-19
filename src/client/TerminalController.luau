--!strict
-- TerminalController: o terminal do GEOMETRY OS (PLANEJAMENTO 3.6, 5.8, B.1, B.2).
-- Envia o texto digitado; o servidor valida, executa e devolve TerminalEcho (5.9). O cliente só imprime,
-- desenha a paleta de comandos e o painel do puzzle. Abre com T, clique no monitor ou botão TERMINAL.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Commands = require(Shared:WaitForChild("Commands"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))
local Types = require(Shared:WaitForChild("Types"))
local UiKit = require(script.Parent.ui.UiKit)
local TerminalGui = require(script.Parent.ui.TerminalGui)
local AudioController = require(script.Parent.AudioController)
local InputController = require(script.Parent.InputController)
local Overlay = require(script.Parent.Overlay)
local HudController = require(script.Parent.HudController)

-- Apresentação
local MAX_LINES = 200
local TEXT_SIZE_RATIO = 0.03 -- da altura da tela
local TEXT_SIZE_MIN = 14
local TEXT_SIZE_MAX = 24
local PALETTE_PADDING_PX = 12
local GATE_ATTRIBUTE = "Gate"

local TerminalController = {}

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local ui = TerminalGui.build(playerGui)

local nightActive = false
local running = false
local blackout = false
local batteryRemaining: number? = nil
local open = false
local booted = false -- as linhas de boot aparecem na primeira abertura da noite (3.6)
local lineOrder = 0
local lines: { TextLabel } = {}
local palette: { string } = {}
local paletteIndex = 0 -- Tab cicla pela paleta
local puzzleToken = 0
local settingText = false -- mudança de texto feita pelo código: sem som de tecla
local minigameActive = false -- 3.8.3 / 4.7: o minigame tem prioridade sobre o prompt
local minigameDeadline = 0
local minigameConn: RBXScriptConnection? = nil

local function textSize(): number
    local camera = Workspace.CurrentCamera
    local height = if camera then camera.ViewportSize.Y else 0
    return math.clamp(math.floor(height * TEXT_SIZE_RATIO), TEXT_SIZE_MIN, TEXT_SIZE_MAX)
end

local function kindColor(kind: Types.EchoKind): Color3
    local C = UiKit.Color
    if kind == Enums.EchoKind.Ok then
        return C.ok
    elseif kind == Enums.EchoKind.Err then
        return C.danger
    elseif kind == Enums.EchoKind.Echo then
        return C.dim
    end
    return C.text
end

local function scrollToBottom()
    -- o AutomaticCanvasSize só recalcula no próximo frame
    task.defer(function()
        ui.output.CanvasPosition = Vector2.new(0, ui.output.AbsoluteCanvasSize.Y)
    end)
end

local function clearLines()
    for _, label in lines do
        label:Destroy()
    end
    table.clear(lines)
end

local function appendLine(text: string, kind: Types.EchoKind)
    lineOrder += 1
    local label = Instance.new("TextLabel")
    label.Name = "Line"
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.Font = UiKit.Font
    label.TextSize = textSize()
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = kindColor(kind)
    label.Text = text
    label.LayoutOrder = lineOrder
    label.Parent = ui.output
    table.insert(lines, label)
    if #lines > MAX_LINES then
        local oldest = table.remove(lines, 1)
        if oldest then
            oldest:Destroy()
        end
    end
    scrollToBottom()
end

local function setInputText(text: string)
    settingText = true
    ui.input.Text = text
    ui.input.CursorPosition = #text + 1
    settingText = false
end

local function focusInput()
    if InputController.isTouchDevice() then
        return -- no celular o teclado virtual cobriria a paleta; o jogador toca no campo se quiser digitar
    end
    task.spawn(function()
        -- espera um frame: capturar o foco no mesmo frame da tecla T faria o "t" ser digitado
        RunService.Heartbeat:Wait()
        if open and not minigameActive then
            ui.input:CaptureFocus()
        end
    end)
end

-- Terminal roda em "running" e, no blackout, enquanto a bateria do tablet durar (3.9)
local function canOpen(): boolean
    if not nightActive then
        return false
    end
    if blackout then
        return (batteryRemaining or 0) > 0
    end
    return running
end

local function setOpenLocal(value: boolean, silent: boolean)
    if open == value then
        return
    end
    open = value
    ui.gui.Enabled = value
    Overlay.set(Enums.Overlay.Terminal, value)
    if value then
        if not silent then
            AudioController.play(Enums.Cue.TerminalOpen)
        end
        if not booted then
            booted = true
            appendLine(Strings.Terminal.boot1, Enums.EchoKind.Ok)
            appendLine(Strings.Terminal.boot2, Enums.EchoKind.Info)
        end
        focusInput()
    else
        ui.input:ReleaseFocus()
    end
end

local function requestOpen(value: boolean)
    if value == open or (value and not canOpen()) then
        return
    end
    setOpenLocal(value, false)
    Remotes.get(Enums.Remote.SetTerminalOpen):FireServer({ open = value } :: Types.SetTerminalOpenPayload)
end

local function submit()
    if minigameActive then
        return -- prompt bloqueado até resolver a anomalia
    end
    local text = Commands.normalize(ui.input.Text)
    setInputText("")
    paletteIndex = 0
    if text == "" or not open then
        return
    end
    Remotes.get(Enums.Remote.TerminalCommand):FireServer({ text = text } :: Types.TerminalCommandPayload)
end

local function fillInput(command: string)
    if minigameActive then
        return
    end
    setInputText(command)
    focusInput()
end

local function rebuildPalette(commands: { string })
    palette = commands
    paletteIndex = 0
    for _, child in ui.palette:GetChildren() do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    local size = textSize()
    for i, command in commands do
        local button = UiKit.button({
            name = command,
            parent = ui.palette,
            position = UDim2.fromScale(0, 0),
            size = UDim2.fromScale(0, 1),
            bg = UiKit.Color.panel,
            border = true,
            text = command,
            color = UiKit.Color.ok,
            scaled = false,
        })
        button.AutomaticSize = Enum.AutomaticSize.X
        button.TextSize = size
        button.LayoutOrder = i
        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, PALETTE_PADDING_PX)
        padding.PaddingRight = UDim.new(0, PALETTE_PADDING_PX)
        padding.Parent = button
        button.Activated:Connect(function()
            fillInput(command)
        end)
    end
end

-- Tab (3.6): completa com o primeiro comando da paleta que começa com o que foi digitado;
-- Tab de novo, sem mexer no texto, passa para o próximo
local function autocomplete()
    if not open or #palette == 0 then
        return
    end
    local typed = Commands.normalize((string.gsub(ui.input.Text, "\t", "")))
    local start = if paletteIndex > 0 and palette[paletteIndex] == typed then paletteIndex else 0
    for offset = 1, #palette do
        local index = (start + offset - 1) % #palette + 1
        local command = palette[index]
        if start > 0 or string.sub(command, 1, #typed) == typed then
            paletteIndex = index
            fillInput(command)
            return
        end
    end
end

local function onEcho(payload: Types.TerminalEchoPayload)
    if payload.kind == Enums.EchoKind.Clear then
        clearLines()
        return
    end
    appendLine(payload.text, payload.kind)
    if payload.kind == Enums.EchoKind.Ok then
        AudioController.play(Enums.Cue.TerminalOk)
    elseif payload.kind == Enums.EchoKind.Err then
        AudioController.play(Enums.Cue.TerminalErr)
    end
end

local function setGateButtonsEnabled(enabled: boolean)
    for _, button in ui.puzzle.buttons do
        UiKit.setEnabled(button, enabled)
    end
end

local function hidePuzzle()
    puzzleToken += 1
    ui.puzzle.frame.Visible = false
end

-- B.2: tabela-verdade à esquerda, seis portas à direita. A resposta certa nunca chega ao cliente (5.9).
local function onPuzzleStart(payload: Types.PuzzleStartPayload)
    puzzleToken += 1
    local view = ui.puzzle
    view.rows[1].Text = Strings.Puzzle.header
    for i, row in payload.truthTable do
        local label = view.rows[i + 1]
        if label then
            label.Text = string.format(Strings.Puzzle.row, row[1], row[2], row[3])
        end
    end
    for i, button in view.buttons do
        local gate = payload.options[i]
        button.Visible = gate ~= nil
        button.Text = if gate then string.format(Strings.Puzzle.option, gate) else ""
        button:SetAttribute(GATE_ATTRIBUTE, gate)
    end
    setGateButtonsEnabled(true)
    view.feedback.Text = ""
    view.frame.Visible = true
end

local function onPuzzleResult(payload: Types.PuzzleResultPayload)
    local view = ui.puzzle
    local P = Strings.Puzzle
    if payload.correct then
        view.feedback.Text = string.format(P.correct, payload.gate)
        view.feedback.TextColor3 = UiKit.Color.ok
        AudioController.play(Enums.Cue.PuzzleOk)
        puzzleToken += 1
        local token = puzzleToken
        task.delay(GameConfig.Puzzle.closeAfterCorrectSeconds, function()
            if token == puzzleToken then
                view.frame.Visible = false
            end
        end)
    else
        view.feedback.Text = if payload.penalty > 0
            then string.format(P.wrong, payload.gate, payload.penalty)
            else string.format(P.wrongNoPenalty, payload.gate)
        view.feedback.TextColor3 = UiKit.Color.danger
        AudioController.play(Enums.Cue.PuzzleErr)
        -- os botões ficam desabilitados até a próxima tabela (PuzzleStart)
    end
end

-- 4.7: com o minigame na tela, o prompt aparece cinza e bloqueado
local function setPromptBlocked(blocked: boolean)
    if blocked then
        setInputText("")
        ui.input:ReleaseFocus()
    end
    ui.input.TextEditable = not blocked
    ui.input.PlaceholderText = if blocked then Strings.Minigame.blocked else ""
    ui.input.PlaceholderColor3 = UiKit.Color.dim
    UiKit.setEnabled(ui.send, not blocked)
end

local function stopMinigameTimer()
    local connection = minigameConn
    if connection then
        connection:Disconnect()
        minigameConn = nil
    end
end

local function hideMinigame()
    minigameActive = false
    stopMinigameTimer()
    ui.minigame.frame.Visible = false
    setPromptBlocked(false)
end

local function setWordButtonsEnabled(enabled: boolean)
    for _, button in ui.minigame.buttons do
        UiKit.setEnabled(button, enabled)
    end
end

-- 3.8.3: 9 palavras, uma infectada. A contagem aqui só mostra o tempo; quem encerra é o servidor.
local function onMinigameStart(payload: Types.MinigameStartPayload)
    minigameActive = true
    hidePuzzle()
    local view = ui.minigame
    for i, button in view.buttons do
        local word = payload.words[i]
        button.Visible = word ~= nil
        button.Text = word or ""
    end
    setWordButtonsEnabled(true)
    setPromptBlocked(true)
    view.frame.Visible = true
    stopMinigameTimer()
    -- Em Studio o servidor pode estar acelerado (Debug.timeScale); a contagem acompanha
    local scale = if RunService:IsStudio() then GameConfig.Debug.timeScale else 1
    minigameDeadline = os.clock() + payload.seconds / scale
    minigameConn = RunService.RenderStepped:Connect(function()
        local remaining = math.max(0, minigameDeadline - os.clock()) * scale
        view.timer.Text = string.format(Strings.Minigame.timer, math.ceil(remaining))
    end)
end

-- 3.8.3: acertando ou errando, o terminal fecha. Com câmera destruída, o HUD já avisa qual (CameraDead).
local function onMinigameResult(payload: Types.MinigameResultPayload)
    hideMinigame()
    if payload.success or payload.cameraKilled == nil then
        local M = Strings.Minigame
        HudController.showMessage(if payload.success then M.ok elseif payload.timeout then M.timeout else M.err)
    end
    requestOpen(false)
end

local function onNightStarted()
    nightActive = true
    running = false
    blackout = false
    batteryRemaining = nil
    booted = false
    clearLines()
    hidePuzzle()
    hideMinigame()
    setInputText("")
    setOpenLocal(false, true)
end

local function onNightPhase(payload: Types.NightPhasePayload)
    running = payload.phase == Enums.Phase.Running
    blackout = payload.phase == Enums.Phase.Blackout
    if payload.phase == Enums.Phase.Won or payload.phase == Enums.Phase.Lost then
        nightActive = false
        hidePuzzle()
        hideMinigame()
        setOpenLocal(false, true)
    end
end

function TerminalController.init()
    InputController.terminalToggle:Connect(function()
        requestOpen(not open)
    end)
    InputController.interact:Connect(function(target)
        if target == Enums.Interact.Terminal then
            requestOpen(true)
        end
    end)
    InputController.autocomplete:Connect(autocomplete)
    Overlay.closeRequested:Connect(function(name: string)
        if name == Enums.Overlay.Terminal then
            requestOpen(false)
        end
    end)

    ui.input.FocusLost:Connect(function(enterPressed: boolean)
        if enterPressed then
            submit()
            focusInput() -- no PC continua digitando sem clicar de novo
        end
    end)
    ui.input:GetPropertyChangedSignal("Text"):Connect(function()
        if settingText then
            return
        end
        local text = ui.input.Text
        local maxLength = GameConfig.Terminal.maxInputLength
        if #text > maxLength then
            setInputText(string.sub(text, 1, maxLength)) -- o servidor ignora acima disso (5.6)
            return
        end
        AudioController.play(Enums.Cue.TerminalKey)
    end)
    ui.send.Activated:Connect(submit)
    ui.close.Activated:Connect(function()
        requestOpen(false)
    end)

    for _, button in ui.puzzle.buttons do
        button.Activated:Connect(function()
            local gate = button:GetAttribute(GATE_ATTRIBUTE)
            if typeof(gate) ~= "string" or not UiKit.isEnabled(button) then
                return
            end
            setGateButtonsEnabled(false)
            Remotes.get(Enums.Remote.PuzzlePick):FireServer({ gate = gate } :: Types.PuzzlePickPayload)
        end)
    end
    for index, button in ui.minigame.buttons do
        button.Activated:Connect(function()
            if not minigameActive or not UiKit.isEnabled(button) then
                return
            end
            setWordButtonsEnabled(false)
            Remotes.get(Enums.Remote.MinigamePick):FireServer({ index = index } :: Types.MinigamePickPayload)
        end)
    end
    ui.puzzle.cancel.Activated:Connect(function()
        hidePuzzle()
        Remotes.get(Enums.Remote.PuzzleCancel):FireServer({})
    end)

    Remotes.get(Enums.Remote.TerminalEcho).OnClientEvent:Connect(onEcho)
    Remotes.get(Enums.Remote.TerminalPalette).OnClientEvent:Connect(function(payload: Types.TerminalPalettePayload)
        rebuildPalette(payload.commands)
    end)
    Remotes.get(Enums.Remote.PuzzleStart).OnClientEvent:Connect(onPuzzleStart)
    Remotes.get(Enums.Remote.PuzzleResult).OnClientEvent:Connect(onPuzzleResult)
    Remotes.get(Enums.Remote.PuzzleClosed).OnClientEvent:Connect(hidePuzzle)
    Remotes.get(Enums.Remote.MinigameStart).OnClientEvent:Connect(onMinigameStart)
    Remotes.get(Enums.Remote.MinigameResult).OnClientEvent:Connect(onMinigameResult)
    Remotes.get(Enums.Remote.TabletState).OnClientEvent:Connect(function(payload: Types.TabletStatePayload)
        batteryRemaining = payload.batteryRemaining
    end)
    Remotes.get(Enums.Remote.TabletBatteryDead).OnClientEvent:Connect(function()
        batteryRemaining = 0
        hidePuzzle()
        setOpenLocal(false, false) -- o servidor já fechou o terminal junto com o tablet (3.9)
    end)
    Remotes.get(Enums.Remote.NightStarted).OnClientEvent:Connect(onNightStarted)
    Remotes.get(Enums.Remote.NightPhase).OnClientEvent:Connect(onNightPhase)
end

return TerminalController
