#!/usr/bin/env python3
"""Cuts a tool/record_demo.sh recording into store videos.

    tool/cut_demo.py iphone   # 3 App Store previews, 886×1920, + Play promo
    tool/cut_demo.py ipad     # 3 App Store previews, 1200×1600

Reads ../logic-sprint-release/demo/<name>.mov|.mp4 and <name>.marks (scene
start times in ms) and writes ../logic-sprint-release/demo/out/. Scenes are
picked by mark, so a new recording cuts the same way. App previews must be
15–30 s, ≤30 fps, H.264 with a stereo AAC track (a silent one is fine).
"""
import subprocess
import sys
from pathlib import Path

DEMO = Path(__file__).resolve().parent.parent.parent / "logic-sprint-release" / "demo"

# The app needs ~2.5 s after the launch mark to draw its first frame.
FIRST_FRAME = 2.6

# (from mark, offset s, to mark, offset s)
PREVIEWS = {
    "1_rocket_launch": [
        ("launch", FIRST_FRAME, "rocket_play", 0.8),
        ("rocket_play", 9, "rocket_revive", 8),
    ],
    "2_memory_math": [
        ("memory_sheet", 0, "memory_play", 13),
        ("math_play", 0.6, "math_play", 12.6),
    ],
    "3_color_ranks": [
        ("color_play", 0.6, "color_play", 20.6),
        ("ranks", 0, "ranks", 4.5),
        ("profile", 0, "profile", 3),
    ],
}

PROMO = [
    ("launch", FIRST_FRAME, "rocket_play", 0.8),
    ("rocket_play", 9, "rocket_revive", 8),
    ("memory_sheet", 0, "memory_play", 14),
    ("memory_end", 0, "memory_result", 3.5),
    ("math_play", 0.6, "math_play", 13.6),
    ("color_play", 0.6, "color_play", 20.6),
    ("ranks", 0, "done", 0),
]

SIZES = {
    "iphone": "scale=886:-2,crop=886:1920",
    "ipad": "scale=1200:1600",
}
PROMO_SIZE = "scale=-2:1920,pad=1080:1920:(ow-iw)/2:0:black"


def cut(src, marks, segments, vf, out, max_len=None):
    spans = [(marks[a] + da, marks[b] + db) for a, da, b, db in segments]
    total = sum(e - s for s, e in spans)
    if max_len and total > max_len:
        s, e = spans[-1]
        spans[-1] = (s, e - (total - max_len))
        total = max_len
    parts, labels = [], []
    for i, (s, e) in enumerate(spans):
        parts.append(
            f"[0:v]trim={s:.3f}:{e:.3f},setpts=PTS-STARTPTS,fps=30,{vf},setsar=1[v{i}]"
        )
        labels.append(f"[v{i}]")
    graph = ";".join(parts) + f";{''.join(labels)}concat=n={len(spans)}:v=1:a=0[v]"
    subprocess.run(
        [
            "ffmpeg", "-loglevel", "error", "-y", "-i", str(src),
            "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000",
            "-filter_complex", graph, "-map", "[v]", "-map", "1:a",
            "-c:v", "libx264", "-profile:v", "high", "-pix_fmt", "yuv420p",
            "-b:v", "10M", "-maxrate", "12M", "-bufsize", "20M",
            "-c:a", "aac", "-b:a", "256k", "-shortest", "-movflags", "+faststart",
            str(out),
        ],
        check=True,
    )
    print(f"{out.name}: {total:.1f} s")


def main():
    name = sys.argv[1]
    src = next(DEMO.glob(f"{name}.m[op][v4]"))
    marks = {
        k: int(v) / 1000
        for k, v in (line.split() for line in (DEMO / f"{name}.marks").read_text().splitlines())
    }
    out = DEMO / "out"
    out.mkdir(exist_ok=True)
    for clip, segments in PREVIEWS.items():
        cut(src, marks, segments, SIZES[name], out / f"{name}_{clip}.mp4", max_len=29.5)
    if name == "iphone":
        cut(src, marks, PROMO, PROMO_SIZE, out / "play_promo.mp4")


if __name__ == "__main__":
    main()
