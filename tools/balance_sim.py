"""Simulação de balanceamento (PLANEJAMENTO, Apêndice A — Fase 7; métricas de 7.8).

Roda só a IA e a energia, sem UI, contra um "jogador competente" simulado, e imprime por noite: taxa de
sobrevivência, causa das mortes, blackouts, energia final e tempo de porta fechada.

Os números do jogo (ticks, drenos, níveis por noite...) são lidos de src/shared/GameConfig.luau, então a
simulação acompanha o balanceamento do jogo. As regras de jogo são reimplementadas aqui em Python: se uma
regra mudar no Luau, mude aqui também. O comportamento do jogador (tempos de reação, chance de erro) é uma
aproximação e fica nas constantes BOT_* abaixo — é o que mais vale ajustar depois do playtest de verdade.

Uso:
    python tools/balance_sim.py              # 200 noites por nível, seeds 1..200
    python tools/balance_sim.py --runs 50 --seed 7
"""

import argparse
import os
import random
import re
from collections import Counter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG_PATH = os.path.join(ROOT, "src", "shared", "GameConfig.luau")

# ----------------------------------------------------------------------------- jogador simulado
BOT_REACT = (0.8, 2.0)          # segundos entre o som de chegada e o clique na porta
BOT_MISS_BASE = 0.03            # chance de não ouvir o cue com volume 1.0
BOT_MISS_PER_QUIET = 0.15       # + isto × (1 − arrivalCueVolume)
BOT_MISS_EXTRA = 4.0            # quem não ouviu só percebe pela silhueta, alguns segundos depois
BOT_REOPEN = (0.3, 1.0)         # depois do BAM, quanto demora para abrir a porta
BOT_SWITCH = 0.5                # fechar tablet/terminal para ir até a porta
BOT_REPAIR = (2.5, 5.0)         # abrir o terminal e digitar/tocar um comando de reparo
BOT_PUZZLE = (4.0, 8.0)         # abrir o puzzle e acertar a porta lógica
BOT_PUZZLE_WRONG = 0.25         # chance de errar cada tentativa do puzzle
BOT_PUZZLE_RETRY = (2.0, 4.0)   # nova tentativa depois de um erro (além dos 1.4 s de nova tabela)
BOT_RESTORE_AT = 2              # restaura o firewall quando sobram isto ou menos camadas
BOT_VIRUS_NOTICE = (3.0, 10.0)  # quanto demora para ir ao terminal depois do alerta do Círculo
BOT_MINIGAME = (2.0, 6.0)       # achar a palavra infectada
BOT_MINIGAME_OK = 0.85          # chance de acertar a palavra
BOT_PING_EVERY = (25.0, 45.0)   # intervalo entre pings
BOT_PING_TIME = 3.0             # tablet aberto por ping
BOT_GENERATOR_AT = 6.0          # usa o gerador abaixo desta energia, se ainda falta noite
BOT_BLACKOUT_SAVE = 0.8         # chance de achar o reset generator nos 15 s de bateria
BOT_BLACKOUT_TIME = (3.0, 8.0)

DT = 0.1  # passo da simulação, em segundos


# ----------------------------------------------------------------------------- leitura do GameConfig
def _block(text, name):
    start = re.search(r"\n    %s = \{" % name, text)
    assert start, "bloco %s não encontrado no GameConfig" % name
    i = start.end()
    depth = 1
    while depth:
        depth += {"{": 1, "}": -1}.get(text[i], 0)
        i += 1
    return text[start.end():i]


def _num(block, key):
    m = re.search(r"\b%s\s*=\s*(-?[0-9.]+)" % key, block)
    assert m, "%s não encontrado" % key
    return float(m.group(1))


