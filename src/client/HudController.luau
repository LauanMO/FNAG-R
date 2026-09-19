--!strict
-- HudController: relógio, noite, energia, firewall, sistemas corrompidos, gerador, intrusão, blackout,
-- mensagens, botões de toque e tela de amanhecer (PLANEJAMENTO 5.12, B.4).
-- Só apresenta o que o servidor manda; cada Remote traz o estado completo do seu subsistema (5.6).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
local Overlay = require(script.Parent.Overlay)
local ClockGlitch = require(script.Parent.ClockGlitch)

-- Números de apresentação, não de jogo (Apêndice C.7)
local DAWN_CLOCK_SECONDS = 3 -- "6:00 AM" antes de "NOITE N CONCLUÍDA" (3.10)
local DAWN_MESSAGE_SECONDS = 3
local MESSAGE_SECONDS = 2.5
local PULSE_SECONDS = 0.6 -- barra de energia pulsando abaixo do aviso (3.2)
local PULSE_TRANSPARENCY = 0.6
local FIREWALL_FLASH_SECONDS = 0.4 -- o firewall pisca a cada camada rompida (3.8.4)
local VIRUS_BLINK_SECONDS = 0.35 -- banner de vírus piscando (3.8.3)
local VIRUS_BLINK_TRANSPARENCY = 0.7
local HEX_GARBLE_SECONDS = 1.4 -- Hexágono: os textos do HUD viram lixo antes de sumir (3.8.4)
local GARBLE_INTERVAL = 0.05
local GARBLE_LENGTH = 10
local SYSTEM_LINE_HEIGHT = 0.19 -- fração da lista; cabem os 5 sistemas
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
local firewallToken = 0
local virusTween: Tween? = nil
local garbleConn: RBXScriptConnection? = nil
local garbleRng = Random.new() -- apresentação, não lógica de jogo (Apêndice C.6)
local pulseTween: Tween? = nil
local touchMode = false
local currentHour = 0

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

-- Botões de toque (5.11). Com tablet, terminal ou manual aberto, os de porta somem (3.5).
local function applyTouchButtons()
    local overlayOpen = Overlay.isAnyOpen()
    hud.doorLeftButton.Visible = touchMode and not overlayOpen
    hud.doorRightButton.Visible = touchMode and not overlayOpen
    hud.tabletButton.Visible = touchMode
    hud.terminalButton.Visible = touchMode
    hud.manualButton.Visible = touchMode
end

local function setTouchMode(on: boolean)
    touchMode = on
    applyTouchButtons()
end

local function showClock()
    if not ClockGlitch.isActive() then
        hud.clock.Text = Strings.clock(currentHour)
    end
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

local function setGenerator(usesLeft: number)
    hud.generator.Text = if usesLeft > 0
        then string.format(Strings.HUD.generatorAvailable, usesLeft)
        else Strings.HUD.generatorUsed
end

local function setSystems(corrupted: { string })
    for _, child in hud.systems:GetChildren() do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    for i, system in corrupted do
        local label = UiKit.label({
            name = system,
            parent = hud.systems,
            position = UDim2.fromScale(0, 0),
            size = UDim2.fromScale(1, SYSTEM_LINE_HEIGHT),
            text = string.format(Strings.HUD.corruptedSystem, system),
            color = UiKit.Color.danger,
            xAlign = Enum.TextXAlignment.Left,
            maxTextSize = 18,
        })
        label.LayoutOrder = i
    end
end

local function setIntrusion(active: boolean, remaining: number?)
    hud.intrusion.Visible = active
    hud.intrusionTint.Visible = active
    if active and remaining then
        hud.intrusion.Text = string.format(Strings.HUD.intrusion, math.ceil(remaining))
    end
end

-- Círculo (3.8.3): banner piscando + barra do fusível. Some quando o terminal abre (vira minigame)
-- ou quando o fusível acaba.
local function setVirusAlert(active: boolean, remaining: number?)
    hud.virusBanner.Visible = active
    hud.virusBar.Visible = active
    if active and remaining then
        hud.virusFill.Size = UDim2.fromScale(math.clamp(remaining / GameConfig.Circle.alertFuseSeconds, 0, 1), 1)
    end
    local current = virusTween
    if active and not current then
        local info = TweenInfo.new(VIRUS_BLINK_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true)
        local tween = TweenService:Create(hud.virusBanner, info, { TextTransparency = VIRUS_BLINK_TRANSPARENCY })
        tween:Play()
        virusTween = tween
    elseif not active and current then
        current:Cancel()
        virusTween = nil
        hud.virusBanner.TextTransparency = 0
    end
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

local function stopGarble()
    local connection = garbleConn
    if connection then
        connection:Disconnect()
        garbleConn = nil
    end
end

