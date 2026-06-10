-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local t = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Animation_CFG = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"):WaitForChild("Config")).Animation_CFG
local LocalPlayer = Players.LocalPlayer
local v1 = nil
local v2 = nil
local v3 = nil
local v4 = nil
local v5 = nil
local t2 = {}
local t3 = {}
local t4 = {}
local t5 = {}
local v6 = ""
local v7 = nil
local v8 = nil
local v9 = false
local v10 = nil
local v11 = 0
local v12 = 0
local v13 = 0
local v14 = nil
local defaultHipHeight = Animation_CFG.scale.defaultHipHeight
local v15 = nil
local v16 = false
local v17 = false
local v18 = false
local t6 = {
	idle = Enum.AnimationPriority.Movement,
	walk = Enum.AnimationPriority.Movement,
	jog = Enum.AnimationPriority.Movement,
	run = Enum.AnimationPriority.Movement,
	walk_forward = Enum.AnimationPriority.Movement,
	walk_backward = Enum.AnimationPriority.Movement,
	walk_left = Enum.AnimationPriority.Movement,
	walk_right = Enum.AnimationPriority.Movement,
	jog_forward = Enum.AnimationPriority.Movement,
	jog_backward = Enum.AnimationPriority.Movement,
	jog_left = Enum.AnimationPriority.Movement,
	jog_right = Enum.AnimationPriority.Movement,
	run_forward = Enum.AnimationPriority.Movement,
	run_backward = Enum.AnimationPriority.Movement,
	run_left = Enum.AnimationPriority.Movement,
	run_right = Enum.AnimationPriority.Movement,
	fall = Enum.AnimationPriority.Movement,
	climb = Enum.AnimationPriority.Action,
	climbidle = Enum.AnimationPriority.Action,
	swim = Enum.AnimationPriority.Movement,
	swimidle = Enum.AnimationPriority.Movement,
	jump = Enum.AnimationPriority.Action,
	land_soft = Enum.AnimationPriority.Action,
	land_hard = Enum.AnimationPriority.Action,
	sit = Enum.AnimationPriority.Action,
	crouch_start = Enum.AnimationPriority.Action,
	crouch_idle = Enum.AnimationPriority.Movement,
	crouch_walk_forward = Enum.AnimationPriority.Movement,
	crouch_walk_backward = Enum.AnimationPriority.Movement,
	crouch_walk_left = Enum.AnimationPriority.Movement,
	crouch_walk_right = Enum.AnimationPriority.Movement,
	prone_idle = Enum.AnimationPriority.Movement,
	prone_crawl_forward = Enum.AnimationPriority.Movement,
	prone_crawl_backward = Enum.AnimationPriority.Movement,
	prone_turn_left = Enum.AnimationPriority.Movement,
	prone_turn_right = Enum.AnimationPriority.Movement
}
local function isGrounded() --[[ isGrounded | Line: 76 | Upvalues: v2 (ref) ]]
	if not v2 then
		return true
	end
	local v1 = v2:GetState()
	return if v1 == Enum.HumanoidStateType.Freefall then false else v1 ~= Enum.HumanoidStateType.FallingDown
end
local function getRigScale() --[[ getRigScale | Line: 82 | Upvalues: Animation_CFG (copy), v1 (ref) ]]
	if Animation_CFG.flags.animateScaleRun and (v1 and v1.GetScale) then
		return v1:GetScale()
	else
		return 1
	end
end
local function getHeightScale() --[[ getHeightScale | Line: 90 | Upvalues: v2 (ref), getRigScale (copy), defaultHipHeight (ref), v14 (ref), Animation_CFG (copy) ]]
	if not v2 then
		return getRigScale()
	end
	if not v2.AutomaticScalingEnabled then
		return getRigScale()
	end
	local v1 = v2.HipHeight / defaultHipHeight
	if not v14 then
		v14 = script:FindFirstChild(Animation_CFG.scale.scaleDampeningValueName)
	end
	if v14 then
		local v3 = tonumber(v14.Value)
		if v3 then
			v1 = 1 + (v2.HipHeight - defaultHipHeight) * v3 / defaultHipHeight
		end
	end
	return v1
