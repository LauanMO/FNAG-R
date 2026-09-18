--!strict
-- HudController: relógio, noite, energia, boot, blackout e tela de amanhecer (PLANEJAMENTO 5.12).
-- Só apresenta o que o servidor manda; nunca calcula estado a partir de eventos anteriores (5.6).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Signal = require(Shared:WaitForChild("Signal"))
local Strings = require(Shared:WaitForChild("Strings"))
local Types = require(Shared:WaitForChild("Types"))
local UiKit = require(script.Parent.ui.UiKit)
local HudGui = require(script.Parent.ui.HudGui)
local DawnGui = require(script.Parent.ui.DawnGui)

-- Números de apresentação, não de jogo (Apêndice C.7): tempos da tela de amanhecer (3.10) e barrinhas (3.2)
local DAWN_CLOCK_SECONDS = 3
local DAWN_MESSAGE_SECONDS = 3
local POWER_SOURCE_SLOTS = 5 -- base + 2 portas + tablet + vazamento
local BAR_FULL = "▮"
local BAR_EMPTY = "▯"

local HudController = {}

-- Dispara quando a sequência de amanhecer termina; Main.client volta ao menu
HudController.dawnFinished = Signal.new() :: Signal.Signal<()>

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local hud = HudGui.build(playerGui)
local dawn = DawnGui.build(playerGui)
local dawnToken = 0 -- invalida uma sequência de amanhecer pendente

local function setVisible(visible: boolean)
    hud.gui.Enabled = visible
    hud.overlay.Enabled = visible
end

local function updatePower(power: number, sources: { Types.PowerSource })
    local P = GameConfig.Power
    local C = UiKit.Color
    hud.powerText.Text = string.format(Strings.HUD.power, math.floor(power))
    hud.powerFill.Size = UDim2.fromScale(math.clamp(power / P.max, 0, 1), 1)
    local color = if power < P.lowPowerCritical then C.danger elseif power < P.lowPowerWarn then C.warn else C.ok
    hud.powerFill.BackgroundColor3 = color
    hud.powerText.TextColor3 = color
    -- 1 barra = só o dreno base; cada fonte a mais acende uma barra (3.2)
    local active = math.clamp(#sources, 0, POWER_SOURCE_SLOTS)
    hud.powerSources.Text = string.rep(BAR_FULL, active) .. string.rep(BAR_EMPTY, POWER_SOURCE_SLOTS - active)
end

local function onNightStarted(payload: Types.NightStartedPayload)
    dawnToken += 1
    dawn.gui.Enabled = false
    hud.night.Text = Strings.nightLabel(payload.night)
    hud.clock.Text = Strings.clock(0)
    hud.blackout.Visible = false
    hud.bootOverlay.Visible = true
    setVisible(true)
end

local function onNightPhase(payload: Types.NightPhasePayload)
    if payload.phase == Enums.Phase.Running then
        hud.bootOverlay.Visible = false
    elseif payload.phase == Enums.Phase.Blackout then
        hud.blackout.Visible = true
    end
end

local function onHourChanged(payload: Types.HourChangedPayload)
    hud.clock.Text = Strings.clock(payload.hour)
end

local function onPowerChanged(payload: Types.PowerChangedPayload)
    updatePower(payload.power, payload.sources)
end

-- 3.10: "6:00 AM" grande, 3s depois "NOITE N CONCLUÍDA", depois volta ao menu.
-- task.delay é apresentação, não lógica de jogo (Apêndice C.5); a sessão já acabou no servidor.
local function onNightWon(payload: Types.NightWonPayload)
    dawnToken += 1
    local token = dawnToken
    dawn.clock.Text = Strings.clock(GameConfig.Night.hours)
    dawn.message.Visible = false
    dawn.gui.Enabled = true
    task.delay(DAWN_CLOCK_SECONDS, function()
        if token ~= dawnToken then
            return
        end
        dawn.message.Text = string.format(Strings.EndScreens.nightComplete, payload.night)
        dawn.message.Visible = true
        task.delay(DAWN_MESSAGE_SECONDS, function()
            if token ~= dawnToken then
                return
            end
            dawn.gui.Enabled = false
            setVisible(false)
            HudController.dawnFinished:Fire()
        end)
    end)
end

function HudController.init()
    Remotes.get(Enums.Remote.NightStarted).OnClientEvent:Connect(onNightStarted)
    Remotes.get(Enums.Remote.NightPhase).OnClientEvent:Connect(onNightPhase)
    Remotes.get(Enums.Remote.HourChanged).OnClientEvent:Connect(onHourChanged)
    Remotes.get(Enums.Remote.PowerChanged).OnClientEvent:Connect(onPowerChanged)
    Remotes.get(Enums.Remote.NightWon).OnClientEvent:Connect(onNightWon)
end

return HudController
