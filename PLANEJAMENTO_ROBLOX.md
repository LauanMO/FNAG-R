# FIVE NIGHTS AT GEOMETRY — PLANEJAMENTO COMPLETO (PORT PARA ROBLOX)

> **Versão:** 1.0 — 18/09/2026
> **Origem:** port do protótipo web em `SerialSX/FnaFTest` (HTML/CSS/JS) para Roblox (Luau).
> **Público deste documento:** o time (Arthur + amigo) e o Claude Code. Ele é ao mesmo tempo o GDD (game design document), o documento de arquitetura e o backlog.
> **Regra de ouro:** se algo aqui e o código discordarem, o documento é a fonte de verdade até ser atualizado. Se o design mudar, muda-se aqui primeiro.

---

## ÍNDICE

0. Como usar este documento (e como usar com Claude Code)
1. Visão geral do jogo
2. Decisões de arquitetura (o que já está decidido e por quê)
3. A jogabilidade em detalhe (GDD)
4. Cenários narrados de jogabilidade (exemplos reais)
5. Arquitetura técnica (pastas, módulos, contratos, remotes)
6. Plano por fases (tarefas, critérios de aceite)
7. Balanceamento inicial (todas as tabelas)
8. Bugs e inconsistências do protótipo web (o que NÃO portar)
9. Checklist de publicação no Roblox
10. Backlog e ideias futuras
11. Glossário
- Apêndice A — Prompts sugeridos para o Claude Code, por fase
- Apêndice B — Textos do jogo (comandos, palavras, manual, diálogos)
- Apêndice C — Convenções de código Luau

---

## 0. COMO USAR ESTE DOCUMENTO

### 0.1 Com o Claude Code

1. Crie a pasta do projeto Roblox (ver seção 5.1) e coloque este arquivo na raiz como `PLANEJAMENTO_ROBLOX.md`.
2. Crie um `CLAUDE.md` na raiz com o conteúdo abaixo. O Claude Code lê esse arquivo automaticamente em toda sessão:

```markdown
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
```

3. Trabalhe **uma fase por vez**. No início de cada fase, use o prompt sugerido no Apêndice A. No fim, rode o critério de aceite da fase no Studio antes de avançar.
4. Quando o design mudar durante o desenvolvimento (vai mudar), atualize a seção correspondente aqui e peça ao Claude Code para refletir a mudança no código — nunca o contrário.

### 0.2 Legenda de status usada no documento

- **[ORIGINAL]** — mecânica que já existe no protótipo web e será portada como está.
- **[AJUSTE]** — existe no original, mas muda no port (o motivo está sempre junto).
- **[NOVO]** — proposta nova, não existe no original.
- **[DECIDIR]** — em aberto; tem uma recomendação, mas precisa de uma decisão do time.

---

## 1. VISÃO GERAL DO JOGO

### 1.1 Elevator pitch

**Five Nights at Geometry** é um survival horror de gerenciamento, no formato "sobreviva a noite trancado num escritório", onde os inimigos são formas geométricas — inteligências artificiais que **você mesmo programou** e que saíram do controle. Metade das ameaças tenta entrar pela porta; a outra metade corrompe o próprio software que te protege. Você se defende fechando portas, lendo um radar de rede e **digitando comandos num terminal** para consertar o que os vírus quebram.

O diferencial em relação ao gênero: além do loop clássico de portas/energia/câmeras, existe uma camada de **"hacking diegético"** — manual físico na mesa, terminal de linha de comando, puzzles de lógica — que transforma o jogador de vigia passivo em administrador de sistema sob ataque.

### 1.2 Lore [ORIGINAL]

Você é um programador contratado para desenvolver o software, o sistema de segurança e as IAs de uma futura pizzaria temática. Durante os testes, as IAs saíram do controle e te trancaram dentro do próprio ambiente de simulação. O seu objetivo é sobreviver às noites desse pesadelo digital, hackeando, consertando e modificando o código do sistema "ao vivo" pelo terminal para se defender das formas geométricas que você criou.

Elementos de lore a preservar no port:

- O nome do sistema operacional é **GEOMETRY OS** (aparece no boot do terminal: `GEOMETRY OS v1.0 ONLINE...`).
- O prompt do terminal é `root@office:~$`.
- A "Unidade de Assistência de Debug" (a figura cinza da Noite 0) apresenta o jogo com um tom de assistente corporativo que deixa escapar que sabe o que vai acontecer ("protocolos básicos de sobreviv... digo, de teste").
- O radar de câmeras é um **"Global Security Node Map v2.4"** — uma topologia de rede, não um sistema de vídeo. Isso justifica o ping, os "nós", e a estética de terminal.
- Os inimigos são "anomalias" na linguagem do sistema.

### 1.3 Pilares de design

Todo o balanceamento e toda feature futura devem ser julgados contra estes quatro pilares. Se uma ideia viola um pilar, ela precisa de uma justificativa muito boa.

1. **Tensão vem de escassez, não de RNG puro.** A energia é o recurso central. O jogador deve *sentir* cada porta fechada. Se a energia não está acabando, o jogo não está funcionando (ver seção 3.2 — o protótipo web falha aqui).
2. **Toda morte tem que ser explicável.** O jogador deve conseguir dizer "eu morri porque não fechei a porta / porque errei o comando / porque abri o tablet na hora errada". Morte por informação que ele não tinha como obter é bug de design, não dificuldade (ver seção 3.5 — o radar do protótipo falha aqui).
3. **Hacking é a identidade do jogo.** Terminal, manual e puzzle não são minigames decorativos — são a defesa contra metade dos inimigos. Eles devem ser rápidos de usar sob pressão e funcionar no celular.
4. **Áudio é metade do horror.** Cada evento relevante (chegada na porta, vírus, camada de firewall rompida, blackout) tem um som que o jogador aprende a reconhecer. O radar informa onde; o som informa *agora*.

### 1.4 Público e plataforma

- **Plataforma:** Roblox (PC, mobile, console). Assumir que **a maioria dos jogadores está no celular**. Isso é uma restrição de design de primeira ordem — ver seção 3.6 (terminal no mobile) e 5.11.
- **Público:** 12+. Horror de sustos (jumpscare) e tensão, sem gore. No Roblox isso exige configurar os descritores de conteúdo (ver seção 9).
- **Sessão típica:** 6 a 8 minutos por noite. Uma noite completa cabe num intervalo.
- **Idioma:** textos do jogo em **português**. Comandos do terminal em **inglês** (`fix camera`, `unjam door_left`) — é parte da ficção de "sistema" e mantém compatibilidade com o original. [DECIDIR] se haverá versão em inglês dos textos; a arquitetura deve deixar isso trivial (todos os textos num módulo `Strings`, ver Apêndice B).

### 1.5 O que já existe (estado do protótipo web)

Resumo do que foi construído no repositório `FnaFTest/Five_Nights_Geometry` e serve de base. Detalhes de cada mecânica na seção 3.

| Sistema | Estado no web | Arquivo original |
|---|---|---|
| Menu com glitch RNG | Feito | `menu.js`, `menu.css` |
| Escritório whitebox (mesa, relógio, energia, portas) | Feito | `index.html`, `game.css` |
| Loop de noite (relógio 12→6, vitória, derrota) | Feito | `game.js` |
| Energia com dreno passivo + portas | Feito (desbalanceado) | `game.js` |
| Quadrado Azul (esquerda) | Feito | `square.js` |
| Triângulo Vermelho (direita) | Feito | `triangle.js` |
| Círculo Amarelo + minigame de sintaxe | Feito | `circle.js`, `minigame.js` |
| Hexágono Ciano + firewall + sistemas corrompidos | Feito | `hexagon.js` |
| Terminal de comandos | Feito | `terminal.js` |
| Manual (notebook paginado) | Feito | `notebook.js` |
| Puzzle de portas lógicas | Feito | `puzzle.js` |
| Radar com ping global | Feito | `camera.js` |
| Blackout + bateria do tablet + `reset generator` | Feito | `game.js`, `terminal.js` |
| Noite 0 tutorial (visual novel) | Só o diálogo de abertura | `tutorial.js` |
| Save (localStorage) | Feito | `main.js` |
| Áudio | **Nada** | — |
| Jumpscares | `alert()` | — |
| Progressão por noite | **Nada** (níveis hardcoded) | — |
| Sonar 3D (noite 6+) | Não começado | — |

Documentos originais que continuam valendo como referência: `README_DEV.MD` (roadmap) e `Tutorial.md` (manual de mecânicas). **Atenção:** os dois divergem do código em vários números (ver seção 8). Este documento resolve as divergências.

---

## 2. DECISÕES DE ARQUITETURA

Cada decisão abaixo tem um "porquê". Se o porquê deixar de valer, a decisão pode mudar — mas mude aqui primeiro.

### 2.1 Servidor autoritativo

**Decisão:** o servidor é dono de todo estado que afeta vitória/derrota: hora, energia, posição das IAs, estado das portas, camadas de firewall, sistemas corrompidos, câmeras mortas, resultado de minigames, save. O cliente é dono apenas de apresentação: HUD, tablet, terminal (input e eco), câmera 3D, efeitos, som, jumpscare visual.

**Por quê:** no Roblox, qualquer coisa que roda no cliente pode ser lida e alterada por exploiters. Se a IA rodar no cliente, o exploiter congela o Quadrado e ganha a noite. Se a energia rodar no cliente, ele a mantém em 100%. Num jogo single player isso "só" estraga leaderboards e a experiência de quem assiste — mas se um dia virar co-op, estraga o jogo dos outros.

**Consequência prática:** toda ação do jogador vira uma *intenção* enviada ao servidor (`ToggleDoor`, `TerminalCommand`, `RequestPing`), e o servidor responde com o novo estado. O cliente pode fazer *predição visual* (a porta começa a descer no mesmo frame do clique) mas reverte se o servidor negar (porta travada pelo Hexágono).

### 2.2 Solo primeiro, sessão preparada para co-op [DECIDIR — recomendação: seguir]

**Decisão:** o jogo lança solo (1 jogador por servidor). Mas todo estado de uma noite vive num objeto `NightSession` que é criado com uma **lista de jogadores**. Solo = lista de 1.

**Por quê:** co-op é o que costuma dar público em FNAF-likes no Roblox, e o time ainda não decidiu. O erro fatal seria espalhar `power`, `hour`, `squarePosition` como variáveis soltas no servidor — aí co-op vira reescrita. Com `NightSession`, co-op vira "adicionar jogadores à lista + decidir regras de compartilhamento", que é trabalho de design, não de arquitetura.

**O que fica em aberto para co-op (não decidir agora):** energia compartilhada ou individual? Qualquer um pode fechar qualquer porta? Terminal é um só? Se um morre, todos morrem? Essas perguntas só fazem sentido depois do solo estar divertido.

**Implementação do solo:** `MaxPlayers = 1` no place principal. Alternativa mais robusta para depois: um place de lobby que usa `TeleportService:ReserveServer()` para criar um servidor privado por jogador. Para a v1, `MaxPlayers = 1` basta.

### 2.3 Escritório híbrido: sala 3D whitebox + HUD 2D [DECIDIR — recomendação: seguir]

**Decisão:** o escritório é uma sala 3D simples (partes cinzas, sem arte na v1). A câmera fica travada na cadeira e o mouse/touch gira a visão num arco limitado (esquerda ↔ direita). As portas são partes físicas que descem. O tablet, o manual, o terminal e o puzzle são **GUI 2D em tela cheia** (ScreenGui).

**Por quê:** o 3D é onde o Roblox entrega o que o HTML não conseguia: som posicional (o passo vem *da esquerda*), portas com peso e ruído, a sensação de olhar para o corredor escuro. Já terminal/manual/puzzle *são telas* na ficção — mantê-los em GUI não é concessão, é coerência. E evita transformar o projeto num projeto de modelagem 3D.

**Whitebox significa:** paredes, chão, teto, mesa, duas aberturas de porta com uma parte que desce, duas luzes, um monitor na mesa (ponto de clique do terminal), um caderno na mesa (ponto de clique do manual), um botão em cada parede ao lado da porta. Tudo em `Part` cinza com `Material = SmoothPlastic`. Arte depois.

### 2.4 Um único relógio de jogo (Scheduler em Heartbeat)

**Decisão:** não existem loops `while true do task.wait(x)` soltos para lógica de jogo. Existe um módulo `Scheduler` que roda em `RunService.Heartbeat` e mantém acumuladores: "a cada 5s chame `SquareAI.tick`", "a cada 1s drene energia", "a cada 60s avance a hora". Pausar o jogo = pausar o Scheduler. Game over = destruir o Scheduler da sessão.

**Por quê:** o protótipo web tem quatro `setInterval` independentes e já sofre com isso: `triggerJumpscare` para o relógio e a energia mas esquece as IAs, que continuam rodando depois da morte; o dreno de energia é criado em dois lugares com intervalos diferentes. Um relógio só elimina essa classe inteira de bug e torna "pausar", "acelerar para testar" e "rodar determinístico com seed" triviais.

### 2.5 Uma única fonte de números: `GameConfig`

**Decisão:** todo número de balanceamento (durações, taxas de dreno, ticks das IAs, níveis por noite, tempos de ping, fusíveis) vive em `src/shared/GameConfig.luau`. Nenhum módulo hardcoda um número de jogo.

**Por quê:** o protótipo tem os números espalhados em quatro arquivos JS e dois documentos, e eles **discordam entre si** (seção 8). Com um módulo só, balancear é editar uma tabela, e o documento (seção 7) pode ser copiado literalmente para o arquivo.

### 2.6 Estado da noite em `NightSession`, IAs como módulos parametrizados

**Decisão:** `NightSession` é uma "classe" Luau (tabela com metatable) que contém *todo* o estado de uma noite e é destruída no fim dela. As IAs são módulos que recebem a sessão e um bloco de config; Quadrado e Triângulo são **a mesma classe** (`PatrolAI`) instanciada duas vezes com parâmetros diferentes.

**Por quê:** `square.js` e `triangle.js` são cópias com o nome trocado. Qualquer correção precisa ser feita duas vezes. Uma classe parametrizada também é o que permite adicionar um terceiro inimigo físico numa linha.

### 2.7 Ferramentas: Rojo + Git [DECIDIR — recomendação: seguir, mas não é bloqueante]

**Decisão:** o código Luau vive em arquivos `.luau` num repositório Git, sincronizado com o Roblox Studio pelo **Rojo**. O Claude Code edita os arquivos; o Studio recebe as mudanças ao vivo.

**Por quê:** o time já usa Git e já tem repositório. O projeto anterior morreu uma vez; histórico de commits é o que permite voltar meses depois e entender onde parou. E o Claude Code só consegue trabalhar em arquivos — sem Rojo, cada script teria que ser copiado e colado manualmente no Studio.

**Curva:** cerca de dois dias para ficar confortável. Alternativa se o Rojo travar o início: trabalhar direto no Studio nas Fases 1 e 2, com o Claude Code gerando os scripts para colar. Migrar para Rojo na Fase 3, quando o volume de arquivos cresce.

**Setup mínimo:**
- Instalar Rojo (plugin no Studio + CLI via Aftman/Rokit).
- `rojo init` na pasta do projeto e ajustar o `default.project.json` conforme seção 5.1.
- Opcional mas recomendado: `selene` (linter) e `stylua` (formatador). O Claude Code segue os dois se estiverem configurados.

### 2.8 Sem frameworks pesados na v1

**Decisão:** sem Knit, sem Roact/React-lua, sem ECS. ModuleScripts puros, uma classe `Signal` simples (ou `GoodSignal`), RemoteEvents nomeados.

**Por quê:** o time sabe o básico de Luau. Frameworks adicionam uma camada de vocabulário que atrapalha mais do que ajuda num projeto deste tamanho. O único "framework" é a disciplina: config única, sessão única, scheduler único, servidor autoritativo.

---

## 3. A JOGABILIDADE EM DETALHE (GDD)

Esta seção descreve cada sistema como ele deve funcionar no Roblox. Os números aqui são os **valores iniciais** e estão consolidados na seção 7 (que é a fonte para o `GameConfig`). Espere mudá-los depois do primeiro playtest — mas mude na seção 7 e no `GameConfig`, nunca no código.

### 3.1 O loop da noite

**Estrutura de uma noite** [AJUSTE — duração]:

| Item | Protótipo web | Roblox (v1) | Motivo |
|---|---|---|---|
| Duração total | 180s (3 min) | **360s (6 min)** | 3 min não dá tempo de terminal, manual e puzzle respirarem. FNAF usa ~8-9 min; 6 min é o meio-termo pra sessão mobile. |
| Duração de 1 hora | 30s | **60s** | Derivado. |
| Horas | 12 AM → 6 AM (6 horas) | igual | [ORIGINAL] |
| Vitória | `hour == 6` | igual | [ORIGINAL] |

**Ciclo de vida de uma noite:**

```
MENU
  └─ [New Game] → salva noite 0, vai pra NOITE 0 (tutorial)
  └─ [Continue]  → carrega save, vai pra noite salva
  └─ [Custom Night] (só após vencer a noite 7) → escolhe níveis 0-20 por IA

NOITE N
  ├─ Boot (3s): tela "INICIALIZANDO SIMULAÇÃO_", HUD aparece com fade, relógio em 12:00 AM
  ├─ Jogo: Scheduler roda, IAs ativas conforme NightConfig[N]
  ├─ Vitória (6:00 AM): Scheduler para, "6:00 AM" na tela com som de alívio, salva N+1, volta ao MENU
  └─ Derrota: jumpscare (3s), tela de game over com [Tentar de novo] [Menu], nada é salvo
```

**Regras:**
- Relógio, energia e IAs só começam depois do boot (3s). Isso dá tempo do jogador se situar.
- O relógio continua rodando durante o blackout [ORIGINAL] — dá pra ganhar "na sorte".
- Nenhuma IA age durante os últimos 2 segundos antes das 6 AM (evita a sensação de "morri no 5:59"). [NOVO, opcional — marcar como config `graceBeforeDawn`]
- Morrer não salva nada. Vencer salva `maxNightUnlocked = N+1` e `currentNight = N+1`.

### 3.2 Energia

A energia é o coração do jogo (pilar 1). É a única coisa que impede o jogador de "fechar as duas portas e esperar".

**Modelo** [AJUSTE — taxas e tick]: a energia é um número de 0 a 100 (com decimais internamente, exibido como inteiro). A cada segundo o servidor calcula o dreno total e subtrai. Tick de 1s em vez dos 4,5s do original — mais suave e mais fácil de raciocinar.

**Fontes de dreno (por segundo):**

| Fonte | Taxa | Status | Comentário |
|---|---|---|---|
| Base (sempre) | 0.12 %/s (7.2 %/min) | [AJUSTE] | Sem fazer nada, termina a noite com ~57%. |
| Porta esquerda fechada | +0.20 %/s | [AJUSTE] | Cada porta. |
| Porta direita fechada | +0.20 %/s | [AJUSTE] | |
| Tablet aberto | +0.08 %/s | [NOVO] | No original o tablet era grátis. Precisa custar pra "olhar demais" ser uma decisão. |
| Vazamento (`power_leak`, Hexágono) | +0.15 %/s | [AJUSTE] | Até ser consertado com `seal power_leak`. |
| Erro no puzzle lógico | −5 instantâneo | [ORIGINAL] | |
| `reset generator` | define para 50 | [ORIGINAL] | Ver 3.9. |

**O que essas taxas produzem** (noite de 360s):

| Comportamento a noite inteira | Dreno/s | Resultado |
|---|---|---|
| Nada | 0.12 | Termina com **57%** |
| Tablet aberto o tempo todo | 0.20 | Termina com **28%** |
| Uma porta fechada o tempo todo | 0.32 | **Blackout às 5:12 AM** |
| Uma porta + tablet | 0.40 | Blackout às 4:10 AM |
| Duas portas | 0.52 | **Blackout às 3:12 AM** |
| Duas portas + tablet | 0.60 | Blackout às 2:46 AM |
| Uma porta + vazamento sem consertar | 0.47 | Blackout às 3:32 AM |

O importante: **segurar uma porta a noite toda agora mata**. No protótipo web (dreno de 1%/4,5s, +1 por porta, noite de 180s), segurar uma porta a noite inteira terminava com 20% — a estratégia ótima era fechar um lado e esquecer. Com as taxas novas, uma porta fechada custa ~19% por minuto; o jogador tem "orçamento" para algo como 2 minutos e meio de porta fechada além do dreno base. Isso força abrir e fechar, que é o jogo.

