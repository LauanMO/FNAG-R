--!strict
-- TabletController: o tablet/radar (PLANEJAMENTO 3.5, 5.8, B.5). Abre e fecha, emite ping, pinta o mapa.
-- Nunca calcula onde as IAs estão: só desenha o PingResult que o servidor mandou (5.9).
-- Abrir é otimista (a tela aparece já); o TabletState do servidor confirma ou fecha de volta.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))
local Types = require(Shared:WaitForChild("Types"))
local UiKit = require(script.Parent.ui.UiKit)
local TabletGui = require(script.Parent.ui.TabletGui)
local AudioController = require(script.Parent.AudioController)
local HudController = require(script.Parent.HudController)
local InputController = require(script.Parent.InputController)

-- Apresentação
local BLINK_SECONDS = 0.35 -- nós com anomalia piscam enquanto o resultado está na tela
local SCANLINE_SPEED = 0.35 -- frações da tela por segundo
local NODE_IDLE_TRANSPARENCY = 0.85
local NODE_BLINK_TRANSPARENCY = 0.45

local TabletController = {}

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local ui = TabletGui.build(playerGui)

local nightActive = false
local blackout = false
local open = false
local available = true
local busy = false
local dead: { [string]: boolean } = {}
local anomalyNodes: { string } = {}
local showToken = 0 -- invalida a limpeza agendada do resultado
local blinkConn: RBXScriptConnection? = nil
local scanConn: RBXScriptConnection? = nil
local progressTween: Tween? = nil

local function paintNode(node: string, state: Types.NodeState?)
    local view = ui.nodes[node]
    if not view then
        return
    end
    local C = UiKit.Color
    view.frame.BackgroundTransparency = NODE_IDLE_TRANSPARENCY
    if dead[node] then
        view.frame.BorderColor3 = C.dim
        view.name.TextColor3 = C.dim
        view.state.TextColor3 = C.dim
        view.state.Text = Strings.Tablet.dead
    elseif state == Enums.NodeState.Anomaly then
        view.frame.BorderColor3 = C.danger
        view.name.TextColor3 = C.danger
        view.state.TextColor3 = C.danger
        view.state.Text = Strings.Tablet.anomaly
    elseif state == Enums.NodeState.Clear then
        view.frame.BorderColor3 = C.border
        view.name.TextColor3 = C.ok
        view.state.TextColor3 = C.dim
        view.state.Text = ""
    else
        view.frame.BorderColor3 = C.border
        view.name.TextColor3 = C.text
        view.state.TextColor3 = C.dim
        view.state.Text = ""
    end
end

local function stopBlink()
    local connection = blinkConn
    if connection then
        connection:Disconnect()
        blinkConn = nil
    end
    for _, node in anomalyNodes do
        local view = ui.nodes[node]
        if view then
            view.frame.BackgroundTransparency = NODE_IDLE_TRANSPARENCY
        end
    end
end

local function startBlink()
    stopBlink()
    local acc = 0
    local lit = false
    blinkConn = RunService.RenderStepped:Connect(function(dt: number)
        acc += dt
        if acc < BLINK_SECONDS then
            return
        end
        acc -= BLINK_SECONDS
        lit = not lit
        for _, node in anomalyNodes do
            local view = ui.nodes[node]
            if view then
                view.frame.BackgroundTransparency = if lit then NODE_BLINK_TRANSPARENCY else NODE_IDLE_TRANSPARENCY
            end
        end
    end)
end

-- Volta os nós ao estado ocioso (nós mortos continuam DEAD)
local function clearScan()
    stopBlink()
    table.clear(anomalyNodes)
    for _, node in Enums.NodeList do
        paintNode(node, nil)
    end
end

local function setScanline(on: boolean)
    local connection = scanConn
    if on and not connection then
        scanConn = RunService.RenderStepped:Connect(function(dt: number)
            local y = (ui.scanline.Position.Y.Scale + dt * SCANLINE_SPEED) % 1
            ui.scanline.Position = UDim2.fromScale(0, y)
        end)
    elseif not on and connection then
        connection:Disconnect()
        scanConn = nil
    end
end

-- Barra de progresso do processamento do ping (3.5a). nil esconde.
local function setProgress(seconds: number?)
    local current = progressTween
    if current then
        current:Cancel()
        progressTween = nil
    end
    if seconds then
        ui.progressFill.Size = UDim2.fromScale(0, 1)
        ui.progress.Visible = true
        local tween = TweenService:Create(ui.progressFill, TweenInfo.new(seconds, Enum.EasingStyle.Linear), {
            Size = UDim2.fromScale(1, 1),
        })
        tween:Play()
        progressTween = tween
    else
        ui.progress.Visible = false
    end
end

local function setOpenLocal(value: boolean, silent: boolean)
    if open == value then
        return
    end
    open = value
    ui.gui.Enabled = value
    setScanline(value)
    if not silent then
        AudioController.play(if value then Enums.Cue.TabletOpen else Enums.Cue.TabletClose)
    end
end

local function requestOpen(value: boolean)
    if not nightActive then
        return
    end
    if value and not available then
        -- camera_offline (Fase 5) ou bateria zerada no blackout
        HudController.showMessage(if blackout then Strings.HUD.blackout else Strings.HUD.tabletOffline)
        return
    end
    setOpenLocal(value, false)
    Remotes.get(Enums.Remote.SetTabletOpen):FireServer({ open = value } :: Types.SetTabletOpenPayload)
end

local function ping()
    if not open or busy then
        return
    end
    busy = true
    UiKit.setEnabled(ui.pingButton, false)
    Remotes.get(Enums.Remote.RequestPing):FireServer({})
