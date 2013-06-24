--[[
  file transfer window
  Kevin Lynx
  2.9.2011
--]]
ft_window = {}

TIPS_ON_NOSEL = "Select item to view file infomation."

function ftwnd_create()
	local tip = iup.label {
		expand = "HORIZONTAL", size="x10", alignment="ACENTER:ACENTER",
		title="Double click to receive the file."
	}
	ft_window.status = iup.label { expand = "HORIZONTAL", size="x15", alignment="ACENTER:ACENTER",
		title=TIPS_ON_NOSEL }
    ft_window.tree = iup.tree {
        name = "FileTransfer",
        font = UI_FONT,
        rastersize = "10x10",
		executeleaf_cb = ftwnd_executeleaf_cb,
		selection_cb = ftwnd_selection_cb
    }
    ft_window.dlg = iup.dialog { iup.vbox {
			ft_window.tree,
			ft_window.status,
			tip,
			gap="10",
			margin="10x10",
		},
        title = "File Transfer",
        size = "380x240",
    }
    iup.Map(ft_window.dlg)
end

function ftwnd_show()
    ft_window.dlg:showxy(iup.CENTER, iup.CENTER)
end

-- format a tree leaf name(somefile(recv:20%) i.e
function ftwnd_formatleaf(ftsdata)
	local opdesc = fts_getop_desc(ftsdata.optype)
	local statusdesc = fts_getstatus_desc(ftsdata)
	return string.format("%s(%s:%s)", ftsdata.name, opdesc, statusdesc)
end

function ftwnd_executeleaf_cb(tree, id)
    local ftsdata = iup.TreeGetTable(tree, id)
	if ftsdata.status ~= TRANS_STATUS_CONFIRM then
		return
	end
	fts_setstatus(ftsdata, TRANS_STATUS_WAIT)
	-- update leaf name
	local leafs = ftwnd_formatleaf(ftsdata)
    local namei = "name"..id
    ft_window.tree[namei] = leafs
    ft_window.tree.redraw = "YES"

	local fmtstr = fts_format(ftsdata)
	ftr_pushreq(luafeiq_filerecv_task(), fmtstr)
end

function ftwnd_format_filesize(size)
	if size < 1024 then -- < 1k
		return string.format("%d(bytes)", size)
	elseif size < 1024*1024 then -- < 1M
		return string.format("%.2f(kb)", size/1024)
	end
	-- > 1M
	local n = size/1024/1024
	return string.format("%.2f(M)", n)
end

function ftwnd_format_fileinfo(ftsdata)
	return string.format("%s  size:%s  trans-id:%d  save-to:%s",
		ftsdata.name, ftwnd_format_filesize(ftsdata.size), ftsdata.id, ftsdata.savedir)
end

function ftwnd_selection_cb(tree, id, status)
	local ftsdata = iup.TreeGetTable(tree, id)
	if ftsdata == nil or status == 0 then 
		ft_window.status.title = TIPS_ON_NOSEL
		return 
	end
	ft_window.status.title = ftwnd_format_fileinfo(ftsdata)
end

-- check whether should add a new group of file-transfer,
-- group by user
function ftwnd_checkadd(ftsdata, user)
    local id = branch_find(ft_window.tree, user.nickname, "BRANCH")
    if id ~= 0 then return end -- already exist
    branch_add(ft_window.tree, user.nickname)
end

-- push some file-transfer request, handle some UI stuff
function ftwnd_onpushreq(ftsdata)
    local user = user_get(ftsdata.ip)
    if user == nil then
        logw(string.format("invalid file-transfer from %s", ftsdata.ip))
        return
    end
    ftwnd_checkadd(ftsdata, user)
    -- and now we add a file-transfer as the tree leaf
    local leafs = ftwnd_formatleaf(ftsdata)
    branch_addleaf(ft_window.tree, user.nickname, leafs, ftsdata)
    ft_window.tree.redraw = "YES"
end

-- some file-transfer status changed, update UI
function ftwnd_onrequpdate(identify, flag, percent)
    local fts = luafeiq.ftstatus
    local ftsdata = fts_find(fts, identify)
    local oldname = ftwnd_formatleaf(ftsdata)
    local user = user_get(ftsdata.ip)
    if user == nil then
        logw(string.format("user %s does not exist", ftsdata.ip))
        return
    end
    fts_update(ftsdata, percent, flag)
    local leafid = branch_findleaf(ft_window.tree, user.nickname, oldname)
    -- we always assume these find operations are correct
    local namei = "name"..leafid
    ft_window.tree[namei] = ftwnd_formatleaf(ftsdata)
    ft_window.tree.redraw = "YES"
end

