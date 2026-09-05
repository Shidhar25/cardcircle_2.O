#!/usr/bin/env python3
"""Install the card-background art into `assets/card-bg/` under bank names.

Source art in `bank_card_svg_files/` is numbered and described by appearance
(`card_03_orange_swoosh.png`), not by issuer. The mapping below is positional
— `card_NN` takes the NNth name in the agreed list — which the descriptive
names corroborate: 05 is `american_express_green`, 17 is `black_one`
(OneCard), 04 is `blue_keyhole` (SBI's logo), 03 is `orange_swoosh` (ICICI).

Also normalises geometry. The source art sits on a 1500x1000 canvas with a
soft drop shadow painted around the card — roughly 60-69px of semi-transparent
pixels on the left, 30-52px on top and up to 72px below, and the amount varies
per bank. Rendered with BoxFit.cover that shadow is scaled into the frame as
padding, so every card lands at a different offset and size.

Trimming at an alpha *threshold* (rather than any non-zero alpha) discards the
shadow and keeps only the card's solid body, so the file *is* the card and all
of them line up. The app draws its own shadow, so the baked-in one is
unwanted anyway — keeping it would double up.

Copies rather than moves, so the numbered originals stay put as the source of
truth. Re-running re-derives everything from source, which is what you want
after the art is updated.

Requires Pillow (`pip install Pillow`).

Usage:
    python tools/rename_card_bg.py [--dry-run] [--no-trim]
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover - dev tooling only
    Image = None

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIR = ROOT / "bank_card_svg_files"
DEST_DIR = ROOT / "assets" / "card-bg"

# Position in the source set (card_NN) -> destination filename stem.
BANKS_IN_ORDER: list[str] = [
    "axis_bank",  # 01 red geometric
    "hdfc_bank",  # 02 blue geometric
    "icici_bank",  # 03 orange swoosh
    "sbi",  # 04 blue keyhole
    "american_express",  # 05 american express green
    "citi",  # 06 blue dotted
    "kotak_mahindra_bank",  # 07 red infinity
    "indusind_bank",  # 08 dark red wave
    "yes_bank",  # 09 blue diagonal
    "rbl_bank",  # 10 navy circle
    "idfc_first_bank",  # 11 red diagonal
    "standard_chartered",  # 12 teal wave
    "hsbc_india",  # 13 black red dots
    "bank_of_baroda",  # 14 orange leaf
    "au_small_finance_bank",  # 15 purple dotted
    "federal_bank",  # 16 blue streak
    "onecard",  # 17 black one
    "canara_bank",  # 18 blue triangles
    "punjab_national_bank",  # 19 red gold stripe
    "union_bank_of_india",  # 20 blue minimal diagonal
    "indian_bank",  # 21 blue mandala
]

EXT = ".png"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print what would change without touching the filesystem",
    )
    parser.add_argument(
        "--no-trim",
        action="store_true",
        help="copy verbatim instead of trimming to the card body",
    )
    parser.add_argument(
        "--alpha-threshold",
        type=int,
        default=200,
        metavar="N",
        help=(
            "pixels below this alpha (0-255) count as shadow and are trimmed "
            "away; lower it to keep more of the soft edge (default: 200)"
        ),
    )
    args = parser.parse_args()

    trim = not args.no_trim
    if trim and Image is None:
        print(
            "error: Pillow is required to trim margins. Install it with "
            "`pip install Pillow`, or pass --no-trim to copy verbatim.",
            file=sys.stderr,
        )
        return 1

    if not SOURCE_DIR.is_dir():
        print(f"error: {SOURCE_DIR} does not exist", file=sys.stderr)
        return 1

    sources = sorted(SOURCE_DIR.glob(f"card_*{EXT}"))
    if len(sources) != len(BANKS_IN_ORDER):
        print(
            f"error: found {len(sources)} source images but the mapping "
            f"expects {len(BANKS_IN_ORDER)}. The positional mapping is only "
            f"valid when the counts match — update BANKS_IN_ORDER.",
            file=sys.stderr,
        )
        return 1

    if not args.dry_run:
        DEST_DIR.mkdir(parents=True, exist_ok=True)

    copied = []
    for src, stem in zip(sources, BANKS_IN_ORDER):
        dst = DEST_DIR / f"{stem}{EXT}"
        note = ""

        if trim:
            with Image.open(src) as im:
                rgba = im.convert("RGBA")
                # Threshold the alpha first: the plain bounding box would
                # include the drop shadow, whose faintest pixels reach the
                # canvas edge and so trim nothing useful.
                alpha = rgba.getchannel("A")
                solid = alpha.point(
                    lambda v: 255 if v >= args.alpha_threshold else 0
                )
                box = solid.getbbox() or alpha.getbbox()
                if box and box != (0, 0, rgba.width, rgba.height):
                    trimmed = rgba.crop(box)
                    note = (
                        f"  (trimmed {rgba.width}x{rgba.height}"
                        f" -> {trimmed.width}x{trimmed.height})"
                    )
                else:
                    trimmed = rgba
                if not args.dry_run:
                    trimmed.save(dst)
        elif not args.dry_run:
            shutil.copy2(src, dst)

        copied.append(f"{src.name}  ->  {dst.name}{note}")

    verb = "would install" if args.dry_run else "installed"
    print(f"{verb}: {len(copied)}")
    for line in copied:
        print(f"  {line}")

    # Anything left in the destination that the mapping didn't write is stale
    # art from an earlier source set, and would silently go unused.
    if not args.dry_run:
        expected = {f"{s}{EXT}" for s in BANKS_IN_ORDER}
        stale = sorted(
            p.name for p in DEST_DIR.glob(f"*{EXT}") if p.name not in expected
        )
        if stale:
            print(f"\nstale files not in the mapping: {len(stale)}")
            for name in stale:
                print(f"  {name}")

        total = sum(p.stat().st_size for p in DEST_DIR.glob(f"*{EXT}"))
        print(f"\nassets/card-bg/ now {total / 1_048_576:.1f} MB")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
