-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local AtomicBinding = require(script:WaitForChild("AtomicBinding"))
local function loadFlag(p1) --[[ loadFlag | Line: 12 ]]
	local v1, v2 = pcall(function() --[[ Line: 13 | Upvalues: p1 (copy) ]]
		return UserSettings():IsUserFeatureEnabled(p1)
	end)
	return v1 and v2
end
local v1 = "UserSoundsUseRelativeVelocity2"
local v2, v3 = pcall(function() --[[ Line: 13 | Upvalues: v1 (copy) ]]
	return UserSettings():IsUserFeatureEnabled(v1)
end)
local v4 = v2 and v3
local v5 = "UserNewCharacterSoundsApi3"
local v6, v7 = pcall(function() --[[ Line: 13 | Upvalues: v5 (copy) ]]
	return UserSettings():IsUserFeatureEnabled(v5)
end)
local v8 = v6 and v7
local v9 = "UserFixCharSoundsEmitters"
local v10, v11 = pcall(function() --[[ Line: 13 | Upvalues: v9 (copy) ]]
	return UserSettings():IsUserFeatureEnabled(v9)
end)
local v12 = v10 and v11
local v13 = "UserFixCharSoundsEmitterRootPart"
local v14, v15 = pcall(function() --[[ Line: 13 | Upvalues: v13 (copy) ]]
	return UserSettings():IsUserFeatureEnabled(v13)
end)
local v16 = v14 and v15
local t = {
	Climbing = {
		SoundId = "rbxasset://sounds/action_footsteps_plastic.mp3",
		Looped = true
	},
	Died = {
		SoundId = "rbxasset://sounds/uuhhh.mp3"
	},
	FreeFalling = {
		SoundId = "rbxasset://sounds/action_falling.ogg",
		Looped = true
	},
	GettingUp = {
		SoundId = "rbxasset://sounds/action_get_up.mp3"
	},
	Jumping = {
		SoundId = "rbxasset://sounds/action_jump.mp3"
	},
	Landing = {
		SoundId = "rbxasset://sounds/action_jump_land.mp3"
	},
	Running = {
		SoundId = "rbxasset://sounds/action_footsteps_plastic.mp3",
		Looped = true,
		Pitch = 1.85
	},
	Splash = {
		SoundId = "rbxasset://sounds/impact_water.mp3"
	},
	Swimming = {
		SoundId = "rbxasset://sounds/action_swim.mp3",
		Looped = true,
		Pitch = 1.6
	}
}
local t2 = {
	Climbing = {
		AssetId = "rbxasset://sounds/action_footsteps_plastic.mp3",
		Looping = true
	},
	Died = {
		AssetId = "rbxasset://sounds/uuhhh.mp3"
	},
	FreeFalling = {
		AssetId = "rbxasset://sounds/action_falling.ogg",
		Looping = true
	},
	GettingUp = {
		AssetId = "rbxasset://sounds/action_get_up.mp3"
	},
	Jumping = {
		AssetId = "rbxasset://sounds/action_jump.mp3"
	},
	Landing = {
		AssetId = "rbxasset://sounds/action_jump_land.mp3"
	},
	Running = {
		AssetId = "rbxasset://sounds/action_footsteps_plastic.mp3",
		Looping = true,
		PlaybackSpeed = 1.85
	},
	Splash = {
		AssetId = "rbxasset://sounds/impact_water.mp3"
	},
	Swimming = {
		AssetId = "rbxasset://sounds/action_swim.mp3",
		Looping = true,
		PlaybackSpeed = 1.6
	}
}
local function map(p1, p2, p3, p4, p5) --[[ map | Line: 97 ]]
	return (p1 - p2) * (p5 - p4) / (p3 - p2) + p4
end
local function getRelativeVelocity(p1, p2) --[[ getRelativeVelocity | Line: 101 ]]
	if not p1 then
		return p2
	end
	local v1 = p1.ActiveController and (p1.ActiveController:IsA("GroundController") and p1.GroundSensor or p1.ActiveController:IsA("ClimbController") and p1.ClimbSensor)
	if v1 and v1.SensedPart then
		return p2 - v1.SensedPart:GetVelocityAtPosition(p1.RootPart.Position)
	end
	return p2
