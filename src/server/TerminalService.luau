--!strict
-- TerminalService: parse, validação e despacho dos comandos do terminal (PLANEJAMENTO 3.6, 5.5, 5.8).
-- Lista fechada (Commands), rate limit e eco canônico: nunca ecoa o texto cru do jogador (5.9).
-- Não decide efeitos: delega para FirewallService e NightSession.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Commands = require(Shared.Commands)
local GameConfig = require(Shared.GameConfig)
local Enums = require(Shared.Enums)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local NightSession = require(script.Parent.NightSession)
local FirewallService = require(script.Parent.FirewallService)
local RateLimiter = require(script.Parent.RateLimiter)

type Session = NightSession.NightSession
type Line = Types.TerminalLine
type Handler = (Session) -> { Line }

local TerminalService = {}

local limiter = RateLimiter.new(GameConfig.Terminal.maxCommandsPerSecond)

local function line(text: string, kind: Types.EchoKind): Line
    return { text = text, kind = kind }
end

-- B.1: `status` monta o relatório a partir do estado da sessão
local function statusLines(session: Session): { Line }
    local s = session.state
    local T = Strings.Terminal
    local info: Types.EchoKind = Enums.EchoKind.Info -- anotado: o checador alarga o literal sem isto
    local lines: { Line } = {
        line(string.format(T.statusFirewall, s.firewallLayers, GameConfig.Hexagon.maxLayers), info),
        line(string.format(T.statusPower, math.floor(s.power)), info),
    }
    local corrupted: { string } = {}
    for _, system in GameConfig.Hexagon.systems do
        if s.corrupted[system] then
            table.insert(corrupted, system)
        end
    end
    if #corrupted == 0 then
        table.insert(lines, line(T.statusSystemsOk, Enums.EchoKind.Ok))
    else
        table.insert(lines, line(T.statusSystemsHeader, info))
        for _, system in corrupted do
            table.insert(lines, line(string.format(T.statusSystemLine, system), Enums.EchoKind.Err))
        end
    end
    local dead: { string } = {}
    for _, node in Enums.NodeList do
        if s.deadCameras[node] then
            table.insert(dead, node)
        end
    end
    if #dead == 0 then
        table.insert(lines, line(T.statusNodesOk, info))
    else
        table.insert(lines, line(string.format(T.statusNodesDead, table.concat(dead, ", ")), Enums.EchoKind.Err))
    end
    if s.generatorUsesLeft > 0 then
        table.insert(lines, line(string.format(T.statusGeneratorLeft, s.generatorUsesLeft), info))
    else
        table.insert(lines, line(T.statusGeneratorUsed, info))
    end
    return lines
end

local HANDLERS: { [string]: Handler } = {
    [Commands.Help] = function(_session: Session): { Line }
        return { line(Strings.Terminal.helpPrefix .. table.concat(Commands.list, ", "), Enums.EchoKind.Info) }
    end,
    [Commands.Status] = statusLines,
    [Commands.Clear] = function(_session: Session): { Line }
        return { line("", Enums.EchoKind.Clear) }
    end,
    [Commands.RestoreFirewall] = FirewallService.openPuzzle,
    [Commands.ResetGenerator] = function(session: Session): { Line }
        return session:generatorReset()
    end,
}
for command, system in Commands.repairs do
    HANDLERS[command] = function(session: Session): { Line }
        return FirewallService.repair(session, system)
    end
end

-- TerminalCommand { text } (5.6): no máximo maxInputLength caracteres, rate limit, sessão viva, terminal aberto
function TerminalService.handle(session: Session, player: Player, payload: unknown)
    if typeof(payload) ~= "table" then
        return
    end
    -- cast justificado: o payload vem do cliente e é validado campo a campo
    local text = (payload :: any).text
    if typeof(text) ~= "string" or #text > GameConfig.Terminal.maxInputLength then
        return
    end
    if not limiter:allow(player) then
        return
    end
    local s = session.state
    if not s.terminalOpen or not session:terminalAvailable() then
        return
    end
    if s.minigame then
        return -- 3.8.3 / 4.7: o minigame tem prioridade sobre o prompt
    end
    local command = Commands.resolve(text)
    if command == nil then
        if Commands.normalize(text) ~= "" then
            s.metrics.commands += 1
            s.metrics.commandsNotFound += 1
            session:echo(Strings.Terminal.notFound, Enums.EchoKind.Err) -- sem repetir o texto do jogador
        end
        return
    end
    s.metrics.commands += 1
    session:echo(Strings.Terminal.prompt .. " " .. command, Enums.EchoKind.Echo)
    local handler = HANDLERS[command]
    if handler then
        for _, result in handler(session) do
            session:echo(result.text, result.kind)
        end
    end
    session:firePalette()
end

function TerminalService.forget(player: Player)
    limiter:forget(player)
end

return TerminalService
