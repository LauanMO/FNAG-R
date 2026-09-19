--!strict
-- NotebookController: o manual de procedimentos na mesa (PLANEJAMENTO 3.7, B.3).
-- Só apresentação: não pausa o jogo, funciona no blackout (é papel) e, aberto, esconde o escritório.
-- Abre com M, clique no caderno, botão MANUAL ou B no gamepad; setas viram a página.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))
local Types = require(Shared:WaitForChild("Types"))
local UiKit = require(script.Parent.ui.UiKit)
local NotebookGui = require(script.Parent.ui.NotebookGui)
local InputController = require(script.Parent.InputController)
local Overlay = require(script.Parent.Overlay)

-- Apresentação
local TEXT_SIZE_RATIO = 0.034 -- da altura da tela
local TEXT_SIZE_MIN = 14
local TEXT_SIZE_MAX = 26

local NotebookController = {}

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local ui = NotebookGui.build(playerGui)

local nightActive = false
local open = false
local page = 1

local function textSize(): number
    local camera = Workspace.CurrentCamera
    local height = if camera then camera.ViewportSize.Y else 0
    return math.clamp(math.floor(height * TEXT_SIZE_RATIO), TEXT_SIZE_MIN, TEXT_SIZE_MAX)
end

local function render()
    local pages = Strings.Manual.pages
    local current = pages[page]
    ui.title.Text = current.title
    for _, child in ui.body:GetChildren() do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    local size = textSize()
    for i, paragraph in current.body do
        local label = Instance.new("TextLabel")
        label.Name = `Paragraph{i}`
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 0)
        label.AutomaticSize = Enum.AutomaticSize.Y
        label.Font = UiKit.Font
        label.TextSize = size
        label.TextWrapped = true
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextColor3 = NotebookGui.Ink
        label.Text = paragraph
        label.LayoutOrder = i
        label.Parent = ui.body
    end
    ui.pageLabel.Text = string.format(Strings.Manual.pageOf, page, #pages)
    UiKit.setEnabled(ui.prevButton, page > 1)
    UiKit.setEnabled(ui.nextButton, page < #pages)
end

local function setOpenLocal(value: boolean)
    if open == value then
        return
    end
    open = value
    ui.gui.Enabled = value
    Overlay.set(Enums.Overlay.Notebook, value)
    if value then
        render()
    end
end

local function turn(direction: number)
    if not open then
        return
    end
    local target = math.clamp(page + direction, 1, #Strings.Manual.pages)
    if target ~= page then
        page = target
        render()
    end
end

function NotebookController.init()
    InputController.notebookToggle:Connect(function()
        if nightActive then
            setOpenLocal(not open)
        end
    end)
    InputController.interact:Connect(function(target)
        if nightActive and target == Enums.Interact.Notebook then
            setOpenLocal(true)
        end
    end)
    InputController.navigate:Connect(turn)
    Overlay.closeRequested:Connect(function(name: string)
        if name == Enums.Overlay.Notebook then
            setOpenLocal(false)
        end
    end)
    ui.prevButton.Activated:Connect(function()
        if UiKit.isEnabled(ui.prevButton) then
            turn(-1)
        end
    end)
    ui.nextButton.Activated:Connect(function()
        if UiKit.isEnabled(ui.nextButton) then
            turn(1)
        end
    end)
    ui.closeButton.Activated:Connect(function()
        setOpenLocal(false)
    end)

    Remotes.get(Enums.Remote.NightStarted).OnClientEvent:Connect(function()
        nightActive = true
        page = 1
        setOpenLocal(false)
    end)
    Remotes.get(Enums.Remote.NightPhase).OnClientEvent:Connect(function(payload: Types.NightPhasePayload)
        if payload.phase == Enums.Phase.Won or payload.phase == Enums.Phase.Lost then
            nightActive = false
            setOpenLocal(false)
        end
    end)
end

return NotebookController