**Exibição:** HUD mostra `ENERGIA: 63%` e uma barra. Abaixo de 20% a barra fica âmbar e pulsa; abaixo de 10% fica vermelha, e um zumbido elétrico baixo entra no áudio. O HUD também mostra o **consumo atual** como barrinhas (`▮▮▯▯`) igual ao FNAF — 1 barra = só base, 2 = +1 fonte, etc. Isso ensina o custo sem explicar.

### 3.3 Portas

[ORIGINAL com ajustes de apresentação]

- Duas portas: esquerda e direita. Cada uma tem um botão físico na parede ao lado (parte 3D clicável; no mobile, também um botão no HUD). **Nota de implementação:** o jogo não carrega personagem (`CharacterAutoLoads = false`), e `ClickDetector`/`ProximityPrompt` exigem um personagem perto — por isso o clique/toque em objetos da sala é um raycast do `InputController` contra partes com o atributo `Interact`.
- Clicar alterna aberta ↔ fechada. Fechar: a porta (uma `Part`) desce em 0.6s com som de servo pesado e um "clank" ao encostar. Abrir: sobe em 0.8s.
- **Predição no cliente:** a porta começa a animar no mesmo frame do clique. O servidor confirma via `DoorStateChanged`. Se negar (porta travada pelo Hexágono, ou blackout), o cliente reverte com um som de "erro" e a porta treme.
- **Porta travada (`door_left_jammed` / `door_right_jammed`):** o botão fica vermelho piscando, clicar produz um buzz curto e uma mensagem no HUD "MOTOR TRAVADO — ver manual". A porta **congela no estado em que estava** (se estava fechada, continua fechada e gastando energia; se estava aberta, fica aberta). Isso torna o jam mais perigoso quando a porta está aberta e mais caro quando está fechada — os dois casos são ruins de jeitos diferentes. [AJUSTE — no original só o botão era desabilitado; o comportamento com porta fechada não era definido.]
- **Blackout:** as duas portas abrem sozinhas (perdem a trava magnética), os botões não respondem.

**Interação com IAs:** um inimigo físico na posição "soleira" (posição 3) que passa no teste de movimento com a porta fechada **volta para o palco** (posição 1). Com a porta aberta, entra e é jumpscare. [ORIGINAL]

### 3.4 O escritório (a sala 3D)

**Layout** (vista de cima, o jogador olha para o "norte"):

```
        ┌─────────────────────────────────┐
        │  CORREDOR ESQ           CORREDOR DIR  │   (fora do escritório — só visível
        │  (CAM 2)                (CAM 3)      │    pelo radar; no 3D é escuridão)
        └───┬─────────────────────────┬───┘
   PORTA ESQ│                         │PORTA DIR
   [btn]    │                         │    [btn]
            │       ┌───────────┐     │
            │       │   MESA    │     │
            │       │ [term][man]│    │
            │       └───────────┘     │
            │           (você)        │
            └─────────────────────────┘
```

- **Câmera:** fixa na posição da cadeira, altura de olhos. `CameraType = Scriptable`. O mouse (ou arrastar no touch) gira a câmera num arco de −60° a +60° no eixo horizontal, com suavização. Olhar totalmente para a esquerda enquadra a porta esquerda e o botão; totalmente para a direita, a direita. No centro, a mesa com o monitor e o caderno. [NOVO — o original era 2D estático]
- **Corredores:** além das portas há um corredor escuro. Na v1, só escuridão com uma luz fraca ao longe. Quando um inimigo físico está na soleira (posição 3), sua **silhueta** aparece na abertura da porta com luz fraca — isso é o "telegraph visual" e complementa o som. [NOVO — não existe no original, mas é o que faz o 3D valer a pena]
- **Mesa:** monitor (clique = abre terminal), caderno (clique = abre manual), tablet (clique = abre radar). No mobile, os três também têm botões no HUD. Um relógio digital na parede mostra a hora (`12:00 AM`) — quando `clock_glitch` está ativo, ele mostra `#$%@!?/<` mudando a cada 0.18s [ORIGINAL].
- **Iluminação:** duas luzes de teto. Blackout = as duas apagam com fade de 3s, sobra só o brilho do tablet (se ainda tiver bateria). Abaixo de 10% de energia, as luzes começam a tremular (flicker) — um aviso ambiental.

**Whitebox v1:** tudo em `Part` cinza. Sem texturas, sem modelos. O objetivo da Fase 2 é a sala *funcionar*, não ser bonita.

### 3.5 O tablet / radar (Global Node Map)

Este é o sistema que mais muda. O problema do original está no pilar 2: **o radar entregava informação atrasada demais para agir.** O ping levava 3s (1,5 + 1,5) para responder e mostrava o resultado por 5s. O Quadrado checava movimento a cada 4s (doc) ou 9s (código). Era possível receber "Quadrado no corredor" quando ele já estava na porta — e morrer de uma coisa que o jogador não tinha como saber.

**Solução em três partes** [AJUSTE]:

**(a) Ping mais rápido, com ciclo previsível.**

| Etapa | Tempo | O que o jogador vê |
|---|---|---|
| Clique em PING | 0s | Botão desabilita, `ENVIANDO PING...`, som de sonar |
| Processamento | 1.0s | Barra de progresso no visor |
| Resultado | exibido por 6s | Nós com anomalia piscam em vermelho; status: `SCAN COMPLETO. 2 ANOMALIAS.` |
| Cooldown | 3s | `SINAL PERDIDO. RECOMENDA-SE NOVO PING.`, botão volta |

Ciclo completo: 10s. Como o Quadrado age a cada 5s, um ping pode ficar desatualizado — e isso é intencional: o radar serve para **planejar** ("o Triângulo está no palco, posso ignorar a direita por um tempo"), não para **reagir**. Reagir é papel do som e da silhueta.

**(b) Telegraph de chegada na porta** [NOVO]: no instante em que um inimigo físico entra na posição 3 (soleira), o servidor dispara `EnemyAudioCue {side="left", cue="arrival"}`. O cliente toca um som posicional daquele lado (passo pesado + zumbido de servo) e acende a silhueta na abertura da porta. O jogador tem **no mínimo um tick inteiro** da IA (5s para o Quadrado, 8s para o Triângulo) para reagir, porque a IA só pode atacar no *próximo* teste. Nas noites altas o cue fica mais sutil (ver seção 7 — `arrivalCueVolume` por noite), mas nunca some.

**(c) Câmeras mortas dão informação parcial** [AJUSTE]: no original, o Círculo destruía câmeras e um nó morto simplesmente não mostrava nada — acumular câmeras mortas era cegueira total e morte por sorte. Agora um nó morto aparece como `DEAD` no mapa, **mas o ping ainda conta a anomalia**: o status diz `SCAN COMPLETO. 2 ANOMALIAS (1 EM NÓ CEGO).` O jogador sabe que *tem algo* que ele não vê, e fica em alerta, sem saber o lado. Cegueira parcial cria tensão; cegueira total cria frustração.

**O mapa** (o que aparece no tablet):

```
   GLOBAL SECURITY NODE MAP v2.4
   ┌──────────────────────────────────────────┐
   │        [CAM 1 — PALCO]                    │
   │            │        │                     │
   │   [CAM 2 — CORR. ESQ]  [CAM 3 — CORR. DIR]│
   │            │        │                     │
   │   [DOOR L] [ESCRITÓRIO] [DOOR R]          │
   │                                           │
   │   [CAM 4 — SALA DE SERVIDORES]            │
   │                                           │
   │   ┌────────────────────────────┐          │
   │   │  ▶ EMITIR PING RADAR GLOBAL │          │
   │   └────────────────────────────┘          │
   │   STATUS: SISTEMA EM ESPERA...            │
   │   FIREWALL: ▮▮▮▮▯    ⚡ 34%               │
   └──────────────────────────────────────────┘
```

- Os nós **DOOR L / DOOR R** não são câmeras — são sensores de proximidade da soleira. Não podem ser destruídos pelo Círculo. Aparecem em vermelho no ping quando um inimigo está na posição 3. (No original, a posição 3 acendia `cam3`, o que colidia com o corredor direito — bug, ver seção 8.)
- **CAM 4 — Sala de Servidores** é a "casa" dos inimigos hackers. Seu ping mostra o estado do firewall e, se houver um vírus do Círculo pendente (alerta ativo), o nó pulsa em amarelo. É a segunda câmera na ordem de destruição do Círculo — perdê-la tira a visibilidade dos hackers. [NOVO — no original, CAM 4 existia no mapa e na ordem de destruição, mas nenhum inimigo passava por ela, então perdê-la não custava nada.]
- O tablet mostra o firewall e a energia no rodapé para o jogador não precisar fechar o tablet para ver [ORIGINAL — o firewall já aparecia só com o tablet aberto].

**Custos e vulnerabilidade:**
- Tablet aberto = +0.08 %/s de energia [NOVO].
- Com o tablet aberto o jogador não vê o escritório e não pode fechar portas [ORIGINAL]. Os botões de porta do HUD ficam ocultos enquanto o tablet está aberto. **Exceção:** o telegraph sonoro continua funcionando — o jogador ouve o passo e precisa fechar o tablet para agir.
- `camera_offline` (Hexágono) desabilita o botão do tablet até `fix camera` [ORIGINAL].
- **Blackout:** o tablet funciona por 15s na bateria interna [ORIGINAL]; depois desliga.

**Sonar 3D (Noite 6+)** [ORIGINAL no roadmap, não implementado — Fase 7 ou backlog]: a partir da noite 6, o ping também produz um *flash* de 0.5s no 3D: a sala fica em wireframe branco-e-preto e, se um inimigo estiver na soleira, sua silhueta aparece no corredor. É uma versão visual do telegraph para as noites em que o som fica sutil. Implementação: trocar o `Lighting` para um preset "sonar" (Ambient branco, FogEnd curto, `ColorCorrection` em alto contraste) por 0.5s e mostrar um modelo wireframe do inimigo.

**Como ficou (Fase 6, `SonarController`):** o ping só acontece com o tablet aberto, que cobre a tela, e olhando para a mesa as soleiras ficam fora do quadro. Por isso, durante o flash, o fundo do tablet fica translúcido e o campo de visão abre para 115° por 0.5s, o que põe as duas soleiras na tela. A sala vira wireframe com um `Highlight` (preenchimento preto, contorno branco) e `ColorCorrection` sem saturação; a silhueta de quem estiver na soleira ganha um `Highlight` branco `AlwaysOnTop`, visível até através da porta fechada. Os Highlights são criados e destruídos a cada flash, porque desativados ainda ocupam o limite do motor.

### 3.6 O terminal

[ORIGINAL com ajustes de mobile e segurança]

O terminal é uma ScreenGui em tela cheia com estética de CLI: fundo preto, texto verde (`line-ok`), branco (`line-info`), vermelho (`line-err`), cinza (`line-echo` — eco do comando digitado). Prompt: `root@office:~$`.

**Abertura:** clique no monitor da mesa, tecla `T` (PC), botão no HUD (mobile). Fecha com `Esc`, botão FECHAR, ou tecla `T` de novo.

**Boot (primeira abertura da noite):**
```
GEOMETRY OS v1.0 ONLINE...
Sistemas estabilizados. Aguardando comando.
```

**Comandos** (tabela completa no Apêndice B):

| Comando | Efeito | Condição |
|---|---|---|
| `help` | Lista comandos | — |
| `status` | Firewall X/5, lista de sistemas corrompidos, energia, câmeras mortas | — |
| `clear` | Limpa a tela | — |
| `fix camera` | Repara `camera_offline` | sistema precisa estar corrompido |
| `unjam door_left` | Repara `door_left_jammed` | idem |
| `unjam door_right` | Repara `door_right_jammed` | idem |
| `sync clock` | Repara `clock_glitch` | idem |
| `seal power_leak` | Repara `power_leak` | idem |
| `restore_firewall` | Abre o puzzle de portas lógicas | firewall < 5 |
| `reset generator` | Override do gerador (ver 3.9) | 1× por noite |

Comando desconhecido: `command not found` (sem repetir o texto do jogador, ver Segurança abaixo). Comando de reparo com sistema não corrompido: `[WARN] door_left_jammed is not currently corrupted.` [ORIGINAL]

**O terminal no celular** [NOVO — restrição de plataforma]: digitar `unjam door_left` num teclado virtual com o Quadrado na porta é injusto. Solução: acima da linha de input, uma **paleta de comandos** — uma linha de botões pequenos com os comandos disponíveis *agora* (só os reparos de sistemas atualmente corrompidos, mais `status`, `restore_firewall` e `reset generator` quando aplicáveis). Tocar num botão preenche o input; o jogador ainda precisa apertar ENVIAR. No PC a paleta também aparece (é útil), e `Tab` autocompleta. A ficção continua sendo "digitar no terminal"; a paleta é o "histórico de comandos recentes" do sistema.

**Segurança:** todo comando vai ao servidor via `TerminalCommand {text}`. O servidor valida (lista fechada de comandos, `string.lower`, `trim`), aplica, e devolve `TerminalEcho` para o cliente imprimir. O cliente **nunca** decide o resultado de um comando. Limite: 5 comandos por segundo por jogador (anti-spam).

**Filtro de texto:** em solo, o texto digitado só é exibido para quem digitou, o que não exige filtragem pela política do Roblox. Se um dia for co-op e os comandos de um jogador aparecerem para outros, o eco precisa passar por `TextService:FilterStringAsync`. Como todo comando válido vem de uma lista fechada, a solução simples é: **ecoar o comando canônico da lista**, não o texto cru do jogador. Comando inválido ecoa `command not found` sem repetir o texto. Assim nunca há texto livre na tela, e não há o que filtrar.

### 3.7 O manual (notebook)

[ORIGINAL]

Caderno na mesa. Clique abre um overlay paginado com estética de papel e carimbo `MANUAL DE PROCEDIMENTOS — Vol. 1`. Botões ◀ ANTERIOR / PRÓXIMA ▶ e `1 / 4`.

Páginas (texto completo no Apêndice B):
1. **Procedimentos de emergência** — explica que sistemas corrompidos se consertam pelo terminal com o comando exato.
2. **Códigos de reparo I** — `fix camera`, `unjam door_left`, `unjam door_right` com descrição.
3. **Códigos de reparo II** — `sync clock`, `seal power_leak`.
4. **Firewall — restauração** — `restore_firewall` e como funciona o puzzle.
5. **[NOVO] Protocolo de blackout** — explica o `reset generator`, os 15s do tablet e a punição por uso acima de 50%. (No original o jogador só descobria isso lendo o `Tutorial.md` fora do jogo.)

O manual pode ser lido com o jogo rodando (não pausa). Enquanto está aberto, o jogador não vê o escritório. Isso é intencional: ler o manual sob pressão é parte da tensão. A Noite 0 obriga o jogador a abrir o manual uma vez para ele saber que existe.

### 3.8 Os inimigos

Todos os inimigos usam o mesmo **teste de movimento**: a cada tick (intervalo próprio), o servidor sorteia um inteiro de 1 a 20. Se `sorteio <= nível`, a IA age. Nível 0 = a IA está desligada nesta noite. Nível 20 = age em todo tick. [ORIGINAL — é o sistema do FNAF e funciona.] O Hexágono no original usava um teste diferente (1-100, ataca acima de 80); no port ele usa o mesmo d20 por consistência [AJUSTE].

#### 3.8.1 Quadrado Azul — inimigo físico, esquerda [ORIGINAL]

- **Tick:** 5s.
- **Caminho:** `1 Palco (CAM 1)` → `2 Corredor Esq (CAM 2)` → `3 Porta Esq (DOOR L)` → `4 Escritório (morte)`.
- **Na posição 3, ao passar no teste:** porta esquerda fechada → volta para 1 com som de impacto ("BAM") do lado esquerdo. Porta aberta → posição 4, jumpscare.
- **Telegraph:** ao chegar em 3: `EnemyAudioCue{side="left", cue="arrival"}` + silhueta na porta esquerda.
- **Ao ser rebatido:** `EnemyAudioCue{side="left", cue="repelled"}` — o jogador aprende que pode abrir a porta.
- **Jumpscare:** o Quadrado (um cubo azul com "olhos" — dois quadrados pretos) entra pela esquerda, a câmera é forçada a olhar para ele, ele avança até encher a tela em 0.4s com um ruído de estática e um acorde grave. 3s no total, depois tela de game over.

#### 3.8.2 Triângulo Vermelho — inimigo físico, direita [ORIGINAL]

- **Tick:** 8s (mais lento que o Quadrado, assíncrono).
- **Caminho:** `1 Palco (CAM 1)` → `2 Corredor Dir (CAM 3)` → `3 Porta Dir (DOOR R)` → `4 Escritório (morte)`.
- Mesmas regras de porta, telegraph e rebate, espelhadas.
- **Jumpscare:** prisma triangular vermelho, mesma coreografia pela direita, ruído mais agudo.

**Nota de design sobre os dois físicos:** o Quadrado é a ameaça "de ritmo" (frequente, previsível); o Triângulo é a ameaça "de distração" (raro, mas chega quando você está ocupado com a esquerda ou com o terminal). O balanceamento por noite (seção 7) mantém o Triângulo sempre alguns níveis abaixo do Quadrado.

#### 3.8.3 Círculo Amarelo — inimigo hacker, vírus de câmera [ORIGINAL com ajustes]

- **Tick:** 15s.
- **Ao passar no teste:** se não há alerta de vírus ativo e o terminal não está aberto, dispara o **alerta de vírus**: banner vermelho piscando no HUD `ANOMALIA DETECTADA — ABRIR TERMINAL`, som de alarme de sistema (curto, repetitivo), e CAM 4 passa a pulsar em amarelo no radar.
- **Fusível** [NOVO]: o alerta tem 30 segundos. Se o jogador não abrir o terminal nesse tempo, o vírus destrói uma câmera sozinho. (No original o alerta ficava parado indefinidamente sem consequência, o que removia a urgência.) O HUD mostra uma barra fina esvaziando abaixo do banner.
- **Minigame de sintaxe:** ao abrir o terminal com alerta ativo, em vez do prompt aparece:
  ```
  SISTEMA CORROMPIDO. SELECIONE A ANOMALIA:
  [Function_Door] [Central_Connection] [Meat_Syntax] [System_Boot] [Camera_Feed]
  [Audio_Link] [Power_Grid] [Data_Log] [Motion_Sensor]
  ```
  9 strings: 8 sorteadas da lista de palavras normais (podem repetir, como no original) e 1 da lista de palavras de erro, embaralhadas. O jogador clica na infectada.
  - **Tempo limite** [NOVO]: 15s. Esgotar = errar.
  - **Acerto:** `[OK] Vírus expurgado.`, terminal fecha, alerta some.
  - **Erro:** `[ERR] Sintaxe válida detectada. Node de vídeo destruído.`, terminal fecha, próxima câmera da ordem morre.
- **Ordem de destruição:** `CAM 1 → CAM 4 → CAM 2 → CAM 3` [ORIGINAL]. Câmera morta é permanente pela noite. Nó `DEAD` no radar; ping ainda conta a anomalia (ver 3.5c).
- **Nunca mata diretamente.** O Círculo só tira informação. Sua "morte" é a morte que ele causa por cegueira.
- **Listas de palavras:** Apêndice B. Devem crescer com o tempo — a palavra errada não pode ficar memorizável.

#### 3.8.4 Hexágono Ciano — inimigo hacker, vírus de firewall [ORIGINAL com ajustes]

- **Tick:** 25s.
- **Firewall:** 5 camadas (`▮▮▮▮▮`). Começa cheio em toda noite.
- **Ao passar no teste:** rompe 1 camada e **corrompe um sistema** sorteado entre os ainda íntegros:

  | Sistema | Efeito | Reparo |
  |---|---|---|
  | `camera_offline` | Botão do tablet desabilitado | `fix camera` |
  | `door_left_jammed` | Porta esquerda congela no estado atual | `unjam door_left` |
  | `door_right_jammed` | Porta direita congela | `unjam door_right` |
  | `clock_glitch` | Relógio vira caracteres aleatórios | `sync clock` |
  | `power_leak` | +0.15 %/s de dreno | `seal power_leak` |

  Cada rompimento: som de vidro digital quebrando, o HUD do firewall pisca, e uma linha aparece no terminal (se aberto) `[ALERT] door_left_jammed corrupted by HEXAGON`.
