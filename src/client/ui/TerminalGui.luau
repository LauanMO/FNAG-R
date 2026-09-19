--!strict
-- TerminalGui: o terminal do GEOMETRY OS (PLANEJAMENTO 3.6, 5.12, B.1, B.2). Tela cheia, estética de CLI.
-- Saída rolável, paleta de comandos, linha de input com prompt e ENVIAR, e o painel do puzzle por cima.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local UiKit = require(script.Parent.UiKit)

export type Puzzle = {
    frame: Frame,
    rows: { TextLabel }, -- cabeçalho + 4 linhas da tabela-verdade
    buttons: { TextButton }, -- 6 portas, na ordem das opções recebidas
    feedback: TextLabel,
    cancel: TextButton,
}

export type Terminal = {
    gui: ScreenGui,
    output: ScrollingFrame,
    palette: ScrollingFrame,
    input: TextBox,
    send: TextButton,
    close: TextButton,
    puzzle: Puzzle,
}

-- Apresentação. Alturas de 0.13 da tela dão ~49 px no iPhone SE (alvo ≥ 48 px, 5.11).
local ROW_HEIGHT = 0.13
local SCROLLBAR_PX = 6
local GATE_COUNT = 6
local TABLE_ROWS = 5 -- cabeçalho + 4

local TerminalGui = {}

local function buildPuzzle(parent: Instance): Puzzle
    local C = UiKit.Color
    local frame = UiKit.frame({
        name = "Puzzle",
        parent = parent,
        position = UDim2.fromScale(0.02, 0.03),
        size = UDim2.fromScale(0.96, 0.76),
        bg = C.panel,
        border = true,
        visible = false,
        zIndex = 5,
    })
    frame.Active = true
    UiKit.label({
        name = "Title",
        parent = frame,
        position = UDim2.fromScale(0.02, 0.02),
        size = UDim2.fromScale(0.74, 0.11),
        text = Strings.Puzzle.title,
        color = C.hacker,
        xAlign = Enum.TextXAlignment.Left,
        maxTextSize = 24,
    })
    local cancel = UiKit.button({
        name = "Cancel",
        parent = frame,
        position = UDim2.fromScale(0.98, 0.02),
        anchor = Vector2.new(1, 0),
        size = UDim2.fromScale(0.2, 0.17),
        bg = C.panel,
        border = true,
        text = Strings.Puzzle.cancel,
        color = C.danger,
        maxTextSize = 22,
    })
    UiKit.label({
        name = "Instruction",
        parent = frame,
        position = UDim2.fromScale(0.02, 0.2),
        size = UDim2.fromScale(0.96, 0.07),
        text = Strings.Puzzle.instruction,
        xAlign = Enum.TextXAlignment.Left,
        maxTextSize = 20,
    })
    local rows: { TextLabel } = {}
    for i = 1, TABLE_ROWS do
        table.insert(
            rows,
            UiKit.label({
                name = `Row{i}`,
                parent = frame,
                position = UDim2.fromScale(0.04, 0.3 + (i - 1) * 0.1),
                size = UDim2.fromScale(0.4, 0.08),
                color = if i == 1 then C.hacker else C.text,
                xAlign = Enum.TextXAlignment.Left,
                maxTextSize = 24,
            })
        )
    end
    -- Seis portas em 3 linhas × 2 colunas, à direita da tabela; 0.17 × 285 px ≈ 48 px de altura
    local buttons: { TextButton } = {}
    for i = 1, GATE_COUNT do
        local column = (i - 1) % 2
        local row = (i - 1) // 2
        table.insert(
            buttons,
            UiKit.button({
                name = `Gate{i}`,
                parent = frame,
                position = UDim2.fromScale(0.5 + column * 0.245, 0.3 + row * 0.2),
                size = UDim2.fromScale(0.23, 0.17),
                bg = C.panel,
                border = true,
                color = C.ok,
                maxTextSize = 22,
            })
        )
    end
    local feedback = UiKit.label({
        name = "Feedback",
        parent = frame,
        position = UDim2.fromScale(0.02, 0.9),
        size = UDim2.fromScale(0.96, 0.08),
        xAlign = Enum.TextXAlignment.Left,
        maxTextSize = 20,
    })
    return { frame = frame, rows = rows, buttons = buttons, feedback = feedback, cancel = cancel }
end