end
local function rootMotionCompensation(p1) --[[ rootMotionCompensation | Line: 115 | Upvalues: Animation_CFG (copy), getHeightScale (copy) ]]
	return p1 * (Animation_CFG.flags.rootMotionScale or 1) / math.max(0.0001, (getHeightScale()))
end
local function horizontalSpeed() --[[ horizontalSpeed | Line: 121 | Upvalues: v2 (ref) ]]
	if v2 and v2.RootPart then
		local AssemblyLinearVelocity = v2.RootPart.AssemblyLinearVelocity
		return math.sqrt(AssemblyLinearVelocity.X * AssemblyLinearVelocity.X + AssemblyLinearVelocity.Z * AssemblyLinearVelocity.Z)
	else
		return 0
	end
end
local function verticalSpeedAbs() --[[ verticalSpeedAbs | Line: 127 | Upvalues: v2 (ref) ]]
	if v2 and v2.RootPart then
		return math.abs(v2.RootPart.AssemblyLinearVelocity.Y)
	else
		return 0
	end
end
local function isLoopingName(p1) --[[ isLoopingName | Line: 132 ]]
	return if p1 == "idle" or (p1 == "walk" or (p1 == "jog" or p1 == "run")) then true else string.match(p1, "^walk_") or (string.match(p1, "^jog_") or (string.match(p1, "^run_") or (if p1 == "fall" or (p1 == "climb" or (p1 == "climbidle" or (p1 == "swim" or (p1 == "swimidle" or (p1 == "sit" or p1 == "crouch_idle"))))) then true else string.match(p1, "^crouch_walk_") or (if p1 == "prone_idle" then true else string.match(p1, "^prone_crawl_") or string.match(p1, "^prone_turn_")))))
end
local function setLoopingFor(p1, p2) --[[ setLoopingFor | Line: 146 | Upvalues: isLoopingName (copy) ]]
	if p2 then
		p2.Looped = isLoopingName(p1)
	end
end
local function stopCurrent(p1) --[[ stopCurrent | Line: 151 | Upvalues: v8 (ref), v7 (ref), v6 (ref) ]]
	if v8 then
		v8:Disconnect()
		v8 = nil
	end
	if v7 then
		v7:Stop(p1 or 0)
		v7 = nil
	end
	v6 = ""
end
local function onKeyframeReached(p1) --[[ onKeyframeReached | Line: 165 ]] end
local function loadOnAnimator(p1) --[[ loadOnAnimator | Line: 167 | Upvalues: v5 (ref), v2 (ref) ]]
	if not p1 then
		return nil
	end
	if v5 then
		return v5:LoadAnimation(p1)
	end
	if v2 then
		return v2:LoadAnimation(p1)
	else
		return nil
	end
end
local function v19(p1, p2) --[[ configureAnimationSet | Line: 180 | Upvalues: t2 (copy), v19 (copy), t4 (copy), v5 (ref), v2 (ref) ]]
	local v1 = t2[p1]
	if v1 and v1.conns then
		for i, v in ipairs(v1.conns) do
			v:Disconnect()
		end
	end
	local v22 = t2[p1] or {}
	v22.anim = nil
	v22.speed = 1
	v22.conns = {}
	t2[p1] = v22
	local v3 = script:FindFirstChild(p1)
	if v3 and v3:IsA("Folder") then
		for i, v in ipairs(v3:GetChildren()) do
			if v:IsA("Animation") then
				v22.anim = v
				local Speed = v3:FindFirstChild("Speed")
				if Speed and Speed:IsA("NumberValue") then
					v22.speed = tonumber(Speed.Value) or 1
				elseif p2 and (p2[1] and p2[1].speed) then
					v22.speed = p2[1].speed
				else
					v22.speed = 1
				end
				local function f5() --[[ Line: 209 | Upvalues: v19 (ref), p1 (copy), p2 (copy) ]]
					v19(p1, p2)
				end
				table.insert(v22.conns, v3.ChildAdded:Connect(f5))
				local function f6() --[[ Line: 212 | Upvalues: v19 (ref), p1 (copy), p2 (copy) ]]
					v19(p1, p2)
				end
				table.insert(v22.conns, v3.ChildRemoved:Connect(f6))
				if v.AnimationId == "" or (t4[v.AnimationId] or not pcall(function() --[[ Line: 217 | Upvalues: v (copy), v5 (ref), v2 (ref) ]]
					local v1 = v
					local v22 = if v1 then if v5 then v5:LoadAnimation(v1) elseif v2 then v2:LoadAnimation(v1) else nil else nil
					if not v22 then
						return
					end
					v22:Stop(0)
				end)) then
					return
				end
				t4[v.AnimationId] = true
				return
			end
		end
	end
	if v22.anim or not (p2 and (p2[1] and p2[1].id)) then
		return
	end
	local Animation = Instance.new("Animation")
	Animation.Name = p1
	Animation.AnimationId = p2[1].id
	v22.anim = Animation
	v22.speed = p2[1].speed or 1
	if Animation.AnimationId == "" or (t4[Animation.AnimationId] or not pcall(function() --[[ Line: 239 | Upvalues: Animation (copy), v5 (ref), v2 (ref) ]]
		local v1 = Animation
		local v22 = if v1 then if v5 then v5:LoadAnimation(v1) elseif v2 then v2:LoadAnimation(v1) else nil else nil
		if not v22 then
			return
		end
		v22:Stop(0)
	end)) then
		return
	end
	t4[Animation.AnimationId] = true
