local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local M = {}

function M.create(opts: {
	config: { [string]: any },
	localPlayer: Player,
	camera: Camera,
	maxSafeWalkspeed: number,
	maxSafeJump: number,
	canHook: boolean,
	connections: { RBXScriptConnection },
	loopStart: (fn: () -> ()) -> thread,
})
	local Config = opts.config
	local LocalPlayer = opts.localPlayer
	local Camera = opts.camera
	local MAX_SAFE_WALKSPEED = opts.maxSafeWalkspeed
	local MAX_SAFE_JUMP = opts.maxSafeJump
	local canHook = opts.canHook
	local connections = opts.connections
	local startLoop = opts.loopStart

	local jumpConn: RBXScriptConnection? = nil
	local headCollideConn: RBXScriptConnection? = nil
	local oldTazeFn: any = nil
	local tazeRemoteConn: any = nil
	local lightingBackup: { [string]: any }? = nil
	local killPlaneParts: { BasePart } = {}
	local killPlaneFolder: Folder? = nil
	local vehicleQueryBackup: { [BasePart]: boolean } = {}
	local vehicleFlyWelds: { Instance } = {}
	local vehicleFlyUp, vehicleFlyDown = 0, 0
	local vehicleFlyPart: BasePart? = nil
	local vehicleFlyConn: RBXScriptConnection? = nil
	local vehicleFlySeat: Instance? = nil
	local vehicleFlyInputBound = false

	local function isSprinting(): boolean
		return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.ButtonL3)
	end

	local function applyMovement()
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then
			return
		end
		if Config.SpeedBoost or Config.AlwaysSprint then
			hum.UseJumpPower = true
		end
		if Config.SpeedBoost then
			hum.WalkSpeed = math.min(Config.WalkSpeed, MAX_SAFE_WALKSPEED)
			hum.JumpPower = math.min(Config.JumpPower, MAX_SAFE_JUMP)
		elseif Config.AlwaysSprint and isSprinting() then
			hum.WalkSpeed = math.min(Config.SprintSpeed, MAX_SAFE_WALKSPEED)
		end
	end

	local function applyNoclip()
		if not Config.Noclip then
			return
		end
		local char = LocalPlayer.Character
		if not char then
			return
		end
		for _, part in char:GetDescendants() do
			if part:IsA("BasePart") and part.CanCollide then
				part.CanCollide = false
			end
		end
	end

	local function applyFullBright()
		if Config.FullBright then
			if not lightingBackup then
				lightingBackup = {
					Brightness = Lighting.Brightness,
					ClockTime = Lighting.ClockTime,
					FogEnd = Lighting.FogEnd,
					GlobalShadows = Lighting.GlobalShadows,
					OutdoorAmbient = Lighting.OutdoorAmbient,
				}
			end
			Lighting.Brightness = 2
			Lighting.ClockTime = 14
			Lighting.FogEnd = 100000
			Lighting.GlobalShadows = false
			Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
		elseif lightingBackup then
			for key, value in lightingBackup do
				Lighting[key] = value
			end
			lightingBackup = nil
		end
	end

	local function syncKillPlane()
		if Config.AntiKillPlane then
			if not killPlaneFolder then
				killPlaneFolder = Instance.new("Folder")
				killPlaneFolder.Name = "MicroHubPL_KillPlane"
				killPlaneFolder.Parent = workspace
				for x = -2048, 2048, 2048 do
					for z = -2048, 2048, 2048 do
						local part = Instance.new("Part")
						part.CanQuery = false
						part.CanCollide = true
						part.Anchored = true
						part.Transparency = 1
						part.Size = Vector3.new(2048, 10, 2048)
						part.Position = Vector3.new(x, 170, z)
						part.Parent = killPlaneFolder
						table.insert(killPlaneParts, part)
					end
				end
			end
		elseif killPlaneFolder then
			killPlaneFolder:Destroy()
			killPlaneFolder = nil
			table.clear(killPlaneParts)
		end
	end

	local function setDisabler(enabled: boolean)
		if not canHook then
			return
		end
		local head = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
		if not head then
			return
		end
		if enabled then
			local conn = getconnections(head:GetPropertyChangedSignal("CanCollide"))[1]
			if conn then
				conn:Disable()
				headCollideConn = conn
			end
		elseif headCollideConn then
			headCollideConn:Enable()
			headCollideConn = nil
		end
	end

	local function movementDisablerNeeded(): boolean
		return Config.Disabler
			or Config.SpeedBoost
			or Config.NoJumpCooldown
			or Config.Noclip
			or Config.AlwaysSprint
			or Config.VehicleSpeed
	end

	local function syncMovementDisabler()
		setDisabler(movementDisablerNeeded())
	end

	local function setAntiTaze(enabled: boolean)
		if not canHook then
			return
		end
		local gunRemotes = game:GetService("ReplicatedStorage"):FindFirstChild("GunRemotes")
		local playerTased = gunRemotes and gunRemotes:FindFirstChild("PlayerTased")
		if not playerTased then
			return
		end
		if enabled and not oldTazeFn then
			tazeRemoteConn = getconnections(playerTased.OnClientEvent)[1]
			if tazeRemoteConn and tazeRemoteConn.Function then
				oldTazeFn = tazeRemoteConn.Function
				hookfunction(oldTazeFn, function()
					local char = LocalPlayer.Character
					LocalPlayer:SetAttribute("BackpackEnabled", false)
					if char then
						local hum = char:FindFirstChildOfClass("Humanoid")
						if hum then
							hum:UnequipTools()
						end
					end
					task.wait(3.5)
					if LocalPlayer.Character == char then
						LocalPlayer:SetAttribute("BackpackEnabled", true)
					end
				end)
			end
		elseif not enabled and oldTazeFn and tazeRemoteConn and tazeRemoteConn.Function then
			if typeof(restorefunction) == "function" then
				restorefunction(tazeRemoteConn.Function)
			else
				hookfunction(tazeRemoteConn.Function, oldTazeFn)
			end
			oldTazeFn = nil
			tazeRemoteConn = nil
		end
	end

	local function setNoJumpCooldown(enabled: boolean)
		if not canHook then
			return
		end
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then
			return
		end
		if enabled then
			local conn = getconnections(hum:GetPropertyChangedSignal("Jump"))[1]
			if conn then
				conn:Disable()
				jumpConn = conn
			end
		elseif jumpConn then
			jumpConn:Enable()
			jumpConn = nil
		end
	end

	local function runVehicleWallbang()
		if not Config.VehicleWallbang then
			for part, value in vehicleQueryBackup do
				if part.Parent then
					part.CanQuery = value
				end
			end
			table.clear(vehicleQueryBackup)
			return
		end
		local cars = workspace:FindFirstChild("CarContainer")
		if not cars then
			return
		end
		for _, part in cars:GetDescendants() do
			if part:IsA("BasePart") then
				if vehicleQueryBackup[part] == nil then
					vehicleQueryBackup[part] = part.CanQuery
				end
				part.CanQuery = false
			end
		end
	end

	local function runVehicleSpeed()
		if not Config.VehicleSpeed then
			return
		end
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local seat = hum and hum.SeatPart
		if not seat or not seat:IsDescendantOf(workspace:FindFirstChild("CarContainer") or workspace) then
			return
		end
		local car = seat:FindFirstAncestorWhichIsA("Model")
		if not car then
			return
		end
		for _, child in car:GetDescendants() do
			if child:IsA("VehicleSeat") then
				child.MaxSpeed = Config.VehicleSpeedValue
				child.Torque = 4
			end
		end
	end

	local function stopVehicleFly()
		if vehicleFlyPart then
			vehicleFlyPart:Destroy()
			vehicleFlyPart = nil
		end
		for _, weld in vehicleFlyWelds do
			pcall(function()
				if typeof(weld) == "Instance" and weld:IsA("Constraint") then
					weld.Enabled = true
				end
			end)
		end
		table.clear(vehicleFlyWelds)
		vehicleFlySeat = nil
		if vehicleFlyConn then
			vehicleFlyConn:Disconnect()
			vehicleFlyConn = nil
		end
	end

	local function syncVehicleFly(enabled: boolean)
		stopVehicleFly()
		if not enabled then
			return
		end
		if not vehicleFlyInputBound then
			vehicleFlyInputBound = true
			for _, eventName in { "InputBegan", "InputEnded" } do
				table.insert(connections, UserInputService[eventName]:Connect(function(input)
					if UserInputService:GetFocusedTextBox() then
						return
					end
					if input.KeyCode == Enum.KeyCode.E then
						vehicleFlyUp = if eventName == "InputBegan" then 1 else 0
					elseif input.KeyCode == Enum.KeyCode.Q then
						vehicleFlyDown = if eventName == "InputBegan" then -1 else 0
					end
				end))
			end
		end
		if Config.VehicleFlyMode == "Part" then
			vehicleFlyPart = Instance.new("Part")
			vehicleFlyPart.Size = Vector3.new(50, 1, 50)
			vehicleFlyPart.Anchored = true
			vehicleFlyPart.CanQuery = false
			vehicleFlyPart.Transparency = 1
			vehicleFlyPart.Parent = nil
			startLoop(function()
				if not Config.VehicleFly then
					return
				end
				local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
				local seat = hum and hum.SeatPart
				if seat and vehicleFlyPart then
					vehicleFlyPart.CFrame = CFrame.new(seat.Position - Vector3.new(0, 2.2 - (vehicleFlyUp + vehicleFlyDown), 0))
					vehicleFlyPart.Parent = workspace
				elseif vehicleFlyPart then
					vehicleFlyPart.Parent = nil
				end
			end)
		else
			local inCar = false
			vehicleFlyConn = RunService.PreSimulation:Connect(function(dt)
				if not Config.VehicleFly then
					return
				end
				local char = LocalPlayer.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local seat = hum and hum.SeatPart
				local root = seat and char:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") and seat then
					if seat ~= vehicleFlySeat then
						inCar = seat:IsDescendantOf(workspace:FindFirstChild("CarContainer") or workspace) and seat:IsA("VehicleSeat")
						table.clear(vehicleFlyWelds)
						if inCar then
							local wheels = seat.Parent and seat.Parent.Parent and seat.Parent.Parent:FindFirstChild("Wheels")
							if wheels then
								for _, weld in wheels:GetDescendants() do
									if weld:IsA("HingeConstraint") or weld:IsA("CylindricalConstraint") or weld.Name == "Rotate" then
										pcall(function()
											weld.Enabled = false
										end)
										table.insert(vehicleFlyWelds, weld)
									end
								end
							end
						end
						vehicleFlySeat = seat
					end
					if inCar then
						root.AssemblyLinearVelocity = Vector3.new(0, 2.25, 0)
						root.CFrame = CFrame.lookAlong(root.Position, Camera.CFrame.LookVector)
							+ (hum.MoveDirection + Vector3.new(0, vehicleFlyUp + vehicleFlyDown, 0)) * Config.VehicleFlySpeed * dt
						Camera.CameraSubject = hum
					end
				elseif vehicleFlySeat then
					vehicleFlySeat = nil
					for _, weld in vehicleFlyWelds do
						pcall(function()
							if typeof(weld) == "Instance" and weld:IsA("Constraint") then
								weld.Enabled = true
							end
						end)
					end
					table.clear(vehicleFlyWelds)
				end
			end)
			table.insert(connections, vehicleFlyConn)
		end
	end

	return {
		applyMovement = applyMovement,
		applyNoclip = applyNoclip,
		applyFullBright = applyFullBright,
		syncKillPlane = syncKillPlane,
		setDisabler = setDisabler,
		syncMovementDisabler = syncMovementDisabler,
		setAntiTaze = setAntiTaze,
		setNoJumpCooldown = setNoJumpCooldown,
		runVehicleWallbang = runVehicleWallbang,
		runVehicleSpeed = runVehicleSpeed,
		syncVehicleFly = syncVehicleFly,
		stopVehicleFly = stopVehicleFly,
	}
end

return M
