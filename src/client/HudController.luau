--!strict
-- HudController: relógio, noite, energia, boot, blackout, mensagens e tela de amanhecer (PLANEJAMENTO 5.12).
-- Só apresenta o que o servidor manda; nunca calcula estado a partir de eventos anteriores (5.6).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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
local InputController = require(script.Parent.InputController)

-- Números de apresentação, não de jogo (Apêndice C.7)
local DAWN_CLOCK_SECONDS = 3 -- "6:00 AM" antes de "NOITE N CONCLUÍDA" (3.10)
local DAWN_MESSAGE_SECONDS = 3
local MESSAGE_SECONDS = 2.5
local PULSE_SECONDS = 0.6 -- barra de energia pulsando abaixo do aviso (3.2)
local PULSE_TRANSPARENCY = 0.6
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
local messageToken = 0
local pulseTween: Tween? = nil
local touchMode = false
local tabletOpen = false

local function setVisible(visible: boolean)
    hud.gui.Enabled = visible
    hud.overlay.Enabled = visible
end

local function setPulse(on: boolean)
    local current = pulseTween
    if on and not current then
        local info = TweenInfo.new(PULSE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
        local tween = TweenService:Create(hud.powerFill, info, { BackgroundTransparency = PULSE_TRANSPARENCY })
        tween:Play()
        pulseTween = tween
    elseif not on and current then
        current:Cancel()
        pulseTween = nil
        hud.powerFill.BackgroundTransparency = 0
    end
end

local function setDoorButtonsEnabled(enabled: boolean)
    UiKit.setEnabled(hud.doorLeftButton, enabled)
    UiKit.setEnabled(hud.doorRightButton, enabled)
end

-- Botões de toque (5.11). Com o tablet aberto os de porta somem (3.5); o de tablet fica para fechar.
local function applyTouchButtons()
    hud.doorLeftButton.Visible = touchMode and not tabletOpen
    hud.doorRightButton.Visible = touchMode and not tabletOpen
    hud.tabletButton.Visible = touchMode
end

local function setTouchButtonsVisible(visible: boolean)
    touchMode = visible
    applyTouchButtons()
end

local function updatePower(power: number, sources: { Types.PowerSource })
    local P = GameConfig.Power
    local C = UiKit.Color
    hud.powerText.Text = string.format(Strings.HUD.power, math.floor(power))
    hud.powerFill.Size = UDim2.fromScale(math.clamp(power / P.max, 0, 1), 1)
    local color = if power < P.lowPowerCritical then C.danger elseif power < P.lowPowerWarn then C.warn else C.ok
    hud.powerFill.BackgroundColor3 = color
    hud.powerText.TextColor3 = color
    setPulse(power > 0 and power < P.lowPowerWarn)
    -- 1 barra = só o dreno base; cada fonte a mais acende uma barra (3.2)
    local active = math.clamp(#sources, 0, POWER_SOURCE_SLOTS)
    hud.powerSources.Text = string.rep(BAR_FULL, active) .. string.rep(BAR_EMPTY, POWER_SOURCE_SLOTS - active)
end

-- Mensagem curta no centro da tela; some sozinha
function HudController.showMessage(text: string)
    messageToken += 1
    local token = messageToken
    hud.message.Text = text
    hud.message.Visible = true
    task.delay(MESSAGE_SECONDS, function()
        if token == messageToken then
            hud.message.Visible = false
        end
    end)
end

local function onNightStarted(payload: Types.NightStartedPayload)
    dawnToken += 1
    dawn.gui.Enabled = false
    hud.night.Text = Strings.nightLabel(payload.night)
    hud.clock.Text = Strings.clock(0)
    hud.blackout.Visible = false
    hud.blackout.Text = Strings.HUD.blackout
    hud.message.Visible = false
    hud.bootOverlay.Visible = true
    setDoorButtonsEnabled(true)
    setVisible(true)
end

local function onNightPhase(payload: Types.NightPhasePayload)
    if payload.phase == Enums.Phase.Running then
        hud.bootOverlay.Visible = false
        hud.blackout.Visible = false
        setDoorButtonsEnabled(true)
    elseif payload.phase == Enums.Phase.Blackout then
        hud.blackout.Visible = true
        setDoorButtonsEnabled(false) -- botões travam no blackout (3.9)
        setPulse(false)
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
    setPulse(false)
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

local function onTabletState(payload: Types.TabletStatePayload)
    tabletOpen = payload.open
    applyTouchButtons()
    -- B.4: no blackout, o aviso mostra a bateria do tablet até ela zerar
    local remaining = payload.batteryRemaining
    if hud.blackout.Visible and remaining ~= nil then
        hud.blackout.Text = if remaining > 0
            then string.format(Strings.HUD.blackoutBattery, math.floor(remaining))
            else Strings.HUD.blackout
    end
end

local function onCameraDead(payload: Types.CameraDeadPayload)
    HudController.showMessage(
        string.format(Strings.HUD.cameraDead, Strings.NodeShort[payload.camera] or payload.camera)
    )
end

-- 3.10: o jumpscare toma a tela; o HUD some e a sequência de amanhecer pendente (se houver) é cancelada
local function onJumpscare()
    dawnToken += 1
    setPulse(false)
    hud.message.Visible = false
    setVisible(false)
end

function HudController.init()
    -- Botões de porta só em dispositivos de toque (5.11); no PC são as teclas A/D e os botões 3D
    setTouchButtonsVisible(InputController.isTouchDevice())
    InputController.touchModeChanged:Connect(setTouchButtonsVisible)
    hud.doorLeftButton.Activated:Connect(function()
        InputController.doorToggle:Fire(Enums.Side.Left)
    end)
    hud.doorRightButton.Activated:Connect(function()
        InputController.doorToggle:Fire(Enums.Side.Right)
    end)
    hud.tabletButton.Activated:Connect(function()
        InputController.tabletToggle:Fire()
    end)

    Remotes.get(Enums.Remote.NightStarted).OnClientEvent:Connect(onNightStarted)
    Remotes.get(Enums.Remote.NightPhase).OnClientEvent:Connect(onNightPhase)
    Remotes.get(Enums.Remote.HourChanged).OnClientEvent:Connect(onHourChanged)
    Remotes.get(Enums.Remote.PowerChanged).OnClientEvent:Connect(onPowerChanged)
    Remotes.get(Enums.Remote.NightWon).OnClientEvent:Connect(onNightWon)
    Remotes.get(Enums.Remote.Jumpscare).OnClientEvent:Connect(onJumpscare)
    Remotes.get(Enums.Remote.TabletState).OnClientEvent:Connect(onTabletState)
    Remotes.get(Enums.Remote.CameraDead).OnClientEvent:Connect(onCameraDead)
end

return HudController
