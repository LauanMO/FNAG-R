--!strict
-- Bootstrap do servidor (PLANEJAMENTO 5.1). Ordem: Remotes primeiro, depois os serviços.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)
local NightService = require(script.Parent.NightService)

Remotes.init()
NightService.init()

if GameConfig.Debug.logSession then
    print("GEOMETRY OS boot") -- critério de aceite da Fase 0
end