end
local function playSound(p1, p2) --[[ playSound | Line: 118 | Upvalues: v8 (copy) ]]
	if not p2 then
		p1.TimePosition = 0
	end
	if v8 and p1:IsA("AudioPlayer") then
		p1:Play()
		return
	end
	p1.Playing = true
end
local function stopSound(p1) --[[ stopSound | Line: 129 | Upvalues: v8 (copy) ]]
	if v8 and p1:IsA("AudioPlayer") then
		p1:Stop()
		return
	end
	p1.Playing = false
end
local function playSoundIf(p1, p2) --[[ playSoundIf | Line: 137 | Upvalues: v8 (copy) ]]
	if v8 and p1:IsA("AudioPlayer") then
		if p1.IsPlaying and not p2 then
			p1:Stop()
			return
		end
		if not p1.IsPlaying and p2 then
			p1:Play()
		end
	else
		p1.Playing = p2
	end
end
local function setSoundLooped(p1, p2) --[[ setSoundLooped | Line: 149 | Upvalues: v8 (copy) ]]
	if v8 and p1:IsA("AudioPlayer") then
		p1.Looping = p2
		return
	end
	p1.Looped = p2
end
local function shallowCopy(p1) --[[ shallowCopy | Line: 157 ]]
	local t = {}
	for k, v in pairs(p1) do
		t[k] = v
	end
	return t
