--!strict
-- LogicGates: as seis portas lógicas do puzzle de restauração do firewall (PLANEJAMENTO 3.8.4, B.2).
-- Compartilhado: o servidor sorteia a porta e valida a resposta; o cliente só recebe a tabela-verdade
-- e as opções embaralhadas (5.9).

export type Row = { number } -- { a, b, out }

local LogicGates = {}

LogicGates.list = table.freeze({ "AND", "OR", "XOR", "NAND", "NOR", "XNOR" })

local INPUTS = table.freeze({ { 0, 0 }, { 0, 1 }, { 1, 0 }, { 1, 1 } })

-- Entradas e saída em 0/1
local EVAL: { [string]: (number, number) -> number } = {
    AND = function(a, b)
        return a * b
    end,
    OR = function(a, b)
        return math.max(a, b)
    end,
    XOR = function(a, b)
        return (a + b) % 2
    end,
    NAND = function(a, b)
        return 1 - a * b
    end,
    NOR = function(a, b)
        return 1 - math.max(a, b)
    end,
    XNOR = function(a, b)
        return 1 - (a + b) % 2
    end,
}

function LogicGates.isGate(name: string): boolean
    return EVAL[name] ~= nil
end

function LogicGates.eval(gate: string, a: number, b: number): number
    local fn = EVAL[gate]
    assert(fn ~= nil, `porta lógica desconhecida: {gate}`)
    return fn(a, b)
end

-- Tabela-verdade completa: quatro linhas { a, b, out } na ordem 00, 01, 10, 11 (B.2)
function LogicGates.truthTable(gate: string): { Row }
    local rows: { Row } = {}
    for _, input in INPUTS do
        table.insert(rows, { input[1], input[2], LogicGates.eval(gate, input[1], input[2]) })
    end
    return rows
end

return table.freeze(LogicGates)
