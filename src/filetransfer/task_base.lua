--[[
  some task definitions, this file is shared by file-recv task and the main task.
  Kevin Lynx
  2.7.2011
--]]

TASK_FLAG_ERROR = -1
TASK_FLAG_IGNORE = 0
TASK_FLAG_EXIT = 1
TASK_FLAG_PUSHREQ = 2
TASK_FLAG_SETUSER = 3
TASK_FLAG_INFOBASE = 10

function task_formatinfo(identify, percent)
	return string.format("%s:%f", identify, percent)
end

function task_parseinfo(s)
	local name, p = readin_from(s, ':', 0)
	local percent = readin_from(s, ':', p)
	return name, tonumber(percent)
end

function task_formatuser(user, host)
	return string.format("%s:%s", user, host)
end

function task_parseuser(s)
	local user, p = readin_from(s, ':', 0)
	local host = readin_from(s, ':', p)
	return user, host
end

-- generate a default request identifier:
-- ip#port#id#name
function task_format_identify(ip, port, info)
    return string.format("%s#%d#%s#%s", ip, port, info.id, info.name);
end

function task_parse_identify(identify)
    local SEP = '#'
    local ip, p = readin_from(identify, SEP, 0)
    local port, p = readin_from(identify, SEP, p)
    local id, p = readin_from(identify, SEP, p)
    local name, p = readin_from(identify, SEP, p)
    return ip, tonumber(port), id, name
end

