--!strict
-- JumpscareController: coreografia do jumpscare e tela de game over (PLANEJAMENTO 3.8, 3.10).
-- O servidor já encerrou a sessão quando Jumpscare chega; tudo aqui é apresentação no cliente.
-- Físicos: a câmera é forçada para a porta e o inimigo avança até encher a tela em 0.4s, com estática.
-- Hexágono: o ciano toma a tela a partir do centro, com estática, e "FIREWALL BREACHED" antes do game over.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Signal = require(Shared:WaitForChild("Signal"))
local Strings = require(Shared:WaitForChild("Strings"))
local Types = require(Shared:WaitForChild("Types"))
local AudioController = require(script.Parent.AudioController)
local OfficeCamera = require(script.Parent.OfficeCamera)
local JumpscareGui = require(script.Parent.ui.JumpscareGui)

-- Apresentação (3.10): 3s inescapáveis; o avanço até a tela leva 0.4s
local JUMPSCARE_SECONDS = 3
local LUNGE_SECONDS = 0.4
local LUNGE_END_OFFSET = CFrame.new(0, -0.4, -3.2) -- em frente à câmera, enchendo a tela
local STATIC_GRAY_MIN = 30
local STATIC_GRAY_MAX = 210
local STATIC_TRANSPARENCY_MIN = 0.35
local STATIC_TRANSPARENCY_MAX = 0.85
local MODEL_SIZE = Vector3.new(4, 4, 4)
local COLOR_SQUARE = Color3.fromRGB(40, 90, 255)
local COLOR_TRIANGLE = Color3.fromRGB(230, 40, 40)
local COLOR_EYES = Color3.fromRGB(5, 5, 8)
-- Hexágono (3.8.4)
local HEX_EXPAND_SECONDS = 1.2
local HEX_BREACH_AT_SECONDS = 1.6
local HEX_FULL_SIZE = UDim2.fromScale(1.2, 1.2)
local HEX_TRANSPARENCY_MIN = 0.1
local HEX_TRANSPARENCY_MAX = 0.55

local JumpscareController = {}

-- Disparado pelo botão MENU; Main.client mostra o menu
JumpscareController.menuRequested = Signal.new() :: Signal.Signal<()>

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local ui = JumpscareGui.build(playerGui)
local rng = Random.new() -- apresentação, não lógica de jogo (Apêndice C.6)
local currentNight = 1
local token = 0 -- invalida coreografia pendente
local model: Model? = nil
local staticConn: RBXScriptConnection? = nil
local lungeConn: RBXScriptConnection? = nil
local hexConn: RBXScriptConnection? = nil
local hexTween: Tween? = nil
local buttonsArmed = false

local function disconnect(connection: RBXScriptConnection?)
    if connection then
        connection:Disconnect()
    end
end

-- Para tudo o que anima durante o jumpscare (estática, avanço do modelo, ciano do Hexágono)
local function stopEffects()
    disconnect(staticConn)
    staticConn = nil
    disconnect(lungeConn)
    lungeConn = nil
    disconnect(hexConn)
    hexConn = nil
    local tween = hexTween
    if tween then
        tween:Cancel()
        hexTween = nil
    end
    local current = model
    if current then
        current:Destroy()
        model = nil
    end
    ui.static.Visible = false
    ui.hexGrid.Visible = false
    ui.breached.Visible = false
end

local function cleanup()
    stopEffects()
    ui.panel.Visible = false
    ui.gui.Enabled = false
    buttonsArmed = false
end

local function makePart(className: string, size: Vector3, color: Color3): BasePart
    -- cast justificado: className é "Part" ou "WedgePart", ambos BasePart
    local part = Instance.new(className) :: BasePart
    part.Size = size
    part.Color = color
    part.Material = Enum.Material.SmoothPlastic
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    return part
end

-- Cubo azul com dois olhos pretos (Quadrado) ou prisma vermelho (Triângulo). Criado só no cliente.
local function buildModel(enemy: Types.Enemy): Model
    local result = Instance.new("Model")
    result.Name = "Jumpscare"
    local body: BasePart
    if enemy == Enums.Enemy.Square then
        body = makePart("Part", MODEL_SIZE, COLOR_SQUARE)
        body.Parent = result
        for _, dx in { -1, 1 } do
            local eye = makePart("Part", Vector3.new(0.9, 0.9, 0.2), COLOR_EYES)
            eye.CFrame = body.CFrame * CFrame.new(dx * 1.1, 0.7, -MODEL_SIZE.Z / 2)
            eye.Parent = result
        end
    else
        body = makePart("WedgePart", MODEL_SIZE, COLOR_TRIANGLE)
        body.Parent = result
    end
    result.PrimaryPart = body
    result.Parent = Workspace
    return result
end

local function startStatic()
    ui.static.Visible = true
    staticConn = RunService.RenderStepped:Connect(function()
        local gray = rng:NextInteger(STATIC_GRAY_MIN, STATIC_GRAY_MAX)
        ui.static.BackgroundColor3 = Color3.fromRGB(gray, gray, gray)
        ui.static.BackgroundTransparency = rng:NextNumber(STATIC_TRANSPARENCY_MIN, STATIC_TRANSPARENCY_MAX)
    end)
