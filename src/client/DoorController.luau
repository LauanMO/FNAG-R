--!strict
-- DoorController: botões, predição e animação das portas (PLANEJAMENTO 3.3, 5.8).
-- A porta anima no mesmo frame do clique; o servidor confirma (accepted=true) ou nega (accepted=false → reverte).
-- Input chega pelo InputController (tecla, botão do HUD ou clique no botão 3D); estado chega por DoorStateChanged.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))
local Types = require(Shared:WaitForChild("Types"))
local AudioController = require(script.Parent.AudioController)
local HudController = require(script.Parent.HudController)
local InputController = require(script.Parent.InputController)

-- Cores do botão de parede por estado (apresentação)
local BUTTON_OPEN = Color3.fromRGB(80, 200, 120)
local BUTTON_CLOSED = Color3.fromRGB(220, 60, 60)
local BUTTON_JAMMED = Color3.fromRGB(255, 140, 40)
local BUTTON_LOCKED = Color3.fromRGB(70, 70, 74)

type DoorView = {
    side: Types.Side,
    part: BasePart,
    button: BasePart,
    openY: number,
    closedY: number,
    closed: boolean,
    jammed: boolean,
    tween: Tween?,
}

local DoorController = {}

local views: { [string]: DoorView } = {}
local nightActive = false
local running = false -- o servidor só aceita em "running" (5.8): boot e blackout negam
local blackout = false

local function findView(side: Types.Side): DoorView
    local office = Workspace:WaitForChild(Enums.Office.Model)
    local doors = office:WaitForChild(Enums.Office.Doors)
    local model = doors:WaitForChild(Enums.Office.DoorModel[side])
    local part = model:WaitForChild(Enums.Office.Door) :: BasePart
    local button = model:WaitForChild(Enums.Office.Button) :: BasePart
    local openY = part:GetAttribute(Enums.Attribute.OpenY)
    local closedY = part:GetAttribute(Enums.Attribute.ClosedY)
    assert(typeof(openY) == "number" and typeof(closedY) == "number", `porta {side} sem atributos OpenY/ClosedY`)
    return {
        side = side,
        part = part,
        button = button,
        openY = openY,
        closedY = closedY,
        closed = false,
        jammed = false,
        tween = nil,
    }
end

local function paintButton(view: DoorView)
    view.button.Color = if blackout
        then BUTTON_LOCKED
        elseif view.jammed then BUTTON_JAMMED
        elseif view.closed then BUTTON_CLOSED
        else BUTTON_OPEN
end

local function targetCFrame(view: DoorView, closed: boolean): CFrame
    local p = view.part.Position
    return CFrame.new(p.X, if closed then view.closedY else view.openY, p.Z)
end

-- Anima até o estado pedido. silent = sem som de porta (a reversão toca door_jammed em vez disso).
local function animate(view: DoorView, closed: boolean, silent: boolean)
    local current = view.tween
    if current then
        current:Cancel()
    end
    local seconds = if closed then GameConfig.Doors.closeSeconds else GameConfig.Doors.openSeconds
    local direction = if closed then Enum.EasingDirection.In else Enum.EasingDirection.Out
    local tween = TweenService:Create(view.part, TweenInfo.new(seconds, Enum.EasingStyle.Quad, direction), {
        CFrame = targetCFrame(view, closed),
    })
    view.tween = tween
    tween:Play()
    if not silent then
        AudioController.play(if closed then Enums.Cue.DoorClose else Enums.Cue.DoorOpen, view.side)
    end
end

local function snap(view: DoorView, closed: boolean)
    local current = view.tween
    if current then
        current:Cancel()
        view.tween = nil
    end
    view.closed = closed
    view.part.CFrame = targetCFrame(view, closed)
end

function DoorController.toggle(side: Types.Side)
    local view = views[side]
    if not view or not nightActive then
        return
    end
    if blackout or not running or view.jammed then
        -- Botão travado (3.3, 3.9): buzz curto; se for jam, o HUD explica
        AudioController.play(Enums.Cue.DoorJammed, side)
        if view.jammed then
            HudController.showMessage(Strings.HUD.doorJammed)
        end
        return
    end
    -- Predição (5.8): anima já e envia a intenção; o servidor confirma ou nega
    view.closed = not view.closed
    animate(view, view.closed, false)
    paintButton(view)
    Remotes.get(Enums.Remote.ToggleDoor):FireServer({ side = side } :: Types.ToggleDoorPayload)
end

local function onDoorStateChanged(payload: Types.DoorStateChangedPayload)
    local view = views[payload.side]
    if not view then
        return
    end
    view.jammed = payload.jammed
    if payload.accepted then
        if view.closed ~= payload.closed then
            -- Mudança iniciada pelo servidor (blackout agora; Hexágono na Fase 5)
            view.closed = payload.closed
            animate(view, view.closed, false)
        end
    else
        -- Predição negada: reverte e avisa (5.8)
        if view.closed ~= payload.closed then
            view.closed = payload.closed
            animate(view, view.closed, true)
        end
        AudioController.play(Enums.Cue.DoorJammed, payload.side)
        if payload.jammed then
            HudController.showMessage(Strings.HUD.doorJammed)
        end
    end
    paintButton(view)
end

local function onNightStarted()
    nightActive = true
    running = false
    blackout = false
    for _, view in views do
        view.jammed = false
        snap(view, false)
        paintButton(view)
    end
end

local function onNightPhase(payload: Types.NightPhasePayload)
    running = payload.phase == Enums.Phase.Running
    blackout = payload.phase == Enums.Phase.Blackout
    if payload.phase == Enums.Phase.Won or payload.phase == Enums.Phase.Lost then
        nightActive = false
    end
    for _, view in views do
        paintButton(view)
    end
end

function DoorController.init()
    views[Enums.Side.Left] = findView(Enums.Side.Left)
    views[Enums.Side.Right] = findView(Enums.Side.Right)
    for _, view in views do
        snap(view, false)
        paintButton(view)
    end

    InputController.doorToggle:Connect(function(side)
        DoorController.toggle(side)
    end)
    InputController.interact:Connect(function(target)
        if target == Enums.Interact.DoorLeft then
            DoorController.toggle(Enums.Side.Left)
        elseif target == Enums.Interact.DoorRight then
            DoorController.toggle(Enums.Side.Right)
        end
    end)

    Remotes.get(Enums.Remote.DoorStateChanged).OnClientEvent:Connect(onDoorStateChanged)
    Remotes.get(Enums.Remote.NightStarted).OnClientEvent:Connect(onNightStarted)
    Remotes.get(Enums.Remote.NightPhase).OnClientEvent:Connect(onNightPhase)
end

return DoorController
