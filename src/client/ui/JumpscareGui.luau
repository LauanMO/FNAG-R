--!strict
-- JumpscareGui: overlays do jumpscare e tela de game over (PLANEJAMENTO 3.8, 3.10, 5.12, B.7).
-- Estática (todos), grade ciana e "FIREWALL BREACHED" (Hexágono), e o painel de falha crítica.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local UiKit = require(script.Parent.UiKit)

export type Jumpscare = {
    gui: ScreenGui,
    hexGrid: Frame, -- Hexágono: a tela é tomada pelo ciano a partir do centro
    static: Frame,
    breached: TextLabel,
    panel: Frame,
    title: TextLabel,
    anomaly: TextLabel,
    retry: TextButton,
    menu: TextButton,
}

-- Botões ≥ 48 px no iPhone SE (0.14 × 375 ≈ 52 px), ver 5.11
local BUTTON_SIZE = UDim2.fromScale(0.4, 0.14)

local JumpscareGui = {}

function JumpscareGui.build(parent: Instance): Jumpscare
    local C = UiKit.Color
    local gui = UiKit.screenGui("JumpscareGui", 40, true)

    -- Hexágono (3.8.4): o JumpscareController cresce este quadro do centro até cobrir a tela
    local hexGrid = UiKit.frame({
        name = "HexGrid",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.5),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0, 0),
        bg = C.hacker,
        visible = false,
        zIndex = 1,
    })

    -- Estática: o JumpscareController troca a cor e a transparência a cada frame
    local static = UiKit.frame({
        name = "Static",
        parent = gui,
        position = UDim2.fromScale(0, 0),
        size = UDim2.fromScale(1, 1),
        bg = C.dim,
        visible = false,
        zIndex = 2,
    })

    local breached = UiKit.label({
        name = "Breached",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.5),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.9, 0.14),
        text = Strings.EndScreens.firewallBreached,
        color = C.hacker,
        visible = false,
        zIndex = 3,
        maxTextSize = 72,
    })

    local panel = UiKit.frame({
        name = "GameOver",
        parent = gui,
        position = UDim2.fromScale(0, 0),
        size = UDim2.fromScale(1, 1),
        bg = C.bg,
        visible = false,
        zIndex = 4,
    })
    local title = UiKit.label({
        name = "Title",
        parent = panel,
        position = UDim2.fromScale(0.5, 0.36),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.9, 0.12),
        color = C.danger,
        maxTextSize = 56,
    })
    local anomaly = UiKit.label({
        name = "Anomaly",
        parent = panel,
        position = UDim2.fromScale(0.5, 0.47),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.9, 0.05),
        color = C.dim,
        maxTextSize = 22,
    })
    local retry = UiKit.button({
        name = "Retry",
        parent = panel,
        position = UDim2.fromScale(0.5, 0.64),
        anchor = Vector2.new(0.5, 0.5),
        size = BUTTON_SIZE,
        bg = C.panel,
        border = true,
        text = Strings.EndScreens.retry,
        color = C.ok,
        maxTextSize = 30,
    })
    local menu = UiKit.button({
        name = "Menu",
        parent = panel,
        position = UDim2.fromScale(0.5, 0.81),
        anchor = Vector2.new(0.5, 0.5),
        size = BUTTON_SIZE,
        bg = C.panel,
        border = true,
        text = Strings.EndScreens.menu,
        color = C.ok,
        maxTextSize = 30,
    })

    gui.Parent = parent
    return {
        gui = gui,
        hexGrid = hexGrid,
        static = static,
        breached = breached,
        panel = panel,
        title = title,
        anomaly = anomaly,
        retry = retry,
        menu = menu,
    }
end

return JumpscareGui
