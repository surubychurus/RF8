"""Genera los íconos PLACEHOLDER de la app (todas las variantes).

Reemplazar por los diseños finales: o bien editar este script para que parta
de un PNG del logo real, o bien pisar directamente los archivos generados.

Uso:  python3 tool/generate_icons.py   (requiere Pillow)
"""
import json
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf"

# id, fondo (arriba, abajo), color texto
VARIANTS = {
    "Default": ((0x16, 0x16, 0x1A), (0x0B, 0x0B, 0x0C), (0xE1, 0x06, 0x00)),
    "Night": ((0x00, 0x00, 0x00), (0x00, 0x00, 0x00), (0xF5, 0xF5, 0xF5)),
    "Gold": ((0x2A, 0x22, 0x10), (0x0B, 0x0B, 0x0C), (0xE8, 0xC0, 0x5A)),
    "Neon": ((0x0A, 0x1F, 0x1A), (0x05, 0x05, 0x10), (0x39, 0xFF, 0x9E)),
    "Light": ((0xFF, 0xFF, 0xFF), (0xEC, 0xEC, 0xEE), (0x0B, 0x0B, 0x0C)),
    "Fire": ((0xFF, 0x7A, 0x00), (0xC4, 0x00, 0x00), (0xFF, 0xFF, 0xFF)),
}

ANDROID_SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}


def render(size, top, bottom, fg, rounded):
    img = Image.new("RGBA", (size, size))
    grad = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / max(size - 1, 1)
        grad.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    bg = grad.resize((size, size))
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    if rounded:
        d.rounded_rectangle((0, 0, size - 1, size - 1), radius=int(size * 0.22), fill=255)
    else:
        d.rectangle((0, 0, size, size), fill=255)
    img.paste(bg, (0, 0), mask)

    draw = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT, int(size * 0.36))
    text = "RF8"
    box = draw.textbbox((0, 0), text, font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    draw.text(((size - w) / 2 - box[0], (size - h) / 2 - box[1]), text, font=font, fill=fg)
    return img


def main():
    previews = os.path.join(ROOT, "assets", "app_icons")
    os.makedirs(previews, exist_ok=True)
    res = os.path.join(ROOT, "android", "app", "src", "main", "res")
    xcassets = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets")

    for vid, (top, bottom, fg) in VARIANTS.items():
        # Vista previa dentro de la app
        render(512, top, bottom, fg, rounded=False).save(os.path.join(previews, f"{vid.lower()}.png"))

        # Android: el principal pisa ic_launcher, el resto ic_launcher_<id>
        name = "ic_launcher" if vid == "Default" else f"ic_launcher_{vid.lower()}"
        for density, px in ANDROID_SIZES.items():
            folder = os.path.join(res, f"mipmap-{density}")
            os.makedirs(folder, exist_ok=True)
            render(px, top, bottom, fg, rounded=True).save(os.path.join(folder, f"{name}.png"))

        # iOS: 1024x1024 sin transparencia (iOS aplica la máscara)
        set_name = "AppIcon" if vid == "Default" else f"AppIcon-{vid}"
        folder = os.path.join(xcassets, f"{set_name}.appiconset")
        if vid == "Default" and os.path.isdir(folder):
            for f in os.listdir(folder):
                os.remove(os.path.join(folder, f))
        os.makedirs(folder, exist_ok=True)
        render(1024, top, bottom, fg, rounded=False).convert("RGB").save(os.path.join(folder, "icon.png"))
        with open(os.path.join(folder, "Contents.json"), "w") as f:
            json.dump(
                {
                    "images": [
                        {"filename": "icon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}
                    ],
                    "info": {"author": "xcode", "version": 1},
                },
                f,
                indent=2,
            )


if __name__ == "__main__":
    main()
