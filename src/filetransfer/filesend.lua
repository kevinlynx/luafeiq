--[[
  handle send file stuff
  interfaces:
  sf_create/sf_destroy/sf_setlistener/sf_reqparse/sf_reqpush/sf_process
  Kevin Lynx
  2.10.2011
--]]
socket = require('socket')

BIND_PORT = 2425
REQ_STATUS_ERROR = -1
REQ_STATUS_WAIT = 0
REQ_STATUS_PROCESS = 1
REQ_STATUS_DONE = 2

-- create a send-file object
--[[
 sf has some different data structure from rf(file-recv):
 #request_table: a key-value container, ip-req_list
 #req_list: a key-value container, file_id-request
 when sf-task accept a new client, it first check in request_table by ip, if the value of 
 this ip is nil, reject it. when sf-task receive file retrieve request, it will get the
 req_list from request_table first, and get the request by file-id, if the request is not nil,
 mark the request can be sended. whenever a socket is writable, find the ip associated to the socket,
 and find the request which can be sended, process it until it's done. when all the requests of a 
 socket have been done, remove the req_list.
--]]
function sf_create()
    local sf = {}
    sf.reqs = {}
    sf.req_cnt = 0
    sf.socks = {}
    sf.sock2ip = {}
    sf.listener = nil
    sf_svrsock_create(sf)
    return sf
end

function sf_destroy(sf)
    sf_closesock(sf, sf.socks[1])
end

function sf_svrsock_create(sf)
    sf.socks[1] = socket.bind("*", BIND_PORT)
    sf.socks[1]:settimeout(1)
    sf_mapsock2ip(sf, sf.socks[1], "*")
end

function sf_mapsock2ip(sf, s, ip)
    sf.sock2ip[s] = ip
end

-- listener: onprocess(identify, status, percent)
-- status: 0(start), 1(processing), 2(done), -1(failed)
function sf_setlistener(sf, listener)
    sf.listener = listener
end

function sf_reqlist_new(sf, ip)
    sf.reqs[ip] = {}
    sf.req_cnt = sf.req_cnt + 1
    return sf.reqs[ip]
end

function sf_reqlist_del(sf, ip)
    sf.reqs[ip] = nil
    sf.req_cnt = sf.req_cnt - 1
    if sf.req_cnt <= 0 then
        sf.reqs = {}
    end
end

-- construct a request
function sf_reqcreate(identify, ip, port, pktNo, dir, fileinfo)
	local req = fileinfo
    req.identify = identify
	req.offset = 0
	req.fp = nil
    req.sock = nil
    req.dir = dir
	req.ip = ip
	req.port = port
	req.pktNo = pktNo
    req.status = REQ_STATUS_WAIT
	return req
end

-- parse a request from a string
-- format: identify:ip:port:pktNo:dir:file_info
function sf_reqparse(reqs)
    logd(string.format("sf_reqparse: %s", reqs))
	local p = 0
	local SEP = ':'
    local identify, p = readin_from(reqs, SEP, 0)
	local ip, p = readin_from(reqs, SEP, p)
	local port, p = readin_from(reqs, SEP, p)
    port = tonumber(port)
	local pktNo, p = readin_from(reqs, SEP, p)
    pktNo = tonumber(pktNo)
    local dir, p = readin_from(reqs, string.char(0), p)
	local infos = string.sub(reqs, p)
    logd(string.format("parse file-info: %s", infos))
	local fileinfo = fileinfo_parse(infos)
	return sf_reqcreate(identify, ip, port, pktNo, dir, fileinfo)
end

function sf_reqpush(sf, req)
	logi(string.format("push a new file send request (%d, %s, %s)", req.id, req.ip, req.name))
    local reqlist = sf.reqs[req.ip]
    if reqlist == nil then
        reqlist = sf_reqlist_new(sf, req.ip)
    end
    reqlist[req.id] = req
end

-- find a file-retrieve information
function sf_reqfind(sf, ip, id)
    local reqlist = sf.reqs[ip]
    if reqlist == nil then return nil end
    return reqlist[id]
end

-- find a processing request
function sf_reqfind_process(sf, ip, s)
    local reqlist = sf.reqs[ip]
    if reqlist == nil then return nil end
    for i, v in pairs(reqlist) do
        if v.status == REQ_STATUS_PROCESS and
           v.sock == s then
            return v
        end
    end
    return nil
end

-- check whether a req_list of an IP is empty
function sf_reqlist_empty(reqlist)
    for _, v in pairs(reqlist) do -- ipairs will not work here
        if v ~= nil then return false end
    end
    return true
end

-- check whether the IP has some requests
function sf_reqempty(sf, ip)
    local reqlist = sf.reqs[ip]
    return reqlist == nil or sf_reqlist_empty(reqlist)
end

-- check whether all requests of an IP have been done, if so, remove it
function sf_reqcheck_alldone(sf, ip)
    local reqlist = sf.reqs[ip]
    if reqlist == nil then return true end
    for i, v in pairs(reqlist) do
        if v.status ~= REQ_STATUS_ERROR and v.status ~= REQ_STATUS_DONE then
            return false
        end
    end
    -- and all request of this IP is either DONE or ERROR
    sf_reqlist_del(sf, ip)
    logi(string.format("%s all requests have been done", ip))
    return true
end

function sf_reqclose(sf, req)
    if req.fp ~= nil then
        req.fp:close()
        req.fp = nil
    end
    if req.sock ~= nil then
        sf_closesock(sf, req.sock)
        req.sock = nil
    end
end

function sf_reqonerror(sf, req, err)
    req.status = REQ_STATUS_ERROR
    sf_reqclose(sf, req)
    if sf.listener ~= nil then
        sf.listener.onprocess(req.identify, -1, 0)
    end
    sf_reqcheck_alldone(sf, req.ip)