end
local function fallbackName(p1) --[[ fallbackName | Line: 250 | Upvalues: t2 (copy) ]]
	if string.match(p1, "^run_") then
		if t2.run and t2.run.anim then
			return "run"
		else
			return nil
		end
	elseif string.match(p1, "^jog_") then
		if t2.jog and t2.jog.anim then
			return "jog"
		else
			return nil
		end
	elseif string.match(p1, "^walk_") then
		if t2.walk and t2.walk.anim then
			return "walk"
		else
			return nil
		end
	elseif string.match(p1, "^crouch_walk_") then
		if t2.crouch_idle and t2.crouch_idle.anim then
			return "crouch_idle"
		else
			return nil
		end
	else
		if not string.match(p1, "^prone_crawl_") then
			return nil
		end
		if t2.prone_idle and t2.prone_idle.anim then
			return "prone_idle"
		else
			return nil
		end
	end
end
local function play(p1, p2) --[[ play | Line: 271 | Upvalues: v6 (ref), v7 (ref), t2 (copy), fallbackName (copy), v5 (ref), v2 (ref), t6 (copy), isLoopingName (copy), v8 (ref), onKeyframeReached (copy) ]]
	if v6 == p1 and (v7 and v7.IsPlaying) then
		return
	end
	local v1 = t2[p1]
	if not (v1 and v1.anim) then
		local v22 = fallbackName(p1) or (if p1 == "idle" then nil else "idle")
		if not (v22 and (t2[v22] and t2[v22].anim)) then
			return
		end
		v1 = t2[v22]
		p1 = v22
	end
	local anim = v1.anim
	local v3 = p2 ~= nil and p2 or 0.18
	local v4 = math.max(v3, 0.2)
	local v52 = if anim then if v5 then v5:LoadAnimation(anim) elseif v2 then v2:LoadAnimation(anim) else nil else nil
	if not v52 then
		return
	end
	v52.Priority = t6[p1] or Enum.AnimationPriority.Movement
	if v52 then
		v52.Looped = isLoopingName(p1)
	end
	v52:AdjustSpeed(v1.speed or 1)
	v6 = p1
	if v7 then
		v52:Play(v3)
		pcall(function() --[[ Line: 311 | Upvalues: v52 (copy), v3 (copy) ]]
			v52:AdjustWeight(0, 0)
			v52:AdjustWeight(1, v3)
		end)
		local v72 = v7
		pcall(function() --[[ Line: 317 | Upvalues: v72 (copy), v4 (copy) ]]
			v72:AdjustWeight(0, v4)
		end)
		task.delay(v4, function() --[[ Line: 321 | Upvalues: v72 (copy) ]]
			if not (v72 and v72.IsPlaying) then
				return
			end
			v72:Stop(0)
		end)
		if v8 then
			v8:Disconnect()
		end
		v7 = v52
	else
		v52:Play(v3)
		v7 = v52
		if v8 then
			v8:Disconnect()
		end
	end
	v8 = v52.KeyframeReached:Connect(onKeyframeReached)