- **Se todos os 5 sistemas já estão corrompidos** e ele passa no teste, ele rompe a camada sem corromper nada novo [ORIGINAL].
- **Firewall em 0 — INTRUSÃO** [AJUSTE]: no original, chegar a 0 camadas era game over instantâneo, sem aviso. Agora inicia uma **contagem de 20s** com alarme contínuo e o HUD inteiro tingido de ciano: `INTRUSÃO EM CURSO — RESTAURE O FIREWALL`. Se o jogador restaurar pelo menos 1 camada (via `restore_firewall` + puzzle) antes do fim, a intrusão é abortada. Se não, jumpscare do Hexágono. É uma morte que o jogador vê chegando e pode evitar — pilar 2.
- **Reparo em duas etapas** [ORIGINAL]: (1) consertar o sistema corrompido com o comando do manual; (2) `restore_firewall` para abrir o puzzle e recuperar a camada. Os dois são independentes: dá para restaurar a camada sem consertar o sistema, e vice-versa.
- **Puzzle de portas lógicas** [ORIGINAL]: abre um painel com uma tabela-verdade de duas entradas (A, B → OUT) gerada a partir de uma porta sorteada entre `AND, OR, XOR, NAND, NOR, XNOR`, e seis botões com as portas em ordem embaralhada. Acerto: `+1 camada`, painel fecha em 1.2s. Erro: `−5% energia`, nova tabela em 1.4s. O painel pode ser cancelado a qualquer momento. [NOVO] O puzzle não pode ser "farmado": só abre se `firewall < 5` (já era assim) e tem cooldown de 10s entre acertos.
- **Jumpscare:** diferente dos físicos — não é um monstro entrando. A tela do escritório é tomada por uma grade hexagonal ciana que se expande do monitor, os textos do HUD viram lixo de caracteres, e um tom digital sobe até estourar. Termina em `FIREWALL BREACHED`.

### 3.9 Blackout e `reset generator`

[ORIGINAL com uma ambiguidade resolvida]

**Quando a energia chega a 0:**
1. As portas abrem sozinhas (som de trava magnética soltando, as duas partes sobem).
2. Botões de porta travam.
3. Luzes fazem fade-out em 3s. Sobra o brilho do tablet/monitor.
4. **Bateria interna do tablet: 15 segundos.** Durante esses 15s, o tablet e o terminal continuam funcionando. (O `Tutorial.md` dizia que o terminal "para de responder" e ao mesmo tempo que a única salvação é digitar no terminal — contradição. Resolvido: **o terminal roda na bateria do tablet**, é isso que dá os 15s de chance.)
5. Após 15s: escuridão total. Tablet e terminal desligam. Só o relógio continua (no escuro, o jogador não vê a hora, mas ela passa).
6. Inimigos físicos: durante o blackout, seus ticks caem para a metade (Quadrado 2.5s, Triângulo 4s) [NOVO — eles "sentem o cheiro"]. Com as portas abertas, a morte é quase certa — mas dá para ganhar se estava perto das 6.

**`reset generator`:**
- Digitado no terminal. Uma vez por noite [AJUSTE — no original era ilimitado; ilimitado zera o risco].
- Define a energia para **50%**, seja qual for o valor atual.
- Se a energia estava **acima de 50%**: é a *punição por desespero* — o jogador perde energia e o terminal responde `[AVISO] Sobrecarga detectada! Bateria descarregada para 50%.` [ORIGINAL]
- Se estava abaixo (incluindo blackout): `[OK] Gerador forçado. Bateria restaurada para 50%.` Se estava em blackout, cancela o timer do tablet, luzes voltam em 1s, botões destravam, portas **continuam abertas** (o jogador precisa fechá-las de novo). [ORIGINAL]
- O manual (página 5) explica isso. A Noite 0 não obriga o jogador a usar — é uma mecânica de descoberta.

### 3.10 Jumpscares, game over, vitória

- **Jumpscare** dura 3s, é inescapável, e é diferente por inimigo (3.8). O cliente recebe `Jumpscare{enemy}` e executa a coreografia; o servidor já encerrou a sessão.
- **Game over:** tela preta com estática, `FALHA CRÍTICA — NOITE 3`, o nome do inimigo em letras pequenas (`anomalia: QUADRADO AZUL`), e dois botões: `TENTAR DE NOVO` (recomeça a mesma noite) e `MENU`. Estatística de mortes por inimigo é salva (3.12).
- **Vitória:** às 6:00 AM o Scheduler para, o som ambiente corta, um "ding" suave, e o relógio na tela muda para `6:00 AM` em fonte grande com fade. 3s depois: `NOITE 3 CONCLUÍDA`, salva, volta ao menu. Se era a noite 7: tela especial de créditos [DECIDIR conteúdo] e desbloqueia Custom Night.

### 3.11 Áudio — lista de cues

Cada linha é um som que precisa existir. Nomes são os `SoundId` lógicos usados no código (o asset real é config).

| Cue | Quando | Posicional? | Notas |
|---|---|---|---|
| `ambient_hum` | loop durante a noite | não | Zumbido de servidor. Base de tudo. |
| `ambient_low_power` | energia < 10% | não | Zumbido elétrico instável, entra por cima. |
| `door_close` | porta descendo | sim (lado) | Servo pesado + clank. |
| `door_open` | porta subindo | sim | |
| `door_jammed` | clique em porta travada | sim | Buzz curto. |
| `door_impact` | inimigo rebatido | sim | "BAM" — o jogador aprende que deu certo. |
| `enemy_arrival_left/right` | inimigo chega na soleira | sim | **O cue mais importante do jogo.** Passo pesado + servo. Volume por noite (seção 7). |
| `ping_send` / `ping_result` | radar | não | Sonar. |
| `tablet_open` / `tablet_close` | | não | Clique + estática curta. |
| `terminal_open` / `terminal_key` / `terminal_ok` / `terminal_err` | | não | `terminal_key` a cada caractere digitado. |
| `virus_alert` | alerta do Círculo | não | Alarme repetitivo, para quando o terminal abre. |
| `firewall_break` | camada rompida | não | Vidro digital. |
| `firewall_restore` | camada recuperada | não | |
| `intrusion_alarm` | firewall em 0 | não | Loop de 20s, sobe de intensidade. |
| `puzzle_ok` / `puzzle_err` | | não | |
| `blackout` | energia em 0 | não | Trava magnética + queda de energia. |
| `generator_reset` | comando | não | Gerador ligando. |
| `jumpscare_square` / `_triangle` / `_hexagon` | | não | Estática + acorde. |
| `dawn` | 6 AM | não | Ding + silêncio. |
| `menu_glitch` | glitch do menu | não | |

Fonte dos sons: biblioteca de áudio do Roblox (Creator Store) ou sons próprios subidos pelo time. **Não usar** sons de outros jogos.

> Status (Fase 6): todos os cues têm asset em `GameConfig.Audio.ids`, da biblioteca licenciada do Roblox (ProSoundEffects e cliques oficiais). Foram escolhidos pelo nome, **sem audição**: o time precisa ouvir cada um no Studio e trocar o que não servir. O nome de cada som está no comentário ao lado do id. `enemy_arrival_*` é o mais importante (seção 7: volume por noite) e merece atenção primeiro.

### 3.12 Noite 0 — tutorial (roteirizado)

[ORIGINAL — só o diálogo de abertura existia; o resto é definido aqui]

A Noite 0 não tem RNG. É uma sequência de passos guiados pela **Unidade de Assistência de Debug** (a figura cinza do `Unknown.png`), com diálogo em máquina de escrever (35ms por caractere, clique pula). Estrutura:

1. **Boot:** `INICIALIZANDO SIMULAÇÃO_` por 3s. Fade-in da figura (4s). Diálogo de abertura (as 4 falas originais, Apêndice B).
2. **Passo — olhar:** "Use o mouse (ou arraste) para olhar em volta." Espera o jogador girar a câmera ≥ 30° para cada lado.
3. **Passo — portas:** "Feche a porta esquerda." Espera. "Note o consumo de energia." Aponta para as barrinhas. "Abra de novo. Portas fechadas gastam a energia que você não tem."
4. **Passo — radar:** "Abra o tablet e emita um ping." O servidor coloca um Quadrado *fake* em CAM 2 só para o ping mostrar algo. "Uma anomalia no corredor esquerdo. Quando ela chegar à porta, você vai ouvir." Toca `enemy_arrival_left` e acende a silhueta. "Feche a porta." Espera. Toca `door_impact`. "Rebatida. Abra a porta para economizar."
5. **Passo — manual:** "Abra o manual na mesa e leia a página 2." Espera abrir e ir à página 2.
6. **Passo — terminal:** "Simulando uma corrupção..." Aplica `door_right_jammed` de verdade. "A porta direita travou. O manual diz o que fazer." Espera o jogador digitar (ou tocar na paleta) `unjam door_right`. "Reparado."
7. **Passo — firewall:** "Uma camada do firewall foi rompida." Aplica. "Digite restore_firewall e resolva o circuito." Espera acerto (erros não punem na Noite 0).
8. **Encerramento:** "Você está pronto. Ou tão pronto quanto qualquer um estaria. Boa sorte na Noite 1." Fade. Salva `currentNight = 1`.

A Noite 0 pode ser pulada no menu depois de concluída uma vez (`[Tutorial]` fica disponível no menu).

**Como ficou (Fase 7):** o `TutorialService` divide os 8 passos em 16 sub-passos de uma espera cada (clique, olhar, porta, ping, página 2 do manual, reparo, puzzle). Na Noite 0 o relógio não anda e a energia não drena: quem encerra a noite é o roteiro, com uma vitória. Esperas da sala são conferidas no servidor; clique, olhar e página do manual vêm do cliente pelo `TutorialAdvance`, validado contra o passo atual. A caixa de diálogo fica no topo e por cima do tablet e do terminal, para o jogador ler enquanto usa; some com o manual aberto.

### 3.13 Progressão por noite

Cada noite deve **introduzir algo** — o pilar contra "11 repetições da mesma coisa". O original planejava 11 noites; o port define **7 + Noite 0 + Custom Night** [AJUSTE].

| Noite | O que entra | Sensação desejada |
|---|---|---|
| 0 | Tutorial roteirizado | "Entendi as ferramentas." |
| 1 | Só Quadrado e Triângulo, fracos | "Aprendi o ritmo porta/radar. Sobrei energia." |
| 2 | Círculo entra (minigame de sintaxe) | "Tem uma segunda coisa pra prestar atenção." |
| 3 | Hexágono entra (terminal, manual, puzzle) | "O sistema está se voltando contra mim." |
| 4 | Todos ativos, ritmo sobe | "Primeira noite realmente difícil. Morri uma vez." |
| 5 | Ritmo sobe; blackout se torna provável | "Descobri que reset generator existe. Usei mal uma vez." |
| 6 | Sonar 3D no ping; cue de chegada mais sutil | "Preciso confiar mais no ping do que no ouvido." |
| 7 | Noite final; todos altos | "Isso foi injusto. De novo." |
| Custom | Jogador escolhe 0-20 por IA | Replay. `20/20/20/20` é o "modo impossível". |

Os níveis exatos estão na seção 7.

### 3.14 Save

[AJUSTE — localStorage → DataStore]

Dados persistidos por jogador (chave `player_<UserId>`):

```lua
{
    version = 1,
    currentNight = 0,          -- noite que o [Continue] abre
    maxNightUnlocked = 0,      -- maior noite alcançada (0 a 8; 8 = venceu a 7)
    tutorialDone = false,
    stats = {
        nightsWon = 0,
        deaths = 0,
        deathsBy = { square = 0, triangle = 0, hexagon = 0 },
        bestTimeAlive = 0,     -- segundos, para o futuro
    },
    settings = {
        masterVolume = 1,
        showCommandPalette = true,
    },
}
```

Regras: carrega no `PlayerAdded`, salva na vitória, na morte (só stats) e no `PlayerRemoving`. Salvar com `pcall` + 3 tentativas + backoff. `version` permite migrar o schema depois. Ver 5.10 para detalhes.

**Progressão (Fase 7):** o save novo começa na Noite 0, porque New Game abre o tutorial (3.1). New Game zera `currentNight` para 0; vencer o tutorial marca `tutorialDone` e libera a Noite 1 sem voltar a noite de quem só está revendo o tutorial. Vencer a noite N (1-7) faz `currentNight = min(N+1, 7)` e `maxNightUnlocked = max(atual, N+1)`; depois da 7, Continue reabre a 7 e a Custom Night fica liberada. A Custom Night não mexe na progressão. Vitórias e mortes contam em `stats`; `bestTimeAlive` guarda os segundos de noite mais longos.

---

## 4. CENÁRIOS NARRADOS DE JOGABILIDADE

Estes cenários são "partidas de mentira" escritas com os números da seção 7. Servem para três coisas: (1) validar que o design produz as sensações da seção 3.13; (2) dar ao Claude Code exemplos concretos do comportamento esperado; (3) virar **casos de teste** — cada cenário pode ser reproduzido com o Scheduler em modo determinístico (seed fixa) e verificado.

Formato: `[tempo real] hora do jogo | energia | evento`. Sorteios são mostrados como `d20=7 vs nível 3` (7 > 3 → não age).

### 4.1 Noite 1 completa — o jogador aprende o ritmo

Config: Quadrado 3, Triângulo 2, Círculo 0, Hexágono 0. Quadrado tick 5s, Triângulo 8s.

```
[00:00] 12:00 AM | 100% | Boot. HUD com fade. "GEOMETRY OS v1.0". Zumbido ambiente.
[00:03] 12:00 AM | 100% | Scheduler inicia. Quadrado em 1 (Palco). Triângulo em 1.
[00:05]          | 99.8 | Quadrado tick: d20=14 vs 3 → parado.
[00:08]          | 99.4 | Triângulo tick: d20=19 vs 2 → parado.
[00:10]          | 99.2 | Quadrado tick: d20=2 vs 3 → MOVE. Posição 2 (Corredor Esq, CAM 2).
                         Nenhum som. O jogador não sabe.
[00:15]          | 98.6 | Quadrado tick: d20=11 → parado.
[00:20]          | 98.0 | Jogador abre o tablet (+0.08/s). Clica PING. Som de sonar.
[00:21]          | 97.8 | Resultado: CAM 2 pisca vermelho. "SCAN COMPLETO. 1 ANOMALIA."
                         Jogador pensa: "esquerda. Ainda no corredor."
[00:25]          | 97.0 | Quadrado tick: d20=3 vs 3 → MOVE. Posição 3 (DOOR L).
                         → EnemyAudioCue{left, arrival}: passo pesado à esquerda.
                         → Silhueta azul aparece na abertura da porta esquerda.
                         Jogador ainda está no tablet. Ouve. Fecha o tablet (0.3s).
[00:26]          | 96.8 | Jogador gira a câmera para a esquerda. Vê a silhueta. Clica no botão.
                         Porta desce (0.6s). door_close à esquerda. Dreno agora 0.32/s.
[00:30]          | 95.6 | Quadrado tick: d20=1 vs 3 → age. Porta FECHADA → volta para 1.
                         → door_impact à esquerda ("BAM"). Silhueta some.
                         Jogador: "funcionou". Não abre a porta ainda — não confia.
[00:35]          | 94.0 | Quadrado tick: d20=16 → parado (está no palco).
[00:40]          | 92.4 | Jogador abre o tablet. PING. CAM 1 vermelho. "1 ANOMALIA."
                         Triângulo também está em CAM 1, mas o ping conta por nó,
                         então mostra 1 nó com anomalia. (Decisão de design: o ping
                         conta NÓS, não inimigos. Dois no mesmo nó = "1 ANOMALIA".
                         Isso esconde informação de propósito.)
[00:42]          | 91.8 | Jogador fecha o tablet, ABRE a porta esquerda. Dreno volta a 0.12/s.
                         "Fiquei 16 segundos com a porta fechada. Custou ~5%."
[00:48]          | 91.1 | Triângulo tick: d20=2 vs 2 → MOVE. Posição 2 (CAM 3).
[01:00]  1:00 AM | 89.6 | Relógio muda. Nada aconteceu por 18s. Jogador relaxa.
[01:04]          | 89.1 | Triângulo tick: d20=1 → MOVE. Posição 3 (DOOR R).
                         → passo pesado à DIREITA. Silhueta vermelha à direita.
[01:05]          | 89.0 | Jogador vira para a direita, fecha a porta direita.
[01:12]          | 87.4 | Triângulo tick: d20=9 vs 2 → parado. (Fica na porta. Tenso.)
[01:20]          | 84.8 | Triângulo tick: d20=15 → parado. Jogador: "ele não vai embora?"
                         Já são 15s de porta fechada. −0.20/s a mais.
[01:28]          | 82.2 | Triângulo tick: d20=2 → age. Porta fechada → volta para 1. BAM.
[01:29]          | 82.0 | Jogador abre a porta direita.
[01:30]          | 81.9 |
        ...
[03:00]  3:00 AM | 71.5 | Duas chegadas do Quadrado nesse intervalo, ambas rebatidas.
[03:40]          | 65.2 | Quadrado chega em 3. Jogador está com o tablet aberto lendo o mapa,
                         demora 3s pra fechar e virar. Fecha a porta a 1s do próximo tick.
[03:45]          | 63.8 | Quadrado tick: d20=8 vs 3 → parado. (Ufa. Não teria importado —
                         a porta estava fechada — mas o jogador não sabia se dava tempo.)
        ...
[05:00]  5:00 AM | 52.0 |
[05:58]          | 44.9 | Últimos 2s: graceBeforeDawn — nenhuma IA age.
[06:00]  6:00 AM | 44.6 | VITÓRIA. dawn.ogg. "NOITE 1 CONCLUÍDA". Salva currentNight = 2.
```

**O que o cenário valida:**
- O jogador termina com ~45% — sobrou energia, como a seção 3.13 pede para a Noite 1.
- A porta é fechada ~6 vezes na noite, por ~8-15s cada. É o ritmo certo: abre-fecha, não "fecha e esquece".
- O telegraph sonoro fez todo o trabalho de reação; o radar serviu para *saber onde estavam* nos intervalos.
- O Triângulo "parado na porta por 24s" é a primeira lição de custo: às vezes a porta precisa ficar fechada muito tempo, e isso dói.

### 4.2 A morte que o radar antigo causava — e por que não acontece mais

Este cenário existe para documentar o motivo do redesenho do radar (3.5). Mesma situação, dois designs.

**Com o design do protótipo web** (ping 3s + resultado 5s; Quadrado tick 4s):

```
[00:00] Quadrado em 2 (corredor). Jogador clica PING.
[00:01.5] "SINAL RECEBIDO. ANALISANDO..."
[00:03]  Quadrado tick → MOVE para 3 (porta). Sem som. Sem silhueta.
[00:03]  Resultado do ping renderiza: "CAM 2" em vermelho. (Já está errado.)
         Jogador: "corredor. Tenho tempo."
[00:07]  Quadrado tick → age. Porta aberta → JUMPSCARE.
```
O jogador morreu com a informação "ele está no corredor" na tela. Ele não tinha como saber. Viola o pilar 2.

**Com o design do port:**

```
[00:00] Quadrado em 2. Jogador clica PING (1s).
[00:01] "CAM 2" vermelho. Correto neste instante.
[00:05] Quadrado tick → MOVE para 3.
        → SOM: passo pesado à esquerda. Silhueta na porta.
        Jogador ouve mesmo com o tablet aberto.
[00:06] Jogador fecha o tablet, vira, fecha a porta. (Ele tinha até [00:10].)
[00:10] Quadrado tick → age. Porta fechada → rebatido. BAM.
```
O ping estava "errado" da mesma forma às [00:05], mas não importou: a informação de *reação* veio pelo som, com uma janela garantida de um tick. O radar informa planejamento; o som informa urgência.

**Consequência para a dificuldade:** as noites altas não tiram o som — reduzem o volume (`arrivalCueVolume`) e, na noite 6+, adicionam ruído ambiente mais alto. O jogador experiente passa a *procurar* o som. Isso é dificuldade por atenção, não por informação sonegada.

### 4.3 Noite 3 — o Hexágono trava a porta errada na hora errada

