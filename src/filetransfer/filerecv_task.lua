--[[
  represents file-recv task, handle lua task stuff
  Kevin Lynx
  2.7.2011
--]]
FILE_PATH = "filetransfer/"
dofile(FILE_PATH..'filerecv.lua')
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

function rftask_init()
	log_init("file_recv_%s.log")
	logi("file-recv task start to run")
end

function rftask_handlemsg(rf, s, flag)
	if flag == TASK_FLAG_PUSHREQ then -- received requests
		local req = rf_reqparse(s)
		rf_reqpush(rf, req)
	elseif flag == TASK_FLAG_SETUSER then
		local user, host = task_parseuser(s)
		logi(string.format("file-recv set user(%s) host(%s)", user, host))
		ft_setuser_host(user, host)
	end
end

function rftask_run()
	rftask_init()
	local rf = rf_create()
	local busy = false
	local t
	rf_setlistener(rf, req_listener)
	while true do
		busy = rf_process(rf)
		if busy then t = 10
		else t = 1000 end
		local s, flag, rc = task.receive(t)
		if flag == TASK_FLAG_EXIT then
			break
		end
		if rc == 0 then -- received task message
			rftask_handlemsg(rf, s, flag)
		end
	end
	logi("file-recv task exit")
	task.post(parent, "", TASK_FLAG_EXIT)
end

function errhandler(obj)
	loge("catch an execute error")
	local stack = debug.traceback()
	loge(stack)
	return false, obj
end

local ret, err = xpcall(rftask_run, errhandler)
if not ret then
    task.post(parent, err, TASK_FLAG_ERROR)
end