end
local function applyCadenceFor(p1, p2) --[[ applyCadenceFor | Line: 333 | Upvalues: v7 (ref), Animation_CFG (copy), t2 (copy), getHeightScale (copy) ]]
	if not v7 then
		return
	end
	local v1 = p1 == "run" and Animation_CFG.tiers.run.target or (p1 == "jog" and Animation_CFG.tiers.jog.target or (p1 == "walk" and Animation_CFG.tiers.walk.target or (string.match(p1, "^run_") and Animation_CFG.tiers.run.target or (string.match(p1, "^jog_") and Animation_CFG.tiers.jog.target or (string.match(p1, "^walk_") and Animation_CFG.tiers.walk.target or (string.match(p1, "^crouch_walk_") and Animation_CFG.tiers.walk.target or ((p1 == "prone_crawl_forward" or p1 == "prone_crawl_backward") and Animation_CFG.tiers.walk.target or (p1 == "swim" and Animation_CFG.tiers.swim and Animation_CFG.tiers.swim.target or 0))))))))
	local v2 = t2[p1] and t2[p1].speed or 1
	if v1 <= 0 then
		v7:AdjustSpeed(v2)
	else
		local v6 = math.clamp(p2 * (Animation_CFG.flags.rootMotionScale or 1) / math.max(0.0001, (getHeightScale())) / v1, Animation_CFG.speedMap.minMult, Animation_CFG.speedMap.maxMult)
		local Speed = v7.Speed
		v7:AdjustSpeed(Speed + (v2 * v6 - Speed) * 0.25)
	end
end
local function tierFromSpeed(p1) --[[ tierFromSpeed | Line: 364 | Upvalues: Animation_CFG (copy) ]]
	if p1 < Animation_CFG.tiers.walk.min then
		return "idle"
	end
	if p1 < Animation_CFG.tiers.walk.max then
		return "walk"
	end
	if p1 < Animation_CFG.tiers.jog.max then
		return "jog"
	else
		return "run"
	end
end
local function getMoveDirection() --[[ getMoveDirection | Line: 376 | Upvalues: v2 (ref) ]]
	if v2 and v2.RootPart then
		return v2.RootPart.CFrame:VectorToObjectSpace(v2.MoveDirection)
	else
		return Vector3.new(0, 0, 0)
	end
end
local function chooseLocomotion(p1, p2, p3, p4) --[[ chooseLocomotion | Line: 387 | Upvalues: v2 (ref), Animation_CFG (copy) ]]
	local v1
	if v2 then
		local v22 = v2:GetState()
		v1 = if v22 == Enum.HumanoidStateType.Freefall then false elseif v22 == Enum.HumanoidStateType.FallingDown then false else true
	else
		v1 = true
	end
	if not v1 then
		return "fall"
	end
	local v3 = if v2 and v2.RootPart then v2.RootPart.CFrame:VectorToObjectSpace(v2.MoveDirection) else Vector3.new(0, 0, 0)
	local Z = v3.Z
	local X = v3.X
	if p4 then
		if p1 < Animation_CFG.thresholds.stopSpeed and p2 < Animation_CFG.thresholds.stopIntentMag then
			return "prone_idle"
		end
		if Z < -0.5 then
			return "prone_crawl_forward"
		end
		if Z > 0.5 then
			return "prone_crawl_backward"
		end
		if X > 0.5 then
			return "prone_turn_right"
		end
		if X < -0.5 then
			return "prone_turn_left"
		else
			return "prone_idle"
		end
	elseif p3 then
		if p1 < Animation_CFG.thresholds.stopSpeed and p2 < Animation_CFG.thresholds.stopIntentMag then
			return "crouch_idle"
		end
		if Z < -0.5 then
			return "crouch_walk_forward"
		end
		if Z > 0.5 then
			return "crouch_walk_backward"
		end
		if X > 0.5 then
			return "crouch_walk_right"
		end
		if X < -0.5 then
			return "crouch_walk_left"
		else
			return "crouch_idle"
		end
	else
		if p1 < Animation_CFG.thresholds.stopSpeed and p2 < Animation_CFG.thresholds.stopIntentMag then
			return "idle"
		end
		local v5 = if p1 < Animation_CFG.tiers.walk.min then "idle" elseif p1 < Animation_CFG.tiers.walk.max then "walk" elseif p1 < Animation_CFG.tiers.jog.max then "jog" else "run"
		if v5 == "idle" then
			return "idle"
		end
		if Z < -0.5 then
			return v5 .. "_forward"
		end
		if Z > 0.5 then
			return v5 .. "_backward"
		end
		if X > 0.5 then
			return v5 .. "_right"
		end
		if X < -0.5 then
			return v5 .. "_left"
		else
			return v5 .. "_forward"
		end
	end
