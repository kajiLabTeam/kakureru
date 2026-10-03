#!/usr/bin/env python3
"""かくれるガチャの効果音(assets/sounds/gacha/*.wav)を合成して書き出す。

外部の音源素材は使わず、正弦波・矩形波・ノイズの足し合わせだけで作る
(このリポジトリの自作物なので、他者のライセンス表記は要らない)。
出どころとライセンスの記録は docs/gacha-sounds.md。

長さとタイミングは演出(lib/features/mission/view/gacha/)に合わせてある:
- turning.wav  ハンドルを回す段(1.5秒)のカチカチ
- heat.wav     激熱の段(1.4秒)の低い溜め
- drop.wav     カプセルが落ちて2回弾む(0.8秒。着地 0.464秒・0.704秒)
- fanfare.wav  確定(当たり)のファンファーレ
- miss.wav     ハズレの短く低い音(演出 0.7秒より短く)

標準ライブラリだけで動く。使い方: python3 scripts/generate_gacha_sounds.py
"""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "sounds" / "gacha"


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def mix(buf, samples, at):
    """bufのat秒の位置にsamplesを足す(はみ出す分は捨てる)。"""
    start = int(RATE * at)
    for i, s in enumerate(samples):
        if start + i < len(buf):
            buf[start + i] += s


def tone(freq, seconds, decay=None, wave_type="sine", vibrato=0.0):
    out = []
    phase = 0.0
    for i in range(int(RATE * seconds)):
        t = i / RATE
        f = freq * (1 + vibrato * math.sin(2 * math.pi * 6 * t))
        phase += 2 * math.pi * f / RATE
        if wave_type == "square":
            # 奇数倍音を3つだけ足した、角の丸い矩形波(耳に刺さりにくい)。
            v = sum(math.sin(phase * k) / k for k in (1, 3, 5)) * 0.8
        elif wave_type == "brass":
            v = sum(math.sin(phase * k) / k for k in range(1, 7)) * 0.6
        else:
            v = math.sin(phase)
        env = math.exp(-t / decay) if decay else 1.0
        # 立ち上がり・切れ目のプチ音を消す短いフェード。
        env *= min(1.0, t / 0.004, (seconds - t) / 0.01)
        out.append(v * env)
    return out


def noise(seconds, decay):
    rng = random.Random(160)
    return [
        rng.uniform(-1, 1) * math.exp(-(i / RATE) / decay)
        for i in range(int(RATE * seconds))
    ]


def turning():
    """ハンドルのカチカチ。1.5秒に12回、少しずつ速く・強くする。"""
    buf = silence(1.5)
    count = 12
    for n in range(count):
        at = 1.45 * (n / count) ** 0.9
        gain = 0.45 + 0.4 * n / count
        click = [a * 0.6 + b * 0.5 for a, b in zip(noise(0.02, 0.003), tone(2600, 0.02, 0.005))]
        mix(buf, [s * gain for s in click], at)
    return buf


def heat():
    """激熱の溜め。低い唸りがうねりを速めながら膨らみ、最後に途切れる。"""
    seconds = 1.4
    out = []
    p1 = p2 = 0.0
    for i in range(int(RATE * seconds)):
        t = i / RATE
        rise = t / seconds
        p1 += 2 * math.pi * (52 + 30 * rise) / RATE
        p2 += 2 * math.pi * (78 + 45 * rise) / RATE
        v = math.sin(p1) + 0.6 * math.sin(p2) + 0.25 * math.sin(p1 * 3)
        tremolo = 0.6 + 0.4 * math.sin(2 * math.pi * (4 + 14 * rise) * t)
        env = (0.2 + 0.8 * rise**1.5) * min(1.0, (seconds - t) / 0.03)
        out.append(v * tremolo * env * 0.55)
    return out


def drop():
    """カプセルの「コロン」。着地と1回目の弾みで木を叩いたような音。"""
    buf = silence(0.8)
    for at, gain in ((0.464, 0.9), (0.704, 0.45)):
        knock = [
            a + 0.5 * b + 0.3 * c
            for a, b, c in zip(
                tone(820, 0.09, 0.03), tone(1310, 0.09, 0.02), noise(0.09, 0.004)
            )
        ]
        mix(buf, [s * gain for s in knock], at)
    return buf


def fanfare():
    """確定のファンファーレ。ド・ミ・ソと駆け上がって、高いドの和音を伸ばす。"""
    buf = silence(1.9)
    c5, e5, g5, c6 = 523.25, 659.25, 783.99, 1046.5
    for i, f in enumerate((c5, e5, g5)):
        mix(buf, [s * 0.45 for s in tone(f, 0.13, wave_type="brass")], i * 0.11)
    for f in (c5, e5, g5, c6):
        mix(buf, [s * 0.3 for s in tone(f, 1.5, decay=0.9, wave_type="brass", vibrato=0.006)], 0.36)
    # きらきら(高い音の細かい粒)。
    rng = random.Random(7)
    for n in range(10):
        f = rng.choice((2093.0, 2637.0, 3136.0))
        mix(buf, [s * 0.18 for s in tone(f, 0.12, 0.04)], 0.4 + n * 0.11)
    return buf


def miss():
    """ハズレの「ブッブー」。低い2音を下げて短く切る。"""
    buf = silence(0.5)
    mix(buf, [s * 0.5 for s in tone(196, 0.12, wave_type="square")], 0.0)
    mix(buf, [s * 0.5 for s in tone(147, 0.32, decay=0.25, wave_type="square")], 0.16)
    return buf


def write(name, samples):
    peak = max(abs(s) for s in samples) or 1.0
    scale = 0.85 / peak  # 音量をそろえる(どの音も最大値を85%に)。
    path = OUT_DIR / name
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(
            b"".join(struct.pack("<h", int(s * scale * 32767)) for s in samples)
        )
    print(f"wrote {path.relative_to(OUT_DIR.parent.parent.parent)}")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    write("turning.wav", turning())
    write("heat.wav", heat())
    write("drop.wav", drop())
    write("fanfare.wav", fanfare())
    write("miss.wav", miss())


if __name__ == "__main__":
    main()