end
local function initializeSoundSystem(p1) --[[ initializeSoundSystem | Line: 165 | Upvalues: v4 (copy), v8 (copy), SoundService (copy), v12 (copy), v16 (copy), Players (copy), t2 (copy), t (copy), getRelativeVelocity (copy), RunService (copy) ]]
	local humanoid = p1.humanoid
	local rootPart = p1.rootPart
	local RbxCharacterSoundsEmitter = nil
	local v1 = if v4 then humanoid.Parent:FindFirstChild("ControllerManager") else nil
	local t3 = {}
	if v8 and SoundService.CharacterSoundsUseNewApi == Enum.RolloutState.Enabled then
		local v2 = nil
		local v3 = nil
		if v12 then
			v3 = if v16 then humanoid.RootPart or humanoid.Parent else humanoid.RootPart
		else
			v2 = Players.LocalPlayer.Character
		end
		local v5 = 5
		local t4 = {}
		while v5 < 150 do
			t4[v5] = 5 / v5
			v5 = v5 * 1.25
		end
		t4[150] = 0
		RbxCharacterSoundsEmitter = if v12 then Instance.new("AudioEmitter", v3) else Instance.new("AudioEmitter", v2)
		RbxCharacterSoundsEmitter.Name = "RbxCharacterSoundsEmitter"
		RbxCharacterSoundsEmitter:SetDistanceAttenuation(t4)
		for k, v in pairs(t2) do
			local AudioPlayer = Instance.new("AudioPlayer")
			local Wire = Instance.new("Wire")
			AudioPlayer.Name = k
			Wire.Name = k .. "Wire"
			AudioPlayer.Archivable = false
			AudioPlayer.Volume = 0.65
			for k2, v6 in pairs(v) do
				AudioPlayer[k2] = v6
			end
			AudioPlayer.Parent = rootPart
			Wire.Parent = AudioPlayer
			Wire.SourceInstance = AudioPlayer
			Wire.TargetInstance = RbxCharacterSoundsEmitter
			t3[k] = AudioPlayer
		end
	else
		for k, v in pairs(t) do
			local Sound = Instance.new("Sound")
			Sound.Name = k
			Sound.Archivable = false
			Sound.RollOffMinDistance = 5
			Sound.RollOffMaxDistance = 150
			Sound.Volume = 0.65
			for k2, v2 in pairs(v) do
				Sound[k2] = v2
			end
			Sound.Parent = rootPart
			t3[k] = Sound
		end
	end
	local t4 = {}
	local function stopPlayingLoopedSounds(p1) --[[ stopPlayingLoopedSounds | Line: 241 | Upvalues: t4 (copy), v8 (ref) ]]
		local v1 = pairs
		local t = {}
		local v3 = p1 or nil
		for k, v in pairs(t4) do
			t[k] = v
		end
		for v4 in v1(t) do
			if v4 ~= v3 then
				if v8 and v4:IsA("AudioPlayer") then
					v4:Stop()
				else
					v4.Playing = false
				end
				t4[v4] = nil
			end
		end
	end
	local t5 = {
		[Enum.HumanoidStateType.FallingDown] = function() --[[ Line: 253 | Upvalues: stopPlayingLoopedSounds (copy) ]]
			stopPlayingLoopedSounds()
		end,
		[Enum.HumanoidStateType.GettingUp] = function() --[[ Line: 257 | Upvalues: stopPlayingLoopedSounds (copy), t3 (copy), v8 (ref) ]]
			stopPlayingLoopedSounds()
			local GettingUp = t3.GettingUp
			GettingUp.TimePosition = 0
			if v8 and GettingUp:IsA("AudioPlayer") then
				GettingUp:Play()
				return
			end
			GettingUp.Playing = true
		end,
		[Enum.HumanoidStateType.Jumping] = function() --[[ Line: 262 | Upvalues: stopPlayingLoopedSounds (copy), t3 (copy), v8 (ref) ]]
			stopPlayingLoopedSounds()
			local Jumping = t3.Jumping
			Jumping.TimePosition = 0
			if v8 and Jumping:IsA("AudioPlayer") then
				Jumping:Play()
				return
			end
			Jumping.Playing = true
		end,
		[Enum.HumanoidStateType.Swimming] = function() --[[ Line: 267 | Upvalues: rootPart (copy), t3 (copy), v8 (ref), stopPlayingLoopedSounds (copy), t4 (copy) ]]
			local v1 = math.abs(rootPart.AssemblyLinearVelocity.Y)
			if v1 > 0.1 then
				t3.Splash.Volume = math.clamp((v1 - 100) * 0.72 / 250 + 0.28, 0, 1)
				local Splash = t3.Splash
				Splash.TimePosition = 0
				if v8 and Splash:IsA("AudioPlayer") then
					Splash:Play()
				else
					Splash.Playing = true
				end
			end
			stopPlayingLoopedSounds(t3.Swimming)
			local Swimming = t3.Swimming
			if v8 and Swimming:IsA("AudioPlayer") then
				Swimming:Play()
			else
				Swimming.Playing = true
			end
			t4[t3.Swimming] = true
		end,
		[Enum.HumanoidStateType.Freefall] = function() --[[ Line: 278 | Upvalues: t3 (copy), stopPlayingLoopedSounds (copy), v8 (ref), t4 (copy) ]]
			t3.FreeFalling.Volume = 0
			stopPlayingLoopedSounds(t3.FreeFalling)
			local FreeFalling = t3.FreeFalling
			if v8 and FreeFalling:IsA("AudioPlayer") then
				FreeFalling.Looping = true
			else
				FreeFalling.Looped = true
			end
			if t3.FreeFalling:IsA("Sound") then
				t3.FreeFalling.PlaybackRegionsEnabled = true
			end
			t3.FreeFalling.LoopRegion = NumberRange.new(2, 9)
			local FreeFalling_2 = t3.FreeFalling
			FreeFalling_2.TimePosition = 0
			if v8 and FreeFalling_2:IsA("AudioPlayer") then
				FreeFalling_2:Play()
			else
				FreeFalling_2.Playing = true
			end
			t4[t3.FreeFalling] = true
		end,
		[Enum.HumanoidStateType.Landed] = function() --[[ Line: 292 | Upvalues: stopPlayingLoopedSounds (copy), rootPart (copy), t3 (copy), v8 (ref) ]]
			stopPlayingLoopedSounds()
			local v1 = math.abs(rootPart.AssemblyLinearVelocity.Y)
			if not (v1 > 75) then
				return
			end
			t3.Landing.Volume = math.clamp((v1 - 50) * 1 / 50 + 0, 0, 1)
			local Landing = t3.Landing
			Landing.TimePosition = 0
			if v8 and Landing:IsA("AudioPlayer") then
				Landing:Play()
				return
			end
			Landing.Playing = true
		end,
		[Enum.HumanoidStateType.Running] = function() --[[ Line: 301 | Upvalues: stopPlayingLoopedSounds (copy), t3 (copy), v8 (ref), t4 (copy) ]]
			stopPlayingLoopedSounds(t3.Running)
			local Running = t3.Running
			if v8 and Running:IsA("AudioPlayer") then
				Running:Play()
			else
				Running.Playing = true
			end
			t4[t3.Running] = true
		end,
		[Enum.HumanoidStateType.Climbing] = function() --[[ Line: 307 | Upvalues: t3 (copy), rootPart (copy), v4 (ref), getRelativeVelocity (ref), v1 (ref), v8 (ref), stopPlayingLoopedSounds (copy), t4 (copy) ]]
			local Climbing = t3.Climbing
			local AssemblyLinearVelocity = rootPart.AssemblyLinearVelocity
			local Y = (if v4 then getRelativeVelocity(v1, AssemblyLinearVelocity) else AssemblyLinearVelocity).Y
			if math.abs(Y) > 0.1 then
				if v8 and Climbing:IsA("AudioPlayer") then
					Climbing:Play()
				else
					Climbing.Playing = true
				end
				stopPlayingLoopedSounds(Climbing)
			else
				stopPlayingLoopedSounds()
			end
			t4[Climbing] = true
		end,
		[Enum.HumanoidStateType.Seated] = function() --[[ Line: 320 | Upvalues: stopPlayingLoopedSounds (copy) ]]
			stopPlayingLoopedSounds()
		end,
		[Enum.HumanoidStateType.Dead] = function() --[[ Line: 324 | Upvalues: stopPlayingLoopedSounds (copy), t3 (copy), v8 (ref) ]]
			stopPlayingLoopedSounds()
			local Died = t3.Died
			Died.TimePosition = 0
			if v8 and Died:IsA("AudioPlayer") then
				Died:Play()
				return
			end
			Died.Playing = true
		end
	}
	local t6 = {
		[t3.Climbing] = function(p1, p2, p3) --[[ Line: 332 | Upvalues: v4 (ref), getRelativeVelocity (ref), v1 (ref), v8 (ref) ]]
			local v2 = if (if v4 then getRelativeVelocity(v1, p3) else p3).Magnitude > 0.1 then true else false
			if v8 and p2:IsA("AudioPlayer") then
				if p2.IsPlaying and not v2 then
					p2:Stop()
					return
				end
				if not p2.IsPlaying and v2 then
					p2:Play()
				end
			else
				p2.Playing = v2
			end
		end,
		[t3.FreeFalling] = function(p1, p2, p3) --[[ Line: 337 ]]
			if p3.Magnitude > 75 then
				p2.Volume = math.clamp(p2.Volume + p1 * 0.9, 0, 1)
			else
				p2.Volume = 0
			end
		end,
		[t3.Running] = function(p1, p2, p3) --[[ Line: 345 | Upvalues: humanoid (copy), v8 (ref) ]]
			local v1 = if p3.Magnitude > 0.5 then humanoid.MoveDirection.Magnitude > 0.5 else false
			if v8 and p2:IsA("AudioPlayer") then
				if p2.IsPlaying and not v1 then
					p2:Stop()
					return
				end
				if not p2.IsPlaying and v1 then
					p2:Play()
				end
			else
				p2.Playing = v1
			end
		end
	}
	local t7 = {
		[Enum.HumanoidStateType.RunningNoPhysics] = Enum.HumanoidStateType.Running
	}
	local v6 = t7[humanoid:GetState()] or humanoid:GetState()
	local function transitionTo(p1) --[[ transitionTo | Line: 357 | Upvalues: t5 (copy), v6 (ref) ]]
		local v1 = t5[p1]
		if v1 then
			v1()
		end
		v6 = p1
	end
	local v7 = v6
	local v82 = t5[v7]
	local v9, v10
	if not v82 then
		v6 = v7
		v9 = humanoid.StateChanged:Connect(function(p1_2, p2_2) --[[ Line: 369 | Upvalues: t7 (copy), v6 (ref), t5 (copy) ]]
			local v1 = t7[p2_2] or p2_2
			if v1 == v6 then
				return
			end
			local v2 = t5[v1]
			if v2 then
				v2()
			end
			v6 = v1
		end)
		v10 = RunService.Stepped:Connect(function(p1_2, p2_2) --[[ Line: 377 | Upvalues: t4 (copy), t6 (copy), rootPart (copy) ]]
			for k2 in pairs(t4) do
				local v1 = t6[k2]
				if v1 then
					v1(p2_2, k2, rootPart.AssemblyLinearVelocity)
				end
			end
		end)
		return function() --[[ terminate | Line: 388 | Upvalues: v9 (copy), v10 (copy), v16 (ref), RbxCharacterSoundsEmitter (ref), t3 (copy) ]]
			v9:Disconnect()
			v10:Disconnect()
			if v16 and RbxCharacterSoundsEmitter then
				RbxCharacterSoundsEmitter:Destroy()
			end
			for k2, v in pairs(t3) do
				v:Destroy()
			end
			table.clear(t3)
		end
	end
	v82()
	v6 = v7
	v9 = humanoid.StateChanged:Connect(function(p1_2, p2_2) --[[ Line: 369 | Upvalues: t7 (copy), v6 (ref), t5 (copy) ]]
		local v1 = t7[p2_2] or p2_2
		if v1 == v6 then
			return
		end
		local v2 = t5[v1]
		if v2 then
			v2()
		end
		v6 = v1
	end)
	v10 = RunService.Stepped:Connect(function(p1_2, p2_2) --[[ Line: 377 | Upvalues: t4 (copy), t6 (copy), rootPart (copy) ]]
		for k2 in pairs(t4) do
			local v1 = t6[k2]
			if v1 then
				v1(p2_2, k2, rootPart.AssemblyLinearVelocity)
			end
		end
	end)
	return function() --[[ terminate | Line: 388 | Upvalues: v9 (copy), v10 (copy), v16 (ref), RbxCharacterSoundsEmitter (ref), t3 (copy) ]]
		v9:Disconnect()
		v10:Disconnect()
		if v16 and RbxCharacterSoundsEmitter then
			RbxCharacterSoundsEmitter:Destroy()
		end
		for k2, v in pairs(t3) do
			v:Destroy()
		end
		table.clear(t3)
	end