end
local function onJumping() --[[ onJumping | Line: 464 | Upvalues: v11 (ref), Animation_CFG (copy), play (copy), v9 (ref) ]]
	v11 = Animation_CFG.transition.jumpDuration
	play("jump", Animation_CFG.transition.jump)
	v9 = false
end
local function onFreeFalling() --[[ onFreeFalling | Line: 470 | Upvalues: v9 (ref), v11 (ref), v2 (ref), v10 (ref), play (copy), Animation_CFG (copy) ]]
	v9 = true
	v11 = 0
	if v2 and v2.RootPart then
		v10 = v2.RootPart.Position.Y
	end
	play("fall", Animation_CFG.transition.fall)
end
local function onLanded(p1) --[[ onLanded | Line: 479 | Upvalues: v12 (ref), Animation_CFG (copy), v2 (ref), v10 (ref), v9 (ref), play (copy) ]]
	if p1 < v12 then
		return
	end
	v12 = p1 + Animation_CFG.landing.cooldown
	local v1 = 0
	if v2 and v2.RootPart then
		local Y = v2.RootPart.Position.Y
		if v10 then
			v1 = math.max(0, v10 - Y)
		end
	end
	v10 = nil
	v9 = false
	if Animation_CFG.landing.hardFromHeight < v1 then
		play("land_hard", Animation_CFG.transition.land_hard)
	else
		play("land_soft", Animation_CFG.transition.land_soft)
	end
end
local function onDied() --[[ onDied | Line: 501 | Upvalues: t (copy), v4 (ref) ]]
	t.Destroy()
	if not v4 then
		return
	end
	v4.Transform = CFrame.new()
