--!strict
-- JumpscareController: coreografia dos jumpscares e tela de game over (PLANEJAMENTO 3.8, 3.10).
-- O servidor já encerrou a sessão quando Jumpscare chega; tudo aqui é apresentação no cliente.
-- Físicos: a câmera trava na porta e treme, o campo de visão fecha, e o cubo com olhos (Quadrado) ou o prisma
-- (Triângulo) sai da soleira até encher a tela em 0.4 s, com estática.
-- Hexágono: a câmera vira para a mesa, uma grade hexagonal ciana sai do monitor e cresce até cobrir a visão,
-- o tom sobe até estourar em estática e ciano, e a tela termina em FIREWALL BREACHED.

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
local EnemyModels = require(script.Parent.EnemyModels)
local OfficeCamera = require(script.Parent.OfficeCamera)
local JumpscareGui = require(script.Parent.ui.JumpscareGui)

-- Apresentação (3.10): 3 s inescapáveis
local JUMPSCARE_SECONDS = 3
local STATIC_GRAY_MIN = 30
local STATIC_GRAY_MAX = 210
local STATIC_TRANSPARENCY_MIN = 0.35
local STATIC_TRANSPARENCY_MAX = 0.85
-- Físicos (3.8.1, 3.8.2)
local LUNGE_SECONDS = 0.4
local LUNGE_END_OFFSET = CFrame.new(0, -0.4, -3.2) -- em frente à câmera, enchendo a tela
local LUNGE_FOV = 45 -- o campo de visão fecha junto com o avanço
local LUNGE_SHAKE_DEGREES = 2.5
local MODEL_SIZE = 4 -- studs
local MODEL_LIGHT_BRIGHTNESS = 3 -- o inimigo se ilumina: aparece mesmo no blackout
local MODEL_LIGHT_RANGE = 14
-- Hexágono (3.8.4)
local HEX_EXPAND_SECONDS = 1.4
local HEX_FLASH_AT_SECONDS = 1.4 -- estouro: estática e ciano tomam a tela
local HEX_BREACH_AT_SECONDS = 1.7
local HEX_RADIUS = 0.5 -- raio de cada hexágono da grade, em studs (antes de escalar)
local HEX_COLUMNS = 7
local HEX_ROWS = 5
local HEX_LINE = 0.06
local HEX_START_SCALE = 0.05
local HEX_END_SCALE = 1.8
local HEX_END_DISTANCE = 3 -- studs à frente da cadeira
local HEX_FOV = 55
local HEX_SHAKE_DEGREES = 1.2
local HEX_TONE_START_SPEED = 0.5
local HEX_TONE_END_SPEED = 2.2
local HEX_FLASH_TRANSPARENCY_MIN = 0.1
local HEX_FLASH_TRANSPARENCY_MAX = 0.55

local JumpscareController = {}

-- Disparado pelo botão MENU; Main.client mostra o menu
JumpscareController.menuRequested = Signal.new() :: Signal.Signal<()>

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local ui = JumpscareGui.build(playerGui)
local rng = Random.new() -- apresentação, não lógica de jogo (Apêndice C.6)
local currentNight = 1
local currentLevels: Types.NightLevels? = nil -- para o TENTAR DE NOVO da Custom Night
local token = 0 -- invalida coreografia pendente
local models: { Model } = {}
local connections: { RBXScriptConnection } = {}
local tweens: { Tween } = {}
local buttonsArmed = false

-- Para tudo o que anima durante o jumpscare
local function stopEffects()
    for _, connection in connections do
        connection:Disconnect()
    end
    table.clear(connections)
    for _, tween in tweens do
        tween:Cancel()
    end
    table.clear(tweens)
    for _, model in models do
        model:Destroy()
    end
    table.clear(models)
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

-- Modelo com uma raiz invisível na origem (pivô) e as partes posicionadas em volta dela
local function newModel(name: string): (Model, BasePart)
    local model = Instance.new("Model")
    model.Name = name
    local root = makePart("Part", Vector3.new(0.2, 0.2, 0.2), EnemyModels.Color.eyes)
    root.Name = "Root"
    root.Transparency = 1
    root.Parent = model
    model.PrimaryPart = root
    table.insert(models, model)
    return model, root