def load_config():
    text = open(CONFIG_PATH, encoding="utf-8").read()
    night, power = _block(text, "Night"), _block(text, "Power")
    blackout, doors = _block(text, "Blackout"), _block(text, "Doors")
    circle, hexagon = _block(text, "Circle"), _block(text, "Hexagon")
    patrol, puzzle = _block(text, "Patrol"), _block(text, "Puzzle")
    nights = {}
    for m in re.finditer(
        r"\[(\d+)\] = \{ square = (\d+), triangle = (\d+), circle = (\d+), hexagon = (\d+), "
        r"arrivalCueVolume = ([0-9.]+)",
        _block(text, "Nights"),
    ):
        n = int(m.group(1))
        nights[n] = dict(square=int(m.group(2)), triangle=int(m.group(3)), circle=int(m.group(4)),
                         hexagon=int(m.group(5)), volume=float(m.group(6)))
    square_tick = float(re.search(r"square = \{ tickSeconds = ([0-9.]+)", patrol).group(1))
    triangle_tick = float(re.search(r"triangle = \{ tickSeconds = ([0-9.]+)", patrol).group(1))
    return dict(
        duration=_num(night, "durationSeconds"), grace=_num(night, "graceBeforeDawn"),
        drain_base=_num(power, "drainBase"), drain_door=_num(power, "drainPerDoor"),
        drain_tablet=_num(power, "drainTablet"), drain_leak=_num(power, "drainLeak"),
        penalty=_num(power, "puzzlePenalty"), reset_to=_num(power, "generatorResetTo"),
        battery=_num(blackout, "tabletBatterySeconds"), blackout_mult=_num(blackout, "aiTickMultiplier"),
        square_tick=square_tick, triangle_tick=triangle_tick,
        circle_tick=_num(circle, "tickSeconds"), fuse=_num(circle, "alertFuseSeconds"),
        minigame=_num(circle, "minigameSeconds"),
        hex_tick=_num(hexagon, "tickSeconds"), layers=int(_num(hexagon, "maxLayers")),
        intrusion=_num(hexagon, "intrusionSeconds"), restore_cooldown=_num(hexagon, "restoreCooldownSeconds"),
        new_table=_num(puzzle, "newTableAfterWrongSeconds"),
        nights=nights,
    )


# ----------------------------------------------------------------------------- uma noite
SYSTEMS = ["camera_offline", "door_left_jammed", "door_right_jammed", "clock_glitch", "power_leak"]
REPAIR_PRIORITY = ["door_left_jammed", "door_right_jammed", "camera_offline", "power_leak", "clock_glitch"]