end
local function heartbeatDriver(p1) --[[ heartbeatDriver | Line: 510 | Upvalues: v15 (ref), v11 (ref), v2 (ref), v1 (ref), v17 (ref), play (copy), Animation_CFG (copy), v18 (ref), v6 (ref), applyCadenceFor (copy), t3 (ref), t2 (copy), v7 (ref), v16 (ref), v9 (ref), v10 (ref), chooseLocomotion (copy), v13 (ref), v4 (ref), isLoopingName (copy) ]]
	if not v15 then
		v15 = p1
		return
	end
	local v12 = p1 - v15
	v15 = p1
	if v11 > 0 then
		v11 = math.max(0, v11 - v12)
	end
	if not v2 or v2.Health <= 0 then
		return
	end
	local v3 = v1:GetAttribute("Crouching") or false
	local v42 = v1:GetAttribute("Prone") or false
	if v3 and not v17 then
		play("crouch_start", Animation_CFG.transition.crouch_start or 0.75)
	end
	v17 = v3
	v18 = v42
	local v5
	if v2 and v2.RootPart then
		local AssemblyLinearVelocity = v2.RootPart.AssemblyLinearVelocity
		v5 = math.sqrt(AssemblyLinearVelocity.X * AssemblyLinearVelocity.X + AssemblyLinearVelocity.Z * AssemblyLinearVelocity.Z)
	else
		v5 = 0
	end
	local Magnitude = v2.MoveDirection.Magnitude
	local v8 = v2:GetState()
	if v8 == Enum.HumanoidStateType.Seated then
		if v6 == "sit" then
			return
		end
		play("sit", Animation_CFG.transition.sit)
	elseif v8 == Enum.HumanoidStateType.Swimming then
		local v92 = if Animation_CFG.thresholds.startSpeed <= v5 then "swim" else "swimidle"
		if v6 ~= v92 then
			play(v92, Animation_CFG.transition[v92] or 0.25)
		end
		if v92 ~= "swim" then
			return
		end
		applyCadenceFor("swim", v5)
	elseif v8 == Enum.HumanoidStateType.Climbing then
		local v102 = "climb"
		local v112 = if v2 and v2.RootPart then math.abs(v2.RootPart.AssemblyLinearVelocity.Y) else 0
		local v122 = Animation_CFG.climb and Animation_CFG.climb.motionEps or 0.05
		local v132 = Animation_CFG.climb and Animation_CFG.climb.intentEps or 0.05
		if t3.climbidle and (t2.climbidle and t2.climbidle.anim) then
			if v112 < v122 and Magnitude < v132 then
				v102 = "climbidle"
			end
		elseif v112 < v122 and Magnitude < v132 then
			v102 = "climb"
		end
		if v6 ~= v102 then
			play(v102, Animation_CFG.transition.climb)
		end
		if not v7 then
			return
		end
		if v102 == "climb" then
			if v112 < v122 and (Magnitude < v132 and not t3.climbidle) then
				if not v16 then
					v7:AdjustSpeed(0)
					v16 = true
				end
			else
				local v14 = if t2[v6] then t2[v6].speed or 1 else 1
				if v16 then
					v7:AdjustSpeed(v14)
					v16 = false
				end
			end
		else
			v7:AdjustSpeed(if t2[v6] then t2[v6].speed or 1 else 1)
			v16 = false
		end
	elseif v8 == Enum.HumanoidStateType.Jumping then
		if v11 <= 0 then
			v11 = Animation_CFG.transition.jumpDuration
			play("jump", Animation_CFG.transition.jump)
			v9 = false
		end
		if not (v11 > 0) or v6 == "jump" then
			return
		end
		play("jump", Animation_CFG.transition.jump)
	elseif v8 == Enum.HumanoidStateType.Freefall or v8 == Enum.HumanoidStateType.FallingDown then
		if not v9 and v11 <= 0 then
			v9 = true
			v11 = 0
			if v2 and v2.RootPart then
				v10 = v2.RootPart.Position.Y
			end
			play("fall", Animation_CFG.transition.fall)
		end
		if v6 == "fall" then
			return
		end
		play("fall", Animation_CFG.transition.fall)
	else
		if v6 == "crouch_start" and (v7 and v7.IsPlaying) then
			return
		end
		if (v6 == "land_soft" or v6 == "land_hard") and (v7 and (if v7.WeightCurrent == nil then 1 else v7.WeightCurrent or 1) > 0.5) then
			return
		end
		local v172 = chooseLocomotion(v5, Magnitude, v3, v42)
		if v172 ~= v6 then
			play(v172, Animation_CFG.transition[v172] or 0.5)
		end
		if v172 == "walk" or (v172 == "jog" or (v172 == "run" or (string.match(v172, "^walk_") or (string.match(v172, "^jog_") or (string.match(v172, "^run_") or (string.match(v172, "^crouch_walk_") or (v172 == "prone_crawl_forward" or v172 == "prone_crawl_backward"))))))) then
			applyCadenceFor(v172, v5)
		elseif v7 then
			v7:AdjustSpeed(if t2[v6] then t2[v6].speed or 1 else 1)
		end
		local v19
		if v2 then
			local v20 = v2:GetState()
			v19 = if v20 == Enum.HumanoidStateType.Freefall then false elseif v20 == Enum.HumanoidStateType.FallingDown then false else true
		else
			v19 = true
		end
		if v19 then
			if v2.RootPart then
				local v23 = -(if v2 and v2.RootPart then v2.RootPart.CFrame:VectorToObjectSpace(v2.MoveDirection) else Vector3.new(0, 0, 0)).X * 0.08726646259971647
				local v24 = math.min(1, v12 / 0.1)
				v13 = v13 * (1 - v24) + v23 * v24
				if v4 then
					v4.Transform = CFrame.Angles(0, 0, v13)
				end
			end
		else
			v13 = 0
			if v4 then
				v4.Transform = CFrame.new()
			end
		end
		if isLoopingName(v6) and not (v7 and v7.IsPlaying) then
			play(v6, 0)
		end
		if v7 and v7.IsPlaying or t2[v6] and t2[v6].anim then
			return
		end
		play("idle", 0)
	end
