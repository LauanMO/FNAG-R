--!strict
-- OfficeCamera: câmera travada na cadeira com arco de giro limitado e suavizado (PLANEJAMENTO 3.4).
-- Não lê input: pega o alvo de olhar do InputController (5.11). Também dá à coreografia dos jumpscares e do
-- sonar o que eles precisam: travar o olhar, tremer e mudar o campo de visão (3.5, 3.8).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Enums = require(Shared:WaitForChild("Enums"))
local InputController = require(script.Parent.InputController)

local BIND_NAME = "FNAG_OfficeCamera"
local FIELD_OF_VIEW = 70 -- apresentação: FOV vertical padrão do Roblox

local OfficeCamera = {}

local yaw = 0 -- radianos; positivo = direita
local lockedYaw: number? = nil -- jumpscare: ignora o input e olha para um ponto fixo
local anchorCFrame = CFrame.identity
local cameraRef: Camera? = nil
local shakeRadians = 0
local fovTween: Tween? = nil
local rng = Random.new() -- apresentação, não lógica de jogo (Apêndice C.6)

function OfficeCamera.init()
    local camera = Workspace.CurrentCamera
    assert(camera ~= nil, "OfficeCamera: sem CurrentCamera")
    local office = Workspace:WaitForChild(Enums.Office.Model)
    local anchor = office:WaitForChild(Enums.Office.CameraAnchor) :: BasePart

    cameraRef = camera
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
        local shake = CFrame.identity
        if shakeRadians > 0 then
            shake = CFrame.Angles(
                rng:NextNumber(-shakeRadians, shakeRadians),
                rng:NextNumber(-shakeRadians, shakeRadians),
                0
            )
        end
        -- CFrame.Angles gira no sentido anti-horário visto de cima; negativo = virar para a direita
        camera.CFrame = anchor.CFrame * CFrame.Angles(0, -yaw, 0) * shake
    end)
end

-- Graus atuais (positivo = direita). A Noite 0 (Fase 7) usa para "olhou para os dois lados".
function OfficeCamera.getYawDegrees(): number
    return math.deg(yaw)
end

-- CFrame que a câmera terá no próximo frame (âncora + giro atual, sem tremor)
function OfficeCamera.getCFrame(): CFrame
    return anchorCFrame * CFrame.Angles(0, -yaw, 0)
end

-- A cadeira olhando para a frente (yaw 0): referência fixa para efeitos que saem da mesa
function OfficeCamera.getBaseCFrame(): CFrame
    return anchorCFrame
end

-- Força a câmera a olhar para um ângulo e ignora o input até unlock() (jumpscares, 3.8).
-- snap = true vira na hora; false deixa a suavização normal fazer o giro.
function OfficeCamera.lockYaw(degrees: number, snap: boolean?)
    local radians = math.rad(degrees)
    lockedYaw = radians
    if snap ~= false then
        yaw = radians
    end
end

-- Tremor em graus (0 desliga)
function OfficeCamera.setShake(degrees: number)
    shakeRadians = math.rad(math.max(0, degrees))
end

-- Muda o campo de visão; seconds = 0 aplica na hora
function OfficeCamera.tweenFieldOfView(fov: number, seconds: number)
    local camera = cameraRef
    if not camera then
        return
    end
    local current = fovTween
    if current then
        current:Cancel()
        fovTween = nil
    end
    if seconds <= 0 then
        camera.FieldOfView = fov
        return
    end
    local tween = TweenService:Create(
        camera,
        TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { FieldOfView = fov }
    )
    tween:Play()
    fovTween = tween
end

function OfficeCamera.defaultFieldOfView(): number
    return FIELD_OF_VIEW
end

-- Volta ao controle do jogador, sem tremor e com o campo de visão normal
function OfficeCamera.unlock()
    lockedYaw = nil
    OfficeCamera.setShake(0)
    OfficeCamera.tweenFieldOfView(FIELD_OF_VIEW, 0)
end

return OfficeCamera
