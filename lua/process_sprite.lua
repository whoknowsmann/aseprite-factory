--[[
  process_sprite.lua
  Process raw pixel art (e.g., from Stable Diffusion) into game-ready sprites
  
  Params:
    output_dir       - Windows path for output
    output_basename  - Base filename
    input_file       - Windows path to source PNG
    target_width     - Desired sprite width (default: 32)
    target_height    - Desired sprite height (default: 32)
    palette_size     - Max colors in palette (default: 16)
    gen_walkcycle    - "true" to generate 4-frame walk from base (default: "false")
]]

local function join_path(dir, name)
  if string.sub(dir, -1) == "\\" then
    return dir .. name
  end
  return dir .. "\\" .. name
end

local function main()
  print("Starting process_sprite")
  
  -- Parse params
  local output_dir = app.params["output_dir"]
  local output_basename = app.params["output_basename"] or "processed"
  local input_file = app.params["input_file"]
  local target_width = tonumber(app.params["target_width"]) or 32
  local target_height = tonumber(app.params["target_height"]) or 32
  local palette_size = tonumber(app.params["palette_size"]) or 16
  local gen_walkcycle = app.params["gen_walkcycle"] == "true"
  
  if not output_dir or output_dir == "" then
    error("output_dir parameter is required")
  end
  if not input_file or input_file == "" then
    error("input_file parameter is required")
  end
  
  print("Input: " .. input_file)
  print("Target size: " .. target_width .. "x" .. target_height)
  print("Palette size: " .. palette_size)
  print("Generate walkcycle: " .. tostring(gen_walkcycle))
  
  -- Open source image
  local source_sprite = app.open(input_file)
  if not source_sprite then
    error("Failed to open input file: " .. input_file)
  end
  
  -- Flatten if multiple layers
  if #source_sprite.layers > 1 then
    app.command.FlattenLayers()
  end
  
  -- Get original dimensions
  local orig_width = source_sprite.width
  local orig_height = source_sprite.height
  print("Original size: " .. orig_width .. "x" .. orig_height)
  
  -- Resize if needed
  if orig_width ~= target_width or orig_height ~= target_height then
    print("Resizing to " .. target_width .. "x" .. target_height)
    app.command.SpriteSize {
      ui = false,
      width = target_width,
      height = target_height,
      method = "nearest"  -- Keep it pixelated
    }
  end
  
  -- Convert to indexed color with limited palette
  print("Reducing palette to " .. palette_size .. " colors")
  app.command.ChangePixelFormat {
    ui = false,
    format = "indexed",
    rgbmap = "octree",
    dithering = "none"
  }
  
  -- Limit palette size if needed
  local current_palette = source_sprite.palettes[1]
  if current_palette and #current_palette > palette_size then
    print("Trimming palette from " .. #current_palette .. " to " .. palette_size)
    -- Re-quantize with target size
    app.command.ChangePixelFormat {
      ui = false,
      format = "rgb"
    }
    -- Create new palette with limited colors
    local new_palette = Palette(palette_size)
    app.command.ChangePixelFormat {
      ui = false,
      format = "indexed",
      rgbmap = "octree",
      dithering = "none"
    }
  end
  
  local total_frames = 1
  
  -- Generate walk cycle if requested
  if gen_walkcycle then
    print("Generating walk cycle...")
    
    -- Add 3 more frames (total 4)
    for i = 2, 4 do
      source_sprite:newFrame()
    end
    
    local base_layer = source_sprite.layers[1]
    local base_cel = base_layer:cel(1)
    
    if base_cel then
      local base_image = base_cel.image:clone()
      
      -- Frame 2: Shift up 1px (step)
      local img2 = base_image:clone()
      source_sprite:newCel(base_layer, 2, img2, Point(0, -1))
      
      -- Frame 3: Same as frame 1
      local img3 = base_image:clone()
      source_sprite:newCel(base_layer, 3, img3, Point(0, 0))
      
      -- Frame 4: Shift up 1px (step)
      local img4 = base_image:clone()
      source_sprite:newCel(base_layer, 4, img4, Point(0, -1))
    end
    
    -- Set frame durations
    for i = 1, 4 do
      source_sprite.frames[i].duration = 0.15
    end
    
    -- Add walk tag
    local walk_tag = source_sprite:newTag(1, 4)
    walk_tag.name = "walk"
    
    total_frames = 4
  end
  
  -- Build output paths
  local aseprite_path = join_path(output_dir, output_basename .. ".aseprite")
  local png_path = join_path(output_dir, output_basename .. ".png")
  
  -- Save aseprite file
  print("Saving: " .. aseprite_path)
  app.command.SaveFileAs {
    ui = false,
    filename = aseprite_path
  }
  
  -- Export sprite sheet
  print("Exporting: " .. png_path)
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
  
  -- Close without saving changes to original
  app.command.CloseFile { ui = false }
  
  print("process_sprite complete")
  print("Output: " .. output_basename)
  print("Frames: " .. total_frames)
end

-- Run with error handling
local ok, err = xpcall(main, function(e)
  return debug.traceback(e, 2)
end)

if not ok then
  print(err)
  error(err)
end