local function garbageText(): string
    local chars = Strings.HUD.glitchChars
    local out = table.create(GARBLE_LENGTH)
    for i = 1, GARBLE_LENGTH do
        local k = garbleRng:NextInteger(1, #chars)
        out[i] = string.sub(chars, k, k)
    end
    return table.concat(out)
end

-- 3.8.4: no jumpscare do Hexágono os textos do HUD viram lixo de caracteres e só depois somem
local function garbleThenHide(token: number)
    stopGarble()
    local labels = { hud.clock, hud.night, hud.powerText, hud.powerSources, hud.firewall, hud.generator }
    local elapsed = 0
    local sinceSwap = GARBLE_INTERVAL
    garbleConn = RunService.Heartbeat:Connect(function(dt: number)
        elapsed += dt
        sinceSwap += dt
        if sinceSwap >= GARBLE_INTERVAL then
            sinceSwap = 0
            for _, label in labels do
                label.Text = garbageText()
            end
        end
        if elapsed >= HEX_GARBLE_SECONDS then
            stopGarble()
            if token == dawnToken then
                setVisible(false)
            end
        end
    end)
end

local function onNightStarted(payload: Types.NightStartedPayload)
    stopGarble()
    dawnToken += 1
    dawn.gui.Enabled = false
    currentHour = 0
    hud.night.Text = Strings.nightLabel(payload.night)
    showClock()
    hud.blackout.Visible = false
    hud.blackout.Text = Strings.HUD.blackout
    hud.message.Visible = false
    hud.bootOverlay.Visible = true
    setSystems({})
    setIntrusion(false, nil)
    setVirusAlert(false, nil)
    setGenerator(GameConfig.Power.generatorUsesPerNight)
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
    currentHour = payload.hour
    showClock()
end

local function onPowerChanged(payload: Types.PowerChangedPayload)
    updatePower(payload.power, payload.sources)
end

local function onFirewallChanged(payload: Types.FirewallChangedPayload)
    local C = UiKit.Color
    hud.firewall.Text = Strings.HUD.firewall .. Strings.firewallBar(payload.layers, payload.max)
    local baseColor = if payload.layers <= 1 then C.danger else C.hacker
    hud.firewall.TextColor3 = baseColor
    if payload.cause == Enums.FirewallCause.Break then
        firewallToken += 1
        local token = firewallToken
        hud.firewall.TextColor3 = C.text
        task.delay(FIREWALL_FLASH_SECONDS, function()
            if token == firewallToken then
                hud.firewall.TextColor3 = baseColor
            end
        end)
    end
end

local function onTabletState(payload: Types.TabletStatePayload)
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

-- 3.10: o jumpscare toma a tela; o HUD some e a sequência de amanhecer pendente (se houver) é cancelada
local function onJumpscare(payload: Types.JumpscarePayload)
    dawnToken += 1
    setPulse(false)
    hud.message.Visible = false
    setIntrusion(false, nil)
    setVirusAlert(false, nil)
    if payload.enemy == Enums.Enemy.Hexagon then
        garbleThenHide(dawnToken)
    else
        setVisible(false)
    end
end

function HudController.init()
    -- Botões de toque só em dispositivos de toque (5.11); no PC são as teclas e os objetos 3D
    setTouchMode(InputController.isTouchDevice())
    InputController.touchModeChanged:Connect(setTouchMode)
    Overlay.changed:Connect(function()
        applyTouchButtons()
    end)
    hud.doorLeftButton.Activated:Connect(function()
        InputController.doorToggle:Fire(Enums.Side.Left)
    end)
    hud.doorRightButton.Activated:Connect(function()
        InputController.doorToggle:Fire(Enums.Side.Right)
    end)
    hud.tabletButton.Activated:Connect(function()
        InputController.tabletToggle:Fire()
    end)
    hud.terminalButton.Activated:Connect(function()
        InputController.terminalToggle:Fire()
    end)
    hud.manualButton.Activated:Connect(function()
        InputController.notebookToggle:Fire()
    end)
    ClockGlitch.changed:Connect(function(text: string?)
        if text then
            hud.clock.Text = text
        else
            showClock()
        end
    end)

    Remotes.get(Enums.Remote.NightStarted).OnClientEvent:Connect(onNightStarted)
    Remotes.get(Enums.Remote.NightPhase).OnClientEvent:Connect(onNightPhase)
    Remotes.get(Enums.Remote.HourChanged).OnClientEvent:Connect(onHourChanged)
    Remotes.get(Enums.Remote.PowerChanged).OnClientEvent:Connect(onPowerChanged)
    Remotes.get(Enums.Remote.FirewallChanged).OnClientEvent:Connect(onFirewallChanged)
    Remotes.get(Enums.Remote.SystemCorrupted).OnClientEvent:Connect(function(payload: Types.SystemChangedPayload)
        setSystems(payload.corrupted)
    end)
    Remotes.get(Enums.Remote.SystemRepaired).OnClientEvent:Connect(function(payload: Types.SystemChangedPayload)
        setSystems(payload.corrupted)
    end)
    Remotes.get(Enums.Remote.IntrusionState).OnClientEvent:Connect(function(payload: Types.IntrusionStatePayload)
        setIntrusion(payload.active, payload.remaining)
    end)
    Remotes.get(Enums.Remote.VirusAlert).OnClientEvent:Connect(function(payload: Types.VirusAlertPayload)
        setVirusAlert(payload.active, payload.remaining)
    end)
    Remotes.get(Enums.Remote.GeneratorUsed).OnClientEvent:Connect(function(payload: Types.GeneratorUsedPayload)
        setGenerator(payload.usesLeft)
    end)
    Remotes.get(Enums.Remote.NightWon).OnClientEvent:Connect(onNightWon)
    Remotes.get(Enums.Remote.Jumpscare).OnClientEvent:Connect(onJumpscare)
    Remotes.get(Enums.Remote.TabletState).OnClientEvent:Connect(onTabletState)
    Remotes.get(Enums.Remote.CameraDead).OnClientEvent:Connect(onCameraDead)
end

return HudController
