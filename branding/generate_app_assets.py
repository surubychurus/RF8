"""Genera los logos que usan las apps y el ícono de la app de administración.

  apps/*/assets/branding/logo.png       emblema en tarjeta naranja (cuadrado)
  apps/*/assets/branding/logo_full.png  logo completo en tarjeta naranja
  apps/admin: íconos de Android/iOS (azul con emblema naranja + "ADMIN")

Uso: python3 branding/generate_app_assets.py   (requiere Pillow)
"""
import json
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ORANGE = (0xEE, 0x6E, 0x31)
NAVY = (0x10, 0x1A, 0x33)
FONTS = [
    "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
]


def mask(name):
    return Image.open(os.path.join(HERE, name)).convert("L")


def card(shape, width, height, pad, radius, bg=ORANGE, fg=NAVY):
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    m = Image.new("L", (width, height), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, width - 1, height - 1), radius=radius, fill=255)
    img.paste(Image.new("RGBA", (width, height), bg + (255,)), (0, 0), m)
    w, h = width - 2 * pad, height - 2 * pad
    s = shape.copy()
    s.thumbnail((w, h), Image.LANCZOS)
    img.paste(Image.new("RGBA", s.size, fg + (255,)), ((width - s.width) // 2, (height - s.height) // 2), s)
    return img


def admin_icon(size, rounded):
    img = Image.new("RGBA", (size, size))
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    if rounded:
        d.rounded_rectangle((0, 0, size - 1, size - 1), radius=int(size * 0.22), fill=255)
    else:
        d.rectangle((0, 0, size, size), fill=255)
    img.paste(Image.new("RGBA", (size, size), NAVY + (255,)), (0, 0), m)
    side = int(size * 0.46)
    em = mask("emblem_mask.png").resize((side, side), Image.LANCZOS)
    img.paste(Image.new("RGBA", (side, side), ORANGE + (255,)), ((size - side) // 2, int(size * 0.17)), em)
    font_path = next((f for f in FONTS if os.path.exists(f)), None)
    font = ImageFont.truetype(font_path, int(size * 0.13)) if font_path else ImageFont.load_default()
    draw = ImageDraw.Draw(img)
    text = "ADMIN"
    b = draw.textbbox((0, 0), text, font=font)
    draw.text(((size - (b[2] - b[0])) / 2 - b[0], size * 0.72 - b[1]), text, font=font, fill=(255, 255, 255))
    return img


def main():
    emblem = mask("emblem_mask.png")
    full = mask("logo_mask.png")
    for app in ("member", "admin"):
        out = os.path.join(ROOT, "apps", app, "assets", "branding")
        os.makedirs(out, exist_ok=True)
        card(emblem, 512, 512, 96, 112).save(os.path.join(out, "logo.png"))
        fw = 1600
        fh = int(fw * full.height / full.width) + 2 * 110
        card(full, fw, fh, 110, 72).save(os.path.join(out, "logo_full.png"))

    res = os.path.join(ROOT, "apps", "admin", "android", "app", "src", "main", "res")
    for density, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        admin_icon(px, True).save(os.path.join(res, f"mipmap-{density}", "ic_launcher.png"))
    ios = os.path.join(ROOT, "apps", "admin", "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    admin_icon(1024, False).convert("RGB").save(os.path.join(ios, "icon.png"))
    with open(os.path.join(ios, "Contents.json"), "w") as f:
        json.dump({"images": [{"filename": "icon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
                   "info": {"author": "xcode", "version": 1}}, f, indent=2)
    print("ok")


if __name__ == "__main__":
    main()
