--[[
  Use luafilesystem library to provide some file operation util functions
  testd on luafilesystem1.4.2
  Kevin Lynx
  2.9.2011
--]]
require('lfs')

-- make a directory, i.e: "../log/", this function will create directories 
-- recursivly. the 'dir' must end with '/'
function fileop_mkdir(dir)
    local SEP = string.byte('/')
    local size = string.len(dir)
    for i = 1, size, 1 do
        if string.byte(dir, i) == SEP then
            lfs.mkdir(string.sub(dir, 1, i))
        end
    end
end

-- append a file, make sure the directory exists already
function fileop_append(savedir, name, context)
    name = savedir .. name
    local fp = io.open(name, "ab+")
    if fp == nil then
        return false
    end
    fp:write(context)
    fp:flush()
    fp:close()
    return true
end

-- write an empty file
function fileop_writeempty(dir, name)
    name = dir .. name
    local fp = io.open(name, "wb")
    fp:close()
end

-- check whether a file exists
function fileop_fileexist(file)
    local r, s = lfs.attributes(file, 'mode')
    if r == 'file' then
        return true
    end
    return false
end

-- get a valid file name, check whether the file exist
function fileop_getvalidname(dir, name)
    local fname = dir .. name
    if not fileop_fileexist(fname) then
        return name
    end
    for i=1, 32, 1 do
        local s = name..i
        if not fileop_fileexist(dir..s) then return s end
    end
    return "NotFoundName.file"
end

-- get a file attributes:size, modifytime, flag_dir(or file)
function fileop_attributes(name)
    local attr = lfs.attributes(name)
    if attr == nil then return nil, nil, nil end
    local file_flag = true
    if attr.mode == 'directory' then
        file_flag = flase
    end
    return attr.size, attr.modification, file_flag
end

-- parse a directory name from something like: /a/b/file, ret:/a/b/
function fileop_parsedir(name)
    local sep = string.byte('\\')
    local sep2 = string.byte('/')
    local len = string.len(name)
    for i = len, 1, -1 do
        local n = string.byte(name, i)
        if n == sep or n == sep2 then
            return string.sub(name, 0, i), string.sub(name, i+1)
        end
    end
    return './', name
end