end
function t.Init(p1) --[[ Init | Line: 688 | Upvalues: v1 (ref), v2 (ref), v3 (ref), v4 (ref), v5 (ref), LocalPlayer (copy), Players (copy), v14 (ref), Animation_CFG (copy), defaultHipHeight (ref), t3 (ref), t5 (copy), v19 (copy), t2 (copy), onDied (copy), onJumping (copy), onFreeFalling (copy), onLanded (copy), play (copy), RunService (copy), heartbeatDriver (copy), t (copy) ]]
	v1 = p1
	v2 = p1:WaitForChild("Humanoid")
	v3 = p1:WaitForChild("UpperTorso")
	v4 = v3:WaitForChild("Waist")
	v5 = v2:WaitForChild("Animator")
	if LocalPlayer and Players:GetPlayerFromCharacter(p1) ~= LocalPlayer then
		return
	end
	local Animate = p1:FindFirstChild("Animate")
	if Animate and Animate:IsA("LocalScript") then
		Animate.Disabled = true
	end
	v14 = script:FindFirstChild(Animation_CFG.scale.scaleDampeningValueName)
	if not (Animation_CFG and Animation_CFG.scale) then
		warn("AnimationModule: CFG or CFG.scale is nil")
	end
	defaultHipHeight = v2.HipHeight or Animation_CFG.scale.defaultHipHeight
	local t4 = {
		idle = Animation_CFG.anims.idle_NoGun or Animation_CFG.anims.idle
	}
	t4.walk_forward = Animation_CFG.anims.walk_forward or Animation_CFG.anims.walk
	t4.walk_backward = Animation_CFG.anims.walk_backward or Animation_CFG.anims.walk
	t4.walk_left = Animation_CFG.anims.walk_left or Animation_CFG.anims.walk
	t4.walk_right = Animation_CFG.anims.walk_right or Animation_CFG.anims.walk
	t4.jog_forward = Animation_CFG.anims.jog_forward and #Animation_CFG.anims.jog_forward > 0 and Animation_CFG.anims.jog_forward or (Animation_CFG.anims.jog or (Animation_CFG.anims.walk_forward or Animation_CFG.anims.walk))
	t4.jog_backward = Animation_CFG.anims.jog_backward and #Animation_CFG.anims.jog_backward > 0 and Animation_CFG.anims.jog_backward or (Animation_CFG.anims.jog or (Animation_CFG.anims.walk_backward or Animation_CFG.anims.walk))
	t4.jog_left = Animation_CFG.anims.jog_left and #Animation_CFG.anims.jog_left > 0 and Animation_CFG.anims.jog_left or (Animation_CFG.anims.jog or (Animation_CFG.anims.walk_left or Animation_CFG.anims.walk))
	t4.jog_right = Animation_CFG.anims.jog_right and #Animation_CFG.anims.jog_right > 0 and Animation_CFG.anims.jog_right or (Animation_CFG.anims.jog or (Animation_CFG.anims.walk_right or Animation_CFG.anims.walk))
	t4.run_forward = Animation_CFG.anims.run_forward or Animation_CFG.anims.run or Animation_CFG.anims.jog or Animation_CFG.anims.walk
	t4.run_backward = Animation_CFG.anims.run_backward or Animation_CFG.anims.run or Animation_CFG.anims.jog or Animation_CFG.anims.walk
	t4.run_left = Animation_CFG.anims.run_left or Animation_CFG.anims.run or Animation_CFG.anims.jog or Animation_CFG.anims.walk
	t4.run_right = Animation_CFG.anims.run_right or Animation_CFG.anims.run or Animation_CFG.anims.jog or Animation_CFG.anims.walk
	t4.walk = Animation_CFG.anims.walk
	t4.jog = Animation_CFG.anims.jog
	t4.run = Animation_CFG.anims.run
	t4.swim = Animation_CFG.anims.swim
	t4.swimidle = Animation_CFG.anims.swimidle
	t4.jump = Animation_CFG.anims.jump
	t4.fall = Animation_CFG.anims.fall
	t4.climb = Animation_CFG.anims.climb
	t4.climbidle = Animation_CFG.anims.climbidle
	t4.sit = Animation_CFG.anims.sit
	t4.land_soft = Animation_CFG.anims.land_soft
	t4.land_hard = Animation_CFG.anims.land_hard
	t4.crouch_start = Animation_CFG.anims.crouch_start
	t4.crouch_idle = Animation_CFG.anims.crouch_idle
	t4.crouch_walk_forward = Animation_CFG.anims.crouch_walk_forward
	t4.crouch_walk_backward = Animation_CFG.anims.crouch_walk_backward
	t4.crouch_walk_left = Animation_CFG.anims.crouch_walk_left
	t4.crouch_walk_right = Animation_CFG.anims.crouch_walk_right
	t4.prone_idle = Animation_CFG.anims.prone_idle
	t4.prone_crawl_forward = Animation_CFG.anims.prone_crawl_forward
	t4.prone_crawl_backward = Animation_CFG.anims.prone_crawl_backward
	t4.prone_turn_left = Animation_CFG.anims.prone_turn_left
	t4.prone_turn_right = Animation_CFG.anims.prone_turn_right
	t3 = t4
	for i, v in ipairs(v5:GetPlayingAnimationTracks()) do
		v:Stop(0)
	end
	local function f16(p1) --[[ Line: 771 | Upvalues: t3 (ref), v19 (ref) ]]
		if not t3[p1.Name] then
			return
		end
		v19(p1.Name, t3[p1.Name])
	end
	table.insert(t5, script.ChildAdded:Connect(f16))
	local function f18(p1) --[[ Line: 777 | Upvalues: t3 (ref), v19 (ref) ]]
		if not t3[p1.Name] then
			return
		end
		v19(p1.Name, t3[p1.Name])
	end
	table.insert(t5, script.ChildRemoved:Connect(f18))
	for k, v in pairs(t3) do
		if v then
			v19(k, v)
		end
	end
	local v20, v23, v26, v29, v30, v322, v33, v35, v36
	if not (t2.idle and t2.idle.anim) then
		local v37 = if t2.walk and t2.walk.anim then "walk" elseif t2.jog and t2.jog.anim then "jog" else t2.run and (t2.run.anim and "run")
		if v37 then
			t2.idle = t2[v37]
		end
	end
	v20 = v2.Died
	table.insert(t5, v20:Connect(onDied))
	v23 = v2.Jumping
	table.insert(t5, v23:Connect(onJumping))
	v26 = v2.FreeFalling
	table.insert(t5, v26:Connect(onFreeFalling))
	v29 = v2.StateChanged
	v30 = function(p1, p2) --[[ Line: 801 | Upvalues: onLanded (ref) ]]
		if p2 ~= Enum.HumanoidStateType.Landed then
			return
		end
		onLanded(os.clock())
	end
	table.insert(t5, v29:Connect(v30))
	play("idle", Animation_CFG.transition.idle)
	v322 = RunService.Heartbeat
	v33 = function() --[[ Line: 809 | Upvalues: heartbeatDriver (ref) ]]
		heartbeatDriver(os.clock())
	end
	table.insert(t5, v322:Connect(v33))
	v35 = p1.AncestryChanged
	v36 = function(p1, p2) --[[ Line: 813 | Upvalues: t (ref) ]]
		if p2 ~= nil then
			return
		end
		t.Destroy()
	end
	table.insert(t5, v35:Connect(v36))
