local M = {}

function M.create(loops)
	return {
		start = function(fn)
			local thread = task.spawn(fn)
			table.insert(loops, thread)
			return thread
		end,
	}
end

return M
