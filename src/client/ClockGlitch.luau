--!strict
-- ClockGlitch: embaralha os relógios enquanto clock_glitch está corrompido (PLANEJAMENTO 3.4, 3.8.4, B.4).
-- 8 caracteres de Strings.HUD.glitchChars trocando a cada 0.18s. HUD e relógio de parede escutam `changed`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Signal = require(Shared:WaitForChild("Signal"))
local Strings = require(Shared:WaitForChild("Strings"))
local Types = require(Shared:WaitForChild("Types"))

-- Apresentação (B.4)
local GLITCH_LENGTH = 8
local GLITCH_INTERVAL = 0.18

local ClockGlitch = {}

-- Texto embaralhado a cada troca; nil quando o glitch acaba (hora volta a aparecer)
ClockGlitch.changed = Signal.new() :: Signal.Signal<string?>

local active = false
local conn: RBXScriptConnection? = nil
local rng = Random.new() -- apresentação, não lógica de jogo (Apêndice C.6)

local function randomText(): string
    local chars = Strings.HUD.glitchChars
    local out = table.create(GLITCH_LENGTH)
    for i = 1, GLITCH_LENGTH do
        local k = rng:NextInteger(1, #chars)
        out[i] = string.sub(chars, k, k)
    end
    return table.concat(out)
end

local function setActive(on: boolean)
    if on == active then
        return
    end
    active = on
    local connection = conn
    if connection then
        connection:Disconnect()
        conn = nil
    end
    if on then
        local acc = GLITCH_INTERVAL
        conn = RunService.Heartbeat:Connect(function(dt: number)
            acc += dt
            if acc >= GLITCH_INTERVAL then
                acc = 0
                ClockGlitch.changed:Fire(randomText())
            end
        end)
    else
        ClockGlitch.changed:Fire(nil)
    end
end

function ClockGlitch.isActive(): boolean
    return active
end

local function onSystems(payload: Types.SystemChangedPayload)
    setActive(table.find(payload.corrupted, Enums.System.ClockGlitch) ~= nil)
end

function ClockGlitch.init()
    Remotes.get(Enums.Remote.SystemCorrupted).OnClientEvent:Connect(onSystems)
    Remotes.get(Enums.Remote.SystemRepaired).OnClientEvent:Connect(onSystems)
    Remotes.get(Enums.Remote.NightStarted).OnClientEvent:Connect(function()
        setActive(false)
    end)
    Remotes.get(Enums.Remote.NightPhase).OnClientEvent:Connect(function(payload: Types.NightPhasePayload)
        if payload.phase == Enums.Phase.Won or payload.phase == Enums.Phase.Lost then
            setActive(false)
        end
    end)
end

return ClockGlitch
