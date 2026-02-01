local function make_palette()
  local palette = Palette(16)
  local colors = {
    {0, 0, 0, 0},
    {12, 12, 12, 255},
    {40, 40, 40, 255},
    {92, 64, 52, 255},
    {140, 96, 72, 255},
    {196, 144, 116, 255},
    {52, 96, 160, 255},
    {76, 140, 196, 255},
    {60, 72, 120, 255},
    {104, 120, 168, 255},
    {76, 140, 84, 255},
    {116, 180, 112, 255},
    {160, 112, 44, 255},
    {200, 156, 60, 255},
    {216, 200, 168, 255},
    {232, 224, 200, 255},
  }
  for i, color in ipairs(colors) do
    palette:setColor(i - 1, Color { r = color[1], g = color[2], b = color[3], a = color[4] })
  end
  return palette
end

local function join_path(dir, name)
  if string.sub(dir, -1) == "\\" then
    return dir .. name
  end
  return dir .. "\\" .. name
end

local function draw_rect(image, x0, y0, x1, y1, color)
  for y = y0, y1 do
    for x = x0, x1 do
      image:drawPixel(x, y, color)
    end
  end
end

local function draw_frame(spec, frame_index)
  local img = Image(spec)
  img:clear(0)

  local outline = 1
  local shirt = 6
  local pants = 8
  local skin = 5
  local accent = 13

  draw_rect(img, 6, 2, 9, 4, skin)
  draw_rect(img, 6, 5, 9, 5, outline)
  draw_rect(img, 5, 6, 10, 9, shirt)
  draw_rect(img, 5, 10, 10, 11, pants)

  local leg_offset = (frame_index % 2 == 0) and 1 or 0
  draw_rect(img, 5, 12, 6, 14, pants)
  draw_rect(img, 9, 12, 10, 14, pants)
  if leg_offset == 1 then
    img:drawPixel(5, 12, accent)
    img:drawPixel(10, 13, accent)
  else
    img:drawPixel(6, 13, accent)
    img:drawPixel(9, 12, accent)
  end

  img:drawPixel(5, 7, outline)
  img:drawPixel(10, 7, outline)
  img:drawPixel(4, 8, outline)
  img:drawPixel(11, 8, outline)

  return img
end

local function main()
  print("Starting sprite placeholder generation")
  local output_dir = app.params["output_dir"]
  local output_basename = app.params["output_basename"]

  if not output_dir or output_dir == "" then
    error("output_dir parameter is required")
  end
  if not output_basename or output_basename == "" then
    error("output_basename parameter is required")
  end

  local sprite = Sprite(16, 16, ColorMode.INDEXED)
  sprite:setPalette(make_palette())

  local layer = sprite:newLayer()
  layer.name = "Base"

  for i = 2, 5 do
    sprite:newFrame()
  end

  for i = 1, 5 do
    sprite.frames[i].duration = 100
    local image = draw_frame(sprite.spec, i)
    sprite:newCel(layer, i, image, Point(0, 0))
  end

  local idle_tag = sprite:newTag(1, 1)
  idle_tag.name = "idle"
  local walk_tag = sprite:newTag(2, 5)
  walk_tag.name = "walk"

  local aseprite_path = join_path(output_dir, output_basename .. ".aseprite")
  local png_path = join_path(output_dir, output_basename .. ".png")

  app.command.SaveFile { filename = aseprite_path }
  
  -- Export sprite sheet PNG 
  -- Note: textureFilename is required to actually save the sheet file
  app.command.ExportSpriteSheet {
    ui = false,
    type = SpriteSheetType.HORIZONTAL,
    textureFilename = png_path,
    columns = 5,
    rows = 1,
    borderPadding = 0,
    shapePadding = 0,
    innerPadding = 0,
    trim = false,
    openGenerated = false
  }

  print("Sprite placeholder generation complete")
end

local ok, err = xpcall(main, function(e)
  return debug.traceback(e, 2)
end)

if not ok then
  print(err)
  error(err)
end
