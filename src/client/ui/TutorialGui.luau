--!strict
-- TutorialGui: a Unidade de Assistência de Debug e a caixa de diálogo da Noite 0 (PLANEJAMENTO 3.12, 5.12).
-- Duas disposições: na abertura, a sala escurece e a figura cinza aparece no centro; nos passos seguintes, a
-- caixa vira um aviso no topo da tela, por cima do tablet e do terminal, para o jogador ler enquanto usa.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local UiKit = require(script.Parent.UiKit)

export type Tutorial = {
    gui: ScreenGui,
    intro: Frame, -- escurece a sala na abertura
    figureParts: { Frame }, -- cabeça, corpo e olhos da figura, para o fade-in
    box: TextButton, -- a caixa inteira é clicável: clicar avança
    speaker: TextLabel,
    text: TextLabel,
    hint: TextLabel, -- ▼ quando um clique continua
}

local FIGURE_GRAY = Color3.fromRGB(120, 120, 126)
local FIGURE_EYES = Color3.fromRGB(20, 20, 24)
local INTRO_DIM_TRANSPARENCY = 0.35

local TutorialGui = {}

-- Transparência final de cada parte da figura, depois do fade-in
TutorialGui.figureTransparency = 0

local function rounded(frame: Frame, radius: number)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(radius, 0)
    corner.Parent = frame
end

function TutorialGui.build(parent: Instance): Tutorial
    local C = UiKit.Color
    -- Acima do HUD e das telas cheias (tablet 15, terminal 16, manual 17): o tutorial fala por cima delas
    local gui = UiKit.screenGui("TutorialGui", 18, true)

    local intro = UiKit.frame({
        name = "Intro",
        parent = gui,
        position = UDim2.fromScale(0, 0),
        size = UDim2.fromScale(1, 1),
        bg = C.bg,
        visible = false,
    })
    intro.BackgroundTransparency = INTRO_DIM_TRANSPARENCY
    intro.Active = true

    -- A figura cinza (3.12): blocos simples, sem arte
    local head = UiKit.frame({
        name = "Head",
        parent = intro,
        position = UDim2.fromScale(0.5, 0.2),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.09, 0.16),
        bg = FIGURE_GRAY,
    })
    rounded(head, 0.5)
    local body = UiKit.frame({
        name = "Body",
        parent = intro,
        position = UDim2.fromScale(0.5, 0.29),
        anchor = Vector2.new(0.5, 0),
        size = UDim2.fromScale(0.16, 0.34),
        bg = FIGURE_GRAY,
    })
    rounded(body, 0.2)
    local figureParts: { Frame } = { head, body }
    for _, dx in { -1, 1 } do
        local eye = UiKit.frame({
            name = "Eye",
            parent = head,
            position = UDim2.fromScale(0.5 + dx * 0.2, 0.45),
            anchor = Vector2.new(0.5, 0.5),
            size = UDim2.fromScale(0.16, 0.1),
            bg = FIGURE_EYES,
        })
        table.insert(figureParts, eye)
    end

    local box = UiKit.button({
        name = "Box",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.97),
        anchor = Vector2.new(0.5, 1),
        size = UDim2.fromScale(0.9, 0.22),
        bg = C.panel,
        border = true,
        text = "",
        visible = false,
        zIndex = 2,
    })
    local speaker = UiKit.label({
        name = "Speaker",
        parent = box,
        position = UDim2.fromScale(0.02, 0.04),
        size = UDim2.fromScale(0.8, 0.22),
        text = Strings.Tutorial.speaker,
        color = C.dim,
        xAlign = Enum.TextXAlignment.Left,
        maxTextSize = 16,
    })
    local text = UiKit.label({
        name = "Text",
        parent = box,
        position = UDim2.fromScale(0.02, 0.28),
        size = UDim2.fromScale(0.9, 0.66),
        color = C.ok,
        xAlign = Enum.TextXAlignment.Left,
        yAlign = Enum.TextYAlignment.Top,
        maxTextSize = 26,
    })
    text.TextWrapped = true
    local hint = UiKit.label({
        name = "Hint",
        parent = box,
        position = UDim2.fromScale(0.98, 0.95),
        anchor = Vector2.new(1, 1),
        size = UDim2.fromScale(0.06, 0.3),
        text = Strings.Tutorial.continueHint,
        color = C.ok,
        visible = false,
        maxTextSize = 22,
    })

    gui.Parent = parent
    return {
        gui = gui,
        intro = intro,
        figureParts = figureParts,
        box = box,
        speaker = speaker,
        text = text,
        hint = hint,
    }
end

return TutorialGui
