# Five Nights at Geometry — Roblox

Leia PLANEJAMENTO_ROBLOX.md antes de qualquer tarefa. Ele é a fonte de verdade
de design e arquitetura.

Regras:
- Trabalhamos UMA fase por vez (seção 6). Não implemente fases futuras.
- Todo número de balanceamento vive em src/shared/GameConfig.luau. Nunca hardcode.
- Servidor é autoritativo. Cliente só mostra e envia intenção.
- Todo estado da noite vive em NightSession. Sem variáveis globais soltas.
- Um único relógio (Scheduler em Heartbeat). Nunca use loops while/wait soltos para timers de jogo.
- Siga as convenções do Apêndice C.
- Ao terminar uma fase, atualize a seção 6 marcando o que foi feito.
- Se o design mudar, mude o PLANEJAMENTO primeiro e depois o código — nunca o contrário.

## Estado atual
- Fase 0 (setup) e Fase 1 (esqueleto e loop da noite) implementadas; critério de aceite no Studio pendente.
- Próxima: Fase 2 (escritório 3D e portas).

## Ferramentas
- Toolchain via Rokit (`rokit.toml`): rojo, selene, stylua. `rokit install` na raiz.
- `rojo serve` + plugin do Rojo no Studio (`rojo plugin install`). Place privado com MaxPlayers = 1.
- Formatar: `stylua src`. Lint: `selene src`. Tipos: `luau-lsp analyze` (comando completo no README; precisa de `.luau-lsp/globalTypes.d.luau` e `sourcemap.json`).
- Antes de cada commit: `stylua --check src`, `selene src`, `luau-lsp analyze` e `rojo build -o <tmp>.rbxl` sem erros.
- No Windows, se o PATH ainda não tiver o Rokit na sessão: `export PATH="$HOME/.rokit/bin:$PATH"`.
- Testar rápido: `Debug.timeScale = 5` no GameConfig (só tem efeito em Studio).

## Layout
- `src/shared`  → ReplicatedStorage/Shared (config, strings, enums, tipos, remotes, signal)
- `src/server`  → ServerScriptService/Server (sessão, scheduler, serviços, IAs em `ai/`)
- `src/client`  → StarterPlayer/StarterPlayerScripts/Client (controllers; ScreenGuis construídas em código em `src/client/ui`)
- `src/ui`      → StarterGui (vazio; reservado para .rbxmx feitos no Studio, se um dia houver)
- `assets/`     → referência de sons/imagens; os IDs entram em `GameConfig.Audio.ids`

## Commits
`feat(fase-N): ...`, `fix(area): ...`, `balance: ...`, `docs: ...` (Apêndice C.14). Um commit por tarefa da seção 6.
