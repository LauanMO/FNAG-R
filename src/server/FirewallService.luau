--!strict
-- FirewallService: camadas do firewall, sistemas corrompidos, puzzle de portas lógicas e intrusão
-- (PLANEJAMENTO 3.8.4, 5.5). O Hexágono chama breakLayer; o terminal chama repair e openPuzzle;
-- o cliente responde o puzzle por PuzzlePick. A porta correta fica só no servidor (5.9).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Enums = require(Shared.Enums)
local LogicGates = require(Shared.LogicGates)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local NightSession = require(script.Parent.NightSession)
local HexagonAI = require(script.Parent.ai.HexagonAI)

type Session = NightSession.NightSession
type Line = Types.TerminalLine

local Task = NightSession.Task
local HEXAGON_TASK = "ai_hexagon"

local FirewallService = {}

local function line(text: string, kind: Types.EchoKind): Line
    return { text = text, kind = kind }
end

local function fireFirewall(session: Session, cause: Types.FirewallCause)
    session:fire(
        Enums.Remote.FirewallChanged,
        {
            layers = session.state.firewallLayers,
            max = GameConfig.Hexagon.maxLayers,
            cause = cause,
        } :: Types.FirewallChangedPayload
    )
end

-- Todos os sistemas corrompidos, na ordem do config: o cliente redesenha a lista inteira a cada evento (5.6)
local function corruptedList(session: Session): { string }
    local list: { string } = {}
    for _, system in GameConfig.Hexagon.systems do
        if session.state.corrupted[system] then
            table.insert(list, system)
        end
    end
    return list
end

local function fireSystems(session: Session, remoteName: string, system: string)
    session:fire(remoteName, { system = system, corrupted = corruptedList(session) } :: Types.SystemChangedPayload)
end

-- Efeitos colaterais de corromper/reparar (3.8.4). clock_glitch é só apresentação: o cliente embaralha os relógios.
local function applyEffect(session: Session, system: string, corrupted: boolean)
    local s = session.state
    if system == Enums.System.DoorLeftJammed or system == Enums.System.DoorRightJammed then
        local side: Types.Side = if system == Enums.System.DoorLeftJammed then Enums.Side.Left else Enums.Side.Right
        local door = if side == Enums.Side.Left then s.doors.left else s.doors.right
        -- 3.3: a porta congela no estado em que está; só a trava muda
        door.jammed = corrupted
        session:fire(
            Enums.Remote.DoorStateChanged,
            {
                side = side,
                closed = door.closed,
                jammed = door.jammed,
                accepted = true,
            } :: Types.DoorStateChangedPayload
        )
    elseif system == Enums.System.CameraOffline then
        if corrupted then
            s.tabletOpen = false -- o tablet desliga na hora (3.5)
        end
        session:fireTabletState()
        session:firePower()
    elseif system == Enums.System.PowerLeak then
        session:firePower()
    end
end

local function corrupt(session: Session, system: string)
    session.state.corrupted[system] = true
    applyEffect(session, system, true)
    fireSystems(session, Enums.Remote.SystemCorrupted, system)
    session:alert(string.format(Strings.Terminal.alertCorrupted, system), Enums.EchoKind.Err)
end

-- Comando de reparo (3.6). Só funciona com o sistema corrompido; senão, [WARN].
function FirewallService.repair(session: Session, system: string): { Line }
    local s = session.state
    if not s.corrupted[system] then
        return { line(string.format(Strings.Terminal.notCorrupted, system), Enums.EchoKind.Err) }
    end
    s.corrupted[system] = nil
    applyEffect(session, system, false)
    fireSystems(session, Enums.Remote.SystemRepaired, system)
    return { line(string.format(Strings.Terminal.repaired, system), Enums.EchoKind.Ok) }
end

local function fireIntrusion(session: Session)
    local remaining = session.state.intrusionRemaining
    session:fire(
        Enums.Remote.IntrusionState,
        { active = remaining ~= nil, remaining = remaining } :: Types.IntrusionStatePayload
    )
end

local function stopIntrusion(session: Session)
    if session.state.intrusionRemaining == nil then
        return
    end
    session.state.intrusionRemaining = nil
    session.scheduler:remove(Task.Intrusion)
    fireIntrusion(session)
end

-- 3.8.4: firewall em zero dá intrusionSeconds para restaurar uma camada; senão, jumpscare do Hexágono
local function startIntrusion(session: Session)
    local s = session.state
    local H = GameConfig.Hexagon
    s.intrusionRemaining = H.intrusionSeconds
    fireIntrusion(session)
    session:alert(Strings.Terminal.alertIntrusion, Enums.EchoKind.Err)
    session.scheduler:every(Task.Intrusion, H.intrusionTickSeconds, function()
        local remaining = (s.intrusionRemaining or 0) - H.intrusionTickSeconds
        if remaining > 0 then
            s.intrusionRemaining = remaining
            fireIntrusion(session)
            return
        end
        stopIntrusion(session)
        -- 3.1: nos últimos segundos antes das 6 nada mata; a intrusão expira sem consequência
        if not session:inDawnGrace() then
            session:lose(Enums.Enemy.Hexagon)
        end
    end)
end

