--[[
  Provide some logger functions
  Kevin Lynx
  1.26.2011
--]]
require("logging")
require("logging.file")

logger = nil
consoleLvl = logging.DEBUG

LOGPATH = '../log/'

-- file i.e: ../log/luafeiq_%s.log
function log_init(file, _consolelvl)
    -- create the directory if necessary
    fileop_mkdir(LOGPATH)
    file = LOGPATH .. file
	logger = logging.file(file, "%Y-%m-%d")
	logi("=========================start log=========================")
	if _consolelvl ~= nil then
		consoleLvl = _consolelvl
	end
end

function check_print(s, l)
	if consoleLvl <= l then
		print(s)
	end
end

function logd(s)
	logger:debug(s)
	check_print(s, logging.DEBUG)
end

function logi(s)
	logger:info(s)
	check_print(s, logging.INFO)
end

function logw(s)
	logger:warn(s)
	check_print(s, logging.WARN)
end

function loge(s)
	logger:error(s)
	check_print(s, logging.ERROR)
end

