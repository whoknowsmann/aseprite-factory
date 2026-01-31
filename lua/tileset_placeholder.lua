local function make_palette()
  local palette = Palette(16)
  local colors = {
    {0, 0, 0, 0},
    {12, 12, 12, 255},
    {48, 48, 48, 255},
    {84, 84, 84, 255},
    {48, 96, 52, 255},
    {76, 140, 84, 255},
    {112, 180, 104, 255},
    {100, 72, 40, 255},
    {144, 104, 60, 255},
    {180, 136, 84, 255},
    {128, 96, 64, 255},
    {168, 128, 92, 255},
    {196, 176, 144, 255},
    {92, 112, 140, 255},
    {128, 160, 200, 255},
    {208, 220, 232, 255},
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

local function draw_tile(image, origin_x, origin_y, base_color, highlight_color)
  draw_rect(image, origin_x, origin_y, origin_x + 15, origin_y + 15, base_color)
  for i = 0, 15 do
    image:drawPixel(origin_x + i, origin_y, highlight_color)
    image:drawPixel(origin_x, origin_y + i, highlight_color)
  end
  for i = 3, 12, 3 do
    image:drawPixel(origin_x + i, origin_y + 6, highlight_color)
    image:drawPixel(origin_x + 6, origin_y + i, highlight_color)
  end
end

local function main()
  print("Starting tileset placeholder generation")
  local output_dir = app.params["output_dir"]
  local output_basename = app.params["output_basename"]

  if not output_dir or output_dir == "" then
    error("output_dir parameter is required")
  end
  if not output_basename or output_basename == "" then
    error("output_basename parameter is required")
  end

  local sprite = app.createSprite(128, 128, ColorMode.INDEXED)
  sprite:setPalette(make_palette())

  local layer = sprite:newLayer()
  layer.name = "Tiles"

  local image = Image(sprite.spec)
  image:clear(0)

  draw_tile(image, 0, 0, 5, 6)
  draw_tile(image, 16, 0, 3, 2)
  draw_tile(image, 32, 0, 10, 11)
  draw_tile(image, 48, 0, 8, 9)

  draw_rect(image, 0, 16, 15, 31, 4)
  draw_rect(image, 16, 16, 31, 31, 12)
  draw_rect(image, 32, 16, 47, 31, 7)
  draw_rect(image, 48, 16, 63, 31, 8)

  sprite:newCel(layer, 1, image, Point(0, 0))

  local aseprite_path = join_path(output_dir, output_basename .. ".aseprite")
  local png_path = join_path(output_dir, output_basename .. ".png")

  app.command.SaveFile { filename = aseprite_path }
  app.command.SaveFile { filename = png_path }

  print("Tileset placeholder generation complete")
end

local ok, err = xpcall(main, function(e)
  return debug.traceback(e, 2)
end)

if not ok then
  print(err)
  error(err)
end