class Night:
    def __init__(self, cfg, levels, rng):
        self.cfg, self.lv, self.rng = cfg, levels, rng
        self.t = 0.0
        self.power = 100.0
        self.closed = {"L": False, "R": False}
        self.jammed = {"L": False, "R": False}
        self.closed_time = 0.0
        self.pos = {"L": 1, "R": 1}                  # 1 palco, 2 corredor, 3 soleira
        self.next_tick = {"L": cfg["square_tick"], "R": cfg["triangle_tick"],
                          "circle": cfg["circle_tick"], "hex": cfg["hex_tick"]}
        self.corrupted = set()
        self.layers = cfg["layers"]
        self.intrusion_end = None
        self.restore_ready = 0.0
        self.alert_end = None                        # fusível do Círculo
        self.alert_notice = None
        self.minigame_end = None
        self.generator = 1
        self.blackout = False
        self.battery_end = None
        self.tablet = False
        self.notice = {"L": None, "R": None}         # quando o bot percebe o inimigo na soleira
        self.reopen_at = {"L": None, "R": None}
        self.busy_until = 0.0
        self.busy_kind = None
        self.pending = None                          # efeito da ação em andamento
        self.next_ping = rng.uniform(*BOT_PING_EVERY)
        self.death = None
        self.blackout_at = None
        self.used_generator = False

    # ---------------------------------------------------------------- IA
    def patrol(self, side):
        level = self.lv["square" if side == "L" else "triangle"]
        if level <= 0 or self.rng.randint(1, 20) > level:
            return
        if self.pos[side] < 3:
            self.pos[side] += 1
            if self.pos[side] == 3:
                miss = BOT_MISS_BASE + BOT_MISS_PER_QUIET * (1 - self.lv["volume"])
                delay = self.rng.uniform(*BOT_REACT) + (BOT_MISS_EXTRA if self.rng.random() < miss else 0)
                self.notice[side] = self.t + delay
            return
        if self.closed[side]:
            self.pos[side] = 1
            self.notice[side] = None
            self.reopen_at[side] = self.t + self.rng.uniform(*BOT_REOPEN)
        else:
            self.death = "square" if side == "L" else "triangle"

    def circle(self):
        if self.lv["circle"] <= 0 or self.rng.randint(1, 20) > self.lv["circle"]:
            return
        if self.alert_end is None and self.minigame_end is None and self.busy_kind != "terminal":
            self.alert_end = self.t + self.cfg["fuse"]
            self.alert_notice = self.t + self.rng.uniform(*BOT_VIRUS_NOTICE)

    def hexagon(self):
        if self.lv["hexagon"] <= 0 or self.rng.randint(1, 20) > self.lv["hexagon"] or self.layers <= 0:
            return
        self.layers -= 1
        intact = [s for s in SYSTEMS if s not in self.corrupted]
        if intact:
            system = self.rng.choice(intact)
            self.corrupted.add(system)
            if system == "door_left_jammed":
                self.jammed["L"] = True
            elif system == "door_right_jammed":
                self.jammed["R"] = True
        if self.layers == 0:
            self.intrusion_end = self.t + self.cfg["intrusion"]

    # ---------------------------------------------------------------- jogador
    def start(self, kind, duration, effect):
        self.busy_kind, self.busy_until, self.pending = kind, self.t + duration, effect

    def threat(self):
        for side in ("L", "R"):
            n = self.notice[side]
            if n is not None and self.t >= n and self.pos[side] == 3 and not self.closed[side]:
                return side
        return None

    def decide(self):
        side = self.threat()
        # Inimigo na porta interrompe tablet e terminal (exceto o próprio reparo da porta)
        if side and self.busy_kind in ("tablet", "terminal") and self.pending != ("unjam", side):
            self.tablet = False
            self.start("switch", BOT_SWITCH, None)
            return
        if self.t < self.busy_until:
            return
        if side:
            if self.blackout:
                return  # botões travados no blackout
            if self.jammed[side]:
                self.start("terminal", self.rng.uniform(*BOT_REPAIR), ("unjam", side))
            else:
                self.closed[side] = True
            return
        for s in ("L", "R"):
            r = self.reopen_at[s]
            if r is not None and self.t >= r and self.closed[s] and not self.jammed[s] and not self.blackout:
                self.closed[s] = False
                self.reopen_at[s] = None
                return
        terminal_ok = not self.blackout or (self.battery_end is not None and self.t < self.battery_end)
        if self.blackout and self.generator and terminal_ok:
            if self.rng.random() < BOT_BLACKOUT_SAVE:
                self.start("terminal", self.rng.uniform(*BOT_BLACKOUT_TIME), ("generator",))
            else:
                self.generator = 0  # não achou o comando a tempo
            return
        if not terminal_ok:
            return
        if self.intrusion_end is not None and self.t >= self.restore_ready:
            self.start("terminal", self.puzzle_time(), ("restore",))
            return
        if self.alert_end is not None and self.t >= self.alert_notice:
            self.alert_end = None
            self.minigame_end = self.t + self.cfg["minigame"]
            self.start("terminal", self.rng.uniform(*BOT_MINIGAME), ("minigame",))
            return
        if (self.generator and not self.blackout and self.power < BOT_GENERATOR_AT
                and self.cfg["duration"] - self.t > 30):
            self.start("terminal", 3.0, ("generator",))
            return
        for system in REPAIR_PRIORITY:
            if system in self.corrupted:
                self.start("terminal", self.rng.uniform(*BOT_REPAIR), ("repair", system))
                return
        if self.layers <= BOT_RESTORE_AT and self.t >= self.restore_ready:
            self.start("terminal", self.puzzle_time(), ("restore",))
            return
        if self.t >= self.next_ping and "camera_offline" not in self.corrupted and not self.blackout:
            self.tablet = True
            self.start("tablet", BOT_PING_TIME, ("ping",))

    def puzzle_time(self):
        duration = self.rng.uniform(*BOT_PUZZLE)
        while self.rng.random() < BOT_PUZZLE_WRONG:
            self.power = max(0.0, self.power - self.cfg["penalty"])
            duration += self.cfg["new_table"] + self.rng.uniform(*BOT_PUZZLE_RETRY)
        return duration

    def finish(self):
        effect, self.pending, self.busy_kind = self.pending, None, None
        if not effect:
            return
        kind = effect[0]
        if kind == "unjam":
            side = effect[1]
            self.corrupted.discard("door_%s_jammed" % ("left" if side == "L" else "right"))
            self.jammed[side] = False
            if not self.blackout:
                self.closed[side] = True
        elif kind == "repair":
            system = effect[1]
            self.corrupted.discard(system)
            if system == "door_left_jammed":
                self.jammed["L"] = False
            elif system == "door_right_jammed":
                self.jammed["R"] = False
        elif kind == "restore":
            self.layers = min(self.cfg["layers"], self.layers + 1)
            self.intrusion_end = None
            self.restore_ready = self.t + self.cfg["restore_cooldown"]
        elif kind == "minigame":
            self.minigame_end = None  # acerto ou erro: só custa câmera, que o bot não usa para decidir
        elif kind == "generator":
            self.generator = 0
            self.used_generator = True
            self.power = self.cfg["reset_to"]
            if self.blackout:
                self.blackout = False
                self.battery_end = None
        elif kind == "ping":
            self.tablet = False
            self.next_ping = self.t + self.rng.uniform(*BOT_PING_EVERY)

    # ---------------------------------------------------------------- relógio
    def run(self):
        cfg = self.cfg
        power_acc = 0.0
        while self.t < cfg["duration"] and not self.death:
            self.t += DT
            grace = cfg["duration"] - self.t <= cfg["grace"]
            mult = cfg["blackout_mult"] if self.blackout else 1.0
            for key, interval, fn in (
                ("L", cfg["square_tick"] * mult, lambda: self.patrol("L")),
                ("R", cfg["triangle_tick"] * mult, lambda: self.patrol("R")),
                ("circle", cfg["circle_tick"], self.circle),
                ("hex", cfg["hex_tick"], self.hexagon),
            ):
                if self.t >= self.next_tick[key]:
                    self.next_tick[key] += interval
                    if not grace:
                        fn()
            if self.death:
                break
            if self.intrusion_end is not None and self.t >= self.intrusion_end:
                if not grace:
                    self.death = "hexagon"
                    break
                self.intrusion_end = None
            if self.alert_end is not None and self.t >= self.alert_end:
                self.alert_end = None  # o vírus destrói uma câmera sozinho
            if self.minigame_end is not None and self.t >= self.minigame_end:
                self.minigame_end = None
            if self.busy_kind and self.t >= self.busy_until:
                self.finish()
            self.decide()
            self.closed_time += DT * (self.closed["L"] + self.closed["R"])
            power_acc += DT
            if power_acc >= 1.0:
                power_acc -= 1.0
                if not self.blackout:
                    drain = cfg["drain_base"] + cfg["drain_door"] * (self.closed["L"] + self.closed["R"])
                    drain += cfg["drain_tablet"] if self.tablet else 0
                    drain += cfg["drain_leak"] if "power_leak" in self.corrupted else 0
                    self.power = max(0.0, self.power - drain)
                    if self.power <= 0:
                        self.blackout = True
                        self.blackout_at = self.t
                        self.battery_end = self.t + cfg["battery"]
                        self.closed = {"L": False, "R": False}
                        self.tablet = False
        return self


