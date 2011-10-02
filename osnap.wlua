local im = require "imlua"
require "imlua_capture"
local gl = require "luagl"
local iup = require "iuplua"
require "iupluagl"

local vc = im.VideoCaptureCreate()

vc:Connect(0)

local capw, caph = vc:GetImageSize()
--aspect ratio of the capture feed
local cap_ratio = capw / caph --almost certainly 4/3 but

local canw, canh = capw, caph

local function ixi(i1, i2)
  return string.format("%ix%i", i1, i2)
end

local flipfactor = 1
local dragfactor = 1

local frbuf = im.ImageCreate(capw, caph, im.RGB, im.BYTE)
local gldata, glformat = frbuf:GetOpenGLData()

--expand=no because the dialog handles the resize personally
cnv = iup.glcanvas{buffer="DOUBLE", rastersize = ixi(canw, canh), expand = 'no', border = 'no'}

-- biggest within aspect ratio
-- reverse the logic for Biggest Containing Aspect Ratio
local function bwar(width, height, ratio)
  if width < height * ratio then
    return width, width / ratio
  else
    return height * ratio, height
  end
end

local function save_image()
  local filename = string.format("%i.jpg",os.time())
  --todo: check if filename is already taken and don't clobber it
  frbuf:Save(filename,"JPEG")
end

local function resize_cap()
  iup.GLMakeCurrent(cnv)
  gl.RasterPos(-(flipfactor * dragfactor),-1)
  gl.PixelZoom(canw / capw * flipfactor * dragfactor, canh / caph)
end

local function flip()
  flipfactor = -flipfactor
  resize_cap()
end

do
  local dox, doy
  local function drag(x, y)
    local cw = canw/2
    dragfactor = (x - cw) / (dox - cw)
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

  function cnv:button_cb(but, pressed, x, y, status)
    if but == iup.BUTTON1 then
      if pressed == 1 then
        grab(x, y)
      elseif dox then
        release(x, y)
      end
    end
  end
  function cnv:motion_cb(x, y, status)
    if dox then
      if iup.isbutton1(status) then
        drag(x, y)
      else --mouse has been released without triggering button_cb
        release(x, y)
      end
    end
  end
end

function cnv:resize_cb(width, height)
  iup.GLMakeCurrent(self)
  gl.Viewport(0, 0, width, height)
  canw, canh = width, height
  resize_cap()
end

function cnv:action(x, y)
  iup.GLMakeCurrent(self)
  gl.PixelStore(gl.UNPACK_ALIGNMENT, 1)

  -- Clear Screen And Depth Buffer
  -- (because the BG is shown when dragging on the preview)
  gl.Clear('COLOR_BUFFER_BIT,DEPTH_BUFFER_BIT')

  gldata, glformat = frbuf:GetOpenGLData() --update the data
  gl.DrawPixelsRaw (capw, caph, glformat, gl.UNSIGNED_BYTE, gldata)

  iup.GLSwapBuffers(self)
end

vc:Live(1)

local lbutton = iup.button{title = "Oh Snap!", action = save_image}
local rbutton = iup.button{title = "Oh Snap!", action = save_image}

local dlg = iup.dialog{
  title = "Oh Snap!",
  placement = "MAXIMIZED";
  iup.hbox{lbutton,cnv,rbutton}
}

local in_loop = true

function dlg:resize_cb(w,h)
  local cw, ch = bwar(w,h,cap_ratio)
  local lbutw = math.ceil((w - cw) / 2)
  local rbutw = w - cw - lbutw
  cnv.rastersize = ixi(cw, ch)
  lbutton.rastersize = ixi(lbutw, h)
  rbutton.rastersize = ixi(rbutw, h)
end

function dlg:close_cb()
  --Stop the IUP pseudo-loop.
  --Don't ask me why this works and returning iup.CLOSE doesn't.
  iup.ExitLoop()
  return iup.IGNORE
end

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
    iup.SetFocus(cnv)
  elseif c == iup.K_SP then
    save_image()
    return iup.IGNORE
  end
end

dlg:show()

--Event loop
while in_loop do
  --Capture the next frame from the camera
  vc:Frame(frbuf,-1)
  iup.Update(cnv)
  local result = iup.LoopStep()
  if result == iup.CLOSE then
    in_loop = false
  end
end

vc:Live(0)
vc:Disconnect()
vc:Destroy()
