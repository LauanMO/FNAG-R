--!strict
-- MenuController: menu principal (PLANEJAMENTO 5.12 / B.8). Envia intenções (StartNight); o servidor decide.
-- Fase 1: New Game e Continue (save em memória). Tutorial, Custom Night e Configurações entram nas Fases 6 e 7.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))
local Types = require(Shared:WaitForChild("Types"))
local UiKit = require(script.Parent.ui.UiKit)
local MenuGui = require(script.Parent.ui.MenuGui)

-- Fase 7: New Game passa a abrir a Noite 0 (tutorial), ver 3.1
local NEW_GAME_NIGHT = 1
-- Se o servidor não responder com NightStarted (não deveria acontecer), libera o menu de novo
local PENDING_TIMEOUT_SECONDS = 3

local MenuController = {}

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local menu = MenuGui.build(playerGui)
local save: Types.SaveData? = nil
local pending = false

local function canContinue(data: Types.SaveData): boolean
    return data.currentNight > NEW_GAME_NIGHT and GameConfig.Nights[data.currentNight] ~= nil
end

local function refresh()
    local data = save
    if data and canContinue(data) then
        menu.continueBtn.Text = string.format(Strings.Menu.continueNight, data.currentNight)
        UiKit.setEnabled(menu.continueBtn, not pending)
    else
        menu.continueBtn.Text = Strings.Menu.continueGame
        UiKit.setEnabled(menu.continueBtn, false)
    end
    UiKit.setEnabled(menu.newGame, data ~= nil and not pending)
end

local function startNight(night: number)
    if pending then
        return
    end
    pending = true
    refresh()
    Remotes.get(Enums.Remote.StartNight):FireServer({ night = night } :: Types.StartNightPayload)
    task.delay(PENDING_TIMEOUT_SECONDS, function()
        if pending then
            pending = false
            refresh()
        end
    end)
end

function MenuController.show()
    pending = false
    refresh()
    menu.gui.Enabled = true
end

function MenuController.hide()
    menu.gui.Enabled = false
end

function MenuController.init()
    -- Botões de fases futuras
    menu.tutorial.Text = string.format(Strings.Menu.comingSoon, Strings.Menu.tutorial)
    menu.settings.Text = string.format(Strings.Menu.comingSoon, Strings.Menu.settings)
    UiKit.setEnabled(menu.tutorial, false)
    UiKit.setEnabled(menu.customNight, false) -- bloqueada até vencer a Noite 7 (Fase 7)
    UiKit.setEnabled(menu.settings, false)

    Remotes.get(Enums.Remote.SaveLoaded).OnClientEvent:Connect(function(payload: Types.SaveLoadedPayload)
        save = payload.save
        refresh()
    end)
    Remotes.get(Enums.Remote.NightStarted).OnClientEvent:Connect(function()
        pending = false
        MenuController.hide()
    end)

    menu.newGame.Activated:Connect(function()
        if UiKit.isEnabled(menu.newGame) then
            startNight(NEW_GAME_NIGHT)
        end
    end)
    menu.continueBtn.Activated:Connect(function()
        local data = save
        if data and UiKit.isEnabled(menu.continueBtn) then
            startNight(data.currentNight)
        end
    end)

    MenuController.show()
end

return MenuController
