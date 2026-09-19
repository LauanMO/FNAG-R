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
    primaryHover = Color3.fromRGB(150, 255, 190), -- botão principal com o mouse em cima
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
local PRIMARY_ATTRIBUTE = "Primary"
local REST_COLOR_ATTRIBUTE = "RestColor"
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

-- inst: any justificado — TextLabel e TextButton têm as mesmas propriedades de texto, mas nenhuma
-- classe base comum que as declare; o Luau não permite escrever propriedades numa união de classes.
local function applyText(inst: any, props: Props)
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

-- Botão principal habilitado: fundo verde e texto preto (ver setPrimary)
local function showsPrimary(button: TextButton): boolean
    return button:GetAttribute(PRIMARY_ATTRIBUTE) == true and UiKit.isEnabled(button)
end

local function restColor(button: TextButton): Color3
    if showsPrimary(button) then
        return UiKit.Color.ok
    end
    local rest = button:GetAttribute(REST_COLOR_ATTRIBUTE)
    return if typeof(rest) == "Color3" then rest else UiKit.Color.panel
end

-- Botão desabilitado: cinza, sem hover, sem foco de gamepad. Quem trata o clique confere isEnabled.
function UiKit.setEnabled(button: TextButton, enabled: boolean)
    button:SetAttribute(ENABLED_ATTRIBUTE, enabled)
    button.Active = enabled
    button.Selectable = enabled
    local primary = showsPrimary(button)
    button.TextColor3 = if primary then UiKit.Color.bg elseif enabled then UiKit.Color.ok else UiKit.Color.dim
    button.BorderColor3 = if primary then UiKit.Color.ok elseif enabled then UiKit.Color.border else UiKit.Color.dim
    -- Só quem já passou por setPrimary tem o fundo repintado aqui; os outros botões mantêm o hover como estava
    if button:GetAttribute(PRIMARY_ATTRIBUTE) ~= nil then
        button.BackgroundColor3 = restColor(button)
    end
end

-- Ação principal da tela (o "jogar" do menu): enquanto habilitado, fundo verde e texto preto
function UiKit.setPrimary(button: TextButton, primary: boolean)
    button:SetAttribute(PRIMARY_ATTRIBUTE, primary)
    UiKit.setEnabled(button, UiKit.isEnabled(button))
end

function UiKit.button(props: Props): TextButton
    local button = Instance.new("TextButton")
    button.AutoButtonColor = false
    applyText(button, props)
    applyBox(button, props)
    button:SetAttribute(ENABLED_ATTRIBUTE, true)
    button:SetAttribute(REST_COLOR_ATTRIBUTE, props.bg or UiKit.Color.panel)
    button.MouseEnter:Connect(function()
        if UiKit.isEnabled(button) then
            button.BackgroundColor3 = if showsPrimary(button) then UiKit.Color.primaryHover else UiKit.Color.panelHover
        end
    end)
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = restColor(button)
    end)
    return button
end

return UiKit
