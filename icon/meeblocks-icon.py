# MeeBlocks icon variants: falling-block puzzle, raw 8-bit / Atari style.
# Hard-edged square cells aligned to the 80 px grid, project background + N9 mask.
# Usage: python3 meeblocks-icon.py background80.png n9mask80.png outdir
from PIL import Image, ImageDraw, ImageFilter
import sys, os
K = 8; W = 80 * K
LIGHT = (231, 255, 205); GLOW = (120, 170, 100)
base = Image.open(sys.argv[1]).convert('RGBA'); mask = Image.open(sys.argv[2]).convert('L'); out = sys.argv[3]

# each variant: cell size, gap (px at 80), origin (x,y at 80), list of rows ('#' = cell)
VARIANTS = {
 'a': (8, 1, None, [        # falling T over a stack with one gap
      "..###..",
      "...#...",
      ".......",
      ".......",
      "#..##.#",
      "##.####",
      "###.###"]),
 'b': (14, 2, None, [       # one big T piece
      "###",
      ".#."]),
 'c': (11, 2, None, [       # interlocked S and Z, staircase
      ".##..",
      "##.##",
      "..##.",
      ]),
 'd': (8, 1, None, [        # L dropping into a well
      "....#..",
      "....#..",
      "....##.",
      ".......",
      "#.....#",
      "##.#..#",
      "####.##"]),
}

def pictogram(v):
    s, g, org, rows = VARIANTS[v]
    m = Image.new('L', (W, W), 0); d = ImageDraw.Draw(m)
    cols = max(len(r) for r in rows)
    tw = cols * s + (cols - 1) * g; th = len(rows) * s + (len(rows) - 1) * g
    x0 = (80 - tw) // 2; y0 = (80 - th) // 2 + 1
    for r, row in enumerate(rows):
        for c, ch in enumerate(row):
            if ch == '#':
                x = x0 + c * (s + g); y = y0 + r * (s + g)
                d.rectangle([x * K, y * K, (x + s) * K - 1, (y + s) * K - 1], fill=255)
    return m

def make(v):
    img = base.resize((W, W), Image.BICUBIC)
    m = pictogram(v)
    gl = m.filter(ImageFilter.GaussianBlur(K * 1.6)).point(lambda x: int(x * .55))
    img = Image.composite(Image.new('RGBA', (W, W), GLOW + (255,)), img, gl)
    small = img.resize((80, 80), Image.LANCZOS)
    # cells pasted at 80 px with NEAREST so edges stay razor sharp (8-bit look)
    cell = m.resize((80, 80), Image.NEAREST)
    small = Image.composite(Image.new('RGBA', (80, 80), LIGHT + (255,)), small, cell)
    small.putalpha(mask); return small

icons = {}
for v in sorted(VARIANTS):
    icons[v] = make(v); icons[v].save(os.path.join(out, 'meeblocks80-%s.png' % v))
n = len(icons)
sheet = Image.new('RGBA', (n * 220 + 20, 330), (0, 0, 0, 255)); d = ImageDraw.Draw(sheet)
for i, v in enumerate(sorted(icons)):
    sheet.alpha_composite(icons[v].resize((200, 200), Image.NEAREST), (20 + i * 220, 20))
    sheet.alpha_composite(icons[v], (80 + i * 220, 230))
    d.text((20 + i * 220, 312), v.upper(), fill=(200, 200, 200))
sheet.save(os.path.join(out, 'meeblocks-icon-preview.png'))
