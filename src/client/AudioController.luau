--!strict
-- AudioController: todos os sons do cliente (PLANEJAMENTO 5.13). Fase 2: portas e blackout. Fase 3: cues de
-- inimigo (chegada/rebate) com volume por noite e ducking — enemy_arrival_* tem prioridade máxima (4.7).
-- Sons posicionais ficam em âncoras invisíveis nas soleiras (esquerda/direita); sons de UI e alarme são 2D.
-- Os assets reais entram em GameConfig.Audio.ids (Fase 6); cue sem asset é ignorado em silêncio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local AudioController = {}

local GROUP_NAMES = { "Ambient", "Enemy", "UI", "Alarm" }
local DEFAULT_GROUP = "UI"
-- Grupos que abaixam quando um inimigo chega na soleira (5.13)
local DUCKED_GROUPS = { "Ambient", "UI", "Alarm" }
local DUCK_ATTACK_SECONDS = 0.05 -- apresentação: descida quase instantânea, subida suave
local DUCK_RELEASE_SECONDS = 0.4

-- Cues que saem de um lado da sala: uma cópia por soleira
local POSITIONAL: { [string]: boolean } = {
    [Enums.Cue.DoorClose] = true,
    [Enums.Cue.DoorOpen] = true,
    [Enums.Cue.DoorJammed] = true,
    [Enums.Cue.DoorImpact] = true,
    [Enums.Cue.EnemyArrivalLeft] = true,
    [Enums.Cue.EnemyArrivalRight] = true,
}

-- Grupo de mixagem por cue (5.13)
local GROUP_OF: { [string]: string } = {
    [Enums.Cue.AmbientHum] = "Ambient",
    [Enums.Cue.AmbientLowPower] = "Ambient",
    [Enums.Cue.DoorClose] = "Ambient",
    [Enums.Cue.DoorOpen] = "Ambient",
    [Enums.Cue.DoorJammed] = "Ambient",
    [Enums.Cue.DoorImpact] = "Enemy",
    [Enums.Cue.EnemyArrivalLeft] = "Enemy",
    [Enums.Cue.EnemyArrivalRight] = "Enemy",
    [Enums.Cue.JumpscareSquare] = "Enemy",
    [Enums.Cue.JumpscareTriangle] = "Enemy",
    [Enums.Cue.JumpscareHexagon] = "Enemy",
    [Enums.Cue.VirusAlert] = "Alarm",
    [Enums.Cue.IntrusionAlarm] = "Alarm",
    [Enums.Cue.Blackout] = "Alarm",
}

-- Loops são ligados/desligados por estado, nunca disparados repetidamente (5.13)
local LOOPED: { [string]: boolean } = {
    [Enums.Cue.AmbientHum] = true,
    [Enums.Cue.AmbientLowPower] = true,
    [Enums.Cue.VirusAlert] = true,
    [Enums.Cue.IntrusionAlarm] = true,
}

local groups: { [string]: SoundGroup } = {}
local sounds2D: { [string]: Sound } = {}
local sounds3D: { [string]: { [string]: Sound } } = {} -- cue → lado → Sound
local duckTweens: { Tween } = {}
local duckToken = 0

local function makeSound(cue: string, assetId: string, parent: Instance): Sound
    local sound = Instance.new("Sound")
    sound.Name = cue
    sound.SoundId = assetId
    sound.Looped = LOOPED[cue] == true
    sound.SoundGroup = groups[GROUP_OF[cue] or DEFAULT_GROUP]
    sound.RollOffMode = Enum.RollOffMode.Linear
    sound.RollOffMaxDistance = GameConfig.Audio.rollOffMaxDistance
    sound.Parent = parent
    return sound
end

local function tweenDuckedGroups(seconds: number, volume: number)
    for _, tween in duckTweens do
        tween:Cancel()
    end
    table.clear(duckTweens)
    local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    for _, name in DUCKED_GROUPS do
        local group = groups[name]
        if group then
            local tween = TweenService:Create(group, info, { Volume = volume })
            tween:Play()
            table.insert(duckTweens, tween)
        end
    end
