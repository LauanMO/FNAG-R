--!strict
-- Scheduler: o relógio único de uma NightSession (PLANEJAMENTO 2.4 e 5.3).
-- Roda em Heartbeat com um acumulador por tarefa. timeScale acelera testes; pause/destroy param tudo.
-- As tarefas disparam na ordem de registro — importante para partidas determinísticas com seed fixa.

local RunService = game:GetService("RunService")

export type Task = {
    name: string,
    interval: number,
    acc: number,
    once: boolean,
    fn: () -> (),
}

local Scheduler = {}
Scheduler.__index = Scheduler

type Fields = {
    tasks: { Task }, -- ordem de registro
    byName: { [string]: Task },
    timeScale: number,
    paused: boolean,
    destroyed: boolean,
    elapsed: number, -- segundos escalados desde a criação
    conn: RBXScriptConnection?,
}

export type Scheduler = typeof(setmetatable({} :: Fields, Scheduler))

function Scheduler.new(timeScale: number): Scheduler
    local self: Scheduler = setmetatable(
        {
            tasks = {},
            byName = {},
            timeScale = timeScale,
            paused = false,
            destroyed = false,
            elapsed = 0,
            conn = nil,
        } :: Fields,
        Scheduler
    )
    self.conn = RunService.Heartbeat:Connect(function(dt: number)
        self:step(dt)
    end)
    return self
end

function Scheduler.step(self: Scheduler, dt: number)
    if self.paused or self.destroyed then
        return
    end
    local scaled = dt * self.timeScale
    self.elapsed += scaled
    -- snapshot: callbacks podem registrar/remover tarefas durante a iteração
    local snapshot = table.clone(self.tasks)
    for _, entry in snapshot do
        if self.destroyed then
            return
        end
        if self.byName[entry.name] ~= entry then
            continue -- removida ou substituída por outra tarefa neste mesmo frame
        end
        entry.acc += scaled
        -- while, não if: se o frame demorou, não perde ticks (5.3)
        while entry.acc >= entry.interval do
            entry.acc -= entry.interval
            if entry.once then
                self:remove(entry.name)
                entry.fn()
                break
            end
            entry.fn()
            if self.destroyed or self.byName[entry.name] ~= entry then
                break
            end
        end
    end
end

-- Tarefa repetida: chama fn a cada `interval` segundos (escalados). Substitui uma tarefa de mesmo nome.
function Scheduler.every(self: Scheduler, name: string, interval: number, fn: () -> ())
    assert(interval > 0, `Scheduler: intervalo inválido para "{name}"`)
    self:remove(name)
    local entry: Task = { name = name, interval = interval, acc = 0, once = false, fn = fn }
    table.insert(self.tasks, entry)
    self.byName[name] = entry
end

-- Tarefa única: chama fn uma vez depois de `delay` segundos (escalados) e se remove.
function Scheduler.after(self: Scheduler, name: string, delay: number, fn: () -> ())
    assert(delay >= 0, `Scheduler: atraso inválido para "{name}"`)
    self:remove(name)
    local entry: Task = { name = name, interval = delay, acc = 0, once = true, fn = fn }
    table.insert(self.tasks, entry)
    self.byName[name] = entry
end

function Scheduler.setInterval(self: Scheduler, name: string, interval: number)
    local entry = self.byName[name]
    if entry then
        entry.interval = interval
    end
end

function Scheduler.has(self: Scheduler, name: string): boolean
    return self.byName[name] ~= nil
end

function Scheduler.remove(self: Scheduler, name: string)
    local entry = self.byName[name]
    if not entry then
        return
    end
    self.byName[name] = nil
    local index = table.find(self.tasks, entry)
    if index then
        table.remove(self.tasks, index)
    end
end

function Scheduler.pause(self: Scheduler)
    self.paused = true
end

function Scheduler.resume(self: Scheduler)
    self.paused = false
end

-- Nada sobrevive à sessão: desconecta o Heartbeat e esquece todas as tarefas.
function Scheduler.destroy(self: Scheduler)
    if self.destroyed then
        return
    end
    self.destroyed = true
    local conn = self.conn
    if conn then
        conn:Disconnect()
        self.conn = nil
    end
    self.tasks = {}
    self.byName = {}
end

return Scheduler
