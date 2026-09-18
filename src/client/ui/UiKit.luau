--!strict
-- UiKit: helpers de UI com a estética do jogo (PLANEJAMENTO 5.12): fonte monoespaçada, fundo preto,
-- verde/ciano/âmbar/vermelho como cores semânticas, bordas de 1px, sem gradientes.
-- Posições e tamanhos sempre em Scale, nunca em Offset (5.11).

local UiKit = {}

UiKit.Font = Enum.Font.Code

UiKit.Color = table.freeze({
    bg = Color3.fromRGB(0, 0, 0),
    panel = Color3.fromRGB(8, 10, 8),
    panelHover = Color3.fromRGB(18, 30, 20),
    text = Color3.fromRGB(210, 215, 210),
    dim = Color3.fromRGB(95, 100, 95),
    border = Color3.fromRGB(60, 95, 65),
    ok = Color3.fromRGB(70, 255, 130), -- verde: sistema ok / terminal
    hacker = Color3.fromRGB(70, 220, 255), -- ciano: Hexágono, intrusão
    warn = Color3.fromRGB(255, 185, 60), -- âmbar: aviso
    danger = Color3.fromRGB(255, 70, 70), -- vermelho: perigo
})

export type Props = {
    name: string,
    parent: Instance,
    position: UDim2,
    size: UDim2,
    anchor: Vector2?,
    bg: Color3?, -- nil = fundo transparente
    border: boolean?,
    visible: boolean?,
    zIndex: number?,
    text: string?,
    color: Color3?,
    xAlign: Enum.TextXAlignment?,
    yAlign: Enum.TextYAlignment?,
    scaled: boolean?, -- TextScaled; padrão true
    maxTextSize: number?, -- limita o TextScaled em telas grandes
}

local ENABLED_ATTRIBUTE = "Enabled"
local FIXED_TEXT_SIZE = 18 -- só vale quando scaled = false

local function applyBox(inst: GuiObject, props: Props)
    inst.Name = props.name
    inst.Position = props.position
    inst.Size = props.size
    inst.AnchorPoint = props.anchor or Vector2.zero
    local bg = props.bg
    if bg then
        inst.BackgroundColor3 = bg
        inst.BackgroundTransparency = 0
    else
        inst.BackgroundTransparency = 1
    end
    inst.BorderSizePixel = if props.border then 1 else 0
    inst.BorderColor3 = UiKit.Color.border
    inst.BorderMode = Enum.BorderMode.Inset
    inst.Visible = props.visible ~= false
    inst.ZIndex = props.zIndex or 1
    inst.Parent = props.parent
end

local function applyText(inst: TextLabel | TextButton, props: Props)
    inst.Font = UiKit.Font
    inst.Text = props.text or ""
    inst.TextColor3 = props.color or UiKit.Color.text
    inst.TextScaled = props.scaled ~= false
    inst.TextSize = FIXED_TEXT_SIZE
    inst.TextXAlignment = props.xAlign or Enum.TextXAlignment.Center
    inst.TextYAlignment = props.yAlign or Enum.TextYAlignment.Center
    local maxTextSize = props.maxTextSize
    if maxTextSize then
        local constraint = Instance.new("UITextSizeConstraint")
        constraint.MaxTextSize = maxTextSize
        constraint.Parent = inst
    end
end

function UiKit.screenGui(name: string, displayOrder: number, ignoreInset: boolean): ScreenGui
    local gui = Instance.new("ScreenGui")
    gui.Name = name
    gui.DisplayOrder = displayOrder
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = ignoreInset
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Enabled = false
    return gui
end

function UiKit.frame(props: Props): Frame
    local frame = Instance.new("Frame")
    applyBox(frame, props)
    return frame
end

function UiKit.label(props: Props): TextLabel
    local label = Instance.new("TextLabel")
    applyText(label, props)
    applyBox(label, props)
    return label
end

function UiKit.isEnabled(button: TextButton): boolean
    return button:GetAttribute(ENABLED_ATTRIBUTE) == true
end

-- Botão desabilitado: cinza, sem hover, sem foco de gamepad. Quem trata o clique confere isEnabled.
function UiKit.setEnabled(button: TextButton, enabled: boolean)
    button:SetAttribute(ENABLED_ATTRIBUTE, enabled)
    button.Active = enabled
    button.Selectable = enabled
    button.TextColor3 = if enabled then UiKit.Color.ok else UiKit.Color.dim
    button.BorderColor3 = if enabled then UiKit.Color.border else UiKit.Color.dim
end

function UiKit.button(props: Props): TextButton
    local button = Instance.new("TextButton")
    button.AutoButtonColor = false
    applyText(button, props)
    applyBox(button, props)
    button:SetAttribute(ENABLED_ATTRIBUTE, true)
    local restingColor = props.bg or UiKit.Color.panel
    button.MouseEnter:Connect(function()
        if UiKit.isEnabled(button) then
            button.BackgroundColor3 = UiKit.Color.panelHover
        end
    end)
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = restingColor
    end)
    return button
end

return UiKit
