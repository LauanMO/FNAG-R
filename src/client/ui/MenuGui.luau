--!strict
-- MenuGui: constrói a ScreenGui do menu (PLANEJAMENTO 5.12 / B.8). O fundo é o palco 3D (MenuScene), então a tela
-- é só o título no alto à esquerda, os cinco botões numa fileira embaixo (a ação principal na ponta direita, em
-- destaque), o rodapé e as camadas de estática que o MenuController anima por cima da cena.

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

-- Fileira com 0.13 da altura da tela ≈ 49 px no iPhone SE (alvo ≥ 48 px, 5.11).
-- Na largura da fileira: 5 × 0.188 + 4 × 0.015 = 1.
local ROW_WIDTH = 0.94
local ROW_HEIGHT = 0.13
local ROW_BOTTOM = 0.94
local BUTTON_WIDTH = 0.188
local BUTTON_GAP = 0.015
local BUTTON_TRANSPARENCY = 0.2 -- a cena aparece um pouco através dos botões
local BUTTON_PADDING_X = 0.06
local BUTTON_PADDING_Y = 0.14
-- O título fica abaixo da barra do Roblox (canto superior esquerdo), no lugar de um logo
local LEFT = 0.04
local TITLE_TOP = 0.14
local TITLE_HEIGHT = 0.22
local TITLE_STROKE_TRANSPARENCY = 0.3
local CONTENT_Z = 4 -- acima da estática

local MenuGui = {}

local function menuButton(parent: Instance, name: string, text: string, order: number): TextButton
    local button = UiKit.button({
        name = name,
        parent = parent,
        position = UDim2.fromScale(0, 0),
        size = UDim2.fromScale(BUTTON_WIDTH, 1),
        bg = UiKit.Color.panel,
        border = true,
        text = text,
        color = UiKit.Color.ok,
        maxTextSize = 34,
    })
    button.LayoutOrder = order
    button.BackgroundTransparency = BUTTON_TRANSPARENCY
    button.TextWrapped = true
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(BUTTON_PADDING_X, 0)
    padding.PaddingRight = UDim.new(BUTTON_PADDING_X, 0)
    padding.PaddingTop = UDim.new(BUTTON_PADDING_Y, 0)
    padding.PaddingBottom = UDim.new(BUTTON_PADDING_Y, 0)
    padding.Parent = button
    return button
end

function MenuGui.build(parent: Instance): Menu
    local C = UiKit.Color
    local gui = UiKit.screenGui("MenuGui", 20, true)

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
        position = UDim2.fromScale(LEFT, TITLE_TOP),
        size = UDim2.fromScale(0.42, TITLE_HEIGHT),
        text = Strings.Menu.title,
        color = C.ok,
        xAlign = Enum.TextXAlignment.Left,
        yAlign = Enum.TextYAlignment.Top,
        zIndex = CONTENT_Z,
        maxTextSize = 80,
    })
    title.TextWrapped = true
    -- Contorno escuro: o título lê bem por cima da cena
    local stroke = Instance.new("UIStroke")
    stroke.Color = C.bg
    stroke.Thickness = 2
    stroke.Transparency = TITLE_STROKE_TRANSPARENCY
    stroke.Parent = title

    local saveWarning = UiKit.label({
        name = "SaveWarning",
        parent = gui,
        position = UDim2.fromScale(LEFT, TITLE_TOP + TITLE_HEIGHT + 0.01),
        size = UDim2.fromScale(0.5, 0.035),
        text = Strings.Menu.saveUnavailable,
        color = C.warn,
        xAlign = Enum.TextXAlignment.Left,
        visible = false,
        zIndex = CONTENT_Z,
        maxTextSize = 18,
    })

    local buttons = UiKit.frame({
        name = "Buttons",
        parent = gui,
        position = UDim2.fromScale(0.5, ROW_BOTTOM),
        anchor = Vector2.new(0.5, 1),
        size = UDim2.fromScale(ROW_WIDTH, ROW_HEIGHT),
        zIndex = CONTENT_Z,
    })
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(BUTTON_GAP, 0)
    layout.Parent = buttons

    -- Da esquerda para a direita, como na referência: configurações na ponta esquerda, jogar na direita
    local settings = menuButton(buttons, "Settings", Strings.Menu.settings, 1)
    local customNight = menuButton(buttons, "CustomNight", Strings.Menu.customNight, 2)
    local tutorial = menuButton(buttons, "Tutorial", Strings.Menu.tutorial, 3)
    local newGame = menuButton(buttons, "NewGame", Strings.Menu.newGame, 4)
    local continueBtn = menuButton(buttons, "Continue", Strings.Menu.continueGame, 5)

    local footer = UiKit.label({
        name = "Footer",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.99),
        anchor = Vector2.new(0.5, 1),
        size = UDim2.fromScale(0.6, 0.03),
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