Config: Quadrado 6, Triângulo 5, Círculo 3, Hexágono 2. Hexágono tick 25s.

```
[02:10]  2:00 AM | 71% | Firewall ▮▮▮▮▮. Triângulo em 2 (CAM 3) — jogador sabe pelo último ping.
[02:15]          | 70% | Hexágono tick: d20=2 vs 2 → ROMPE. Firewall ▮▮▮▮▯.
                         Sorteio de sistema entre os 5 íntegros → door_right_jammed.
                         → firewall_break (vidro digital). Botão da porta direita pisca vermelho.
                         → Porta direita estava ABERTA. Congela aberta.
                         Terminal está fechado; nada é impresso. HUD: "[!] door_right_jammed".
[02:16]          | 70% | Jogador vê o botão vermelho. "Travou. E o Triângulo está do lado de lá."
                         Decisão: manual ou terminal direto?
                         Ele lembra do comando? É a primeira vez que vê esse. Abre o MANUAL.
[02:19]          | 69% | Página 2: "unjam door_right — Libera o motor travado da porta direita."
[02:20]          | 69% | Fecha o manual. Triângulo tick: d20=4 vs 5 → MOVE. Posição 3 (DOOR R).
                         → passo pesado à DIREITA. Silhueta.
                         Porta travada aberta. Botão não responde (buzz).
                         Jogador tem até [02:28] (próximo tick do Triângulo).
[02:21]          | 69% | Abre o terminal (tecla T). Digita "unjam door_right" (ou toca na paleta,
                         que já mostra [unjam door_right] porque é o único sistema corrompido).
[02:24]          | 68% | ENTER. Servidor valida → repairSystem → "[OK] door_right_jammed restored."
                         Botão volta ao normal.
[02:25]          | 68% | Fecha o terminal, vira à direita, fecha a porta. door_close.
[02:28]          | 67% | Triângulo tick: d20=3 vs 5 → age. Porta FECHADA → volta para 1. BAM.
                         Jogador: respiração. 8 segundos do aviso ao BAM. Deu.
[02:29]          | 67% | Abre a porta direita.
                         Firewall ainda em ▮▮▮▮▯. "Preciso restaurar, senão ele quebra mais."
[02:35]          | 66% | Abre o terminal. "restore_firewall". Painel do puzzle:
                            A  B  OUT
                            0  0   1
                            0  1   0
                            1  0   0
                            1  1   0
                         [XOR] [NOR] [AND] [XNOR] [OR] [NAND]
                         Jogador: "só é 1 quando os dois são 0... NOR." Clica NOR.
[02:38]          | 65% | "[OK] NOR bate com a tabela. +1 camada de Firewall." ▮▮▮▮▮.
                         Painel fecha. Cooldown de 10s antes de outro restore.
```

**O que o cenário valida:**
- A cadeia manual → terminal → porta leva ~9s para um jogador que não sabe o comando. Com o Triângulo em tick de 8s, é apertado mas viável. Com o Quadrado (5s) travando a porta esquerda, um jogador que precisa ler o manual **provavelmente morre** — o que é aceitável na Noite 3 (é a lição "decore os comandos") e é exatamente a função da paleta no mobile.
- `door_right_jammed` com a porta aberta é o pior caso. Com a porta fechada, seria "só" um vazamento de energia. A assimetria é intencional.

### 4.4 Noite 4 — o Círculo ataca com o tablet aberto

Config: Quadrado 8, Triângulo 7, Círculo 4, Hexágono 4.

```
[01:30]  1:00 AM | 78% | Jogador com tablet aberto, esperando o cooldown do ping.
[01:32]          | 78% | Círculo tick: d20=3 vs 4 → ATACA.
                         → virus_alert (alarme). Banner vermelho no HUD:
                           "ANOMALIA DETECTADA — ABRIR TERMINAL" + barra de 30s.
                         → CAM 4 pulsa amarelo no radar.
                         Tablet continua aberto. Jogador tem 30s.
[01:33]          | 78% | Jogador: "fecho o tablet e vou pro terminal, ou pingo antes?"
                         Último ping mostrou Quadrado em 2. Faz 9s. Ele pode estar na porta.
                         Decide: PING primeiro (1s).
[01:34]          | 78% | Resultado: DOOR L vermelho. "1 ANOMALIA." Quadrado está na porta.
                         (Ele chegou há 2s; o passo tocou, mas o alarme do vírus abafou.
                          NOTA DE DESIGN: virus_alert deve tocar em canal separado e com
                          ducking — abaixar 40% do volume enquanto enemy_arrival toca.)
[01:35]          | 78% | Fecha tablet. Vira. Fecha porta esquerda. Barra do vírus: 27s.
[01:37]          | 77% | Quadrado tick: rebatido. BAM.
[01:38]          | 77% | Abre porta. Abre terminal (T). Minigame:
                         "SISTEMA CORROMPIDO. SELECIONE A ANOMALIA:"
                         [Power_Grid] [Camera_Feed] [Data_Log] [Shadow_Byte] [System_Boot]
                         [Audio_Link] [Motion_Sensor] [Function_Door] [Power_Grid]
                         Timer: 15s.
[01:41]          | 77% | Clica Shadow_Byte. "[OK] Vírus expurgado." Terminal fecha. Alarme para.
```

**Variante — o jogador ignora:** se em [02:02] (30s depois) o terminal não foi aberto, `CAM 1` morre: nó `DEAD`, som `firewall_break` (reutilizado) e mensagem no HUD `NODE CAM 1 DESTRUÍDO`. A partir daí, o ping do palco diz `1 ANOMALIA (1 EM NÓ CEGO)` sempre que alguém estiver lá — o jogador sabe que tem gente "em casa", mas não se está prestes a sair.

**Variante — erro no minigame:** clicou `Power_Grid`. `[ERR] Sintaxe válida detectada. Node de vídeo destruído.` CAM 1 morre. O terminal fecha e o alerta some (o vírus "ganhou" esta rodada).

### 4.5 Noite 5 — blackout salvo por `reset generator` no último segundo

Config: Quadrado 10, Triângulo 9, Círculo 6, Hexágono 5.

```
[04:10]  4:00 AM | 14% | HUD âmbar pulsando. ambient_low_power. Luzes tremulando.
                         power_leak ativo desde [03:40] (jogador não consertou — estava
                         ocupado com o Quadrado). Dreno: 0.12 + 0.15 = 0.27/s sem portas.
[04:20]          | 11% | Quadrado chega na porta esquerda. Jogador fecha. Dreno 0.47/s.
[04:25]          | 9%  | HUD vermelho. Quadrado tick: d20=12 vs 10 → parado. Fica na porta.
[04:30]          | 6%  | Quadrado tick: d20=15 → parado. Jogador: "abre ou segura?"
                         Segura.
[04:35]          | 4%  | Quadrado tick: d20=6 → rebatido. BAM. Abre a porta.
[04:36]          | 4%  | Dreno 0.27/s. ~15s de energia.
                         Jogador: "seal power_leak agora." Abre o terminal. Digita.
[04:40]          | 3%  | "[OK] power_leak restored." Dreno 0.12/s. ~25s de energia.
                         Não é suficiente para chegar às 6 (faltam 80s).
[04:41]          | 3%  | Decisão: "reset generator" agora (3% → 50%) ou esperar o blackout?
                         Não há motivo para esperar. Mas o jogador não sabe que o comando
                         existe — ele nunca abriu a página 5 do manual.
[05:05]  5:00 AM | 0%  | BLACKOUT. blackout.ogg. Portas sobem. Luzes: fade 3s.
                         Só o brilho do tablet/monitor. Timer interno: 15s.
                         Ticks das IAs caem pela metade: Quadrado 2.5s, Triângulo 4s.
[05:06]          | 0%  | Jogador em pânico abre o manual (funciona? SIM — o manual é um
                         objeto físico, não depende de energia). Folheia. Página 5:
                         "PROTOCOLO DE BLACKOUT — reset generator".
[05:12]          | 0%  | Abre o terminal (bateria do tablet: 8s restantes). Digita.
                         Quadrado tick [05:10]: d20=9 vs 10 → MOVE para 2.
                         Quadrado tick [05:12.5]: d20=4 → MOVE para 3. Passo à esquerda.
[05:17]          | 0%  | ENTER. "[OK] Gerador forçado. Bateria restaurada para 50%."
                         (bateria do tablet tinha 3s). Luzes voltam (1s). Botões destravam.
                         PORTAS CONTINUAM ABERTAS. Quadrado na soleira.
[05:17.5]        | 50% | Quadrado tick: d20=2 → age. Porta ABERTA → JUMPSCARE.
```

**Morte explicável:** o jogador salvou a energia mas esqueceu que o gerador não fecha as portas. Ele morre sabendo exatamente o quê fazer diferente: fechar a esquerda **antes** de dar ENTER (o botão está travado no blackout, então a ordem correta é: reset → fechar porta em < 0.5s → impossível neste caso; a lição real é "usar o reset antes do blackout, com margem"). Pilar 2 satisfeito: a morte ensina.

**Nota de design que sai deste cenário:** o `reset generator` deveria, ao sair do blackout, dar **1 segundo de imunidade** aos ticks das IAs físicas? [DECIDIR]. Recomendação: não. A punição de usar tarde é o ponto. Mas o manual deve dizer explicitamente: *"O gerador não fecha as portas. Feche-as você."*

### 4.6 A punição por desespero

```
[00:40] 12:00 AM | 91% | Noite 2. Jogador leu o manual até a página 5 na Noite 1.
                         "Se eu resetar agora fico com 50%... não, espera."
                         Leu de novo: "acima de 50% → cai para 50%."
                         Não usa. (Design funcionando: o texto é claro.)

Versão que dá errado:
[02:00]  2:00 AM | 68% | Jogador está com medo porque perdeu 20% em um minuto
                         segurando as duas portas. Digita "reset generator".
                         "[AVISO] Sobrecarga detectada! Bateria descarregada para 50%."
                         −18%. E o comando único da noite foi gasto.
[03:50]  3:00 AM | 9%  | Blackout inevitável. Sem reset. Morre às 4:20.
```
A punição existe para que `reset generator` seja uma decisão, não um botão de pânico. Uma vez por noite reforça isso.

### 4.7 Noite 7 — três ameaças ao mesmo tempo (a noite "injusta")

Config: Quadrado 16 (80%), Triângulo 14 (70%), Círculo 10 (50%), Hexágono 8 (40%). `arrivalCueVolume = 0.5`. Sonar 3D ativo.

```
[02:00]  2:00 AM | 61% | Firewall ▮▮▮▯▯. clock_glitch e camera_offline corrompidos.
                         (Relógio ilegível. Tablet indisponível. O jogador sabe que são ~2 AM
                          porque contou.) Círculo: alerta ativo há 12s (barra em 18s).
[02:01]          | 61% | Quadrado na porta esquerda (chegou há 3s, som a 50%). Porta fechada.
[02:03]          | 60% | Triângulo chega na porta direita. Som fraco. Jogador fecha. Dreno 0.52/s.
[02:05]          | 59% | Quadrado tick: d20=19 vs 16 → parado. (20% de chance de ficar. Ficou.)
[02:08]          | 57% | Terminal aberto para o minigame (alerta do Círculo). Não dá para
                         digitar "fix camera" — o minigame ocupa o terminal.
                         (REGRA: minigame tem prioridade sobre o prompt enquanto o alerta
                          está ativo. Resolver o vírus primeiro.)
[02:10]          | 56% | Acerta o minigame. Terminal volta ao prompt. Digita "fix camera".
[02:11]          | 56% | Triângulo tick: rebatido. BAM à direita. Abre a direita. Dreno 0.32.
[02:13]          | 55% | Quadrado tick: d20=3 → rebatido. BAM. Abre a esquerda. Dreno 0.12.
[02:14]          | 55% | "sync clock". Relógio: 2:00 AM. "restore_firewall". Puzzle: XNOR. Acerta.
                         ▮▮▮▮▯.
[02:15]          | 55% | Hexágono tick: d20=5 vs 8 → ROMPE. ▮▮▮▯▯. Sorteio: power_leak.
                         (Jogador: "de novo?!")
[02:18]          | 54% | Quadrado tick: d20=7 → MOVE para 2. Triângulo tick: MOVE para 2.
[02:23]          | 53% | Quadrado: MOVE para 3. Som a 50% — abafado pelo alarme do firewall.
                         Jogador está no terminal digitando "seal power_leak".
                         ...
```

**O que este cenário valida (e alerta):**
- Na noite 7, o jogador precisa de **prioridades**, não de reflexos: (1) portas quando ouvir passo, (2) vírus do Círculo antes do fusível, (3) sistemas corrompidos em ordem de perigo (`door_*_jammed` > `camera_offline` > `power_leak` > `clock_glitch`), (4) firewall quando sobrar tempo.
- **Risco de design:** com quatro alarmes possíveis simultâneos (virus_alert, intrusion_alarm, ambient_low_power, arrival cue), o áudio vira mingau. Regra obrigatória de mixagem: `enemy_arrival_*` tem **prioridade máxima** e abaixa (duck) todos os outros em 60% por 1.5s. Isso deve estar no `AudioController` desde a Fase 3.
- A regra "minigame tem prioridade sobre o prompt" precisa estar clara na UI: o prompt aparece cinza com `[bloqueado — resolva a anomalia]`.

### 4.8 Firewall em zero — a intrusão abortada em 4 segundos

```
[03:30]  3:00 AM | 40% | Firewall ▮▯▯▯▯. Jogador vem adiando.
[03:35]          | 39% | Hexágono tick: d20=1 → ROMPE. ▯▯▯▯▯.
                         → INTRUSÃO. intrusion_alarm (loop, sobe de intensidade).
                         → HUD inteiro tingido de ciano. Texto grande:
                           "INTRUSÃO EM CURSO — RESTAURE O FIREWALL — 20s"
                         Todos os 5 sistemas já estavam corrompidos → nenhum novo.
[03:36]          | 39% | Jogador abre o terminal. "restore_firewall". Puzzle:
                            0 0 → 0 / 0 1 → 1 / 1 0 → 1 / 1 1 → 0   [OR][AND][XOR]...
                         "XOR." Clica.
[03:39]          | 38% | "[OK]". ▮▯▯▯▯. Intrusão ABORTADA. Alarme para com um "clunk".
                         Cooldown de 10s antes de outro restore.
                         Contagem parou com 16s restantes: o jogador usou 4s dos 20.
                         (A contagem para no primeiro restore; não precisa encher o firewall.)
```

**Variante — erro no puzzle durante a intrusão:** cada erro custa 5% e 1.4s de nova tabela. Dois erros seguidos = 2.8s + tempo de leitura. Com 20s, dá para errar duas vezes e ainda acertar. Três erros = provavelmente morte. É o balanceamento desejado.

### 4.9 O espaço de decisões do jogador

Resumo do que o jogador decide, a cada instante. Serve para checar se uma feature nova adiciona uma decisão ou só adiciona trabalho.

| Decisão | Custo de errar | O que informa |
|---|---|---|
| Fechar porta agora ou esperar? | Energia vs. morte | Som de chegada, silhueta, último ping |
| Abrir a porta já ou segurar mais um tick? | Energia vs. morte | BAM (rebate) — é o sinal de "pode abrir" |
| Pingar agora ou economizar? | Energia (tablet) + não ver o escritório | Quanto tempo faz do último ping |
| Terminal ou porta primeiro? | Sistema corrompido piora vs. morte | Qual sistema caiu, quem está perto |
| Qual sistema consertar primeiro? | Jam de porta > câmera > vazamento > relógio | HUD de sistemas corrompidos |
| Restaurar firewall agora ou depois? | Intrusão vs. tempo gasto | Camadas restantes, nível do Hexágono |
| `reset generator` agora ou nunca? | −X% se acima de 50; morte se tarde demais | Energia atual, hora |
| Ler o manual ou chutar o comando? | 3s de leitura vs. `command not found` | Memória |

Se uma feature futura não entra nesta tabela (não cria uma decisão com custo), ela provavelmente é decoração.

---

## 5. ARQUITETURA TÉCNICA

### 5.1 Estrutura de pastas (Rojo)

```
five-nights-at-geometry/
├── CLAUDE.md
├── PLANEJAMENTO_ROBLOX.md          ← este arquivo
├── default.project.json             ← mapeamento Rojo
├── aftman.toml / rokit.toml         ← rojo, selene, stylua
├── selene.toml
├── stylua.toml
├── assets/                          ← sons, imagens (referência; os IDs vão no config)
├── tools/
│   └── balance_sim.py               ← simulação de balanceamento (Fase 7, ver 7.9)
└── src/
    ├── shared/                      → ReplicatedStorage/Shared
    │   ├── GameConfig.luau          ← TODOS os números (seção 7)
    │   ├── Strings.luau             ← todos os textos (Apêndice B)
    │   ├── Enums.luau               ← nomes de sistemas, câmeras, inimigos, cues
    │   ├── Remotes.luau             ← cria/retorna os RemoteEvents por nome
    │   ├── Signal.luau              ← classe Signal simples
    │   ├── LogicGates.luau          ← tabelas-verdade (usado por server e client)
    │   ├── Commands.luau            ← lista fechada de comandos do terminal, normalização, reparo↔sistema
    │   └── Types.luau               ← tipos Luau exportados
    ├── server/                      → ServerScriptService/Server
    │   ├── Main.server.luau         ← bootstrap: PlayerAdded → SaveService → menu
    │   ├── Scheduler.luau           ← relógio único (Heartbeat + acumuladores)
    │   ├── NightSession.luau        ← estado de uma noite + ciclo de vida
    │   ├── OfficeBuilder.server.luau ← sala whitebox construída por código (3.4)
    │   ├── RateLimiter.luau         ← janela de 1s por jogador (5.9)
    │   ├── NightService.luau        ← cria/destrói sessões; relógio; energia; blackout
    │   ├── SaveService.luau         ← DataStore
    │   ├── TerminalService.luau     ← valida e executa comandos
    │   ├── RadarService.luau        ← ping, câmeras mortas
    │   ├── FirewallService.luau     ← camadas, sistemas corrompidos, intrusão, puzzle
    │   ├── MinigameService.luau     ← minigame de sintaxe do Círculo
    │   ├── TutorialService.luau     ← Noite 0 roteirizada
    │   └── ai/
    │       ├── PatrolAI.luau        ← Quadrado e Triângulo (mesma classe)
    │       ├── CircleAI.luau
    │       └── HexagonAI.luau
    ├── client/                      → StarterPlayer/StarterPlayerScripts/Client
    │   ├── Main.client.luau         ← bootstrap: controllers, menu
    │   ├── OfficeCamera.luau        ← câmera travada + arco de giro
    │   ├── HudController.luau       ← relógio, energia, firewall, sistemas, alertas
    │   ├── DoorController.luau      ← botões, predição, animação da porta
    │   ├── OfficeController.luau    ← luzes (blackout, flicker) e relógio de parede
    │   ├── Overlay.luau             ← qual tela cheia está aberta (tablet/terminal/manual); uma por vez
    │   ├── ClockGlitch.luau         ← embaralha HUD e relógio de parede durante clock_glitch
    │   ├── TabletController.luau    ← radar (TabletGui em client/ui)
    │   ├── TerminalController.luau  ← CLI + paleta + minigame + puzzle (subviews)
    │   ├── NotebookController.luau  ← manual
    │   ├── AudioController.luau     ← todos os sons, ducking, posicional
    │   ├── JumpscareController.luau
    │   ├── EnemyModels.luau         ← modelos 3D dos quatro inimigos (jumpscares e palco do menu)
    │   ├── MenuController.luau
    │   ├── MenuScene.luau           ← palco 3D do menu: inimigos girando, câmera orbitando
    │   ├── TutorialController.luau  ← visual novel da Noite 0
    │   ├── CustomNightController.luau ← painel da Custom Night
    │   ├── InputController.luau     ← teclado / touch / gamepad → intenções
    │   └── ui/                      ← ScreenGuis construídas em código (UiKit, HudGui, MenuGui, DawnGui, ...)
    └── ui/                          → StarterGui (ScreenGuis construídos em código
                                        ou salvos como .rbxmx pelo Rojo)
```

**Regra de dependência:** `client` e `server` podem importar `shared`. `shared` não importa ninguém. `client` **nunca** importa `server` (e o Roblox nem permite). Toda comunicação cliente↔servidor passa por `Remotes.luau`.

