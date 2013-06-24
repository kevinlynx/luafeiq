--[[
  Utility
  Kevin Lynx
  1.26.2011
--]]
require('bit')

PKGDIR = '../unknown_pkg/'

function dump_message(arg)
    local t = msg_read_type(arg.fullheader)
    local fp = io.open(string.format("%spkg_%x.dat", PKGDIR, t), "ab+")
    fp:write(arg.fullheader, arg.body)
    fp:flush()
    fp:close()
end

function check_string(str)
    local len = string.len(str)
    local i = 1
    while i <= len do
        if string.byte(str, i) == 0 then
            break
        end
        i = i + 1
    end
    if i == 1 then
        return "null"
    elseif i > len then
        return str 
    end
    return string.sub(str, 0, i-1)
end

function string_empty(str)
    return str == nil or str == "null" or str == "" or str == string.char(0)
end

function skipto(s, c, i)
   local s,_ = string.find(s, c, i) 
   return s
end

function readin(str, c, cnt)
    local s = 0
    while cnt > 0 do
        s = skipto(str, c, s)
		if s == nil then 
			return nil 
		end
		s = s + 1
		cnt = cnt - 1
    end
    local e = skipto(str, c, s)
    if e == nil then
        return string.sub(str, s)
    else
		e = e - 1
        return string.sub(str, s, e)
    end
end

-- read sub string start at p and end at the first c
function readin_from(str, c, p)
	if p > string.len(str) then return nil end
	local s = skipto(str, c, p)
	if s == nil then 
		return string.sub(str, p), string.len(str)+1
	end
	return string.sub(str, p, s-1), s+1
end

function pickmask(t, mask)
	return bit.band(t, mask)
end

function combine(a, b)
    return bit.bor(a, b)
end

function tohex(t)
    return bit.tohex(t)
end

