--!strict
-- HudGui: constrói as ScreenGuis do HUD (PLANEJAMENTO 5.12, B.4).
-- Relógio, noite, energia, firewall, gerador, sistemas corrompidos, intrusão, blackout, mensagem e os botões
-- de toque (portas, tablet, terminal, manual). O banner de vírus do Círculo entra na Fase 5b.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local UiKit = require(script.Parent.UiKit)

export type Hud = {
    gui: ScreenGui, -- leituras e botões (respeita o inset da barra do Roblox)
    overlay: ScreenGui, -- tela de boot e tingimento de intrusão (tela cheia)
    clock: TextLabel,
    night: TextLabel,
    powerText: TextLabel,
    powerFill: Frame,
    powerSources: TextLabel,
    firewall: TextLabel,
    generator: TextLabel,
    systems: Frame, -- uma linha "[!] sistema" por sistema corrompido (UIListLayout)
    intrusion: TextLabel,
    intrusionTint: Frame,
    blackout: TextLabel,
    message: TextLabel,
    bootOverlay: Frame,
    doorLeftButton: TextButton,
    doorRightButton: TextButton,
    tabletButton: TextButton,
    terminalButton: TextButton,
    manualButton: TextButton,
}

-- Fileira de botões de toque (5.11): cinco botões de 0.176 × 0.17 da tela, ≈ 64 px de altura no iPhone SE
local BUTTON_ROW_Y = 0.8
local BUTTON_W = 0.176
local BUTTON_H = 0.17
local BUTTON_GAP = 0.02
local INTRUSION_TINT_TRANSPARENCY = 0.82

local HudGui = {}

local function rowX(slot: number): number
    return BUTTON_GAP + (slot - 1) * (BUTTON_W + BUTTON_GAP)
end

local function touchButton(parent: Instance, name: string, slot: number, text: string, color: Color3): TextButton
    return UiKit.button({
        name = name,
        parent = parent,
        position = UDim2.fromScale(rowX(slot), BUTTON_ROW_Y),
        size = UDim2.fromScale(BUTTON_W, BUTTON_H),
        bg = UiKit.Color.panel,
        border = true,
        text = text,
        color = color,
        visible = false,
        maxTextSize = 26,
    })
end

