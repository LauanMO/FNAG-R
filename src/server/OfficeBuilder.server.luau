--!strict
-- OfficeBuilder: constrói a sala whitebox por código, para ficar versionada e reproduzível (PLANEJAMENTO 3.4, 5.1).
-- Tudo em Part cinza, SmoothPlastic, sem arte. Nomes e atributos vêm de Enums.Office / Enums.Attribute:
-- é o contrato com os controllers do cliente. Números aqui são de cena (studs), não de jogo (Apêndice C.7).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Enums = require(Shared.Enums)
local Strings = require(Shared.Strings)

-- Sala: 20 de largura (X), 12 de profundidade (Z), 9 de altura (Y). O jogador olha para −Z ("norte").
local FLOOR_TOP = 1 -- acima do topo do Baseplate padrão (y = 0), para não haver z-fighting
local ROOM_HALF_W = 10
local ROOM_HALF_D = 6
local ROOM_HEIGHT = 9
local WALL_T = 1
local CEILING_Y = FLOOR_TOP + ROOM_HEIGHT

-- Aberturas das portas: na ponta norte das paredes leste/oeste, 4 de largura e 7 de altura (3.4)
local DOOR_Z_MIN = -5
local DOOR_Z_MAX = -1
local DOOR_HEIGHT = 7
local DOOR_THICKNESS = 0.6
local BUTTON_OFFSET_Z = 1 -- o botão fica logo ao sul da abertura, do lado de dentro

-- Corredores atrás das portas: escuros, com uma luz fraca ao longe
local CORRIDOR_LENGTH = 30
local CORRIDOR_HEIGHT = 7

-- Mesa e objetos na frente do jogador
local DESK_SIZE = Vector3.new(7, 2.2, 2.5)
local DESK_Z = -0.5
local CHAIR_Z = 3.2
local EYE_HEIGHT = 4.2

local COLOR = {
    floor = Color3.fromRGB(62, 62, 66),
    wall = Color3.fromRGB(108, 108, 112),
    ceiling = Color3.fromRGB(88, 88, 92),
    corridor = Color3.fromRGB(48, 48, 52),
    door = Color3.fromRGB(52, 56, 62),
    desk = Color3.fromRGB(92, 82, 72),
    monitor = Color3.fromRGB(28, 28, 32),
    notebook = Color3.fromRGB(205, 195, 165),
    tablet = Color3.fromRGB(38, 42, 48),
    chair = Color3.fromRGB(40, 40, 44),
    button = Color3.fromRGB(80, 200, 120), -- o DoorController repinta conforme o estado
    lightOn = Color3.fromRGB(255, 244, 214),
    corridorLight = Color3.fromRGB(120, 140, 170),
}

