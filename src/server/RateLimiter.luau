--!strict
-- RateLimiter: janela deslizante de 1s por jogador (PLANEJAMENTO 5.9).
-- Uso: ToggleDoor 10/s (Fase 2), TerminalCommand 5/s (Fase 5). Excedeu → o pedido é ignorado em silêncio.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Fields = {
    maxPerSecond: number,
    stamps: { [Player]: { number } },
}

export type RateLimiter = typeof(setmetatable({} :: Fields, RateLimiter))

function RateLimiter.new(maxPerSecond: number): RateLimiter
    local self: RateLimiter = setmetatable({ maxPerSecond = maxPerSecond, stamps = {} } :: Fields, RateLimiter)
    return self
end

function RateLimiter.allow(self: RateLimiter, player: Player): boolean
    local now = os.clock()
    local recent: { number } = {}
    local previous = self.stamps[player]
    if previous then
        for _, stamp in previous do
            if now - stamp < 1 then
                table.insert(recent, stamp)
            end
        end
    end
    local allowed = #recent < self.maxPerSecond
    if allowed then
        table.insert(recent, now)
    end
    self.stamps[player] = recent
    return allowed
end

function RateLimiter.forget(self: RateLimiter, player: Player)
    self.stamps[player] = nil
end

return RateLimiter
