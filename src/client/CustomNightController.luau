--!strict
-- CustomNightController: a Custom Night (PLANEJAMENTO 3.13): o jogador escolhe 0-20 por IA e começa a noite.
-- O servidor confere se a última noite foi vencida e se os níveis estão na faixa (5.6).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local UiKit = require(script.Parent.ui.UiKit)
local CustomNightGui = require(script.Parent.ui.CustomNightGui)

-- Se o servidor não responder com NightStarted, libera o botão de novo
local PENDING_TIMEOUT_SECONDS = 3

local CustomNightController = {}

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local ui = CustomNightGui.build(playerGui)

-- Começa nos níveis da última noite: um ponto de partida conhecido
local lastNight = GameConfig.Nights[#GameConfig.Nights]
local levels: { [string]: number } = {
    square = lastNight.square,
    triangle = lastNight.triangle,
    circle = lastNight.circle,
    hexagon = lastNight.hexagon,
}
local pending = false

local function render()
    local maxLevel = GameConfig.CustomNight.maxLevel
    for enemy, row in ui.rows do
        local level = levels[enemy]
        row.value.Text = tostring(level)
        UiKit.setEnabled(row.decrease, level > 0)
        UiKit.setEnabled(row.increase, level < maxLevel)
    end
    UiKit.setEnabled(ui.start, not pending)
end

local function change(enemy: string, delta: number)
    levels[enemy] = math.clamp(levels[enemy] + delta, 0, GameConfig.CustomNight.maxLevel)
    render()
end

local function start()
    if pending then
        return
    end
    pending = true
    render()
    local custom: Types.CustomLevels = {
        square = levels.square,
        triangle = levels.triangle,
        circle = levels.circle,
        hexagon = levels.hexagon,
    }
    Remotes.get(Enums.Remote.StartNight)
        :FireServer({ night = Enums.Night.Custom, custom = custom } :: Types.StartNightPayload)
    task.delay(PENDING_TIMEOUT_SECONDS, function()
        if pending then
            pending = false
            render()
        end
    end)
end

function CustomNightController.show()
    pending = false
    render()
    ui.gui.Enabled = true
end

function CustomNightController.hide()
    ui.gui.Enabled = false
end

function CustomNightController.init()
    for enemy, row in ui.rows do
        row.decrease.Activated:Connect(function()
            if UiKit.isEnabled(row.decrease) then
                change(enemy, -1)
            end
        end)
        row.increase.Activated:Connect(function()
            if UiKit.isEnabled(row.increase) then
                change(enemy, 1)
            end
        end)
    end
    ui.maxAll.Activated:Connect(function()
        for enemy in levels do
            levels[enemy] = GameConfig.CustomNight.maxLevel
        end
        render()
    end)
    ui.start.Activated:Connect(function()
        if UiKit.isEnabled(ui.start) then
            start()
        end
    end)
    ui.back.Activated:Connect(CustomNightController.hide)
    Remotes.get(Enums.Remote.NightStarted).OnClientEvent:Connect(function()
        pending = false
        CustomNightController.hide()
    end)
    render()
end

return CustomNightController
