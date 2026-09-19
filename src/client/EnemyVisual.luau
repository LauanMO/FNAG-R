--!strict
-- EnemyVisual: silhueta do inimigo na abertura da porta (PLANEJAMENTO 3.4, 3.5b).
-- É o telegraph visual que acompanha o som de chegada. Liga/desliga só pelo Remote EnemyVisual.
-- A silhueta é um modelo (cubo com olhos, prisma de duas cunhas); cada parte guarda no atributo
-- VisibleTransparency o quanto aparece quando está visível.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local DEFAULT_VISIBLE_TRANSPARENCY = 0.35 -- semitransparente (3.4), se a parte não disser outro valor

type View = {
    parts: { BasePart },
    lights: { PointLight },
}

local EnemyVisual = {}

local views: { [string]: View } = {}

local function set(side: string, visible: boolean)
    local view = views[side]
    if not view then
        return
    end
    for _, part in view.parts do
        local target = part:GetAttribute(Enums.Attribute.VisibleTransparency)
        local shown = if typeof(target) == "number" then target else DEFAULT_VISIBLE_TRANSPARENCY
        part.Transparency = if visible then shown else 1
    end
    for _, light in view.lights do
        light.Enabled = visible
    end
end

local function hideAll()
    for side in views do
        set(side, false)
    end
end

-- Modelo da silhueta de um lado (o SonarController usa para o flash)
function EnemyVisual.getModel(side: string): Instance?
    local office = Workspace:FindFirstChild(Enums.Office.Model)
    local doors = office and office:FindFirstChild(Enums.Office.Doors)
    local door = doors and doors:FindFirstChild(Enums.Office.DoorModel[side])
    return door and door:FindFirstChild(Enums.Office.Silhouette)
end

function EnemyVisual.init()
    local office = Workspace:WaitForChild(Enums.Office.Model)
    local doors = office:WaitForChild(Enums.Office.Doors)
    for side, modelName in Enums.Office.DoorModel do
        local silhouette = doors:WaitForChild(modelName):WaitForChild(Enums.Office.Silhouette)
        local view: View = { parts = {}, lights = {} }
        for _, descendant in silhouette:GetDescendants() do
            if descendant:IsA("BasePart") then
                table.insert(view.parts, descendant)
            elseif descendant:IsA("PointLight") then
                table.insert(view.lights, descendant)
            end
        end
        views[side] = view
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