# ----------------------------------------------------------------------------- relatório
def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--runs", type=int, default=200, help="noites simuladas por nível")
    parser.add_argument("--seed", type=int, default=1, help="primeira seed; cada noite usa seed + i")
    args = parser.parse_args()
    cfg = load_config()

    print("Noite | Sobrevive | Mortes Q/T/H     | Blackout | Gerador | Energia final* | Porta fechada")
    print("------|-----------|------------------|----------|---------|----------------|--------------")
    for n in sorted(k for k in cfg["nights"] if k > 0):
        levels = cfg["nights"][n]
        deaths, wins, blackouts, generators, power, closed = Counter(), 0, 0, 0, [], []
        for i in range(args.runs):
            night = Night(cfg, levels, random.Random(args.seed + i * 7919 + n)).run()
            if night.death:
                deaths[night.death] += 1
            else:
                wins += 1
                power.append(night.power)
            blackouts += night.blackout_at is not None
            generators += night.used_generator
            closed.append(night.closed_time)
        pct = lambda x: 100.0 * x / args.runs
        mean_power = sum(power) / len(power) if power else 0.0
        print("  %d   |   %5.1f%%  | %4.1f/%4.1f/%4.1f%%  |  %5.1f%%  | %5.1f%%  |     %5.1f%%     |   %5.0f s"
              % (n, pct(wins), pct(deaths["square"]), pct(deaths["triangle"]), pct(deaths["hexagon"]),
                 pct(blackouts), pct(generators), mean_power, sum(closed) / len(closed)))
    print("* energia média ao amanhecer, só de quem sobreviveu. Porta fechada = soma das duas portas.")


if __name__ == "__main__":
    main()
