"""Gera o ícone (512x512) e a thumbnail (1920x1080) da página do jogo no Roblox (PLANEJAMENTO 9).

As quatro formas nas cores do jogo sobre preto, com uma faixa de estática atravessando. As cores vêm de
src/client/EnemyModels.luau (inimigos) e src/client/ui/UiKit.luau (verde do título): mudar a cor lá muda
a arte aqui. As proporções das formas seguem os modelos 3D (olhos do Quadrado, Hexágono de vértice a vértice).

Uso: python tools/make_store_art.py   (grava em assets/publicacao/; precisa de Pillow)
"""

import math
import random
import re
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "publicacao"
SS = 4  # supersampling: desenha 4x maior e reduz, para bordas lisas
SEED = 7  # estática reproduzível

# Proporções do Quadrado, iguais às de EnemyModels.luau
EYE_SIZE = 0.225
EYE_OFFSET_X = 0.275
EYE_OFFSET_Y = 0.175
HEX_HEIGHT = math.sqrt(3) / 2  # altura do Hexágono de vértice a vértice = 1

FONT_CANDIDATES = [
    Path("C:/Windows/Fonts/consolab.ttf"),
    Path("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"),
    Path("/System/Library/Fonts/Menlo.ttc"),
]


def read_colors(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    pattern = r"(\w+) = Color3\.fromRGB\((\d+), (\d+), (\d+)\)"
    return {name: (int(r), int(g), int(b)) for name, r, g, b in re.findall(pattern, text)}


ENEMY = read_colors(ROOT / "src" / "client" / "EnemyModels.luau")
UI = read_colors(ROOT / "src" / "client" / "ui" / "UiKit.luau")


def shape_height(kind: str, size: float) -> float:
    return size * HEX_HEIGHT if kind == "hexagon" else size


def draw_shape(draw: ImageDraw.ImageDraw, kind: str, cx: float, bottom: float, size: float) -> None:
    """Forma de `size` de largura com o centro da base em (cx, bottom)."""
    h = size / 2
    height = shape_height(kind, size)
    cy = bottom - height / 2
    if kind == "square":
        draw.rectangle([cx - h, cy - h, cx + h, cy + h], fill=ENEMY["square"])
        eye = size * EYE_SIZE / 2
        for dx in (-1, 1):
            ex, ey = cx + dx * EYE_OFFSET_X * size, cy - EYE_OFFSET_Y * size
            draw.rectangle([ex - eye, ey - eye, ex + eye, ey + eye], fill=ENEMY["eyes"])
    elif kind == "triangle":
        draw.polygon([(cx, cy - h), (cx + h, cy + h), (cx - h, cy + h)], fill=ENEMY["triangle"])
    elif kind == "circle":
        draw.ellipse([cx - h, cy - h, cx + h, cy + h], fill=ENEMY["circle"])
    else:
        points = [(cx + h * math.cos(math.radians(a)), cy + h * math.sin(math.radians(a))) for a in range(0, 360, 60)]
        draw.polygon(points, fill=ENEMY["hexagon"])


def shapes_layer(canvas: tuple, shapes: list) -> Image.Image:
    """Camada RGBA transparente com as formas, desenhada em SS e reduzida."""
    w, h = canvas
    layer = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for kind, cx, bottom, size in shapes:
        draw_shape(draw, kind, cx * SS, bottom * SS, size * SS)
    return layer.resize((w, h), Image.LANCZOS)


def with_alpha(layer: Image.Image, factor: float) -> Image.Image:
    r, g, b, a = layer.split()
    a = a.point(lambda v: int(v * factor))
    return Image.merge("RGBA", (r, g, b, a))


def glow(base: Image.Image, layer: Image.Image, radius: float, strength: float) -> None:
    """Brilho em volta das formas: a própria camada borrada, por baixo."""
    base.alpha_composite(with_alpha(layer.filter(ImageFilter.GaussianBlur(radius)), strength))


def reflection(base: Image.Image, layer: Image.Image, floor_y: int, depth: int, strength: float) -> None:
    """Reflexo no chão: a camada espelhada em torno de floor_y, sumindo em `depth` px."""
    w, h = base.size
    flipped = layer.transpose(Image.FLIP_TOP_BOTTOM)
    offset = 2 * floor_y - h  # o espelho de y é 2*floor_y - y; na imagem virada, y vira h - y
    top = max(0, -offset)
    region = flipped.crop((0, top, w, h - max(0, offset)))
    fade = Image.new("L", region.size, 0)
    fade_draw = ImageDraw.Draw(fade)
    start = floor_y - max(0, offset)
    for y in range(depth):
        fade_draw.line([(0, start + y), (w, start + y)], fill=int(255 * strength * (1 - y / depth)))
    r, g, b, a = region.split()
    region = Image.merge("RGBA", (r, g, b, ImageChops.multiply(a, fade)))
    base.alpha_composite(region, dest=(0, max(0, offset)))


def static_band(image: Image.Image, y0: int, y1: int, shift: int, rng: random.Random) -> None:
    """A "linha de estática": a faixa desliza para o lado, separa os canais e ganha ruído em riscos horizontais."""
    w = image.width
    band = image.crop((0, y0, w, y1)).convert("RGB")
    band = ImageChops.offset(band, shift, 0)
    r, g, b = band.split()
    band = Image.merge("RGB", (ImageChops.offset(r, shift // 2, 0), g, ImageChops.offset(b, -shift // 2, 0)))
    streak_w = max(1, w // 12)
    noise = Image.frombytes("L", (streak_w, y1 - y0), rng.randbytes(streak_w * (y1 - y0)))
    noise = noise.resize((w, y1 - y0), Image.NEAREST).convert("RGB")
    band = Image.blend(band, noise, 0.35)
    image.paste(band, (0, y0))


def scanlines(image: Image.Image, spacing: int, darkness: float) -> None:
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for y in range(0, image.height, spacing):
        draw.line([(0, y), (image.width, y)], fill=(0, 0, 0, int(255 * darkness)))
    image.alpha_composite(overlay)


def vignette(image: Image.Image, strength: float) -> None:
    mask = Image.radial_gradient("L").resize(image.size, Image.BILINEAR)
    mask = mask.point(lambda v: int(min(255, v * 1.15) * strength))
    black = Image.new("RGBA", image.size, (0, 0, 0, 255))
    image.paste(black, (0, 0), mask)


def font(size: int) -> ImageFont.FreeTypeFont:
    for path in FONT_CANDIDATES:
        if path.exists():
            return ImageFont.truetype(str(path), size)
    raise SystemExit("Nenhuma fonte monoespaçada encontrada; ajuste FONT_CANDIDATES.")


def title(image: Image.Image, text: str, cy: int, size: int) -> None:
    """Título verde com as bordas separadas em vermelho e ciano, como no glitch do menu."""
    w, h = image.size
    layer = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    face = font(size * SS)
    box = draw.textbbox((0, 0), text, font=face)
    x = (w * SS - (box[2] - box[0])) / 2 - box[0]
    y = cy * SS - (box[3] - box[1]) / 2 - box[1]
    split = 4 * SS
    draw.text((x - split, y), text, font=face, fill=UI["danger"] + (150,))
    draw.text((x + split, y), text, font=face, fill=UI["hacker"] + (150,))
    draw.text((x, y), text, font=face, fill=UI["ok"] + (255,))
    layer = layer.resize((w, h), Image.LANCZOS)
    glow(image, layer, size * 0.18, 0.5)
    image.alpha_composite(layer)


def compose(size: tuple, shapes: list, glow_radius: float) -> tuple:
    image = Image.new("RGBA", size, (0, 0, 0, 255))
    layer = shapes_layer(size, shapes)
    glow(image, layer, glow_radius, 0.75)
    image.alpha_composite(layer)
    return image, layer


def make_icon(path: Path) -> None:
    # 2x2: físicos em cima (Quadrado à esquerda, Triângulo à direita, como as portas), hackers embaixo.
    # Margem larga: o Roblox arredonda os cantos do ícone.
    w = h = 512
    s = 150
    shapes = [
        ("square", 150, 232, s),
        ("triangle", 362, 232, s),
        ("circle", 150, 440, s),
        ("hexagon", 362, 440 - (s - s * HEX_HEIGHT) / 2, s),
    ]
    image, _ = compose((w, h), shapes, 18)
    rng = random.Random(SEED)
    static_band(image, 180, 214, 14, rng)
    scanlines(image, 4, 0.18)
    vignette(image, 0.55)
    image.convert("RGB").save(path)


def make_thumbnail(path: Path) -> None:
    w, h = 1920, 1080
    s = 290
    floor = 820
    # Mesma leitura da sala: Quadrado na ponta esquerda, Triângulo na direita, os hackers no meio
    order = ["square", "circle", "hexagon", "triangle"]
    shapes = [(kind, 360 + i * 400, floor, s) for i, kind in enumerate(order)]
    image = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    layer = shapes_layer((w, h), shapes)
    reflection(image, layer, floor + 6, 190, 0.22)
    glow(image, layer, 30, 0.75)
    image.alpha_composite(layer)
    rng = random.Random(SEED)
    # A faixa passa abaixo dos olhos do Quadrado: eles são a marca dele
    static_band(image, 722, 768, 36, rng)
    vignette(image, 0.6)
    title(image, "FIVE NIGHTS AT GEOMETRY", 245, 132)  # depois da vinheta, para o verde não apagar
    scanlines(image, 4, 0.16)
    image.convert("RGB").save(path)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    make_icon(OUT / "icon_512.png")
    make_thumbnail(OUT / "thumbnail_1920x1080.png")
    print(f"gravado em {OUT}")


if __name__ == "__main__":
    main()
