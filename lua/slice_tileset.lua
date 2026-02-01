--[[
  slice_tileset.lua
  Takes a scene image and slices it into a tileset grid
  
  Params:
    output_dir       - Windows path for output
    output_basename  - Base filename
    input_file       - Windows path to source PNG
    tile_width       - Tile width (default: 16)
    tile_height      - Tile height (default: 16)
    palette_size     - Max colors in palette (default: 32)
    remove_dupes     - "true" to remove duplicate tiles (default: "true")
]]

local function join_path(dir, name)
  if string.sub(dir, -1) == "\\" then
    return dir .. name
  end
  return dir .. "\\" .. name
end

local function images_equal(img1, img2)
  if img1.width ~= img2.width or img1.height ~= img2.height then
    return false
  end
  for y = 0, img1.height - 1 do
    for x = 0, img1.width - 1 do
      if img1:getPixel(x, y) ~= img2:getPixel(x, y) then
        return false
      end
    end
  end
  return true
end

local function find_duplicate(tile_images, new_image)
  for i, existing in ipairs(tile_images) do
    if images_equal(existing, new_image) then
      return i
    end
  end
  return nil
end

local function main()
  print("Starting slice_tileset")
  
  -- Parse params
  local output_dir = app.params["output_dir"]
  local output_basename = app.params["output_basename"] or "tileset"
  local input_file = app.params["input_file"]
  local tile_width = tonumber(app.params["tile_width"]) or 16
  local tile_height = tonumber(app.params["tile_height"]) or 16
  local palette_size = tonumber(app.params["palette_size"]) or 32
  local remove_dupes = app.params["remove_dupes"] ~= "false"
  
  if not output_dir or output_dir == "" then
    error("output_dir parameter is required")
  end
  if not input_file or input_file == "" then
    error("input_file parameter is required")
  end
  
  print("Input: " .. input_file)
  print("Tile size: " .. tile_width .. "x" .. tile_height)
  print("Palette size: " .. palette_size)
  print("Remove duplicates: " .. tostring(remove_dupes))
  
  -- Open source image
  local source_sprite = app.open(input_file)
  if not source_sprite then
    error("Failed to open input file: " .. input_file)
  end
  
  -- Flatten if multiple layers
  if #source_sprite.layers > 1 then
    app.command.FlattenLayers()
  end
  
  local src_width = source_sprite.width
  local src_height = source_sprite.height
  print("Source size: " .. src_width .. "x" .. src_height)
  
  -- Convert to indexed color
  print("Converting to indexed color...")
  app.command.ChangePixelFormat {
    ui = false,
    format = "indexed",
    rgbmap = "octree",
    dithering = "none"
  }
  
  -- Calculate grid dimensions
  local cols = math.floor(src_width / tile_width)
  local rows = math.floor(src_height / tile_height)
  local total_tiles = cols * rows
  print("Grid: " .. cols .. " x " .. rows .. " = " .. total_tiles .. " tiles")
  
  -- Get source image data
  local source_cel = source_sprite.layers[1]:cel(1)
  if not source_cel then
    error("No image data in source")
  end
  local source_image = source_cel.image
  
  -- Extract tiles
  local unique_tiles = {}
  local tile_map = {}  -- Maps grid position to tile index
  local extracted_count = 0
  local dupe_count = 0
  
  for row = 0, rows - 1 do
    for col = 0, cols - 1 do
      -- Extract this tile
      local tile_image = Image(tile_width, tile_height, source_image.colorMode)
      tile_image:clear(0)
      
      for y = 0, tile_height - 1 do
        for x = 0, tile_width - 1 do
          local src_x = col * tile_width + x
          local src_y = row * tile_height + y
          if src_x < src_width and src_y < src_height then
            local pixel = source_image:getPixel(src_x, src_y)
            tile_image:drawPixel(x, y, pixel)
          end
        end
      end
      
      -- Check for duplicate
      local tile_index
      if remove_dupes then
        local existing = find_duplicate(unique_tiles, tile_image)
        if existing then
          tile_index = existing
          dupe_count = dupe_count + 1
        else
          table.insert(unique_tiles, tile_image)
          tile_index = #unique_tiles
          extracted_count = extracted_count + 1
        end
      else
        table.insert(unique_tiles, tile_image)
        tile_index = #unique_tiles
        extracted_count = extracted_count + 1
      end
      
      table.insert(tile_map, tile_index)
    end
  end
  
  print("Extracted " .. extracted_count .. " unique tiles")
  if remove_dupes then
    print("Removed " .. dupe_count .. " duplicate tiles")
  end
  
  -- Save the source palette BEFORE closing
  local saved_palette = Palette(#source_sprite.palettes[1])
  for i = 0, #source_sprite.palettes[1] - 1 do
    saved_palette:setColor(i, source_sprite.palettes[1]:getColor(i))
  end
  print("Saved palette with " .. #saved_palette .. " colors")
  
  -- Close source
  app.command.CloseFile { ui = false }
  
  -- Calculate tileset dimensions (try to make it roughly square)
  local tileset_cols = math.ceil(math.sqrt(#unique_tiles))
  local tileset_rows = math.ceil(#unique_tiles / tileset_cols)
  local tileset_width = tileset_cols * tile_width
  local tileset_height = tileset_rows * tile_height
  
  print("Tileset dimensions: " .. tileset_cols .. "x" .. tileset_rows .. " tiles (" .. tileset_width .. "x" .. tileset_height .. " px)")
  
  -- Create tileset sprite
  local tileset_sprite = Sprite(tileset_width, tileset_height, ColorMode.INDEXED)
  
  -- Apply the saved palette from the source image
  tileset_sprite:setPalette(saved_palette)
  
  -- Draw tiles to tileset
  local layer = tileset_sprite.layers[1]
  layer.name = "Tileset"
  
  local tileset_image = Image(tileset_width, tileset_height, ColorMode.INDEXED)
  tileset_image:clear(0)
  
  for i, tile_image in ipairs(unique_tiles) do
    local idx = i - 1
    local col = idx % tileset_cols
    local row = math.floor(idx / tileset_cols)
    local x = col * tile_width
    local y = row * tile_height
    
    -- Copy tile pixels
    for ty = 0, tile_height - 1 do
      for tx = 0, tile_width - 1 do
        local pixel = tile_image:getPixel(tx, ty)
        tileset_image:drawPixel(x + tx, y + ty, pixel)
      end
    end
  end
  
  tileset_sprite:newCel(layer, 1, tileset_image, Point(0, 0))
  
  -- Build output paths
  local aseprite_path = join_path(output_dir, output_basename .. ".aseprite")
  local png_path = join_path(output_dir, output_basename .. ".png")
  local map_path = join_path(output_dir, output_basename .. "_map.txt")
  
  -- Save aseprite file
  print("Saving: " .. aseprite_path)
  app.command.SaveFileAs {
    ui = false,
    filename = aseprite_path
  }
  
  -- Export PNG
  print("Exporting: " .. png_path)
  tileset_sprite:saveCopyAs(png_path)
  
  -- Write tile map (simple text format)
  -- Note: Aseprite Lua doesn't have great file I/O, but we can print it
  print("=== TILE MAP ===")
  print("Columns: " .. cols)
  print("Rows: " .. rows)
  print("Data:")
  local map_line = ""
  for i, idx in ipairs(tile_map) do
    map_line = map_line .. (idx - 1) .. ","  -- 0-indexed for game engines
    if i % cols == 0 then
      print(map_line)
      map_line = ""
    end
  end
  print("=== END MAP ===")
  
  -- Close
  app.command.CloseFile { ui = false }
  
  print("slice_tileset complete")
  print("Unique tiles: " .. #unique_tiles)
end

-- Run with error handling
local ok, err = xpcall(main, function(e)
  return debug.traceback(e, 2)
end)

if not ok then
  print(err)
  error(err)
end
