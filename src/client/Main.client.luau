--!strict
-- Bootstrap do cliente (PLANEJAMENTO 5.1): controllers, sala, menu e handshake com o servidor.
-- Ordem: input, áudio e o glitch de relógio primeiro (os outros dependem), depois câmera/sala, HUD, portas,
-- telas cheias (tablet, terminal, manual), o palco 3D do menu e o menu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local InputController = require(script.Parent.InputController)
local AudioController = require(script.Parent.AudioController)
local ClockGlitch = require(script.Parent.ClockGlitch)
local OfficeCamera = require(script.Parent.OfficeCamera)
local OfficeController = require(script.Parent.OfficeController)
local HudController = require(script.Parent.HudController)
local DoorController = require(script.Parent.DoorController)
local EnemyVisual = require(script.Parent.EnemyVisual)
local JumpscareController = require(script.Parent.JumpscareController)
local TabletController = require(script.Parent.TabletController)
local TerminalController = require(script.Parent.TerminalController)
local NotebookController = require(script.Parent.NotebookController)
local SonarController = require(script.Parent.SonarController)
local SettingsController = require(script.Parent.SettingsController)
local CustomNightController = require(script.Parent.CustomNightController)
local TutorialController = require(script.Parent.TutorialController)
local MenuScene = require(script.Parent.MenuScene)
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

InputController.init()
AudioController.init()
ClockGlitch.init()
OfficeCamera.init()
OfficeController.init()
HudController.init()
DoorController.init()
EnemyVisual.init()
JumpscareController.init()
TabletController.init()
TerminalController.init()
NotebookController.init()
SonarController.init()
SettingsController.init()
CustomNightController.init()
TutorialController.init()
MenuScene.init()
MenuController.init()
HudController.dawnFinished:Connect(function()
    MenuController.show()
end)
JumpscareController.menuRequested:Connect(function()
    MenuController.show()
end)

-- Handshake: o SaveLoaded do PlayerAdded pode ter sido enviado antes destes scripts existirem (5.6)
Remotes.get(Enums.Remote.ClientReady):FireServer({})
