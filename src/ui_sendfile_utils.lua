--[[
  some ui utility functions used for file send
  Kevin Lynx
  2.10.2011
--]]

-- popup a file selecting dialog, return a string which can be parsed later.
function ui_popup_selfiles()
    local dlg = iup.filedlg {
        dialogtype = 'OPEN',
        multiplefiles = 'YES',
        title = 'Select files'
    }
    iup.Popup(dlg, iup.CENTER, iup.CENTER)
    return dlg.status, dlg.value
end

-- s is returned by ui_popup_selfiles.
-- format: /xxx/xxx/file
-- or : /xxx/xxx|file1|file2
function ui_parse_filelist(s)
    local SEP = '|'
    local fl = {}
    local dir = nil
    local p = skipto(s, SEP, 0)
    if p == nil then -- only one file
        dir, fl[#fl+1] = fileop_parsedir(s)
        return dir, fl
    end
    -- multiple files
    dir = string.sub(s, 0, p-1)..'/'
    local name
    p = p + 1
    name, p = readin_from(s, SEP, p)
    while not string_empty(name) do
        fl[#fl+1] = name
        name, p = readin_from(s, SEP, p)
    end
    return dir, fl
end

-- push these file-send request, and return a string which will be sent later
function ui_handle_sendreq(ip, port, pktNo, dir, fnamelist)
    local infolist = fileinfo_createlist(dir, fnamelist)
    local formats = fileinfo_formatlist(infolist) -- used to send message
    -- push send file request to file-send task
    for _, info in ipairs(infolist) do
        local infos = fileinfo_format(info)
        local identify = task_format_identify(ip, port, info)
        local ftsdata = fts_create(ip, port, pktNo, dir, identify, FILE_TRANS_SEND, info)
        fts_push(luafeiq.ftstatus, ftsdata)
        fts_setstatus(ftsdata, TRANS_STATUS_WAIT)
        ftwnd_onpushreq(ftsdata)
        local reqstr = fts_format(ftsdata, infos)
        -- done so many steps, here we are, we can push the file-send request to
        -- the file-send task.
        fts_pushreq(luafeiq_filesend_task(), reqstr)
    end 
    return formats
end

