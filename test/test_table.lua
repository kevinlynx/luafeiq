
gt = {}

function get_table()
	gt.size = 0
	return gt
end

function get_table2()
	local s = {}
	s.size = 0
	gt[1] = s
	return gt[1]
end

local s = get_table2()
s.size = 1
--print(gt.size, s.size)
--print(gt, s)
print(gt[1], s)


