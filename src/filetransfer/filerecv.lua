--[[
  handle recv file stuff
  Kevin Lynx
  2.7.2011
--]]
socket = require('socket')

-- create a recv-file object
function rf_create()
	local rf = {}
	rf_init(rf)
	rf.listener = nil
	return rf
end

function rf_init(rf)
	rf.tcp = nil
	rf.reqs = {}
	rf.req_index = 1
end

-- listener:
-- processing a request: onprocess(name, status, percent)
-- status: 0(start), 1(processing), 2(done), -1(failed)
function rf_setlistener(rf, listener)
	rf.listener = listener
end

-- construct a request
function rf_reqcreate(identify, ip, port, pktNo, savedir, fileinfo)
	local req = fileinfo
    -- donot confuse about 'id' and 'identify', they're different here
    req.identify = identify
	req.offset = 0
	req.file = ""
    req.savedir = savedir
	req.ip = ip
	req.port = port
	req.pktNo = pktNo
	return req
end

-- parse a request from a string
-- format: ip:port:pktNo:savedir:file_info
function rf_reqparse(reqs)
	local p = 0
	local SEP = ':'
    local identify, p = readin_from(reqs, SEP, 0)
	local ip, p = readin_from(reqs, SEP, p)
	local port, p = readin_from(reqs, SEP, p)
	local pktNo, p = readin_from(reqs, SEP, p)
    local savedir, p = readin_from(reqs, string.char(0), p)
	local infos = string.sub(reqs, p)
	local fileinfo = fileinfo_parse(infos)
	return rf_reqcreate(identify, ip, port, pktNo, savedir, fileinfo)
end

function rf_reqpush(rf, req)
	logi(string.format("push a new file recv request (%s)", req.ip))
	rf.reqs[#rf.reqs+1] = req
end

-- send file recv request to host
function rf_reqsend(rf, req)
	local msg = nil
	-- not very sure why it maybe 0.
	if req.attr == 0 or pickmask(req.attr, FILE_ATTR_REGULAR) then
		local body = ft_format(req.pktNo, req.id, 0)
		msg = ft_createmsg(MSG_GETFILEDATA, body)
	elseif pickmask(req.attr, FILE_ATTR_DIR) then
		-- not support now
        logw(string.format("currently not support recv-directory from %s", req.ip))
	end
	if msg ~= nil then
		logd(string.format("send file recv request (%s) to (%s-%d)",
			msg, req.ip, req.port))
		rf.tcp:send(msg)
	end
end

-- check whether the request has been completed
function rf_reqcompleted(req)
	return req.offset >= req.size
end

-- the request has been done, save the received file
function rf_reqdone(rf, req)
	logi(string.format("request %s done", req.name))
	rf_reqflush(rf, req)
	if rf.listener ~= nil then
		rf.listener.onprocess(req.identify, 2, 1.0)
	end
	-- the stupid server will disconnect this socket, so when we process the 
	-- next request, we should create a new socket.
	rf_reqdisconnect(rf)
end

-- flush the received file cache
function rf_reqflush(rf, req)
	logd(string.format("flush the file %s context", req.name))
	fileop_append(req.savedir, req.name, req.file)	
	req.file = ""
end

-- step into the next request
function rf_reqnext(rf, req)
	rf.req_index = rf.req_index + 1
	local next_req = rf.reqs[rf.req_index]
	if next_req == nil then 
		logi("file-recv has done all requests")
		return 
	end
	if next_req.ip == req.ip and next_req.port == req.port then
		return
	end
	-- new connection
	if not rf_reqconnect(rf, next_req) then
		rf_reqnext(rf, next_req)
	end
end

function rf_reqdisconnect(rf)
	rf.tcp:close()
	rf.tcp = nil
end

-- connect to host
function rf_reqconnect(rf, req)
	if rf.tcp ~= nil then
		rf_reqdisconnect(rf)
	end
	rf.tcp = socket.tcp()
	local ret, err = rf.tcp:connect(req.ip, req.port)
	if ret == nil then
		loge(string.format("connect to host (%s-%d)(%s) failed", req.ip, req.port, err))
		rf_reqdisconnect(rf)
		return false
	end
	logi(string.format("connect to host (%s-%d) success", req.ip, req.port))
	return true
end

-- start a request
function rf_reqstart(rf, req)
	logi(string.format("start to process request(%s:%d)", req.name, req.size))
	rf_reqsend(rf, req)
	if rf.listener ~= nil then
		rf.listener.onprocess(req.identify, 0, 0)
	end
end

function rf_reqonfailed(rf, req)
	if rf.listener ~= nil then
		rf.listener.onprocess(req.identify, -1, 0)
	end
end

function rf_reqremain(req)
	local remain = req.size - req.offset
	if remain > RECV_MAXBYTES then
		remain = RECV_MAXBYTES
	end
	return remain
end

-- process a request
-- return -1 indicate error, 0 indicate normal, 1 indicate this reuqest is done
function rf_reqprocess(rf, req)
	--logd(string.format("enter reqprocess %s, %d, %d", req.name, req.size, req.offset))
	if rf.tcp == nil then 
		if not rf_reqconnect(rf, req) then
			rf_reqonfailed(rf, req)
			return -1
		end
	end
	if req.offset == 0 then
		rf_reqstart(rf, req)
	end
	local s, err = rf.tcp:receive(rf_reqremain(req))
	if s == nil then
		rf_reqonfailed(rf, req)
		loge(string.format("failed to receive data from (%s-%d)(%s)", req.ip, req.port, err))
		return -1
	end
	req.file = req.file .. s
	req.offset = req.offset + string.len(s)
	--logd(string.format("received %d data", string.len(s)))
	if rf_reqcompleted(req) then 
		rf_reqdone(rf, req)
		return 1
	end
	if string.len(req.file) >= CACHE_SIZE then
		rf_reqflush(rf, req)
	end
	if rf.listener ~= nil then
		rf.listener.onprocess(req.identify, 1, req.offset/req.size)
	end
	return 0
end

-- return true indicate busy, false is not busy
function rf_process(rf)
	if #rf.reqs == 0 then 
		return false 
	end
	local req = rf.reqs[rf.req_index]	
	if req == nil then
		rf_init(rf)
		return false
	end
	local ret = rf_reqprocess(rf, req)
	if ret ~= 0 then
		rf_reqnext(rf, req)
	end
	return true
end

