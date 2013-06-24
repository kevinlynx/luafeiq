--[[
  file transfer module base definitions
  Kevin Lynx
  2.7.2011
--]]

-- message type
MSG_GETFILEDATA = 0x0060
MSG_GETDIRFILES = 0x0062

MASK_CMD = 0x000000ff

-- for tcp recv buffer size
RECV_MAXBYTES = 65536
SEND_MAXBYTES = 65536
-- recv cache size:1M
CACHE_SIZE = 1024*1024

USER_NAME = ""
HOST_NAME = ""
MSG_HEADER = "1" --ip messager header

function ft_setuser_host(user, host)
	USER_NAME = user
	HOST_NAME = host
end

-- create a file-retrieve message which means send a message to file-host
-- to ask some file.
function ft_createmsg(cmd, body)
	local s = string.format("%s:%d:%s:%s:%d:%s",
		MSG_HEADER, os.time(), USER_NAME, HOST_NAME, cmd, body)
	return s
end

-- parse a string as a full message, we assume the message is full even it's
-- received from a tcp connection. because the message here has a big chance 
-- to be an invalid message, so i should take more check on it.
function ft_parsemsg(s)
    local SEP = ':'
    local p = 0
    -- ignore these fields i donot care
    _, p = readin_from(s, SEP, p)
    _, p = readin_from(s, SEP, p)
    _, p = readin_from(s, SEP, p)
    _, p = readin_from(s, SEP, p)
    local cmd, p = readin_from(s, SEP, p)
    if cmd == nil then return 0, nil end
    local body = string.sub(s, p)
    cmd = tonumber(cmd)
    return pickmask(MASK_CMD, cmd), body 
end

-- format a file transfer request string like:1:101:0
function ft_format(pktNo, id, offset)
    local s = string.format("%x:%x", pktNo, id)
    if offset ~= nil then
        s = string.format("%s:%x", s, offset)
    end
    return s
end

-- parse a file transfer string
function ft_parse(s)
    local SEP = ':'
    local pktNo, p = readin_from(s, SEP, 0)
    local id, p = readin_from(s, SEP, p)
    -- we donot care 'offset', so ignore here
    return tonumber(pktNo, 16), tonumber(id, 16)
end

