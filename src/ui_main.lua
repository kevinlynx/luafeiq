--[[
  The main dialog, show user list.
  Kevin Lynx
  1.28.2011
--]]
require( "iuplua" )
-- since IUP 3.3, it does not require iupluacontrols
--require( "iupluacontrols" )

dofile("luafeiq.lua")
dofile("ui_chat_dlg.lua")
dofile("ui_branch_utils.lua")
dofile("ui_unread_message.lua")
dofile("ui_grouplist.lua")
dofile("ui_env.lua")
dofile("ui_menu.lua")
dofile("ui_filetrans.lua")
dofile("ui_sendfile_utils.lua")
dofile("ui_trayicon.lua")

OTHER_GROUP_NAME = "Others"
UI_FONT = "COURIER_NORMAL_10" 

local tree = iup.tree{}
function tree:executeleaf_cb(id)
    local arg = iup.TreeGetTable(tree, id)
    local wnd = chatdlg_create(arg, WINDOW_DATA_USER)
    chatdlg_show(wnd)
end

function idle_cb(udp)
    return function () 
        luafeiq_runonce()
        return iup.DEFAULT
    end
end

function add_group(tree, groupname)
    if string_empty(groupname) then
        groupname = OTHER_GROUP_NAME
    end
    local i = branch_find(tree, groupname, "BRANCH")
    if i == 0 then
        branch_add(tree, groupname)
		tree.redraw = "YES"
    end
end

function add_user(tree, user)
    local groupname = user.groupname
    if string_empty(groupname) then
        groupname = OTHER_GROUP_NAME
    end
    branch_addleaf(tree, groupname, user.nickname, user)
	tree.redraw = "YES"
end

function remove_user(tree, user)
	branch_delleaf(tree, user.nickname)
	tree.redraw = "YES"
end

local user_listener = {}
user_listener.onadd = function(user)
    add_group(tree, user.groupname)
    add_user(tree, user)
end

user_listener.onremove = function(user)
	remove_user(tree, user)
end

function ui_on_recv_privatemsg(user, text)
	if not chatdlg_handle_recvmsg(user, WINDOW_DATA_USER, text, user) then
		-- put the message in the unread window
		unreaddlg_append_private(user, text)
        -- flash the tray icon
        trayicon_flash(true)
	end
end

function ui_on_recv_groupmsg(user, group, text)
	if not chatdlg_handle_recvmsg(group, WINDOW_DATA_GROUP, text, user) then
		-- put the message in the unread window
		unreaddlg_append_group(group, text)
        -- flash the tray icon
        trayicon_flash(true)
	end
end

function set_ui_listener()
	user_setlistener(user_listener)
	luafeiq.on_recv_privatemsg = ui_on_recv_privatemsg
	luafeiq.on_recv_groupmsg = ui_on_recv_groupmsg
    luafeiq.on_recv_filemsg = ftwnd_onpushreq
    luafeiq.on_filerecv_process = ftwnd_onrequpdate
    luafeiq.on_filesend_process = ftwnd_onrequpdate
end

function wrap_in_tabs()
	tree.tabtitle = "Users"
	-- the size of the tree seems some bugs.
	-- here must set the correct rastersize, can make it works fine.
	tree.rastersize = "10x10" -- tree.rastersize has default value "400x200"
	local unread = unreaddlg_create()
	unread.tabtitle = "Unread"
	local grouplist = groupwnd_create()
	grouplist.tabtitle = "Groups"
	return iup.tabs { tree, grouplist, unread }, unread
end

function ui_switch_unread(tabs, page)
    tabs.value = page
end

function start_mainui()
	tree.font = UI_FONT 
	tree.name = "All"
    local tabs, unread = wrap_in_tabs()
	local dlg = iup.dialog
	{
        tabs,
		title = "luaFeiq", 
		size = "180x320",
		maxbox = "NO",
		menu = menu_create()
	} 
	dlg.close_cb = function(dlg)
        dlg.hidetaskbar = "YES"
		return iup.IGNORE
	end
    trayicon_init(dlg, function(flash, dclick)
        if not dclick then return end
        if flash then
            trayicon_flash(false)
            ui_switch_unread(tabs, unread)
        end
        dlg.hidetaskbar = "NO"
    end)
	dlg:showxy(iup.CENTER,iup.CENTER)
end


local udp = luafeiq_init()
env_init()
ftwnd_create()
set_ui_listener()
start_mainui()
luafeiq_start()
iup.SetIdle(idle_cb(udp))
iup.MainLoop()
trayicon_destroy()
luafeiq_release()

