#!/usr/bin/env python3
"""Builds the landscape product rundown video (1920×1080, 30 fps, silent).

    tool/creative/make_promo.py

Gameplay comes from ../logic-sprint-release/demo/out/play_promo.mp4 (made by
tool/cut_demo.py iphone). Each scene's background is tool/creative/promo.html
rendered by headless Chrome; the gameplay is laid into the phone screen with
rounded corners and a Dynamic Island, then the scenes are crossfaded together.
Writes ../logic-sprint-release/demo/out/promo_landscape.mp4.
"""
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent.parent
DEMO = ROOT.parent / "logic-sprint-release" / "demo" / "out"
SRC = DEMO / "play_promo.mp4"
OUT = DEMO / "promo_landscape.mp4"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Phone screen in promo.html, and the gameplay inside play_promo.mp4
# (884×1920 centred on a 1080-wide black canvas).
SCREEN_X, SCREEN_Y, SCREEN_W, SCREEN_H, RADIUS = 1240, 80, 416, 920, 50
ISLAND_W, ISLAND_H, ISLAND_TOP = 137, 39, 15
GAMEPLAY = "crop=884:1920:98:0,scale=424:920,crop=416:920:4:0"

FADE = 0.5
# (scene, start s in play_promo.mp4 or None for a title card, length s)
SCENES = [
    ("intro", None, 3.0),
    ("home", 0.1, 3.8),
    ("rocket", 6.8, 12.0),
    ("memory", 30.2, 14.0),
    ("math", 53.0, 10.0),
    ("color", 66.0, 12.0),
    ("ranks", 85.6, 4.8),
    ("profile", 90.7, 3.8),
    ("outro", None, 4.0),
]


def run(*args):
    subprocess.run(args, check=True)


def main():
    tmp = Path(tempfile.mkdtemp(prefix="promo_"))

    mask = Image.new("L", (SCREEN_W, SCREEN_H), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, SCREEN_W - 1, SCREEN_H - 1), RADIUS, fill=255)
    mask.save(tmp / "mask.png")
    island = Image.new("RGBA", (ISLAND_W, ISLAND_H), (0, 0, 0, 0))
    ImageDraw.Draw(island).rounded_rectangle((0, 0, ISLAND_W - 1, ISLAND_H - 1), ISLAND_H // 2, fill=(0, 0, 0, 255))
    island.save(tmp / "island.png")

    clips = []
    for name, start, length in SCENES:
        bg = tmp / f"{name}.png"
        run(CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
            "--force-device-scale-factor=1", "--allow-file-access-from-files",
            "--virtual-time-budget=3000", "--window-size=1920,1080",
            f"--screenshot={bg}", f"file://{ROOT}/tool/creative/promo.html?scene={name}")
        clip = tmp / f"{name}.mp4"
        enc = ["-r", "30", "-c:v", "libx264", "-preset", "slow", "-crf", "16", "-pix_fmt", "yuv420p", str(clip)]
        if start is None:
            run("ffmpeg", "-loglevel", "error", "-y", "-loop", "1", "-t", str(length), "-i", str(bg), *enc)
        else:
            ix = SCREEN_X + (SCREEN_W - ISLAND_W) // 2
            graph = (
                f"[1:v]{GAMEPLAY},setsar=1,format=rgba[g];[2:v]format=gray[m];[g][m]alphamerge[s];"
                f"[0:v][s]overlay={SCREEN_X}:{SCREEN_Y}[a];[a][3:v]overlay={ix}:{SCREEN_Y + ISLAND_TOP}"
            )
            run("ffmpeg", "-loglevel", "error", "-y",
                "-loop", "1", "-t", str(length), "-i", str(bg),
                "-ss", str(start), "-t", str(length), "-i", str(SRC),
                "-loop", "1", "-t", str(length), "-i", str(tmp / "mask.png"),
                "-loop", "1", "-t", str(length), "-i", str(tmp / "island.png"),
                "-filter_complex", graph, "-t", str(length), *enc)
        clips.append((clip, length))

    # Crossfade the scenes together, then add a silent stereo track.
    inputs, parts, last, offset = [], [], "[0:v]", 0.0
    for i, (clip, _) in enumerate(clips):
        inputs += ["-i", str(clip)]
    for i in range(1, len(clips)):
        offset += clips[i - 1][1] - FADE
        label = f"[x{i}]"
        parts.append(f"{last}[{i}:v]xfade=transition=fade:duration={FADE}:offset={offset:.3f}{label}")
        last = label
    graph = ";".join(parts) + f";{last}fade=t=in:d=0.4,format=yuv420p[v]"
    run("ffmpeg", "-loglevel", "error", "-y", *inputs,
        "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000",
        "-filter_complex", graph, "-map", "[v]", "-map", f"{len(clips)}:a",
        "-c:v", "libx264", "-profile:v", "high", "-preset", "slow", "-crf", "18",
        "-c:a", "aac", "-b:a", "128k", "-shortest", "-movflags", "+faststart", str(OUT))
    print(OUT)


if __name__ == "__main__":
    main()
