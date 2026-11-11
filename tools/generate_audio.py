"""Generate original, dependency-free mono sound design for The Ashen Bough."""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / "audio"
ROOT.mkdir(exist_ok=True)
RATE = 22050
random.seed(719)

def save(name, seconds, sample):
    values = []
    for i in range(int(RATE * seconds)):
        t = i / RATE
        x = max(-1, min(1, sample(t, seconds)))
        values.append(struct.pack("<h", int(x * 24000)))
    with wave.open(str(ROOT / (name + ".wav")), "wb") as f:
        f.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        f.writeframes(b"".join(values))

def sine(f, t):
    return math.sin(math.tau * f * t)

def noise():
    return random.uniform(-1, 1)

save("swing", .26, lambda t, d: noise() * math.sin(math.pi * t / d) ** 2 * .45 + sine(120 - 180 * t, t) * .12)
save("dodge", .3, lambda t, d: noise() * math.sin(math.pi * t / d) * .2)
save("hit", .26, lambda t, d: (noise() * .55 + sine(140, t) * .4) * math.exp(-t * 24))
save("hurt", .4, lambda t, d: (sine(72 - 50 * t, t) * .6 + noise() * .2) * math.exp(-t * 10))
save("slam", .65, lambda t, d: (sine(48, t) * .65 + noise() * .3) * math.exp(-t * 8))
save("warning", .42, lambda t, d: sine(182, t) * sine(29, t) * math.sin(math.pi * t / d) * .22)
save("parry", .8, lambda t, d: (sine(784, t) + sine(1175, t) * .5 + sine(2153, t) * .2) * math.exp(-t * 7) * .42)
save("heal", 1.4, lambda t, d: (sine(220, t) + sine(330, t) * .5 + sine(440, t) * .25) * math.sin(math.pi * t / d) * .18)
save("menu", .18, lambda t, d: sine(440, t) * math.exp(-t * 35) * .3)
save("clear", 2.8, lambda t, d: (sine(130.81, t) + sine(196, t) * .6 + sine(261.63, t) * .35) * math.exp(-t * 1.8) * .3)
save("death", 2.0, lambda t, d: (sine(65.41, t) + sine(69.3, t) * .5) * math.sin(math.pi * t / d) * .35)
save("atmosphere", 12, lambda t, d: (sine(55, t) * .3 + sine(82.5, t) * .16 + sine(110, t) * .06 + noise() * .015) * (.65 + .15 * sine(1/12, t)))
print("Generated 12 original WAV assets in", ROOT)
