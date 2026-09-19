--!strict
-- CustomNightGui: painel da Custom Night (PLANEJAMENTO 3.13, Fase 7): um nível de 0 a 20 por IA.
-- Botões − e + em vez de sliders: alvos grandes funcionam melhor no celular (5.11).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local UiKit = require(script.Parent.UiKit)

export type Row = {
    value: TextLabel,
    decrease: TextButton,
    increase: TextButton,
}

export type CustomNight = {
    gui: ScreenGui,
    rows: { [string]: Row }, -- Enums.Enemy → linha
    maxAll: TextButton,
    start: TextButton,
    back: TextButton,
}

-- Ordem das linhas no painel
local ENEMIES = { "square", "triangle", "circle", "hexagon" }
-- Painel de 0.92 da altura da tela: linhas de 0.14 dele ≈ 48 px no iPhone SE (5.11)
local ROW_TOP = 0.13
local ROW_STEP = 0.165
local ROW_HEIGHT = 0.14
local DIM_TRANSPARENCY = 0.3

local CustomNightGui = {}

CustomNightGui.enemies = ENEMIES

local function smallButton(parent: Instance, name: string, x: number, y: number, text: string): TextButton
    return UiKit.button({
        name = name,
        parent = parent,
        position = UDim2.fromScale(x, y),
        size = UDim2.fromScale(0.14, ROW_HEIGHT),
        bg = UiKit.Color.panel,
        border = true,
        text = text,
        color = UiKit.Color.ok,
        maxTextSize = 34,
    })
end

local function wideButton(parent: Instance, name: string, x: number, text: string): TextButton
    return UiKit.button({
        name = name,
        parent = parent,
        position = UDim2.fromScale(x, 0.82),
        size = UDim2.fromScale(0.29, ROW_HEIGHT),
        bg = UiKit.Color.panel,
        border = true,
        text = text,
        color = UiKit.Color.ok,
        maxTextSize = 26,
    })
end

function CustomNightGui.build(parent: Instance): CustomNight
    local C = UiKit.Color
    local gui = UiKit.screenGui("CustomNightGui", 24, true)

    local dim = UiKit.frame({
        name = "Dim",
        parent = gui,
        position = UDim2.fromScale(0, 0),
        size = UDim2.fromScale(1, 1),
        bg = C.bg,
    })
    dim.BackgroundTransparency = DIM_TRANSPARENCY
    dim.Active = true

    local panel = UiKit.frame({
        name = "Panel",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.5),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.8, 0.92),
        bg = C.panel,
        border = true,
    })
    UiKit.label({
        name = "Title",
        parent = panel,
        position = UDim2.fromScale(0.5, 0.06),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.9, 0.09),
        text = Strings.CustomNight.title,
        color = C.ok,
        maxTextSize = 34,
    })

    local rows: { [string]: Row } = {}
    for i, enemy in ENEMIES do
        local y = ROW_TOP + (i - 1) * ROW_STEP
        UiKit.label({
            name = `{enemy}Name`,
            parent = panel,
            position = UDim2.fromScale(0.04, y),
            size = UDim2.fromScale(0.4, ROW_HEIGHT),
            text = Strings.EnemyName[enemy] or enemy,
            xAlign = Enum.TextXAlignment.Left,
            maxTextSize = 24,
        })
        local decrease = smallButton(panel, `{enemy}Decrease`, 0.46, y, Strings.CustomNight.decrease)
        local value = UiKit.label({
            name = `{enemy}Value`,
            parent = panel,
            position = UDim2.fromScale(0.62, y),
            size = UDim2.fromScale(0.14, ROW_HEIGHT),
            color = C.warn,
            maxTextSize = 34,
        })
        local increase = smallButton(panel, `{enemy}Increase`, 0.78, y, Strings.CustomNight.increase)
        rows[enemy] = { value = value, decrease = decrease, increase = increase }
    end

    local maxAll = wideButton(panel, "MaxAll", 0.04, Strings.CustomNight.maxAll)
    local back = wideButton(panel, "Back", 0.355, Strings.CustomNight.back)
    local start = wideButton(panel, "Start", 0.67, Strings.CustomNight.start)

    gui.Parent = parent
    return { gui = gui, rows = rows, maxAll = maxAll, start = start, back = back }
end

return CustomNightGui
