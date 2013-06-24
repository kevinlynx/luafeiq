--[[
  represents a file host
  Kevin Lynx
  2.7.2011
--]]
function host_create(ip, port)
	local host = {}
	host.ip = ip
	host.port = port
	return host
end

function host_equal(h1, h2)
	return h1.ip == h2.ip and h1.port == h2.port
end

