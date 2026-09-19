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
- Fases 0 a 6 validadas no Studio. Fase 7 (tutorial, save em DataStore, progressão, Custom Night, créditos, métricas) implementada; aceite pendente.
- Menu com palco 3D (PLANEJAMENTO 5.12): `MenuScene` assume a câmera enquanto o menu está aberto (`OfficeCamera.setActive`); modelos dos inimigos em `EnemyModels`. Aceite no Studio pendente.
- Fase 8 (publicação): parte do repositório feita (auditorias, arte em `assets/publicacao/`, textos em PLANEJAMENTO 9.1 e 9.2). Falta o Creator Hub: configurações, questionário, upload, publicação privada.
- Próxima: playtest com pessoas decide as propostas de balanceamento (PLANEJAMENTO 7.9).
- Balanceamento: `python tools/balance_sim.py` lê o GameConfig; as regras de jogo estão reimplementadas nele, então mudança de regra no Luau exige mudar lá também.
- Sons são placeholders escolhidos pelo nome; o time precisa ouvir e trocar no GameConfig.
- Tablet, terminal e manual são telas exclusivas (`src/client/Overlay.luau`). Serviços registram IAs com `session:addAITask`.
- Esc é reservado pelo Roblox: overlays fecham com a mesma tecla que abriu ou com o botão FECHAR.
- As IAs recebem a sessão pela interface `Types.AIHost`; nunca fazem require de NightSession.
- Sem personagem no jogo: clique em objetos 3D é raycast do InputController (atributo `Interact`), não ClickDetector.

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