local function part(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = CFrame.new(position)
    p.Color = color
    p.Material = Enum.Material.SmoothPlastic
    p.Anchored = true
    p.CanCollide = true
    p.CanTouch = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function invisible(p: Part): Part
    p.Transparency = 1
    p.CanCollide = false
    p.CanQuery = false
    p.CastShadow = false
    return p
end

local function buildShell(parent: Instance)
    local outerW = 2 * (ROOM_HALF_W + WALL_T)
    local outerD = 2 * (ROOM_HALF_D + WALL_T)
    local wallY = FLOOR_TOP + ROOM_HEIGHT / 2
    part("Floor", Vector3.new(outerW, WALL_T, outerD), Vector3.new(0, FLOOR_TOP - WALL_T / 2, 0), COLOR.floor, parent)
    part(
        "Ceiling",
        Vector3.new(outerW, WALL_T, outerD),
        Vector3.new(0, CEILING_Y + WALL_T / 2, 0),
        COLOR.ceiling,
        parent
    )
    part(
        "WallNorth",
        Vector3.new(outerW, ROOM_HEIGHT, WALL_T),
        Vector3.new(0, wallY, -(ROOM_HALF_D + WALL_T / 2)),
        COLOR.wall,
        parent
    )
    part(
        "WallSouth",
        Vector3.new(outerW, ROOM_HEIGHT, WALL_T),
        Vector3.new(0, wallY, ROOM_HALF_D + WALL_T / 2),
        COLOR.wall,
        parent
    )

    -- Paredes leste/oeste em três pedaços: trecho norte, trecho sul e a verga acima da abertura
    for _, sign in { -1, 1 } do
        local x = sign * (ROOM_HALF_W + WALL_T / 2)
        local suffix = if sign < 0 then "West" else "East"
        local northLen = DOOR_Z_MIN + ROOM_HALF_D -- da parede norte até o início da abertura
        local southLen = ROOM_HALF_D - DOOR_Z_MAX
        part(
            `Wall{suffix}North`,
            Vector3.new(WALL_T, ROOM_HEIGHT, northLen),
            Vector3.new(x, wallY, -ROOM_HALF_D + northLen / 2),
            COLOR.wall,
            parent
        )
        part(
            `Wall{suffix}South`,
            Vector3.new(WALL_T, ROOM_HEIGHT, southLen),
            Vector3.new(x, wallY, ROOM_HALF_D - southLen / 2),
            COLOR.wall,
            parent
        )
        local headerH = CEILING_Y - (FLOOR_TOP + DOOR_HEIGHT)
        part(
            `Wall{suffix}Header`,
            Vector3.new(WALL_T, headerH, DOOR_Z_MAX - DOOR_Z_MIN),
            Vector3.new(x, CEILING_Y - headerH / 2, (DOOR_Z_MIN + DOOR_Z_MAX) / 2),
            COLOR.wall,
            parent
        )
    end
end

local function buildDoor(parent: Instance, side: string)
    local sign = if side == Enums.Side.Left then -1 else 1
    local model = Instance.new("Model")
    model.Name = Enums.Office.DoorModel[side]

    local wallX = sign * (ROOM_HALF_W + WALL_T / 2)
    local doorZ = (DOOR_Z_MIN + DOOR_Z_MAX) / 2
    local doorW = DOOR_Z_MAX - DOOR_Z_MIN
    local closedY = FLOOR_TOP + DOOR_HEIGHT / 2
    local openY = closedY + DOOR_HEIGHT -- sobe inteira para dentro da parede/teto

    local door = part(
        Enums.Office.Door,
        Vector3.new(DOOR_THICKNESS, DOOR_HEIGHT, doorW),
        Vector3.new(wallX, openY, doorZ),
        COLOR.door,
        model
    )
    door.CanCollide = false
    door:SetAttribute(Enums.Attribute.Side, side)
    door:SetAttribute(Enums.Attribute.OpenY, openY)
    door:SetAttribute(Enums.Attribute.ClosedY, closedY)

    -- Botão físico na parede ao lado da porta (3.3). O cliente detecta o clique por raycast (Enums.Attribute.Interact).
    local buttonX = sign * (ROOM_HALF_W - 0.15)
    local button = part(
        Enums.Office.Button,
        Vector3.new(0.3, 0.8, 0.8),
        Vector3.new(buttonX, FLOOR_TOP + 3.5, DOOR_Z_MAX + BUTTON_OFFSET_Z),
        COLOR.button,
        model
    )
    button:SetAttribute(Enums.Attribute.Side, side)
    button:SetAttribute(
        Enums.Attribute.Interact,
        if side == Enums.Side.Left then Enums.Interact.DoorLeft else Enums.Interact.DoorRight
    )

    -- Âncora invisível na soleira: os sons posicionais "daquele lado" saem daqui (5.13)
    invisible(
        part(
            Enums.Office.SoundAnchor,
            Vector3.new(1, 1, 1),
            Vector3.new(wallX, FLOOR_TOP + 3, doorZ),
            COLOR.wall,
            model
        )
    )

    model.Parent = parent
end

local function buildCorridor(parent: Instance, side: string)
    local sign = if side == Enums.Side.Left then -1 else 1
    local model = Instance.new("Model")
    model.Name = Enums.Office.DoorModel[side]

    local zc = (DOOR_Z_MIN + DOOR_Z_MAX) / 2
    local innerW = DOOR_Z_MAX - DOOR_Z_MIN
    local outerW = innerW + 2 * WALL_T
    local xStart = ROOM_HALF_W + WALL_T -- face externa da parede da sala
    local xCenter = sign * (xStart + CORRIDOR_LENGTH / 2)
    local wallY = FLOOR_TOP + CORRIDOR_HEIGHT / 2

    part(
        "Floor",
        Vector3.new(CORRIDOR_LENGTH, WALL_T, outerW),
        Vector3.new(xCenter, FLOOR_TOP - WALL_T / 2, zc),
        COLOR.corridor,
        model
    )
    part(
        "Ceiling",
        Vector3.new(CORRIDOR_LENGTH, WALL_T, outerW),
        Vector3.new(xCenter, FLOOR_TOP + CORRIDOR_HEIGHT + WALL_T / 2, zc),
        COLOR.corridor,
        model
    )
    part(
        "WallNorth",
        Vector3.new(CORRIDOR_LENGTH, CORRIDOR_HEIGHT, WALL_T),
        Vector3.new(xCenter, wallY, DOOR_Z_MIN - WALL_T / 2),
        COLOR.corridor,
        model
    )
    part(
        "WallSouth",
        Vector3.new(CORRIDOR_LENGTH, CORRIDOR_HEIGHT, WALL_T),
        Vector3.new(xCenter, wallY, DOOR_Z_MAX + WALL_T / 2),
        COLOR.corridor,
        model
    )
    part(
        "WallEnd",
        Vector3.new(WALL_T, CORRIDOR_HEIGHT, outerW),
        Vector3.new(sign * (xStart + CORRIDOR_LENGTH + WALL_T / 2), wallY, zc),
        COLOR.corridor,
        model
    )

    -- Luz fraca ao longe: só para o corredor não ser um buraco preto (3.4)
    local lamp = invisible(
        part(
            "EndLight",
            Vector3.new(1, 1, 1),
            Vector3.new(sign * (xStart + CORRIDOR_LENGTH - 2), FLOOR_TOP + 5, zc),
            COLOR.corridor,
            model
        )
    )
    local light = Instance.new("PointLight")
    light.Brightness = 0.35
    light.Range = 14
    light.Color = COLOR.corridorLight
    light.Shadows = false
    light.Parent = lamp

    model.Parent = parent
end

local function buildDesk(parent: Instance)
    local deskTop = FLOOR_TOP + DESK_SIZE.Y
    part("Desk", DESK_SIZE, Vector3.new(0, FLOOR_TOP + DESK_SIZE.Y / 2, DESK_Z), COLOR.desk, parent)
    part("Chair", Vector3.new(1.6, 1.6, 1.6), Vector3.new(0, FLOOR_TOP + 0.8, CHAIR_Z), COLOR.chair, parent)

    -- Pontos de clique (5.11): terminal, manual e tablet. As fases 4 e 5 ligam cada um ao seu overlay.
    local monitor = part(
        "Monitor",
        Vector3.new(2.2, 1.6, 0.3),
        Vector3.new(-1.8, deskTop + 0.8, DESK_Z - 0.8),
        COLOR.monitor,
        parent
    )
    monitor:SetAttribute(Enums.Attribute.Interact, Enums.Interact.Terminal)
    local notebook = part(
        "Notebook",
        Vector3.new(1.4, 0.15, 1.8),
        Vector3.new(1.2, deskTop + 0.075, DESK_Z + 0.1),
        COLOR.notebook,
        parent
    )
    notebook:SetAttribute(Enums.Attribute.Interact, Enums.Interact.Notebook)
    local tablet =
        part("Tablet", Vector3.new(1.2, 0.1, 1.8), Vector3.new(2.7, deskTop + 0.05, DESK_Z + 0.2), COLOR.tablet, parent)
    tablet:SetAttribute(Enums.Attribute.Interact, Enums.Interact.Tablet)
end

local function buildLights(parent: Instance)
    local folder = Instance.new("Folder")
    folder.Name = Enums.Office.Lights
    for _, x in { -4, 4 } do
        local fixture = part(
            if x < 0 then "Left" else "Right",
            Vector3.new(3, 0.2, 1.5),
            Vector3.new(x, CEILING_Y - 0.1, 0),
            COLOR.lightOn,
            folder
        )
        fixture.Material = Enum.Material.Neon
        fixture.CanCollide = false
        local light = Instance.new("PointLight")
        light.Brightness = 1.5
        light.Range = 26
        light.Color = COLOR.lightOn
        light.Shadows = true
        light.Parent = fixture
    end
    folder.Parent = parent
end

-- Relógio digital na parede norte (3.4). O cliente atualiza o texto; clock_glitch (Fase 5) embaralha aqui também.
local function buildWallClock(parent: Instance)
    local clock = part(
        Enums.Office.WallClock,
        Vector3.new(2.6, 1, 0.2),
        Vector3.new(0, FLOOR_TOP + 7.5, -(ROOM_HALF_D - 0.1)),
        COLOR.monitor,
        parent
    )
    local gui = Instance.new("SurfaceGui")
    gui.Name = "SurfaceGui"
    gui.Face = Enum.NormalId.Back -- a face +Z, voltada para a cadeira
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 100
    gui.LightInfluence = 0
    local label = Instance.new("TextLabel")
    label.Name = Enums.Office.WallClockLabel
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundColor3 = Color3.new(0, 0, 0)
    label.BorderSizePixel = 0
    label.Font = Enum.Font.Code
    label.TextScaled = true
    label.TextColor3 = Color3.fromRGB(70, 255, 130)
    label.Text = Strings.clock(0)
    label.Parent = gui
    gui.Parent = clock
end

local function buildCameraAnchor(parent: Instance)
    local eye = Vector3.new(0, FLOOR_TOP + EYE_HEIGHT, CHAIR_Z)
    local anchor = invisible(part(Enums.Office.CameraAnchor, Vector3.new(0.5, 0.5, 0.5), eye, COLOR.chair, parent))
    anchor.CFrame = CFrame.lookAt(eye, eye + Vector3.new(0, 0, -1))
end

local function build()
    local existing = Workspace:FindFirstChild(Enums.Office.Model)
    if existing then
        existing:Destroy()
    end
    local office = Instance.new("Model")
    office.Name = Enums.Office.Model

    buildShell(office)
    buildDesk(office)
    buildLights(office)
    buildWallClock(office)
    buildCameraAnchor(office)

    local doors = Instance.new("Folder")
    doors.Name = Enums.Office.Doors
    buildDoor(doors, Enums.Side.Left)
    buildDoor(doors, Enums.Side.Right)
    doors.Parent = office

    local corridors = Instance.new("Folder")
    corridors.Name = Enums.Office.Corridors
    buildCorridor(corridors, Enums.Side.Left)
    buildCorridor(corridors, Enums.Side.Right)
    corridors.Parent = office

    office.Parent = Workspace
end

build()
