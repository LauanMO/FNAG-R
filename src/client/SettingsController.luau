--!strict
-- SettingsController: Configurações do menu (PLANEJAMENTO 5.12, 3.14): volume master.
-- O volume vale na hora (SoundGroup Master) e vai para o save do jogador pelo Remote UpdateSettings.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))
local Types = require(Shared:WaitForChild("Types"))
local UiKit = require(script.Parent.ui.UiKit)
local SettingsGui = require(script.Parent.ui.SettingsGui)
local AudioController = require(script.Parent.AudioController)

-- Volume em pontos percentuais inteiros: passos de 10 sem erro de ponto flutuante
local VOLUME_STEP = 10
local VOLUME_MAX = 100

local SettingsController = {}

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local ui = SettingsGui.build(playerGui)
local volumePercent = VOLUME_MAX

local function apply(percent: number)
    volumePercent = math.clamp(math.round(percent / VOLUME_STEP) * VOLUME_STEP, 0, VOLUME_MAX)
    AudioController.setMasterVolume(volumePercent / VOLUME_MAX)
    ui.volume.Text = string.format(Strings.Settings.volume, volumePercent)
    UiKit.setEnabled(ui.volumeDown, volumePercent > 0)
    UiKit.setEnabled(ui.volumeUp, volumePercent < VOLUME_MAX)
end

local function change(delta: number)
    local before = volumePercent
    apply(volumePercent + delta)
    if volumePercent ~= before then
        Remotes.get(Enums.Remote.UpdateSettings):FireServer({
            masterVolume = volumePercent / VOLUME_MAX,
        } :: Types.UpdateSettingsPayload)
    end
end

function SettingsController.show()
    ui.gui.Enabled = true
end

function SettingsController.hide()
    ui.gui.Enabled = false
end

function SettingsController.init()
    apply(volumePercent)
    ui.volumeDown.Activated:Connect(function()
        if UiKit.isEnabled(ui.volumeDown) then
            change(-VOLUME_STEP)
        end
    end)
    ui.volumeUp.Activated:Connect(function()
        if UiKit.isEnabled(ui.volumeUp) then
            change(VOLUME_STEP)
        end
    end)
    ui.back.Activated:Connect(SettingsController.hide)
    Remotes.get(Enums.Remote.SaveLoaded).OnClientEvent:Connect(function(payload: Types.SaveLoadedPayload)
        apply(payload.save.settings.masterVolume * VOLUME_MAX)
    end)
    Remotes.get(Enums.Remote.NightStarted).OnClientEvent:Connect(SettingsController.hide)
end

return SettingsController
