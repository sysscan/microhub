local M = {}

function M.create(loops: { thread })
	local function stop(threadRef: thread?)
		if threadRef then
			pcall(task.cancel, threadRef)
		end
	end

	local function start(fn: () -> ())
		local threadRef = task.spawn(function()
			while true do
				fn()
				task.wait(0.05)
			end
		end)
		table.insert(loops, threadRef)
		return threadRef
	end

	return { stop = stop, start = start }
end

return M
