--[[
  this is a helper functions collection file, it runs in the main thread which
  is the file-recv-task parent.
  Kevin Lynx
  2.7.2011
--]]
require('task')

-- start the file-recv task
function ftr_start()
	local id = task.id()
	local tsk, err = task.create("filetransfer/filerecv_task.lua", {id})
	if tsk < 0 then
		loge("create file-recv task failed: " .. err)
	else
		logi(string.format("create file-recv task success %d", tsk))
	end
	return tsk
end

function ftr_stop(tsk)
	if not task.isrunning(tsk) then
		logw(string.format("file-recv task is not running"))
		return
	end
	task.post(tsk, "", TASK_FLAG_EXIT)
	logd(string.format("post exit message (%d) to file-recv task(%d)", TASK_FLAG_EXIT, tsk));
	-- there maybe still some file-recv operation not completed
	task.receive(-1)
end

function ftr_pushreq(tsk, fmtstr)
	logd(string.format("post file-recv request:%s", fmtstr))
	task.post(tsk, fmtstr, TASK_FLAG_PUSHREQ)
end

-- set user and host 
function ftr_setuser(tsk, user, host)
	local s = task_formatuser(user, host)
	task.post(tsk, s, TASK_FLAG_SETUSER)
end

-- here we can make some ui stuff in main thread(task)
function ftr_onreqprocess(s, flag, listener)
	local name, percent = task_parseinfo(s)
	--logd(string.format("main task file-recv info <%s,%d,%f>", name, flag, percent))
    if listener ~= nil then
        listener(name, flag, percent)
    end
end

-- receive file-recv task message, better call in the main loop
function ftr_receive(tsk, listener)
	local s, flag, rc = task.receive(10)
	if rc < 0 then return end
	if flag == TASK_FLAG_ERROR then
		loge(string.format("file-recv task execute error:%s", s))
		return false
	end
	if flag >= TASK_FLAG_INFOBASE then
		ftr_onreqprocess(s, flag - TASK_FLAG_INFOBASE, listener)
	end
	return true
end

