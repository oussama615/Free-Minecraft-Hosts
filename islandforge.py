#!/usr/bin/env python3
"""IslandForge: generate themed Minecraft island schematics from an image mask and prompt.

The tool can read/write PNG masks and previews with the Python standard
library. Pillow is optional but recommended because it also enables JPG input
and higher-quality image resizing. Schematic generation is self-contained NBT
and gzip encoding.
"""

from __future__ import annotations

import argparse
import gzip
import json
import math
import os
import random
import struct
import zlib
from collections import deque
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Tuple

try:
    from PIL import Image
except ImportError:  # Pillow is optional for PNG-only workflows.
    Image = None


DETAILS = {
    "simple": {"trees": 0.010, "decor": 0.003, "passes": 1, "feature_scale": 0.65},
    "balanced": {"trees": 0.018, "decor": 0.006, "passes": 2, "feature_scale": 1.0},
    "detailed": {"trees": 0.032, "decor": 0.010, "passes": 3, "feature_scale": 1.35},
    "epic": {"trees": 0.050, "decor": 0.017, "passes": 4, "feature_scale": 1.8},
}

THEMES = {
    "starter": {
        "top": "minecraft:grass_block",
        "filler": "minecraft:dirt",
        "base": "minecraft:stone",
        "accent": "minecraft:cobblestone",
        "path": "minecraft:coarse_dirt",
        "wood": "minecraft:oak_log",
        "leaves": "minecraft:oak_leaves[persistent=true]",
        "flower": "minecraft:poppy",
        "color": (92, 151, 68),
    },
    "mine": {
        "top": "minecraft:stone",
        "filler": "minecraft:andesite",
        "base": "minecraft:deepslate",
        "accent": "minecraft:iron_ore",
        "path": "minecraft:gravel",
        "wood": "minecraft:spruce_log",
        "leaves": "minecraft:spruce_leaves[persistent=true]",
        "flower": "minecraft:lantern[hanging=false]",
        "color": (96, 96, 94),
    },
    "desert": {
        "top": "minecraft:sand",
        "filler": "minecraft:sandstone",
        "base": "minecraft:terracotta",
        "accent": "minecraft:chiseled_sandstone",
        "path": "minecraft:smooth_sandstone",
        "wood": "minecraft:acacia_log",
        "leaves": "minecraft:dead_bush",
        "flower": "minecraft:cactus",
        "color": (213, 190, 116),
    },
    "jungle": {
        "top": "minecraft:moss_block",
        "filler": "minecraft:dirt",
        "base": "minecraft:stone",
        "accent": "minecraft:mossy_cobblestone",
        "path": "minecraft:rooted_dirt",
        "wood": "minecraft:jungle_log",
        "leaves": "minecraft:jungle_leaves[persistent=true]",
        "flower": "minecraft:fern",
        "color": (58, 128, 54),
    },
    "frost": {
        "top": "minecraft:snow_block",
        "filler": "minecraft:packed_ice",
        "base": "minecraft:stone",
        "accent": "minecraft:blue_ice",
        "path": "minecraft:snow_block",
        "wood": "minecraft:spruce_log",
        "leaves": "minecraft:spruce_leaves[persistent=true]",
        "flower": "minecraft:ice",
        "color": (170, 218, 232),
    },
    "arena": {
        "top": "minecraft:smooth_stone",
        "filler": "minecraft:stone_bricks",
        "base": "minecraft:deepslate_bricks",
        "accent": "minecraft:red_nether_bricks",
        "path": "minecraft:polished_andesite",
        "wood": "minecraft:dark_oak_log",
        "leaves": "minecraft:chain",
        "flower": "minecraft:torch",
        "color": (128, 116, 112),
    },
    "ancient": {
        "top": "minecraft:mossy_stone_bricks",
        "filler": "minecraft:stone_bricks",
        "base": "minecraft:cracked_stone_bricks",
        "accent": "minecraft:chiseled_stone_bricks",
        "path": "minecraft:cobblestone",
        "wood": "minecraft:dark_oak_log",
        "leaves": "minecraft:vine",
        "flower": "minecraft:glow_lichen",
        "color": (91, 111, 84),
    },
}

FEATURE_KEYWORDS = {
    "ruins": {"ruin", "ruins", "ruined", "broken"},
    "trees": {"tree", "trees", "forest", "foliage", "jungle", "grove"},
    "paths": {"path", "paths", "road", "trail", "walkway"},
    "caves": {"cave", "caves", "hidden cave", "cavern"},
    "docks": {"dock", "docks", "pier", "harbor", "boat"},
    "temples": {"temple", "shrine", "sanctuary"},
    "boss_area": {"boss", "boss area", "arena", "final"},
    "mob_area": {"mob", "mobs", "spawn", "camp"},
    "towers": {"tower", "towers", "watchtower"},
    "statues": {"statue", "statues", "monument", "idol"},
}


@dataclass
class Feature:
    kind: str
    x: int
    y: int
    z: int
    radius: int = 0


class Schematic:
    def __init__(self, width: int, height: int, length: int) -> None:
        self.width = width
        self.height = height
        self.length = length
        self.palette: Dict[str, int] = {"minecraft:air": 0}
        self.blocks = bytearray(width * height * length)

    def _idx(self, x: int, y: int, z: int) -> int:
        return (y * self.length + z) * self.width + x

    def palette_id(self, block: str) -> int:
        if block not in self.palette:
            self.palette[block] = len(self.palette)
        return self.palette[block]

    def set(self, x: int, y: int, z: int, block: str) -> None:
        if 0 <= x < self.width and 0 <= y < self.height and 0 <= z < self.length:
            pid = self.palette_id(block)
            if pid > 255:
                raise ValueError("Palette exceeded 255 blocks; byte storage needs widening")
            self.blocks[self._idx(x, y, z)] = pid

    def get(self, x: int, y: int, z: int) -> str:
        inv = {v: k for k, v in self.palette.items()}
        return inv[self.blocks[self._idx(x, y, z)]]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate themed Minecraft islands from an image mask and text prompt.")
    parser.add_argument("image", help="PNG/JPG top-down island mask. Bright/opaque pixels become land.")
    parser.add_argument("--prompt", required=True, help="Style and feature prompt, e.g. 'ruined jungle temple with docks'.")
    parser.add_argument("--theme", choices=sorted(THEMES), default="starter")
    parser.add_argument("--size", type=int, default=128, help="Island width and length in blocks.")
    parser.add_argument("--height", type=int, default=24, help="Maximum terrain relief in blocks.")
    parser.add_argument("--detail", choices=sorted(DETAILS), default="balanced")
    parser.add_argument("--output", required=True, help="Output WorldEdit/FAWE .schem path.")
    parser.add_argument("--layout", choices=("island", "spawn_hub"), default="island", help="Generation layout. Use spawn_hub for a structured RPG starter spawn island.")
    parser.add_argument("--seed", type=int, default=None, help="Optional deterministic seed. Defaults to image/prompt-derived seed.")
    return parser.parse_args()


