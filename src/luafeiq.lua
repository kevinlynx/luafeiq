--[[
  The main entry
  Kevin Lynx
  1.26.2011
--]]

dofile("log.lua")
dofile('fileop_utils.lua')
dofile("utils.lua")
dofile("userlist.lua")
dofile("grouplist.lua")
dofile("message_defs.lua")
dofile("message.lua")
dofile("handler_table.lua")
dofile("message_handlers.lua")
dofile("udpentry.lua")
dofile("message_sender.lua")
dofile("message_history.lua")
dofile("config_reader.lua")
dofile("filetransfer/task_base.lua")
dofile("filetransfer/filerecv_taskparent.lua")
dofile("filetransfer/filesend_taskparent.lua")
dofile("filetransfer/filetrans_status.lua")
dofile("filetransfer/fileinfo.lua")

-- global object, handle these global data.
luafeiq = {}
luafeiq._VERSION = "0.5.1"

TEST_FlAG = false

function luafeiq_initdata()
	luafeiq.udp = nil
    -- called when recv some private messages
	luafeiq.on_recv_privatemsg = nil
    -- called when recv some group messages
	luafeiq.on_recv_groupmsg = nil
    -- called when recv file-recv request 
    luafeiq.on_recv_filemsg = nil
    -- called when file-recv processing
    luafeiq.on_filerecv_process = nil
    -- called when file-send processing
    luafeiq.on_filesend_process = nil
end

function luafeiq_handle_push_filerecv_req(ip, port, pktNo, info)
	local savedir = config_savedir()
    local validname = fileop_getvalidname(savedir, info.name)
    fileop_writeempty(savedir, validname)
	info.name = validname
	local identify = task_format_identify(ip, port, info)
	local ftsdata = fts_create(ip, port, pktNo, savedir, identify, FILE_TRANS_RECV, info)
	fts_push(luafeiq.ftstatus, ftsdata)
    if luafeiq.on_recv_filemsg ~= nil then
        luafeiq.on_recv_filemsg(ftsdata)
    end
end

function luafeiq_handle_recvfiles(arg)
	if pickmask(arg.cmd, OPT_FILEATTACH) == 0 then
		return false
	end
	logi(string.format("recv files from %s", arg.ip))
    -- actually the text here maybe cut off by '\0', so we use the raw string
	local p = skipto(arg.body, string.char(0), 0)
	if p == nil then 
        logw(string.format("invalid file-recv string (%s)", arg.body))
        return 
    end
	local filestr = string.sub(arg.body, p+1)
    local msgno = msg_read_msgno(arg.fullheader)
    logd(string.format("file-recv string :%s, %s", filestr, arg.body))
	fileinfo_parselist(arg.feiqheader, filestr, function(info) 
        -- maybe i should check UTF8OPT.
        info.name = env_s_g2u(info.name)
		luafeiq_handle_push_filerecv_req(arg.ip, arg.port, msgno, info)
	end)
    return true
end

function luafeiq_handle_recv_privatemsg(arg, text)
	local user = user_get(arg.ip)
	if user == nil then
		logw(string.format("recv private message from an unknown user(%s)",
		arg.ip))
		return
	end
	-- check whether attach some files
	local hasfile = luafeiq_handle_recvfiles(arg)
    if hasfile then
        text = text .. '\n[Has attached files, check out File-Transfer window]'
    end
	-- insert a chat log entry
	chatlog_insert(user.message, text, user.nickname)
	-- notify listener
	if luafeiq.on_recv_privatemsg ~= nil then
		luafeiq.on_recv_privatemsg(user, text)
	end
end

function luafeiq_handle_recv_groupmsg(arg, groupnum, text)
	local user = user_get(arg.ip)
	if user == nil then
		logw(string.format("recv group message from an unknown user(%s)",
		arg.ip))
		return
	end
	local group = group_get(groupnum)
	if group == nil then
		logi(string.format("recv nonexist group %s message, create a new one", groupnum));
        -- query if we focused on this group, if so the group will have a name
        local name = config_get_groupname(groupnum)
		group = group_create(groupnum, name)
		group_insert(group)
	end
	-- insert a chat log entry
	chatlog_insert(group.message, text, user.nickname)
	if luafeiq.on_recv_groupmsg ~= nil then
		luafeiq.on_recv_groupmsg(user, group, text)
	end
end

function luafeiq_send_groupentry(udp)
    config_iterate_group(function(number, name) 
        send_br_groupentry(udp, number)
        logi(string.format("send group entry message (%s,%s)", number, name))
    end)
end

function luafeiq_init()
	log_init("luafeiq_%s.log")
	logi(string.format("luafeiq %s init...", luafeiq._VERSION))
	if arg[1] == "test" then
		TEST_FLAG = true
		logi("test flag on")
	end
    if config_load() then
        logi("load config success")
    end
	mh_registerall()
    -- make sure the savedir exists
    fileop_mkdir(config_savedir())
    fileop_mkdir(PKGDIR)
    luafeiq.udp = udp_init()
	luafeiq.filerecv_task = ftr_start()
	luafeiq.filesend_task = fts_start()
    luafeiq.ftstatus = fts_new()
	ftr_setuser(luafeiq.filerecv_task, config_loginname(), config_pcname())
    return luafeiq.udp
end

function luafeiq_start()
	send_br_entry(luafeiq.udp)
	luafeiq_send_groupentry(luafeiq.udp)
end

function luafeiq_release()
	ftr_stop(luafeiq.filerecv_task)
    send_br_entryexit(luafeiq.udp)
	luafeiq.udp:close()
end

function luafeiq_runonce()
	udp_runonce(luafeiq.udp)
	ftr_receive(luafeiq.filerecv_task, luafeiq.on_filerecv_process)
	fts_receive(luafeiq.filesend_task, luafeiq.on_filesend_process)
end

function luafeiq_udp()
	return luafeiq.udp
end

function luafeiq_filerecv_task()
	return luafeiq.filerecv_task
end

function luafeiq_filesend_task()
	return luafeiq.filesend_task
end

function luafeiq_isself(username, pcname)
	return username == config_loginname() and pcname == config_pcname()
end

