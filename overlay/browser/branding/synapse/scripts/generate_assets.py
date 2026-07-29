#!/usr/bin/env python3
"""Generate deterministic Synapse branding assets from the transparent master."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


BRAND = Path(__file__).resolve().parents[1]
REPO = Path(__file__).resolve().parents[5]
MASTER = REPO / "assets" / "branding" / "synapse-logo.png"

INK = (244, 247, 255, 255)
NIGHT = (16, 11, 40, 255)
DEEP = (8, 6, 22, 255)
INDIGO = (50, 47, 119, 255)
CYAN = (77, 231, 245, 255)
TEAL = (70, 240, 181, 255)
VIOLET = (143, 102, 255, 255)

RESAMPLE = Image.Resampling.LANCZOS


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    name = "segoeuib.ttf" if bold else "segoeui.ttf"
    candidate = Path("C:/Windows/Fonts") / name
    try:
        return ImageFont.truetype(str(candidate), size=size)
    except OSError:
        return ImageFont.load_default()


def load_trimmed_master() -> Image.Image:
    source = Image.open(MASTER).convert("RGBA")
    alpha_box = source.getchannel("A").getbbox()
    if alpha_box is None:
        raise RuntimeError(f"Master logo has no visible pixels: {MASTER}")
    return source.crop(alpha_box)


MASTER_IMAGE = load_trimmed_master()


def brand_gradient(size: tuple[int, int], start=DEEP, end=NIGHT) -> Image.Image:
    width, height = size
    canvas = Image.new("RGBA", size)
    draw = ImageDraw.Draw(canvas)
    for y in range(height):
        t = y / max(1, height - 1)
        color = tuple(round(start[i] * (1 - t) + end[i] * t) for i in range(4))
        draw.line((0, y, width, y), fill=color)
    return canvas


def logo_on_canvas(
    size: tuple[int, int],
    *,
    scale: float = 0.82,
    center: tuple[float, float] = (0.5, 0.5),
    background: tuple[int, int, int, int] | None = None,
) -> Image.Image:
    canvas = Image.new("RGBA", size, background or (0, 0, 0, 0))
    width, height = size
    max_width = max(1, round(width * scale))
    max_height = max(1, round(height * scale))
    ratio = min(max_width / MASTER_IMAGE.width, max_height / MASTER_IMAGE.height)
    logo = MASTER_IMAGE.resize(
        (max(1, round(MASTER_IMAGE.width * ratio)), max(1, round(MASTER_IMAGE.height * ratio))),
        RESAMPLE,
    )
    x = round(width * center[0] - logo.width / 2)
    y = round(height * center[1] - logo.height / 2)
    canvas.alpha_composite(logo, (x, y))
    return canvas


def private_logo(size: tuple[int, int], *, background: bool = False) -> Image.Image:
    canvas = brand_gradient(size, DEEP, (29, 14, 67, 255)) if background else Image.new(
        "RGBA", size, (0, 0, 0, 0)
    )
    unit = min(size)
    draw = ImageDraw.Draw(canvas)
    inset = max(2, round(unit * 0.055))
    stroke = max(1, round(unit * 0.025))
    draw.rounded_rectangle(
        (inset, inset, size[0] - inset - 1, size[1] - inset - 1),
        radius=round(unit * 0.2),
        outline=VIOLET,
        width=stroke,
    )
    logo = logo_on_canvas(size, scale=0.67)
    canvas.alpha_composite(logo)
    return canvas


def document_icon(size: int, *, pdf: bool = False) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    pad = max(2, round(size * 0.13))
    fold = max(4, round(size * 0.22))
    page = [
        (pad, pad),
        (size - pad - fold, pad),
        (size - pad, pad + fold),
        (size - pad, size - pad),
        (pad, size - pad),
    ]
    draw.polygon(page, fill=(23, 22, 66, 255), outline=INDIGO)
    draw.line(
        (size - pad - fold, pad, size - pad - fold, pad + fold, size - pad, pad + fold),
        fill=CYAN,
        width=max(1, round(size * 0.025)),
    )
    if pdf:
        label_h = max(6, round(size * 0.22))
        y0 = size - pad - label_h
        draw.rounded_rectangle(
            (pad + 1, y0, size - pad - 1, size - pad - 1),
            radius=max(1, round(size * 0.025)),
            fill=(44, 38, 102, 255),
        )
        label_font = font(max(6, round(size * 0.11)), bold=True)
        text = "PDF"
        box = draw.textbbox((0, 0), text, font=label_font)
        draw.text(
            ((size - (box[2] - box[0])) / 2, y0 + (label_h - (box[3] - box[1])) / 2 - box[1]),
            text,
            font=label_font,
            fill=INK,
        )
    else:
        mark = logo_on_canvas((size, size), scale=0.34, center=(0.5, 0.57))
        canvas.alpha_composite(mark)
    return canvas


def window_icon(size: int, *, plus: bool) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    pad = max(2, round(size * 0.11))
    stroke = max(1, round(size * 0.05))
    draw.rounded_rectangle(
        (pad, pad, size - pad - 1, size - pad - 1),
        radius=max(2, round(size * 0.1)),
        fill=(20, 19, 58, 255),
        outline=CYAN,
        width=stroke,
    )
    draw.line((pad, round(size * 0.3), size - pad, round(size * 0.3)), fill=INDIGO, width=stroke)
    if plus:
        center = round(size * 0.53)
        extent = round(size * 0.14)
        draw.line((center - extent, center, center + extent, center), fill=TEAL, width=stroke)
        draw.line((center, center - extent, center, center + extent), fill=TEAL, width=stroke)
    else:
        logo = logo_on_canvas((size, size), scale=0.38, center=(0.5, 0.61))
        canvas.alpha_composite(logo)
    return canvas


def save_png(image: Image.Image, relative: str, *, mode: str = "RGBA") -> None:
    path = BRAND / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    image.convert(mode).save(path, format="PNG", optimize=True)


def save_ico(image: Image.Image, relative: str, sizes: list[int]) -> None:
    path = BRAND / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGBA").save(path, format="ICO", sizes=[(size, size) for size in sizes])


def save_icns(image: Image.Image, relative: str) -> None:
    path = BRAND / relative
    image.convert("RGBA").resize((1024, 1024), RESAMPLE).save(path, format="ICNS")


def create_about() -> Image.Image:
    canvas = brand_gradient((300, 236), (26, 24, 72, 255), DEEP)
    halo = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    hd.ellipse((36, -80, 264, 148), fill=(65, 221, 239, 30))
    canvas.alpha_composite(halo)
    logo = logo_on_canvas((150, 150), scale=0.84)
    canvas.alpha_composite(logo, (75, 8))
    draw = ImageDraw.Draw(canvas)
    label = "SYNAPSE"
    face = font(31, bold=True)
    box = draw.textbbox((0, 0), label, font=face)
    draw.text(((300 - (box[2] - box[0])) / 2, 174), label, font=face, fill=INK)
    return canvas


def create_background(size: tuple[int, int], *, installer: bool = False) -> Image.Image:
    canvas = brand_gradient(size, (6, 6, 20, 255), (30, 26, 78, 255))
    draw = ImageDraw.Draw(canvas, "RGBA")
    width, height = size
    for radius, alpha in ((0.42, 22), (0.28, 30), (0.16, 34)):
        r = round(min(size) * radius)
        cx, cy = round(width * 0.72), round(height * 0.35)
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(77, 231, 245, alpha))
    logo_size = round(min(size) * (0.58 if installer else 0.45))
    logo = logo_on_canvas((logo_size, logo_size), scale=0.84)
    canvas.alpha_composite(logo, (round(width * 0.1), round((height - logo_size) / 2)))
    face = font(max(24, round(height * 0.1)), bold=True)
    draw.text(
        (round(width * 0.46), round(height * 0.37)),
        "SYNAPSE",
        font=face,
        fill=INK,
        stroke_width=max(1, round(height * 0.002)),
        stroke_fill=(25, 22, 69, 255),
    )
    subface = font(max(14, round(height * 0.032)))
    draw.text(
        (round(width * 0.465), round(height * 0.51)),
        "Private by design",
        font=subface,
        fill=(155, 242, 245, 255),
    )
    return canvas


def create_visual_tile(size: int, *, private: bool) -> Image.Image:
    canvas = brand_gradient(
        (size, size),
        (9, 7, 28, 255) if private else DEEP,
        (42, 20, 83, 255) if private else (37, 35, 93, 255),
    )
    logo = private_logo((size, size)) if private else logo_on_canvas((size, size), scale=0.73)
    canvas.alpha_composite(logo)
    return canvas


def create_wizard_header(rtl: bool = False) -> Image.Image:
    canvas = brand_gradient((150, 57), DEEP, (32, 29, 82, 255))
    logo = logo_on_canvas((52, 52), scale=0.82)
    x = 4 if rtl else 94
    canvas.alpha_composite(logo, (x, 2))
    return canvas.convert("RGB")


def create_wizard_watermark() -> Image.Image:
    canvas = brand_gradient((164, 314), DEEP, (32, 29, 82, 255))
    logo = logo_on_canvas((150, 190), scale=0.82)
    canvas.alpha_composite(logo, (7, 20))
    draw = ImageDraw.Draw(canvas)
    label = "SYNAPSE"
    face = font(21, bold=True)
    box = draw.textbbox((0, 0), label, font=face)
    draw.text(((164 - (box[2] - box[0])) / 2, 238), label, font=face, fill=INK)
    draw.line((35, 276, 129, 276), fill=CYAN, width=2)
    return canvas.convert("RGB")


def write_manifest() -> None:
    files = []
    ignored = {"README.md", "ASSET-MANIFEST.json"}
    for path in sorted(p for p in BRAND.rglob("*") if p.is_file() and p.name not in ignored):
        relative = path.relative_to(BRAND).as_posix()
        entry: dict[str, object] = {
            "path": relative,
            "bytes": path.stat().st_size,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        }
        try:
            with Image.open(path) as image:
                entry.update(
                    {
                        "format": image.format,
                        "width": image.width,
                        "height": image.height,
                        "mode": image.mode,
                        "frames": getattr(image, "n_frames", 1),
                    }
                )
        except Exception:
            pass
        files.append(entry)
    payload = {
        "schema": 1,
        "source": MASTER.relative_to(REPO).as_posix(),
        "sourceSha256": hashlib.sha256(MASTER.read_bytes()).hexdigest(),
        "files": files,
    }
    (BRAND / "ASSET-MANIFEST.json").write_text(
        json.dumps(payload, indent=2) + "\n", encoding="utf-8", newline="\n"
    )


def main() -> None:
    for size in (16, 22, 24, 32, 48, 64, 128, 256):
        save_png(logo_on_canvas((size, size), scale=0.88), f"default{size}.png")

    save_png(logo_on_canvas((192, 192), scale=0.88), "content/about-logo.png")
    save_png(logo_on_canvas((384, 384), scale=0.88), "content/about-logo@2x.png")
    save_png(private_logo((192, 192)), "content/about-logo-private.png")
    save_png(private_logo((384, 384)), "content/about-logo-private@2x.png")
    save_png(create_about(), "content/about.png", mode="RGB")

    app_ico = logo_on_canvas((1024, 1024), scale=0.88)
    private_ico = private_logo((1024, 1024))
    document = document_icon(1024)
    document_pdf = document_icon(1024, pdf=True)
    save_ico(app_ico, "firefox.ico", [16, 24, 32, 48, 64, 128, 256])
    save_ico(app_ico, "firefox64.ico", [16, 24, 32, 48, 64])
    save_ico(document, "document.ico", [16, 24, 32, 48, 64, 128, 256])
    save_ico(document_pdf, "document_pdf.ico", [16, 24, 32, 48, 64, 128, 256])
    save_ico(window_icon(256, plus=True), "newtab.ico", [16, 24, 32])
    save_ico(window_icon(256, plus=False), "newwindow.ico", [16, 24, 32])
    save_ico(private_ico, "pbmode.ico", [16, 24, 32, 48, 64, 128, 256])

    save_icns(app_ico, "firefox.icns")
    save_icns(document, "document.icns")
    save_icns(app_ico, "disk.icns")

    save_png(create_background((1440, 880)), "background.png")
    create_wizard_header().save(BRAND / "wizHeader.bmp", format="BMP")
    create_wizard_header(rtl=True).save(BRAND / "wizHeaderRTL.bmp", format="BMP")
    create_wizard_watermark().save(BRAND / "wizWatermark.bmp", format="BMP")

    (BRAND / "stubinstaller").mkdir(parents=True, exist_ok=True)
    create_background((1344, 822), installer=True).convert("RGB").save(
        BRAND / "stubinstaller" / "bgstub.jpg", format="JPEG", quality=94, optimize=True
    )

    save_png(create_visual_tile(300, private=False), "VisualElements_150.png")
    save_png(create_visual_tile(142, private=False), "VisualElements_70.png")
    save_png(create_visual_tile(300, private=True), "PrivateBrowsing_150.png")
    save_png(create_visual_tile(142, private=True), "PrivateBrowsing_70.png")

    msix = {
        "Document44x44.png": document_icon(44),
        "LargeTile.scale-200.png": create_visual_tile(620, private=False),
        "MedTile.scale-200.png": create_visual_tile(300, private=False),
        "SmallTile.scale-200.png": create_visual_tile(142, private=False),
        "Square150x150Logo.scale-200.png": create_visual_tile(300, private=False),
        "Square44x44Logo.altform-lightunplated_targetsize-256.png": logo_on_canvas(
            (256, 256), scale=0.88
        ),
        "Square44x44Logo.altform-unplated_targetsize-256.png": logo_on_canvas(
            (256, 256), scale=0.88
        ),
        "Square44x44Logo.scale-200.png": create_visual_tile(88, private=False),
        "Square44x44Logo.targetsize-256.png": logo_on_canvas((256, 256), scale=0.88),
        "StoreLogo.scale-200.png": create_visual_tile(100, private=False),
    }
    wide = brand_gradient((620, 300), DEEP, (37, 35, 93, 255))
    wide_logo = logo_on_canvas((250, 250), scale=0.82)
    wide.alpha_composite(wide_logo, (42, 25))
    wide_draw = ImageDraw.Draw(wide)
    wide_draw.text((288, 112), "SYNAPSE", font=font(47, bold=True), fill=INK)
    msix["Wide310x150Logo.scale-200.png"] = wide
    for name, image in msix.items():
        save_png(image, f"msix/Assets/{name}")

    write_manifest()
    print(f"Generated Synapse branding in {BRAND}")


if __name__ == "__main__":
    main()
