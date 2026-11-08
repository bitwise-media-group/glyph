# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Builds Glyph's App Store artwork: layered SVG masters (each element its own
# named layer, text kept as text, so Pixelmator Pro opens them editable) and
# opaque PNG exports at Apple's exact sizes.
#
#   python3 design/app-store/build.py [--captures .build/screenshots]
#
# Creative assets are always built. Screenshots are built from the PNGs that
# `mise run screenshots` exports (see README.md); a frame whose capture is
# missing gets a placeholder SVG and no PNG. Needs rsvg-convert, Pillow and the
# JetBrains Mono font.

import argparse
import base64
import json
import math
import subprocess
from pathlib import Path
from xml.sax.saxutils import escape

from PIL import Image

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
FONT = "JetBrains Mono"
ADVANCE = 0.6  # JetBrains Mono's advance width, in em

# dotty's palette (oss.bitwisemedia.uk/dotty).
THEMES = {
    "dark": {
        "bg": "#15140F", "bg_glow": "#2A2718", "grid": "#2A2718",
        "rim": "#C8C0A4", "rim_opacity": 0.55, "face": "#F4EFDD", "reading": "#15140F",
        "wave": ("#E0A800", "#FFD740"), "glow": 0.55, "shadow": "#000000", "shadow_opacity": 0.55,
        "text": "#F4EFDD", "muted": "#A39A77", "accent": "#F5C518",
        "frame": "#2A2718", "slot": "#1F1D15",
    },
    "light": {
        "bg": "#FBF8ED", "bg_glow": "#FFFDF7", "grid": "#E6DECB",
        "rim": "#E6DECB", "rim_opacity": 1.0, "face": "#FFFDF7", "reading": "#211E14",
        "wave": ("#A85A00", "#E6B400"), "glow": 0.2, "shadow": "#533F14", "shadow_opacity": 0.2,
        "text": "#211E14", "muted": "#6F6748", "accent": "#F5C518",
        "frame": "#211E14", "slot": "#F3EEDF",
    },
}


# ---------- shapes ----------


def wave_points(x0, x1, cx, cy, r, bias_left=0.78, step=None):
    """The icon's wave, scaled to a sensor of radius r and carried out to x0..x1.

    Near the sensor it matches the icon: a small swing through the centre,
    widest around the rim. Beyond that it settles into a calm, longer wave."""
    wavelength = 0.7585 * r
    step = step or r / 40

    def envelope(u):
        if u <= 1.06:
            e = (u / 1.06) ** 1.4
        elif u <= 1.7:
            f = (u - 1.06) / 0.64
            e = 1 - 0.55 * f * f
        else:
            e = 0.45 * math.exp(-(u - 1.7) / 1.1) + 0.16 * (1 - math.exp(-(u - 1.7) / 1.1))
        return 0.087 + (0.633 - 0.087) * e

    def stretch(u):  # the wave lengthens away from the sensor
        return 1.0 if u <= 1.7 else 1.0 + 0.35 * min((u - 1.7) / 2.0, 1.0)

    def phase_at(x):
        # integrate 2π/λ from the centre so the phase is continuous
        n = max(int(abs(x - cx) / step), 1)
        dx = (x - cx) / n
        total = 0.0
        for i in range(n):
            u = abs(cx + (i + 0.5) * dx - cx) / r
            total += 2 * math.pi * dx / (wavelength * stretch(u))
        return total

    pts = []
    x = x0
    while x <= x1 + 1e-6:
        u = abs(x - cx) / r
        bias = 1.0 if x >= cx else bias_left
        pts.append((x, cy - r * envelope(u) * bias * math.sin(phase_at(x))))
        x += step
    return pts


