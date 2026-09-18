--!strict
-- Signal: evento simples, síncrono e determinístico (PLANEJAMENTO 2.8 — sem frameworks).
-- Handlers rodam na ordem de conexão, no mesmo frame do Fire, sem yield. Um handler que precisa
-- esperar faz task.spawn por conta própria.

export type Connection = {
    Connected: boolean,
    Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
    Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
    Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
    Fire: (self: Signal<T...>, T...) -> (),
    Destroy: (self: Signal<T...>) -> (),
}

type Handler = {
    fn: (...any) -> (),
    once: boolean,
    connected: boolean,
}

type SignalImpl = {
    _handlers: { Handler },
}

type ConnectionImpl = {
    Connected: boolean,
    _signal: SignalImpl,
    _handler: Handler,
}

local Connection = {}
Connection.__index = Connection

function Connection.Disconnect(self: ConnectionImpl)
    if not self.Connected then
        return
    end
    self.Connected = false
    self._handler.connected = false
    local index = table.find(self._signal._handlers, self._handler)
    if index then
        table.remove(self._signal._handlers, index)
    end
end

local Signal = {}
Signal.__index = Signal

local function connect(self: SignalImpl, fn: (...any) -> (), once: boolean): Connection
    local handler: Handler = { fn = fn, once = once, connected = true }
    table.insert(self._handlers, handler)
    local connection = setmetatable({ Connected = true, _signal = self, _handler = handler }, Connection)
    -- cast justificado: a interface pública (Connection) esconde os campos privados da implementação
    return (connection :: any) :: Connection
end

function Signal.Connect(self: SignalImpl, fn: (...any) -> ()): Connection
    return connect(self, fn, false)
end

function Signal.Once(self: SignalImpl, fn: (...any) -> ()): Connection
    return connect(self, fn, true)
end

function Signal.Fire(self: SignalImpl, ...: any)
    -- snapshot: handlers podem (des)conectar durante o disparo
    local snapshot = table.clone(self._handlers)
    for _, handler in snapshot do
        if not handler.connected then
            continue
        end
        if handler.once then
            handler.connected = false
            local index = table.find(self._handlers, handler)
            if index then
                table.remove(self._handlers, index)
            end
        end
        handler.fn(...)
    end
end

function Signal.Destroy(self: SignalImpl)
    for _, handler in self._handlers do
        handler.connected = false
    end
    table.clear(self._handlers)
end

function Signal.new<T...>(): Signal<T...>
    local self: SignalImpl = { _handlers = {} }
    -- cast justificado: a interface pública é o tipo genérico Signal<T...>;
    -- a implementação é a tabela com metatable
    return (setmetatable(self, Signal) :: any) :: Signal<T...>
end

return Signal
