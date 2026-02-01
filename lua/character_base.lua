--[[
  character_base.lua
  Parameterized character sprite generator
  
  Params:
    output_dir      - Windows path for output
    output_basename - Base filename
    palette         - Color preset name (or JSON for custom)
    body_type       - small, medium, heavy
    animations      - Comma-separated: idle,walk,attack,hurt,cast
    facing          - side or 4dir
]]

-- ============================================================================
-- COLOR PALETTES
-- ============================================================================

local PALETTES = {
  knight_default = {
    outline = {26, 26, 46},
    skin = {245, 203, 167},
    skin_shadow = {212, 165, 116},
    primary = {100, 116, 139},      -- armor
    primary_shadow = {71, 85, 105},
    secondary = {59, 130, 246},     -- blue accent
    secondary_shadow = {37, 99, 235},
    accent = {250, 250, 250},       -- highlight
  },
  knight_red = {
    outline = {26, 26, 46},
    skin = {245, 203, 167},
    skin_shadow = {212, 165, 116},
    primary = {100, 116, 139},
    primary_shadow = {71, 85, 105},
    secondary = {239, 68, 68},      -- red accent
    secondary_shadow = {185, 28, 28},
    accent = {250, 250, 250},
  },
  knight_gold = {
    outline = {26, 26, 46},
    skin = {245, 203, 167},
    skin_shadow = {212, 165, 116},
    primary = {234, 179, 8},        -- gold armor
    primary_shadow = {161, 98, 7},
    secondary = {250, 250, 250},
    secondary_shadow = {212, 212, 216},
    accent = {254, 240, 138},
  },
  mage_blue = {
    outline = {26, 26, 46},
    skin = {245, 203, 167},
    skin_shadow = {212, 165, 116},
    primary = {59, 130, 246},       -- blue robe
    primary_shadow = {30, 64, 175},
    secondary = {250, 250, 250},
    secondary_shadow = {212, 212, 216},
    accent = {147, 197, 253},
  },
  mage_purple = {
    outline = {26, 26, 46},
    skin = {245, 203, 167},
    skin_shadow = {212, 165, 116},
    primary = {139, 92, 246},       -- purple robe
    primary_shadow = {91, 33, 182},
    secondary = {234, 179, 8},      -- gold trim
    secondary_shadow = {161, 98, 7},
    accent = {196, 181, 253},
  },
  rogue_brown = {
    outline = {26, 26, 46},
    skin = {245, 203, 167},
    skin_shadow = {212, 165, 116},
    primary = {120, 80, 50},        -- brown leather
    primary_shadow = {80, 50, 30},
    secondary = {60, 60, 60},
    secondary_shadow = {40, 40, 40},
    accent = {180, 140, 100},
  },
  rogue_black = {
    outline = {26, 26, 46},
    skin = {245, 203, 167},
    skin_shadow = {212, 165, 116},
    primary = {50, 50, 55},         -- black leather
    primary_shadow = {30, 30, 35},
    secondary = {80, 80, 85},
    secondary_shadow = {60, 60, 65},
    accent = {120, 120, 125},
  },
  peasant_green = {
    outline = {26, 26, 46},
    skin = {245, 203, 167},
    skin_shadow = {212, 165, 116},
    primary = {74, 122, 68},        -- green tunic
    primary_shadow = {50, 90, 45},
    secondary = {180, 160, 130},    -- beige
    secondary_shadow = {140, 120, 90},
    accent = {120, 180, 100},
  },
  peasant_brown = {
    outline = {26, 26, 46},
    skin = {245, 203, 167},
    skin_shadow = {212, 165, 116},
    primary = {139, 90, 60},        -- brown tunic
    primary_shadow = {100, 60, 40},
    secondary = {180, 160, 130},
    secondary_shadow = {140, 120, 90},
    accent = {200, 150, 100},
  },
}

-- ============================================================================
-- BODY TEMPLATES (16x16 grid, pixel patterns)
-- ============================================================================
-- Legend: 0=transparent, 1=outline, 2=skin, 3=skin_shadow, 
--         4=primary, 5=primary_shadow, 6=secondary, 7=secondary_shadow, 8=accent