end

local function onTabletState(payload: Types.TabletStatePayload)
    available = payload.available
    if payload.open ~= open then
        setOpenLocal(payload.open, false) -- pedido negado ou fechamento vindo do servidor (bateria)
    end
    local remaining = payload.batteryRemaining
    if remaining ~= nil then
        ui.battery.Text = string.format(Strings.HUD.blackoutBattery, math.floor(remaining))
        ui.battery.Visible = true
    else
        ui.battery.Visible = false
    end
end

local function onPingStarted()
    busy = true
    UiKit.setEnabled(ui.pingButton, false)
    showToken += 1
    clearScan()
    ui.status.Text = Strings.Tablet.statusSending
    AudioController.play(Enums.Cue.PingSend)
    setProgress(GameConfig.Radar.pingProcessSeconds)
end

local function onPingResult(payload: Types.PingResultPayload)
    showToken += 1
    local token = showToken
    setProgress(nil)
    AudioController.play(Enums.Cue.PingResult)
    table.clear(anomalyNodes)
    for node: string, state: Types.NodeState in payload.nodes do -- anotado: o checador alarga o literal sem isto
        paintNode(node, state)
        if state == Enums.NodeState.Anomaly then
            table.insert(anomalyNodes, node)
        end
    end
    -- CAM 4 mostra o estado dos hackers (3.5): tráfego anômalo = vírus pendente (Fase 5b)
    local servers = ui.nodes[Enums.Node.CAM4]
    if servers and not dead[Enums.Node.CAM4] and payload.serverStatus == Enums.ServerStatus.Anomalous then
        servers.state.Text = Strings.Tablet.anomalousTraffic
        servers.state.TextColor3 = UiKit.Color.warn
    end
    if payload.anomalies == 0 then
        ui.status.Text = Strings.Tablet.statusClear
    elseif payload.blind > 0 then
        ui.status.Text = string.format(Strings.Tablet.statusResultBlind, payload.anomalies, payload.blind)
    else
        ui.status.Text = string.format(Strings.Tablet.statusResult, payload.anomalies)
    end
    startBlink()
    -- O resultado fica na tela por pingShowSeconds; depois "sinal perdido" até o cooldown acabar (3.5a)
    task.delay(GameConfig.Radar.pingShowSeconds, function()
        if token == showToken then
            clearScan()
            ui.status.Text = Strings.Tablet.statusLost
        end
    end)
end

local function onPingCooldownOver()
    busy = false
    UiKit.setEnabled(ui.pingButton, true)
    ui.status.Text = Strings.Tablet.statusIdle
end

local function onCameraDead(payload: Types.CameraDeadPayload)
    dead[payload.camera] = true
    paintNode(payload.camera, nil)
end

local function onFirewallChanged(payload: Types.FirewallChangedPayload)
    ui.footerFirewall.Text =
        string.format(Strings.Tablet.footerFirewall, Strings.firewallBar(payload.layers, payload.max))
end

local function onPowerChanged(payload: Types.PowerChangedPayload)
    ui.footerPower.Text = string.format(Strings.Tablet.footerPower, math.floor(payload.power))
end

local function onNightStarted()
    nightActive = true
    blackout = false
    available = true
    busy = false
    showToken += 1
    table.clear(dead)
    setOpenLocal(false, true)
    setProgress(nil)
    clearScan()
    UiKit.setEnabled(ui.pingButton, true)
    ui.status.Text = Strings.Tablet.statusIdle
    ui.battery.Visible = false
end

local function onNightPhase(payload: Types.NightPhasePayload)
    blackout = payload.phase == Enums.Phase.Blackout
    if payload.phase == Enums.Phase.Won or payload.phase == Enums.Phase.Lost then
        nightActive = false
        setOpenLocal(false, true)
    end
end

local function onTabletBatteryDead()
    available = false
    setOpenLocal(false, false)
end

function TabletController.init()
    InputController.tabletToggle:Connect(function()
        requestOpen(not open)
    end)
    InputController.overlayClose:Connect(function()
        if open then
            requestOpen(false)
        end
    end)
    InputController.interact:Connect(function(target)
        if target == Enums.Interact.Tablet then
            requestOpen(true)
        end
    end)
    ui.pingButton.Activated:Connect(function()
        if UiKit.isEnabled(ui.pingButton) then
            ping()
        end
    end)
    ui.closeButton.Activated:Connect(function()
        requestOpen(false)
    end)

    Remotes.get(Enums.Remote.TabletState).OnClientEvent:Connect(onTabletState)
    Remotes.get(Enums.Remote.PingStarted).OnClientEvent:Connect(onPingStarted)
    Remotes.get(Enums.Remote.PingResult).OnClientEvent:Connect(onPingResult)
    Remotes.get(Enums.Remote.PingCooldownOver).OnClientEvent:Connect(onPingCooldownOver)
    Remotes.get(Enums.Remote.CameraDead).OnClientEvent:Connect(onCameraDead)
    Remotes.get(Enums.Remote.FirewallChanged).OnClientEvent:Connect(onFirewallChanged)
    Remotes.get(Enums.Remote.PowerChanged).OnClientEvent:Connect(onPowerChanged)
    Remotes.get(Enums.Remote.TabletBatteryDead).OnClientEvent:Connect(onTabletBatteryDead)
    Remotes.get(Enums.Remote.NightStarted).OnClientEvent:Connect(onNightStarted)
    Remotes.get(Enums.Remote.NightPhase).OnClientEvent:Connect(onNightPhase)
end

return TabletController
