#!/usr/bin/env python3
"""Generate the 1024x1024 MotoSpeedy app icon."""

from __future__ import annotations

import pathlib

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUTPUT = (
    ROOT
    / "cursorSpeedometer"
    / "Resources"
    / "Assets.xcassets"
    / "AppIcon.appiconset"
    / "AppIcon-1024.png"
)

SIZE = 1024
BLACK = (0, 0, 0)
FACE = (38, 38, 38)
RED = (255, 36, 36)
WHITE = (245, 245, 245)

FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Black.ttf",
    "/Library/Fonts/Arial Bold.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
]


def font_path() -> str | None:
    for candidate in FONT_CANDIDATES:
        if pathlib.Path(candidate).exists():
            return candidate
    return None


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    path = font_path()
    if path is None:
        return ImageFont.load_default()
    try:
        index = 1 if path.endswith(".ttc") else 0
        return ImageFont.truetype(path, size=size, index=index)
    except OSError:
        return ImageFont.truetype(path, size=size)


def text_width(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont | ImageFont.ImageFont) -> float:
    bbox = draw.textbbox((0, 0), text, font=font)
    return bbox[2] - bbox[0]


def fit_font(
    draw: ImageDraw.ImageDraw,
    text: str,
    max_width: float,
    min_size: int = 200,
    max_size: int = 700,
) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for size in range(max_size, min_size, -2):
        font = load_font(size)
        if text_width(draw, text, font) <= max_width:
            return font
    return load_font(min_size)


def centered_x(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont | ImageFont.ImageFont) -> float:
    return (SIZE - text_width(draw, text, font)) / 2


def main() -> None:
    image = Image.new("RGB", (SIZE, SIZE), BLACK)
    draw = ImageDraw.Draw(image)

    margin = 36
    brand_band = 112
    panel_bottom = SIZE - brand_band
    draw.rounded_rectangle(
        (margin, margin, SIZE - margin, panel_bottom),
        radius=68,
        fill=FACE,
    )

    panel_width = SIZE - (margin * 2)
    speed_font = fit_font(draw, "42", panel_width * 0.96, max_size=760)
    speed_size = getattr(speed_font, "size", 500)
    unit_font = load_font(max(64, int(speed_size * 0.20)))
    brand_font = load_font(108)

    speed_stroke = 5
    unit_stroke = 2
    speed_bbox = draw.textbbox((0, 0), "42", font=speed_font, stroke_width=speed_stroke)
    unit_bbox = draw.textbbox((0, 0), "mph", font=unit_font, stroke_width=unit_stroke)
    speed_ink_h = speed_bbox[3] - speed_bbox[1]
    unit_ink_h = unit_bbox[3] - unit_bbox[1]
    speed_unit_gap = 4
    block_h = speed_ink_h + unit_ink_h + speed_unit_gap
    panel_h = panel_bottom - margin
    speed_y = margin + (panel_h - block_h) / 2 - 109

    draw.text(
        (centered_x(draw, "42", speed_font), speed_y),
        "42",
        fill=RED,
        font=speed_font,
        stroke_width=speed_stroke,
        stroke_fill=RED,
    )

    unit_y = speed_y + speed_bbox[3] + speed_unit_gap
    draw.text(
        (centered_x(draw, "mph", unit_font), unit_y),
        "mph",
        fill=RED,
        font=unit_font,
        stroke_width=unit_stroke,
        stroke_fill=RED,
    )

    draw.text(
        (centered_x(draw, "MotoSpeedy", brand_font), SIZE - 126),
        "MotoSpeedy",
        fill=WHITE,
        font=brand_font,
    )

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUTPUT, format="PNG", optimize=True)
    print(f"Wrote {OUTPUT} ({image.size[0]}x{image.size[1]})")


if __name__ == "__main__":
    main()
