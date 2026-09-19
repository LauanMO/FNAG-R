--!strict
-- MenuScene: o palco 3D atrás do menu principal (PLANEJAMENTO 5.12). Os quatro inimigos giram e flutuam, cada um
-- no seu pedestal, e a câmera dá voltas em volta do palco — o Palco da CAM 1, de onde os físicos saem toda noite.
-- Apresentação pura, no cliente: a cena é montada localmente, longe da sala e fechada por paredes escuras, e só
-- fica no Workspace enquanto o menu está aberto. Nesse tempo a câmera é deste módulo e o OfficeCamera fica
-- suspenso. Números aqui são de cena (studs, radianos por segundo), não de jogo (Apêndice C.7).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local Types = require(Shared:WaitForChild("Types"))
local UiKit = require(script.Parent.ui.UiKit)
local EnemyModels = require(script.Parent.EnemyModels)
local OfficeCamera = require(script.Parent.OfficeCamera)

local BIND_NAME = "FNAG_MenuScene"

-- Sala do palco: longe do escritório, para uma não aparecer na outra
local ORIGIN = Vector3.new(0, 0, 600)
local FLOOR_TOP = 1
local ROOM_HALF = 45
local ROOM_HEIGHT = 30
local WALL_T = 1
-- Palco e pedestais são cilindros de pé, com um aro de neon que sobra por baixo da borda
local STAGE_RADIUS = 11
local STAGE_HEIGHT = 1
local PEDESTAL_RADIUS = 2.6
local PEDESTAL_HEIGHT = 0.6
local PEDESTAL_DISTANCE = 6.2 -- do centro do palco
local RIM_WIDTH = 0.25
local RIM_HEIGHT = 0.15
local RIM_DROP = 0.02 -- o topo do aro fica logo abaixo do topo do cilindro, para as faces não disputarem o plano
-- Inimigos
local FIGURE_SIZE = 4
local FIGURE_HOVER = 0.5 -- vão entre o pedestal e a base da forma
local BOB_AMPLITUDE = 0.25
local BOB_SPEED = 1.3
-- Luzes
local SPOT_HEIGHT = 12 -- acima do palco
local SPOT_ANGLE = 40
local SPOT_BRIGHTNESS = 4
local SPOT_RANGE = 20
local GLOW_BRIGHTNESS = 1.2
local GLOW_RANGE = 8
local FILL_HEIGHT = 16
local FILL_BRIGHTNESS = 0.4
local FILL_RANGE = 30
-- Câmera
local ORBIT_RADIUS = 17
local ORBIT_HEIGHT = 7 -- acima do palco
local ORBIT_HEIGHT_SWAY = 1
local ORBIT_SWAY_SPEED = 0.35
local ORBIT_SPEED = 2 * math.pi / 45 -- uma volta a cada 45 s
local ORBIT_START = math.pi / 2 -- começa com o Quadrado à esquerda e o Triângulo à direita, como na sala
local LOOK_HEIGHT = 3 -- acima do palco
local FIELD_OF_VIEW = 50
-- Glitch: acompanha o glitch do título
local GLITCH_JITTER = 0.3
local GLITCH_LIGHT_OFF_CHANCE = 0.5 -- por holofote, a cada frame

local COLOR = {
    floor = Color3.fromRGB(14, 14, 16),
    wall = Color3.fromRGB(8, 8, 10),
    stage = Color3.fromRGB(34, 34, 38),
    pedestal = Color3.fromRGB(24, 24, 28),
    spot = Color3.fromRGB(255, 244, 214),
    fill = Color3.fromRGB(120, 140, 170),
}

-- Lugar no anel (graus; 90° fica de frente para a câmera no começo), giro próprio (rad/s) e fase de cada inimigo
type FigureSpec = { enemy: Types.Enemy, angle: number, spin: number, phase: number }
local FIGURES: { FigureSpec } = {
    { enemy = Enums.Enemy.Square, angle = 135, spin = 0.55, phase = 0 },
    { enemy = Enums.Enemy.Triangle, angle = 45, spin = -0.5, phase = 0.4 },
    { enemy = Enums.Enemy.Circle, angle = 225, spin = 0.6, phase = 1.9 },
    { enemy = Enums.Enemy.Hexagon, angle = 315, spin = -0.45, phase = 3.1 },
}

type Figure = { model: Model, base: Vector3, spec: FigureSpec }

local MenuScene = {}

