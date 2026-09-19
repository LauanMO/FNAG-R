--!strict
-- DawnGui: tela de amanhecer (PLANEJAMENTO 3.10, 5.12, B.7): "6:00 AM" grande, depois "NOITE N CONCLUÍDA".
-- Depois da última noite, os créditos: SIMULAÇÃO ENCERRADA.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local UiKit = require(script.Parent.UiKit)

export type Dawn = {
    gui: ScreenGui,
    clock: TextLabel,
    message: TextLabel,
    credits: Frame,
}

local CREDIT_LINE_HEIGHT = 0.1 -- fração do quadro dos créditos

local DawnGui = {}

function DawnGui.build(parent: Instance): Dawn
    local C = UiKit.Color
    local gui = UiKit.screenGui("DawnGui", 30, true)

    UiKit.frame({
        name = "Background",
        parent = gui,
        position = UDim2.fromScale(0, 0),
        size = UDim2.fromScale(1, 1),
        bg = C.bg,
    })
    local clock = UiKit.label({
        name = "Clock",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.42),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.8, 0.16),
        maxTextSize = 96,
    })
    local message = UiKit.label({
        name = "Message",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.58),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.8, 0.07),
        color = C.ok,
        visible = false,
        maxTextSize = 36,
    })

    -- B.7: depois da Noite 7
    local credits = UiKit.frame({
        name = "Credits",
        parent = gui,
        position = UDim2.fromScale(0.5, 0.5),
        anchor = Vector2.new(0.5, 0.5),
        size = UDim2.fromScale(0.8, 0.7),
        visible = false,
    })
    UiKit.label({
        name = "Title",
        parent = credits,
        position = UDim2.fromScale(0, 0),
        size = UDim2.fromScale(1, 0.2),
        text = Strings.Credits.title,
        color = C.ok,
        maxTextSize = 56,
    })
    for i, text in Strings.Credits.lines do
        UiKit.label({
            name = `Line{i}`,
            parent = credits,
            position = UDim2.fromScale(0, 0.3 + (i - 1) * (CREDIT_LINE_HEIGHT + 0.04)),
            size = UDim2.fromScale(1, CREDIT_LINE_HEIGHT),
            text = text,
            color = if i == 1 then C.text else C.dim,
            maxTextSize = 30,
        })
    end

    gui.Parent = parent
    return { gui = gui, clock = clock, message = message, credits = credits }
end

return DawnGui
