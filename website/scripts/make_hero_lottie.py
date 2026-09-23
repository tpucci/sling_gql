#!/usr/bin/env python3
"""Generates public/hero.json — the landing-page Lottie animation.

Story (7 s loop, 60 fps):
  1. A widget card shows three skeleton rows (grey bars).
  2. Reading each row emits a dot that flies into a document card, where a
     query line lights up on arrival.
  3. The document pulses: one request.
  4. A response dot flies back; the widget rows fill with data (bright bars).
  5. Everything fades back to the start.

Shapes only — no text — so it stays crisp at any size and needs no fonts.
"""
import json
from pathlib import Path

FPS = 60
DUR = 420  # frames
W, H = 620, 400

# palette
CARD = (0.086, 0.102, 0.176)      # #161a2d
CARD_STROKE = (0.20, 0.22, 0.31)  # #333850
SKEL = (0.20, 0.22, 0.31)
DATA = (0.93, 0.93, 0.96)         # #eceef4
ORANGE = (1.0, 0.604, 0.235)      # #ff9a3c
CORAL = (1.0, 0.369, 0.384)       # #ff5e62
DIM = (0.33, 0.35, 0.44)          # #545a70


def rgba(c, a=1.0):
    return [c[0], c[1], c[2], a]


EASE = {"i": {"x": [0.3], "y": [1]}, "o": {"x": [0.5], "y": [0]}}


def anim(keys, dims=1):
    """keys: list of (t, value) -> animated property; value is list."""
    out = []
    for i, (t, v) in enumerate(keys):
        k = {"t": t, "s": v}
        if i < len(keys) - 1:
            k["i"] = {"x": [0.3] * dims, "y": [1] * dims}
            k["o"] = {"x": [0.5] * dims, "y": [0] * dims}
        out.append(k)
    return {"a": 1, "k": out}


def hold(keys, dims=1):
    out = []
    for i, (t, v) in enumerate(keys):
        k = {"t": t, "s": v, "h": 1}
        out.append(k)
    return {"a": 1, "k": out}


def const(v):
    return {"a": 0, "k": v}


def transform(p=(0, 0), o=100, s=(100, 100), r=0):
    return {
        "ty": "tr",
        "p": const([p[0], p[1]]) if not isinstance(p, dict) else p,
        "a": const([0, 0]),
        "s": const([s[0], s[1]]) if not isinstance(s, dict) else s,
        "r": const(r),
        "o": const(o) if not isinstance(o, dict) else o,
        "sk": const(0),
        "sa": const(0),
    }


def rect(w, h, r, fill=None, stroke=None, stroke_w=2, p=(0, 0), o=100, name="rect"):
    items = [{"ty": "rc", "d": 1, "s": const([w, h]), "p": const([0, 0]), "r": const(r)}]
    if fill is not None:
        items.append({"ty": "fl", "c": fill if isinstance(fill, dict) else const(rgba(fill)), "o": const(100), "r": 1})
    if stroke is not None:
        items.append({"ty": "st", "c": stroke if isinstance(stroke, dict) else const(rgba(stroke)),
                      "o": const(100), "w": const(stroke_w), "lc": 2, "lj": 2})
    items.append(transform(p=p, o=o))
    return {"ty": "gr", "it": items, "nm": name}


def dot(d, fill, p, o=100, name="dot"):
    items = [{"ty": "el", "d": 1, "s": const([d, d]), "p": const([0, 0])},
             {"ty": "fl", "c": const(rgba(fill)), "o": const(100), "r": 1},
             transform(p=p, o=o)]
    return {"ty": "gr", "it": items, "nm": name}


def layer(name, shapes, ind, p=(0, 0), o=100):
    return {
        "ddd": 0, "ind": ind, "ty": 4, "nm": name, "sr": 1,
        "ks": {"o": const(o) if not isinstance(o, dict) else o, "r": const(0),
               "p": const([p[0], p[1], 0]) if not isinstance(p, dict) else p,
               "a": const([0, 0, 0]), "s": const([100, 100, 100])},
        "ao": 0, "shapes": shapes, "ip": 0, "op": DUR, "st": 0, "bm": 0,
    }


layers = []
ind = 1

# ---------------------------------------------------------------- geometry
WX, DX = 150, 470          # card centers x
CY = 200                   # card center y
CW, CH = 260, 320          # card size
ROW_Y = [CY - 50, CY + 20, CY + 90]
ROW_BAR_W = [130, 96, 150]
ICON_X = WX - 94
BAR_X0 = WX - 64

