#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional

REPO_ROOT = Path(__file__).resolve().parent
ARTIFACTS_DIR = REPO_ROOT / "artifacts"
LUA_DIR = REPO_ROOT / "lua"

SUPPORTED_TASKS = {"sprite_placeholder", "tileset_placeholder"}
JOB_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]+$")


class JobError(Exception):
    pass


def run_wslpath(args: List[str]) -> str:
    try:
        result = subprocess.run(
            ["wslpath", *args],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except FileNotFoundError as exc:
        raise JobError("wslpath not found; ensure this runs inside WSL.") from exc
    except subprocess.CalledProcessError as exc:
        raise JobError(f"wslpath failed: {exc.stderr.strip()}") from exc
    return result.stdout.strip()


def to_windows_path(path: str) -> str:
    return run_wslpath(["-w", path])


def to_wsl_path(path: str) -> str:
    return run_wslpath(["-u", path])


def find_aseprite_executable() -> Dict[str, str]:
    env_path = os.environ.get("ASEPRITE_EXE")
    if env_path:
        if env_path.startswith("/"):
            wsl_path = env_path
            if not Path(wsl_path).exists():
                raise JobError(f"ASEPRITE_EXE not found at {env_path}.")
            win_path = to_windows_path(wsl_path)
        else:
            wsl_path = to_wsl_path(env_path)
            if not Path(wsl_path).exists():
                raise JobError(f"ASEPRITE_EXE not found at {env_path}.")
            win_path = env_path
        return {"wsl": wsl_path, "win": win_path}

    candidates = [
        "C:\\Program Files\\Aseprite\\aseprite.exe",
        "C:\\Program Files (x86)\\Aseprite\\aseprite.exe",
    ]
    for candidate in candidates:
        try:
            wsl_path = to_wsl_path(candidate)
        except JobError:
            continue
        if Path(wsl_path).exists():
            return {"wsl": wsl_path, "win": candidate}

    raise JobError(
        "Aseprite executable not found. Set ASEPRITE_EXE to the Windows path "
        "(e.g. C:\\Program Files\\Aseprite\\aseprite.exe) or a WSL path."
    )


def validate_job(job: Dict[str, object]) -> Dict[str, object]:
    if not isinstance(job, dict):
        raise JobError("Job spec must be a JSON object.")

    job_id = job.get("job_id")
    task = job.get("task")
    output_basename = job.get("output_basename")

    if not isinstance(job_id, str) or not job_id:
        raise JobError("job_id is required and must be a string.")
    if not JOB_ID_PATTERN.match(job_id):
        raise JobError("job_id must contain only letters, numbers, underscore, or dash.")

    if not isinstance(task, str) or task not in SUPPORTED_TASKS:
        raise JobError(f"task must be one of {sorted(SUPPORTED_TASKS)}.")

    if not isinstance(output_basename, str) or not output_basename:
        raise JobError("output_basename is required and must be a string.")
    if Path(output_basename).name != output_basename:
        raise JobError("output_basename must be a file basename without directories.")

    return {
        "job_id": job_id,
        "task": task,
        "output_basename": output_basename,
        "params": job.get("params", {}),
    }


@dataclass
class CommandContext:
    job: Dict[str, object]
    artifacts_dir: Path


class BaseCommand:
    def __init__(self, context: CommandContext):
        self.context = context

    @property
    def lua_script(self) -> Path:
        raise NotImplementedError

    def script_params(self) -> Dict[str, str]:
        return {
            "output_dir": to_windows_path(str(self.context.artifacts_dir)),
            "output_basename": str(self.context.job["output_basename"]),
        }

    def meta_payload(self) -> Dict[str, object]:
        return {"job": self.context.job}


class SpritePlaceholderCommand(BaseCommand):
    @property
    def lua_script(self) -> Path:
        return LUA_DIR / "sprite_placeholder.lua"

    def meta_payload(self) -> Dict[str, object]:
        return {
            "job": self.context.job,
            "frame_count": 5,
            "tags": {
                "idle": {"from": 1, "to": 1},
                "walk": {"from": 2, "to": 5},
            },
        }


class TilesetPlaceholderCommand(BaseCommand):
    @property
    def lua_script(self) -> Path:
        return LUA_DIR / "tileset_placeholder.lua"

    def meta_payload(self) -> Dict[str, object]:
        return {
            "job": self.context.job,
            "tileset_size": [128, 128],
            "tile_size": [16, 16],
            "tiles": ["grass", "stone", "wall", "dirt"],
        }


def build_command(context: CommandContext) -> BaseCommand:
    task = context.job["task"]
    if task == "sprite_placeholder":
        return SpritePlaceholderCommand(context)
    if task == "tileset_placeholder":
        return TilesetPlaceholderCommand(context)
    raise JobError(f"Unsupported task: {task}")


def write_meta_json(payload: Dict[str, object], artifacts_dir: Path) -> None:
    meta_path = artifacts_dir / "meta.json"
    with meta_path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, sort_keys=True)
        handle.write("\n")


def run_aseprite(executable: str, script_path: Path, params: Dict[str, str], log_path: Path) -> int:
    script_win_path = to_windows_path(str(script_path))

    cmd = [executable, "-b", "--script", script_win_path]
    for key, value in params.items():
        cmd.extend(["--script-param", f"{key}={value}"])

    result = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    log_contents = [
        "Command:",
        " ".join(cmd),
        "",
        "--- stdout ---",
        result.stdout,
        "--- stderr ---",
        result.stderr,
    ]
    log_path.write_text("\n".join(log_contents), encoding="utf-8")
    return result.returncode


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Aseprite automation runner")
    parser.add_argument("job_spec", help="Path to job JSON spec")
    args = parser.parse_args(argv)

    job_spec_path = Path(args.job_spec)
    if not job_spec_path.exists():
        raise JobError(f"Job spec not found at {job_spec_path}")

    with job_spec_path.open("r", encoding="utf-8") as handle:
        job_data = json.load(handle)

    job = validate_job(job_data)

    artifacts_dir = ARTIFACTS_DIR / str(job["job_id"])
    artifacts_dir.mkdir(parents=True, exist_ok=True)

    context = CommandContext(job=job, artifacts_dir=artifacts_dir)
    command = build_command(context)

    write_meta_json(command.meta_payload(), artifacts_dir)

    exe_paths = find_aseprite_executable()
    log_path = artifacts_dir / "logs.txt"
    exit_code = run_aseprite(exe_paths["wsl"], command.lua_script, command.script_params(), log_path)

    if exit_code != 0:
        raise JobError(f"Aseprite exited with code {exit_code}. See logs.txt for details.")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except JobError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
