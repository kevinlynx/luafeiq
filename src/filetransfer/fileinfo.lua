--[[
  Some file stuff related file recv/send.
  Kevin Lynx
  2.6.2011
--]]

-- file attributes
FILE_ATTR_REGULAR = 0x0001
FILE_ATTR_DIR = 0x0002

-- used to generate file id
fi_id_seed = 0

function fileinfo_genid()
    fi_id_seed = fi_id_seed + 1
    return fi_id_seed
end

-- parse file information from a string.
-- format: id:name:size:time:attr
function fileinfo_parse(s)
	local info = {}
	local SEP = ':'
	local p = 0
    -- my lord, IPTux has different format, a file-info string may start
    -- from ':' so we may got a nil id. the simplest and ugliest way to 
    -- solve this problem is ..as below
    repeat
        info.id, p = readin_from(s, SEP, p)
        info.id = tonumber(info.id)
    until info.id ~= nil
	info.name, p = readin_from(s, SEP, p)
	info.size, p = readin_from(s, SEP, p);
	info.size = tonumber(info.size, 16)
	info.time, p = readin_from(s, SEP, p)
	info.time = tonumber(info.time, 16)
	info.attr, p = readin_from(s, SEP, p)
	info.attr = tonumber(info.attr, 16)
	return info
end

function fileinfo_new(name, size, time, attr)
    local info = {}
    info.id = fileinfo_genid()
    info.name = name
    info.size = size
    info.time = time
    info.attr = attr
    return info
end

-- create a list of file info from a list of file name
-- these file must be in the same directory
function fileinfo_createlist(dir, fnamelist)
    local fileinfos = {}
    for _, name in ipairs(fnamelist) do
        local size, time, r = fileop_attributes(dir..name)    
        if size ~= nil then
            local attr = FILE_ATTR_REGULAR 
            if not r then attr = FILE_ATTR_DIR end
            local info = fileinfo_new(name, size, time, attr)
            fileinfos[#fileinfos+1] = info
        end
    end
    return fileinfos
end

-- format a list of file-info into a string 
function fileinfo_formatlist(infos)
    local SEP = fileinfo_getsep() -- we use 0x07 as separator
    local s = ""
    for _, info in ipairs(infos) do
        s = s..string.format("%s:%s", fileinfo_format(info), SEP)
    end
    return s
end

-- format file-info into a string
function fileinfo_format(info)
	return string.format("%d:%s:%x:%x:%x", info.id, info.name, info.size,
		info.time, info.attr)
end

-- currently i found that IP messager and FeiQ have different file-info
-- separator.
function fileinfo_getsep(header)
	if header == "1" then
		return string.char(0x01) -- IP messager
	else
		return string.char(0x07) -- IPTux or FeiQ
	end
end

-- parse file info list from a string.
function fileinfo_parselist(header, s, listener)
	local SEP = fileinfo_getsep(header)
	local infos, p = readin_from(s, SEP, 0)
	while not string_empty(infos) do
		local info = fileinfo_parse(infos)
		infos, p = readin_from(s, SEP, p)
		if listener ~= nil then
			listener(info)
		end
	end
end

