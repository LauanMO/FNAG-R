--!strict
-- HudGui: constrói as ScreenGuis do HUD (PLANEJAMENTO 5.12). Fase 1: relógio, noite, energia, boot, blackout.
-- Firewall, sistemas corrompidos, banners e botões mobile entram nas Fases 2 e 5.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local UiKit = require(script.Parent.UiKit)

export type Hud = {
    gui: ScreenGui, -- leituras (respeita o inset da barra do Roblox)
    overlay: ScreenGui, -- fundo e tela de boot (tela cheia)
    clock: TextLabel,
    night: TextLabel,
    powerText: TextLabel,
    powerFill: Frame,
    powerSources: TextLabel,
    blackout: TextLabel,
    bootOverlay: Frame,
}

local HudGui = {}

function HudGui.build(parent: Instance): Hud
    local C = UiKit.Color

    local overlay = UiKit.screenGui("HudOverlayGui", 5, true)
    -- Fase 1: ainda não existe sala 3D; este fundo escuro sai na Fase 2 (OfficeBuilder).
    UiKit.frame({
        name = "Backdrop",
        parent = overlay,
        position = UDim2.fromScale(0, 0),
        size = UDim2.fromScale(1, 1),
        bg = C.bg,
    })
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
        bootOverlay = bootOverlay,
    }
end

return HudGui
