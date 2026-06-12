--[[ Teleport / AC signal instrumentation — logs events for diagnosis, not bypass. ]]

local M = {}

local MAX_ENTRIES = 250

function M.create(opts)
	local Config = opts.config
	local entries: { { t: number, tag: string, detail: any } } = {}
	local globalConnections: { RBXScriptConnection } = {}
	local charConnections: { RBXScriptConnection } = {}
	local remotesRef = nil
	local savedRemotes: { packet: any, fire: any, invoke: any }? = nil
	local hooked = false

	local function formatDetail(detail: any): string
		if detail == nil then
			return ""
		end
		if type(detail) ~= "table" then
			return tostring(detail)
		end
		local keys = {}
		for k in detail do
			table.insert(keys, k)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		local parts = {}
		for _, k in keys do
			table.insert(parts, tostring(k) .. "=" .. tostring(detail[k]))
		end
		return table.concat(parts, ", ")
	end

	local function log(tag: string, detail: any?)
		local row = {
			t = os.clock(),
			tag = tag,
			detail = detail,
		}
		table.insert(entries, row)
		while #entries > MAX_ENTRIES do
			table.remove(entries, 1)
		end
		if Config.DebugLivePrint then
			warn("[VV-DBG]", tag, formatDetail(detail))
		end
	end

	local function formatEntry(row)
		return string.format("[%.2f] %s | %s", row.t, row.tag, formatDetail(row.detail))
	end

	local function dump()
		print("[VV Ultimatum] debug log (" .. tostring(#entries) .. " entries)")
		for _, row in entries do
			print(formatEntry(row))
		end
	end

	local function clear()
		table.clear(entries)
	end

	local function clearCharConnections()
		for _, conn in charConnections do
			pcall(function()
				conn:Disconnect()
			end)
		end
		table.clear(charConnections)
	end

	local function watchCharacter(char: Model)
		clearCharConnections()

		local function watchPart(part: BasePart)
			table.insert(charConnections, part.ChildAdded:Connect(function(child)
				if not Config.DebugMonitorAC then
					return
				end
				local suspicious = child:IsA("BodyAngularVelocity")
					or child:IsA("BodyVelocity")
					or child:IsA("VectorForce")
					or child:IsA("BodyThrust")
					or child:IsA("RocketPropulsion")
					or child:IsA("Torque")
					or child:IsA("HingeConstraint")
					or child:IsA("CylindricalConstraint")
					or child:IsA("PrismaticConstraint")
				if suspicious then
					log("physics_child", {
						part = part.Name,
						class = child.ClassName,
						name = child.Name,
					})
				end
			end))
		end

		for _, name in { "HumanoidRootPart", "Torso", "UpperTorso", "Head" } do
			local part = char:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				watchPart(part)
			end
		end
	end

	local function hookRemotes(remotes)
		if hooked then
			return
		end
		hooked = true
		remotesRef = remotes
		savedRemotes = {
			packet = remotes.packet,
			fire = remotes.fire,
			invoke = remotes.invoke,
		}

		remotes.packet = function(name, ...)
			if name == "ProcessDamage" then
				log("ProcessDamage", { code = ... })
			elseif name == "TeleportToPlayer" then
				log("packet_TeleportToPlayer", { target = ... })
			end
			return savedRemotes.packet(name, ...)
		end

		remotes.fire = function(name, ...)
			if name == "TakeDamage" then
				log("TakeDamage", { amount = ... })
			elseif name == "ToggleFlight" then
				log("ToggleFlight", { active = ... })
			elseif name == "FX_Server" then
				local payload = ...
				if type(payload) == "table" and payload.Type == "FallFX" then
					log("FallFX", {
						distance = payload.FallDistance,
						y = payload.Position and payload.Position.Y,
					})
				end
			end
			return savedRemotes.fire(name, ...)
		end

		remotes.invoke = function(name, ...)
			local t0 = os.clock()
			local ok, result = savedRemotes.invoke(name, ...)
			if name == "FinishLoading" or name == "TeleportToServer" or name == "GetServerList" then
				log("invoke_" .. name, {
					ok = ok,
					result = if ok then tostring(result) else "err",
					ms = math.floor((os.clock() - t0) * 1000),
				})
			end
			return ok, result
		end
	end

	local function unhookRemotes()
		if not hooked or not remotesRef or not savedRemotes then
			return
		end
		remotesRef.packet = savedRemotes.packet
		remotesRef.fire = savedRemotes.fire
		remotesRef.invoke = savedRemotes.invoke
		remotesRef = nil
		savedRemotes = nil
		hooked = false
	end

	local function start(localPlayer: Player)
		table.insert(globalConnections, game:GetService("ScriptContext").Error:Connect(function(msg, _stack, errScript)
			if not Config.DebugMonitorAC then
				return
			end
			log("ScriptContext.Error", {
				msg = tostring(msg):sub(1, 120),
				errScript = errScript and errScript:GetFullName() or "nil",
			})
		end))

		table.insert(globalConnections, localPlayer.OnTeleport:Connect(function(state)
			log("OnTeleport", { state = tostring(state) })
		end))

		table.insert(globalConnections, localPlayer.CharacterRemoving:Connect(function(char)
			local root = char:FindFirstChild("HumanoidRootPart")
			log("CharacterRemoving", {
				reason = "kick_or_reset",
				y = root and math.floor(root.Position.Y) or "nil",
			})
		end))

		if localPlayer.Character then
			watchCharacter(localPlayer.Character)
		end
		table.insert(globalConnections, localPlayer.CharacterAdded:Connect(watchCharacter))
	end

	local function destroy()
		clearCharConnections()
		for _, conn in globalConnections do
			pcall(function()
				conn:Disconnect()
			end)
		end
		table.clear(globalConnections)
		unhookRemotes()
		table.clear(entries)
	end

	return {
		log = log,
		dump = dump,
		clear = clear,
		getEntries = function()
			return entries
		end,
		hookRemotes = hookRemotes,
		start = start,
		destroy = destroy,
	}
end

return M
