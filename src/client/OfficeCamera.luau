--!strict
-- OfficeCamera: câmera travada na cadeira com arco de giro limitado e suavizado (PLANEJAMENTO 3.4).
-- Não lê input: pega o alvo de olhar do InputController (5.11).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Enums = require(Shared:WaitForChild("Enums"))
local InputController = require(script.Parent.InputController)

local BIND_NAME = "FNAG_OfficeCamera"
local FIELD_OF_VIEW = 70 -- apresentação: FOV vertical padrão do Roblox

local OfficeCamera = {}

local yaw = 0 -- radianos; positivo = direita
local lockedYaw: number? = nil -- jumpscare: ignora o input e olha para a porta
local anchorCFrame = CFrame.identity

function OfficeCamera.init()
    local camera = Workspace.CurrentCamera
    assert(camera ~= nil, "OfficeCamera: sem CurrentCamera")
    local office = Workspace:WaitForChild(Enums.Office.Model)
    local anchor = office:WaitForChild(Enums.Office.CameraAnchor) :: BasePart

    camera.CameraType = Enum.CameraType.Scriptable
    camera.FieldOfView = FIELD_OF_VIEW
    camera.CFrame = anchor.CFrame
    anchorCFrame = anchor.CFrame

    local maxYaw = math.rad(GameConfig.Camera.maxYawDegrees)
    RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value, function(dt: number)
        -- O PlayerModule do Roblox pode devolver a câmera para Custom; reforça a cada frame
        if camera.CameraType ~= Enum.CameraType.Scriptable then
            camera.CameraType = Enum.CameraType.Scriptable
        end
        local locked = lockedYaw
        local target = if locked then locked else InputController.getLookAxis() * maxYaw
        local alpha = 1 - math.exp(-dt * GameConfig.Camera.smoothing)
        yaw += (target - yaw) * alpha
        -- CFrame.Angles gira no sentido anti-horário visto de cima; negativo = virar para a direita
        camera.CFrame = anchor.CFrame * CFrame.Angles(0, -yaw, 0)
    end)
end

-- Graus atuais (positivo = direita). A Noite 0 (Fase 7) usa para "olhou para os dois lados".
function OfficeCamera.getYawDegrees(): number
    return math.deg(yaw)
end

-- CFrame que a câmera terá no próximo frame (âncora + giro atual)
function OfficeCamera.getCFrame(): CFrame
    return anchorCFrame * CFrame.Angles(0, -yaw, 0)
end

-- Força a câmera a olhar para um ângulo e ignora o input até unlock() (jumpscare, 3.8)
function OfficeCamera.lockYaw(degrees: number)
    local radians = math.rad(degrees)
    lockedYaw = radians
    yaw = radians
end

function OfficeCamera.unlock()
    lockedYaw = nil
end

return OfficeCamera