function HudGui.build(parent: Instance): Hud
    local C = UiKit.Color

    local overlay = UiKit.screenGui("HudOverlayGui", 5, true)
    -- Intrusão (3.8.4): a tela inteira tingida de ciano, por baixo das leituras do HUD
    local intrusionTint = UiKit.frame({
        name = "IntrusionTint",
        parent = overlay,
        position = UDim2.fromScale(0, 0),
        size = UDim2.fromScale(1, 1),
        bg = C.hacker,
        visible = false,
    })
    intrusionTint.BackgroundTransparency = INTRUSION_TINT_TRANSPARENCY
    local bootOverlay = UiKit.frame({
        name = "Boot",
        parent = overlay,
        position = UDim2.fromScale(0, 0),
        size = UDim2.fromScale(1, 1),
        bg = C.bg,
        zIndex = 2,
    })
    UiKit.label({
        name = "BootText",
        parent = bootOverlay,
        position = UDim2.fromScale(0.5, 0.5),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.8, 0.08),
        text = Strings.Boot.initializing,
        color = C.ok,
        maxTextSize = 36,
    })

    local gui = UiKit.screenGui("HudGui", 10, false)

    local clock = UiKit.label({
        name = "Clock",
        parent = gui,
        position = UDim2.fromScale(0.03, 0.03),
        size = UDim2.fromScale(0.35, 0.1),
        text = Strings.clock(0),
        xAlign = Enum.TextXAlignment.Left,
        maxTextSize = 48,
    })
    local night = UiKit.label({
        name = "Night",
        parent = gui,
        position = UDim2.fromScale(0.03, 0.135),
        size = UDim2.fromScale(0.35, 0.045),
        color = C.dim,
        xAlign = Enum.TextXAlignment.Left,
        maxTextSize = 22,
    })
    local firewall = UiKit.label({
        name = "Firewall",
        parent = gui,
        position = UDim2.fromScale(0.03, 0.185),
        size = UDim2.fromScale(0.35, 0.045),
        color = C.hacker,
        xAlign = Enum.TextXAlignment.Left,
        maxTextSize = 22,
    })
    local generator = UiKit.label({
        name = "Generator",
        parent = gui,
        position = UDim2.fromScale(0.03, 0.235),
        size = UDim2.fromScale(0.35, 0.04),
        color = C.dim,
        xAlign = Enum.TextXAlignment.Left,
        maxTextSize = 18,
    })
    local systems = UiKit.frame({
        name = "Systems",
        parent = gui,
        position = UDim2.fromScale(0.03, 0.285),
        size = UDim2.fromScale(0.42, 0.25),
    })
    local systemsLayout = Instance.new("UIListLayout")
    systemsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    systemsLayout.Parent = systems

    local powerText = UiKit.label({
        name = "PowerText",
        parent = gui,
        position = UDim2.fromScale(0.62, 0.03),
        size = UDim2.fromScale(0.35, 0.05),
        color = C.ok,
        xAlign = Enum.TextXAlignment.Right,
        maxTextSize = 26,
    })
    local powerBar = UiKit.frame({
        name = "PowerBar",
        parent = gui,
        position = UDim2.fromScale(0.62, 0.09),
        size = UDim2.fromScale(0.35, 0.022),
        bg = C.panel,
        border = true,
    })
    local powerFill = UiKit.frame({
        name = "Fill",
        parent = powerBar,
        position = UDim2.fromScale(0, 0),
        size = UDim2.fromScale(1, 1),
        bg = C.ok,
    })
    local powerSources = UiKit.label({
        name = "PowerSources",
        parent = gui,
        position = UDim2.fromScale(0.62, 0.125),
        size = UDim2.fromScale(0.35, 0.045),
        color = C.dim,
        xAlign = Enum.TextXAlignment.Right,
        maxTextSize = 22,
    })

    local intrusion = UiKit.label({
        name = "Intrusion",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.42),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.92, 0.08),
        color = C.hacker,
        visible = false,
        maxTextSize = 34,
    })
    local blackout = UiKit.label({
        name = "Blackout",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.52),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.6, 0.08),
        text = Strings.HUD.blackout,
        color = C.danger,
        visible = false,
        maxTextSize = 40,
    })

    -- Mensagem curta de feedback ("MOTOR TRAVADO — ver manual")
    local message = UiKit.label({
        name = "Message",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.7),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.8, 0.05),
        color = C.warn,
        visible = false,
        maxTextSize = 26,
    })

    local doorLeftButton = touchButton(gui, "DoorLeftButton", 1, Strings.HUD.doorLeftButton, C.ok)
    local tabletButton = touchButton(gui, "TabletButton", 2, Strings.Tablet.hudButton, C.hacker)
    local terminalButton = touchButton(gui, "TerminalButton", 3, Strings.Terminal.hudButton, C.hacker)
    local manualButton = touchButton(gui, "ManualButton", 4, Strings.Manual.hudButton, C.hacker)
    local doorRightButton = touchButton(gui, "DoorRightButton", 5, Strings.HUD.doorRightButton, C.ok)

    overlay.Parent = parent
    gui.Parent = parent

    return {
        gui = gui,
        overlay = overlay,
        clock = clock,
        night = night,
        powerText = powerText,
        powerFill = powerFill,
        powerSources = powerSources,
        firewall = firewall,
        generator = generator,
        systems = systems,
        intrusion = intrusion,
        intrusionTint = intrusionTint,
        blackout = blackout,
        message = message,
        bootOverlay = bootOverlay,
        doorLeftButton = doorLeftButton,
        doorRightButton = doorRightButton,
        tabletButton = tabletButton,
        terminalButton = terminalButton,
        manualButton = manualButton,
    }
end

return HudGui