LINE_Y = [CY - 114, CY - 76, CY - 38, CY, CY + 38, CY + 76, CY + 114]
#         query {    launch {   name     date  rocket {   name     }
LINE_INDENT = [0, 18, 36, 36, 36, 54, 18]
LINE_W = [76, 92, 70, 66, 100, 70, 22]
LINE_X0 = DX - 104

# timeline (frames)
T_READ = [40, 70, 100]          # each row read -> dot leaves
FLIGHT = 45                     # dot travel time
T_ARRIVE = [t + FLIGHT for t in T_READ]
T_SEND = 175                    # document pulses
T_BACK = 215                    # response leaves doc
T_FILL = T_BACK + FLIGHT        # widget rows fill
T_HOLD_END = 370                # start fading back
T_RESET = 400

# ---------------------------------------------------------------- cards
# NB: Lottie draws the FIRST shape/layer on top; decorations go before the card.
layers.append(layer("widget-card", [
    # title bar
    rect(110, 12, 6, fill=DIM, p=(-CW / 2 + 22 + 55, -CH / 2 + 30), name="title"),
    # app-bar dot
    dot(12, ORANGE, p=(CW / 2 - 28, -CH / 2 + 30)),
    rect(CW, CH, 22, fill=CARD, stroke=CARD_STROKE, stroke_w=2, name="card"),
], ind, p=(WX, CY)))
ind += 1

layers.append(layer("doc-card", [
    rect(CW, CH, 22, fill=CARD,
         stroke=anim([(0, rgba(CARD_STROKE)), (T_SEND - 8, rgba(CARD_STROKE)), (T_SEND, rgba(ORANGE)),
                      (T_SEND + 40, rgba(CARD_STROKE))], dims=4),
         stroke_w=2, name="card"),
], ind, p=(DX, CY)))
ind += 1

# send pulse ring
layers.append(layer("pulse", [
    {"ty": "gr", "nm": "ring", "it": [
        {"ty": "rc", "d": 1, "s": const([CW, CH]), "p": const([0, 0]), "r": const(22)},
        {"ty": "st", "c": const(rgba(ORANGE)), "o": anim([(T_SEND, [70]), (T_SEND + 45, [0])]),
         "w": const(3), "lc": 2, "lj": 2},
        transform(s=anim([(T_SEND, [100, 100]), (T_SEND + 45, [118, 118])], dims=2)),
    ]},
], ind, p=(DX, CY), o=hold([(0, [0]), (T_SEND, [100]), (T_SEND + 46, [0])])))
ind += 1

# ---------------------------------------------------------------- widget rows
for i, y in enumerate(ROW_Y):
    bar_fill = anim([
        (0, rgba(SKEL)),
        (T_FILL + i * 8, rgba(SKEL)),
        (T_FILL + i * 8 + 14, rgba(DATA)),
        (T_HOLD_END, rgba(DATA)),
        (T_RESET, rgba(SKEL)),
    ], dims=4)
    icon_fill = anim([
        (0, rgba(SKEL)),
        (T_FILL + i * 8, rgba(SKEL)),
        (T_FILL + i * 8 + 14, rgba(ORANGE)),
        (T_HOLD_END, rgba(ORANGE)),
        (T_RESET, rgba(SKEL)),
    ], dims=4)
    # brief "read" flash on the bar when the dot leaves
    flash = anim([
        (0, [0]), (T_READ[i] - 6, [0]), (T_READ[i], [55]), (T_READ[i] + 18, [0]),
    ])
    w = ROW_BAR_W[i]
    layers.append(layer(f"row-{i}", [
        rect(18, 18, 5, fill=icon_fill, p=(ICON_X, y), name="icon"),
        rect(w, 14, 7, fill=bar_fill, p=(BAR_X0 + w / 2, y), name="bar"),
        {"ty": "gr", "nm": "flash", "it": [
            {"ty": "rc", "d": 1, "s": const([w + 8, 22]), "p": const([0, 0]), "r": const(11)},
            {"ty": "fl", "c": const(rgba(ORANGE)), "o": flash, "r": 1},
            transform(p=(BAR_X0 + w / 2, y)),
        ]},
    ], ind))
    ind += 1

