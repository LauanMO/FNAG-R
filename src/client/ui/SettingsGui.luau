--!strict
-- SettingsGui: painel de Configurações do menu (PLANEJAMENTO 5.12, Fase 6): volume master.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local UiKit = require(script.Parent.UiKit)

export type Settings = {
    gui: ScreenGui,
    volume: TextLabel,
    volumeDown: TextButton,
    volumeUp: TextButton,
    back: TextButton,
}

local DIM_TRANSPARENCY = 0.3

local SettingsGui = {}

function SettingsGui.build(parent: Instance): Settings
    local C = UiKit.Color
    local gui = UiKit.screenGui("SettingsGui", 25, true)

    local dim = UiKit.frame({
        name = "Dim",
        parent = gui,
        position = UDim2.fromScale(0, 0),
        size = UDim2.fromScale(1, 1),
        bg = C.bg,
    })
    dim.BackgroundTransparency = DIM_TRANSPARENCY
    dim.Active = true

    -- Painel de 0.6 da altura da tela: botões de 0.24 dele ≈ 54 px no iPhone SE (5.11)
    local panel = UiKit.frame({
        name = "Panel",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.5),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.6, 0.6),
        bg = C.panel,
        border = true,
    })
    UiKit.label({
        name = "Title",
        parent = panel,
        position = UDim2.fromScale(0.5, 0.12),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.9, 0.14),
        text = Strings.Settings.title,
        color = C.ok,
        maxTextSize = 34,
    })
    local volumeDown = UiKit.button({
        name = "VolumeDown",
        parent = panel,
        position = UDim2.fromScale(0.05, 0.3),
        size = UDim2.fromScale(0.2, 0.24),
        bg = C.panel,
        border = true,
        text = Strings.Settings.volumeDown,
        color = C.ok,
        maxTextSize = 40,
    })
    local volume = UiKit.label({
        name = "Volume",
        parent = panel,
        position = UDim2.fromScale(0.5, 0.42),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.46, 0.14),
        color = C.text,
        maxTextSize = 30,
    })
    local volumeUp = UiKit.button({
        name = "VolumeUp",
        parent = panel,
        position = UDim2.fromScale(0.95, 0.3),
        anchor = Vector2.new(1, 0),
        size = UDim2.fromScale(0.2, 0.24),
        bg = C.panel,
        border = true,
        text = Strings.Settings.volumeUp,
        color = C.ok,
        maxTextSize = 40,
    })
    local back = UiKit.button({
        name = "Back",
        parent = panel,
        position = UDim2.fromScale(0.5, 0.72),
        anchor = Vector2.new(0.5, 0),
        size = UDim2.fromScale(0.5, 0.22),
        bg = C.panel,
        border = true,
        text = Strings.Settings.back,
        color = C.ok,
        maxTextSize = 30,
    })

    gui.Parent = parent
    return { gui = gui, volume = volume, volumeDown = volumeDown, volumeUp = volumeUp, back = back }
end

return SettingsGui
