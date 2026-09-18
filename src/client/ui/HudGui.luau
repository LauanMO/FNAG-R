--!strict
-- HudGui: constrói as ScreenGuis do HUD (PLANEJAMENTO 5.12).
-- Fase 1: relógio, noite, energia, boot, blackout. Fase 2: mensagem transitória e botões de porta para toque.
-- Firewall, sistemas corrompidos e banners entram na Fase 5.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local UiKit = require(script.Parent.UiKit)

export type Hud = {
    gui: ScreenGui, -- leituras e botões (respeita o inset da barra do Roblox)
    overlay: ScreenGui, -- tela de boot (tela cheia)
    clock: TextLabel,
    night: TextLabel,
    powerText: TextLabel,
    powerFill: Frame,
    powerSources: TextLabel,
    blackout: TextLabel,
    message: TextLabel,
    bootOverlay: Frame,
    doorLeftButton: TextButton,
    doorRightButton: TextButton,
}

-- Botões de porta para toque (5.11): cantos inferiores, ≥ 56 px no iPhone SE (0.17 × 375 ≈ 64 px)
local DOOR_BUTTON_SIZE = UDim2.fromScale(0.2, 0.17)
local DOOR_BUTTON_Y = 0.8

local HudGui = {}

function HudGui.build(parent: Instance): Hud
    local C = UiKit.Color

    local overlay = UiKit.screenGui("HudOverlayGui", 5, true)
    local bootOverlay = UiKit.frame({
        name = "Boot",
        parent = overlay,
        position = UDim2.fromScale(0, 0),
        size = UDim2.fromScale(1, 1),
        bg = C.bg,
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

    local blackout = UiKit.label({
        name = "Blackout",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.5),
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

    local doorLeftButton = UiKit.button({
        name = "DoorLeftButton",
        parent = gui,
        position = UDim2.fromScale(0.02, DOOR_BUTTON_Y),
        size = DOOR_BUTTON_SIZE,
        bg = C.panel,
        border = true,
        text = Strings.HUD.doorLeftButton,
        color = C.ok,
        visible = false,
        maxTextSize = 28,
    })
    local doorRightButton = UiKit.button({
        name = "DoorRightButton",
        parent = gui,
        position = UDim2.fromScale(0.98, DOOR_BUTTON_Y),
        anchor = Vector2.new(1, 0),
        size = DOOR_BUTTON_SIZE,
        bg = C.panel,
        border = true,
        text = Strings.HUD.doorRightButton,
        color = C.ok,
        visible = false,
        maxTextSize = 28,
    })

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
        blackout = blackout,
        message = message,
        bootOverlay = bootOverlay,
        doorLeftButton = doorLeftButton,
        doorRightButton = doorRightButton,
    }
end

return HudGui