end

local function lunge(target: Model, startCFrame: CFrame, endCFrame: CFrame)
    local elapsed = 0
    target:PivotTo(startCFrame)
    lungeConn = RunService.RenderStepped:Connect(function(dt: number)
        elapsed += dt
        local alpha = math.clamp(elapsed / LUNGE_SECONDS, 0, 1)
        local eased = 1 - (1 - alpha) * (1 - alpha) -- ease-out: começa rápido, encosta devagar
        target:PivotTo(startCFrame:Lerp(endCFrame, eased))
        if alpha >= 1 then
            disconnect(lungeConn)
            lungeConn = nil
        end
    end)
end

-- Físicos (3.8.1, 3.8.2): a câmera é forçada a olhar para a porta; o inimigo sai da soleira até a tela
local function physicalScare(enemy: Types.Enemy, side: Types.Side)
    local sign = if side == Enums.Side.Left then -1 else 1
    OfficeCamera.lockYaw(sign * GameConfig.Camera.maxYawDegrees)
    local office = Workspace:WaitForChild(Enums.Office.Model)
    local doorway = office
        :WaitForChild(Enums.Office.Doors)
        :WaitForChild(Enums.Office.DoorModel[side])
        :WaitForChild(Enums.Office.SoundAnchor) :: BasePart
    local endCFrame = OfficeCamera.getCFrame() * LUNGE_END_OFFSET * CFrame.Angles(0, math.pi, 0)
    local startCFrame = CFrame.new(doorway.Position) * endCFrame.Rotation
    local built = buildModel(enemy)
    model = built
    lunge(built, startCFrame, endCFrame)
end

-- Hexágono (3.8.4): não é um monstro entrando; o ciano toma a tela e termina em FIREWALL BREACHED
local function hexagonScare(mine: number)
    ui.hexGrid.Size = UDim2.fromScale(0, 0)
    ui.hexGrid.Visible = true
    local tween = TweenService:Create(
        ui.hexGrid,
        TweenInfo.new(HEX_EXPAND_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Size = HEX_FULL_SIZE }
    )
    tween:Play()
    hexTween = tween
    hexConn = RunService.RenderStepped:Connect(function()
        ui.hexGrid.BackgroundTransparency = rng:NextNumber(HEX_TRANSPARENCY_MIN, HEX_TRANSPARENCY_MAX)
    end)
    task.delay(HEX_BREACH_AT_SECONDS, function()
        if mine == token then
            ui.breached.Visible = true
        end
    end)
end

local function showGameOver(enemy: Types.Enemy)
    stopEffects()
    ui.title.Text = string.format(Strings.EndScreens.criticalFailure, currentNight)
    ui.anomaly.Text = string.format(Strings.EndScreens.anomaly, Strings.EnemyName[enemy] or enemy)
    ui.panel.Visible = true
    buttonsArmed = true
end

local function onJumpscare(payload: Types.JumpscarePayload)
    token += 1
    local mine = token
    cleanup()
    ui.gui.Enabled = true

    local enemy: Types.Enemy = payload.enemy -- anotado: o checador alarga o literal para string sem isto
    if enemy == Enums.Enemy.Square then
        physicalScare(enemy, Enums.Side.Left)
    elseif enemy == Enums.Enemy.Triangle then
        physicalScare(enemy, Enums.Side.Right)
    elseif enemy == Enums.Enemy.Hexagon then
        hexagonScare(mine)
    end

    startStatic()
    local cue = if enemy == Enums.Enemy.Square
        then Enums.Cue.JumpscareSquare
        elseif enemy == Enums.Enemy.Triangle then Enums.Cue.JumpscareTriangle
        else Enums.Cue.JumpscareHexagon
    AudioController.play(cue)

    -- task.delay é apresentação (Apêndice C.5); a sessão já acabou no servidor
    task.delay(JUMPSCARE_SECONDS, function()
        if mine == token then
            showGameOver(enemy)
        end
    end)
end

local function onNightStarted(payload: Types.NightStartedPayload)
    currentNight = payload.night
    token += 1
    cleanup()
    OfficeCamera.unlock()
end

function JumpscareController.init()
    ui.retry.Activated:Connect(function()
        if not buttonsArmed then
            return
        end
        buttonsArmed = false
        cleanup()
        OfficeCamera.unlock()
        Remotes.get(Enums.Remote.StartNight):FireServer({ night = currentNight } :: Types.StartNightPayload)
    end)
    ui.menu.Activated:Connect(function()
        if not buttonsArmed then
            return
        end
        cleanup()
        OfficeCamera.unlock()
        Remotes.get(Enums.Remote.ReturnToMenu):FireServer({})
        JumpscareController.menuRequested:Fire()
    end)

    Remotes.get(Enums.Remote.Jumpscare).OnClientEvent:Connect(onJumpscare)
    Remotes.get(Enums.Remote.NightStarted).OnClientEvent:Connect(onNightStarted)
end

return JumpscareController
