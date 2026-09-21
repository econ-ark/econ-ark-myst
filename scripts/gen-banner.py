# /// script
# requires-python = ">=3.11"
# dependencies = ["numpy", "svgelements"]
# ///
"""Build banner.svg and favicon.svg from the four curves of the official Econ-ARK logo.

The logo is distributed as EPS (Econ-Ark_Logo_1536x768px.eps, Illustrator 16). Its curves are
filled ribbons that taper to a point at each end, so two things have to survive the stretch into
a banner: the geometry, and that taper. Scaling the ribbons non-uniformly would keep the taper
but thin the flat right arm and fatten the steep left one, because the pen distorts with the
slope. So this reads each ribbon, measures its centreline and its perpendicular half width at
every x, stretches the centreline into the banner frame, and rebuilds the ribbon there with the
half width scaled uniformly.

Run it from the repository root. A directory target writes both assets from one reading of the
curves, which is the whole cost of a run, so this is the way to rebuild them. The dependencies are
declared above, so uv resolves them and nothing has to name them at the call site:

    uv run --no-project scripts/gen-banner.py scripts/curves-crop.svg brand/

The run is deterministic, so regenerating an unchanged input rewrites the same bytes.

A file target writes the banner alone, and a third argument `favicon` the square tile alone:

    uv run --no-project scripts/gen-banner.py scripts/curves-crop.svg brand/banner.svg
    uv run --no-project scripts/gen-banner.py scripts/curves-crop.svg brand/favicon.svg favicon

myst.yml points at the png, so the tile is rasterized at the 256 pixels it is drawn for:

    inkscape brand/favicon.svg --export-type=png --export-filename=brand/favicon.png

Inkscape 1.2.2 writes the same bytes on every run. rsvg-convert and ImageMagick render the tile
to identical pixels and pack the png differently, so a rebuild with either shows a diff in the
container alone.

Input: scripts/curves-crop.svg, tracked beside this file so the assets can be rebuilt from the
repository alone. It came from the official EPS, which is not tracked here because it is a brand
asset rather than a source this repository owns:
    gs -dEPSCrop -sDEVICE=pdfwrite -o color.pdf Econ-Ark_Logo_1536x768px.eps
    inkscape color.pdf --export-type=svg --export-plain-svg --export-filename=color.svg
    (drop the wordmark, keep the four coloured paths)
    inkscape curves.svg --export-type=svg --export-area-drawing --export-plain-svg \
        --export-filename=curves-crop.svg
"""

import logging
import os
import sys

import numpy as np
from svgelements import SVG, Path

logging.basicConfig(format="%(message)s", level=logging.INFO)
log = logging.getLogger(__name__)

# Banner frame, and the content inset the current banner.svg already uses
WIDTH, HEIGHT = 1600, 445
X0, X1, Y0, Y1 = 30.0, 1570.0, 26.0, 418.0
# Pen width in banner units where the logo's own ribbon is at its widest
PEN = 9.0

# The artwork's own fills, which are CMYK, mapped to the sRGB the design guidelines name
BRAND = {
    "#f9a72b": "#fbaf3f",
    "#ed127c": "#ed2a7b",
    "#00adef": "#00adef",
    "#40b93c": "#38b449",
}
# Drawing order: the lowest curve first, so the higher ones are drawn over it where they cross
ORDER = ["#40b93c", "#00adef", "#ed127c", "#f9a72b"]


def sample(path, n):
    return np.array([[p.x, p.y] for p in (path.point(t / n) for t in range(n + 1))])


def profile(path, stations=240):
    """Centreline and perpendicular half width of a ribbon, at evenly spaced x positions."""
    pts = sample(path, 40000)
    lo, hi = pts[:, 0].min(), pts[:, 0].max()
    xs = np.linspace(lo, hi, stations)
    tol = (hi - lo) / stations
    mid, half = [], []
    for x in xs:
        band = pts[np.abs(pts[:, 0] - x) <= tol, 1]
        if not len(band):
            continue
        mid.append((x, (band.min() + band.max()) / 2))
        half.append((band.max() - band.min()) / 2)
    mid = np.array(mid)
    # The vertical span overstates the width on a steep stretch; project it onto the normal
    slope = np.gradient(mid[:, 1], mid[:, 0])
    return mid, np.array(half) * np.cos(np.arctan(slope))


def rdp(points, eps):
    """Ramer-Douglas-Peucker: drop points the eye cannot see, keep the kinks."""
    if len(points) < 3:
        return points
    a, b = points[0], points[-1]
    ab = b - a
    length = float(np.hypot(*ab))
    rel = points - a
    dist = (
        np.abs(ab[0] * rel[:, 1] - ab[1] * rel[:, 0]) / length
        if length
        else np.hypot(*rel.T)
    )
    far = int(np.argmax(dist))
    if dist[far] <= eps:
        return np.array([a, b])
    return np.vstack([rdp(points[: far + 1], eps)[:-1], rdp(points[far:], eps)])


def ribbon(mid, half, eps=0.25):
    """Offset a centreline by a half width on both sides and close the loop."""
    tangent = np.gradient(mid, axis=0)
    tangent /= np.hypot(tangent[:, 0], tangent[:, 1])[:, None]
    normal = np.column_stack([-tangent[:, 1], tangent[:, 0]])
    upper = rdp(mid + normal * half[:, None], eps)
    lower = rdp(mid - normal * half[:, None], eps)
    loop = np.vstack([upper, lower[::-1]])
    return "M " + " L ".join("%.1f %.1f" % (x, y) for x, y in loop) + " Z", len(loop)


