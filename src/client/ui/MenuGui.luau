--!strict
-- MenuGui: constrói a ScreenGui do menu (PLANEJAMENTO 5.12 / B.8). Glitch do título e estática entram na Fase 6.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local UiKit = require(script.Parent.UiKit)

export type Menu = {
    gui: ScreenGui,
    title: TextLabel,
    newGame: TextButton,
    continueBtn: TextButton,
    tutorial: TextButton,
    customNight: TextButton,
    settings: TextButton,
    footer: TextLabel,
    saveWarning: TextLabel,
}

-- Cinco botões empilhados: 5 × 0.164 + 4 × 0.03 de espaçamento = 0.94 do container.
-- O container ocupa 0.66 da tela: ~46 px por botão no iPhone SE.
-- Alvo de 5.11 é ≥ 48 px; revisar na Fase 6 junto com as outras ScreenGuis.
local BUTTON_HEIGHT = 0.164
local BUTTON_GAP = 0.03

local MenuGui = {}

local function menuButton(parent: Instance, name: string, text: string, order: number): TextButton
    local button = UiKit.button({
        name = name,
        parent = parent,
        position = UDim2.fromScale(0, 0),
        size = UDim2.fromScale(1, BUTTON_HEIGHT),
        bg = UiKit.Color.panel,
        border = true,
        text = text,
        color = UiKit.Color.ok,
        maxTextSize = 30,
    })
    button.LayoutOrder = order
    return button
end

function MenuGui.build(parent: Instance): Menu
    local C = UiKit.Color
    local gui = UiKit.screenGui("MenuGui", 20, true)

    UiKit.frame({
        name = "Background",
        parent = gui,
        position = UDim2.fromScale(0, 0),
        size = UDim2.fromScale(1, 1),
        bg = C.bg,
    })

    local title = UiKit.label({
        name = "Title",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.11),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.9, 0.12),
        text = Strings.Menu.title,
        color = C.ok,
        maxTextSize = 64,
    })

    local buttons = UiKit.frame({
        name = "Buttons",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.56),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.5, 0.66),
    })
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(BUTTON_GAP, 0)
    layout.Parent = buttons

    local newGame = menuButton(buttons, "NewGame", Strings.Menu.newGame, 1)
    local continueBtn = menuButton(buttons, "Continue", Strings.Menu.continueGame, 2)
    local tutorial = menuButton(buttons, "Tutorial", Strings.Menu.tutorial, 3)
    local customNight = menuButton(buttons, "CustomNight", Strings.Menu.customNight, 4)
    local settings = menuButton(buttons, "Settings", Strings.Menu.settings, 5)

    local saveWarning = UiKit.label({
        name = "SaveWarning",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.915),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.9, 0.035),
        text = Strings.Menu.saveUnavailable,
        color = C.warn,
        visible = false,
        maxTextSize = 18,
    })
    local footer = UiKit.label({
        name = "Footer",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.965),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.8, 0.035),
        text = Strings.Menu.footer,
        color = C.dim,
        maxTextSize = 16,
    })

    gui.Parent = parent
    return {
        gui = gui,
        title = title,
        newGame = newGame,
        continueBtn = continueBtn,
        tutorial = tutorial,
        customNight = customNight,
        settings = settings,
        footer = footer,
        saveWarning = saveWarning,
    }
end

return MenuGui
