-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Packets = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("Modules"):WaitForChild("Packets"))
local CapturingProgress = LocalPlayer.PlayerGui:WaitForChild("Main"):WaitForChild("CanvasInGame"):WaitForChild("CapturingProgress")
local v1 = workspace:WaitForChild("Game"):WaitForChild("Capture Points")
local v2 = false
local v3 = nil
local v4 = nil
local v5 = nil
local t = {}
local v6 = 0
local function createFlash(p1) --[[ createFlash | Line: 22 | Upvalues: TweenService (copy) ]]
	local CompletionFlash = p1:FindFirstChild("CompletionFlash")
	if CompletionFlash then
		CompletionFlash:Destroy()
	end
	local CompletionFlash_2 = Instance.new("Frame")
	CompletionFlash_2.Name = "CompletionFlash"
	CompletionFlash_2.Size = UDim2.new(1, 0, 1, 0)
	CompletionFlash_2.BackgroundColor3 = Color3.new(255/255, 255/255, 255/255)
	CompletionFlash_2.BackgroundTransparency = 0.2
	CompletionFlash_2.BorderSizePixel = 0
	CompletionFlash_2.ZIndex = p1.ZIndex + 1
	for i, v in ipairs(p1:GetChildren()) do
		if v:IsA("UICorner") then
			v:Clone().Parent = CompletionFlash_2
		end
	end
	CompletionFlash_2.Parent = p1
	local v1 = TweenService:Create(CompletionFlash_2, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1
	})
	v1.Completed:Connect(function() --[[ Line: 45 | Upvalues: CompletionFlash_2 (copy) ]]
		CompletionFlash_2:Destroy()
	end)
	v1:Play()
end
local function updateWorldGradient(p1, p2, p3, p4, p5) --[[ updateWorldGradient | Line: 51 | Upvalues: v1 (copy), TweenService (copy), t (copy), createFlash (copy) ]]
	local v12 = v1:FindFirstChild(p1)
	if not v12 then
		return
	end
	local Point = v12:FindFirstChild("Point")
	local v2 = if Point then Point:FindFirstChild("BillboardGui") else Point
	local v3 = if v2 then v2:FindFirstChild("ImageLabel") else v2
	local v4 = v3 and v3:FindFirstChild("UIGradient")
	if not v4 then
		return
	end
	v3.ImageColor3 = p3
	local AnimValue = v4:FindFirstChild("AnimValue") or Instance.new("NumberValue")
	AnimValue.Name = "AnimValue"
	AnimValue.Parent = v4
	local v6 = AnimValue.Changed:Connect(function(p1) --[[ Line: 74 | Upvalues: v4 (copy) ]]
		if p1 >= 0.999 then
			v4.Transparency = NumberSequence.new(0)
			return
		end
		if p1 <= 0.001 then
			v4.Transparency = NumberSequence.new(1)
		else
			local v1 = math.clamp(p1, 0.001, 0.998)
			v4.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(v1, 0),
				NumberSequenceKeypoint.new(v1 + 0.001, 1),
				NumberSequenceKeypoint.new(1, 1)
			})
		end
	end)
	local v7 = TweenService:Create(AnimValue, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Value = if p5 == "SyncColor" then 1 else p2
	})
	v7.Completed:Connect(function() --[[ Line: 91 | Upvalues: v6 (ref) ]]
		v6:Disconnect()
	end)
	v7:Play()
	if p4 then
		local v8 = tick()
		if not t[p1] or v8 - t[p1] > 1 then
			t[p1] = v8
			local v9 = v3:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			v9.Parent = v3
			v9.Scale = 1
			TweenService:Create(v9, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true), {
				Scale = 1.3
			}):Play()
			v4.Transparency = NumberSequence.new(0)
			createFlash(v3)
		end
	end
