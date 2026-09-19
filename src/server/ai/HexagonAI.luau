--!strict
-- HexagonAI: o Hexágono Ciano, vírus de firewall (PLANEJAMENTO 3.8.4, 5.7).
-- A cada tick, d20 ≤ nível rompe uma camada. Recebe só o que usa — o RNG da sessão, se pode agir agora e o
-- que fazer ao passar no teste — então não depende de NightSession nem de FirewallService (sem ciclo).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local D20_SIDES = 20 -- regra do 3.8: sorteio de 1 a 20 contra o nível

local HexagonAI = {}
HexagonAI.__index = HexagonAI

type Fields = {
    level: number,
    rng: Random,
    canAct: () -> boolean, -- falso nos últimos segundos antes das 6 (3.1)
    breach: () -> (), -- rompe uma camada e corrompe um sistema (FirewallService)
}

export type HexagonAI = typeof(setmetatable({} :: Fields, HexagonAI))

function HexagonAI.new(level: number, rng: Random, canAct: () -> boolean, breach: () -> ()): HexagonAI
    local self: HexagonAI =
        setmetatable({ level = level, rng = rng, canAct = canAct, breach = breach } :: Fields, HexagonAI)
    return self
end

function HexagonAI.tick(self: HexagonAI)
    if self.level <= 0 or not self.canAct() then
        return
    end
    local roll = self.rng:NextInteger(1, D20_SIDES)
    local hit = roll <= self.level
    if GameConfig.Debug.logAI then
        print(`[hexagon] d20={roll} vs {self.level} → {if hit then "BREAK" else "stay"}`)
    end
    if hit then
        self.breach()
    end
end

return HexagonAI