def smooth_d(pts):
    d = [f"M{pts[0][0]:.1f} {pts[0][1]:.1f}"]
    for i in range(len(pts) - 1):
        a, b, c = pts[max(i - 1, 0)], pts[i], pts[i + 1]
        e = pts[min(i + 2, len(pts) - 1)]
        c1 = (b[0] + (c[0] - a[0]) / 6, b[1] + (c[1] - a[1]) / 6)
        c2 = (c[0] - (e[0] - b[0]) / 6, c[1] - (e[1] - b[1]) / 6)
        d.append(f"C{c1[0]:.1f} {c1[1]:.1f} {c2[0]:.1f} {c2[1]:.1f} {c[0]:.1f} {c[1]:.1f}")
    return " ".join(d)


def dot_grid_d(w, h, spacing, radius):
    # one compound path, so it imports as a single shape layer
    parts = []
    cols, rows = int(w / spacing) + 2, int(h / spacing) + 2
    ox, oy = (w - (cols - 1) * spacing) / 2, (h - (rows - 1) * spacing) / 2
    for j in range(rows):
        for i in range(cols):
            x, y = ox + i * spacing, oy + j * spacing
            parts.append(f"M{x - radius:.1f} {y:.1f}a{radius} {radius} 0 1 0 {2 * radius} 0a{radius} {radius} 0 1 0 {-2 * radius} 0Z")
    return "".join(parts)


def wrap(text, size, width):
    """Wraps to the fewest lines that fit, then evens out their lengths."""
    per_line = max(int(width / (size * ADVANCE)), 1)

    def greedy(limit):
        lines, line = [], ""
        for word in text.split():
            candidate = f"{line} {word}".strip()
            if len(candidate) <= limit or not line:
                line = candidate
            else:
                lines.append(line)
                line = word
        return lines + [line]

    lines = greedy(per_line)
    for limit in range(per_line - 1, 0, -1):
        tighter = greedy(limit)
        if len(tighter) > len(lines):
            break
        lines = tighter
    return lines


# ---------- SVG pieces ----------


def defs(theme, uid, w, h, cx, cy, r, x0, x1):
    t = THEMES[theme]
    a, b = t["wave"]
    blur = r * 0.05
    return f"""  <defs>
    <radialGradient id="{uid}-bg-glow" gradientUnits="userSpaceOnUse" cx="{cx}" cy="{cy}" r="{max(w, h) * 0.6:.0f}">
      <stop offset="0" stop-color="{t['bg_glow']}"/>
      <stop offset="1" stop-color="{t['bg']}"/>
    </radialGradient>
    <linearGradient id="{uid}-wave-gradient" gradientUnits="userSpaceOnUse" x1="{x0}" y1="0" x2="{x1}" y2="0">
      <stop offset="0" stop-color="{a}"/>
      <stop offset="1" stop-color="{b}"/>
    </linearGradient>
    <filter id="{uid}-glow" x="-10%" y="-50%" width="120%" height="200%">
      <feGaussianBlur stdDeviation="{blur:.1f}"/>
    </filter>
    <filter id="{uid}-shadow" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="{r * 0.06:.1f}"/>
    </filter>
  </defs>
"""


def background(theme, uid, w, h, grid=True, spacing=None):
    t = THEMES[theme]
    out = f'  <g id="Background">\n    <rect id="Canvas" width="{w}" height="{h}" fill="url(#{uid}-bg-glow)"/>\n'
    if grid:
        spacing = spacing or round(min(w, h) / 30)
        out += f'    <path id="Dot-grid" fill="{t["grid"]}" d="{dot_grid_d(w, h, spacing, max(spacing * 0.045, 1.5))}"/>\n'
    return out + "  </g>\n"