-- O Hexágono passou no teste (3.8.4): −1 camada e um sistema íntegro corrompido. Em zero, intrusão.
function FirewallService.breakLayer(session: Session)
    local s = session.state
    local H = GameConfig.Hexagon
    if s.firewallLayers <= 0 then
        return -- já em intrusão; não há mais o que romper
    end
    s.firewallLayers -= 1
    fireFirewall(session, Enums.FirewallCause.Break)
    session:alert(string.format(Strings.Terminal.alertLayerLost, s.firewallLayers, H.maxLayers), Enums.EchoKind.Err)
    -- Com todos os sistemas já corrompidos, só rompe a camada
    local intact: { string } = {}
    for _, system in H.systems do
        if not s.corrupted[system] then
            table.insert(intact, system)
        end
    end
    if #intact > 0 then
        corrupt(session, intact[session.rng:NextInteger(1, #intact)])
    end
    if s.firewallLayers == 0 then
        startIntrusion(session)
    end
    session:firePalette()
end

local function shuffled(rng: Random, list: { string }): { string }
    local copy = table.clone(list)
    for i = #copy, 2, -1 do
        local j = rng:NextInteger(1, i)
        copy[i], copy[j] = copy[j], copy[i]
    end
    return copy
end

local function newPuzzle(session: Session)
    local gates = LogicGates.list
    local gate = gates[session.rng:NextInteger(1, #gates)]
    local options = shuffled(session.rng, gates)
    session.state.puzzle = { gate = gate, options = options, locked = false }
    session:fire(
        Enums.Remote.PuzzleStart,
        { truthTable = LogicGates.truthTable(gate), options = options } :: Types.PuzzleStartPayload
    )
end

-- `restore_firewall` (3.6): abre o painel se há camada a recuperar e o console não está em cooldown
function FirewallService.openPuzzle(session: Session): { Line }
    local s = session.state
    local T = Strings.Terminal
    if s.firewallLayers >= GameConfig.Hexagon.maxLayers then
        return { line(T.firewallFull, Enums.EchoKind.Err) }
    end
    if session.scheduler:has(Task.RestoreCooldown) then
        return { line(T.consoleCooldown, Enums.EchoKind.Err) }
    end
    local puzzle = s.puzzle
    if not puzzle then
        newPuzzle(session)
    elseif not puzzle.locked then
        -- Painel já aberto: reenvia a mesma tabela (a resposta não muda por pedir de novo)
        session:fire(
            Enums.Remote.PuzzleStart,
            { truthTable = LogicGates.truthTable(puzzle.gate), options = puzzle.options } :: Types.PuzzleStartPayload
        )
    end
    return { line(T.puzzleOpening, Enums.EchoKind.Info) }
end

-- PuzzlePick { gate } (5.6). Acerto: +1 camada, aborta a intrusão, cooldown de restore.
-- Erro: −5% de energia (menos na Noite 0) e nova tabela depois de newTableAfterWrongSeconds.
function FirewallService.puzzlePick(session: Session, gate: string)
    local s = session.state
    local puzzle = s.puzzle
    if not puzzle or puzzle.locked or not s.terminalOpen then
        return
    end
    if not table.find(puzzle.options, gate) then
        return
    end
    local H = GameConfig.Hexagon
    if gate == puzzle.gate then
        s.puzzle = nil
        s.firewallLayers = math.min(H.maxLayers, s.firewallLayers + 1)
        s.restoreCooldown = H.restoreCooldownSeconds
        session.scheduler:after(Task.RestoreCooldown, H.restoreCooldownSeconds, function()
            s.restoreCooldown = 0
            session:firePalette()
        end)
        fireFirewall(session, Enums.FirewallCause.Restore)
        session:fire(
            Enums.Remote.PuzzleResult,
            { correct = true, gate = gate, layers = s.firewallLayers, penalty = 0 } :: Types.PuzzleResultPayload
        )
        stopIntrusion(session) -- 4.8: a contagem para no primeiro restore; não precisa encher o firewall
        session:firePalette()
        return
    end
    -- 3.12: erros não punem na Noite 0 (tutorial)
    local penalty = if s.night == 0 then 0 else GameConfig.Power.puzzlePenalty
    puzzle.locked = true
    session:fire(
        Enums.Remote.PuzzleResult,
        { correct = false, gate = gate, layers = s.firewallLayers, penalty = penalty } :: Types.PuzzleResultPayload
    )
    if penalty > 0 then
        session:addPower(-penalty)
    end
    session.scheduler:after(Task.PuzzleNext, GameConfig.Puzzle.newTableAfterWrongSeconds, function()
        if s.puzzle == puzzle then
            newPuzzle(session)
        end
    end)
end

-- PuzzleCancel {}: o painel pode ser cancelado a qualquer momento (3.8.4)
function FirewallService.cancelPuzzle(session: Session)
    session:closePuzzle()
end

-- Cria o Hexágono da noite e registra o tick dele na sessão. Chamar antes de session:start().
function FirewallService.attach(session: Session)
    local hexagon = HexagonAI.new(session.levels.hexagon, session.rng, function()
        return not session:inDawnGrace()
    end, function()
        FirewallService.breakLayer(session)
    end)
    session.state.ai[Enums.Enemy.Hexagon] = hexagon
    session:addAITask(HEXAGON_TASK, GameConfig.Hexagon.tickSeconds, function()
        hexagon:tick()
    end)
end

return FirewallService
