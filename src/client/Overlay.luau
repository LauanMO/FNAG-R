--!strict
-- Overlay: qual tela cheia está aberta — tablet, terminal ou manual (PLANEJAMENTO 3.5, 3.6, 3.7).
-- Só uma por vez: abrir uma pede para a anterior fechar. Com qualquer uma aberta o jogador não vê o
-- escritório, então as portas não respondem e os botões de porta do HUD somem.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared:WaitForChild("Signal"))

local Overlay = {}

-- Nome da tela aberta agora (Enums.Overlay) ou nil
Overlay.changed = Signal.new() :: Signal.Signal<string?>
-- Pede para a tela com este nome se fechar; o controller dono dela escuta
Overlay.closeRequested = Signal.new() :: Signal.Signal<string>

local current: string? = nil

function Overlay.current(): string?
    return current
end

function Overlay.isAnyOpen(): boolean
    return current ~= nil
end

-- Os controllers chamam ao abrir ou fechar a própria tela
function Overlay.set(name: string, open: boolean)
    if open then
        if current == name then
            return
        end
        local previous = current
        current = name
        if previous then
            Overlay.closeRequested:Fire(previous)
        end
        Overlay.changed:Fire(current)
    elseif current == name then
        current = nil
        Overlay.changed:Fire(nil)
    end
end

-- Fecha a tela aberta, se houver (botão B do gamepad)
function Overlay.requestClose()
    local name = current
    if name then
        Overlay.closeRequested:Fire(name)
    end
end

return Overlay
