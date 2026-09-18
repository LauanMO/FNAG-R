--!strict
-- Remotes: cria (servidor) e resolve (servidor e cliente) os RemoteEvents do contrato (PLANEJAMENTO 5.6).
-- Toda comunicação cliente↔servidor passa por aqui. Payloads são tabelas; o servidor valida tudo (5.9).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Enums = require(script.Parent.Enums)

local FOLDER_NAME = "Remotes"

local Remotes = {}
local cache: { [string]: RemoteEvent } = {}

-- cast justificado: Enums.Remote tem campos nomeados (para autocomplete); aqui precisamos iterar e checar por nome
local remoteNames = (Enums.Remote :: any) :: { [string]: string }

local function isKnown(name: string): boolean
    return remoteNames[name] ~= nil
end

-- Servidor: cria ReplicatedStorage/Remotes com um RemoteEvent por nome do contrato.
function Remotes.init()
    assert(RunService:IsServer(), "Remotes.init só roda no servidor")
    if ReplicatedStorage:FindFirstChild(FOLDER_NAME) then
        return
    end
    local folder = Instance.new("Folder")
    folder.Name = FOLDER_NAME
    for _, name in remoteNames do
        local remote = Instance.new("RemoteEvent")
        remote.Name = name
        remote.Parent = folder
        cache[name] = remote
    end
    folder.Parent = ReplicatedStorage
end

-- Servidor e cliente: devolve o RemoteEvent pelo nome. No cliente, espera a replicação.
function Remotes.get(name: string): RemoteEvent
    assert(isKnown(name), `Remote desconhecido: {name} (ver Enums.Remote)`)
    local cached = cache[name]
    if cached then
        return cached
    end
    local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
    local remote = folder:WaitForChild(name)
    assert(remote:IsA("RemoteEvent"), `{name} não é um RemoteEvent`)
    local event = remote :: RemoteEvent
    cache[name] = event
    return event
end

return Remotes
