--!strict
-- NotebookGui: o manual de papel na mesa (PLANEJAMENTO 3.7, 5.12, B.3). Uma página por vez, navegação e n / N.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local UiKit = require(script.Parent.UiKit)

export type Notebook = {
    gui: ScreenGui,
    title: TextLabel,
    body: Frame, -- parágrafos da página (UIListLayout); o NotebookController preenche
    pageLabel: TextLabel,
    prevButton: TextButton,
    nextButton: TextButton,
    closeButton: TextButton,
}

-- Estética de papel (3.7): única exceção ao fundo preto do resto da UI
local PAPER = Color3.fromRGB(226, 218, 196)
local INK = Color3.fromRGB(40, 36, 30)
local STAMP = Color3.fromRGB(150, 40, 40)
local DIM_TRANSPARENCY = 0.35

local NotebookGui = {}

NotebookGui.Ink = INK

function NotebookGui.build(parent: Instance): Notebook
    local C = UiKit.Color
    local gui = UiKit.screenGui("NotebookGui", 17, true)

    -- Active: o manual engole cliques e toques; nada passa para a sala embaixo
    local dim = UiKit.frame({
        name = "Dim",
        parent = gui,
        position = UDim2.fromScale(0, 0),
        size = UDim2.fromScale(1, 1),
        bg = C.bg,
    })
    dim.BackgroundTransparency = DIM_TRANSPARENCY
    dim.Active = true

    local paper = UiKit.frame({
        name = "Paper",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.5),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.86, 0.92),
        bg = PAPER,
        border = true,
    })
    UiKit.label({
        name = "Header",
        parent = paper,
        position = UDim2.fromScale(0.04, 0.03),
        size = UDim2.fromScale(0.7, 0.07),
        text = Strings.Manual.header,
        color = STAMP,
        xAlign = Enum.TextXAlignment.Left,
        maxTextSize = 22,
    })
    -- 0.15 × 0.92 × 375 ≈ 52 px no iPhone SE (≥ 48 px, 5.11)
    local closeButton = UiKit.button({
        name = "Close",
        parent = paper,
        position = UDim2.fromScale(0.97, 0.03),
        anchor = Vector2.new(1, 0),
        size = UDim2.fromScale(0.2, 0.15),
        bg = C.panel,
        border = true,
        text = Strings.Manual.close,
        color = C.ok,
        maxTextSize = 22,
    })
    local title = UiKit.label({
        name = "Title",
        parent = paper,
        position = UDim2.fromScale(0.04, 0.13),
        size = UDim2.fromScale(0.7, 0.08),
        color = INK,
        xAlign = Enum.TextXAlignment.Left,
        maxTextSize = 30,
    })
    local body = UiKit.frame({
        name = "Body",
        parent = paper,
        position = UDim2.fromScale(0.04, 0.24),
        size = UDim2.fromScale(0.92, 0.56),
    })
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0.04, 0)
    layout.Parent = body

    local prevButton = UiKit.button({
        name = "Prev",
        parent = paper,
        position = UDim2.fromScale(0.04, 0.83),
        size = UDim2.fromScale(0.28, 0.14),
        bg = C.panel,
        border = true,
        text = Strings.Manual.prev,
        color = C.ok,
        maxTextSize = 22,
    })
    local pageLabel = UiKit.label({
        name = "Page",
        parent = paper,
        position = UDim2.fromScale(0.5, 0.9),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.3, 0.08),
        color = INK,
        maxTextSize = 24,
    })
    local nextButton = UiKit.button({
        name = "Next",
        parent = paper,
        position = UDim2.fromScale(0.96, 0.83),
        anchor = Vector2.new(1, 0),
        size = UDim2.fromScale(0.28, 0.14),
        bg = C.panel,
        border = true,
        text = Strings.Manual.nextPage,
        color = C.ok,
        maxTextSize = 22,
    })

    gui.Parent = parent
    return {
        gui = gui,
        title = title,
        body = body,
        pageLabel = pageLabel,
        prevButton = prevButton,
        nextButton = nextButton,
        closeButton = closeButton,
    }
end

return NotebookGui
