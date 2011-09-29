local im = require "imlua"
require "imlua_capture"
local gl = require "luagl"
local iup = require "iuplua"
require "iupluagl"

local vc = im.VideoCaptureCreate()

vc:Connect(0)

local capw, caph = vc:GetImageSize()
local initimgsize = string.format("%ix%i", capw, caph)


local frbuf = im.ImageCreate(capw, caph, im.RGB, im.BYTE)
local gldata, glformat = frbuf:GetOpenGLData()

cnv = iup.glcanvas{buffer="DOUBLE", rastersize = initimgsize}
iup.GLMakeCurrent(cnv)
gl.Viewport(0, 0, capw, caph)

function cnv:resize_cb(width, height)
  iup.GLMakeCurrent(self)
  gl.Viewport(0, 0, width, height)
end

function cnv:action(x, y)
  iup.GLMakeCurrent(self)
  gl.PixelStore(gl.UNPACK_ALIGNMENT, 1)

  gldata, glformat = frbuf:GetOpenGLData() --update the data
  gl.DrawPixelsRaw (capw, caph, glformat, gl.UNSIGNED_BYTE, gldata)

  iup.GLSwapBuffers(self)
end


vc:Live(1)

local dlg = iup.dialog{title = "Oh Snap!", cnv}

function dlg:unmap_cb()
  vc:Live(0)
  vc:Disconnect()
  vc:Destroy()
  cappan = false
end

function dlg:k_any(c)
  if c == iup.K_q or c == iup.K_ESC then
    return iup.CLOSE
  end

  if c == iup.K_F1 then
    if fullscreen then
      fullscreen = false
      dlg.fullscreen = "No"
    else
      fullscreen = true
      dlg.fullscreen = "Yes"
    end
    iup.SetFocus(cnv)
  end
end

dlg:show()

local cappan = true

while cappan do
  vc:Frame(frbuf,-1)
  iup.Update(cnv)
  iup.LoopStep()
end
