--!strict
-- DawnGui: tela de amanhecer (PLANEJAMENTO 3.10 / 5.12): "6:00 AM" grande, depois "NOITE N CONCLUÍDA".

local UiKit = require(script.Parent.UiKit)

export type Dawn = {
    gui: ScreenGui,
    clock: TextLabel,
    message: TextLabel,
}

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

    gui.Parent = parent
    return { gui = gui, clock = clock, message = message }
end

return DawnGui
