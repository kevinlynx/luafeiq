--[[
  Some dependent module
  Kevin Lynx
  2.7.2011
  i want to write file transfer module very independent from luafeiq.
  file transfer contains file recv/send module. they can be put in an 
  indenpendent lua state(lua task) to execute. also there should be 
  some helper functions to communicate with file transfer module.
--]]
UPDIR = '' -- or '../'
dofile(UPDIR..'fileop_utils.lua')
dofile(UPDIR..'utils.lua')
dofile(UPDIR..'log.lua')
