--!strict
-- TabletGui: o Global Security Node Map (PLANEJAMENTO 3.5, 5.12, B.5). Tela cheia, por cima do HUD.
-- É uma topologia de rede, não um sistema de vídeo: nós com nome, botão de ping, visor de status e rodapé.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local Strings = require(Shared:WaitForChild("Strings"))
local UiKit = require(script.Parent.UiKit)

export type NodeView = {
    frame: Frame,
    name: TextLabel,
    state: TextLabel,
}

export type Tablet = {
    gui: ScreenGui,
    background: Frame,
    scanline: Frame,
    nodes: { [string]: NodeView },
    pingButton: TextButton,
    progress: Frame,
    progressFill: Frame,
    status: TextLabel,
    battery: TextLabel,
    footerFirewall: TextLabel,
    footerPower: TextLabel,
    closeButton: TextButton,
}

-- Posições dos nós dentro do mapa (3.5): palco em cima, corredores no meio, portas e escritório embaixo,
-- sala de servidores no rodapé do mapa
local NODE_LAYOUT: { { node: string, x: number, y: number } } = {
    { node = Enums.Node.CAM1, x = 0.5, y = 0.1 },
    { node = Enums.Node.CAM2, x = 0.24, y = 0.36 },
    { node = Enums.Node.CAM3, x = 0.76, y = 0.36 },
    { node = Enums.Node.DoorLeft, x = 0.14, y = 0.62 },
    { node = Enums.Node.Office, x = 0.5, y = 0.62 },
    { node = Enums.Node.DoorRight, x = 0.86, y = 0.62 },
    { node = Enums.Node.CAM4, x = 0.5, y = 0.88 },
}
local NODE_SIZE = UDim2.fromScale(0.28, 0.16)
local NODE_IDLE_TRANSPARENCY = 0.85

local TabletGui = {}

local function buildNode(parent: Instance, node: string, x: number, y: number): NodeView
    local C = UiKit.Color
    local frame = UiKit.frame({
        name = node,
        parent = parent,
        position = UDim2.fromScale(x, y),
        anchor = Vector2.new(0.5, 0.5),
        size = NODE_SIZE,
        bg = C.panel,
        border = true,
    })
    frame.BackgroundTransparency = NODE_IDLE_TRANSPARENCY
    local name = UiKit.label({
        name = "Name",
        parent = frame,
        position = UDim2.fromScale(0.05, 0.05),
        size = UDim2.fromScale(0.9, 0.5),
        text = Strings.NodeName[node] or node,
        maxTextSize = 18,
    })
    local state = UiKit.label({
        name = "State",
        parent = frame,
        position = UDim2.fromScale(0.05, 0.55),
        size = UDim2.fromScale(0.9, 0.4),
        color = C.dim,
        maxTextSize = 16,
    })
    return { frame = frame, name = name, state = state }
end

function TabletGui.build(parent: Instance): Tablet
    local C = UiKit.Color
    local gui = UiKit.screenGui("TabletGui", 15, true)

    -- Active: o tablet engole cliques e toques; nada passa para os botões 3D nem para o HUD embaixo
    local background = UiKit.frame({
        name = "Background",
        parent = gui,
        position = UDim2.fromScale(0, 0),
        size = UDim2.fromScale(1, 1),
        bg = Color3.fromRGB(4, 8, 10),
    })
    background.Active = true

    -- Estática animada (3.5): uma linha varrendo a tela; o TabletController move
    local scanline = UiKit.frame({
        name = "Scanline",
        parent = gui,
        position = UDim2.fromScale(0, 0),
        size = UDim2.fromScale(1, 0.006),
        bg = C.hacker,
    })
    scanline.BackgroundTransparency = 0.75

    UiKit.label({
        name = "Title",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.06),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.7, 0.06),
        text = Strings.Tablet.title,
        color = C.hacker,
        maxTextSize = 28,
    })
    local closeButton = UiKit.button({
        name = "Close",
        parent = gui,
        position = UDim2.fromScale(0.985, 0.02),
        anchor = Vector2.new(1, 0),
        size = UDim2.fromScale(0.16, 0.14), -- ≥ 48 px no iPhone SE (5.11)
        bg = C.panel,
        border = true,
        text = Strings.Tablet.close,
        color = C.ok,
        maxTextSize = 22,
    })

    local map = UiKit.frame({
        name = "Map",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.39),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.92, 0.52),
        border = true,
    })
    local nodes: { [string]: NodeView } = {}
    for _, entry in NODE_LAYOUT do
        nodes[entry.node] = buildNode(map, entry.node, entry.x, entry.y)
    end

    local pingButton = UiKit.button({
        name = "Ping",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.73),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.62, 0.13), -- ≈ 49 px no iPhone SE (5.11)
        bg = C.panel,
        border = true,
        text = Strings.Tablet.pingButton,
        color = C.ok,
        maxTextSize = 26,
    })
    local progress = UiKit.frame({
        name = "Progress",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.81),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.62, 0.012),
        bg = C.panel,
        border = true,
        visible = false,
    })
    local progressFill = UiKit.frame({
        name = "Fill",
        parent = progress,
        position = UDim2.fromScale(0, 0),
        size = UDim2.fromScale(0, 1),
        bg = C.hacker,
    })
    local status = UiKit.label({
        name = "Status",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.85),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.9, 0.045),
        text = Strings.Tablet.statusIdle,
        color = C.text,
        maxTextSize = 20,
    })
    local battery = UiKit.label({
        name = "Battery",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.895),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.9, 0.04),
        color = C.danger,
        visible = false,
        maxTextSize = 18,
    })
    local footerFirewall = UiKit.label({
        name = "FooterFirewall",
        parent = gui,
        position = UDim2.fromScale(0.04, 0.945),
        size = UDim2.fromScale(0.45, 0.045),
        color = C.dim,
        xAlign = Enum.TextXAlignment.Left,
        maxTextSize = 20,
    })
    local footerPower = UiKit.label({
        name = "FooterPower",
        parent = gui,
        position = UDim2.fromScale(0.96, 0.945),
        anchor = Vector2.new(1, 0),
        size = UDim2.fromScale(0.45, 0.045),
        color = C.dim,
        xAlign = Enum.TextXAlignment.Right,
        maxTextSize = 20,
    })

    gui.Parent = parent
    return {
        gui = gui,
        background = background,
        scanline = scanline,
        nodes = nodes,
        pingButton = pingButton,
        progress = progress,
        progressFill = progressFill,
        status = status,
        battery = battery,
        footerFirewall = footerFirewall,
        footerPower = footerPower,
        closeButton = closeButton,
    }
end

return TabletGui
