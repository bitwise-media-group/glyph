# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Generates the Glyph app icon layers as SVG on Icon Composer's 1024 pt canvas:
# a sensor disc (base and face), a glucose wave across it and the current
# reading at its centre. Strokes are outlined into filled paths, and every
# layer is a full-canvas, transparent, white SVG with no background rectangle,
# so the layers stay aligned when Icon Composer imports them. Colours, glass and
# opacity live in AppIcon.icon/icon.json, which Icon Composer owns.
#
#   python3 design/app-icon/generate.py design/app-icon/AppIcon.icon/Assets
#
# Needs skia-pathops and fonttools (pip install skia-pathops fonttools).

import math
import sys
from pathlib import Path

import pathops
from fontTools.pens.svgPathPen import SVGPathPen

CANVAS = 1024
CENTER = CANVAS / 2

BASE_RADIUS = 300  # the sensor's outer rim
FACE_RADIUS = 244  # its raised face
READING_RADIUS = 42  # the current reading, at the centre

# The wave runs off both edges, so the system mask crops it on every platform.
# It passes through the centre with a small swing, swings widest around the
# rim of the disc (more so on the right) and settles again towards the edges.
WAVE_WIDTH = 40
WAVE_CYCLES = 2.25  # full cycles per half-canvas
WAVE_SWING_CENTRE = 26
WAVE_SWING_PEAK = 190
WAVE_PEAK_AT = 0.62  # where the swing peaks, as a fraction of the half-canvas
WAVE_SWING_EDGE = 0.45  # the swing at the canvas edge, as a fraction of the peak
WAVE_BIAS_LEFT = 0.78
WAVE_BIAS_RIGHT = 1.0
WAVE_BLEED = 72
WAVE_SAMPLES = 120


def svg_d(path: pathops.Path) -> str:
    pen = SVGPathPen(None, ntos=lambda v: f"{v:.2f}".rstrip("0").rstrip("."))
    path.draw(pen)
    return pen.getCommands()


def svg(name: str, d: str) -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS}" height="{CANVAS}" '
        f'viewBox="0 0 {CANVAS} {CANVAS}">\n'
        f"  <title>{name}</title>\n"
        f'  <path fill="#FFFFFF" d="{d}"/>\n'
        f"</svg>\n"
    )


def circle(r: float) -> pathops.Path:
    # Four cubic quadrants (kappa approximation).
    cx = cy = CENTER
    k = 0.5522847498 * r
    p = pathops.Path()
    p.moveTo(cx + r, cy)
    p.cubicTo(cx + r, cy + k, cx + k, cy + r, cx, cy + r)
    p.cubicTo(cx - k, cy + r, cx - r, cy + k, cx - r, cy)
    p.cubicTo(cx - r, cy - k, cx - k, cy - r, cx, cy - r)
    p.cubicTo(cx + k, cy - r, cx + r, cy - k, cx + r, cy)
    p.close()
    return p


def envelope(u: float) -> float:
    # 0 at the centre, 1 at WAVE_PEAK_AT, easing to WAVE_SWING_EDGE at the edge.
    if u <= WAVE_PEAK_AT:
        return (u / WAVE_PEAK_AT) ** 1.4
    f = min((u - WAVE_PEAK_AT) / (1 - WAVE_PEAK_AT), 1.2)
    return 1 - (1 - WAVE_SWING_EDGE) * f * f


def wave_y(x: float) -> float:
    t = (x - CENTER) / CENTER
    bias = WAVE_BIAS_RIGHT if t > 0 else WAVE_BIAS_LEFT
    swing = WAVE_SWING_CENTRE + (WAVE_SWING_PEAK - WAVE_SWING_CENTRE) * envelope(abs(t)) * bias
    return CENTER - swing * math.sin(2 * math.pi * WAVE_CYCLES * t)


def wave() -> pathops.Path:
    # Sample the curve, then join the samples with Catmull-Rom cubics.
    x0, x1 = -WAVE_BLEED, CANVAS + WAVE_BLEED
    pts = [(x, wave_y(x)) for x in (x0 + (x1 - x0) * i / WAVE_SAMPLES for i in range(WAVE_SAMPLES + 1))]
    p = pathops.Path()
    p.moveTo(*pts[0])
    for i in range(len(pts) - 1):
        a = pts[max(i - 1, 0)]
        b, c = pts[i], pts[i + 1]
        d = pts[min(i + 2, len(pts) - 1)]
        c1 = (b[0] + (c[0] - a[0]) / 6, b[1] + (c[1] - a[1]) / 6)
        c2 = (c[0] - (d[0] - b[0]) / 6, c[1] - (d[1] - b[1]) / 6)
        p.cubicTo(*c1, *c2, *c)
    p.stroke(WAVE_WIDTH, pathops.LineCap.ROUND_CAP, pathops.LineJoin.ROUND_JOIN, 4)
    p.convertConicsToQuads()
    p.simplify()
    return p


# Back to front.
LAYERS = {
    "1-base": lambda: circle(BASE_RADIUS),
    "2-face": lambda: circle(FACE_RADIUS),
    "3-wave": wave,
    "4-reading": lambda: circle(READING_RADIUS),
}


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    out.mkdir(parents=True, exist_ok=True)
    for name, build in LAYERS.items():
        (out / f"{name}.svg").write_text(svg(name, svg_d(build())))


if __name__ == "__main__":
    main()