end
local function updateLocalHUD(p1, p2, p3) --[[ updateLocalHUD | Line: 110 | Upvalues: v4 (ref), CapturingProgress (copy), TweenService (copy), v6 (ref), createFlash (copy) ]]
	if v4 then
		v4:Cancel()
	end
	CapturingProgress.BackgroundColor3 = p2
	v4 = TweenService:Create(CapturingProgress, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(p1, 0, 0.15, 0)
	})
	v4:Play()
	if not p3 then
		return
	end
	local v1 = tick()
	if not (v1 - v6 > 1) then
		return
	end
	v6 = v1
	local v2 = CapturingProgress:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	v2.Parent = CapturingProgress
	v2.Scale = 1
	TweenService:Create(v2, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true), {
		Scale = 1.15
	}):Play()
	createFlash(CapturingProgress)
end
local function setProgressBarVisible(p1) --[[ setProgressBarVisible | Line: 132 | Upvalues: v3 (ref), CapturingProgress (copy) ]]
	if not v3 then
		CapturingProgress.Visible = p1
		return
	end
	task.cancel(v3)
	v3 = nil
	CapturingProgress.Visible = p1
end
local function onCapturingEvent(p1, p2, p3, p4) --[[ onCapturingEvent | Line: 140 | Upvalues: updateWorldGradient (copy), v5 (ref), v3 (ref), CapturingProgress (copy), v1 (copy), LocalPlayer (copy), updateLocalHUD (copy) ]]
	local v12 = if p2 >= 1 or p2 <= 0 then if p4 == "SyncColor" then false elseif p4 == "Sync" then false else true else false
	if p4 == "SyncColor" or p4 == "Sync" then
		updateWorldGradient(p1, p2, p3, false, p4)
	elseif p1 == "Hide" then
		v5 = nil
		if v3 then
			task.cancel(v3)
			v3 = nil
		end
		CapturingProgress.Visible = false
	elseif p1 == "Show" then
		if type(p2) == "string" and v1:FindFirstChild(p2) then
			v5 = p2
			if v3 then
				task.cancel(v3)
				v3 = nil
			end
		else
			local Character = LocalPlayer.Character
			local v2 = if Character then Character:FindFirstChild("HumanoidRootPart") else Character
			if not v2 then
				return
			end
			local v32 = 45
			for i, v in ipairs(v1:GetChildren()) do
				local Point = v:FindFirstChild("Point")
				if Point then
					local Magnitude = (Point.Position - v2.Position).Magnitude
					if Magnitude <= v32 then
						v5 = v.Name
						v32 = Magnitude
					end
				end
			end
			if not v5 then
				return
			end
			if v3 then
				task.cancel(v3)
				v3 = nil
			end
		end
		CapturingProgress.Visible = true
	else
		updateWorldGradient(p1, p2, p3, v12, p4)
		if v5 ~= p1 then
			return
		end
		if v3 then
			task.cancel(v3)
			v3 = nil
		end
		CapturingProgress.Visible = true
		updateLocalHUD(p2, p3, v12)
		if not v12 then
			return
		end
		v3 = task.delay(1.5, function() --[[ Line: 188 | Upvalues: v3 (ref), CapturingProgress (ref), v5 (ref) ]]
			if v3 then
				task.cancel(v3)
				v3 = nil
			end
			CapturingProgress.Visible = false
			v5 = nil
		end)
	end
end
return function() --[[ Line: 196 | Upvalues: v2 (ref), Packets (copy), onCapturingEvent (copy), v3 (ref), CapturingProgress (copy), LocalPlayer (copy) ]]
	if not v2 then
		v2 = true
		Packets.CapturingPoint.OnClientEvent:Connect(onCapturingEvent)
		workspace:GetAttributeChangedSignal("InMenu"):Connect(function() --[[ Line: 202 | Upvalues: v3 (ref), CapturingProgress (ref) ]]
			if not workspace:GetAttribute("InMenu") then
				return
			end
			if v3 then
				task.cancel(v3)
				v3 = nil
			end
			CapturingProgress.Visible = false
		end)
		LocalPlayer.CharacterAdded:Connect(function() --[[ Line: 208 | Upvalues: v3 (ref), CapturingProgress (ref) ]]
			if v3 then
				task.cancel(v3)
				v3 = nil
			end
			CapturingProgress.Visible = false
		end)
	end
end