local scene: Model? = nil
local figures: { Figure } = {}
local spots: { SpotLight } = {}
local stageTop = ORIGIN + Vector3.new(0, FLOOR_TOP + STAGE_HEIGHT, 0) -- centro do topo do palco
local elapsed = 0
local glitchLeft = 0
local running = false
local rng = Random.new() -- apresentação, não lógica de jogo (Apêndice C.6)

local function setup(p: BasePart, name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance)
    p.Name = name
    p.Size = size
    p.CFrame = cframe
    p.Color = color
    p.Material = Enum.Material.SmoothPlastic
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false -- o raycast de clique da sala nunca acha o palco
    p.CanTouch = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
end

local function block(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
    local p = Instance.new("Part")
    setup(p, name, size, CFrame.new(position), color, parent)
    return p
end

-- Cilindro de pé com o centro do topo em `top`. O eixo do cilindro é o X local; girado 90° em Z, fica vertical.
local function cylinder(name: string, radius: number, height: number, top: Vector3, color: Color3, parent: Instance)
    local p = Instance.new("Part")
    p.Shape = Enum.PartType.Cylinder
    local cframe = CFrame.new(top - Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
    setup(p, name, Vector3.new(height, 2 * radius, 2 * radius), cframe, color, parent)
end

-- Aro de neon: um disco um pouco mais largo logo abaixo do topo; só a borda que sobra aparece
local function rim(radius: number, top: Vector3, color: Color3, parent: Instance)
    local p = Instance.new("Part")
    p.Shape = Enum.PartType.Cylinder
    local height = RIM_HEIGHT
    local cframe = CFrame.new(top - Vector3.new(0, RIM_DROP + height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
    local diameter = 2 * (radius + RIM_WIDTH)
    setup(p, "Rim", Vector3.new(height, diameter, diameter), cframe, color, parent)
    p.Material = Enum.Material.Neon
    p.CastShadow = false
end

local function pointLight(parent: BasePart, color: Color3, brightness: number, range: number)
    local light = Instance.new("PointLight")
    light.Color = color
    light.Brightness = brightness
    light.Range = range
    light.Shadows = false
    light.Parent = parent
end

-- Caixa escura em volta de tudo: esconde o céu, o Baseplate e o resto do mapa
local function buildRoom(parent: Instance)
    local outer = 2 * (ROOM_HALF + WALL_T)
    local floorY = ORIGIN.Y + FLOOR_TOP
    local wallY = floorY + ROOM_HEIGHT / 2
    block(
        "Floor",
        Vector3.new(outer, WALL_T, outer),
        Vector3.new(ORIGIN.X, floorY - WALL_T / 2, ORIGIN.Z),
        COLOR.floor,
        parent
    )
    block(
        "Ceiling",
        Vector3.new(outer, WALL_T, outer),
        Vector3.new(ORIGIN.X, floorY + ROOM_HEIGHT + WALL_T / 2, ORIGIN.Z),
        COLOR.wall,
        parent
    )
    for _, sign in { -1, 1 } do
        local offset = sign * (ROOM_HALF + WALL_T / 2)
        block(
            "Wall",
            Vector3.new(outer, ROOM_HEIGHT, WALL_T),
            Vector3.new(ORIGIN.X, wallY, ORIGIN.Z + offset),
            COLOR.wall,
            parent
        )
        block(
            "Wall",
            Vector3.new(WALL_T, ROOM_HEIGHT, outer),
            Vector3.new(ORIGIN.X + offset, wallY, ORIGIN.Z),
            COLOR.wall,
            parent
        )
    end
end

local function buildStage(parent: Instance)
    cylinder("Stage", STAGE_RADIUS, STAGE_HEIGHT, stageTop, COLOR.stage, parent)
    rim(STAGE_RADIUS, stageTop, UiKit.Color.ok, parent)
    -- Luz fria e fraca no alto: o palco não some no preto entre os holofotes
    local fill = block("Fill", Vector3.one, stageTop + Vector3.new(0, FILL_HEIGHT, 0), COLOR.fill, parent)
    fill.Transparency = 1
    fill.CastShadow = false
    pointLight(fill, COLOR.fill, FILL_BRIGHTNESS, FILL_RANGE)
end

-- Pedestal com aro na cor do inimigo, holofote em cima e o inimigo flutuando no meio
local function buildFigure(spec: FigureSpec, parent: Instance): Figure
    local color = EnemyModels.Color[spec.enemy]
    local angle = math.rad(spec.angle)
    local foot = stageTop + Vector3.new(math.cos(angle), 0, math.sin(angle)) * PEDESTAL_DISTANCE
    local pedestalTop = foot + Vector3.new(0, PEDESTAL_HEIGHT, 0)
    cylinder("Pedestal", PEDESTAL_RADIUS, PEDESTAL_HEIGHT, pedestalTop, COLOR.pedestal, parent)
    rim(PEDESTAL_RADIUS, pedestalTop, color, parent)

    local holder = block("Spot", Vector3.one, foot + Vector3.new(0, SPOT_HEIGHT, 0), COLOR.spot, parent)
    holder.Transparency = 1
    holder.CastShadow = false
    local spot = Instance.new("SpotLight")
    spot.Face = Enum.NormalId.Bottom
    spot.Angle = SPOT_ANGLE
    spot.Brightness = SPOT_BRIGHTNESS
    spot.Range = SPOT_RANGE
    spot.Color = COLOR.spot
    spot.Shadows = true
    spot.Parent = holder
    table.insert(spots, spot)

    local model, root = EnemyModels.build(spec.enemy, FIGURE_SIZE)
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") and descendant ~= root then
            descendant.CastShadow = true -- a sombra no pedestal vende o "flutuando"
        end
    end
    pointLight(root, color, GLOW_BRIGHTNESS, GLOW_RANGE)
    model.Parent = parent
    local base = pedestalTop + Vector3.new(0, FIGURE_HOVER + model:GetExtentsSize().Y / 2, 0)
    return { model = model, base = base, spec = spec }
end

local function step(dt: number)
    elapsed += dt
    local glitching = glitchLeft > 0
    if glitching then
        glitchLeft -= dt
    end

    for _, figure in figures do
        local spec = figure.spec
        local bob = math.sin(spec.phase + elapsed * BOB_SPEED) * BOB_AMPLITUDE
        local position = figure.base + Vector3.new(0, bob, 0)
        if glitching then
            position += Vector3.new(
                rng:NextNumber(-GLITCH_JITTER, GLITCH_JITTER),
                rng:NextNumber(-GLITCH_JITTER, GLITCH_JITTER),
                rng:NextNumber(-GLITCH_JITTER, GLITCH_JITTER)
            )
        end
        -- yaw π: a frente do modelo (−Z) olha para a câmera no começo
        local yaw = math.pi + spec.phase + elapsed * spec.spin
        figure.model:PivotTo(CFrame.new(position) * CFrame.Angles(0, yaw, 0))
    end
    for _, spot in spots do
        spot.Enabled = not glitching or rng:NextNumber() > GLITCH_LIGHT_OFF_CHANCE
    end

    local camera = Workspace.CurrentCamera
    if camera then
        -- O PlayerModule do Roblox pode devolver a câmera para Custom; reforça a cada frame
        if camera.CameraType ~= Enum.CameraType.Scriptable then
            camera.CameraType = Enum.CameraType.Scriptable
        end
        local angle = ORBIT_START + elapsed * ORBIT_SPEED
        local height = ORBIT_HEIGHT + math.sin(elapsed * ORBIT_SWAY_SPEED) * ORBIT_HEIGHT_SWAY
        local eye = stageTop + Vector3.new(math.cos(angle) * ORBIT_RADIUS, height, math.sin(angle) * ORBIT_RADIUS)
        camera.CFrame = CFrame.lookAt(eye, stageTop + Vector3.new(0, LOOK_HEIGHT, 0))
        camera.FieldOfView = FIELD_OF_VIEW
    end
end

-- Mostra o palco e assume a câmera
function MenuScene.start()
    local model = scene
    if running or not model then
        return
    end
    running = true
    model.Parent = Workspace
    OfficeCamera.setActive(false)
    step(0)
    RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value, step)
end

-- Tira o palco do Workspace e devolve a câmera para a sala
function MenuScene.stop()
    if not running then
        return
    end
    running = false
    glitchLeft = 0
    RunService:UnbindFromRenderStep(BIND_NAME)
    local model = scene
    if model then
        model.Parent = nil
    end
    OfficeCamera.setActive(true)
end

-- Holofotes piscam e os inimigos tremem por `seconds` (o MenuController chama junto com o glitch do título)
function MenuScene.glitch(seconds: number)
    if running then
        glitchLeft = seconds
    end
end

function MenuScene.init()
    local model = Instance.new("Model")
    model.Name = "MenuStage"
    buildRoom(model)
    buildStage(model)
    for _, spec in FIGURES do
        table.insert(figures, buildFigure(spec, model))
    end
    scene = model
end

return MenuScene