end

-- Ducking (5.13): abaixa os outros grupos por arrivalDuckSeconds e devolve com suavidade
local function duck()
    duckToken += 1
    local mine = duckToken
    tweenDuckedGroups(DUCK_ATTACK_SECONDS, 1 - GameConfig.Audio.arrivalDuckAmount)
    task.delay(GameConfig.Audio.arrivalDuckSeconds, function()
        if mine == duckToken then
            tweenDuckedGroups(DUCK_RELEASE_SECONDS, 1)
        end
    end)
end

local function onEnemyAudioCue(payload: Types.EnemyAudioCuePayload)
    if payload.cue == Enums.EnemyCue.Arrival then
        -- O cue mais importante do jogo (3.11): volume por noite (7.4) e prioridade sobre todo o resto
        local cue = if payload.side == Enums.Side.Left then Enums.Cue.EnemyArrivalLeft else Enums.Cue.EnemyArrivalRight
        AudioController.play(cue, payload.side, payload.volume)
        duck()
    elseif payload.cue == Enums.EnemyCue.Repelled then
        AudioController.play(Enums.Cue.DoorImpact, payload.side) -- "BAM": o jogador aprende que deu certo
    end
end

function AudioController.init()
    for _, name in GROUP_NAMES do
        local group = Instance.new("SoundGroup")
        group.Name = name
        group.Parent = SoundService
        groups[name] = group
    end

    local office = Workspace:WaitForChild(Enums.Office.Model)
    local doors = office:WaitForChild(Enums.Office.Doors)
    local anchors: { [string]: Instance } = {}
    for side, modelName in Enums.Office.DoorModel do
        anchors[side] = doors:WaitForChild(modelName):WaitForChild(Enums.Office.SoundAnchor)
    end

    local missing: { string } = {}
    -- cast justificado: Enums.Cue tem campos nomeados (para autocomplete); aqui precisamos iterar
    for _, cue in (Enums.Cue :: any) :: { [string]: string } do
        local assetId = GameConfig.Audio.ids[cue]
        if assetId == nil or assetId == "" then
            table.insert(missing, cue)
            continue
        end
        if POSITIONAL[cue] then
            local bySide: { [string]: Sound } = {}
            for side, anchor in anchors do
                bySide[side] = makeSound(cue, assetId, anchor)
            end
            sounds3D[cue] = bySide
        else
            sounds2D[cue] = makeSound(cue, assetId, SoundService)
        end
    end
    if RunService:IsStudio() and #missing > 0 then
        table.sort(missing)
        warn(
            `[AudioController] {#missing} cues sem asset em GameConfig.Audio.ids (Fase 6): {table.concat(missing, ", ")}`
        )
    end

    Remotes.get(Enums.Remote.BlackoutStarted).OnClientEvent:Connect(function()
        AudioController.play(Enums.Cue.Blackout)
    end)
    Remotes.get(Enums.Remote.EnemyAudioCue).OnClientEvent:Connect(onEnemyAudioCue)
    Remotes.get(Enums.Remote.NightStarted).OnClientEvent:Connect(function()
        duckToken += 1
        tweenDuckedGroups(DUCK_ATTACK_SECONDS, 1)
    end)
end

-- Toca um cue do início. side escolhe a soleira dos posicionais (padrão: esquerda); volume multiplica (padrão 1).
function AudioController.play(cue: string, side: Types.Side?, volume: number?)
    local bySide = sounds3D[cue]
    local sound = if bySide then bySide[side or Enums.Side.Left] else sounds2D[cue]
    if sound then
        sound.Volume = volume or 1
        sound:Play()
    end
end

-- Liga/desliga um loop 2D (ambient_hum, virus_alert, intrusion_alarm)
function AudioController.setLoop(cue: string, on: boolean)
    local sound = sounds2D[cue]
    if not sound then
        return
    end
    if on then
        if not sound.IsPlaying then
            sound:Play()
        end
    else
        sound:Stop()
    end
end

return AudioController
