--!strict
-- CircleAI: o Círculo Amarelo, vírus de câmera (PLANEJAMENTO 3.8.3, 5.7).
-- A cada tick, d20 ≤ nível tenta disparar o alerta de vírus. Recebe só o que usa — o RNG da sessão, se pode
-- agir agora e o ataque (MinigameService) — então não depende de NightSession nem de serviços (sem ciclo).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local D20_SIDES = 20 -- regra do 3.8: sorteio de 1 a 20 contra o nível

local CircleAI = {}
CircleAI.__index = CircleAI

type Fields = {
    level: number,
    rng: Random,
    canAct: () -> boolean, -- falso nos últimos segundos antes das 6 (3.1)
    attack: () -> boolean, -- dispara o alerta; false se já há alerta/minigame ou o terminal está aberto
}

export type CircleAI = typeof(setmetatable({} :: Fields, CircleAI))

function CircleAI.new(level: number, rng: Random, canAct: () -> boolean, attack: () -> boolean): CircleAI
    local self: CircleAI =
        setmetatable({ level = level, rng = rng, canAct = canAct, attack = attack } :: Fields, CircleAI)
    return self
end

function CircleAI.tick(self: CircleAI)
    if self.level <= 0 or not self.canAct() then
        return
    end
    local roll = self.rng:NextInteger(1, D20_SIDES)
    if roll > self.level then
        if GameConfig.Debug.logAI then
            print(`[circle] d20={roll} vs {self.level} → stay`)
        end
        return
    end
    local started = self.attack()
    if GameConfig.Debug.logAI then
        print(`[circle] d20={roll} vs {self.level} → {if started then "ALERT" else "blocked"}`)
    end
end

return CircleAI