def read(source):
    curves = {
        str(e.fill).lower(): e
        for e in SVG.parse(source).elements()
        if isinstance(e, Path)
    }
    missing = set(ORDER) - set(curves)
    if missing:
        raise SystemExit(f"{source} is missing the curves for {sorted(missing)}")
    return {colour: profile(curves[colour]) for colour in ORDER}


def favicon(shapes, target, size=256, margin=26, pen=13):
    """A square tile of the curves alone, drawn heavy enough to survive 16 pixels.

    The curves fill the square, so their proportions change. The extra height spreads
    their ends apart, which is what makes four lines still read as four at 32px.
    """
    every = np.vstack([mid for mid, _ in shapes.values()])
    gx0, gx1 = every[:, 0].min(), every[:, 0].max()
    gy0, gy1 = every[:, 1].min(), every[:, 1].max()
    span = size - 2 * margin
    sx, sy = span / (gx1 - gx0), span / (gy1 - gy0)

    drawn = []
    for colour in ORDER:
        mid, _ = shapes[colour]
        pts = np.column_stack(
            [margin + (mid[:, 0] - gx0) * sx, margin + (mid[:, 1] - gy0) * sy]
        )
        kept = rdp(pts, 0.4)
        d = "M " + " L ".join("%.1f %.1f" % (x, y) for x, y in kept)
        drawn.append(f'    <path d="{d}" stroke="{BRAND[colour]}"/>')

    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}"'
        f' width="{size}" height="{size}" role="img"'
        f' aria-label="The four Econ-ARK logo curves on a deep blue tile">\n'
        f'  <rect width="{size}" height="{size}" fill="#1f476b"/>\n'
        f'  <g fill="none" stroke-width="{pen}" stroke-linecap="round"'
        f' stroke-linejoin="round">\n' + "\n".join(drawn) + "\n  </g>\n</svg>\n"
    )
    with open(target, "w") as handle:
        handle.write(svg)
    log.info("wrote %s, %d bytes", target, len(svg))


def banner(shapes, target):
    every = np.vstack([mid for mid, _ in shapes.values()])
    gx0, gx1 = every[:, 0].min(), every[:, 0].max()
    gy0, gy1 = every[:, 1].min(), every[:, 1].max()
    sx, sy = (X1 - X0) / (gx1 - gx0), (Y1 - Y0) / (gy1 - gy0)
    widest = max(half.max() for _, half in shapes.values())
    pen = PEN / 2 / widest
    log.info(
        "scale x %.4f, y %.4f (squashed %.2f to 1); pen %.4f", sx, sy, sx / sy, pen
    )

    drawn = []
    for colour in ORDER:
        mid, half = shapes[colour]
        mid = np.column_stack(
            [X0 + (mid[:, 0] - gx0) * sx, Y0 + (mid[:, 1] - gy0) * sy]
        )
        d, n = ribbon(mid, half * pen)
        log.info("%s: %d stations as a %d point ribbon", colour, len(half), n)
        drawn.append(f'      <path d="{d}" fill="{BRAND[colour]}"/>')

    note = (
        "  <!--\n"
        "    The default banner for an Econ-ARK paper: the four curves of the official logo,\n"
        "    stretched to the width of a banner. Each path is the centreline of one curve in\n"
        "    Econ-Ark_Logo_1536x768px.eps, rebuilt at banner proportions with the logo's own\n"
        "    taper and a pen that stays even across the stretch. Drawing them this way keeps\n"
        "    what the logo says: the curves leave one origin, each kinks where it stops being\n"
        "    bound by the constraint, and the kinks sit on one line.\n"
        "\n"
        "    preserveAspectRatio is none, so the fan reaches the corners of whatever box holds\n"
        "    it. The curves all leave one point at the lower left and open out to the right\n"
        "    edge, so under a non-uniform scale that reading survives and only the steepness\n"
        "    changes. Why a caller would want that belongs to the caller.\n"
        "  -->\n"
    )
    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {WIDTH} {HEIGHT}"'
        f' width="{WIDTH}" height="{HEIGHT}" preserveAspectRatio="none" role="img"'
        f' aria-label="The four Econ-ARK logo curves, stretched across a deep blue field">\n'
        + note
        + f'  <rect width="{WIDTH}" height="{HEIGHT}" fill="#1f476b"/>\n'
        f"  <g>\n" + "\n".join(drawn) + "\n  </g>\n</svg>\n"
    )
    with open(target, "w") as handle:
        handle.write(svg)
    log.info("wrote %s, %d bytes", target, len(svg))


if __name__ == "__main__":
    # Sampling the curves is the whole cost and both assets need the same result, so it is read
    # once here. A directory target writes the pair from that one read; a file writes just the one.
    shapes = read(sys.argv[1])
    target = sys.argv[2]
    if len(sys.argv) > 3 and sys.argv[3] == "favicon":
        favicon(shapes, target)
    elif os.path.isdir(target):
        banner(shapes, os.path.join(target, "banner.svg"))
        favicon(shapes, os.path.join(target, "favicon.svg"))
    else:
        banner(shapes, target)