local BODY_TEMPLATES = {
  medium = {
    -- Standing base frame (side view)
    base = {
      "0000000110000000",
      "0000001221000000",
      "0000001221000000",
      "0000000110000000",
      "0000011441000000",
      "0000144441000000",
      "0001444461000000",
      "0001444461000000",
      "0000144410000000",
      "0000014410000000",
      "0000015510000000",
      "0000015510000000",
      "0000015510000000",
      "0000011011000000",
      "0000011011000000",
      "0000000000000000",
    },
    -- Walk frame offsets (relative pixel shifts for legs)
    walk_offsets = {
      {leg_l = 0, leg_r = 0},   -- frame 0: neutral
      {leg_l = -1, leg_r = 1},  -- frame 1: step
      {leg_l = 0, leg_r = 0},   -- frame 2: neutral  
      {leg_l = 1, leg_r = -1},  -- frame 3: step other
    },
    height = 14,
  },
  small = {
    base = {
      "0000000000000000",
      "0000000110000000",
      "0000001221000000",
      "0000001221000000",
      "0000000110000000",
      "0000014441000000",
      "0000144461000000",
      "0000144461000000",
      "0000014410000000",
      "0000015510000000",
      "0000015510000000",
      "0000011011000000",
      "0000000000000000",
      "0000000000000000",
      "0000000000000000",
      "0000000000000000",
    },
    walk_offsets = {
      {leg_l = 0, leg_r = 0},
      {leg_l = -1, leg_r = 1},
      {leg_l = 0, leg_r = 0},
      {leg_l = 1, leg_r = -1},
    },
    height = 12,
  },
  heavy = {
    base = {
      "0000000110000000",
      "0000001221000000",
      "0000001221000000",
      "0000001111000000",
      "0000114461100000",
      "0001444446100000",
      "0001444446100000",
      "0011444446110000",
      "0001444446100000",
      "0000144446000000",
      "0000155551000000",
      "0000155551000000",
      "0000155551000000",
      "0000110011000000",
      "0000110011000000",
      "0000000000000000",
    },
    walk_offsets = {
      {leg_l = 0, leg_r = 0},
      {leg_l = -1, leg_r = 1},
      {leg_l = 0, leg_r = 0},
      {leg_l = 1, leg_r = -1},
    },
    height = 14,
  },
}

-- ============================================================================
-- ANIMATION DEFINITIONS
-- ============================================================================