**`default.project.json` (mínimo):**

```json
{
  "name": "FiveNightsAtGeometry",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "Shared": { "$path": "src/shared" }
    },
    "ServerScriptService": {
      "Server": { "$path": "src/server" }
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "Client": { "$path": "src/client" }
      }
    },
    "StarterGui": { "$path": "src/ui" },
    "Players": {
      "$properties": { "CharacterAutoLoads": false }
    }
  }
}
```

`CharacterAutoLoads = false`: o jogo nunca usa o personagem — a câmera é fixa na cadeira (2.3). `FilteringEnabled` já é sempre `true` no Roblox atual e não precisa (nem pode) ser definido pelo Rojo. `globIgnorePaths: ["**/.gitkeep"]` mantém as pastas vazias no Git sem o Rojo tentar sincronizá-las.

A sala 3D whitebox pode ser construída no Studio e salva; o Rojo não precisa gerenciá-la na v1. Alternativa: um `OfficeBuilder.server.luau` que cria as `Part`s por código — recomendado para a Fase 2 porque deixa a sala versionada e reproduzível.

**Streaming:** places novos vêm com `Workspace.StreamingEnabled = true`, e nesse modo as peças só replicam perto do personagem. Como o jogo não tem personagem, todos os modelos da sala são criados com `ModelStreamingMode = Persistent`; sem isso o cliente espera a sala para sempre (tela preta). Qualquer modelo novo que o cliente precise ler (silhuetas da Fase 3, modelos de jumpscare) segue a mesma regra.

### 5.2 `GameConfig` — schema

O arquivo é uma tabela Luau congelada (`table.freeze`). Valores na seção 7. Estrutura:

```lua
--!strict
local GameConfig = {
    Night = {
        durationSeconds = 360,
        hours = 6,                     -- 12 AM → 6 AM
        bootSeconds = 3,
        graceBeforeDawn = 2,
        clockTickSeconds = 1,   -- resolução do relógio; 1 hora = durationSeconds / hours
    },
    Power = {
        max = 100,
        tickSeconds = 1,
        drainBase = 0.12,
        drainPerDoor = 0.20,
        drainTablet = 0.08,
        drainLeak = 0.15,
        puzzlePenalty = 5,
        generatorResetTo = 50,
        generatorUsesPerNight = 1,
        lowPowerWarn = 20,
        lowPowerCritical = 10,
    },
    Blackout = {
        lightsFadeSeconds = 3,
        tabletBatterySeconds = 15,
        batteryTickSeconds = 1, -- resolução do contador da bateria
        aiTickMultiplier = 0.5,
    },
    Doors = {
        closeSeconds = 0.6,
        openSeconds = 0.8,
        maxTogglesPerSecond = 10,  -- rate limit (5.9)
    },
    Camera = {
        maxYawDegrees = 60,     -- arco de −60° a +60° (3.4)
        smoothing = 10,
        mouseDeadzone = 0.15,
    },
    Tablet = {
        maxTogglesPerSecond = 10,  -- rate limit de SetTabletOpen (5.9)
    },
    Radar = {
        pingProcessSeconds = 1.0,
        pingShowSeconds = 6,
        pingCooldownSeconds = 3,
        cameraBreakOrder = { "CAM1", "CAM4", "CAM2", "CAM3" },
        sonarFlashSeconds = 0.5,
    },
    Circle = {
        tickSeconds = 15,
        alertFuseSeconds = 30,
        minigameSeconds = 15,
        minigameWordCount = 9,
        fuseTickSeconds = 1,
        minigameTickSeconds = 1,
    },
    Hexagon = {
        tickSeconds = 25,
        maxLayers = 5,
        intrusionSeconds = 20,
        intrusionTickSeconds = 1,
        restoreCooldownSeconds = 10,
        systems = { "camera_offline", "door_left_jammed", "door_right_jammed", "clock_glitch", "power_leak" },
    },
    Patrol = {
        square   = { tickSeconds = 5, side = "left",  path = { "CAM1", "CAM2", "DOOR_L" } },
        triangle = { tickSeconds = 8, side = "right", path = { "CAM1", "CAM3", "DOOR_R" } },
    },
    Terminal = {
        maxCommandsPerSecond = 5,
        maxInputLength = 64,      -- TerminalCommand acima disso é ignorado (5.6)
        maxTogglesPerSecond = 10, -- rate limit de SetTerminalOpen (5.9)
    },
    Settings = {
        maxUpdatesPerSecond = 5,  -- rate limit de UpdateSettings (5.9)
    },
    Save = {
        storeName = "PlayerSave_v1",
        version = 1,
        retryDelays = { 1, 2, 4 },
        minSecondsBetweenWrites = 6,
        closeTimeoutSeconds = 25,
    },
    Tutorial = {
        lookDegrees = 30,
        typewriterSeconds = 0.035,
        figureFadeSeconds = 4,
        pollSeconds = 0.1,
    },
    CustomNight = {
        maxLevel = 20,
        presentationNight = 7,   -- volume do cue de chegada e sonar da Custom Night
    },
    Puzzle = {
        closeAfterCorrectSeconds = 1.2,
        newTableAfterWrongSeconds = 1.4,
    },
    -- Níveis por noite. Índice = noite (0 = tutorial, 1-7, "custom" é montado em runtime).
    Nights = {
        [0] = { square = 0,  triangle = 0,  circle = 0,  hexagon = 0, arrivalCueVolume = 1.0, sonar = false },
        [1] = { square = 3,  triangle = 2,  circle = 0,  hexagon = 0, arrivalCueVolume = 1.0, sonar = false },
        [2] = { square = 5,  triangle = 3,  circle = 2,  hexagon = 0, arrivalCueVolume = 1.0, sonar = false },
        [3] = { square = 6,  triangle = 5,  circle = 3,  hexagon = 2, arrivalCueVolume = 0.9, sonar = false },
        [4] = { square = 8,  triangle = 7,  circle = 4,  hexagon = 4, arrivalCueVolume = 0.8, sonar = false },
        [5] = { square = 10, triangle = 9,  circle = 6,  hexagon = 5, arrivalCueVolume = 0.7, sonar = false },
        [6] = { square = 13, triangle = 11, circle = 8,  hexagon = 6, arrivalCueVolume = 0.6, sonar = true  },
        [7] = { square = 16, triangle = 14, circle = 10, hexagon = 8, arrivalCueVolume = 0.5, sonar = true  },
    },
    Audio = {
        -- SoundId lógico → asset id. Preencher na Fase 6.
        ids = {},
        arrivalDuckAmount = 0.6,
        arrivalDuckSeconds = 1.5,
        rollOffMaxDistance = 40, -- sons posicionais (5.13)
    },
    Debug = {
        timeScale = 1,          -- 5 = noite de 72s para testar
        deterministicSeed = nil, -- número = RNG reproduzível
        logAI = false,
        logSession = false,     -- imprime boot, fases e fim de noite no Output (ligar só para testar)
        deadCamerasAtStart = {}, -- ex.: { "CAM1" } para testar "em nó cego" (Fase 4). Só em Studio.
        levelOverrides = {},     -- ex.: { hexagon = 20 } para testar hackers em qualquer noite. Só em Studio.
        forceSonar = false,      -- liga o sonar 3D em qualquer noite. Só em Studio.
        unlockAllNights = false, -- libera todas as noites e a Custom Night. Só em Studio.
        logMetrics = false,      -- imprime as métricas de 7.8 no fim de cada noite
    },
}
return table.freeze(GameConfig)  -- na prática, congelamento recursivo (deepFreeze)
```

### 5.3 `Scheduler` — o relógio único

```lua
--!strict
-- Um Scheduler por NightSession. Roda em Heartbeat. Cada "tarefa" tem um intervalo
-- e um acumulador. timeScale permite acelerar para testes.
local RunService = game:GetService("RunService")

export type Task = { name: string, interval: number, acc: number, fn: () -> () }

local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new(timeScale: number)
    local self = setmetatable({}, Scheduler)
    self.tasks = {} :: { [string]: Task }
    self.timeScale = timeScale
    self.paused = false
    self.elapsed = 0
    self.conn = RunService.Heartbeat:Connect(function(dt)
        if self.paused then return end
        local scaled = dt * self.timeScale
        self.elapsed += scaled
        for _, t in self.tasks do
            t.acc += scaled
            -- while, não if: se o frame demorou, não perde ticks
            while t.acc >= t.interval do
                t.acc -= t.interval
                t.fn()
            end
        end
    end)
    return self
end

function Scheduler:every(name: string, interval: number, fn: () -> ())
    self.tasks[name] = { name = name, interval = interval, acc = 0, fn = fn }
end

function Scheduler:setInterval(name: string, interval: number)
    local t = self.tasks[name]; if t then t.interval = interval end
end

function Scheduler:remove(name: string) self.tasks[name] = nil end
function Scheduler:pause() self.paused = true end
function Scheduler:resume() self.paused = false end

function Scheduler:destroy()
    self.conn:Disconnect()
    self.tasks = {}
end

return Scheduler
```

Uso: `scheduler:every("power", cfg.Power.tickSeconds, function() session:drainPower() end)`. O blackout faz `scheduler:setInterval("ai_square", 5 * 0.5)`. O game over faz `scheduler:destroy()`. Nada sobrevive à sessão.

**RNG:** a sessão tem um `Random.new(seed)`; se `Debug.deterministicSeed` estiver definido, a seed é fixa e uma partida é reproduzível. Toda IA usa `session.rng:NextInteger(1, 20)`, nunca `math.random`.

### 5.4 `NightSession` — o estado

```lua
--!strict
export type DoorState = { closed: boolean, jammed: boolean }
export type NightState = {
    night: number,
    players: { Player },
    phase: "boot" | "running" | "blackout" | "won" | "lost",
    hour: number,                     -- 0..6
    secondsIntoHour: number,
    power: number,                    -- 0..100 (float)
    doors: { left: DoorState, right: DoorState },
    tabletOpen: boolean,
    terminalOpen: boolean,
    firewallLayers: number,
    corrupted: { [string]: boolean }, -- "door_left_jammed" = true
    deadCameras: { [string]: boolean },
    intrusionRemaining: number?,
    generatorUsesLeft: number,
    tabletBatteryRemaining: number?,  -- só em blackout
    virusAlert: { remaining: number }?,
    minigame: { words: { string }, answerIndex: number, remaining: number }?,
    puzzle: { gate: string, options: { string } }?,
    restoreCooldown: number,
    ai: {
        square: PatrolAI, triangle: PatrolAI, circle: CircleAI, hexagon: HexagonAI,
    },
}
```

`NightSession.new(players, night)` monta o estado a partir do `GameConfig`, cria o `Scheduler`, instancia as IAs com seus níveis, e expõe métodos: `start()`, `toggleDoor(player, side)`, `setTablet(player, open)`, `requestPing(player)`, `runCommand(player, text)`, `minigamePick(player, index)`, `puzzlePick(player, gate)`, `win()`, `lose(enemy)`, `destroy()`. Tudo que muda estado dispara o Remote correspondente (5.6) para os jogadores da sessão.

### 5.5 Serviços do servidor — responsabilidades

| Serviço | Faz | Não faz |
|---|---|---|
| `NightService` | Cria/destrói `NightSession` por jogador; relógio e energia; blackout; vitória/derrota; encaminha Remotes cliente→servidor para a sessão certa | Lógica de IA, terminal |
| `PatrolAI` | Máquina de estados de Quadrado/Triângulo; dispara cues | Mexer em energia, portas |
| `CircleAI` | Tick, alerta, fusível | O minigame em si |
| `MinigameService` | Gera palavras, valida escolha, aplica consequência (câmera) | |
| `HexagonAI` | Tick, rompe camadas, sorteia sistema | Puzzle |
| `FirewallService` | Camadas, corrupção/reparo de sistemas, intrusão, puzzle | |
| `RadarService` | Ping (lê posições das IAs), câmeras mortas | |
| `TerminalService` | Parse + validação + dispatch de comandos; rate limit; eco canônico | Decidir efeitos (delega para Firewall/NightService) |
| `SaveService` | Load/save DataStore com retry; migração de schema | |
| `TutorialService` | Sequência roteirizada da Noite 0 (usa uma sessão com todas as IAs em 0 e injeta eventos) | |

### 5.6 Remotes — contrato completo

Todos são `RemoteEvent`, criados em `ReplicatedStorage/Remotes` por `Remotes.luau` no servidor. Payloads são tabelas. **O servidor valida tipo e faixa de todo campo recebido.**

**Cliente → Servidor (intenções):**

| Remote | Payload | Validação no servidor |
|---|---|---|
| `ClientReady` | `{}` | Scripts do cliente carregaram; o servidor reenvia `SaveLoaded` (o do `PlayerAdded` pode chegar antes de o cliente existir) |
| `StartNight` | `{ night: number, newGame: boolean?, custom: {square, triangle, circle, hexagon}? }` | `night <= save.maxNightUnlocked` e `0..7`; `newGame` só com `night = 0`; `custom` exige ter vencido a 7 e quatro inteiros `0..20` (Custom Night usa `night = -1`) |
| `ReturnToMenu` | `{}` | Destrói a sessão se houver |
| `ToggleDoor` | `{ side: "left"\|"right" }` | Sessão em `running`; porta não `jammed`; não em blackout |
| `SetTabletOpen` | `{ open: boolean }` | Não `camera_offline`; se blackout, bateria > 0 |
| `RequestPing` | `{}` | Tablet aberto; ping não em andamento nem em cooldown |
| `TerminalCommand` | `{ text: string }` | `#text <= 64`; rate limit; sessão viva; terminal aberto |
| `SetTerminalOpen` | `{ open: boolean }` | (para o servidor saber e o Círculo não atacar com o terminal aberto) |
| `MinigamePick` | `{ index: number }` | Minigame ativo; `1..9` |
| `PuzzlePick` | `{ gate: string }` | Puzzle ativo; `gate` ∈ lista |
| `PuzzleCancel` | `{}` | |
| `TutorialAdvance` | `{ step: number }` | Só na Noite 0; `step == expected` |
| `UpdateSettings` | `{ masterVolume: number }` | Número, não NaN, preso a `0..1`; rate limit. Vai para `save.settings` (Fase 6) |

**Servidor → Cliente (estado/eventos):**

| Remote | Payload | Quando |
|---|---|---|
| `SaveLoaded` | `{ save: SaveData, available: boolean }` | Depois do load e a cada fim de noite; `available = false` = modo sem save |
| `NightStarted` | `{ night, config: NightLevels }` | Início do boot |
| `NightPhase` | `{ phase }` | Toda mudança de fase |
| `HourChanged` | `{ hour }` | A cada hora |
| `PowerChanged` | `{ power, drainRate, sources: {string} }` | A cada tick de energia (1/s) |
| `DoorStateChanged` | `{ side, closed, jammed, accepted: boolean }` | Após ToggleDoor (accepted=false = reverter predição) ou por Hexágono/blackout |
| `TabletState` | `{ open, available: boolean, batteryRemaining: number? }` | |
| `PingStarted` | `{}` | |
| `PingResult` | `{ nodes: { [string]: "clear"\|"anomaly"\|"dead" }, anomalies: number, blind: number, serverStatus: string }` | 1s após PingStarted |
| `PingCooldownOver` | `{}` | |
| `EnemyAudioCue` | `{ side: "left"\|"right", cue: "arrival"\|"repelled"\|"footstep", volume: number }` | Ver 3.5b |
| `EnemyVisual` | `{ side, visible: boolean }` | Silhueta na porta |
| `VirusAlert` | `{ active: boolean, remaining: number? }` | Círculo |
| `MinigameStart` | `{ words: {string}, seconds }` | Terminal aberto com alerta |
| `MinigameResult` | `{ success, cameraKilled: string?, timeout: boolean }` | O terminal fecha em seguida, acertando ou errando |
| `CameraDead` | `{ camera }` | Também por fusível |
| `FirewallChanged` | `{ layers, max, cause: "init"\|"break"\|"restore" }` | `cause` escolhe o som no cliente |
| `SystemCorrupted` | `{ system, corrupted: {string} }` | `corrupted` = lista completa (o cliente redesenha tudo) |
| `SystemRepaired` | `{ system, corrupted: {string} }` | idem |
| `IntrusionState` | `{ active, remaining: number? }` | |
| `PuzzleStart` | `{ truthTable: {{a,b,out}}, options: {string} }` | |
| `PuzzleResult` | `{ correct, gate, layers, penalty }` | `penalty` = 0 na Noite 0 |
| `PuzzleClosed` | `{}` | |
| `TerminalEcho` | `{ text, kind: "ok"\|"info"\|"err"\|"echo"\|"clear" }` | Toda resposta do terminal; `clear` limpa a tela |
| `TerminalPalette` | `{ commands: {string} }` | Sempre que o conjunto de comandos disponíveis muda |
| `BlackoutStarted` | `{ tabletBatterySeconds }` | |
| `BlackoutEnded` | `{}` | Após reset generator |
| `TabletBatteryDead` | `{}` | |
| `GeneratorUsed` | `{ punished: boolean, power, usesLeft }` | |
| `Jumpscare` | `{ enemy: "square"\|"triangle"\|"hexagon" }` | |
| `NightWon` | `{ night, nextNight }` | |
| `TutorialStep` | `{ step, lines: {string}, waitFor: string }` | Noite 0 |

**Princípio:** o cliente nunca calcula estado a partir de eventos anteriores. Cada Remote traz o estado completo daquele subsistema. Se o cliente perder um evento, o próximo corrige.

### 5.7 Máquina de estados das IAs

**`PatrolAI`** (Quadrado e Triângulo):

```lua
--!strict
local PatrolAI = {}
PatrolAI.__index = PatrolAI

type Config = { tickSeconds: number, side: "left" | "right", path: { string } }

function PatrolAI.new(session, name: string, cfg: Config, level: number)
    local self = setmetatable({}, PatrolAI)
    self.session, self.name, self.cfg, self.level = session, name, cfg, level
    self.position = 1   -- índice em cfg.path; #path + 1 = escritório
    return self
end

function PatrolAI:node(): string?  -- nó atual para o radar
    return self.cfg.path[self.position]
end

function PatrolAI:tick()
    if self.level <= 0 then return end
    local roll = self.session.rng:NextInteger(1, 20)
    if roll > self.level then return end

    local atDoor = self.position == #self.cfg.path
    if not atDoor then
        self.position += 1
        if self.position == #self.cfg.path then
            self.session:fireCue(self.cfg.side, "arrival")
            self.session:setEnemyVisual(self.cfg.side, true)
        end
        return
    end

    local door = self.session.state.doors[self.cfg.side]
    if door.closed then
        self.position = 1
        self.session:fireCue(self.cfg.side, "repelled")
        self.session:setEnemyVisual(self.cfg.side, false)
    else
        self.session:lose(self.name)
    end
end

return PatrolAI
```

Registrado na sessão com `scheduler:every("ai_square", cfg.tickSeconds, function() square:tick() end)`.

**Implementação:** `PatrolAI.new(host, name, cfg, level)` recebe a sessão pela interface estrutural `Types.AIHost` (`rng`, `state`, `fireCue`, `setEnemyVisual`, `lose`, `inDawnGrace`) em vez do tipo `NightSession` — evita require circular e permite testar a IA com um host falso. O tick checa `inDawnGrace()` antes de sortear (3.1). A sessão registra as tarefas na ordem Quadrado → Triângulo; com `Debug.deterministicSeed` fixo, a sequência de sorteios é reproduzível.

**`CircleAI`:** `tick()` → se `level > 0`, sorteia; se passa e não há `virusAlert` e `not terminalOpen`, cria `virusAlert = { remaining = fuse }` e dispara `VirusAlert`. Uma tarefa `circle_fuse` (1s) decrementa `remaining`; em 0 → `RadarService:killNextCamera()` e limpa o alerta. Quando o cliente abre o terminal com alerta ativo, `MinigameService:start(session)`.

**Implementação (5b):** `CircleAI.new(level, rng, canAct, attack)` não conhece a sessão; `MinigameService.attach` cria o Círculo e registra o tick por `session:addAITask`, como o Hexágono. Ao abrir o terminal, o `NightService` chama `MinigameService.onTerminalOpened`: o alerta vira minigame (o alarme e o fusível param) e o `virusAlert` sai do estado. O relógio do minigame continua com o terminal fechado; reabrir reenvia `MinigameStart` com o tempo que resta.

