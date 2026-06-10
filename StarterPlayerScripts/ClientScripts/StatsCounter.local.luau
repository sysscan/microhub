-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Icon = require(ReplicatedStorage.Icon)
local PingCheck = ReplicatedStorage:WaitForChild("PingCheck", 10)
if PingCheck then
	local v1 = Icon.new():setName("StatsCounter"):setLabel("FPS: -- | MS: --"):setWidth(160):align("Right"):lock():disableStateOverlay(true)
	local v2 = 0
	local v3 = 0
	local v4 = 0
	local v5 = 0
	local v6 = 0
	local v7 = false
	local function getColor() --[[ getColor | Line: 31 | Upvalues: v2 (ref), v3 (ref) ]]
		if v2 < 30 or v3 > 200 then
			return Color3.fromRGB(255, 80, 80)
		end
		if v2 < 50 or v3 > 100 then
			return Color3.fromRGB(255, 200, 50)
		else
			return Color3.fromRGB(100, 220, 100)
		end
	end
	local function updateIcon() --[[ updateIcon | Line: 41 | Upvalues: v1 (copy), v2 (ref), v3 (ref), getColor (copy) ]]
		v1:setLabel(string.format("FPS: %d | MS: %d", v2, v3)):setTextColor(getColor())
	end
	local function measurePing() --[[ measurePing | Line: 47 | Upvalues: v7 (ref), PingCheck (copy), v3 (ref) ]]
		if not v7 then
			v7 = true
			task.spawn(function() --[[ Line: 50 | Upvalues: PingCheck (ref), v3 (ref), v7 (ref) ]]
				local v1 = os.clock()
				if not pcall(function() --[[ Line: 52 | Upvalues: PingCheck (ref) ]]
					PingCheck:InvokeServer()
				end) then
					v7 = false
					return
				end
				v3 = math.round((os.clock() - v1) * 1000)
				v7 = false
			end)
		end
	end
	RunService.RenderStepped:Connect(function(p1) --[[ Line: 62 | Upvalues: v4 (ref), v5 (ref), v2 (ref), v1 (copy), v3 (ref), getColor (copy), v6 (ref), v7 (ref), PingCheck (copy) ]]
		v4 = v4 + 1
		v5 = v5 + p1
		if v5 >= 0.5 then
			v2 = math.round(v4 / v5)
			v4 = 0
			v5 = 0
			v1:setLabel(string.format("FPS: %d | MS: %d", v2, v3)):setTextColor(getColor())
		end
		v6 = v6 + p1
		if not (v6 >= 2) then
			return
		end
		v6 = 0
		if v7 then
			return
		end
		v7 = true
		task.spawn(function() --[[ Line: 50 | Upvalues: PingCheck (ref), v3 (ref), v7 (ref) ]]
			local v1 = os.clock()
			if not pcall(function() --[[ Line: 52 | Upvalues: PingCheck (ref) ]]
				PingCheck:InvokeServer()
			end) then
				v7 = false
				return
			end
			v3 = math.round((os.clock() - v1) * 1000)
			v7 = false
		end)
	end)
	Players.LocalPlayer.AncestryChanged:Connect(function() --[[ Line: 80 | Upvalues: v1 (copy) ]]
		v1:destroy()
	end)
else
	warn("[StatsBar] PingCheck RemoteFunction not found.")
end