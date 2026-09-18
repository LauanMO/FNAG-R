--!strict
-- PatrolAI: Quadrado e Triângulo — a mesma classe, dois parâmetros (PLANEJAMENTO 2.6, 3.8.1, 3.8.2, 5.7).
-- Caminho: palco → corredor → soleira. Na soleira, porta fechada = rebate para o palco; aberta = jumpscare.
-- Teste de movimento: d20 ≤ nível (3.8). Nível 0 = desligada; 20 = age em todo tick.
-- A IA enxerga a sessão pela interface Types.AIHost — não faz require de NightSession (sem ciclo).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Enums = require(Shared.Enums)
local Types = require(Shared.Types)

local D20_SIDES = 20 -- regra do 3.8: sorteio de 1 a 20 contra o nível

local PatrolAI = {}
PatrolAI.__index = PatrolAI

export type Config = {
    tickSeconds: number,
    side: Types.Side,
    path: { string }, -- nós do radar; o último é a soleira (DOOR_L / DOOR_R)
}

type Fields = {
    host: Types.AIHost,
    name: Types.Enemy,
    cfg: Config,
    level: number,
    position: number, -- índice em cfg.path; #path = soleira
}

export type PatrolAI = typeof(setmetatable({} :: Fields, PatrolAI))

function PatrolAI.new(host: Types.AIHost, name: Types.Enemy, cfg: Config, level: number): PatrolAI
    local self: PatrolAI =
        setmetatable({ host = host, name = name, cfg = cfg, level = level, position = 1 } :: Fields, PatrolAI)
    return self
end

-- Nó atual, para o radar (Fase 4)
function PatrolAI.node(self: PatrolAI): string
    return self.cfg.path[self.position]
end

function PatrolAI.isAtDoor(self: PatrolAI): boolean
    return self.position == #self.cfg.path
end

local function log(self: PatrolAI, roll: number, action: string)
    if GameConfig.Debug.logAI then
        print(`[{self.name}] d20={roll} vs {self.level} → {action}`)
    end
end

function PatrolAI.tick(self: PatrolAI)
    if self.level <= 0 then
        return
    end
    if self.host:inDawnGrace() then
        return -- 3.1: ninguém age nos últimos segundos antes das 6
    end
    local roll = self.host.rng:NextInteger(1, D20_SIDES)
    if roll > self.level then
        log(self, roll, "stay")
        return
    end

    local side: Types.Side = self.cfg.side -- anotado: o checador alarga o literal para string sem isto
    if not self:isAtDoor() then
        self.position += 1
        log(self, roll, `move to {self:node()}`)
        if self:isAtDoor() then
            -- Telegraph (3.5b): som + silhueta. O jogador tem pelo menos um tick inteiro para reagir.
            self.host:fireCue(side, Enums.EnemyCue.Arrival)
            self.host:setEnemyVisual(side, true)
        end
        return
    end

    local door = if side == Enums.Side.Left then self.host.state.doors.left else self.host.state.doors.right
    if door.closed then
        self.position = 1
        log(self, roll, "repelled")
        self.host:fireCue(side, Enums.EnemyCue.Repelled)
        self.host:setEnemyVisual(side, false)
    else
        log(self, roll, "ATTACK")
        self.host:lose(self.name)
    end
end

return PatrolAI