function TerminalGui.build(parent: Instance): Terminal
    local C = UiKit.Color
    local gui = UiKit.screenGui("TerminalGui", 16, true)

    -- Active: o terminal engole cliques e toques; nada passa para os botões 3D nem para o HUD embaixo
    local background = UiKit.frame({
        name = "Background",
        parent = gui,
        position = UDim2.fromScale(0, 0),
        size = UDim2.fromScale(1, 1),
        bg = C.bg,
    })
    background.Active = true

    local close = UiKit.button({
        name = "Close",
        parent = gui,
        position = UDim2.fromScale(0.985, 0.02),
        anchor = Vector2.new(1, 0),
        size = UDim2.fromScale(0.16, 0.14),
        bg = C.panel,
        border = true,
        text = Strings.Terminal.close,
        color = C.ok,
        maxTextSize = 22,
    })

    local output = Instance.new("ScrollingFrame")
    output.Name = "Output"
    output.Position = UDim2.fromScale(0.02, 0.03)
    output.Size = UDim2.fromScale(0.8, 0.6)
    output.BackgroundTransparency = 1
    output.BorderSizePixel = 0
    output.CanvasSize = UDim2.new()
    output.AutomaticCanvasSize = Enum.AutomaticSize.Y
    output.ScrollingDirection = Enum.ScrollingDirection.Y
    output.ScrollBarThickness = SCROLLBAR_PX
    output.ScrollBarImageColor3 = C.border
    output.Parent = gui
    local outputLayout = Instance.new("UIListLayout")
    outputLayout.SortOrder = Enum.SortOrder.LayoutOrder
    outputLayout.Parent = output

    -- Paleta (3.6): os comandos disponíveis agora; tocar preenche o input, ENVIAR executa
    local palette = Instance.new("ScrollingFrame")
    palette.Name = "Palette"
    palette.Position = UDim2.fromScale(0.02, 0.655)
    palette.Size = UDim2.fromScale(0.96, ROW_HEIGHT)
    palette.BackgroundTransparency = 1
    palette.BorderSizePixel = 0
    palette.CanvasSize = UDim2.new()
    palette.AutomaticCanvasSize = Enum.AutomaticSize.X
    palette.ScrollingDirection = Enum.ScrollingDirection.X
    palette.ScrollBarThickness = 0
    palette.Parent = gui
    local paletteLayout = Instance.new("UIListLayout")
    paletteLayout.FillDirection = Enum.FillDirection.Horizontal
    paletteLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    paletteLayout.SortOrder = Enum.SortOrder.LayoutOrder
    paletteLayout.Padding = UDim.new(0.01, 0)
    paletteLayout.Parent = palette

    UiKit.label({
        name = "Prompt",
        parent = gui,
        position = UDim2.fromScale(0.02, 0.82),
        size = UDim2.fromScale(0.27, ROW_HEIGHT),
        text = Strings.Terminal.prompt,
        color = C.ok,
        xAlign = Enum.TextXAlignment.Left,
        maxTextSize = 26,
    })
    local input = Instance.new("TextBox")
    input.Name = "Input"
    input.Position = UDim2.fromScale(0.3, 0.82)
    input.Size = UDim2.fromScale(0.5, ROW_HEIGHT)
    input.BackgroundColor3 = C.panel
    input.BorderSizePixel = 1
    input.BorderColor3 = C.border
    input.Font = UiKit.Font
    input.Text = ""
    input.PlaceholderText = ""
    input.TextColor3 = C.text
    input.TextScaled = true
    input.TextXAlignment = Enum.TextXAlignment.Left
    input.ClearTextOnFocus = false
    input.Parent = gui
    local inputSize = Instance.new("UITextSizeConstraint")
    inputSize.MaxTextSize = 26
    inputSize.Parent = input

    local send = UiKit.button({
        name = "Send",
        parent = gui,
        position = UDim2.fromScale(0.82, 0.82),
        size = UDim2.fromScale(0.16, ROW_HEIGHT),
        bg = C.panel,
        border = true,
        text = Strings.Terminal.send,
        color = C.ok,
        maxTextSize = 24,
    })

    local puzzle = buildPuzzle(gui)

    gui.Parent = parent
    return {
        gui = gui,
        output = output,
        palette = palette,
        input = input,
        send = send,
        close = close,
        puzzle = puzzle,
    }
end

return TerminalGui
