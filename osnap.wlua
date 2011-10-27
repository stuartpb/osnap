-- The base IM library is used for saving captured
-- frames to disk as JPEG.
local im = require "imlua"
-- The IM Capture library is required to get data
-- from the webcam.
require "imlua_capture"
-- CalcHistoImageStatistics from the IM Processing library
-- is used to determine if the camera has been covered.
require "imlua_process"
-- LuaGL is used to draw the preview to the screen efficiently.
local gl = require "luagl"
-- CanvasDraw is used to draw the side buttons.
local cd = require "cdlua"
require "iupluacd"
-- IUPLua is used to assemble the UI.
local iup = require "iuplua"
require "iupluagl"

--Create the video capture context.
local vc = im.VideoCaptureCreate()

-- Connect to the first webcam.
-- TODO: Enumerate cameras, prompt if more than one
-- (and save the option / make it configurable)
vc:Connect(0)

-- The dimensions of the capture feed.
local capw, caph = vc:GetImageSize()
-- The aspect ratio of the capture feed.
local cap_ratio = capw / caph --almost certainly 4/3 but

--The size of the preview canvas
--(initially the same as the capture feed).
local canw, canh = capw, caph

-- Function for converting two integers to a string
-- of the form '<i1>x<i2>'.
-- Used for setting sizes in IUP.
local function ixi(i1, i2)
  return string.format("%ix%i", i1, i2)
end

-- Min, max, and clamp.
-- Used to keep the image from stretching
-- when dragging for flip.
local max = math.max
local min = math.min
local function clamp(number, low, high)
  return min(max(low,number),high)
end

-- Hue to RGB values.
-- Used for setting the color of the snap buttons.
local function hue_to_rgb(h)
  local function h2c(h)
    h = h % 1
    if h < 1/6 then
      return h*6
    elseif h < 1/2 then
      return 1
    elseif h < 2/3 then
      return (2/3-h)*6
    else return 0
    end
  end
  return h2c(h+1/3),h2c(h),h2c(h-1/3)
end

-- Function for converting three values from 0 to 1 to a string
-- of 3 ints from 0 to 255 of the form '<i1> <i2> <i3>'.
-- Used for setting the BGCOLOR of the snap button canvases in IUP.
local function isisi(i1, i2, i3)
  i1 = i1 * 255
  i2 = i2 * 255
  i3 = i3 * 255
  return string.format("%i %i %i", i1, i2, i3)
end

-- The horizontal scaling factor when dragging.
-- Changed when dragging, reset to 1 on release.
local dragfactor = 1

-- The last frame obtained form the capture feed.
local last_frame = im.ImageCreate(capw, caph, im.RGB, im.BYTE)

-- The OpenGL data from the last frame.
local gldata, glformat = last_frame:GetOpenGLData()

-- The canvas for the capture preview.
local preview = iup.glcanvas{
  buffer="DOUBLE", -- Double buffer for smoothness
  rastersize = ixi(canw, canh),
  expand = 'no', -- the dialog resizes the canvas in its callback
  border = 'no'
}

-- The starting flip factor for the preview.
-- Set to -1 to start with the image flipped.
local flipfactor = 1

--Whether to close the app when
local blackout = false

--Function that determines filenames for new images.
local function get_filename()
  --The user's home directory on Windows 7 (ie. 'C:\Users\Stuart').
  local user_dir = os.getenv"USERPROFILE"
  --The Pictures directory.
  local pics_dir = user_dir .. '/Pictures'
  --The directory for osnap images.
  local osnap_dir = pics_dir .. '/osnap'
  --The filename format.
  local filename = string.format(osnap_dir .. "/%i", os.time())
  --The file extension (should probably move this elsewhere,
  --  to match configuration with the image saving).
  local extension = '.jpg'

  local finalname = filename

  -- check if filename is already taken and don't clobber it
  local file = io.open(finalname .. extension,'r')
  local retries = 0

  while file do
    file:close()
    finalname = string.format("%s-%i", filename, retries+2)
    file = io.open(finalname .. extension,'r')
    retries = retries + 1
  end

  return finalname .. extension
end

-- The starting hue for the buttons [0, 1).
local button_hue = 0

-- The value to increment the button hue by when each picture is taken
local button_hue_step = 9/16

-- The starting BGCOLOR of the snap button canvases.
local snapcanbgc = isisi(hue_to_rgb(button_hue))

-- Function taking 2 dimensions and an aspect ratio,
-- returning the largest dimensions within that aspect ratio.
-- Used to determine the size of the preview.
-- Reverse the logic for Biggest Containing Aspect Ratio.
local function bwar(width, height, ratio)
  if width < height * ratio then
    return width, width / ratio
  else
    return height * ratio, height
  end
end

-- Function to save the last frame to file.
-- Called by snap_pic, which also performs the actions
-- that generate feedback to the user (the snappers changing color).
local function save_image()
  local filename = get_filename()
  last_frame:Save(filename,"JPEG")
end

-- Forward declaration of buttons which get modified when snapping a pic
local lbutton, rbutton

-- Perform actions signifying feedback that the picture has been taken

