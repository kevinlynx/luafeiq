--[[
  store file transfer status data, this file is only used in UI module.
  we use the default file-trans request identifier here.
  Kevin Lynx
  2.9.2011
--]]
-- file transfer type
FILE_TRANS_SEND = 1
FILE_TRANS_RECV = 2

TRANS_STATUS_ERROR = 0
TRANS_STATUS_CONFIRM = 1
TRANS_STATUS_WAIT = 2
TRANS_STATUS_PROCESS = 3
TRANS_STATUS_DONE = 4

-- new a fts table, this table stores fts-data created by fts_create
function fts_new()
    local fts = {}
    return fts
end

-- create a file transfer data
function fts_create(ip, port, pktNo, savedir, identify, t, fileinfo)
    local data = fileinfo
    data.ip = ip
    data.optype = t
    data.port = port
    data.identify = identify
    data.percent = 0
	data.pktNo = pktNo
	data.savedir = savedir
	data.status = TRANS_STATUS_CONFIRM
    return data
end

-- if infos is nil, it will format it here.
function fts_format(data, infos)
	-- fix: because dir may container ':' character in Windows, so i use char(0)
	local h = string.format("%s:%s:%d:%d:%s", data.identify, data.ip, data.port, 
		data.pktNo, data.savedir)
    if infos == nil then infos = fileinfo_format(data) end
	return h..string.char(0)..infos
end

function fts_push(fts, data)
    fts[data.identify] = data
end

function fts_setstatus(data, s)
	data.status = s
end

function fts_getstatus_desc(data)
	local s = data.status
	if s == TRANS_STATUS_CONFIRM then
		return "Conform"
	elseif s == TRANS_STATUS_WAIT then
		return "Wait"
	elseif s == TRANS_STATUS_PROCESS then
		return string.format("%d%%", math.floor(data.percent*100))
	elseif s == TRANS_STATUS_DONE then
		return "Done"
	end
	return "Error"
end

-- flag comes from filerecv.lua
function fts_update(data, percent, flag)
    data.percent = percent
	if flag < 0 then
		fts_setstatus(data, TRANS_STATUS_ERROR)
	elseif flag == 1 then
		fts_setstatus(data, TRANS_STATUS_PROCESS)
	elseif flag == 2 then
		fts_setstatus(data, TRANS_STATUS_DONE)
	end
end

function fts_find(fts, identify)
    return fts[identify]
end

function fts_getop_desc(op)
    if op == FILE_TRANS_SEND then
        return "Send"
    end
    return "Recv"
end