def sensor_and_wave(theme, uid, cx, cy, r, x0, x1):
    t = THEMES[theme]
    d = smooth_d(wave_points(x0, x1, cx, cy, r))
    width = r * 0.133
    face_r, dot_r = r * 0.813, r * 0.14
    return f"""  <g id="Sensor">
    <circle id="Sensor-shadow" cx="{cx}" cy="{cy + r * 0.07:.1f}" r="{r:.1f}" fill="{t['shadow']}" opacity="{t['shadow_opacity']}" filter="url(#{uid}-shadow)"/>
    <circle id="Sensor-rim" cx="{cx}" cy="{cy}" r="{r:.1f}" fill="{t['rim']}" opacity="{t['rim_opacity']}"/>
    <circle id="Sensor-face-shadow" cx="{cx}" cy="{cy + r * 0.035:.1f}" r="{face_r:.1f}" fill="{t['shadow']}" opacity="{t['shadow_opacity'] * 0.7:.2f}" filter="url(#{uid}-shadow)"/>
    <circle id="Sensor-face" cx="{cx}" cy="{cy}" r="{face_r:.1f}" fill="{t['face']}"/>
  </g>
  <g id="Wave">
    <path id="Wave-glow" d="{d}" fill="none" stroke="url(#{uid}-wave-gradient)" stroke-width="{width * 2.2:.1f}" stroke-linecap="round" stroke-linejoin="round" opacity="{t['glow']}" filter="url(#{uid}-glow)"/>
    <path id="Wave-line" d="{d}" fill="none" stroke="url(#{uid}-wave-gradient)" stroke-width="{width:.1f}" stroke-linecap="round" stroke-linejoin="round"/>
  </g>
  <g id="Reading">
    <circle id="Reading-dot" cx="{cx}" cy="{cy}" r="{dot_r:.1f}" fill="{t['reading']}"/>
  </g>
"""


def text_block(theme, x, y, lines, size, weight, color, anchor="middle", tracking=-0.02, leading=1.18, layer="Text"):
    spans = "".join(
        f'<tspan x="{x:.0f}" dy="{0 if i == 0 else size * leading:.0f}">{escape(line)}</tspan>' for i, line in enumerate(lines)
    )
    return (
        f'    <text id="{layer}" x="{x:.0f}" y="{y:.0f}" font-family="{FONT}" font-size="{size:.0f}" '
        f'font-weight="{weight}" letter-spacing="{size * tracking:.1f}" fill="{color}" text-anchor="{anchor}">{spans}</text>\n'
    )


def svg_doc(w, h, title, body):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
        f'width="{w}" height="{h}" viewBox="0 0 {w} {h}">\n  <title>{escape(title)}</title>\n{body}</svg>\n'
    )


# ---------- export ----------


def export(svg_path, png_path, w, h):
    tmp = png_path.with_suffix(".rgba.png")
    subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h), "-o", str(tmp), str(svg_path)], check=True)
    img = Image.open(tmp)
    flat = Image.new("RGB", img.size, (0, 0, 0))
    flat.paste(img.convert("RGB"), mask=img.getchannel("A") if img.mode == "RGBA" else None)
    flat.save(png_path, optimize=True)
    tmp.unlink()
    assert flat.size == (w, h), (png_path, flat.size)


# ---------- creative assets ----------

CREATIVE = [
    # name, w, h, theme, sensor centre y and radius (fractions of h), headline size (fraction of h) or None
    ("universal-5244x2950", 5244, 2950, "dark", 0.44, 0.235, 0.055),
    ("header-3840x1646", 3840, 1646, "dark", 0.42, 0.25, 0.062),
    ("search-3840x2560", 3840, 2560, "dark", 0.42, 0.25, 0.062),
    ("event-card-3840x2160", 3840, 2160, "light", 0.5, 0.25, None),
    ("event-details-2160x3840", 2160, 3840, "light", 0.4, 0.17, None),
]
TAGLINE = "Glucose, every minute."