end

local function addLight(parent: BasePart, color: Color3)
    local light = Instance.new("PointLight")
    light.Color = color
    light.Brightness = MODEL_LIGHT_BRIGHTNESS
    light.Range = MODEL_LIGHT_RANGE
    light.Parent = parent
end

-- Grade hexagonal plana (plano XY), cada hexágono com 6 arestas de neon ciano
local function buildHexGrid(): Model
    local model = newModel("HexGrid")
    local columnStep = math.sqrt(3) * HEX_RADIUS
    local rowStep = 1.5 * HEX_RADIUS
    for row = 0, HEX_ROWS - 1 do
        for column = 0, HEX_COLUMNS - 1 do
            local cx = (column - (HEX_COLUMNS - 1) / 2) * columnStep + (if row % 2 == 1 then columnStep / 2 else 0)
            local cy = (row - (HEX_ROWS - 1) / 2) * rowStep
            for k = 0, 5 do
                local a1 = math.rad(60 * k + 30)
                local a2 = math.rad(60 * (k + 1) + 30)
                local x1, y1 = cx + HEX_RADIUS * math.cos(a1), cy + HEX_RADIUS * math.sin(a1)
                local x2, y2 = cx + HEX_RADIUS * math.cos(a2), cy + HEX_RADIUS * math.sin(a2)
                local edge = makePart("Part", Vector3.new(HEX_RADIUS, HEX_LINE, HEX_LINE), EnemyModels.Color.hexagon)
                edge.Material = Enum.Material.Neon
                edge.CFrame = CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, 0)
                    * CFrame.Angles(0, 0, math.atan2(y2 - y1, x2 - x1))
                edge.Parent = model
            end
        end
    end
    return model
end

local function startStatic()
    ui.static.Visible = true
    table.insert(
        connections,
        RunService.RenderStepped:Connect(function()
            local gray = rng:NextInteger(STATIC_GRAY_MIN, STATIC_GRAY_MAX)
            ui.static.BackgroundColor3 = Color3.fromRGB(gray, gray, gray)
            ui.static.BackgroundTransparency = rng:NextNumber(STATIC_TRANSPARENCY_MIN, STATIC_TRANSPARENCY_MAX)
        end)
    )
end

local function lunge(target: Model, startCFrame: CFrame, endCFrame: CFrame)
    local elapsed = 0
    target:PivotTo(startCFrame)
    local connection: RBXScriptConnection
    connection = RunService.RenderStepped:Connect(function(dt: number)
        elapsed += dt
        local alpha = math.clamp(elapsed / LUNGE_SECONDS, 0, 1)
        local eased = 1 - (1 - alpha) * (1 - alpha) -- ease-out: começa rápido, encosta devagar
        target:PivotTo(startCFrame:Lerp(endCFrame, eased))
        if alpha >= 1 then
            connection:Disconnect()
        end
    end)
    table.insert(connections, connection)
end

-- Físicos (3.8.1, 3.8.2): a câmera é forçada a olhar para a porta; o inimigo sai da soleira até a tela
local function physicalScare(enemy: Types.Enemy, side: Types.Side)
    local sign = if side == Enums.Side.Left then -1 else 1
    OfficeCamera.lockYaw(sign * GameConfig.Camera.maxYawDegrees)
    OfficeCamera.setShake(LUNGE_SHAKE_DEGREES)
    OfficeCamera.tweenFieldOfView(LUNGE_FOV, LUNGE_SECONDS)
    local office = Workspace:WaitForChild(Enums.Office.Model)
    local doorway = office
        :WaitForChild(Enums.Office.Doors)
        :WaitForChild(Enums.Office.DoorModel[side])
        :WaitForChild(Enums.Office.SoundAnchor) :: BasePart
    local endCFrame = OfficeCamera.getCFrame() * LUNGE_END_OFFSET * CFrame.Angles(0, math.pi, 0)
    local startCFrame = CFrame.new(doorway.Position) * endCFrame.Rotation
    local model, root = EnemyModels.build(enemy, MODEL_SIZE)
    model.Name = "Jumpscare"
    addLight(root, EnemyModels.Color[enemy])
    table.insert(models, model)
    model.Parent = Workspace
    lunge(model, startCFrame, endCFrame)
    startStatic()
