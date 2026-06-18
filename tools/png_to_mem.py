from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "rom"

ASSETS = {
    "dino_default": ("assets/img/dino/default.png", (66, 70)),
    "dino_left": ("assets/img/dino/left.png", (66, 70)),
    "dino_right": ("assets/img/dino/right.png", (66, 70)),
    "dino_dead": ("assets/img/dino/dead.png", (66, 70)),
    "dino_duck_left": ("assets/img/dino/DuckLeft.png", (88, 45)),
    "dino_duck_right": ("assets/img/dino/DuckRight.png", (88, 45)),
    "cactus_small_a": ("assets/img/cactus/smallA.png", (26, 53)),
    "cactus_small_b": ("assets/img/cactus/smallB.png", (51, 53)),
    "cactus_small_c": ("assets/img/cactus/smallC.png", (77, 53)),
    "cactus_large_a": ("assets/img/cactus/largeA.png", (38, 75)),
    "cactus_large_b": ("assets/img/cactus/largeB.png", (75, 75)),
    "cactus_large_c": ("assets/img/cactus/largeC.png", (113, 75)),
    "ptero_up": ("assets/img/pterosaur/PterosaurUp.png", (69, 60)),
    "ptero_down": ("assets/img/pterosaur/PterosaurDown.png", (69, 60)),
    "cloud": ("assets/img/others/cloud.png", (69, 20)),
    "ground_a": ("assets/img/others/groundA.png", (900, 20)),
    "ground_b": ("assets/img/others/groundB.png", (900, 20)),
    "moon": ("assets/img/others/moonA.png", (30, 60)),
}


def encode_pixel(r, g, b, a):
    if a < 128:
        return 0

    # The source sprites contain transparent pixels, dark foreground pixels,
    # and a few near-white matte pixels from the browser sprite sheet. Treat
    # the matte as transparent and keep the visible artwork as a hard mask.
    if r >= 220 and g >= 220 and b >= 220:
        return 0

    return 1


def convert(name, src, size):
    image = Image.open(ROOT / src).convert("RGBA").resize(size, Image.Resampling.NEAREST)
    values = [format(encode_pixel(*pixel), "x") for pixel in image.getdata()]
    (OUT_DIR / f"{name}.mem").write_text("\n".join(values) + "\n", encoding="ascii")
    print(f"{name:16s} {size[0]}x{size[1]} -> {len(values)} pixels")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, (src, size) in ASSETS.items():
        convert(name, src, size)


if __name__ == "__main__":
    main()
