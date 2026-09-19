# Five Nights at Geometry — Roblox (FNAG-R)

Port do protótipo web *Five Nights at Geometry* para Roblox (Luau), sincronizado com o Studio pelo Rojo.
Survival horror de gerenciamento: portas, energia, radar de rede e um terminal para consertar o que os vírus quebram.

**Fonte de verdade de design e arquitetura:** [PLANEJAMENTO_ROBLOX.md](PLANEJAMENTO_ROBLOX.md).
**Instruções para o Claude Code:** [CLAUDE.md](CLAUDE.md).

## Requisitos

- Roblox Studio
- [Rokit](https://github.com/rojo-rbx/rokit) — gerenciador do toolchain (rojo, selene, stylua)

## Setup (uma vez)

1. Instale o Rokit: baixe `rokit-<versão>-windows-x86_64.zip` em
   https://github.com/rojo-rbx/rokit/releases, extraia e rode `rokit self-install`.
   Abra um terminal novo depois disso.
2. Na raiz do repositório:

   ```
   rokit install
   rojo plugin install
   ```

   O `rokit install` lê o `rokit.toml` e baixa as versões fixadas (rojo, selene, stylua, luau-lsp).
   Na primeira vez ele pede para confiar nos autores (`rojo-rbx`, `Kampfkarren`, `JohnnyMorganz`); confirme.
   O `rojo plugin install` copia o plugin para a pasta de plugins do Studio (reabra o Studio se estiver aberto).
3. Crie um place **privado** no Roblox com `MaxPlayers = 1` (Game Settings → Places).

## Rodando

```
rojo serve
```

No Studio: abra o place, plugin do Rojo → **Connect** (`localhost:34872`) → **Play**.
A pasta `Shared` aparece em `ReplicatedStorage` e o Output mostra `GEOMETRY OS boot`.

Para testar mais rápido, mude `Debug.timeScale = 5` em `src/shared/GameConfig.luau`
(noite de 72 s em vez de 360 s; só tem efeito em Studio).

## Ferramentas

```
stylua src     # formata (stylua.toml: 4 espaços, 120 colunas, aspas duplas)
selene src     # lint
```

Checagem de tipos em modo strict com o luau-lsp. Na primeira vez, baixe as definições de tipo do Roblox
(a pasta `.luau-lsp/` fica fora do Git):

```
mkdir .luau-lsp
curl -L -o .luau-lsp/globalTypes.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.69.0/scripts/globalTypes.None.d.luau
```

Depois, a cada checagem:

```
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --definitions=.luau-lsp/globalTypes.d.luau --sourcemap=sourcemap.json --base-luaurc=.luaurc src
```

Sem saída e código de saída 0 = nenhum erro de tipo. Rode as três checagens antes de cada commit.

## Estrutura

```
src/
├── shared/   → ReplicatedStorage/Shared      GameConfig, Strings, Enums, Types, Remotes, Signal
├── server/   → ServerScriptService/Server    Main.server, Scheduler, NightSession, NightService, ...
├── client/   → StarterPlayerScripts/Client   Main.client, HudController, MenuController, ui/ (ScreenGuis em código)
└── ui/       → StarterGui                    vazio por enquanto
```

## Save e testes

O save usa DataStore. No Studio ele só funciona com o place publicado e **Game Settings → Security → Enable Studio Access to API Services** ligado; sem isso o jogo entra em modo sem save e avisa no menu.

Atalhos de teste no bloco `Debug` do `src/shared/GameConfig.luau` (só valem no Studio): `unlockAllNights`, `levelOverrides`, `forceSonar`, `deadCamerasAtStart`, `timeScale`, `deterministicSeed`, `logAI`, `logMetrics`.

## Balanceamento

```
python tools/balance_sim.py
```

Simula as noites 1-7 contra um jogador simulado, com os números do `GameConfig`. Resultados e propostas estão na seção 7.9 do planejamento.

## Status

Ver a seção 6 do [planejamento](PLANEJAMENTO_ROBLOX.md) — cada fase tem tarefas e critério de aceite.
