--[[
  ui menu stuff
  Kevin Lynx
  2.8.2011
--]]

function test_load_shareinfo()
	local fp = io.open("../data/shareinfo.dat", "rb")
	if fp == nil then return nil end
	local s = fp:read("*a")
	fp:close()
	local pktNo, p = readin_from(s, ':', 0)
	return tonumber(pktNo), string.sub(s, p)
end

function menu_item_fs_test_cb(item)
    local ret, s = ui_popup_selfiles()
    if ret ~= "0" then return iup.DEFAULT end
    logd(string.format("%d, %s", ret, s))
    local dir, fl = ui_parse_filelist(s)
    logd(string.format("parse dir: %s", dir))
    for _, name in ipairs(fl) do
        logd(string.format("parse file name: %s", name))
    end
    -- test send some files to other 
    local pktNo = os.time()
    local ip = '10.34.64.44'
    local port = 2425
    local sendfile_s = ui_handle_sendreq(ip, port, pktNo, dir, fl)
    send_chat_msgfile(luafeiq_udp(), ip, port, "send files", sendfile_s, pktNo)
    return iup.DEFAULT
end

function menu_item_fr_test_cb(item)
	local pktNo, s = test_load_shareinfo()
	fileinfo_parselist("1", s, function(info) 
		luafeiq_handle_push_filerecv_req("192.168.0.2", DEST_PORT, pktNo, info)
	end)
	return iup.DEFAULT
end

function menu_item_file_exit_cb(item)
    local ret = iup.Alarm("Exit", "Exit this application?",
    "Exit", "No")
    if ret == 1 then
        -- exit the entire application
        return iup.CLOSE
    end
	return iup.IGNORE
end

function menu_item_file_transfer_cb(item)
    ftwnd_show()
    return iup.DEFAULT
end

function menu_subtest()
    if not TEST_FLAG then return nil end
	local fr_item = iup.item {title="Test file-recv"}
	fr_item.action = menu_item_fr_test_cb
	local fs_item = iup.item {title="Test file-send"}
	fs_item.action = menu_item_fs_test_cb
	local fr_menu = iup.menu {fr_item, fs_item}
	local test_main = iup.submenu {fr_menu, title="Test"}
	return test_main
end

function menu_subfile()
    local filetrans_item = iup.item {title="FileTransfer"}
    filetrans_item.action = menu_item_file_transfer_cb
	local exit_item = iup.item {title="Exit"}
	exit_item.action = menu_item_file_exit_cb
	local file_menu = iup.menu {filetrans_item, exit_item}
	local file_main = iup.submenu {file_menu, title="File"}
	return file_main
end

function menu_create()
	local file_sub = menu_subfile()
	local test_sub = menu_subtest()
	return iup.menu {file_sub, test_sub}
end

