"""Generate the Windows/project icons from the source artwork."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
BRAND_DIR = ROOT / "assets" / "branding"
SOURCE = BRAND_DIR / "cisco_game_icon_source.png"

ICO_SIZES = (16, 24, 32, 48, 64, 128, 256)
ICON_BACKGROUND = (255, 255, 255, 255)


def contain(image: Image.Image, box: int) -> Image.Image:
    ratio = min(box / image.width, box / image.height)
    size = (max(1, round(image.width * ratio)), max(1, round(image.height * ratio)))
    return image.resize(size, Image.Resampling.LANCZOS)


def square_icon(source: Image.Image, size: int, inner: int) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), ICON_BACKGROUND)
    scaled = contain(source, inner)
    position = ((size - scaled.width) // 2, (size - scaled.height) // 2)
    canvas.alpha_composite(scaled, position)
    return canvas


def main() -> None:
    BRAND_DIR.mkdir(parents=True, exist_ok=True)
    source = Image.open(SOURCE).convert("RGBA")
    bbox = source.getbbox()
    if bbox is not None:
        source = source.crop(bbox)

    project_icon = square_icon(source, 512, 480)
    project_icon.save(BRAND_DIR / "cisco_game_icon.png")

    windows_icon = square_icon(source, 256, 240)
    windows_icon.save(
        BRAND_DIR / "cisco_game.ico",
        format="ICO",
        sizes=[(size, size) for size in ICO_SIZES],
    )

    for path in (BRAND_DIR / "cisco_game_icon.png", BRAND_DIR / "cisco_game.ico"):
        print(f"{path.name}: {path.stat().st_size} bytes")


if __name__ == "__main__":
    main()