end

-- start the request
function sf_reqstart(sf, req, s)
    local err = nil
    local name = req.dir..req.name
    req.status = REQ_STATUS_PROCESS 
    req.sock = s
    req.fp, err = io.open(name, "rb")
    if req.fp == nil then
        sf_reqonerror(sf, req, err)
        loge(string.format("open file %s failed (%s)", name, err))
        return false
    end
    logi(string.format("start to process request (%s)", req.name))
    if sf.listener ~= nil then
        sf.listener.onprocess(req.identify, 0, 0)
    end
    return true
end

function sf_reqdone(sf, req)
    logi(string.format("request (%s) is done", req.name))
    sf_reqclose(sf, req)
    req.status = REQ_STATUS_DONE
    if sf.listener ~= nil then
        sf.listener.onprocess(req.identify, 2, 1.0)
    end
    sf_reqcheck_alldone(sf, req.ip)
end

function sf_reqget_sendbytes(req)
    local ret = req.size - req.offset
    if ret > SEND_MAXBYTES then
        ret = SEND_MAXBYTES
    end
    return ret
end

function sf_reqcompleted(req)
    return req.offset >= req.size
end

-- process a request (send data)
function sf_reqprocess(sf, req, s)
    local cnt = sf_reqget_sendbytes(req)
    local data = req.fp:read(cnt)
    local r, err = s:send(data)
    if r == nil then
        logw(string.format("send files %s error: %s", req.name, err))
        sf_reqerror(sf, req, err)
        return false
    end
    if r < cnt then -- only sent a part of
        local back = cnt - r
        req.fp:seek('cur', -back) -- seek back
    end
    req.offset = req.offset + r
    if sf_reqcompleted(req) then
        sf_reqdone(sf, req)
        return true
    end
    if sf.listener ~= nil then
        sf.listener.onprocess(req.identify, 1, req.offset/req.size)
    end
end

-- close all client sockets
function sf_closeall(sf)
    for i = 2, #sf.socks, 1 do
        sf.socks[i]:close()
        sf.socks[i] = nil
    end
end

-- close a socket
function sf_closesock(sf, s)
    s:close()
    if s == sf.socks[1] then
        sf_closeall(sf)
        sf.socks = {}
        sf.sock2ip = {}
        return
    end
    for i = 2, #sf.socks, 1 do
        if sf.socks[i] == s then
            table.remove(sf.socks, i)
            sf.sock2ip[s] = nil
            return
        end
    end
end

function sf_addsock(sf, s, ip)
    s:settimeout(1)
    sf.socks[#sf.socks+1] = s
    sf.sock2ip[s] = ip
end

-- accept a new client
function sf_onaccept(sf)
    local s, err = sf.socks[1]:accept()
    if s == nil then
        logw(string.format("accept a new connection failed:%s", err))
        return false
    end
    -- check whether it's valid
    local ip, port = s:getpeername()
    logi(string.format("accepted a client (%s-%d)", ip, port))
    if sf_reqempty(sf, ip) then
        logw(string.format("invalid file-retrieve request from (%s), close it", ip))
        s:close()
        return false
    end
    -- a valid connection
    sf_addsock(sf, s, ip)
    return true
end

function sf_onretrieve_file(sf, ip, body, s)
    local pktNo, id = ft_parse(body)
    local req = sf_reqfind(sf, ip, id)
    if req ~= nil then
        logi(string.format("find send-req %s for %s", req.name, ip))
    end
    if req == nil or req.pktNo ~= pktNo then
        logw(string.format("%s request an invailid file-recv (%d,%d)", ip, pktNo, id))
        return
    end
    logd(string.format("recv retrieve-file %s cmd %d, %d", req.name, pktNo, id))
    sf_reqstart(sf, req, s)
end

-- receive some message
function sf_onreceive(sf, s)
    local ip = sf.sock2ip[s]
    logd(string.format("sf_onreceive :%s", ip))
    local str, err, pstr = s:receive(RECV_MAXBYTES)
    if str == nil and err ~= "timeout" then -- receive error or the peer closed
        if err == "closed" then
            logi(string.format("client %s closed", ip))
        else
            logw(string.format("receive from %s failed %s", ip, err))
        end
        sf_closesock(sf, s)
        return
    end
    if str == nil then
        logd(string.format("receive a nil string, err:%s", err))
    end
    if pstr ~= nil then
        logd(string.format("receive a partial string: %s", pstr))
        str = pstr
    end
    local cmd, body = ft_parsemsg(str) 
    if cmd == MSG_GETFILEDATA then
        sf_onretrieve_file(sf, ip, body, s) 
    elseif cmd == MSG_GEDIRFILES then
        -- not support now
        logw(string.format("receive GETDIRFILES from %s which not support now", ip))
    else
        logw(string.format("invalid message string:%s", str))
    end
end

-- called when some socket are writable
function sf_onsend(sf, s)
    local ip = sf.sock2ip[s]
    local req = sf_reqfind_process(sf, ip, s)
    if req == nil then return end -- no request should be processed of on this IP
    sf_reqprocess(sf, req, s)
end

-- the main process entry
function sf_process(sf)
    if sf.req_cnt == 0 then return false end
    local readsocks, writesocks = socket.select(sf.socks, sf.socks, 1)
    for _, s in ipairs(readsocks) do
        if s == sf.socks[1] then -- can accept some connection
            sf_onaccept(sf)
        else
            sf_onreceive(sf, s)
        end
    end
    for _, s in ipairs(writesocks) do
        if s ~= sf.socks[1] then -- is this necessary ?
            sf_onsend(sf, s)
        end
    end
    return true
end


