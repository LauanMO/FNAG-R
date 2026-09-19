--!strict
-- MenuGui: constrói a ScreenGui do menu (PLANEJAMENTO 5.12 / B.8): título, cinco botões, rodapé e as camadas
-- de estática que o MenuController anima.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local UiKit = require(script.Parent.UiKit)

export type Menu = {
    gui: ScreenGui,
    static: Frame,
    scanline: Frame,
    title: TextLabel,
    newGame: TextButton,
    continueBtn: TextButton,
    tutorial: TextButton,
    customNight: TextButton,
    settings: TextButton,
    footer: TextLabel,
    saveWarning: TextLabel,
}

-- Cinco botões empilhados num container de 0.70 da altura da tela (5.11): 5 × 0.186 + 4 × 0.0175 = 1.
-- Cada botão fica com 0.13 da tela ≈ 49 px no iPhone SE (alvo ≥ 48 px).
local BUTTON_HEIGHT = 0.186
local BUTTON_GAP = 0.0175
local CONTENT_Z = 4 -- acima da estática

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
        zIndex = 1,
    })
    -- Estática (5.12): o MenuController troca cor e transparência a cada frame e move a linha de varredura
    local static = UiKit.frame({
        name = "Static",
        parent = gui,
        position = UDim2.fromScale(0, 0),
        size = UDim2.fromScale(1, 1),
        bg = C.dim,
        zIndex = 2,
    })
    static.BackgroundTransparency = 1
    local scanline = UiKit.frame({
        name = "Scanline",
        parent = gui,
        position = UDim2.fromScale(0, 0),
        size = UDim2.fromScale(1, 0.008),
        bg = C.ok,
        zIndex = 3,
    })
    scanline.BackgroundTransparency = 0.85

    local title = UiKit.label({
        name = "Title",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.1),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.9, 0.12),
        text = Strings.Menu.title,
        color = C.ok,
        zIndex = CONTENT_Z,
        maxTextSize = 64,
    })

    local buttons = UiKit.frame({
        name = "Buttons",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.54),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.5, 0.7),
        zIndex = CONTENT_Z,
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
        zIndex = CONTENT_Z,
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
        zIndex = CONTENT_Z,
        maxTextSize = 16,
    })

    gui.Parent = parent
    return {
        gui = gui,
        static = static,
        scanline = scanline,
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