**`HexagonAI`:** `tick()` → sorteia; se passa → `FirewallService:breakLayer(session)`, que decrementa, sorteia um sistema íntegro, aplica (`corrupted[sys] = true` + efeito colateral: `doors.left.jammed = true`, etc.), e se `layers == 0` inicia `intrusionRemaining = 20` com tarefa `intrusion` (1s). `restoreLayer()` cancela a intrusão.

**Estados de posição para o radar:** `RadarService:ping(session)` monta o mapa: para cada nó, `"dead"` se em `deadCameras`, senão `"anomaly"` se algum `PatrolAI:node() == nó`, senão `"clear"`. `anomalies` = nós com anomalia visíveis; `blind` = nós com anomalia que estão mortos.

### 5.8 Fluxo de dados — três exemplos

**Fechar a porta (com predição):**
```
Cliente: clique no botão esquerdo
  → DoorController: se não jammed localmente, inicia tween de fechar + door_close
  → Remotes.ToggleDoor:FireServer({ side = "left" })
Servidor: NightService recebe
  → sessão.toggleDoor(player, "left")
  → valida: running? não jammed? não blackout?
  → OK: doors.left.closed = true; Remotes.DoorStateChanged:FireClient(player, {side="left", closed=true, jammed=false, accepted=true})
  → NEGADO: FireClient(..., {side="left", closed=false, jammed=true, accepted=false})
Cliente: DoorStateChanged
  → accepted=true: nada (já animou); sincroniza estado
  → accepted=false: reverte tween, toca door_jammed, mostra "MOTOR TRAVADO"
```

**Ping:**
```
Cliente: RequestPing → Servidor valida (tablet aberto, sem ping ativo)
Servidor: PingStarted → agenda tarefa única "ping_resolve" em 1.0s
  → resolve: RadarService:ping → PingResult{nodes, anomalies, blind}
  → agenda "ping_cooldown" em 6s+3s → PingCooldownOver
Cliente: PingStarted → som + barra; PingResult → pinta nós, status; PingCooldownOver → botão volta
```

**Comando do terminal:**
```
Cliente: TextBox.FocusLost(enterPressed) ou botão ENVIAR
  → TerminalController: text = trim(lower(text)); limpa TextBox
  → Remotes.TerminalCommand:FireServer({ text })
Servidor: TerminalService:handle(player, text)
  → rate limit (5/s) — excedeu? ignora
  → canonical = COMMANDS[text]; nil → TerminalEcho{ "command not found", "err" } (sem repetir o texto)
  → TerminalEcho{ "root@office:~$ " .. canonical, "echo" }
  → dispatch:
      "fix camera"        → FirewallService:repair(session, "camera_offline")
      "restore_firewall"  → FirewallService:openPuzzle(session)
      "reset generator"   → NightService:generatorReset(session)
      "status"            → monta texto a partir de session.state
  → cada handler devolve { text, kind } → TerminalEcho
  → TerminalPalette{ commands = comandos disponíveis agora }
Cliente: TerminalEcho → appenda linha, scroll; TerminalPalette → refaz botões
```

### 5.9 Segurança / anti-exploit (checklist)

- [ ] Nenhum Remote cliente→servidor muda estado sem validação de fase, de pré-condição e de faixa.
- [ ] Rate limit em `TerminalCommand`, `ToggleDoor` (10/s), `RequestPing` (o cooldown já limita).
- [ ] `StartNight` confere `night <= maxNightUnlocked` do save no servidor, nunca do cliente.
- [ ] Posições das IAs **nunca** são replicadas ao cliente fora do `PingResult` e dos cues. Não existe `EnemyPosition` remote. (Senão um exploiter faz um radar em tempo real.)
- [ ] Minigame: a resposta certa (`answerIndex`) fica só no servidor; o cliente recebe só as palavras.
- [ ] Puzzle: a porta correta fica só no servidor; o cliente recebe só a tabela e as opções.
- [ ] Eco do terminal é sempre o comando canônico ou mensagem fixa — nunca texto livre do jogador.
- [ ] `Debug.timeScale` e `deterministicSeed` só têm efeito em Studio (`RunService:IsStudio()`).

### 5.10 DataStore

- Store: `DataStoreService:GetDataStore("PlayerSave_v1")`. Chave: `tostring(player.UserId)`.
- **Load** no `PlayerAdded`: `pcall(GetAsync)` com 3 tentativas (1s, 2s, 4s). Falhou tudo → jogador entra em "modo sem save" (aviso no menu: `Save indisponível — progresso não será salvo`), nunca trava o jogo.
- **Save**: na vitória (noite + stats), na morte (stats), no `PlayerRemoving`, e em `BindToClose` (loop pelos jogadores). `pcall(SetAsync)` com retry. Usar `UpdateAsync` se um dia houver risco de escrita concorrente (co-op não tem, é um save por jogador).
- **Migração:** `if save.version == nil then save = migrateV0toV1(save) end`. Sempre preencher campos ausentes com o default.
- **Fila:** uma fila simples por jogador para não estourar o limite de 6s entre writes na mesma chave. Se um save está em andamento, o próximo espera.
- Opção futura: `ProfileStore` (session locking, muito mais robusto). Não é necessário na v1.

### 5.11 Mobile e input

`InputController` converte qualquer input em intenções nomeadas. Ninguém mais lê `UserInputService` diretamente.

| Intenção | PC | Mobile | Gamepad |
|---|---|---|---|
| Olhar | mouse (delta) | arrastar na tela | stick direito |
| Porta esq/dir | clique no botão 3D ou `A`/`D` | botão HUD (canto inferior esq/dir, ≥ 56px) | LB / RB |
| Tablet | clique no tablet ou `Space` | botão HUD central inferior | Y |
| Terminal | clique no monitor ou `T` | botão HUD | X |
| Manual | clique no caderno ou `M` | botão HUD | B |
| Fechar overlay | mesma tecla que abriu (`Space`, `T`, `M`) | botão FECHAR | B |
| Terminal: enviar | `Enter` | botão ENVIAR | A |
| Terminal: paleta | clique / `Tab` cicla | toque | D-pad |
| Minigame / puzzle | clique | toque (alvos ≥ 48px) | D-pad + A |

**Esc:** o Roblox reserva a tecla `Esc` para o próprio menu e ela não chega aos scripts do jogo. Por isso overlays fecham com a mesma tecla que os abriu ou com o botão FECHAR.

**Regras de UI mobile:** todo alvo de toque ≥ 48×48 px em escala (`UIScale` por resolução). O HUD usa `Scale`, nunca `Offset`, para posição. Testar em `Device Emulator` com iPhone SE (menor tela comum) antes de fechar cada fase.

### 5.12 Telas e elementos de UI

| ScreenGui | Elementos | Controller |
|---|---|---|
| `MenuGui` | palco 3D ao fundo (ver abaixo), título com glitch no alto à esquerda (RNG 1-15, >10 → 400ms de glitch a cada 5s), fileira de botões embaixo — Configurações (volume), Custom Night (bloqueado), Tutorial, New Game, Continue —, estática por cima | `MenuController`, `MenuScene` |
| `HudGui` | relógio (`12:00 AM` / glitch), noite (`NOITE 3`), energia (% + barra + barrinhas de consumo), firewall (`▮▮▮▯▯`), lista de sistemas corrompidos (`[!] door_left_jammed`), banner de vírus + barra de 30s, banner de intrusão + contagem, aviso de gerador (`GERADOR: 1 uso`), botões mobile (portas, tablet, terminal, manual) | `HudController`, `DoorController` |
| `TabletGui` | fundo com estática animada, mapa de nós (CAM1-4, DOOR L/R, ESCRITÓRIO), botão PING, visor de status, rodapé com firewall e energia, bateria interna em blackout | `TabletController` |
| `TerminalGui` | saída rolável, linha de input com prompt, paleta de comandos, botão FECHAR; subviews: minigame (9 botões + timer), puzzle (tabela + 6 botões + feedback) | `TerminalController` |
| `NotebookGui` | página com papel, título, entradas, navegação, `n / N` | `NotebookController` |
| `TutorialGui` | tela de boot, sprite da figura, caixa de diálogo com máquina de escrever, indicador ▼ | `TutorialController` |
| `JumpscareGui` | overlay de estática, tela de game over (`FALHA CRÍTICA — NOITE N`, `anomalia: X`, botões) | `JumpscareController` |
| `DawnGui` | `6:00 AM`, `NOITE N CONCLUÍDA` | `HudController` |

Estética: monoespaçada (`Code` ou `RobotoMono`), fundo preto, verde/ciano/âmbar/vermelho como cores semânticas (ok/hacker/aviso/perigo), bordas de 1px, sem gradientes, estática como textura. É o visual do protótipo web e funciona.

**Menu com palco 3D** [NOVO — pedido do time, 19/09/2026, com referência de menu de jogo de carro em que o carro gira e a câmera dá voltas]: o fundo do menu é o Palco da CAM 1. Os quatro inimigos flutuam e giram no lugar, cada um num pedestal com aro de neon na sua cor e um holofote em cima, e a câmera dá uma volta no palco a cada 45 s. O glitch do título também faz os holofotes piscarem e os inimigos tremerem. A ação principal fica em destaque (fundo verde, texto preto): `Continue` quando há noite salva, senão `New Game`.
- `MenuScene` (cliente) monta a cena localmente, longe da sala e dentro de uma caixa escura que esconde céu e Baseplate. Ela só fica no `Workspace` enquanto o menu está aberto. Nesse tempo a câmera é do `MenuScene` e o `OfficeCamera` fica suspenso (`setActive(false)`); ao voltar, a cadeira olha para a frente.
- `EnemyModels` (cliente) é a fonte única dos modelos 3D dos inimigos, usada pelo palco e pelos jumpscares. Cada inimigo é a própria forma extrudada, com a frente em −Z: Quadrado = cubo com olhos, Triângulo = prisma de duas cunhas, Círculo = disco amarelo, Hexágono = prisma hexagonal ciano (três blocos girados de 60°). Círculo e Hexágono ganham aqui a primeira forma 3D; até então só existiam no HUD e no jumpscare de grade.

### 5.13 Áudio — implementação

- `AudioController` no cliente possui todos os `Sound`s, criados a partir de `GameConfig.Audio.ids`.
- Sons **posicionais** (portas, chegadas, rebates) são `Sound` parentados a uma `Part` invisível na posição da porta correspondente, com `RollOffMode = Linear`, `RollOffMaxDistance = 40`. Como a câmera está na cadeira, "esquerda" e "direita" saem naturalmente do posicionamento.
- Sons **de UI** (terminal, tablet, alarmes) são 2D (`Sound` em `SoundService`).
- **Grupos:** `SoundGroup`s `Ambient`, `Enemy`, `UI`, `Alarm`. `Enemy` tem prioridade: ao tocar `enemy_arrival_*`, o controller reduz `Ambient`, `UI` e `Alarm` em `arrivalDuckAmount` por `arrivalDuckSeconds` com tween.
- `arrivalCueVolume` (por noite) multiplica o volume de `enemy_arrival_*`.
- Loops (`ambient_hum`, `virus_alert`, `intrusion_alarm`) têm `Looped = true` e são ligados/desligados por estado, nunca disparados repetidamente.

---

## 6. PLANO POR FASES

Cada fase termina em algo **jogável e testável** no Studio. Não avance sem o critério de aceite passar. As caixas `[ ]` são para o time marcar (e para o Claude Code atualizar ao terminar).

### Fase 0 — Setup (½ dia)

- [x] Criar o repositório Git — `LauanMO/FNAG-R`, branch `dev`.
- [x] `default.project.json` (5.1) e `rokit.toml` (rojo 7.7.0, selene 0.31.0, stylua 2.5.2) criados.
- [ ] Instalar o Rokit, rodar `rokit install` e `rojo plugin install` (ver README).
- [x] Criar `CLAUDE.md` (0.1) e copiar este documento.
- [ ] Criar o place no Roblox (privado), `MaxPlayers = 1`, `FilteringEnabled = true` (já é padrão).
- [x] `selene` + `stylua` configurados (`selene.toml`, `stylua.toml`, `.luaurc` strict).
- [ ] Rodar `rojo serve`, conectar o Studio, ver a pasta `Shared` aparecer em `ReplicatedStorage`.

**Aceite:** um `print("hello")` em `src/server/Main.server.luau` aparece no Output do Studio ao dar Play.

> Status 18/09/2026: arquivos prontos (`Main.server.luau` imprime `GEOMETRY OS boot`). Falta instalar o toolchain, criar o place e validar no Studio.

### Fase 1 — Esqueleto e loop da noite (sem inimigos)

**Arquivos:** `GameConfig`, `Enums`, `Strings` (parcial), `Remotes`, `Signal`, `Types`, `Scheduler`, `NightSession` (parcial), `NightService`, `Main.server`, `Main.client`, `HudController`, `MenuController`, `HudGui`, `MenuGui`.

- [x] `GameConfig` com a seção 7 inteira (mesmo os campos ainda não usados).
- [x] `Scheduler` (5.3) com `timeScale` e testes manuais (`Debug.timeScale = 5`).
- [x] `NightSession.new(players, night)` + `start()` + `win()` + `lose()` + `destroy()`.
- [x] Relógio: `HourChanged` a cada 60s; vitória em 6.
- [x] Energia: tick 1s com `drainBase`; `PowerChanged` com `drainRate` e `sources`.
- [x] Blackout ao chegar em 0 (só o estado e o evento; luzes vêm na Fase 2).
- [x] Menu: New Game / Continue (Continue lê um save em memória por enquanto — DataStore é Fase 7).
- [x] HUD: relógio, noite, energia (% + barra + barrinhas de consumo).
- [x] Tela de vitória (`6:00 AM` → `NOITE N CONCLUÍDA` → menu).

**Aceite:** dar Play, New Game, ver o relógio andar de 12 AM a 6 AM em 6 minutos (ou 72s com `timeScale = 5`), a energia cair de 100 para ~57, e a tela de vitória aparecer. Nada tenta te matar.

> Status 18/09/2026: implementado (shared, servidor e cliente). Aceite no Studio pendente. Notas: New Game abre a Noite 1 até a Fase 7 trazer a Noite 0; `Scheduler` ganhou `after(name, delay, fn)` para tarefas únicas (boot, ping); o cliente faz o handshake `ClientReady` para receber o `SaveLoaded`.

### Fase 2 — Escritório 3D e portas

**Arquivos:** `OfficeBuilder.server` (ou sala no Studio), `OfficeCamera`, `DoorController`, `InputController`, `AudioController` (mínimo: portas), `Strings`.

- [x] Sala whitebox: chão, teto, 4 paredes, duas aberturas de porta, mesa, monitor, caderno, tablet, dois botões de parede, duas luzes, corredores escuros. (`OfficeBuilder.server.luau`; iluminação escura versionada no `default.project.json`)
- [x] Câmera travada com arco de −60° a +60°, suavizada, mouse (posição do cursor, com zona morta), touch (arrasto) e stick direito.
- [x] Portas: `Part` que desce/sobe com `TweenService`; `ToggleDoor` com predição e reversão.
- [x] Custo de porta na energia (`drainPerDoor`).
- [x] Botões de parede (raycast em partes com atributo `Interact`, ver 3.3) + botões HUD mobile + teclas `A`/`D` + LB/RB.
- [x] Sons: `door_close`, `door_open`, `door_jammed`, `blackout` (posicionais) — `AudioController` com grupos e âncoras; assets placeholder da biblioteca licenciada do Roblox, a revisar na Fase 6.
- [x] Blackout visual: luzes com fade, portas sobem sozinhas, botões travam.
- [x] HUD: aviso de energia baixa (âmbar pulsando / vermelho), flicker das luzes < 10%.
- [ ] `Device Emulator` iPhone SE: tudo alcançável com o polegar.

**Aceite:** dá para morrer de blackout segurando as duas portas (às ~3:12 AM). Dá para ganhar não fazendo nada. A porta reage no mesmo frame do clique. No celular, dá para jogar com uma mão.

> Status 18/09/2026: implementado; aceite no Studio e teste no Device Emulator (iPhone SE) pendentes. Sem inimigos ainda, o blackout às ~3:12 AM não mata: as portas sobem, as luzes apagam e a noite continua até as 6 (3.1).

### Fase 3 — Inimigos físicos

**Arquivos:** `PatrolAI`, `EnemyVisual` (silhuetas), `JumpscareController`, `JumpscareGui`, `AudioController` (cues de inimigo + ducking).

- [x] `PatrolAI` (5.7) instanciado duas vezes a partir de `GameConfig.Patrol`.
- [x] Níveis lidos de `GameConfig.Nights[night]`.
- [x] `EnemyAudioCue` (arrival/repelled) posicional com `arrivalCueVolume`.
- [x] Silhueta (um `Part` azul/vermelho semitransparente na abertura da porta) via `EnemyVisual`.
- [x] Ducking: `enemy_arrival_*` abaixa o resto por 1.5s.
- [x] `lose(enemy)` → `Jumpscare{enemy}` → coreografia de 3s → tela de game over com `TENTAR DE NOVO` / `MENU`.
- [x] Blackout: `aiTickMultiplier` aplicado aos ticks.
- [x] `graceBeforeDawn`.
- [x] `Debug.logAI` imprime cada sorteio (`[square] d20=7 vs 3 → stay`).
- [x] `Debug.deterministicSeed` funciona.

**Aceite:** Noite 1 (3/2/0/0) é vencível prestando atenção nos sons e fechando portas na hora; ignorar o som mata. Uma partida com seed fixa reproduz a mesma sequência de sorteios duas vezes. Um jumpscare de cada lado.

> Status 18/09/2026: implementado; aceite no Studio pendente. Notas: as IAs enxergam a sessão pela interface `Types.AIHost` (sem require circular); o modelo do jumpscare é criado só no cliente; cues de chegada, rebate e jumpscare usam placeholders da biblioteca licenciada do Roblox (revisar na Fase 6). A silhueta e a luz fraca ficam na soleira, do lado do corredor.

### Fase 4 — Tablet e radar

**Arquivos:** `RadarService`, `TabletController`, `TabletGui`.

- [x] Tablet abre/fecha (clique no tablet da mesa, `Space`, botão TABLET no HUD de toque, Y no gamepad). Custo `drainTablet`.
- [x] Botões de porta somem com o tablet aberto (e A/D ficam inertes); cues de som continuam.
- [x] Mapa com CAM1-4, DOOR L/R, ESCRITÓRIO. Estática animada de fundo (linha de varredura).
- [x] Ping: `RequestPing` → 1s → `PingResult` → 6s → cooldown 3s. Sons (placeholders licenciados).
- [x] `PingResult` pinta nós (`clear`/`anomaly`/`dead`), status com contagem e "em nó cego". `Debug.logAI` também imprime cada ping.
- [x] Rodapé com firewall e energia.
- [x] `camera_offline` bloqueia o tablet (só o estado; o Hexágono vem na Fase 5).
- [x] Blackout: bateria de 15s, contador visível no tablet e no HUD, `TabletBatteryDead` desliga.

**Aceite:** com `Debug.logAI`, o ping mostra exatamente onde as IAs estão no instante da resolução. Um nó `dead` (forçado via debug) ainda conta em "em nó cego". Deixar o tablet aberto a noite inteira termina com ~28%.

> Status 18/09/2026: implementado; aceite no Studio pendente. O "debug para matar uma câmera" é `Debug.deadCamerasAtStart`; `RadarService.killNextCamera` já existe para o Círculo (Fase 5b).

### Fase 5 — Inimigos hackers, terminal, manual, puzzle

Maior fase. Dividir em 5a (Terminal + Manual + Hexágono + Puzzle) e 5b (Círculo + Minigame).

**Arquivos:** `TerminalService`, `TerminalController`, `TerminalGui`, `NotebookController`, `NotebookGui`, `FirewallService`, `HexagonAI`, `LogicGates`, `CircleAI`, `MinigameService`.

