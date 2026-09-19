--!strict
-- Commands: a lista fechada de comandos do terminal (PLANEJAMENTO 3.6, B.1).
-- O servidor aceita só o que está aqui e ecoa sempre o nome canônico, nunca o texto cru do jogador (5.9).

local Enums = require(script.Parent.Enums)

local Commands = {}

Commands.Help = "help"
Commands.Status = "status"
Commands.Clear = "clear"
Commands.FixCamera = "fix camera"
Commands.UnjamLeft = "unjam door_left"
Commands.UnjamRight = "unjam door_right"
Commands.SyncClock = "sync clock"
Commands.SealLeak = "seal power_leak"
Commands.RestoreFirewall = "restore_firewall"
Commands.ResetGenerator = "reset generator"

-- Ordem do `help` (B.1)
Commands.list = table.freeze({
    Commands.Help,
    Commands.Status,
    Commands.Clear,
    Commands.FixCamera,
    Commands.UnjamLeft,
    Commands.UnjamRight,
    Commands.SyncClock,
    Commands.SealLeak,
    Commands.RestoreFirewall,
    Commands.ResetGenerator,
})

-- Comando de reparo → sistema que ele conserta (3.8.4). cast justificado: indexado por texto em runtime
Commands.repairs = table.freeze({
    [Commands.FixCamera] = Enums.System.CameraOffline,
    [Commands.UnjamLeft] = Enums.System.DoorLeftJammed,
    [Commands.UnjamRight] = Enums.System.DoorRightJammed,
    [Commands.SyncClock] = Enums.System.ClockGlitch,
    [Commands.SealLeak] = Enums.System.PowerLeak,
} :: { [string]: string })

-- Sistema → comando de reparo, para a paleta de comandos (3.6)
Commands.repairFor = table.freeze({
    [Enums.System.CameraOffline] = Commands.FixCamera,
    [Enums.System.DoorLeftJammed] = Commands.UnjamLeft,
    [Enums.System.DoorRightJammed] = Commands.UnjamRight,
    [Enums.System.ClockGlitch] = Commands.SyncClock,
    [Enums.System.PowerLeak] = Commands.SealLeak,
} :: { [string]: string })

local known: { [string]: boolean } = {}
for _, command in Commands.list do
    known[command] = true
end

-- "  UNJAM   Door_Left " → "unjam door_left" (5.8: trim + lower; espaços internos colapsados)
function Commands.normalize(text: string): string
    local lowered = string.lower(text)
    local trimmed = string.match(lowered, "^%s*(.-)%s*$") or ""
    local collapsed = string.gsub(trimmed, "%s+", " ")
    return collapsed
end

-- Nome canônico do comando, ou nil se não estiver na lista fechada
function Commands.resolve(text: string): string?
    local key = Commands.normalize(text)
    return if known[key] then key else nil
end

return table.freeze(Commands)