end

-- Hexágono (3.8.4): não é um monstro entrando; o sistema toma a tela a partir do monitor
local function hexagonScare(mine: number)
    OfficeCamera.lockYaw(0, false)
    OfficeCamera.setShake(HEX_SHAKE_DEGREES)
    OfficeCamera.tweenFieldOfView(HEX_FOV, HEX_EXPAND_SECONDS)

    local office = Workspace:WaitForChild(Enums.Office.Model)
    local monitor = office:WaitForChild(Enums.Office.Monitor) :: BasePart
    local base = OfficeCamera.getBaseCFrame()
    local from = monitor.Position
    local to = base.Position + base.LookVector * HEX_END_DISTANCE
    local grid = buildHexGrid()
    grid.Parent = Workspace
    grid:ScaleTo(HEX_START_SCALE)
    grid:PivotTo(CFrame.lookAt(from, base.Position))
    local elapsed = 0
    local connection: RBXScriptConnection
    connection = RunService.RenderStepped:Connect(function(dt: number)
        elapsed += dt
        local alpha = math.clamp(elapsed / HEX_EXPAND_SECONDS, 0, 1)
        local eased = alpha * alpha -- ease-in: começa devagar e acelera para cima do jogador
        local position = from:Lerp(to, eased)
        grid:ScaleTo(HEX_START_SCALE + (HEX_END_SCALE - HEX_START_SCALE) * eased)
        grid:PivotTo(CFrame.lookAt(position, base.Position))
        if alpha >= 1 then
            connection:Disconnect()
        end
    end)
    table.insert(connections, connection)

    -- "um tom digital sobe até estourar"
    local tone = AudioController.play(Enums.Cue.JumpscareHexagon)
    if tone then
        tone.PlaybackSpeed = HEX_TONE_START_SPEED
        local rise = TweenService:Create(
            tone,
            TweenInfo.new(HEX_EXPAND_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { PlaybackSpeed = HEX_TONE_END_SPEED }
        )
        rise:Play()
        table.insert(tweens, rise)
    end

    task.delay(HEX_FLASH_AT_SECONDS, function()
        if mine ~= token then
            return
        end
        startStatic()
        ui.hexGrid.Size = UDim2.fromScale(1, 1)
        ui.hexGrid.Visible = true
        table.insert(
            connections,
            RunService.RenderStepped:Connect(function()
                ui.hexGrid.BackgroundTransparency =
                    rng:NextNumber(HEX_FLASH_TRANSPARENCY_MIN, HEX_FLASH_TRANSPARENCY_MAX)
            end)
        )
    end)
    task.delay(HEX_BREACH_AT_SECONDS, function()
        if mine == token then
            ui.breached.Visible = true
        end
    end)
end

local function showGameOver(enemy: Types.Enemy)
    stopEffects()
    OfficeCamera.setShake(0)
    ui.title.Text = string.format(Strings.EndScreens.criticalFailure, Strings.nightLabel(currentNight))
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
        AudioController.play(Enums.Cue.JumpscareSquare)
    elseif enemy == Enums.Enemy.Triangle then
        physicalScare(enemy, Enums.Side.Right)
        AudioController.play(Enums.Cue.JumpscareTriangle)
    else
        hexagonScare(mine)
    end

    -- task.delay é apresentação (Apêndice C.5); a sessão já acabou no servidor
    task.delay(JUMPSCARE_SECONDS, function()
        if mine == token then
            showGameOver(enemy)
        end
    end)
end

local function onNightStarted(payload: Types.NightStartedPayload)
    currentNight = payload.night
    currentLevels = payload.config
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
        -- A Custom Night repete com os mesmos níveis; as outras, com o mesmo número de noite
        local levels = currentLevels
        local payload: Types.StartNightPayload = { night = currentNight }
        if currentNight == Enums.Night.Custom and levels then
            payload.custom = {
                square = levels.square,
                triangle = levels.triangle,
                circle = levels.circle,
                hexagon = levels.hexagon,
            }
        end
        Remotes.get(Enums.Remote.StartNight):FireServer(payload)
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
