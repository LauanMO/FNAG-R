--!strict
-- EnemyVisual: silhueta do inimigo na abertura da porta (PLANEJAMENTO 3.4, 3.5b).
-- É o telegraph visual que acompanha o som de chegada. Liga/desliga só pelo Remote EnemyVisual.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local VISIBLE_TRANSPARENCY = 0.35 -- semitransparente (3.4)

type View = {
    part: BasePart,
    light: PointLight?,
}

local EnemyVisual = {}

local views: { [string]: View } = {}

local function set(side: string, visible: boolean)
    local view = views[side]
    if not view then
        return
    end
    view.part.Transparency = if visible then VISIBLE_TRANSPARENCY else 1
    local light = view.light
    if light then
        light.Enabled = visible
    end
end

local function hideAll()
    for side in views do
        set(side, false)
    end
end

function EnemyVisual.init()
    local office = Workspace:WaitForChild(Enums.Office.Model)
    local doors = office:WaitForChild(Enums.Office.Doors)
    for side, modelName in Enums.Office.DoorModel do
        local part = doors:WaitForChild(modelName):WaitForChild(Enums.Office.Silhouette) :: BasePart
        views[side] = { part = part, light = part:FindFirstChildOfClass("PointLight") }
    end
    hideAll()

    Remotes.get(Enums.Remote.EnemyVisual).OnClientEvent:Connect(function(payload: Types.EnemyVisualPayload)
        set(payload.side, payload.visible)
    end)
    Remotes.get(Enums.Remote.NightStarted).OnClientEvent:Connect(hideAll)
    Remotes.get(Enums.Remote.NightPhase).OnClientEvent:Connect(function(payload: Types.NightPhasePayload)
        if payload.phase == Enums.Phase.Won or payload.phase == Enums.Phase.Lost then
            hideAll()
        end
    end)
end

return EnemyVisual
