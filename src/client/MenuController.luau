--!strict
-- MenuController: menu principal (PLANEJAMENTO 5.12 / B.8). Envia intenções (StartNight); o servidor decide.
-- New Game, Continue e Configurações funcionam; Tutorial e Custom Night ficam bloqueados até a Fase 7.
-- Apresentação: estática de fundo e o glitch do título (RNG 1-15; acima de 10, 400 ms de glitch a cada 5 s).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))
local Types = require(Shared:WaitForChild("Types"))
local UiKit = require(script.Parent.ui.UiKit)
local MenuGui = require(script.Parent.ui.MenuGui)
local AudioController = require(script.Parent.AudioController)
local SettingsController = require(script.Parent.SettingsController)

-- Fase 7: New Game passa a abrir a Noite 0 (tutorial), ver 3.1
local NEW_GAME_NIGHT = 1
-- Se o servidor não responder com NightStarted (não deveria acontecer), libera o menu de novo
local PENDING_TIMEOUT_SECONDS = 3

-- Glitch do título (5.12)
local GLITCH_CHECK_SECONDS = 5
local GLITCH_ROLL_MAX = 15
local GLITCH_ROLL_THRESHOLD = 10
local GLITCH_SECONDS = 0.4
local GLITCH_CHAR_CHANCE = 0.35 -- fração das letras trocadas durante o glitch
local GLITCH_JITTER = 0.01 -- deslocamento do título, em fração da tela
-- Estática de fundo
local STATIC_GRAY_MIN = 20
local STATIC_GRAY_MAX = 160
local STATIC_TRANSPARENCY_MIN = 0.9
local STATIC_TRANSPARENCY_MAX = 0.97
local SCANLINE_SPEED = 0.25 -- frações da tela por segundo

local MenuController = {}

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local menu = MenuGui.build(playerGui)
local save: Types.SaveData? = nil
local pending = false
local rng = Random.new() -- apresentação, não lógica de jogo (Apêndice C.6)
local fxConn: RBXScriptConnection? = nil
local titlePosition = menu.title.Position

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
    UiKit.setEnabled(menu.settings, not pending)
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

-- Troca parte das letras do título por caracteres de glitch
local function glitchedTitle(): string
    local chars = Strings.HUD.glitchChars
    local out: { string } = {}
    for i = 1, #Strings.Menu.title do
        local original = string.sub(Strings.Menu.title, i, i)
        if original ~= " " and rng:NextNumber() < GLITCH_CHAR_CHANCE then
            local k = rng:NextInteger(1, #chars)
            table.insert(out, string.sub(chars, k, k))
        else
            table.insert(out, original)
        end
    end
    return table.concat(out)
end

local function setTitleNormal()
    menu.title.Text = Strings.Menu.title
    menu.title.TextColor3 = UiKit.Color.ok
    menu.title.Position = titlePosition
end

-- Estática + linha de varredura a cada frame; a cada 5 s, rola o glitch do título (5.12)
local function startEffects()
    if fxConn then
        return
    end
    local sinceCheck = 0
    local glitchLeft = 0
    fxConn = RunService.RenderStepped:Connect(function(dt: number)
        local gray = rng:NextInteger(STATIC_GRAY_MIN, STATIC_GRAY_MAX)
        menu.static.BackgroundColor3 = Color3.fromRGB(gray, gray, gray)
        menu.static.BackgroundTransparency = rng:NextNumber(STATIC_TRANSPARENCY_MIN, STATIC_TRANSPARENCY_MAX)
        local y = (menu.scanline.Position.Y.Scale + dt * SCANLINE_SPEED) % 1
        menu.scanline.Position = UDim2.fromScale(0, y)

        if glitchLeft > 0 then
            glitchLeft -= dt
            if glitchLeft <= 0 then
                setTitleNormal()
            else
                menu.title.Text = glitchedTitle()
                menu.title.TextColor3 = if rng:NextNumber() < 0.5 then UiKit.Color.danger else UiKit.Color.hacker
                menu.title.Position = titlePosition
                    + UDim2.fromScale(
                        rng:NextNumber(-GLITCH_JITTER, GLITCH_JITTER),
                        rng:NextNumber(-GLITCH_JITTER, GLITCH_JITTER)
                    )
            end
        end
        sinceCheck += dt
        if sinceCheck >= GLITCH_CHECK_SECONDS then
            sinceCheck = 0
            if rng:NextInteger(1, GLITCH_ROLL_MAX) > GLITCH_ROLL_THRESHOLD then
                glitchLeft = GLITCH_SECONDS
                AudioController.play(Enums.Cue.MenuGlitch)
            end
        end
    end)
end

local function stopEffects()
    local connection = fxConn
    if connection then
        connection:Disconnect()
        fxConn = nil
    end
    setTitleNormal()
end

function MenuController.show()
    pending = false
    refresh()
    menu.gui.Enabled = true
    startEffects()
end

function MenuController.hide()
    menu.gui.Enabled = false
    stopEffects()
    SettingsController.hide()
end

function MenuController.init()
    -- Tutorial e Custom Night chegam na Fase 7; Custom Night só depois de vencer a Noite 7
    UiKit.setEnabled(menu.tutorial, false)
    UiKit.setEnabled(menu.customNight, false)

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
    menu.settings.Activated:Connect(function()
        if UiKit.isEnabled(menu.settings) then
            SettingsController.show()
        end
    end)

    MenuController.show()
end

return MenuController