end
function t.ForcePlay(p1, p2) --[[ ForcePlay | Line: 820 | Upvalues: t2 (copy), fallbackName (copy), play (copy) ]]
	if not p1 then
		return
	end
	if not (t2[p1] and t2[p1].anim) then
		local v1 = fallbackName(p1)
		if not (v1 and (t2[v1] and t2[v1].anim)) then
			return
		end
		p1 = v1
	end
	play(p1, p2)
end
function t.Stop(p1) --[[ Stop | Line: 832 | Upvalues: v8 (ref), v7 (ref), v6 (ref) ]]
	local v1 = p1 or 0
	if v8 then
		v8:Disconnect()
		v8 = nil
	end
	if v7 then
		v7:Stop(v1 or 0)
		v7 = nil
	end
	v6 = ""
end
function t.Destroy() --[[ Destroy | Line: 836 | Upvalues: v8 (ref), v7 (ref), v6 (ref), t2 (copy), t5 (copy) ]]
	if v8 then
		v8:Disconnect()
		v8 = nil
	end
	if v7 then
		v7:Stop(0)
		v7 = nil
	end
	v6 = ""
	for k, v in pairs(t2) do
		if v.conns then
			for i, v2 in ipairs(v.conns) do
				v2:Disconnect()
			end
		end
	end
	for i, v in ipairs(t5) do
		v:Disconnect()
	end
	table.clear(t5)
end
return t