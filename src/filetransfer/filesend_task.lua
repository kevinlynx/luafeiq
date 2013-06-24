--[[
  represents file-send task, handle lua task stuff, even this file is similar to filerecv_task.lua,
  it's still different, and the most important is they run in different lua_state
  Kevin Lynx
  2.10.2011
--]]
FILE_PATH = "filetransfer/"
dofile(FILE_PATH..'filesend.lua')
dofile(FILE_PATH..'filetransfer.lua')
dofile(FILE_PATH..'fileinfo.lua')
dofile(FILE_PATH..'dep.lua')
dofile(FILE_PATH..'task_base.lua')

parent = arg[1]
req_listener = {}
req_listener.onprocess = function(identify, flag, percent)
	local s = task_formatinfo(identify, percent)
	task.post(parent, s, TASK_FLAG_INFOBASE + flag)
end

function sftask_init()
	log_init("file_send_%s.log")
	logi("file-send task start to run")
end

function sftask_handlemsg(sf, s, flag)
	if flag == TASK_FLAG_PUSHREQ then -- received requests
		local req = sf_reqparse(s)
		sf_reqpush(sf, req)
	end
end

function sftask_run()
	sftask_init()
	local sf = sf_create()
	local busy = false
	local t
	sf_setlistener(sf, req_listener)
	while true do
		busy = sf_process(sf)
		if busy then t = 10
		else t = 1000 end
		local s, flag, rc = task.receive(t)
		if flag == TASK_FLAG_EXIT then
			break
		end
		if rc == 0 then -- received task message
			sftask_handlemsg(sf, s, flag)
		end
	end
	logi("file-send task exit")
	task.post(parent, "", TASK_FLAG_EXIT)
end

function errhandler(obj)
	loge("catch an execute error")
	local stack = debug.traceback()
	loge(stack)
	return false, obj
end

local ret, err = xpcall(sftask_run, errhandler)
if not ret then
    task.post(parent, err, TASK_FLAG_ERROR)
end

