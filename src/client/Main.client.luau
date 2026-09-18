--!strict
-- Bootstrap do cliente (PLANEJAMENTO 5.1): controllers, menu e handshake com o servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local HudController = require(script.Parent.HudController)
local MenuController = require(script.Parent.MenuController)

-- O jogo tem HUD própria; a CoreGui padrão (chat, lista de jogadores, mochila) atrapalha o clima.
-- pcall justificado: SetCoreGuiEnabled falha enquanto a CoreGui não carregou; tentamos algumas vezes.
task.spawn(function()
    for _ = 1, 10 do
        local ok = pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
        end)
        if ok then
            return
        end
        task.wait(0.5)
    end
end)

HudController.init()
MenuController.init()
HudController.dawnFinished:Connect(function()
    MenuController.show()
end)

-- Handshake: o SaveLoaded do PlayerAdded pode ter sido enviado antes destes scripts existirem (5.6)
Remotes.get(Enums.Remote.ClientReady):FireServer({})
