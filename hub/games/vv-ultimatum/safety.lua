--[[ Isolates hub errors so they never reach ScriptContext (ProcessDamage type 2). ]]

local M = {}

local PREFIX = "[VVUltimatum]"

function M.safeCall(label: string, fn: () -> ())
	local ok, err = xpcall(fn, debug.traceback)
	if not ok then
		warn(PREFIX, label, err)
	end
end

function M.guard(fn: () -> ()): () -> ()
	return function()
		M.safeCall("tick", fn)
	end
end

return M