# ---------------------------------------------------------------- doc lines
# lines 0,1,6 (braces) appear with the first dot; 2,3 with dots 1,2; 4,5 with dot 3
appear_at = {0: T_ARRIVE[0], 1: T_ARRIVE[0], 6: T_ARRIVE[0],
             2: T_ARRIVE[0], 3: T_ARRIVE[1], 4: T_ARRIVE[2], 5: T_ARRIVE[2] + 6}
for j, y in enumerate(LINE_Y):
    t0 = appear_at[j]
    is_field = j in (2, 3, 5)
    color = ORANGE if is_field else DIM
    op = anim([(0, [0]), (t0, [0]), (t0 + 12, [100]), (T_HOLD_END, [100]), (T_RESET, [0])])
    sx = anim([(0, [20, 100]), (t0, [20, 100]), (t0 + 14, [100, 100])], dims=2)
    w = LINE_W[j]
    x = LINE_X0 + LINE_INDENT[j]
    layers.append(layer(f"line-{j}", [
        {"ty": "gr", "nm": "line", "it": [
            {"ty": "rc", "d": 1, "s": const([w, 12]), "p": const([w / 2, 0]), "r": const(6)},
            {"ty": "fl", "c": const(rgba(color)), "o": op, "r": 1},
            transform(p=(x, y), s=sx),
        ]},
    ], ind))
    ind += 1

# ---------------------------------------------------------------- flying dots
targets = {0: LINE_Y[2], 1: LINE_Y[3], 2: LINE_Y[4]}
for i in range(3):
    t0, t1 = T_READ[i], T_ARRIVE[i]
    start = [BAR_X0 + ROW_BAR_W[i], ROW_Y[i], 0]
    end = [LINE_X0 + LINE_INDENT[2 if i == 0 else 3 if i == 1 else 4] + 6, targets[i], 0]
    pos = {"a": 1, "k": [
        {"t": t0, "s": start, "to": [70, -60, 0], "ti": [-70, -40, 0],
         "i": {"x": [0.2, 0.2, 0.2], "y": [1, 1, 1]}, "o": {"x": [0.4, 0.4, 0.4], "y": [0, 0, 0]}},
        {"t": t1, "s": end},
    ]}
    op = hold([(0, [0]), (t0, [100]), (t1, [0])])
    layers.append(layer(f"dot-{i}", [dot(12, ORANGE, p=(0, 0))], ind, p=pos, o=op))
    ind += 1
    # trailing smaller dot
    pos2 = {"a": 1, "k": [
        {"t": t0 + 5, "s": start, "to": [70, -60, 0], "ti": [-70, -40, 0],
         "i": {"x": [0.2, 0.2, 0.2], "y": [1, 1, 1]}, "o": {"x": [0.4, 0.4, 0.4], "y": [0, 0, 0]}},
        {"t": t1 + 4, "s": end},
    ]}
    layers.append(layer(f"trail-{i}", [dot(7, CORAL, p=(0, 0))], ind, p=pos2,
                        o=hold([(0, [0]), (t0 + 5, [70]), (t1 + 4, [0])])))
    ind += 1

# response: one bigger dot back to the widget, splitting visually via three arrivals
for i in range(3):
    t0 = T_BACK + i * 8
    t1 = t0 + FLIGHT
    start = [DX - CW / 2, CY, 0]
    end = [BAR_X0 + ROW_BAR_W[i] / 2, ROW_Y[i], 0]
    pos = {"a": 1, "k": [
        {"t": t0, "s": start, "to": [-70, 50, 0], "ti": [60, 30, 0],
         "i": {"x": [0.2, 0.2, 0.2], "y": [1, 1, 1]}, "o": {"x": [0.4, 0.4, 0.4], "y": [0, 0, 0]}},
        {"t": t1, "s": end},
    ]}
    layers.append(layer(f"resp-{i}", [dot(14, DATA, p=(0, 0))], ind, p=pos,
                        o=hold([(0, [0]), (t0, [100]), (t1, [0])])))
    ind += 1

# Built background-first; Lottie wants foreground-first.
layers.reverse()
for i, l in enumerate(layers, start=1):
    l["ind"] = i

lottie = {
    "v": "5.9.6", "fr": FPS, "ip": 0, "op": DUR, "w": W, "h": H, "nm": "sling_gql hero",
    "ddd": 0, "assets": [], "layers": layers,
}

out = Path(__file__).resolve().parent.parent / "public" / "hero.json"
out.write_text(json.dumps(lottie, separators=(",", ":")))
print(f"wrote {out} ({out.stat().st_size // 1024} KB, {len(layers)} layers)")
