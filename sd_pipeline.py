#!/usr/bin/env python3
"""
SD → Aseprite Factory Pipeline

Generates pixel art scenes via Stable Diffusion, then processes them
through Aseprite Factory for game-ready tilesets and sprites.
"""

import argparse
import base64
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional
from urllib.request import Request, urlopen
from urllib.error import URLError

REPO_ROOT = Path(__file__).resolve().parent
ARTIFACTS_DIR = Path("/mnt/c/Users/hound/Pictures/Aseprite Factory")
TEMP_DIR = ARTIFACTS_DIR / "_sd_temp"

# SD WebUI API - default to Windows host from WSL
SD_API_BASE = os.environ.get("SD_API_URL", "http://172.26.32.1:7860")


def sd_api(endpoint: str, payload: Optional[dict] = None, timeout: int = 120) -> dict:
    """Make a request to the SD WebUI API."""
    url = f"{SD_API_BASE}{endpoint}"
    
    if payload:
        data = json.dumps(payload).encode("utf-8")
        req = Request(url, data=data, headers={"Content-Type": "application/json"})
    else:
        req = Request(url)
    
    try:
        with urlopen(req, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except URLError as e:
        raise RuntimeError(f"SD API error: {e}")


def generate_scene(
    prompt: str,
    negative_prompt: str = "",
    width: int = 512,
    height: int = 512,
    steps: int = 25,
    cfg_scale: float = 7.0,
    seed: int = -1,
) -> bytes:
    """Generate an image via txt2img and return PNG bytes."""
    
    # Light style hints (pixel art model handles the rest)
    style_prompt = f"{prompt}, game asset, clean pixels"
    style_negative = f"{negative_prompt}, blurry, noisy, artifacts"
    
    payload = {
        "prompt": style_prompt,
        "negative_prompt": style_negative,
        "width": width,
        "height": height,
        "steps": steps,
        "cfg_scale": cfg_scale,
        "seed": seed,
        "sampler_name": "DPM++ 2M Karras",
    }
    
    print(f"Generating: {prompt}")
    print(f"Size: {width}x{height}, Steps: {steps}, CFG: {cfg_scale}")
    
    result = sd_api("/sdapi/v1/txt2img", payload, timeout=300)
    
    if "images" not in result or not result["images"]:
        raise RuntimeError("No images returned from SD")
    
    # First image is the result
    image_b64 = result["images"][0]
    image_bytes = base64.b64decode(image_b64)
    
    # Extract seed from info
    info = json.loads(result.get("info", "{}"))
    actual_seed = info.get("seed", "unknown")
    print(f"Generated with seed: {actual_seed}")
    
    return image_bytes, actual_seed


def run_factory_job(job_spec: dict) -> Path:
    """Run an Aseprite Factory job and return the artifacts directory."""
    job_id = job_spec["job_id"]
    spec_path = TEMP_DIR / f"{job_id}_spec.json"
    
    # Write job spec
    spec_path.parent.mkdir(parents=True, exist_ok=True)
    with open(spec_path, "w") as f:
        json.dump(job_spec, f, indent=2)
    
    # Run factory
    result = subprocess.run(
        [sys.executable, str(REPO_ROOT / "run.py"), str(spec_path)],
        capture_output=True,
        text=True,
    )
    
    if result.returncode != 0:
        print("Factory stdout:", result.stdout)
        print("Factory stderr:", result.stderr)
        raise RuntimeError(f"Factory job failed with code {result.returncode}")
    
    print(result.stdout)
    return ARTIFACTS_DIR / job_id


def pipeline_tileset(
    prompt: str,
    job_id: Optional[str] = None,
    width: int = 512,
    height: int = 512,
    tile_size: int = 16,
    palette_size: int = 32,
    seed: int = -1,
) -> Path:
    """
    Generate a scene and slice it into a tileset.
    
    Returns the path to the artifacts directory.
    """
    if not job_id:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        job_id = f"sd_tileset_{timestamp}"
    
    # Ensure temp dir exists
    TEMP_DIR.mkdir(parents=True, exist_ok=True)
    
    # Generate the scene
    image_bytes, actual_seed = generate_scene(
        prompt=prompt,
        width=width,
        height=height,
        seed=seed,
    )
    
    # Save to temp
    temp_image = TEMP_DIR / f"{job_id}_source.png"
    with open(temp_image, "wb") as f:
        f.write(image_bytes)
    print(f"Saved source: {temp_image}")
    
    # Run slice_tileset
    job_spec = {
        "job_id": job_id,
        "task": "slice_tileset",
        "output_basename": "tileset",
        "params": {
            "input_file": str(temp_image),
            "tile_width": tile_size,
            "tile_height": tile_size,
            "palette_size": palette_size,
            "remove_dupes": True,
        }
    }
    
    artifacts_dir = run_factory_job(job_spec)
    
    # Copy source image to artifacts for reference
    import shutil
    shutil.copy(temp_image, artifacts_dir / "source.png")
    
    # Save generation info
    info = {
        "prompt": prompt,
        "seed": actual_seed,
        "width": width,
        "height": height,
        "tile_size": tile_size,
        "palette_size": palette_size,
    }
    with open(artifacts_dir / "generation_info.json", "w") as f:
        json.dump(info, f, indent=2)
    
    print(f"\n✓ Tileset generated: {artifacts_dir}")
    return artifacts_dir


def pipeline_sprite(
    prompt: str,
    job_id: Optional[str] = None,
    sd_size: int = 512,
    target_width: int = 32,
    target_height: int = 32,
    palette_size: int = 16,
    gen_walkcycle: bool = False,
    seed: int = -1,
) -> Path:
    """
    Generate a character/object and convert it to a game sprite.
    
    Returns the path to the artifacts directory.
    """
    if not job_id:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        job_id = f"sd_sprite_{timestamp}"
    
    # Ensure temp dir exists
    TEMP_DIR.mkdir(parents=True, exist_ok=True)
    
    # Generate the image (square for sprites)
    image_bytes, actual_seed = generate_scene(
        prompt=prompt,
        width=sd_size,
        height=sd_size,
        seed=seed,
    )
    
    # Save to temp
    temp_image = TEMP_DIR / f"{job_id}_source.png"
    with open(temp_image, "wb") as f:
        f.write(image_bytes)
    print(f"Saved source: {temp_image}")
    
    # Run process_sprite
    job_spec = {
        "job_id": job_id,
        "task": "process_sprite",
        "output_basename": "sprite",
        "params": {
            "input_file": str(temp_image),
            "target_width": target_width,
            "target_height": target_height,
            "palette_size": palette_size,
            "gen_walkcycle": gen_walkcycle,
        }
    }
    
    artifacts_dir = run_factory_job(job_spec)
    
    # Copy source image to artifacts for reference
    import shutil
    shutil.copy(temp_image, artifacts_dir / "source.png")
    
    # Save generation info
    info = {
        "prompt": prompt,
        "seed": actual_seed,
        "sd_size": sd_size,
        "target_size": [target_width, target_height],
        "palette_size": palette_size,
        "gen_walkcycle": gen_walkcycle,
    }
    with open(artifacts_dir / "generation_info.json", "w") as f:
        json.dump(info, f, indent=2)
    
    print(f"\n✓ Sprite generated: {artifacts_dir}")
    return artifacts_dir


def main():
    parser = argparse.ArgumentParser(description="SD → Aseprite Factory Pipeline")
    subparsers = parser.add_subparsers(dest="command", required=True)
    
    # Tileset command
    tile_parser = subparsers.add_parser("tileset", help="Generate a scene and slice into tileset")
    tile_parser.add_argument("prompt", help="Scene description")
    tile_parser.add_argument("--job-id", help="Custom job ID")
    tile_parser.add_argument("--width", type=int, default=512, help="SD output width")
    tile_parser.add_argument("--height", type=int, default=512, help="SD output height")
    tile_parser.add_argument("--tile-size", type=int, default=16, help="Tile size in pixels")
    tile_parser.add_argument("--palette", type=int, default=32, help="Max colors in palette")
    tile_parser.add_argument("--seed", type=int, default=-1, help="Generation seed")
    
    # Sprite command
    sprite_parser = subparsers.add_parser("sprite", help="Generate a character/object sprite")
    sprite_parser.add_argument("prompt", help="Character/object description")
    sprite_parser.add_argument("--job-id", help="Custom job ID")
    sprite_parser.add_argument("--sd-size", type=int, default=512, help="SD output size")
    sprite_parser.add_argument("--width", type=int, default=32, help="Target sprite width")
    sprite_parser.add_argument("--height", type=int, default=32, help="Target sprite height")
    sprite_parser.add_argument("--palette", type=int, default=16, help="Max colors in palette")
    sprite_parser.add_argument("--walkcycle", action="store_true", help="Generate walk cycle")
    sprite_parser.add_argument("--seed", type=int, default=-1, help="Generation seed")
    
    # Status command
    status_parser = subparsers.add_parser("status", help="Check SD WebUI status")
    
    args = parser.parse_args()
    
    if args.command == "status":
        try:
            models = sd_api("/sdapi/v1/sd-models")
            options = sd_api("/sdapi/v1/options")
            print(f"✓ SD WebUI connected at {SD_API_BASE}")
            print(f"Current model: {options.get('sd_model_checkpoint', 'unknown')}")
            print(f"Available models: {len(models)}")
        except Exception as e:
            print(f"✗ Cannot connect to SD WebUI: {e}")
            return 1
    
    elif args.command == "tileset":
        pipeline_tileset(
            prompt=args.prompt,
            job_id=args.job_id,
            width=args.width,
            height=args.height,
            tile_size=args.tile_size,
            palette_size=args.palette,
            seed=args.seed,
        )
    
    elif args.command == "sprite":
        pipeline_sprite(
            prompt=args.prompt,
            job_id=args.job_id,
            sd_size=args.sd_size,
            target_width=args.width,
            target_height=args.height,
            palette_size=args.palette,
            gen_walkcycle=args.walkcycle,
            seed=args.seed,
        )
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