end
local v17 = AtomicBinding.new({
	humanoid = "Humanoid",
	rootPart = "HumanoidRootPart"
}, initializeSoundSystem)
local t3 = {}
local function characterAdded(p1) --[[ characterAdded | Line: 415 | Upvalues: v17 (copy) ]]
	v17:bindRoot(p1)
end
local function characterRemoving(p1) --[[ characterRemoving | Line: 419 | Upvalues: v17 (copy) ]]
	v17:unbindRoot(p1)
end
local function playerAdded(p1) --[[ playerAdded | Line: 423 | Upvalues: t3 (copy), v17 (copy), characterAdded (copy), characterRemoving (copy) ]]
	local v1 = t3[p1]
	if not v1 then
		v1 = {}
		t3[p1] = v1
	end
	if p1.Character then
		v17:bindRoot(p1.Character)
	end
	table.insert(v1, p1.CharacterAdded:Connect(characterAdded))
	table.insert(v1, p1.CharacterRemoving:Connect(characterRemoving))
end
local function playerRemoving(p1) --[[ playerRemoving | Line: 437 | Upvalues: t3 (copy), v17 (copy) ]]
	local v1 = t3[p1]
	if v1 then
		for i, v in ipairs(v1) do
			v:Disconnect()
		end
		t3[p1] = nil
	end
	if not p1.Character then
		return
	end
	v17:unbindRoot(p1.Character)
end
for i, v in ipairs(Players:GetPlayers()) do
	task.spawn(playerAdded, v)
end
Players.PlayerAdded:Connect(playerAdded)
Players.PlayerRemoving:Connect(playerRemoving)