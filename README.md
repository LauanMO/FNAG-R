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

   O `rokit install` lê o `rokit.toml` e baixa as versões fixadas. Na primeira vez ele pede para
   confiar nos autores (`rojo-rbx`, `Kampfkarren`, `JohnnyMorganz`); confirme.
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

## Estrutura

```
src/
├── shared/   → ReplicatedStorage/Shared      GameConfig, Strings, Enums, Types, Remotes, Signal
├── server/   → ServerScriptService/Server    Main.server, Scheduler, NightSession, NightService, ...
├── client/   → StarterPlayerScripts/Client   Main.client, HudController, MenuController, ui/ (ScreenGuis em código)
└── ui/       → StarterGui                    vazio por enquanto
```

## Status

Ver a seção 6 do [planejamento](PLANEJAMENTO_ROBLOX.md) — cada fase tem tarefas e critério de aceite.
