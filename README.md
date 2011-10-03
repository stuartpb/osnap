# osnap: a simple webcam snapshooter

# Requirements

To run osnap.wlua, you'll need:

- [Lua](http://lua.org)
- [IUPLua](http://www.tecgraf.puc-rio.br/iup/)
- [IMLua](http://www.tecgraf.puc-rio.br/im/)
- [CDLua](http://www.tecgraf.puc-rio.br/cd/)
- [LuaGL](http://luagl.sourceforge.net/)

On Windows, you can get all this and more by installing [Lua for Windows](http://code.google.com/p/luaforwindows/downloads/detail?name=LuaForWindows_v5.1.4-45.exe).

Outside of Windows, check your local package manager (which will most likely have packages for Lua) and/or Sourceforge (there are some good tips out there for setting up the files you can get from Sourceforge if you search for them).

# Running

Run osnap.wlua with a Lua interpreter like wlua.exe for Windows.

# Usage

Press the "oh snap" buttons on either side of the frame (or the spacebar) to take a picture. (It will be saved as an epoch-time-named JPEG in the working directory.)

Drag across the center of the preview horizontally (or press the H key) to flip it.

Press F11 to toggle fullscreen.

# Roadmap

- Sooner:
  - Canvas-based buttons
  - Access to camera options dialog
- Later:
  - Overlay(s)
