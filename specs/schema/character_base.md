# character_base - Job Spec Schema

## Overview
Generates a parameterized pixel art character sprite with animations.

## Spec Format

```json
{
  "job_id": "knight_blue",
  "task": "character_base",
  "output_basename": "knight_blue",
  "params": {
    "palette": "knight_default",
    "body_type": "medium",
    "animations": ["idle", "walk"],
    "facing": "side"
  }
}
```

## Parameters

### `palette` (string, required)
Color scheme for the character. Can be a preset name or "custom".

**Presets:**
- `knight_default` - Steel armor, blue accents
- `knight_red` - Steel armor, red accents  
- `knight_gold` - Gold armor, white accents
- `mage_blue` - Blue robes, white trim
- `mage_purple` - Purple robes, gold trim
- `rogue_brown` - Brown leather, dark accents
- `rogue_black` - Black leather, gray accents
- `peasant_green` - Simple green tunic
- `peasant_brown` - Simple brown tunic

**Custom palette:**
```json
"palette": {
  "outline": "#1a1a2e",
  "skin": "#f5cba7",
  "skin_shadow": "#d4a574", 
  "primary": "#3498db",
  "primary_shadow": "#2070a0",
  "secondary": "#ecf0f1",
  "secondary_shadow": "#bdc3c7",
  "accent": "#e74c3c"
}
```

### `body_type` (string, default: "medium")
Character build affecting silhouette.

- `small` - Child/halfling proportions (12px tall)
- `medium` - Standard humanoid (14px tall)
- `heavy` - Armored/large build (14px tall, wider)

### `animations` (array, default: ["idle"])
Which animation cycles to include.

- `idle` - Breathing/standing (2 frames)
- `walk` - Walk cycle (4 frames)
- `attack` - Melee swing (3 frames)
- `hurt` - Damage reaction (2 frames)
- `cast` - Magic casting (3 frames)

### `facing` (string, default: "side")
Directional variants to generate.

- `side` - Single side-view (flip for other direction)
- `4dir` - Down, up, left, right (multiplies frame count by 4)

## Output

- `{output_basename}.aseprite` - Layered source file with tags per animation
- `{output_basename}.png` - Horizontal sprite sheet

## Frame Layout

For `facing: "side"` with `animations: ["idle", "walk"]`:
```
[idle_0][idle_1][walk_0][walk_1][walk_2][walk_3]
```

For `facing: "4dir"`:
```
[down_idle_0][down_idle_1][down_walk_0]...
[up_idle_0][up_idle_1][up_walk_0]...
[left_idle_0]...
[right_idle_0]...
```

## Tags

Each animation becomes an Aseprite tag for easy export:
- `idle` (frames 1-2)
- `walk` (frames 3-6)
- etc.