def build_creative(out):
    out.mkdir(parents=True, exist_ok=True)
    for name, w, h, theme, fy, fr, text in CREATIVE:
        uid = name.split("-")[0]
        cx, cy, r = w / 2, h * fy, h * fr
        x0, x1 = -r * 0.3, w + r * 0.3
        body = defs(theme, uid, w, h, cx, cy, r, x0, x1)
        body += background(theme, uid, w, h)
        body += sensor_and_wave(theme, uid, cx, cy, r, x0, x1)
        if text:
            size = h * text
            y = cy + r * 1.62 + size * 0.35
            body += '  <g id="Tagline">\n' + text_block(theme, w / 2, y, [TAGLINE], size, 800, THEMES[theme]["text"], layer="Headline") + "  </g>\n"
        svg = out / f"{name}.svg"
        svg.write_text(svg_doc(w, h, f"Glyph {name}", body))
        export(svg, out / f"{name}.png", w, h)


# ---------- screenshots ----------

SIZES = {
    # name: canvas, orientation, source device folder (under the posture folder), posture
    "iphone-6.9-1320x2868": ((1320, 2868), "portrait", "iPhone 18 Pro", "folded"),
    "iphone-6.3-1206x2622": ((1206, 2622), "portrait", "iPhone 18 Pro", "folded"),
    "duo-outer-1398x2034": ((1398, 2034), "portrait", "iPhone Duo", "folded"),
    "duo-inner-2853x2007": ((2853, 2007), "landscape", "iPhone Duo", "unfolded"),
}


def find_capture(captures, posture, device, orientation, scenario, section):
    folder = captures / posture / device
    hits = sorted(folder.glob(f"{orientation}-*-{scenario}-{section}.png")) if folder.is_dir() else []
    return hits[0] if hits else None


def screenshot_svg(theme, w, h, frame, capture, size_name):
    t = THEMES[theme]
    uid = "shot"
    landscape = w > h
    margin = w * (0.06 if landscape else 0.07)
    head_size = (h * 0.05) if landscape else (w * 0.066)
    sub_size = head_size * (0.5 if landscape else 0.56)
    top = h * (0.07 if landscape else 0.055)
    head_lines = wrap(frame["headline"], head_size, w - 2 * margin)
    sub_lines = wrap(frame["subline"], sub_size, w - 2 * margin)
    head_y = top + head_size
    bar_y = head_y + (len(head_lines) - 1) * head_size * 1.18 + head_size * 0.62
    sub_y = bar_y + head_size * 0.16 + sub_size * 1.9

    # the device: the capture's aspect ratio, as large as fits below the text
    if capture:
        cw, ch = Image.open(capture).size
    else:
        cw, ch = (2853, 2007) if landscape else ((1398, 2034) if size_name.startswith("duo-outer") else (1206, 2622))
    area_top = sub_y + (len(sub_lines) - 1) * sub_size * 1.3 + sub_size * 1.4
    area_h = h - area_top - h * 0.045
    area_w = w - 2 * margin
    bezel = min(area_w, area_h) * 0.014
    scale = min((area_w - 2 * bezel) / cw, (area_h - 2 * bezel) / ch)
    sw, sh = cw * scale, ch * scale
    sx, sy = (w - sw) / 2, area_top + (area_h - sh - 2 * bezel) / 2 + bezel
    radius = min(sw, sh) * (0.075 if landscape else 0.12)

    body = f"""  <defs>
    <radialGradient id="{uid}-bg-glow" gradientUnits="userSpaceOnUse" cx="{w / 2}" cy="{h * 0.62:.0f}" r="{max(w, h) * 0.7:.0f}">
      <stop offset="0" stop-color="{t['bg_glow']}"/>
      <stop offset="1" stop-color="{t['bg']}"/>
    </radialGradient>
    <clipPath id="{uid}-screen"><rect x="{sx:.1f}" y="{sy:.1f}" width="{sw:.1f}" height="{sh:.1f}" rx="{radius:.1f}"/></clipPath>
    <filter id="{uid}-shadow" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="{w * 0.02:.1f}"/></filter>
  </defs>
"""
    body += background(theme, uid, w, h, spacing=round(min(w, h) / 22))
    body += '  <g id="Caption">\n'
    body += text_block(theme, w / 2, head_y, head_lines, head_size, 800, t["text"], layer="Headline")
    body += f'    <rect id="Accent" x="{w / 2 - head_size * 0.9:.1f}" y="{bar_y:.1f}" width="{head_size * 1.8:.1f}" height="{head_size * 0.16:.1f}" rx="{head_size * 0.03:.1f}" fill="{t["accent"]}"/>\n'
    body += text_block(theme, w / 2, sub_y, sub_lines, sub_size, 500, t["muted"], tracking=0, leading=1.3, layer="Subline")
    body += "  </g>\n"
    fx, fy, fw, fh = sx - bezel, sy - bezel, sw + 2 * bezel, sh + 2 * bezel
    body += f"""  <g id="Device">
    <rect id="Device-shadow" x="{fx:.1f}" y="{fy + w * 0.02:.1f}" width="{fw:.1f}" height="{fh:.1f}" rx="{radius + bezel:.1f}" fill="{t['shadow']}" opacity="{t['shadow_opacity']}" filter="url(#{uid}-shadow)"/>
    <rect id="Device-frame" x="{fx:.1f}" y="{fy:.1f}" width="{fw:.1f}" height="{fh:.1f}" rx="{radius + bezel:.1f}" fill="{t['frame']}"/>
"""
    if capture:
        data = base64.b64encode(capture.read_bytes()).decode()
        body += (
            f'    <image id="Screenshot" x="{sx:.1f}" y="{sy:.1f}" width="{sw:.1f}" height="{sh:.1f}" '
            f'preserveAspectRatio="xMidYMid slice" clip-path="url(#{uid}-screen)" '
            f'xlink:href="data:image/png;base64,{data}" href="data:image/png;base64,{data}"/>\n'
        )
    else:
        label = f"{frame['section']} · {frame['scenario']}"
        body += f'    <rect id="Screenshot-placeholder" x="{sx:.1f}" y="{sy:.1f}" width="{sw:.1f}" height="{sh:.1f}" rx="{radius:.1f}" fill="{t["slot"]}"/>\n'
        body += text_block(theme, w / 2, sy + sh / 2, ["Screenshot", label], sub_size, 500, t["muted"], tracking=0, leading=1.4, layer="Placeholder-label")
    body += "  </g>\n"
    return body