**5a:**
- [x] Terminal: abrir/fechar (T, clique no monitor, botão TERMINAL, X no gamepad), boot, eco, `help`, `status`, `clear`, `command not found`.
- [x] `TerminalService` com lista canônica (`Commands.luau`), rate limit, eco canônico.
- [x] Paleta de comandos (`TerminalPalette`), `Tab` autocompleta e cicla.
- [x] Manual com 5 páginas (Apêndice B), números lidos do `GameConfig`. Abre com M, clique no caderno, botão MANUAL, B no gamepad; setas viram a página.
- [x] `FirewallService`: camadas, `SystemCorrupted`/`SystemRepaired`, efeitos colaterais (jam congela a porta; leak soma dreno; glitch no relógio do HUD e da parede; camera_offline bloqueia tablet).
- [x] Comandos de reparo funcionando + `[WARN] ... is not currently corrupted`.
- [x] `HexagonAI` com d20 (`Debug.logAI` imprime os sorteios).
- [x] Puzzle: `LogicGates` compartilhado, `PuzzleStart/Pick/Result/Cancel`, penalidade de 5%, cooldown de 10s.
- [x] Intrusão: contagem de 20s, alarme, tingimento ciano, abortar ao restaurar, jumpscare do Hexágono.
- [x] `reset generator`: 1× por noite, punição, saída do blackout (portas ficam abertas).

**5b:**
- [x] `CircleAI` com d20, alerta, fusível de 30s, CAM4 pulsando (no tablet, mesmo sem ping).
- [x] Minigame no terminal (prioridade sobre o prompt, que fica cinza e bloqueado), 9 palavras, timer de 15s, resultado.
- [x] `RadarService:killNextCamera()` com a ordem do config.
- [x] Listas de palavras no `Strings` (Apêndice B), com 20 normais e 15 de erro.

**Aceite 5a:** cenário 4.3 reproduzível: jam da porta direita → manual → `unjam door_right` → porta fecha → rebate. Cenário 4.8: intrusão abortada. `reset generator` acima de 50% pune; em blackout salva mas não fecha as portas.

> Status 19/09/2026: 5a implementada; aceite no Studio pendente. Notas: tablet, terminal e manual são telas exclusivas (`Overlay.luau`); com qualquer uma aberta as portas não respondem. `Debug.levelOverrides = { hexagon = 20 }` faz o Hexágono agir em todo tick para testar na Noite 1. O jumpscare do Hexágono é o ciano tomando a tela a partir do centro, com estática e `FIREWALL BREACHED`; a grade hexagonal propriamente dita fica para a Fase 6.
**Aceite 5b:** cenário 4.4: alerta com tablet aberto, minigame, acerto e erro (câmera morre e o ping passa a contar "em nó cego").

> Status 19/09/2026: 5b implementada; aceite no Studio pendente. `Debug.levelOverrides = { circle = 20 }` faz o Círculo tentar em todo tick para testar na Noite 1.

### Fase 6 — Áudio completo, jumpscares finais, polimento visual

- [x] Todos os cues da tabela 3.11 com assets em `GameConfig.Audio.ids` (placeholders licenciados, escolhidos sem audição; ver 3.11). Zumbido ambiente em loop, zumbido de energia baixa abaixo de 10%, "ding" às 6 AM, glitch do menu.
- [x] Jumpscares com modelos (cubo com olhos, prisma de duas cunhas, grade hexagonal de neon saindo do monitor) e coreografia de câmera (trava, tremor, campo de visão). No Hexágono, os textos do HUD viram lixo e o tom sobe até estourar.
- [x] Menu com glitch (RNG 1-15, >10 → 400 ms a cada 5 s) e estática.
- [x] Silhuetas melhores (cubo com olhos, prisma); luz fraca nos corredores tremulando; flicker das luzes da sala abaixo de 10%.
- [x] Sonar 3D (noite 6+): preset de Lighting + wireframe por 0.5s no ping (ver 3.5: tablet translúcido e campo de visão aberto durante o flash).
- [x] Configurações: volume master (passos de 10%, SoundGroup `Master`, salvo em `save.settings` pelo `UpdateSettings`).
- [ ] Passar por todas as telas no emulador mobile.

**Aceite:** alguém que nunca viu o jogo joga a Noite 1 sem explicação e entende o que os sons significam. Nenhum `print` visível, nenhum placeholder de texto.

> Status 19/09/2026: implementada; aceite no Studio pendente, incluindo a passada pelo Device Emulator (iPhone SE) e a audição dos sons. Revisão de 5.11 feita no código: todos os botões com pelo menos 48 px no iPhone SE (menu e ping do tablet foram ampliados), posições em Scale. `Debug.logSession` agora vem desligado. Pendências de texto: o rodapé `© 2026 Arthur` (B.8) espera os créditos do time; Tutorial e Custom Night aparecem bloqueados até a Fase 7.

### Fase 7 — Tutorial, progressão, save, balanceamento

- [x] `TutorialService` + `TutorialController`: os 8 passos de 3.12 (16 sub-passos, ver 3.12).
- [x] `SaveService` com DataStore, retry, migração, modo sem save e fila de writes.
- [x] Continue lê o save real. Vitória salva. Morte salva stats.
- [x] Custom Night (desbloqueada após a 7): 4 controles 0-20 com − e + (melhores que sliders no celular) e atalho 20/20/20/20.
- [x] Tela de créditos após a Noite 7 — estrutura pronta em `Strings.Credits`; o conteúdo final segue [DECIDIR] com o time.
- [ ] **Playtest de balanceamento:** 3 pessoas jogam as noites 1-4; anotar em que noite cada uma morreu pela primeira vez e por quê. Meta: primeira morte na Noite 3 ou 4. Ajustar a seção 7 e o `GameConfig`.

**Aceite:** um jogador novo faz Noite 0 → 1 → 2 sem ajuda externa. Fechar o Roblox e voltar abre na noite certa. Custom Night 20/20/20/20 é jogável (e quase impossível).

> Status 19/09/2026: implementada; aceite no Studio pendente, e o playtest com pessoas é do time. O save real exige o place publicado e "Enable Studio Access to API Services" ligado; sem isso o jogo entra em modo sem save e avisa no menu. O gerador de métricas de 7.8 é `Debug.logMetrics`. A simulação do Apêndice A está em 7.9, com propostas ainda não aplicadas.

### Fase 8 — Publicação

Ver seção 9.

---

## 7. BALANCEAMENTO INICIAL — TABELAS

Esta seção **é** o conteúdo de `GameConfig.luau`. Ao mudar aqui, mude lá (ou vice-versa, mas sempre os dois).

### 7.1 Tempo

| Parâmetro | Valor |
|---|---|
| Duração da noite | 360 s |
| Horas | 6 |
| Boot | 3 s |
| Graça antes das 6 | 2 s |

### 7.2 Energia (por segundo)

| Parâmetro | Valor |
|---|---|
| Base | 0.12 |
| Por porta fechada | 0.20 |
| Tablet aberto | 0.08 |
| Vazamento | 0.15 |
| Penalidade do puzzle | 5 (instantâneo) |
| Gerador reseta para | 50 |
| Usos do gerador por noite | 1 |
| Aviso (âmbar) | < 20 |
| Crítico (vermelho) | < 10 |

### 7.3 Ticks e faixas das IAs

| IA | Tick | Teste | Caminho / efeito |
|---|---|---|---|
| Quadrado | 5 s | d20 ≤ nível | CAM1 → CAM2 → DOOR L → escritório |
| Triângulo | 8 s | d20 ≤ nível | CAM1 → CAM3 → DOOR R → escritório |
| Círculo | 15 s | d20 ≤ nível | Alerta (fusível 30 s) → minigame 15 s → câmera morre |
| Hexágono | 25 s | d20 ≤ nível | −1 camada + 1 sistema; 0 camadas → intrusão 20 s |

### 7.4 Níveis por noite

| Noite | Quadrado | Triângulo | Círculo | Hexágono | Cue vol. | Sonar |
|---|---|---|---|---|---|---|
| 0 | 0 | 0 | 0 | 0 | 1.0 | não |
| 1 | 3 | 2 | 0 | 0 | 1.0 | não |
| 2 | 5 | 3 | 2 | 0 | 1.0 | não |
| 3 | 6 | 5 | 3 | 2 | 0.9 | não |
| 4 | 8 | 7 | 4 | 4 | 0.8 | não |
| 5 | 10 | 9 | 6 | 5 | 0.7 | não |
| 6 | 13 | 11 | 8 | 6 | 0.6 | sim |
| 7 | 16 | 14 | 10 | 8 | 0.5 | sim |

**Leitura rápida (chegadas na porta esperadas por noite):** Quadrado nível 3 = ~15% × 72 ticks ≈ 11 movimentos ≈ 3-4 chegadas. Nível 16 = 80% × 72 ≈ 58 movimentos ≈ 19 chegadas (uma a cada ~19 s). Triângulo nível 2 = 10% × 45 ≈ 4 movimentos ≈ 1-2 chegadas. Nível 14 = 70% × 45 ≈ 31 ≈ 10 chegadas. Hexágono nível 8 = 40% × 14 ticks ≈ 5.8 camadas rompidas — sem restaurar, a intrusão é certa na Noite 7. Círculo nível 10 = 50% × 24 ≈ 12 alertas (um a cada 30 s).

### 7.5 Radar

| Parâmetro | Valor |
|---|---|
| Processamento do ping | 1.0 s |
| Exibição do resultado | 6 s |
| Cooldown | 3 s |
| Ordem de destruição | CAM1, CAM4, CAM2, CAM3 |

### 7.6 Blackout

| Parâmetro | Valor |
|---|---|
| Fade das luzes | 3 s |
| Bateria do tablet | 15 s |
| Multiplicador de tick das IAs físicas | 0.5 |

### 7.7 Hexágono

| Parâmetro | Valor |
|---|---|
| Camadas | 5 |
| Intrusão | 20 s |
| Cooldown de restore | 10 s |

### 7.8 O que observar no playtest (métricas)

Registrar por partida (o `Debug.logAI` pode gerar isso):
- Noite, resultado, hora da morte, inimigo.
- Energia ao fim (ou hora do blackout).
- Número de vezes que cada porta fechou, tempo total fechada.
- Número de pings.
- Comandos digitados e quantos `command not found`.
- Erros no minigame e no puzzle.

Sinais de desbalanceamento: energia final > 60% na Noite 4 (portas baratas demais); morte na Noite 1 ou 2 por mais de 50% dos testers (Quadrado forte demais ou cue baixo demais); `command not found` > 3 por noite (comandos difíceis demais — considerar aliases como `unjam left`).

---

### 7.9 Simulação (Fase 7) e propostas [DECIDIR]

`tools/balance_sim.py` roda só a IA e a energia contra um jogador simulado, lendo os números do `GameConfig`. Resultado com os valores atuais (300 noites por linha; "competente" reage em 0.8-2 s e perde 3-10% dos cues; "mediano" reage em 1.2-3 s, perde 8-20% dos cues e erra mais puzzle e minigame):

| Noite | Vivo (competente) | Vivo (mediano) | Energia final (mediano) | Blackout (mediano) |
|---|---|---|---|---|
| 1 | 99% | 98% | 22% | 3% |
| 2 | 95% | 88% | 20% | 2% |
| 3 | 87% | 75% | 16% | 2% |
| 4 | 76% | 55% | 14% | 4% |
| 5 | 59% | 33% | 14% | 4% |
| 6 | 36% | 10% | 13% | 2% |
| 7 | 13% | 2% | 13% | 0% |

Leituras:

1. **A energia não escala com a noite.** Na soleira o inimigo só vai embora quando passa no d20, então a espera média é `tick / chance`. Somando as duas etapas até a porta, cada inimigo físico ativo deixa a porta fechada perto de um terço da noite, qualquer que seja o nível. Resultado: a Noite 1 termina com ~22%, não os ~45% do cenário 4.1, e a Noite 7 termina com quase o mesmo.
2. **Quase toda morte é do Quadrado**, que dá só 5 s de reação. O Triângulo (8 s) mata menos de 7% das vezes; o Hexágono nunca matou, porque o jogador simulado restaura o firewall antes de zerar — o perigo real dele é travar a porta na hora errada.
3. **A curva do jogador mediano bate com a meta da Fase 7** (primeira morte na Noite 3 ou 4) e despenca nas noites 6 e 7.

Propostas (nenhuma aplicada; o playtest com pessoas decide):

- **Energia, opção A (só números):** `drainPerDoor` 0.20 → 0.14 e `drainBase` 0.12 → 0.10. Energia final do mediano vai para ~35% na Noite 1 e ~25% na 7. A curva continua achatada, mas a Noite 1 passa a sobrar energia como 3.13 pede.
- **Energia, opção B (regra, muda 5.7):** com a porta fechada, o inimigo na soleira é rebatido no tick seguinte, sem rolar o d20. Energia final do mediano vai de ~49% na Noite 1 a ~19% na 7 — a escassez cresce com a noite, como 3.13 descreve. Custa a tensão do "inimigo estacionado na porta" do cenário 4.1 e sobe um pouco as mortes (mais chegadas por noite).
- **Fim da curva:** Quadrado 10/13/16 → 9/11/14 nas noites 5/6/7 leva o mediano de 33/10/2% para 37/18/5% de sobrevivência. Aumentar o volume do cue nas noites 6-7 rende menos (15% e 4%).
- **Hexágono:** observar no playtest se ele é passivo demais para humanos; se for, subir os níveis das noites 5-7.

## 8. BUGS E INCONSISTÊNCIAS DO PROTÓTIPO WEB (NÃO PORTAR)

Lista do que foi encontrado lendo o repositório. O port deve implementar o **design da seção 3**, não reproduzir isto.

### 8.1 Bugs de código

| Onde | Bug | No port |
|---|---|---|
| `main.js` | `btnNewGame.addEventListener('click', startGame)` — `startGame` não existe. | — |
| `main.js` | `btnContinue` é usado antes do `const btnContinue` (TDZ). O menu provavelmente não funciona. | — |
| `game.js` | `startNoite()` ignora o parâmetro `noite`; não há progressão. | `NightSession.new(players, night)` lê `Nights[night]`. |
| `game.js` | As IAs estão **comentadas** em `startNoite` — o jogo atual não tem inimigos. | — |
| `game.js` | O loop de energia é duplicado em `triggerEnergyOverride` com intervalo de **1000ms** em vez de 4500ms: após o reset, a energia drena 4,5× mais rápido. | Um único tick de energia no Scheduler. |
| `game.js` | `triggerJumpscare` para relógio e energia mas não as IAs. Depois de morrer, elas continuam rodando. | `scheduler:destroy()`. |
| `game.js` | `runOutPower` desabilita `btn-open-terminal` (botão do vírus), mas o `Tutorial.md` diz que o terminal é a salvação no blackout. Ambíguo. | Terminal funciona nos 15 s da bateria (3.9). |
| `camera.js` | Posição 3 acende `cam${posição}` = `cam3` para **os dois** inimigos, e posição 2 acende `cam2` para os dois. O Triângulo no corredor **direito** acendia a câmera do corredor **esquerdo**. | Nós nomeados por caminho (`DOOR_L`, `DOOR_R`, `CAM3`). |
| `camera.js` | O ping não distingue "câmera morta com inimigo" de "câmera vazia". | `blind` no `PingResult`. |
| `hexagon.js` | `attackThreshold: 80` com `rng > 80` = 20% fixo; não escala por noite. | d20 vs nível. |
| `hexagon.js` | 0 camadas = `alert()` imediato, sem aviso. | Intrusão de 20 s. |
| `circle.js` | O alerta fica ativo indefinidamente sem consequência. | Fusível de 30 s. |
| `puzzle.js` | `restore_firewall` pode ser repetido sem limite. | Cooldown de 10 s. |
| `terminal.js` | `reset generator` ilimitado. | 1× por noite. |
| `index.html` | `<span id="night">Noite 1</span>` nunca é atualizado. | HUD lê `NightStarted`. |
| `notebook.js` | O manual não menciona `reset generator`. | Página 5. |

### 8.2 Divergências entre `Tutorial.md`, `README_DEV.MD` e código

| Item | Tutorial.md | README_DEV | Código | Port |
|---|---|---|---|---|
| Tick do Quadrado | 4 s | — | 9 s (comentado) | **5 s** |
| Tick do Triângulo | 7 s | — | 16 s (comentado) | **8 s** |
| Tick do Círculo | 10 s | — | 20 s (comentado) | **15 s** |
| Tick do Hexágono | 20 s | — | 30 s | **25 s** |
| Dreno de energia | "a cada período configurado" | 1%/s, porta dobra para 2%/s | 1% a cada 4,5 s, +1 por porta | **0.12/s base, +0.20 por porta** |
| Duração da hora | — | — | 30 s | **60 s** |
| Noites | 11 | 11 | — | **7 + tutorial + custom** |
| Comando do gerador | `reset generator` | `Reset Energy Generator Protocol` | `reset generator` | **`reset generator`** |

### 8.3 O que estava bom e foi mantido

Vale registrar para não "consertar" o que funciona: o teste d20 vs nível; a estrutura em duas etapas do reparo do Hexágono (sistema + firewall); o minigame de sintaxe com palavras "erradas" temáticas; o puzzle de tabela-verdade; a punição por desespero do gerador; a estética de terminal e a ficção do "Node Map"; a máquina de escrever do tutorial; o glitch RNG do menu.

---

## 9. CHECKLIST DE PUBLICAÇÃO NO ROBLOX

- [ ] **Configurações do experience:** nome, descrição, gênero "Horror", `MaxPlayers = 1`, dispositivos: PC, mobile, console (testar os três).
- [ ] **Questionário de maturidade** (obrigatório): marcar **Medo** (jumpscares, ambiente de tensão) em nível moderado; sem violência gráfica, sem sangue, sem conteúdo romântico. Isso define a faixa etária sugerida. Preencher com honestidade — errar aqui pode derrubar o jogo.
- [ ] **Áudio:** só sons próprios ou da biblioteca do Roblox com licença de uso. Nada extraído de outros jogos. Sons subidos pelo time passam por moderação (pode levar horas).
- [ ] **Texto do jogador:** o terminal nunca exibe texto livre (5.6). Se isso mudar, `TextService:FilterStringAsync` é obrigatório.
- [ ] **DataStore:** habilitar "Enable Studio Access to API Services" só para testar; desabilitar para produção se não precisar.
- [ ] **Ícone e thumbnails:** 512×512 e 1920×1080. Sugestão: as quatro formas em preto com uma linha de estática. Sem texto pequeno (não lê no mobile).
- [ ] **Nome:** verificar disponibilidade de "Five Nights at Geometry". Se ocupado, variações: "Five Nights at Geometry OS", "Geometry OS: Five Nights".
- [ ] **Privacidade:** publicar privado primeiro; testar com 3-5 amigos por uma semana; depois público.
- [ ] **Versões:** o Roblox guarda versões publicadas — dá para reverter. Mas o Git é a fonte de verdade.
- [ ] **Monetização:** nenhuma na v1. Se um dia: Custom Night como Game Pass é o candidato natural. Nunca vender vantagem que quebre o pilar 1.

---

## 10. BACKLOG E IDEIAS FUTURAS (NÃO AGORA)

Coisas discutidas ou imaginadas que **não entram na v1**. Registradas para não se perder.

- **Co-op 2-4 jogadores:** decisões pendentes em 2.2. Provável desenho: energia compartilhada, qualquer um fecha qualquer porta, um terminal por jogador, morte de um = morte de todos.
- **Quinto inimigo — o Pentágono:** físico, mas usa um caminho que passa por CAM4 e pode chegar por qualquer lado (o ping em CAM4 mostra "direção indefinida"). Só faz sentido depois de balancear os quatro.
- **Aliases de comando:** `unjam left`, `fix cam`, `seal leak`. Reduz `command not found` sem tirar a ficção.
- **Terminal com histórico:** setas ↑/↓ no PC.
- **Modo "sem som"** (acessibilidade): telegraph visual mais forte (a silhueta pisca) quando o jogador marca "surdo/sem áudio" nas configurações.
- **Leaderboard de Custom Night:** melhor tempo de sobrevivência em 20/20/20/20. Precisa de servidor autoritativo (já é) e `OrderedDataStore`.
- **Lore expandida:** logs de sistema que aparecem no `status` a cada noite, contando o que aconteceu com o projeto da pizzaria. O jogador que lê descobre a história.
- **Modos de dificuldade do tutorial:** "Noite 0 rápida" que só mostra os comandos.
- **Roblox Voice / câmera do jogador:** não.
- **Traduções:** `Strings.luau` já separa; inglês seria o primeiro.
- **Estatísticas na tela de game over:** "você fechou a porta esquerda 14 vezes; 3 rebates; 2 comandos errados". Ajuda o jogador a aprender e é barato de fazer com as métricas de 7.8.

