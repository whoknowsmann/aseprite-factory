# Aseprite Factory

A deterministic, headless Aseprite automation tool that runs from WSL (Ubuntu) while executing the Windows Aseprite executable in batch mode.

## Requirements

- WSL (Ubuntu) with access to the Windows filesystem.
- Aseprite installed on Windows.
- `wslpath` available in WSL.

## Setup

Set the Aseprite executable path via `ASEPRITE_EXE`. You may use either a Windows path or the corresponding WSL path.

```bash
export ASEPRITE_EXE="C:\\Program Files\\Aseprite\\aseprite.exe"
```

If `ASEPRITE_EXE` is not set, the runner will search common install locations.

## Usage

```bash
python run.py specs/examples/sprite_basic.json
python run.py specs/examples/tileset_basic.json
```

## Output

Each run writes to `artifacts/<job_id>/`:

- `logs.txt` (stdout/stderr from Aseprite)
- `meta.json` (validated job metadata)
- Task outputs
  - Sprite placeholder: `output.aseprite`, `output.png`
  - Tileset placeholder: `tileset.aseprite`, `tileset.png`

## Notes

- The runner converts all file paths to Windows-style paths using `wslpath -w` before calling Aseprite.
- All logic is deterministic and safe for unattended execution.
