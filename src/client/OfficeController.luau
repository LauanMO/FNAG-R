--!strict
-- OfficeController: efeitos da sala que não são porta — luzes (blackout, flicker) e relógio de parede (PLANEJAMENTO 3.4, 3.9).
-- Só apresenta o que o servidor manda pelos Remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))
local Types = require(Shared:WaitForChild("Types"))
local ClockGlitch = require(script.Parent.ClockGlitch)

-- Apresentação: cor da luminária apagada e comportamento do flicker abaixo de 10% (3.4)
local FIXTURE_OFF_COLOR = Color3.fromRGB(22, 22, 24)
local RESTORE_SECONDS = 1 -- luzes voltam em 1s após reset generator (3.9)
local FLICKER_CHANCE_PER_FRAME = 0.06
local FLICKER_MIN = 0.15
local FLICKER_MAX = 0.7

type Fixture = {
    part: BasePart,
    light: PointLight,
    baseBrightness: number,
    baseColor: Color3,
}

local OfficeController = {}

local fixtures: { Fixture } = {}
local wallClockLabel: TextLabel? = nil
local tweens: { Tween } = {}
local flickerConn: RBXScriptConnection? = nil
local blackout = false
local currentHour = 0
local rng = Random.new() -- apresentação, não lógica de jogo (Apêndice C.6)

local function cancelTweens()
    for _, tween in tweens do
        tween:Cancel()
    end
    table.clear(tweens)
end

local function setScale(scale: number)
    for _, fixture in fixtures do
        fixture.light.Brightness = fixture.baseBrightness * scale
        fixture.part.Color = FIXTURE_OFF_COLOR:Lerp(fixture.baseColor, scale)
    end
end

local function tweenLights(seconds: number, scale: number)
    cancelTweens()
    local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    for _, fixture in fixtures do
        local lightTween = TweenService:Create(fixture.light, info, { Brightness = fixture.baseBrightness * scale })
        local partTween =
            TweenService:Create(fixture.part, info, { Color = FIXTURE_OFF_COLOR:Lerp(fixture.baseColor, scale) })
        lightTween:Play()
        partTween:Play()
        table.insert(tweens, lightTween)
        table.insert(tweens, partTween)
    end
end

local function setFlicker(on: boolean)
    if on and not flickerConn then
        flickerConn = RunService.Heartbeat:Connect(function()
            local dip = rng:NextNumber() < FLICKER_CHANCE_PER_FRAME
            setScale(if dip then rng:NextNumber(FLICKER_MIN, FLICKER_MAX) else 1)
        end)
    elseif not on and flickerConn then
        flickerConn:Disconnect()
        flickerConn = nil
        if not blackout then
            setScale(1)
        end
    end
end

local function setWallClock(text: string, visible: boolean)
    local label = wallClockLabel
    if label then
        label.Text = text
        label.Visible = visible
    end
end

-- Hora no relógio de parede, a menos que o glitch esteja embaralhando (3.4) ou seja blackout (3.9)
local function showWallClock()
    if blackout then
        setWallClock("", false)
    elseif not ClockGlitch.isActive() then
        setWallClock(Strings.clock(currentHour), true)
    end
end

local function onNightStarted()
    blackout = false
    setFlicker(false)
    cancelTweens()
    setScale(1)
    currentHour = 0
    showWallClock()
end

local function onNightPhase(payload: Types.NightPhasePayload)
    if payload.phase == Enums.Phase.Blackout then
        blackout = true
        setFlicker(false)
        tweenLights(GameConfig.Blackout.lightsFadeSeconds, 0)
        setWallClock("", false) -- no escuro o jogador não vê a hora, mas ela passa (3.9)
    elseif payload.phase == Enums.Phase.Running and blackout then
        -- saída do blackout (reset generator, Fase 5)
        blackout = false
        tweenLights(RESTORE_SECONDS, 1)
        showWallClock()
    end
end

local function onHourChanged(payload: Types.HourChangedPayload)
    currentHour = payload.hour
    showWallClock()
end

local function onPowerChanged(payload: Types.PowerChangedPayload)
    local critical = payload.power > 0 and payload.power < GameConfig.Power.lowPowerCritical
    setFlicker(critical and not blackout)
end

function OfficeController.init()
    local office = Workspace:WaitForChild(Enums.Office.Model)
    local lightsFolder = office:WaitForChild(Enums.Office.Lights)
    for _, child in lightsFolder:GetChildren() do
        local light = child:FindFirstChildOfClass("PointLight")
        if child:IsA("BasePart") and light then
            table.insert(
                fixtures,
                { part = child, light = light, baseBrightness = light.Brightness, baseColor = child.Color }
            )
        end
    end
    local clock = office:WaitForChild(Enums.Office.WallClock)
    local gui = clock:WaitForChild("SurfaceGui")
    wallClockLabel = gui:WaitForChild(Enums.Office.WallClockLabel) :: TextLabel

    Remotes.get(Enums.Remote.NightStarted).OnClientEvent:Connect(onNightStarted)
    Remotes.get(Enums.Remote.NightPhase).OnClientEvent:Connect(onNightPhase)
    Remotes.get(Enums.Remote.HourChanged).OnClientEvent:Connect(onHourChanged)
    Remotes.get(Enums.Remote.PowerChanged).OnClientEvent:Connect(onPowerChanged)
    ClockGlitch.changed:Connect(function(text: string?)
        if blackout then
            return
        end
        if text then
            setWallClock(text, true)
        else
            showWallClock()
        end
    end)
end

return OfficeController
