--[[
  this is a helper functions collection file, it runs in the main thread which
  is the file-send-task parent.
  Kevin Lynx
  2.10.2011
--]]
require('task')

-- start the file-send task
function fts_start()
	local id = task.id()
	local tsk, err = task.create("filetransfer/filesend_task.lua", {id})
	if tsk < 0 then
		loge("create file-send task failed: " .. err)
	else
		logi(string.format("create file-send task success %d", tsk))
	end
	return tsk
end

function fts_stop(tsk)
	if not task.isrunning(tsk) then
		logw(string.format("file-send task is not running"))
		return
	end
	task.post(tsk, "", TASK_FLAG_EXIT)
	logd(string.format("post exit message (%d) to file-send task(%d)", TASK_FLAG_EXIT, tsk));
	-- there maybe still some file-send operation not completed
	task.receive(-1)
end

function fts_pushreq(tsk, fmtstr)
	logd(string.format("post file-send request:%s", fmtstr))
	task.post(tsk, fmtstr, TASK_FLAG_PUSHREQ)
end

-- here we can make some ui stuff in main thread(task)
function fts_onreqprocess(s, flag, listener)
	local name, percent = task_parseinfo(s)
	--logd(string.format("main task file-recv info <%s,%d,%f>", name, flag, percent))
    if listener ~= nil then
        listener(name, flag, percent)
    end
end

-- receive file-send task message, better call in the main loop
function fts_receive(tsk, listener)
	local s, flag, rc = task.receive(10)
	if rc < 0 then return end
	if flag == TASK_FLAG_ERROR then
		loge(string.format("file-send task execute error:%s", s))
		return false
	end
	if flag >= TASK_FLAG_INFOBASE then
		fts_onreqprocess(s, flag - TASK_FLAG_INFOBASE, listener)
	end
	return true
end