local function shutter_feedback()
  button_hue = (button_hue + button_hue_step) % 1
  local newbgc = isisi(hue_to_rgb(button_hue))
  lbutton.BGCOLOR = newbgc
  rbutton.BGCOLOR = newbgc
end

-- Function to take a picture.
-- Saves the last frame to a file, then performs feedback actions.
local function snap_pic()
  save_image()
  shutter_feedback()
end

-- Resizes the preview area on the canvas.
-- Called whenever the canvas' size changes,
-- and when the capture feed changes size
-- (dragging and flipping).
local function resize_cap()
  iup.GLMakeCurrent(preview)
  gl.RasterPos(
    -(flipfactor * dragfactor),
    -1)
  gl.PixelZoom(canw / capw * flipfactor * dragfactor, canh / caph)
end

-- Flips the capture preview.
local function flip()
  flipfactor = -flipfactor
  resize_cap()
end

do --Preview canvas mouse handling
  local dox, doy
  local function drag(x, y)
    local cw = canw/2
    dragfactor = clamp((x - cw) / (dox - cw),-1,1)
    resize_cap()
  end

  local function grab(x, y)
    dox, doy = x, y
    drag(x, y)
  end

  local function release(x, y)
    dragfactor = 1
    local cw = canw/2
    if (x < cw) ~= (dox < cw) then
      flip()
    else
      resize_cap()
    end
    dox, doy = nil, nil
  end

  function preview:button_cb(but, pressed, x, y, status)
    if but == iup.BUTTON1 then
      if pressed == 1 then
        grab(x, y)
      elseif dox then
        release(x, y)
      end
    end
  end
  function preview:motion_cb(x, y, status)
    if dox then
      if iup.isbutton1(status) then
        drag(x, y)
      else --mouse has been released without triggering button_cb
        release(x, y)
      end
    end
  end
end

-- Callback for the preview canvas to resize the
-- capture area.
function preview:resize_cb(width, height)
  iup.GLMakeCurrent(self)
  gl.Viewport(0, 0, width, height)
  canw, canh = width, height
  resize_cap()
end

-- Function for updating the preview area.
function preview:action(x, y)
  iup.GLMakeCurrent(self)
  gl.PixelStore(gl.UNPACK_ALIGNMENT, 1)

  -- Clear Screen And Depth Buffer
  -- (because the BG is shown when dragging on the preview)
  gl.Clear('COLOR_BUFFER_BIT,DEPTH_BUFFER_BIT')

  -- Update the GL data from the last frame
  gldata, glformat = last_frame:GetOpenGLData()

  --Draw the preview
  gl.DrawPixelsRaw (capw, caph, glformat, gl.UNSIGNED_BYTE, gldata)

  --Swap to the front buffer
  iup.GLSwapBuffers(self)
end

local function snapper_button_cb(self, but, pressed, x, y, status)
  --do it on press and not on release because we are SNAPPY
  if but == iup.BUTTON1 and pressed == 1 then
    snap_pic()
  end
end

-- The buttons for saving an image.
lbutton = iup.canvas{bgcolor = snapcanbgc, button_cb = snapper_button_cb, border = "NO"}
rbutton = iup.canvas{bgcolor = snapcanbgc, button_cb = snapper_button_cb, border = "NO"}

local dlg = iup.dialog{
  title = "Oh Snap!",
  placement = "MAXIMIZED";
  iup.hbox{lbutton,preview,rbutton}
}

function dlg:resize_cb(w,h)
  local cw, ch = bwar(w,h,cap_ratio)
  local lbutw = math.ceil((w - cw) / 2)
  local rbutw = w - cw - lbutw
  preview.rastersize = ixi(cw, ch)
  lbutton.rastersize = ixi(lbutw, h)
  rbutton.rastersize = ixi(rbutw, h)
end

local blackout_start

local function refresh_frame()
  vc:Frame(last_frame,-1)

  if blackout then
    local median, mean = im.CalcHistoImageStatistics(last_frame)
    local maxtotal = median[0] + median[1] + median[2]
    if maxtotal < 6 then
      if not blackout_start then
        blackout_start = os.time()
      elseif os.time() > blackout_start + 2 then
        iup.ExitLoop()
      end
    end
  end

  iup.Update(preview)
end

local frame_timer = iup.timer{
  time = 10,
  action_cb = refresh_frame
}

--Key handling.

function dlg:k_any(c)
  if c == iup.K_q
  or c == iup.K_ESC then
    return iup.CLOSE
  elseif c == iup.K_h then
    flip()
  elseif c == iup.K_F11 then
    if dlg.fullscreen == "YES" then
      dlg.fullscreen = "NO"
    else
      dlg.fullscreen = "YES"
    end
    iup.SetFocus(preview)
  elseif c == iup.K_SP then
    snap_pic()
    return iup.IGNORE
  end
end

-- Show the dialog
dlg:show()
--Start pulling from the camera feed
vc:Live(1)
--Start updating frames
frame_timer.run = "YES"

--Enter the event loop
iup.MainLoop()

-- Stop actively pulling from the camera feed
vc:Live(0)
-- Disconnect from the camera
vc:Disconnect()
-- Destroy the capture context
vc:Destroy()