def read_png_rgba(path: str) -> Tuple[int, int, List[Tuple[int, int, int, int]]]:
    data = Path(path).read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("not a PNG file")
    pos = 8
    width = height = color_type = bit_depth = None
    compressed = bytearray()
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        ctype = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if ctype == b"IHDR":
            width, height, bit_depth, color_type, compression, png_filter, interlace = struct.unpack(">IIBBBBB", chunk)
            if bit_depth != 8 or compression != 0 or png_filter != 0 or interlace != 0 or color_type not in {0, 2, 4, 6}:
                raise ValueError("unsupported PNG; use non-interlaced 8-bit grayscale/RGB/RGBA or install Pillow")
        elif ctype == b"IDAT":
            compressed.extend(chunk)
        elif ctype == b"IEND":
            break
    if width is None or height is None or color_type is None:
        raise ValueError("invalid PNG: missing IHDR")
    channels = {0: 1, 2: 3, 4: 2, 6: 4}[color_type]
    stride = width * channels
    raw = zlib.decompress(bytes(compressed))
    rows: List[bytearray] = []
    i = 0
    previous = bytearray(stride)
    for _ in range(height):
        filter_type = raw[i]
        i += 1
        scan = bytearray(raw[i:i + stride])
        i += stride
        for x in range(stride):
            left = scan[x - channels] if x >= channels else 0
            up = previous[x]
            up_left = previous[x - channels] if x >= channels else 0
            if filter_type == 1:
                scan[x] = (scan[x] + left) & 0xFF
            elif filter_type == 2:
                scan[x] = (scan[x] + up) & 0xFF
            elif filter_type == 3:
                scan[x] = (scan[x] + ((left + up) // 2)) & 0xFF
            elif filter_type == 4:
                p = left + up - up_left
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - up_left)
                scan[x] = (scan[x] + (left if pa <= pb and pa <= pc else up if pb <= pc else up_left)) & 0xFF
            elif filter_type != 0:
                raise ValueError(f"unsupported PNG filter: {filter_type}")
        rows.append(scan)
        previous = scan
    pixels: List[Tuple[int, int, int, int]] = []
    for row in rows:
        for x in range(0, stride, channels):
            if color_type == 0:
                g = row[x]
                pixels.append((g, g, g, 255))
            elif color_type == 2:
                pixels.append((row[x], row[x + 1], row[x + 2], 255))
            elif color_type == 4:
                g, a = row[x], row[x + 1]
                pixels.append((g, g, g, a))
            else:
                pixels.append((row[x], row[x + 1], row[x + 2], row[x + 3]))
    return width, height, pixels


def resize_rgba_nearest(width: int, height: int, pixels: Sequence[Tuple[int, int, int, int]], size: int) -> List[Tuple[int, int, int, int]]:
    out = []
    for z in range(size):
        src_z = min(height - 1, int(z * height / size))
        for x in range(size):
            src_x = min(width - 1, int(x * width / size))
            out.append(pixels[src_z * width + src_x])
    return out


def load_mask(path: str, size: int) -> List[List[bool]]:
    ext = Path(path).suffix.lower()
    if Image is not None:
        img = Image.open(path).convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
        source = [img.getpixel((x, z)) for z in range(size) for x in range(size)]
    elif ext == ".png":
        width, height, pixels = read_png_rgba(path)
        source = resize_rgba_nearest(width, height, pixels, size)
    else:
        raise SystemExit(
            "JPG input requires Pillow. Install it with: "
            "python -m pip install -r requirements-islandforge.txt"
        )
    mask: List[List[bool]] = [[False for _ in range(size)] for _ in range(size)]
    for z in range(size):
        for x in range(size):
            r, g, b, a = source[z * size + x]
            luminance = (r * 0.299 + g * 0.587 + b * 0.114)
            mask[z][x] = a > 24 and luminance > 42
    return mask


def smooth_mask(mask: List[List[bool]], passes: int) -> List[List[bool]]:
    size = len(mask)
    current = mask
    for _ in range(passes):
        nxt = [[False for _ in range(size)] for _ in range(size)]
        for z in range(size):
            for x in range(size):
                count = 0
                for dz in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        nz, nx = z + dz, x + dx
                        if 0 <= nz < size and 0 <= nx < size and current[nz][nx]:
                            count += 1
                nxt[z][x] = count >= (4 if current[z][x] else 5)
        current = nxt
    return current


def distance_to_edge(mask: List[List[bool]]) -> List[List[int]]:
    size = len(mask)
    inf = size * size
    dist = [[inf for _ in range(size)] for _ in range(size)]
    q: deque[Tuple[int, int]] = deque()
    for z in range(size):
        for x in range(size):
            if not mask[z][x] or x == 0 or z == 0 or x == size - 1 or z == size - 1:
                dist[z][x] = 0
                q.append((x, z))
    while q:
        x, z = q.popleft()
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, nz = x + dx, z + dz
            if 0 <= nx < size and 0 <= nz < size and dist[nz][nx] > dist[z][x] + 1:
                dist[nz][nx] = dist[z][x] + 1
                q.append((nx, nz))
    return dist


def hash_noise(x: float, z: float, seed: int) -> float:
    xi = int(math.floor(x * 1619))
    zi = int(math.floor(z * 31337))
    n = (xi * 374761393 + zi * 668265263 + seed * 1442695040888963407) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def value_noise(x: float, z: float, seed: int, octaves: int = 4) -> float:
    total = 0.0
    amp = 1.0
    freq = 1.0
    norm = 0.0
    for octave in range(octaves):
        sx, sz = x * freq, z * freq
        x0, z0 = math.floor(sx), math.floor(sz)
        tx, tz = sx - x0, sz - z0
        def h(ix: int, iz: int) -> float:
            return hash_noise(ix + octave * 17, iz - octave * 31, seed)
        a = h(x0, z0) * (1 - tx) + h(x0 + 1, z0) * tx
        b = h(x0, z0 + 1) * (1 - tx) + h(x0 + 1, z0 + 1) * tx
        total += (a * (1 - tz) + b * tz) * amp
        norm += amp
        amp *= 0.5
        freq *= 2.03
    return total / norm


def terrain_height(x: int, z: int, dist: int, max_dist: int, requested_height: int, seed: int, size: int) -> int:
    edge = 0.0 if max_dist == 0 else min(1.0, dist / max_dist)
    dome = math.sin(edge * math.pi / 2) ** 0.9
    n = value_noise(x / max(size, 1) * 5.0, z / max(size, 1) * 5.0, seed, 5)
    ridge = value_noise(x / max(size, 1) * 13.0, z / max(size, 1) * 13.0, seed + 99, 2)
    relief = requested_height * (0.18 + 0.72 * dome) + (n - 0.5) * requested_height * 0.28 + (ridge - 0.5) * 3
    return max(3, int(round(relief)))


def prompt_features(prompt: str, theme: str) -> List[str]:
    lower = prompt.lower()
    features = [name for name, words in FEATURE_KEYWORDS.items() if any(word in lower for word in words)]
    theme_defaults = {
        "starter": ["trees", "paths"],
        "mine": ["caves", "mob_area"],
        "desert": ["temples", "ruins"],
        "jungle": ["trees", "ruins", "temples"],
        "frost": ["towers", "caves"],
        "arena": ["boss_area", "mob_area"],
        "ancient": ["ruins", "statues", "temples"],
    }
    for default in theme_defaults[theme]:
        if default not in features:
            features.append(default)
    return features


def land_points(mask: List[List[bool]], heights: List[List[int]]) -> List[Tuple[int, int, int]]:
    return [(x, heights[z][x], z) for z, row in enumerate(mask) for x, land in enumerate(row) if land]


def choose_feature_spots(points: Sequence[Tuple[int, int, int]], features: Sequence[str], detail: str, rng: random.Random) -> List[Feature]:
    if not points:
        return []
    scale = DETAILS[detail]["feature_scale"]
    counts = {
        "ruins": max(1, round(scale)), "trees": 0, "paths": 1, "caves": max(1, round(scale)),
        "docks": 1, "temples": max(1, round(scale * 0.8)), "boss_area": 1,
        "mob_area": max(1, round(scale)), "towers": max(1, round(scale * 1.2)), "statues": max(1, round(scale)),
    }
    spots: List[Feature] = []
    for kind in features:
        for _ in range(counts.get(kind, 1)):
            x, y, z = rng.choice(points)
            spots.append(Feature(kind, x, y, z, radius=rng.randint(4, 9)))
    tree_count = int(len(points) * DETAILS[detail]["trees"])
    if "trees" in features:
        for _ in range(tree_count):
            x, y, z = rng.choice(points)
            spots.append(Feature("tree", x, y, z, radius=2))
    decor_count = int(len(points) * DETAILS[detail]["decor"])
    for _ in range(decor_count):
        x, y, z = rng.choice(points)
        spots.append(Feature("decor", x, y, z, radius=1))
    return spots


def build_terrain(mask: List[List[bool]], theme: Dict[str, object], requested_height: int, seed: int, layout: str = "island") -> Tuple[Schematic, List[List[int]]]:
    size = len(mask)
    dist = distance_to_edge(mask)
    max_dist = max((dist[z][x] for z in range(size) for x in range(size) if mask[z][x]), default=1)
    heights = [[0 for _ in range(size)] for _ in range(size)]
    world_height = max(16, requested_height + (44 if layout == "spawn_hub" else 24))
    schem = Schematic(size, world_height, size)
    for z in range(size):
        for x in range(size):
            if not mask[z][x]:
                continue
            surface = terrain_height(x, z, dist[z][x], max_dist, requested_height, seed, size) + 8
            heights[z][x] = min(surface, world_height - 8)
            thickness = int(4 + min(14, dist[z][x] * 0.55) + value_noise(x * 0.14, z * 0.14, seed + 7, 3) * 5)
            bottom = max(1, heights[z][x] - thickness)
            for y in range(bottom, heights[z][x] + 1):
                if layout == "spawn_hub":
                    surface_noise = value_noise(x * 0.09, z * 0.09, seed + 401, 3)
                    deep_noise = value_noise(x * 0.16, z * 0.16, seed + 402, 2)
                    if y == heights[z][x]:
                        if dist[z][x] < 4 and surface_noise > 0.54:
                            block = "minecraft:stone"
                        elif surface_noise > 0.82:
                            block = "minecraft:coarse_dirt"
                        elif surface_noise > 0.68:
                            block = "minecraft:rooted_dirt"
                        elif surface_noise < 0.18:
                            block = "minecraft:moss_block"
                        else:
                            block = str(theme["top"])
                    elif y >= heights[z][x] - 3:
                        if deep_noise > 0.78:
                            block = "minecraft:gravel"
                        elif deep_noise < 0.22:
                            block = "minecraft:coarse_dirt"
                        else:
                            block = str(theme["filler"])
                    else:
                        if deep_noise > 0.72:
                            block = "minecraft:andesite"
                        elif deep_noise < 0.20:
                            block = "minecraft:cobblestone"
                        else:
                            block = str(theme["base"])
                elif y == heights[z][x]:
                    block = str(theme["top"])
                elif y >= heights[z][x] - 3:
                    block = str(theme["filler"])
                else:
                    block = str(theme["base"])
                schem.set(x, y, z, block)
            # Ragged stone teeth under floating island edges.
            if dist[z][x] < max(3, max_dist * 0.2):
                drip = int(value_noise(x * 0.3, z * 0.3, seed + 12, 2) * 4)
                for y in range(max(0, bottom - drip), bottom):
                    schem.set(x, y, z, str(theme["base"]))
    return schem, heights


def flatten_disc(schem: Schematic, heights: List[List[int]], cx: int, cz: int, radius: int, block: str) -> int:
    ys = []
    for z in range(max(0, cz - radius), min(schem.length, cz + radius + 1)):
        for x in range(max(0, cx - radius), min(schem.width, cx + radius + 1)):
            if (x - cx) ** 2 + (z - cz) ** 2 <= radius ** 2 and heights[z][x] > 0:
                ys.append(heights[z][x])
    if not ys:
        return 0
    y = int(sum(ys) / len(ys))
    for z in range(max(0, cz - radius), min(schem.length, cz + radius + 1)):
        for x in range(max(0, cx - radius), min(schem.width, cx + radius + 1)):
            if (x - cx) ** 2 + (z - cz) ** 2 <= radius ** 2 and heights[z][x] > 0:
                for yy in range(max(1, y - 3), y + 1):
                    schem.set(x, yy, z, block)
                heights[z][x] = y
    return y


def add_tree(schem: Schematic, x: int, y: int, z: int, theme: Dict[str, object], rng: random.Random) -> None:
    trunk_h = rng.randint(4, 8)
    for yy in range(y + 1, y + trunk_h + 1):
        schem.set(x, yy, z, str(theme["wood"]))
    leaf = str(theme["leaves"])
    if "dead_bush" in leaf or "chain" in leaf or "vine" in leaf:
        schem.set(x, y + 1, z, leaf)
        return
    top = y + trunk_h
    for yy in range(top - 2, top + 2):
        radius = 2 if yy < top + 1 else 1
        for dz in range(-radius, radius + 1):
            for dx in range(-radius, radius + 1):
                if abs(dx) + abs(dz) <= radius + rng.randint(0, 1):
                    schem.set(x + dx, yy, z + dz, leaf)


def add_ruin(schem: Schematic, heights: List[List[int]], f: Feature, theme: Dict[str, object], rng: random.Random) -> None:
    y = flatten_disc(schem, heights, f.x, f.z, f.radius, str(theme["path"]))
    accent = str(theme["accent"])
    for ox, oz in ((-f.radius, -f.radius), (f.radius, -f.radius), (-f.radius, f.radius), (f.radius, f.radius)):
        h = rng.randint(2, 6)
        for yy in range(y + 1, y + h + 1):
            schem.set(f.x + ox, yy, f.z + oz, accent)
    for _ in range(f.radius * 3):
        dx, dz = rng.randint(-f.radius, f.radius), rng.randint(-f.radius, f.radius)
        if dx * dx + dz * dz <= f.radius * f.radius:
            schem.set(f.x + dx, y + 1, f.z + dz, accent)


def add_temple(schem: Schematic, heights: List[List[int]], f: Feature, theme: Dict[str, object], rng: random.Random) -> None:
    radius = max(5, f.radius)
    y = flatten_disc(schem, heights, f.x, f.z, radius, str(theme["accent"]))
    block = str(theme["accent"])
    for layer in range(3):
        r = radius - layer * 2
        for z in range(f.z - r, f.z + r + 1):
            for x in range(f.x - r, f.x + r + 1):
                if abs(x - f.x) == r or abs(z - f.z) == r or layer == 2:
                    schem.set(x, y + 1 + layer, z, block)
    for yy in range(y + 4, y + 8):
        schem.set(f.x, yy, f.z, block)


def add_tower(schem: Schematic, heights: List[List[int]], f: Feature, theme: Dict[str, object]) -> None:
    y = flatten_disc(schem, heights, f.x, f.z, 3, str(theme["accent"]))
    block = str(theme["accent"])
    for yy in range(y + 1, y + 12):
        for dx, dz in ((-2, -2), (2, -2), (-2, 2), (2, 2), (0, -2), (0, 2), (-2, 0), (2, 0)):
            schem.set(f.x + dx, yy, f.z + dz, block)
    for dx in range(-3, 4):
        for dz in range(-3, 4):
            if abs(dx) == 3 or abs(dz) == 3:
                schem.set(f.x + dx, y + 12, f.z + dz, block)


def add_statue(schem: Schematic, heights: List[List[int]], f: Feature, theme: Dict[str, object]) -> None:
    y = flatten_disc(schem, heights, f.x, f.z, 2, str(theme["path"]))
    block = str(theme["accent"])
    for yy in range(y + 1, y + 7):
        schem.set(f.x, yy, f.z, block)
    for dx in (-1, 1):
        for yy in range(y + 3, y + 5):
            schem.set(f.x + dx, yy, f.z, block)
    schem.set(f.x, y + 7, f.z, "minecraft:glowstone")


def add_cave(schem: Schematic, heights: List[List[int]], f: Feature, theme: Dict[str, object], rng: random.Random) -> None:
    direction = rng.choice(((1, 0), (-1, 0), (0, 1), (0, -1)))
    x, z = f.x, f.z
    for step in range(f.radius * 2):
        if not (0 <= x < schem.width and 0 <= z < schem.length) or heights[z][x] <= 0:
            break
        y = max(2, heights[z][x] - 3 - step // 4)
        for yy in range(y - 1, y + 3):
            for dx in range(-2, 3):
                for dz in range(-2, 3):
                    if dx * dx + dz * dz + (yy - y) ** 2 <= 6:
                        schem.set(x + dx, yy, z + dz, "minecraft:air")
        if step % 4 == 0:
            schem.set(x, y, z, str(theme["accent"]))
        x += direction[0]
        z += direction[1]


def add_dock(schem: Schematic, heights: List[List[int]], mask: List[List[bool]], theme: Dict[str, object]) -> None:
    edge = min(((x, z) for z in range(schem.length) for x in range(schem.width) if mask[z][x]), key=lambda p: min(p[0], p[1], schem.width - 1 - p[0], schem.length - 1 - p[1]), default=None)
    if edge is None:
        return
    x, z = edge
    y = heights[z][x]
    dx = -1 if x < schem.width / 2 else 1
    dz = -1 if z < schem.length / 2 else 1
    if min(x, schem.width - 1 - x) < min(z, schem.length - 1 - z):
        dz = 0
    else:
        dx = 0
    wood = str(theme["wood"])
    for i in range(12):
        px, pz = x + dx * i, z + dz * i
        for side in (-1, 0, 1):
            schem.set(px + (side if dz else 0), y, pz + (side if dx else 0), wood)
        if i % 4 == 0:
            schem.set(px, y + 1, pz, "minecraft:oak_fence")


def add_path(schem: Schematic, heights: List[List[int]], points: Sequence[Feature], theme: Dict[str, object]) -> None:
    if len(points) < 2:
        return
    path_block = str(theme["path"])
    anchors = points[: min(4, len(points))]
    for a, b in zip(anchors, anchors[1:]):
        steps = max(abs(a.x - b.x), abs(a.z - b.z), 1)
        for i in range(steps + 1):
            t = i / steps
            x = int(round(a.x * (1 - t) + b.x * t))
            z = int(round(a.z * (1 - t) + b.z * t))
            for dx in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    nx, nz = x + dx, z + dz
                    if 0 <= nx < schem.width and 0 <= nz < schem.length and heights[nz][nx] > 0:
                        schem.set(nx, heights[nz][nx], nz, path_block)


def add_boss_or_mob_area(schem: Schematic, heights: List[List[int]], f: Feature, theme: Dict[str, object], boss: bool) -> None:
    radius = 8 if boss else 5
    y = flatten_disc(schem, heights, f.x, f.z, radius, str(theme["path"]))
    accent = "minecraft:redstone_block" if boss else str(theme["accent"])
    for angle in range(0, 360, 30 if boss else 45):
        x = f.x + int(math.cos(math.radians(angle)) * radius)
        z = f.z + int(math.sin(math.radians(angle)) * radius)
        for yy in range(y + 1, y + (4 if boss else 3)):
            schem.set(x, yy, z, accent)
    schem.set(f.x, y + 1, f.z, "minecraft:beacon" if boss else "minecraft:spawner")


def apply_features(schem: Schematic, heights: List[List[int]], mask: List[List[bool]], features: List[Feature], theme: Dict[str, object], rng: random.Random) -> None:
    structural = [f for f in features if f.kind not in {"tree", "decor", "paths"}]
    for f in structural:
        if f.kind == "ruins":
            add_ruin(schem, heights, f, theme, rng)
        elif f.kind == "temples":
            add_temple(schem, heights, f, theme, rng)
        elif f.kind == "caves":
            add_cave(schem, heights, f, theme, rng)
        elif f.kind == "docks":
            add_dock(schem, heights, mask, theme)
        elif f.kind == "towers":
            add_tower(schem, heights, f, theme)
        elif f.kind == "statues":
            add_statue(schem, heights, f, theme)
        elif f.kind == "boss_area":
            add_boss_or_mob_area(schem, heights, f, theme, True)
        elif f.kind == "mob_area":
            add_boss_or_mob_area(schem, heights, f, theme, False)
    add_path(schem, heights, structural, theme)
    for f in features:
        if heights[f.z][f.x] <= 0:
            continue
        if f.kind == "tree":
            add_tree(schem, f.x, heights[f.z][f.x], f.z, theme, rng)
        elif f.kind == "decor":
            schem.set(f.x, heights[f.z][f.x] + 1, f.z, str(theme["flower"]))


SPAWN_PATH_BLOCK = "minecraft:stone_bricks"
SPAWN_PATH_BORDER = "minecraft:cobblestone"
SPAWN_PLAZA_BLOCK = "minecraft:polished_andesite"
SPAWN_PLAZA_DETAIL = "minecraft:chiseled_stone_bricks"


def point_meta(x: int, y: int, z: int, radius: int = 0) -> Dict[str, int]:
    data = {"x": x, "y": y, "z": z}
    if radius:
        data["radius"] = radius
    return data


def nearest_land(points: Sequence[Tuple[int, int, int]], tx: float, tz: float) -> Tuple[int, int, int]:
    if not points:
        return (0, 0, 0)
    return min(points, key=lambda p: (p[0] - tx) ** 2 + (p[2] - tz) ** 2)


def edge_land(points: Sequence[Tuple[int, int, int]], size: int, prefer: Tuple[float, float]) -> Tuple[int, int, int]:
    if not points:
        return (0, 0, 0)
    px, pz = prefer
    return min(
        points,
        key=lambda p: min(p[0], p[2], size - 1 - p[0], size - 1 - p[2]) * 8 + (p[0] - px) ** 2 * 0.01 + (p[2] - pz) ** 2 * 0.01,
    )


def set_surface_disc(schem: Schematic, heights: List[List[int]], cx: int, cz: int, radius: int, block: str, border: str | None = None) -> int:
    y = flatten_disc(schem, heights, cx, cz, radius, block)
    if y <= 0:
        return y
    for z in range(max(0, cz - radius), min(schem.length, cz + radius + 1)):
        for x in range(max(0, cx - radius), min(schem.width, cx + radius + 1)):
            d2 = (x - cx) ** 2 + (z - cz) ** 2
            if d2 <= radius ** 2 and heights[z][x] > 0:
                if border and radius - 2 <= math.sqrt(d2) <= radius:
                    schem.set(x, y, z, border)
                elif (x + z) % 11 == 0:
                    schem.set(x, y, z, SPAWN_PLAZA_DETAIL)
    return y


def raise_hill(schem: Schematic, heights: List[List[int]], cx: int, cz: int, radius: int, lift: int, theme: Dict[str, object]) -> int:
    peak = 0
    for z in range(max(0, cz - radius), min(schem.length, cz + radius + 1)):
        for x in range(max(0, cx - radius), min(schem.width, cx + radius + 1)):
            if heights[z][x] <= 0:
                continue
            d = math.sqrt((x - cx) ** 2 + (z - cz) ** 2)
            if d > radius:
                continue
            add = int(round(lift * (1.0 - d / radius) ** 1.25))
            if add <= 0:
                continue
            old = heights[z][x]
            new = min(schem.height - 8, old + add)
            for y in range(old + 1, new + 1):
                if y == new:
                    block = str(theme["top"])
                elif y >= new - 3:
                    block = "minecraft:coarse_dirt" if (x + y + z) % 3 == 0 else str(theme["filler"])
                else:
                    block = "minecraft:stone" if (x + z) % 2 == 0 else str(theme["base"])
                schem.set(x, y, z, block)
            heights[z][x] = new
            peak = max(peak, new)
    return peak


def path_between(schem: Schematic, heights: List[List[int]], a: Tuple[int, int, int], b: Tuple[int, int, int], width: int = 2) -> None:
    ax, _, az = a
    bx, _, bz = b
    steps = max(abs(ax - bx), abs(az - bz), 1)
    for i in range(steps + 1):
        t = i / steps
        x = int(round(ax * (1 - t) + bx * t))
        z = int(round(az * (1 - t) + bz * t))
        for dz in range(-width - 1, width + 2):
            for dx in range(-width - 1, width + 2):
                nx, nz = x + dx, z + dz
                if 0 <= nx < schem.width and 0 <= nz < schem.length and heights[nz][nx] > 0:
                    if abs(dx) == width + 1 or abs(dz) == width + 1:
                        schem.set(nx, heights[nz][nx], nz, SPAWN_PATH_BORDER)
                    elif dx * dx + dz * dz <= (width + 0.75) ** 2:
                        schem.set(nx, heights[nz][nx], nz, SPAWN_PATH_BLOCK if (nx + nz) % 5 else "minecraft:cracked_stone_bricks")


def add_plaza(schem: Schematic, heights: List[List[int]], center: Tuple[int, int, int], radius: int, main: bool) -> Dict[str, int]:
    x, _, z = center
    y = set_surface_disc(schem, heights, x, z, radius, SPAWN_PLAZA_BLOCK, SPAWN_PATH_BORDER)
    # Premium hub marker: fountain/notice monument for main, smaller waypoint for secondary.
    for yy in range(y + 1, y + (5 if main else 3)):
        schem.set(x, yy, z, "minecraft:chiseled_stone_bricks")
    if main:
        for dx, dz in ((2, 0), (-2, 0), (0, 2), (0, -2)):
            schem.set(x + dx, y + 1, z + dz, "minecraft:water")
            schem.set(x + dx, y, z + dz, "minecraft:quartz_block")
        schem.set(x, y + 5, z, "minecraft:lantern[hanging=false]")
    else:
        schem.set(x, y + 3, z, "minecraft:bell")
    return point_meta(x, y, z, radius)


def add_medieval_building(schem: Schematic, heights: List[List[int]], cx: int, cz: int, width: int, depth: int, floors: int, theme: Dict[str, object]) -> Dict[str, int]:
    half_w, half_d = width // 2, depth // 2
    ys = [heights[z][x] for z in range(max(0, cz - half_d), min(schem.length, cz + half_d + 1)) for x in range(max(0, cx - half_w), min(schem.width, cx + half_w + 1)) if heights[z][x] > 0]
    if not ys:
        return point_meta(cx, 0, cz)
    y = int(sum(ys) / len(ys))
    for z in range(max(0, cz - half_d), min(schem.length, cz + half_d + 1)):
        for x in range(max(0, cx - half_w), min(schem.width, cx + half_w + 1)):
            if heights[z][x] > 0:
                for yy in range(max(1, y - 2), y + 1):
                    schem.set(x, yy, z, "minecraft:cobblestone")
                heights[z][x] = y
    wall_h = floors * 4
    for yy in range(y + 1, y + wall_h + 1):
        for z in range(cz - half_d, cz + half_d + 1):
            for x in range(cx - half_w, cx + half_w + 1):
                edge = x in (cx - half_w, cx + half_w) or z in (cz - half_d, cz + half_d)
                corner = x in (cx - half_w, cx + half_w) and z in (cz - half_d, cz + half_d)
                if corner:
                    schem.set(x, yy, z, str(theme["wood"]))
                elif edge:
                    if yy % 4 == 3 and (x + z) % 4 == 0:
                        schem.set(x, yy, z, "minecraft:glass_pane")
                    else:
                        schem.set(x, yy, z, "minecraft:oak_planks" if yy % 2 else "minecraft:stripped_oak_log")
    roof_y = y + wall_h + 1
    for layer in range(half_w + 2):
        for z in range(cz - half_d - 1, cz + half_d + 2):
            for x in (cx - half_w - 1 + layer, cx + half_w + 1 - layer):
                schem.set(x, roof_y + layer, z, "minecraft:dark_oak_planks")
    schem.set(cx, y + 1, cz - half_d, "minecraft:oak_door[facing=north,half=lower]")
    schem.set(cx, y + 2, cz - half_d, "minecraft:oak_door[facing=north,half=upper]")
    return point_meta(cx, y, cz, max(width, depth) // 2)


def add_spawn_buildings(schem: Schematic, heights: List[List[int]], main: Tuple[int, int, int], points: Sequence[Tuple[int, int, int]], radius: int, theme: Dict[str, object], rng: random.Random) -> List[Dict[str, int]]:
    buildings: List[Dict[str, int]] = []
    for angle in range(20, 360, 45):
        tx = main[0] + math.cos(math.radians(angle)) * (radius + 11)
        tz = main[2] + math.sin(math.radians(angle)) * (radius + 11)
        x, _, z = nearest_land(points, tx, tz)
        width = rng.choice((7, 9, 9, 11))
        depth = rng.choice((7, 9, 11))
        floors = rng.choice((1, 2, 2))
        buildings.append(add_medieval_building(schem, heights, x, z, width, depth, floors, theme))
    return buildings


def add_windmill(schem: Schematic, heights: List[List[int]], center: Tuple[int, int, int], theme: Dict[str, object]) -> Dict[str, int]:
    x, _, z = center
    raise_hill(schem, heights, x, z, 13, 7, theme)
    y = set_surface_disc(schem, heights, x, z, 5, "minecraft:coarse_dirt", "minecraft:mossy_cobblestone")
    for yy in range(y + 1, y + 13):
        for dx in range(-2, 3):
            for dz in range(-2, 3):
                if abs(dx) == 2 or abs(dz) == 2:
                    schem.set(x + dx, yy, z + dz, "minecraft:stripped_spruce_log" if yy % 4 == 0 else "minecraft:white_wool")
    for layer in range(4):
        for dx in range(-4 + layer, 5 - layer):
            schem.set(x + dx, y + 13 + layer, z - 3, "minecraft:spruce_planks")
            schem.set(x + dx, y + 13 + layer, z + 3, "minecraft:spruce_planks")
    hub_y = y + 9
    schem.set(x, hub_y, z - 3, "minecraft:oak_log")
    for i in range(1, 7):
        schem.set(x, hub_y + i, z - 4, "minecraft:oak_fence")
        schem.set(x, hub_y - i, z - 4, "minecraft:oak_fence")
        schem.set(x + i, hub_y, z - 4, "minecraft:oak_fence")
        schem.set(x - i, hub_y, z - 4, "minecraft:oak_fence")
    return point_meta(x, y, z, 13)


def add_dock_area(schem: Schematic, heights: List[List[int]], dock: Tuple[int, int, int], theme: Dict[str, object]) -> Dict[str, int]:
    x, y, z = dock
    y = set_surface_disc(schem, heights, x, z, 6, "minecraft:smooth_stone", "minecraft:oak_planks") or y
    # Extend a broad travel pier outward from the nearest island edge.
    dx = -1 if x < schem.width / 2 else 1
    dz = -1 if z < schem.length / 2 else 1
    if min(x, schem.width - 1 - x) < min(z, schem.length - 1 - z):
        dz = 0
    else:
        dx = 0
    for i in range(16):
        px, pz = x + dx * i, z + dz * i
        for side in range(-2, 3):
            schem.set(px + (side if dz else 0), y, pz + (side if dx else 0), "minecraft:spruce_planks")
        if i % 4 == 0:
            schem.set(px, y + 1, pz, "minecraft:lantern[hanging=false]")
    schem.set(x, y + 1, z, "minecraft:bell")
    return point_meta(x, y, z, 6)


def add_boss_arena(schem: Schematic, heights: List[List[int]], center: Tuple[int, int, int], theme: Dict[str, object]) -> Dict[str, int]:
    x, _, z = center
    raise_hill(schem, heights, x, z, 16, 8, theme)
    y = set_surface_disc(schem, heights, x, z, 10, "minecraft:deepslate_tiles", "minecraft:red_nether_bricks")
    for angle in range(0, 360, 30):
        px = x + int(math.cos(math.radians(angle)) * 10)
        pz = z + int(math.sin(math.radians(angle)) * 10)
        for yy in range(y + 1, y + 6):
            schem.set(px, yy, pz, "minecraft:polished_blackstone_bricks")
        schem.set(px, y + 6, pz, "minecraft:soul_lantern[hanging=false]")
    schem.set(x, y + 1, z, "minecraft:beacon")
    return point_meta(x, y, z, 10)


def add_npc_spots(schem: Schematic, heights: List[List[int]], main: Tuple[int, int, int], secondary: Tuple[int, int, int], points: Sequence[Tuple[int, int, int]], main_radius: int, secondary_radius: int) -> List[Dict[str, int]]:
    targets: List[Tuple[float, float]] = []
    for angle in range(0, 360, 45):
        targets.append((main[0] + math.cos(math.radians(angle)) * (main_radius + 4), main[2] + math.sin(math.radians(angle)) * (main_radius + 4)))
    for angle in (45, 135, 225, 315):
        targets.append((secondary[0] + math.cos(math.radians(angle)) * (secondary_radius + 3), secondary[2] + math.sin(math.radians(angle)) * (secondary_radius + 3)))
    spots: List[Dict[str, int]] = []
    used: set[Tuple[int, int]] = set()
    for tx, tz in targets[:12]:
        x, _, z = nearest_land(points, tx, tz)
        if (x, z) in used:
            x, _, z = nearest_land(points, tx + 3, tz + 3)
        used.add((x, z))
        y = heights[z][x]
        for dx in range(-1, 2):
            for dz in range(-1, 2):
                if 0 <= x + dx < schem.width and 0 <= z + dz < schem.length and heights[z + dz][x + dx] > 0:
                    schem.set(x + dx, heights[z + dz][x + dx], z + dz, "minecraft:smooth_stone")
        schem.set(x, y + 1, z, "minecraft:barrel")
        schem.set(x, y + 2, z, "minecraft:lantern[hanging=false]")
        spots.append(point_meta(x, y, z, 1))
    return spots


def apply_spawn_hub_layout(schem: Schematic, heights: List[List[int]], mask: List[List[bool]], theme: Dict[str, object], prompt: str, rng: random.Random) -> Dict[str, object]:
    points = land_points(mask, heights)
    # Prompt flavor is applied first; fixed hub structures are stamped afterward
    # so plaza/path readability always wins over decorative noise.
    hub_prompt_features = prompt_features(prompt + " trees statues ruins paths", "starter")
    flavor = [name for name in hub_prompt_features if name in {"trees", "statues", "ruins", "caves"}]
    flavor_features = choose_feature_spots(points, flavor, "balanced", rng)
    apply_features(schem, heights, mask, flavor_features, theme, rng)

    size = schem.width
    main = nearest_land(points, size * 0.50, size * 0.50)
    secondary = nearest_land(points, size * 0.30, size * 0.68)
    windmill = nearest_land(points, size * 0.72, size * 0.28)
    boss = nearest_land(points, size * 0.75, size * 0.72)
    dock = edge_land(points, size, (size * 0.50, size * 0.95))

    main_radius = max(10, size // 11)
    secondary_radius = max(7, size // 16)
    main_meta = add_plaza(schem, heights, main, main_radius, True)
    secondary_meta = add_plaza(schem, heights, secondary, secondary_radius, False)
    windmill_meta = add_windmill(schem, heights, windmill, theme)
    boss_meta = add_boss_arena(schem, heights, boss, theme)
    dock_meta = add_dock_area(schem, heights, dock, theme)

    anchors = [
        (main_meta["x"], main_meta["y"], main_meta["z"]),
        (secondary_meta["x"], secondary_meta["y"], secondary_meta["z"]),
        (windmill_meta["x"], windmill_meta["y"], windmill_meta["z"]),
        (boss_meta["x"], boss_meta["y"], boss_meta["z"]),
        (dock_meta["x"], dock_meta["y"], dock_meta["z"]),
    ]
    for anchor in anchors[1:]:
        path_between(schem, heights, anchors[0], anchor, width=2)
    path_between(schem, heights, anchors[1], anchors[4], width=2)

    buildings = add_spawn_buildings(schem, heights, anchors[0], points, main_radius, theme, rng)
    npc_spots = add_npc_spots(schem, heights, anchors[0], anchors[1], points, main_radius, secondary_radius)
    for npc in npc_spots:
        path_between(schem, heights, anchors[0], (npc["x"], npc["y"], npc["z"]), width=1)

    return {
        "main_plaza": main_meta,
        "secondary_plaza": secondary_meta,
        "npc_spots": npc_spots,
        "boss_arena": boss_meta,
        "dock_area": dock_meta,
        "windmill_area": windmill_meta,
        "buildings": buildings,
        "hub_paths": [point_meta(*anchor) for anchor in anchors],
        "style_notes": "Prompt details are layered onto a fixed premium RPG starter spawn hub layout.",
    }


def write_varints(ids: Iterable[int]) -> bytes:
    out = bytearray()
    for value in ids:
        v = value
        while True:
            temp = v & 0x7F
            v >>= 7
            if v:
                out.append(temp | 0x80)
            else:
                out.append(temp)
                break
    return bytes(out)


def nbt_string_payload(value: str) -> bytes:
    raw = value.encode("utf-8")
    return struct.pack(">H", len(raw)) + raw


def nbt_named(tag: int, name: str, payload: bytes) -> bytes:
    return bytes([tag]) + nbt_string_payload(name) + payload


def nbt_compound(items: Sequence[bytes]) -> bytes:
    return b"".join(items) + b"\x00"


def nbt_int(value: int) -> bytes:
    return struct.pack(">i", value)


def nbt_short(value: int) -> bytes:
    return struct.pack(">h", value)


def nbt_int_array(values: Sequence[int]) -> bytes:
    return struct.pack(">i", len(values)) + b"".join(struct.pack(">i", v) for v in values)


def nbt_byte_array(values: bytes) -> bytes:
    return struct.pack(">i", len(values)) + values


def write_schem(schem: Schematic, path: str, metadata: Dict[str, object]) -> None:
    palette_items = [nbt_named(3, name, nbt_int(pid)) for name, pid in sorted(schem.palette.items(), key=lambda item: item[1])]
    metadata_items = [
        nbt_named(8, "Name", nbt_string_payload("IslandForge island")),
        nbt_named(8, "Generator", nbt_string_payload("IslandForge")),
        nbt_named(8, "Theme", nbt_string_payload(str(metadata["theme"]))),
        nbt_named(8, "Prompt", nbt_string_payload(str(metadata["prompt"]))),
    ]
    schematic_payload = nbt_compound([
        nbt_named(3, "Version", nbt_int(2)),
        nbt_named(3, "DataVersion", nbt_int(3465)),
        nbt_named(2, "Width", nbt_short(schem.width)),
        nbt_named(2, "Height", nbt_short(schem.height)),
        nbt_named(2, "Length", nbt_short(schem.length)),
        nbt_named(11, "Offset", nbt_int_array([0, 0, 0])),
        nbt_named(10, "Palette", nbt_compound(palette_items)),
        nbt_named(7, "BlockData", nbt_byte_array(write_varints(schem.blocks))),
        nbt_named(10, "Metadata", nbt_compound(metadata_items)),
    ])
    root = nbt_named(10, "Schematic", schematic_payload)
    with gzip.open(path, "wb") as fh:
        fh.write(root)


def write_rgb_png(path: str, width: int, height: int, pixels: Sequence[Tuple[int, int, int]]) -> None:
    rows = bytearray()
    for z in range(height):
        rows.append(0)
        for x in range(width):
            rows.extend(bytes(pixels[z * width + x]))
    def chunk(kind: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(rows), 9))
    png += chunk(b"IEND", b"")
    Path(path).write_bytes(png)


def write_preview(path: str, mask: List[List[bool]], heights: List[List[int]], features: Sequence[Feature], theme: Dict[str, object]) -> None:
    size = len(mask)
    max_h = max((h for row in heights for h in row), default=1)
    base = tuple(theme["color"])  # type: ignore[arg-type]
    pixels: List[Tuple[int, int, int]] = [(20, 24, 35) for _ in range(size * size)]
    for z in range(size):
        for x in range(size):
            if mask[z][x] and heights[z][x] > 0:
                shade = 0.62 + 0.45 * heights[z][x] / max_h
                pixels[z * size + x] = tuple(min(255, int(c * shade)) for c in base)
    colors = {"tree": (35, 105, 38), "ruins": (170, 170, 150), "temples": (230, 205, 120), "caves": (10, 10, 12), "docks": (130, 83, 45), "boss_area": (220, 35, 35), "mob_area": (150, 45, 180), "towers": (210, 210, 210), "statues": (115, 180, 180), "decor": (245, 215, 90), "main_plaza": (235, 235, 210), "secondary_plaza": (190, 190, 180), "npc_spot": (80, 220, 255), "boss_arena": (230, 40, 40), "dock_area": (155, 95, 45), "windmill_area": (240, 240, 160)}
    for f in features:
        r = max(1, min(5, f.radius // 2))
        color = colors.get(f.kind, (255, 255, 255))
        for dz in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dz * dz <= r * r:
                    x, z = f.x + dx, f.z + dz
                    if 0 <= x < size and 0 <= z < size:
                        pixels[z * size + x] = color
    scale = max(1, min(4, 1024 // max(size, 1)))
    if Image is not None:
        img = Image.new("RGB", (size, size))
        img.putdata(pixels)
        img.resize((size * scale, size * scale), Image.Resampling.NEAREST).save(path)
    else:
        if scale > 1:
            big: List[Tuple[int, int, int]] = []
            for z in range(size):
                row: List[Tuple[int, int, int]] = []
                for x in range(size):
                    row.extend([pixels[z * size + x]] * scale)
                for _ in range(scale):
                    big.extend(row)
            write_rgb_png(path, size * scale, size * scale, big)
        else:
            write_rgb_png(path, size, size, pixels)


def island_seed(image_path: str, prompt: str, theme: str, layout: str, explicit: int | None) -> int:
    if explicit is not None:
        return explicit
    payload = f"{Path(image_path).name}|{prompt}|{theme}|{layout}"
    seed = 0x811C9DC5
    for b in payload.encode("utf-8"):
        seed ^= b
        seed = (seed * 0x01000193) & 0xFFFFFFFF
    return seed


def validate_args(args: argparse.Namespace) -> None:
    if args.size < 16 or args.size > 512:
        raise SystemExit("--size must be between 16 and 512 blocks")
    if args.height < 6 or args.height > 128:
        raise SystemExit("--height must be between 6 and 128 blocks")
    if not Path(args.image).is_file():
        raise SystemExit(f"Input image not found: {args.image}")


def main() -> int:
    args = parse_args()
    validate_args(args)
    seed = island_seed(args.image, args.prompt, args.theme, args.layout, args.seed)
    rng = random.Random(seed)
    detail = DETAILS[args.detail]
    mask = smooth_mask(load_mask(args.image, args.size), int(detail["passes"]))
    theme = THEMES[args.theme]
    schem, heights = build_terrain(mask, theme, args.height, seed, args.layout)
    points = land_points(mask, heights)
    feature_names = prompt_features(args.prompt, args.theme)
    layout_metadata: Dict[str, object] = {}
    if args.layout == "spawn_hub":
        layout_metadata = apply_spawn_hub_layout(schem, heights, mask, theme, args.prompt, rng)
        features = [
            Feature("main_plaza", int(layout_metadata["main_plaza"]["x"]), int(layout_metadata["main_plaza"]["y"]), int(layout_metadata["main_plaza"]["z"]), int(layout_metadata["main_plaza"]["radius"])),
            Feature("secondary_plaza", int(layout_metadata["secondary_plaza"]["x"]), int(layout_metadata["secondary_plaza"]["y"]), int(layout_metadata["secondary_plaza"]["z"]), int(layout_metadata["secondary_plaza"]["radius"])),
            Feature("boss_arena", int(layout_metadata["boss_arena"]["x"]), int(layout_metadata["boss_arena"]["y"]), int(layout_metadata["boss_arena"]["z"]), int(layout_metadata["boss_arena"]["radius"])),
            Feature("dock_area", int(layout_metadata["dock_area"]["x"]), int(layout_metadata["dock_area"]["y"]), int(layout_metadata["dock_area"]["z"]), int(layout_metadata["dock_area"]["radius"])),
            Feature("windmill_area", int(layout_metadata["windmill_area"]["x"]), int(layout_metadata["windmill_area"]["y"]), int(layout_metadata["windmill_area"]["z"]), int(layout_metadata["windmill_area"]["radius"])),
        ]
        for spot in layout_metadata["npc_spots"]:
            features.append(Feature("npc_spot", int(spot["x"]), int(spot["y"]), int(spot["z"]), int(spot["radius"])))
    else:
        features = choose_feature_spots(points, feature_names, args.detail, rng)
        apply_features(schem, heights, mask, features, theme, rng)

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    preview = output.with_suffix(".preview.png")
    meta_path = output.with_suffix(".metadata.json")
    metadata = {
        "tool": "IslandForge",
        "image": os.path.abspath(args.image),
        "prompt": args.prompt,
        "theme": args.theme,
        "size": args.size,
        "height": args.height,
        "detail": args.detail,
        "layout": args.layout,
        "seed": seed,
        "schematic": os.path.abspath(output),
        "preview": os.path.abspath(preview),
        "features_requested": feature_names,
        "features_placed": [f.__dict__ for f in features],
        **layout_metadata,
        "palette": sorted(schem.palette),
        "format": "Sponge schematic v2 (.schem), gzip-compressed NBT",
    }
    write_schem(schem, str(output), metadata)
    write_preview(str(preview), mask, heights, features, theme)
    meta_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    print(f"IslandForge generated {output}")
    print(f"Preview: {preview}")
    print(f"Metadata: {meta_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
