--!strict
-- RadarService: ping do Global Security Node Map e câmeras mortas (PLANEJAMENTO 3.5, 5.5, 5.8).
-- A posição das IAs é lida só no instante da resolução e sai só dentro do PingResult (5.9).
-- Ping conta NÓS com anomalia, não inimigos (4.1); nó morto ainda conta, como "em nó cego" (3.5c).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Enums = require(Shared.Enums)
local Types = require(Shared.Types)
local NightSession = require(script.Parent.NightSession)

type Session = NightSession.NightSession

local PING_RESOLVE_TASK = "ping_resolve"
local PING_COOLDOWN_TASK = "ping_cooldown"

local RadarService = {}

-- Foto do instante: dead > anomaly > clear por nó. IAs desligadas (nível 0) não aparecem.
function RadarService.scan(session: Session): Types.PingResultPayload
    local s = session.state
    local occupied: { [string]: boolean } = {}
    for _, ai in session.patrols do
        if ai.level > 0 then
            occupied[ai:node()] = true
        end
    end

    local nodes: { [string]: Types.NodeState } = {}
    local anomalies = 0
    local blind = 0
    for _, node in Enums.NodeList do
        local isDead = s.deadCameras[node] == true
        local present = occupied[node] == true
        if present then
            anomalies += 1
            if isDead then
                blind += 1
            end
        end
        nodes[node] = if isDead
            then Enums.NodeState.Dead
            elseif present then Enums.NodeState.Anomaly
            else Enums.NodeState.Clear
    end

    local serverStatus: Types.ServerStatus = if s.virusAlert
        then Enums.ServerStatus.Anomalous
        else Enums.ServerStatus.Ok
    return { nodes = nodes, anomalies = anomalies, blind = blind, serverStatus = serverStatus }
end

local function logScan(result: Types.PingResultPayload)
    if not GameConfig.Debug.logAI then
        return
    end
    local hits: { string } = {}
    for node, state in result.nodes do
        if state ~= Enums.NodeState.Clear then
            table.insert(hits, `{node}={state}`)
        end
    end
    table.sort(hits)
    print(`[radar] ping: {result.anomalies} anomalia(s), {result.blind} em nó cego — {table.concat(hits, " ")}`)
end

-- 3.5a / 5.8: RequestPing → 1s → PingResult → (6s exibição + 3s cooldown) → PingCooldownOver.
-- Devolve false quando o pedido é recusado (tablet fechado/indisponível ou ping em andamento).
function RadarService.requestPing(session: Session): boolean
    local s = session.state
    if not s.tabletOpen or s.pingBusy or not session:tabletAvailable() then
        return false
    end
    s.pingBusy = true
    session:fire(Enums.Remote.PingStarted, {})
    session.scheduler:after(PING_RESOLVE_TASK, GameConfig.Radar.pingProcessSeconds, function()
        local result = RadarService.scan(session)
        logScan(result)
        session:fire(Enums.Remote.PingResult, result)
        local cooldown = GameConfig.Radar.pingShowSeconds + GameConfig.Radar.pingCooldownSeconds
        session.scheduler:after(PING_COOLDOWN_TASK, cooldown, function()
            s.pingBusy = false
            session:fire(Enums.Remote.PingCooldownOver, {})
        end)
    end)
    return true
end

-- Destrói uma câmera; permanente pela noite (3.8.3). Usado pelo Círculo (Fase 5b) e pelo debug.
function RadarService.killCamera(session: Session, camera: string)
    local s = session.state
    if s.deadCameras[camera] then
        return
    end
    s.deadCameras[camera] = true
    session:fire(Enums.Remote.CameraDead, { camera = camera } :: Types.CameraDeadPayload)
end

-- Próxima câmera da ordem de destruição (7.5). Devolve nil quando todas já morreram.
function RadarService.killNextCamera(session: Session): string?
    for _, camera in GameConfig.Radar.cameraBreakOrder do
        if not session.state.deadCameras[camera] then
            RadarService.killCamera(session, camera)
            return camera
        end
    end
    return nil
end

return RadarService
