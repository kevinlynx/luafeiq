--[[
  handle application tray icon stuff(implemented by iup, so only supported
  on gtk and windows.
  Kevin Lynx
  2.11.2011
--]]
dofile("res/blink.lua")
dofile("res/icon.lua")

trayicon = {}

function trayicon_ontimer(timer)
    if trayicon.dlg.trayimage == trayicon.old_ico then
        trayicon.dlg.trayimage = trayicon.new_ico
    else
        trayicon.dlg.trayimage = trayicon.old_ico
    end
end

function trayicon_init(dlg, click_cb)
    trayicon.old_ico = load_image_blink() 
	trayicon.new_ico = load_image_icon()
    trayicon.dlg = dlg
    dlg.tray = "YES"
    dlg.trayimage = trayicon.new_ico
    dlg.traytip = "luaFeiq"..luafeiq._VERSION
    dlg.trayclick_cb = trayicon_onclick
    trayicon.timer = iup.timer { time = "500", action_cb = trayicon_ontimer }
    trayicon.click_cb = click_cb
end

function trayicon_destroy()
	trayicon.dlg.tray = "NO"
	trayicon.dlg.trayimage = nil
end

function trayicon_onclick(dlg, btn, pressed, dclick)
    trayicon.click_cb(trayicon.timer.run == 'YES', dclick == 1)
end

function trayicon_flash(flag)
    if flag then--and trayicon.dlg.visible == 'NO' then
        trayicon.timer.run = "YES"
    else
        trayicon.timer.run = "NO"
        trayicon.dlg.trayimage = trayicon.new_ico
    end
end