local ANIMATIONS = {
  idle = {
    frames = 2,
    durations = {500, 500},  -- ms per frame
    generator = "gen_idle",
  },
  walk = {
    frames = 4,
    durations = {120, 120, 120, 120},
    generator = "gen_walk",
  },
  attack = {
    frames = 3,
    durations = {100, 80, 150},
    generator = "gen_attack",
  },
  hurt = {
    frames = 2,
    durations = {100, 200},
    generator = "gen_hurt",
  },
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function make_color(r, g, b, a)
  return Color { r = r, g = g, b = b, a = a or 255 }
end

local function get_palette_color(palette, index)
  local map = {
    [0] = nil,  -- transparent
    [1] = palette.outline,
    [2] = palette.skin,
    [3] = palette.skin_shadow,
    [4] = palette.primary,
    [5] = palette.primary_shadow,
    [6] = palette.secondary,
    [7] = palette.secondary_shadow,
    [8] = palette.accent,
  }
  local c = map[index]
  if c then
    return make_color(c[1], c[2], c[3])
  end
  return Color { r = 0, g = 0, b = 0, a = 0 }
end

local function draw_template(image, template, palette, offset_x, offset_y)
  for y, row in ipairs(template) do
    for x = 1, #row do
      local pixel = tonumber(string.sub(row, x, x))
      if pixel and pixel > 0 then
        local color = get_palette_color(palette, pixel)
        image:drawPixel(offset_x + x - 1, offset_y + y - 1, color)
      end
    end
  end
end

local function copy_template(template)
  local copy = {}
  for i, row in ipairs(template) do
    copy[i] = row
  end
  return copy
end

local function join_path(dir, name)
  if string.sub(dir, -1) == "\\" then
    return dir .. name
  end
  return dir .. "\\" .. name
end

local function split_string(str, delimiter)
  local result = {}
  for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
    if match ~= "" then
      table.insert(result, match)
    end
  end
  return result
end

-- ============================================================================
-- FRAME GENERATORS
-- ============================================================================

local function gen_idle(sprite, layer, palette, body, start_frame)
  -- Frame 1: base
  local img1 = Image(sprite.spec)
  img1:clear()
  draw_template(img1, body.base, palette, 0, 0)
  sprite:newCel(layer, start_frame, img1, Point(0, 0))
  
  -- Frame 2: slight bob (shift body up 1px)
  local img2 = Image(sprite.spec)
  img2:clear()
  draw_template(img2, body.base, palette, 0, -1)
  sprite:newCel(layer, start_frame + 1, img2, Point(0, 0))
  
  return 2
end

local function gen_walk(sprite, layer, palette, body, start_frame)
  for i = 1, 4 do
    local img = Image(sprite.spec)
    img:clear()
    -- Simple walk: alternate leg positions via vertical shift
    local y_offset = (i == 2 or i == 4) and -1 or 0
    draw_template(img, body.base, palette, 0, y_offset)
    sprite:newCel(layer, start_frame + i - 1, img, Point(0, 0))
  end
  return 4
end

local function gen_attack(sprite, layer, palette, body, start_frame)
  -- Frame 1: wind up (lean back)
  local img1 = Image(sprite.spec)
  img1:clear()
  draw_template(img1, body.base, palette, -1, 0)
  sprite:newCel(layer, start_frame, img1, Point(0, 0))
  
  -- Frame 2: swing (lean forward)
  local img2 = Image(sprite.spec)
  img2:clear()
  draw_template(img2, body.base, palette, 1, 0)
  sprite:newCel(layer, start_frame + 1, img2, Point(0, 0))
  
  -- Frame 3: recover
  local img3 = Image(sprite.spec)
  img3:clear()
  draw_template(img3, body.base, palette, 0, 0)
  sprite:newCel(layer, start_frame + 2, img3, Point(0, 0))
  
  return 3
end

local function gen_hurt(sprite, layer, palette, body, start_frame)
  -- Frame 1: recoil
  local img1 = Image(sprite.spec)
  img1:clear()
  draw_template(img1, body.base, palette, -1, 0)
  sprite:newCel(layer, start_frame, img1, Point(0, 0))
  
  -- Frame 2: recover
  local img2 = Image(sprite.spec)
  img2:clear()
  draw_template(img2, body.base, palette, 0, 0)
  sprite:newCel(layer, start_frame + 1, img2, Point(0, 0))
  
  return 2
end

local GENERATORS = {
  gen_idle = gen_idle,
  gen_walk = gen_walk,
  gen_attack = gen_attack,
  gen_hurt = gen_hurt,
}

-- ============================================================================
-- MAIN
-- ============================================================================

local function main()
  print("Starting character_base generation")
  
  -- Parse params
  local output_dir = app.params["output_dir"]
  local output_basename = app.params["output_basename"] or "character"
  local palette_name = app.params["palette"] or "knight_default"
  local body_type = app.params["body_type"] or "medium"
  local animations_str = app.params["animations"] or "idle"
  local facing = app.params["facing"] or "side"
  
  if not output_dir or output_dir == "" then
    error("output_dir parameter is required")
  end
  
  -- Get palette
  local palette = PALETTES[palette_name]
  if not palette then
    error("Unknown palette: " .. palette_name)
  end
  
  -- Get body template
  local body = BODY_TEMPLATES[body_type]
  if not body then
    error("Unknown body_type: " .. body_type)
  end
  
  -- Parse animations
  local anim_list = split_string(animations_str, ",")
  
  -- Calculate total frames needed
  local total_frames = 0
  for _, anim_name in ipairs(anim_list) do
    local anim = ANIMATIONS[anim_name]
    if anim then
      total_frames = total_frames + anim.frames
    end
  end
  
  if total_frames == 0 then
    error("No valid animations specified")
  end
  
  -- Create sprite
  local sprite = Sprite(16, 16, ColorMode.RGB)
  
  -- Add frames (sprite starts with 1)
  for i = 2, total_frames do
    sprite:newFrame()
  end
  
  -- Create layer
  local layer = sprite.layers[1]
  layer.name = "Character"
  
  -- Generate each animation
  local current_frame = 1
  for _, anim_name in ipairs(anim_list) do
    local anim = ANIMATIONS[anim_name]
    if anim then
      local gen_func = GENERATORS[anim.generator]
      if gen_func then
        local start_frame = current_frame
        local frame_count = gen_func(sprite, layer, palette, body, current_frame)
        
        -- Create tag for this animation
        local tag = sprite:newTag(start_frame, start_frame + frame_count - 1)
        tag.name = anim_name
        
        -- Set frame durations
        for i = 0, frame_count - 1 do
          sprite.frames[start_frame + i].duration = anim.durations[i + 1] / 1000
        end
        
        current_frame = current_frame + frame_count
      end
    end
  end
  
  -- Build output paths
  local aseprite_path = join_path(output_dir, output_basename .. ".aseprite")
  local png_path = join_path(output_dir, output_basename .. ".png")
  
  -- Save aseprite file
  app.command.SaveFile { filename = aseprite_path }
  
  -- Export sprite sheet
  app.command.ExportSpriteSheet {
    ui = false,
    type = SpriteSheetType.HORIZONTAL,
    textureFilename = png_path,
    columns = total_frames,
    rows = 1,
    borderPadding = 0,
    shapePadding = 0,
    innerPadding = 0,
    trim = false,
    openGenerated = false,
  }
  
  print("Character generation complete: " .. output_basename)
  print("Frames: " .. total_frames)
  print("Animations: " .. animations_str)
end

-- Run with error handling
local ok, err = xpcall(main, function(e)
  return debug.traceback(e, 2)
end)

if not ok then
  print(err)
  error(err)
end
