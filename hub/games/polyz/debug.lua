local M = {}

local WATCHED = {
	ShootEnemy = { "host", "hitPart", "hitPosition", "pierceCount", "gunName" },
	RaycastRedirect = { "origin", "direction", "hitPart" },
}

function M.create(opts)
	local Config = opts.config

	if not Config then
		error("[POLYZ] debug.create missing config", 0)
	end

	local TAG = "[POLYZ Remote]"
	local MAX_LOGS = 120
	local RAYCAST_LOG_INTERVAL = 0.25
	local logs: { [number]: string } = {}
	local logCount = 0
	local lastRaycastLogAt = 0

	local function kindOf(value)
		return typeof(value)
	end

	local function serialize(value, depth: number?): string
		depth = depth or 0
		if depth > 2 then
			return "<deep>"
		end

		local kind = kindOf(value)
		if kind == "nil" or kind == "boolean" or kind == "number" then
			return tostring(value)
		end
		if kind == "string" then
			if #value > 48 then
				return string.format("%q..", string.sub(value, 1, 48))
			end
			return string.format("%q", value)
		end
		if kind == "Vector3" then
			return string.format("(%.1f, %.1f, %.1f)", value.X, value.Y, value.Z)
		end
		if kind == "Instance" then
			local ok, fullName = pcall(function()
				return value:GetFullName()
			end)
			if ok then
				return fullName
			end
			return tostring(value)
		end
		if kind == "table" then
			local parts = {}
			local count = 0
			for key, entry in value do
				count += 1
				if count > 6 then
					table.insert(parts, "...")
					break
				end
				table.insert(parts, string.format("[%s]=%s", tostring(key), serialize(entry, depth + 1)))
			end
			return "{" .. table.concat(parts, ", ") .. "}"
		end
		return kind
	end

	local function serializeArgs(args: { any })
		local parts = {}
		for index, value in args do
			parts[index] = serialize(value)
		end
		return table.concat(parts, ", ")
	end

	local function pushLog(line: string)
		logCount += 1
		logs[logCount] = line
		if logCount > MAX_LOGS then
			table.remove(logs, 1)
			logCount -= 1
		end
	end

	local function emit(level: string, line: string)
		pushLog(line)
		if level == "ERR" then
			warn(TAG, line)
			return
		end
		if Config.DebugRemotes then
			print(TAG, line)
		end
	end

	local function logShootEnemy(stage: string, rawArgs: { any }, finalArgs: { any }?, err: string?)
		local finalText = if finalArgs then serializeArgs(finalArgs) else "nil"
		local line = string.format(
			"ShootEnemy %s | raw=(%s) | final=(%s)%s",
			stage,
			serializeArgs(rawArgs),
			finalText,
			if err then " | err=" .. err else ""
		)
		emit(if err then "ERR" else "OUT", line)
	end

	local function logRaycastRedirect(origin: Vector3, direction: Vector3, hitPart: BasePart?, ok: boolean, note: string?)
		if not Config.DebugRemotes then
			return
		end
		local now = os.clock()
		if now - lastRaycastLogAt < RAYCAST_LOG_INTERVAL then
			return
		end
		lastRaycastLogAt = now
		local line = string.format(
			"RaycastRedirect %s | origin=%s | dir=(%.2f, %.2f, %.2f) | hit=%s%s",
			if ok then "HIT" else "MISS",
			serialize(origin),
			direction.X,
			direction.Y,
			direction.Z,
			if hitPart then serialize(hitPart) else "nil",
			if note then " | " .. note else ""
		)
		emit("OUT", line)
	end

	local function logInvokeError(remoteName: string, args: { any }, err: string)
		emit("ERR", string.format("%s invoke failed | args=(%s) | err=%s", remoteName, serializeArgs(args), err))
	end

	return {
		watched = WATCHED,
		logShootEnemy = logShootEnemy,
		logRaycastRedirect = logRaycastRedirect,
		logInvokeError = logInvokeError,
		getRecentLogs = function()
			return logs
		end,
	}
end

return M