---

## 11. GLOSSÁRIO

| Termo | Significado |
|---|---|
| **Anomalia** | Nome que o sistema dá a um inimigo detectado pelo radar. |
| **Cue** | Sinal sonoro (ou visual) que informa um evento ao jogador. |
| **d20** | Sorteio de 1 a 20. A IA age se o resultado for ≤ ao seu nível. |
| **Firewall** | As 5 camadas que o Hexágono rompe. 0 = intrusão. |
| **Fusível** | Tempo que o alerta do Círculo fica ativo antes de agir sozinho (30 s). |
| **Intrusão** | Contagem de 20 s após o firewall chegar a 0. |
| **Jam** | Porta travada pelo Hexágono (`door_*_jammed`). |
| **Nó / Node** | Um ponto do mapa do radar (CAM1-4, DOOR L/R). |
| **Nó cego** | Nó cuja câmera foi destruída; ainda conta anomalias, sem mostrar onde. |
| **Ping** | Ação do radar que revela anomalias por ~6 s. |
| **Predição** | O cliente animar uma ação antes de o servidor confirmar. |
| **Rebate** | Inimigo físico bater na porta fechada e voltar ao palco ("BAM"). |
| **Scheduler** | O relógio único da sessão (Heartbeat + acumuladores). |
| **Sessão / NightSession** | Todo o estado de uma noite, do boot ao fim. |
| **Soleira** | Posição 3 de um inimigo físico: na porta, prestes a entrar. |
| **Sonar 3D** | Flash wireframe no ping, a partir da noite 6. |
| **Telegraph** | Aviso prévio de que algo vai acontecer (a chegada na soleira). |
| **Whitebox** | Cena 3D feita de blocos cinza, sem arte, para testar funcionamento. |

---

## APÊNDICE A — PROMPTS SUGERIDOS PARA O CLAUDE CODE, POR FASE

Use no início de cada fase. Ajuste o que já foi feito. O importante é: apontar para a seção, pedir uma fase só, exigir o critério de aceite.

**Fase 0:**
> Leia PLANEJAMENTO_ROBLOX.md. Faça o setup da Fase 0 (seção 6): estrutura de pastas da seção 5.1, default.project.json, aftman/rokit com rojo, selene e stylua, e um Main.server.luau que imprime "GEOMETRY OS boot". Não implemente nada de jogo ainda. Ao final, me diga como rodar rojo serve e conectar o Studio.

**Fase 1:**
> Leia PLANEJAMENTO_ROBLOX.md, seções 2, 3.1, 3.2, 5.2, 5.3, 5.4, 5.6 e a Fase 1 da seção 6. Implemente a Fase 1 completa: GameConfig com todos os valores da seção 7, Scheduler, NightSession com relógio e energia, NightService, Remotes, HudController e MenuController mínimos. Nada de inimigos. Siga as convenções do Apêndice C. Quando terminar, descreva como verificar o critério de aceite da Fase 1 no Studio e marque as caixas da Fase 1 no documento.

**Fase 2:**
> Implemente a Fase 2 (seção 6) seguindo 3.3, 3.4, 5.11, 5.13. Construa a sala whitebox por código em OfficeBuilder.server.luau para ficar versionada. Portas com predição no cliente e reversão (fluxo em 5.8). Sons de porta posicionais. Blackout visual. Teste mentalmente contra o Device Emulator iPhone SE. Critério de aceite: morrer de blackout com as duas portas às ~3:12 AM.

**Fase 3:**
> Implemente a Fase 3: PatrolAI conforme 5.7 (uma classe, duas instâncias a partir de GameConfig.Patrol), cues de chegada/rebate posicionais com ducking (5.13), silhuetas, jumpscares e tela de game over (3.10). Adicione Debug.logAI e Debug.deterministicSeed. Reproduza o cenário 4.1 com seed fixa e me mostre o log dos sorteios.

**Fase 4:**
> Implemente a Fase 4: RadarService e TabletController conforme 3.5 e o fluxo de ping em 5.8. O tablet custa energia. Nós DEAD contam anomalias como "em nó cego". Bateria de 15 s no blackout. Não implemente o Círculo ainda — deixe um comando de debug para matar uma câmera.

**Fase 5a:**
> Implemente a Fase 5a: TerminalService/Controller (3.6, com paleta de comandos e eco canônico), NotebookController com as 5 páginas do Apêndice B, FirewallService e HexagonAI (3.8.4), puzzle com LogicGates compartilhado, intrusão de 20 s, e reset generator (3.9). Depois reproduza os cenários 4.3, 4.5, 4.6 e 4.8 e me diga se o comportamento bate.

**Fase 5b:**
> Implemente a Fase 5b: CircleAI e MinigameService (3.8.3) com fusível de 30 s, minigame com prioridade sobre o prompt do terminal, timer de 15 s, e destruição de câmeras na ordem do config. Reproduza o cenário 4.4 incluindo as duas variantes.

**Fase 6:**
> Passe por todos os cues da tabela 3.11 e liste os que faltam asset. Implemente os jumpscares finais (3.8) e o sonar 3D (3.5) para noites com sonar=true. Revise todas as ScreenGuis contra 5.11 (alvos ≥ 48 px, Scale em vez de Offset).

**Fase 7:**
> Implemente TutorialService/Controller com os 8 passos de 3.12 (diálogos no Apêndice B), SaveService conforme 3.14 e 5.10 com retry e modo sem save, Custom Night, e o gerador de métricas de 7.8 em Debug. Depois me proponha mudanças na seção 7 com base numa simulação de 20 noites por nível com seed variada (só a IA e a energia, sem UI).

**Prompt de manutenção (qualquer hora):**
> Compare o código atual com PLANEJAMENTO_ROBLOX.md e liste onde eles divergem. Não mude nada ainda; só liste.

---

## APÊNDICE B — TEXTOS DO JOGO

Tudo aqui vai para `src/shared/Strings.luau`. Manter em português; comandos em inglês.

### B.1 Terminal

**Boot:**
```
GEOMETRY OS v1.0 ONLINE...
Sistemas estabilizados. Aguardando comando.
```

**Prompt:** `root@office:~$`

**Comandos canônicos** (chave = o que o jogador digita, em minúsculas; o servidor faz `trim` e `lower`):

| Entrada | Resposta (ok) | Resposta (falha) |
|---|---|---|
| `help` | `Comandos: help, status, clear, fix camera, unjam door_left, unjam door_right, sync clock, seal power_leak, restore_firewall, reset generator` | — |
| `status` | `Firewall: 4/5` / `Energia: 63%` / `Sistemas: ALL OK` ou `  [!] door_left_jammed` por linha / `Nodes mortos: CAM1` ou `Nodes: OK` / `Gerador: 1 uso` | — |
| `clear` | (limpa) | — |
| `fix camera` | `[OK] camera_offline restored.` | `[WARN] camera_offline is not currently corrupted.` |
| `unjam door_left` | `[OK] door_left_jammed restored.` | `[WARN] door_left_jammed is not currently corrupted.` |
| `unjam door_right` | `[OK] door_right_jammed restored.` | `[WARN] door_right_jammed is not currently corrupted.` |
| `sync clock` | `[OK] clock_glitch restored.` | `[WARN] clock_glitch is not currently corrupted.` |
| `seal power_leak` | `[OK] power_leak restored.` | `[WARN] power_leak is not currently corrupted.` |
| `restore_firewall` | `Opening logic-gate repair console...` | `Firewall already at maximum.` / `Console em cooldown. Aguarde.` |
| `reset generator` | `Iniciando protocolo de override do gerador...` + `[OK] Gerador forçado. Bateria restaurada para 50%.` | `[AVISO] Sobrecarga detectada! Bateria descarregada para 50%.` / `[ERRO] Override já utilizado nesta noite.` |
| (outro) | — | `command not found` |

**Alertas assíncronos** (aparecem no terminal se ele estiver aberto):
- `[ALERT] <sistema> corrupted by HEXAGON`
- `[ALERT] Firewall layer lost. <n>/5 remaining.`
- `[CRITICAL] INTRUSION IN PROGRESS. Restore firewall.`
- `[ALERT] Node <cam> destroyed by CIRCLE.`

**Minigame:**
```
SISTEMA CORROMPIDO. SELECIONE A ANOMALIA:
```
- Acerto: `[OK] Vírus expurgado. Sistemas nominais.`
- Erro: `[ERR] Sintaxe válida detectada. Node de vídeo destruído.`
- Timeout: `[ERR] Tempo esgotado. O vírus destruiu um node de vídeo.`
- Prompt bloqueado: `[bloqueado — resolva a anomalia]`

**Palavras normais** (mínimo 20; as 12 originais + 8 novas):
```
Function_Door, Central_Connection, Terminal_Overdrive, System_Boot, Camera_Feed,
Audio_Link, Security_Breach, Power_Grid, Ventilation_Control, Mainframe_Access,
Data_Log, Motion_Sensor, Node_Sync, Firewall_Layer, Door_Servo, Clock_Daemon,
Radar_Pulse, Battery_Monitor, Access_Token, Kernel_Patch
```

**Palavras de erro** (mínimo 15; as 9 originais + 6 novas):
```
Banana_Core, Pizza_Protocol, Teeth_Render, Glitch_Entity, Smile_Format,
Eye_Tracker, Meat_Syntax, Blood_String, Shadow_Byte, Laugh_Buffer,
Skin_Compile, Hunger_Loop, Whisper_Socket, Bone_Index, Wet_Pointer
```

Regra para adicionar palavras: normais parecem nomes de módulo de sistema; erradas misturam vocabulário de sistema com algo orgânico/perturbador. Nunca deixe uma palavra errada ser plausível como sistema (`Eye_Tracker` está no limite — é intencionalmente a mais difícil).

### B.2 Puzzle

- Título: `PAINEL DE CIRCUITO LÓGICO — RESTAURAÇÃO DE FIREWALL`
- Instrução: `Identifique a porta lógica que gera a tabela-verdade abaixo.`
- Cabeçalho: `A | B | OUT`
- Botões: `AND(a, b)`, `OR(a, b)`, `XOR(a, b)`, `NAND(a, b)`, `NOR(a, b)`, `XNOR(a, b)`
- Acerto: `[OK] <PORTA> bate com a tabela. +1 camada de Firewall.`
- Erro: `[ERR] <PORTA> não bate. Punição: -5% energia. Tente novamente.`
- Cancelar: `CANCELAR ✕`

Tabelas-verdade (para `LogicGates.luau`):

| A | B | AND | OR | XOR | NAND | NOR | XNOR |
|---|---|---|---|---|---|---|---|
| 0 | 0 | 0 | 0 | 0 | 1 | 1 | 1 |
| 0 | 1 | 0 | 1 | 1 | 1 | 0 | 0 |
| 1 | 0 | 0 | 1 | 1 | 1 | 0 | 0 |
| 1 | 1 | 1 | 1 | 0 | 0 | 0 | 1 |

### B.3 Manual (5 páginas)

**Capa/cabeçalho:** `MANUAL DE PROCEDIMENTOS — Vol. 1`

**Página 1 — PROCEDIMENTOS DE EMERGÊNCIA**
> Se algum sistema for corrompido pelo vírus, abra o TERMINAL e digite o comando exato da página correspondente. Comandos só funcionam enquanto o sistema estiver corrompido.
> O sistema informa corrupções no painel superior (`[!] nome_do_sistema`).

**Página 2 — CÓDIGOS DE REPARO — I**
- `fix camera` — Recompila o feed da câmera principal. (camera_offline)
- `unjam door_left` — Libera o motor travado da porta esquerda. (door_left_jammed)
- `unjam door_right` — Libera o motor travado da porta direita. (door_right_jammed)

**Página 3 — CÓDIGOS DE REPARO — II**
- `sync clock` — Ressincroniza o cronômetro do sistema. (clock_glitch)
- `seal power_leak` — Fecha o vazamento no gerador. (power_leak)
> Nota: uma porta travada congela no estado em que está. Se estava fechada, continua consumindo energia.

**Página 4 — FIREWALL — RESTAURAÇÃO**
> Para subir +1 camada de Firewall, digite `restore_firewall` no Terminal e resolva o circuito lógico exibido. Erros custam 5% de energia.
> Se o Firewall chegar a zero, uma INTRUSÃO começa. Você tem 20 segundos para restaurar uma camada.

**Página 5 — PROTOCOLO DE BLACKOUT** [NOVO]
> Quando a energia zera, as portas abrem e as luzes apagam. O tablet e o terminal funcionam por 15 segundos na bateria interna.
> Comando de emergência: `reset generator` — restaura a energia para 50%. Uso único por noite.
> ATENÇÃO: usado com a energia acima de 50%, o sistema entende como sobrecarga e REDUZ a energia para 50%.
> O gerador não fecha as portas. Feche-as você.

### B.4 HUD

- Relógio: `12:00 AM`, `1:00 AM` … `6:00 AM`. Glitch: 8 caracteres de `!@#$%^&*?<>/\|`, trocando a cada 0.18 s.
- Noite: `NOITE 0 — TUTORIAL`, `NOITE 1` … `NOITE 7`, `CUSTOM NIGHT`.
- Energia: `ENERGIA: 63%` + barrinhas de consumo `▮▮▯▯`.
- Firewall: `FIREWALL: ▮▮▮▮▯`.
- Sistemas: `[!] door_left_jammed` (uma linha por sistema).
- Vírus: `ANOMALIA DETECTADA — ABRIR TERMINAL` + barra.
- Intrusão: `INTRUSÃO EM CURSO — RESTAURE O FIREWALL — 17s`.
- Porta travada (ao clicar): `MOTOR TRAVADO — ver manual`.
- Gerador: `GERADOR: 1 uso` / `GERADOR: usado`.
- Câmera morta: `NODE CAM 1 DESTRUÍDO`.
- Blackout: `BLACKOUT — bateria do tablet: 12s`.
- Tablet indisponível: `TABLET OFFLINE — fix camera`.

### B.5 Tablet

- Título: `GLOBAL SECURITY NODE MAP v2.4`
- Nós: `CAM 1 — PALCO`, `CAM 2 — CORR. ESQ`, `CAM 3 — CORR. DIR`, `CAM 4 — SERVIDORES`, `DOOR L`, `DOOR R`, `ESCRITÓRIO`.
- Botão: `▶ EMITIR PING RADAR GLOBAL`
- Status: `SISTEMA EM ESPERA...` / `ENVIANDO PING RADAR PARA TODOS OS NODES...` / `SCAN COMPLETO. <n> ANOMALIA(S).` / `SCAN COMPLETO. <n> ANOMALIA(S) (<m> EM NÓ CEGO).` / `SCAN COMPLETO. NENHUMA ANOMALIA VISÍVEL.` / `SINAL PERDIDO. RECOMENDA-SE NOVO PING.`
- Nó morto: `DEAD`. CAM 4 com vírus pendente: `TRÁFEGO ANÔMALO`.

### B.6 Tutorial (Noite 0)

Falas da Unidade de Assistência de Debug. As quatro primeiras são as originais.

**Abertura:**
1. `SISTEMA INICIADO.`
2. `Olá. Eu sou a sua unidade de assistência de debug.`
3. `Identifiquei que você foi escalado para validar o Geometry OS.`
4. `Não se preocupe, eu guiarei você pelos protocolos básicos de sobreviv... digo, de teste.`

**Passo 2 — olhar:**
5. `Primeiro, familiarize-se com o ambiente. Olhe para os dois lados.`
6. (após girar) `Ótimo. Duas saídas. Duas... entradas.`

**Passo 3 — portas:**
7. `Feche a porta esquerda. O botão está na parede.`
8. (após fechar) `Observe o consumo de energia no painel. Portas fechadas gastam a energia que você não tem.`
9. `Abra de novo. Você vai fechar só quando precisar.`

**Passo 4 — radar:**
10. `Abra o tablet e emita um ping. Ele mostra onde as anomalias estão. Onde estavam, na verdade.`
11. (após ping) `Uma anomalia no corredor esquerdo. Quando ela chegar à porta, você vai ouvir.`
12. (toca o cue) `Agora. Feche a porta.`
13. (após rebate) `Rebatida. Ela volta ao palco e tenta de novo. Abra a porta para economizar.`

**Passo 5 — manual:**
14. `Na mesa há um manual. Abra e leia a página 2. Vai precisar.`

**Passo 6 — terminal:**
15. `Simulando uma corrupção de sistema...`
16. `A porta direita travou. O manual diz o que fazer. O terminal está no monitor.`
17. (após reparo) `Reparado. Nas noites reais, você não terá tempo de ler. Decore.`

**Passo 7 — firewall:**
18. `Uma camada do firewall foi rompida. Digite restore_firewall e resolva o circuito.`
19. (após acerto) `Correto. Se o firewall chegar a zero, você terá vinte segundos. Não chegue a zero.`

**Encerramento:**
20. `Você está pronto. Ou tão pronto quanto qualquer um estaria.`
21. `Boa sorte na Noite 1. Eu estarei... por perto.`

### B.7 Telas de fim

- Vitória: `6:00 AM` → `NOITE <n> CONCLUÍDA` → (noite 7) `SIMULAÇÃO ENCERRADA` + créditos.
- Derrota: `FALHA CRÍTICA — NOITE <n>` / `anomalia: QUADRADO AZUL` | `TRIÂNGULO VERMELHO` | `HEXÁGONO CIANO` / `[TENTAR DE NOVO] [MENU]`.
- Hexágono: antes da tela, `FIREWALL BREACHED` em ciano.

### B.8 Menu

- Título: `Five Nights at Geometry`
- Botões, da esquerda para a direita: `Configurações`, `Custom Night`, `Tutorial`, `New Game`, `Continue`
- Rodapé: `© 2026 Arthur` (ajustar créditos do time)
- Save indisponível: `Save indisponível — progresso não será salvo`

---

## APÊNDICE C — CONVENÇÕES DE CÓDIGO LUAU

1. **`--!strict` em todo arquivo.** Tipos exportados em `Types.luau`. Sem `any` sem comentário justificando.
2. **Nomes:** módulos e classes em `PascalCase` (`NightSession`), funções e variáveis em `camelCase`, constantes em `UPPER_SNAKE` só dentro de módulos (config vem do `GameConfig`, não de constantes locais). Remotes em `PascalCase` (`ToggleDoor`).
3. **Um módulo, uma responsabilidade.** Se um arquivo passa de ~300 linhas, provavelmente são dois.
4. **Serviços do Roblox** sempre via `game:GetService("X")` no topo do arquivo.
5. **Sem `wait()`, sem `spawn()`, sem `delay()`.** Use `task.wait`, `task.spawn`, `task.delay` — e para lógica de jogo, o `Scheduler`.
6. **Sem `math.random` na lógica de jogo.** Use `session.rng`.
7. **Sem números mágicos.** Se é um número de jogo, está no `GameConfig`. Se é um número de UI (padding), pode ser local com nome.
8. **Sem texto de jogo inline.** Está no `Strings`.
9. **Remotes:** o servidor valida tudo (tipo, faixa, pré-condição) antes de tocar no estado. O cliente nunca assume que um pedido foi aceito.
10. **Erros:** `pcall` só em DataStore, `TweenService` em objetos que podem não existir, e chamadas de assets. Erro de lógica deve estourar em Studio — é assim que se acha.
11. **Logs:** `print` só atrás de `GameConfig.Debug.*`. `warn` para situações recuperáveis. Nunca deixar `print` solto.
12. **Comentários** explicam *por quê*, não *o quê*. Referenciar a seção deste documento quando implementar uma regra (`-- ver PLANEJAMENTO 3.9: portas ficam abertas após reset`).
13. **Formatação:** `stylua` com o `stylua.toml` do repo (4 espaços, 120 colunas, aspas duplas).
14. **Commits:** `feat(fase-3): PatrolAI com cues e silhueta`, `fix(radar): contar nós cegos`, `balance: drainPerDoor 0.20 → 0.22`. Um commit por tarefa da seção 6.

---

*Fim do documento. Próxima ação: validar a Fase 7 e o menu com palco 3D (5.12) no Studio, decidir as propostas de 7.9 com o playtest e seguir para a Fase 8 (publicação).*
