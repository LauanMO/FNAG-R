--!strict
-- EnemyModels: os modelos 3D dos quatro inimigos no cliente (PLANEJAMENTO 3.8), usados pelos jumpscares e pelo
-- palco do menu. Cada inimigo é a própria forma extrudada, de pé e com a frente em −Z: o Quadrado é um cubo com
-- dois olhos pretos, o Triângulo um prisma de duas cunhas, o Círculo um disco e o Hexágono um prisma de três
-- blocos girados de 60°. O modelo tem uma raiz invisível na origem (PrimaryPart), para PivotTo e ScaleTo.
-- As silhuetas da soleira são do servidor (OfficeBuilder) e seguem as mesmas cores.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local Types = require(Shared:WaitForChild("Types"))

-- Proporções, em fração do tamanho do modelo
local EYE_SIZE = 0.225
local EYE_DEPTH = 0.05
local EYE_OFFSET_X = 0.275
local EYE_OFFSET_Y = 0.175
local PRISM_DEPTH = 0.5 -- espessura do Triângulo, do Círculo e do Hexágono
-- Em studs
local ROOT_SIZE = 0.2
local HEX_DEPTH_STEP = 0.01 -- cada bloco do Hexágono é um pouco mais raso: as faces não disputam o mesmo plano

local EnemyModels = {}

EnemyModels.Color = table.freeze({
    square = Color3.fromRGB(40, 90, 255), -- Quadrado Azul (3.8.1)
    triangle = Color3.fromRGB(230, 40, 40), -- Triângulo Vermelho (3.8.2)
    circle = Color3.fromRGB(255, 205, 40), -- Círculo Amarelo (3.8.3)
    hexagon = Color3.fromRGB(70, 220, 255), -- Hexágono Ciano (3.8.4)
    eyes = Color3.fromRGB(5, 5, 8), -- "dois quadrados pretos" (3.8.1)
} :: { [string]: Color3 })

local function makePart(className: string, name: string, size: Vector3, color: Color3, parent: Instance): BasePart
    -- cast justificado: className é sempre uma classe de BasePart ("Part" ou "WedgePart")
    local part = Instance.new(className) :: BasePart
    part.Name = name
    part.Size = size
    part.CFrame = CFrame.identity
    part.Color = color
    part.Material = Enum.Material.SmoothPlastic
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Parent = parent
    return part
end

-- Quadrado Azul (3.8.1): cubo com dois olhos pretos na face da frente
local function square(model: Model, size: number)
    makePart("Part", "Body", Vector3.new(size, size, size), EnemyModels.Color.square, model)
    local eyeSize = Vector3.new(EYE_SIZE, EYE_SIZE, EYE_DEPTH) * size
    for _, dx in { -1, 1 } do
        local eye = makePart("Part", "Eye", eyeSize, EnemyModels.Color.eyes, model)
        eye.CFrame = CFrame.new(dx * EYE_OFFSET_X * size, EYE_OFFSET_Y * size, -size / 2)
    end
end

-- Triângulo Vermelho (3.8.2): duas cunhas encostadas; o triângulo fica no plano XY
local function triangle(model: Model, size: number)
    local wedgeSize = Vector3.new(size * PRISM_DEPTH, size, size / 2)
    for _, sign in { -1, 1 } do
        local half = makePart("WedgePart", "Body", wedgeSize, EnemyModels.Color.triangle, model)
        -- a face vertical da cunha (lado +Z dela) encosta no centro; a rampa desce para fora
        half.CFrame = CFrame.new(sign * size / 4, 0, 0) * CFrame.Angles(0, -sign * math.pi / 2, 0)
    end
end

-- Círculo Amarelo (3.8.3): disco com a face redonda para a frente
local function circle(model: Model, size: number)
    local discSize = Vector3.new(size * PRISM_DEPTH, size, size)
    -- cast justificado: makePart com "Part" devolve um Part
    local disc = makePart("Part", "Body", discSize, EnemyModels.Color.circle, model) :: Part
    disc.Shape = Enum.PartType.Cylinder
    disc.Size = discSize -- trocar a forma pode reajustar o tamanho; reaplica
    -- o eixo do cilindro é o X local; girado 90° em Y, ele aponta para Z
    disc.CFrame = CFrame.Angles(0, math.pi / 2, 0)
end

-- Hexágono Ciano (3.8.4): um hexágono regular de vértice a vértice = size é a união de três blocos de
-- raio × raio·√3 girados de 60° em torno do eixo de profundidade
local function hexagon(model: Model, size: number)
    local radius = size / 2
    for k = 0, 2 do
        local depth = size * PRISM_DEPTH - k * HEX_DEPTH_STEP
        local block = makePart(
            "Part",
            "Body",
            Vector3.new(radius, radius * math.sqrt(3), depth),
            EnemyModels.Color.hexagon,
            model
        )
        block.CFrame = CFrame.Angles(0, 0, math.rad(60 * k))
    end
end

-- Monta o inimigo na origem com `size` studs de lado (no Hexágono, de vértice a vértice).
-- Devolve o modelo e a raiz invisível (onde pôr luzes).
function EnemyModels.build(enemy: Types.Enemy, size: number): (Model, BasePart)
    local model = Instance.new("Model")
    model.Name = enemy
    local root = makePart("Part", "Root", Vector3.new(ROOT_SIZE, ROOT_SIZE, ROOT_SIZE), EnemyModels.Color.eyes, model)
    root.Transparency = 1
    model.PrimaryPart = root
    if enemy == Enums.Enemy.Square then
        square(model, size)
    elseif enemy == Enums.Enemy.Triangle then
        triangle(model, size)
    elseif enemy == Enums.Enemy.Circle then
        circle(model, size)
    else
        hexagon(model, size)
    end
    return model, root
end

return EnemyModels
