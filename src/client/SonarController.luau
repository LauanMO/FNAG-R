--!strict
-- SonarController: flash de sonar 3D no ping, nas noites com sonar (PLANEJAMENTO 3.5, 7.4 — noites 6 e 7).
-- Por Radar.sonarFlashSeconds a sala vira wireframe branco-e-preto (Highlight + ColorCorrection), o campo de
-- visão abre o bastante para as duas soleiras e, se o ping achou alguém na porta, a silhueta aparece por cima
-- de tudo — inclusive através da porta fechada. O tablet fica translúcido durante o flash (TabletController).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Signal = require(Shared:WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Types"))
local EnemyVisual = require(script.Parent.EnemyVisual)
local OfficeCamera = require(script.Parent.OfficeCamera)

-- Apresentação do preset "sonar" (3.5)
local SONAR_AMBIENT = Color3.new(1, 1, 1)
local SONAR_FOG_END = 45
local SONAR_FOV = 115 -- as duas soleiras entram no quadro mesmo olhando para a mesa
local ROOM_FILL = Color3.new(0, 0, 0)
local ROOM_FILL_TRANSPARENCY = 0.1
local LINE_COLOR = Color3.new(1, 1, 1)
local ENEMY_FILL_TRANSPARENCY = 0.5
local CORRECTION_CONTRAST = 1
local CORRECTION_SATURATION = -1

local DOOR_NODES: { [string]: string } = {
    [Enums.Side.Left] = Enums.Node.DoorLeft,
    [Enums.Side.Right] = Enums.Node.DoorRight,
}

type SavedLighting = {
    ambient: Color3,
    outdoorAmbient: Color3,
    fogEnd: number,
    fogColor: Color3,
}

local SonarController = {}

-- Disparado no começo de cada flash, com a duração em segundos
SonarController.flashed = Signal.new() :: Signal.Signal<number>

local sonarNight = false
local token = 0
local saved: SavedLighting? = nil
local highlights: { Highlight } = {}
local correction: ColorCorrectionEffect? = nil

local function makeHighlight(adornee: Instance, alwaysOnTop: boolean): Highlight
    local highlight = Instance.new("Highlight")
    highlight.Adornee = adornee
    highlight.OutlineColor = LINE_COLOR
    highlight.OutlineTransparency = 0
    if alwaysOnTop then
        highlight.FillColor = LINE_COLOR
        highlight.FillTransparency = ENEMY_FILL_TRANSPARENCY
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    else
        highlight.FillColor = ROOM_FILL
        highlight.FillTransparency = ROOM_FILL_TRANSPARENCY
        highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    end
    highlight.Parent = adornee
    table.insert(highlights, highlight)
    return highlight
end

-- Desfaz o flash. Highlights são destruídos, não desativados: desativados ainda ocupam o limite do motor.
local function restore()
    local previous = saved
    if previous then
        Lighting.Ambient = previous.ambient
        Lighting.OutdoorAmbient = previous.outdoorAmbient
        Lighting.FogEnd = previous.fogEnd
        Lighting.FogColor = previous.fogColor
        saved = nil
    end
    for _, highlight in highlights do
        highlight:Destroy()
    end
    table.clear(highlights)
    local effect = correction
    if effect then
        effect.Enabled = false
    end
    OfficeCamera.tweenFieldOfView(OfficeCamera.defaultFieldOfView(), 0)
end

local function flash(payload: Types.PingResultPayload)
    token += 1
    local mine = token
    restore()
    saved = {
        ambient = Lighting.Ambient,
        outdoorAmbient = Lighting.OutdoorAmbient,
        fogEnd = Lighting.FogEnd,
        fogColor = Lighting.FogColor,
    }
    Lighting.Ambient = SONAR_AMBIENT
    Lighting.OutdoorAmbient = SONAR_AMBIENT
    Lighting.FogEnd = SONAR_FOG_END
    Lighting.FogColor = ROOM_FILL
    local effect = correction
    if effect then
        effect.Enabled = true
    end
    local office = Workspace:FindFirstChild(Enums.Office.Model)
    if office then
        makeHighlight(office, false)
    end
    for side, node in DOOR_NODES do
        local silhouette = EnemyVisual.getModel(side)
        if silhouette and payload.nodes[node] == Enums.NodeState.Anomaly then
            makeHighlight(silhouette, true)
        end
    end
    OfficeCamera.tweenFieldOfView(SONAR_FOV, 0)

    local seconds = GameConfig.Radar.sonarFlashSeconds
    SonarController.flashed:Fire(seconds)
    task.delay(seconds, function()
        if mine == token then
            restore()
        end
    end)
end

function SonarController.init()
    local effect = Instance.new("ColorCorrectionEffect")
    effect.Name = "SonarCorrection"
    effect.Contrast = CORRECTION_CONTRAST
    effect.Saturation = CORRECTION_SATURATION
    effect.Enabled = false
    effect.Parent = Lighting
    correction = effect

    Remotes.get(Enums.Remote.NightStarted).OnClientEvent:Connect(function(payload: Types.NightStartedPayload)
        sonarNight = payload.config.sonar
        token += 1
        restore()
    end)
    Remotes.get(Enums.Remote.PingResult).OnClientEvent:Connect(function(payload: Types.PingResultPayload)
        if sonarNight then
            flash(payload)
        end
    end)
    Remotes.get(Enums.Remote.NightPhase).OnClientEvent:Connect(function(payload: Types.NightPhasePayload)
        if payload.phase == Enums.Phase.Won or payload.phase == Enums.Phase.Lost then
            token += 1
            restore()
        end
    end)
end

return SonarController
