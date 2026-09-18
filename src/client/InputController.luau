--!strict
-- InputController: converte teclado, mouse, toque e gamepad em intenções nomeadas (PLANEJAMENTO 5.11).
-- Ninguém mais lê UserInputService diretamente. Fase 2: olhar, portas (A/D, LB/RB, botão do HUD) e
-- clique/toque em objetos da sala (raycast — não há personagem, então ClickDetector não serve).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Enums = require(Shared:WaitForChild("Enums"))
local Signal = require(Shared:WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Types"))

-- Ergonomia (apresentação, não números de jogo)
local TOUCH_PIXELS_FOR_FULL_ARC = 400 -- arrastar 400 px percorre o arco inteiro (−1 → 1)
local GAMEPAD_AXIS_PER_SECOND = 2 -- com o stick no máximo, de uma ponta à outra em 1 s
local GAMEPAD_DEADZONE = 0.2
local TAP_MAX_PIXELS = 12 -- toque que anda mais que isso é arrasto, não tap
local RAY_LENGTH = 100

local KEY_DOOR_LEFT = Enum.KeyCode.A
local KEY_DOOR_RIGHT = Enum.KeyCode.D
local PAD_DOOR_LEFT = Enum.KeyCode.ButtonL1
local PAD_DOOR_RIGHT = Enum.KeyCode.ButtonR1
local KEY_TABLET = Enum.KeyCode.Space
local PAD_TABLET = Enum.KeyCode.ButtonY
-- Esc é reservado pelo menu do Roblox e não chega aos scripts: no teclado, fecha-se com a mesma tecla que abriu
local PAD_CLOSE = Enum.KeyCode.ButtonB

local InputController = {}

-- Intenções
InputController.doorToggle = Signal.new() :: Signal.Signal<Types.Side>
InputController.interact = Signal.new() :: Signal.Signal<Types.Interact>
InputController.touchModeChanged = Signal.new() :: Signal.Signal<boolean>
InputController.tabletToggle = Signal.new() :: Signal.Signal<()>
InputController.overlayClose = Signal.new() :: Signal.Signal<()>

-- "mouse": o alvo de olhar vem da posição do cursor; "manual": vem do arrasto/stick acumulado
local lookMode: "mouse" | "manual" = "mouse"
local manualAxis = 0 -- −1..1
local gamepadX = 0
local touchStart: { [InputObject]: Vector2 } = {}
local touchMoved: { [InputObject]: boolean } = {}
local raycastParams = RaycastParams.new()

function InputController.isTouchDevice(): boolean
    return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- Posição horizontal do cursor → −1..1 com zona morta no centro (a mesa fica parada)
local function mouseAxis(): number
    local camera = Workspace.CurrentCamera
    if not camera or camera.ViewportSize.X <= 0 then
        return 0
    end
    local x = UserInputService:GetMouseLocation().X / camera.ViewportSize.X * 2 - 1
    local deadzone = GameConfig.Camera.mouseDeadzone
    if math.abs(x) < deadzone then
        return 0
    end
    local sign = if x < 0 then -1 else 1
    return sign * math.clamp((math.abs(x) - deadzone) / (1 - deadzone), 0, 1)
end

-- Alvo de olhar em −1..1 (esquerda..direita); a OfficeCamera multiplica pelo arco
function InputController.getLookAxis(): number
    return if lookMode == "mouse" then mouseAxis() else manualAxis
end

-- InputObject.Position já considera o inset da GUI, então o par certo é ScreenPointToRay
local function raycastInteract(screenX: number, screenY: number)
    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end
    local ray = camera:ScreenPointToRay(screenX, screenY)
    local result = Workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, raycastParams)
    if not result then
        return
    end
    local target = result.Instance:GetAttribute(Enums.Attribute.Interact)
    if typeof(target) == "string" then
        InputController.interact:Fire(target :: Types.Interact)
    end
end

local function onInputBegan(input: InputObject, processed: boolean)
    if processed then
        return -- foco num TextBox (terminal) ou toque em botão do HUD
    end
    local inputType = input.UserInputType
    if inputType == Enum.UserInputType.Keyboard or inputType == Enum.UserInputType.Gamepad1 then
        local key = input.KeyCode
        if key == KEY_DOOR_LEFT or key == PAD_DOOR_LEFT then
            InputController.doorToggle:Fire(Enums.Side.Left)
        elseif key == KEY_DOOR_RIGHT or key == PAD_DOOR_RIGHT then
            InputController.doorToggle:Fire(Enums.Side.Right)
        elseif key == KEY_TABLET or key == PAD_TABLET then
            InputController.tabletToggle:Fire()
        elseif key == PAD_CLOSE then
            InputController.overlayClose:Fire()
        end
    elseif inputType == Enum.UserInputType.MouseButton1 then
        raycastInteract(input.Position.X, input.Position.Y)
    elseif inputType == Enum.UserInputType.Touch then
        lookMode = "manual"
        touchStart[input] = Vector2.new(input.Position.X, input.Position.Y)
        touchMoved[input] = false
    end
end

local function onInputChanged(input: InputObject, _processed: boolean)
    local inputType = input.UserInputType
    if inputType == Enum.UserInputType.MouseMovement then
        lookMode = "mouse"
    elseif inputType == Enum.UserInputType.Touch then
        local start = touchStart[input]
        if not start then
            return
        end
        manualAxis = math.clamp(manualAxis + input.Delta.X / TOUCH_PIXELS_FOR_FULL_ARC * 2, -1, 1)
        local position = Vector2.new(input.Position.X, input.Position.Y)
        if (position - start).Magnitude > TAP_MAX_PIXELS then
            touchMoved[input] = true
        end
    elseif inputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick2 then
        local x = input.Position.X
        gamepadX = if math.abs(x) < GAMEPAD_DEADZONE then 0 else x
        if gamepadX ~= 0 then
            lookMode = "manual"
        end
    end
end

local function onInputEnded(input: InputObject, _processed: boolean)
    if input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    local start = touchStart[input]
    if start and not touchMoved[input] then
        raycastInteract(input.Position.X, input.Position.Y) -- tap sem arrasto = clique em objeto
    end
    touchStart[input] = nil
    touchMoved[input] = nil
end

function InputController.init()
    local office = Workspace:WaitForChild(Enums.Office.Model)
    raycastParams.FilterType = Enum.RaycastFilterType.Include
    raycastParams.FilterDescendantsInstances = { office }

    UserInputService.InputBegan:Connect(onInputBegan)
    UserInputService.InputChanged:Connect(onInputChanged)
    UserInputService.InputEnded:Connect(onInputEnded)
    UserInputService.LastInputTypeChanged:Connect(function(inputType: Enum.UserInputType)
        InputController.touchModeChanged:Fire(inputType == Enum.UserInputType.Touch or InputController.isTouchDevice())
    end)
    -- Stick do gamepad integra ao longo do tempo (apresentação; não é timer de jogo)
    RunService.RenderStepped:Connect(function(dt: number)
        if gamepadX ~= 0 then
            manualAxis = math.clamp(manualAxis + gamepadX * GAMEPAD_AXIS_PER_SECOND * dt, -1, 1)
        end
    end)
end

return InputController