def build_screenshots(out, captures, frames_spec):
    built, missing = [], []
    for size_name, ((w, h), orientation, device, posture) in SIZES.items():
        folder = out / size_name
        folder.mkdir(parents=True, exist_ok=True)
        for frame in frames_spec["frames"]:
            frame = {**frame, **frame.get("overrides", {}).get(size_name, {})}
            capture = find_capture(captures, posture, device, orientation, frame["scenario"], frame["section"])
            svg = folder / f"{frame['id']}.svg"
            svg.write_text(svg_doc(w, h, f"Glyph {size_name} {frame['id']}", screenshot_svg(frames_spec["theme"], w, h, frame, capture, size_name)))
            png = folder / f"{frame['id']}.png"
            if capture:
                export(svg, png, w, h)
                built.append(png)
            else:
                if png.exists():
                    png.unlink()
                missing.append(f"{posture}/{device}/{orientation}-*-{frame['scenario']}-{frame['section']}.png")
    return built, sorted(set(missing))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--captures", type=Path, default=REPO / ".build" / "screenshots")
    parser.add_argument("--only", choices=["creative", "screenshots"])
    args = parser.parse_args()
    if args.only != "screenshots":
        build_creative(HERE / "creative")
    if args.only != "creative":
        spec = json.loads((HERE / "screenshots.json").read_text())
        built, missing = build_screenshots(HERE / "screenshots", args.captures, spec)
        print(f"screenshots: {len(built)} built")
        for m in missing:
            print(f"  missing capture: {m}")


if __name__ == "__main__":
    main()
