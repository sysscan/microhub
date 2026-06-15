local UserInputService = game:GetService("UserInputService")

local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local util = opts.util

	local enterCooldown = 0

	local function getVehiclesFolder()
		return workspace:FindFirstChild("Vehicles")
	end

	local function getPlayerFolder()
		return util.getPlayerFolder()
	end

	local function getInVehicleValue()
		local folder = getPlayerFolder()
		local values = folder and folder:FindFirstChild("Values")
		return values and values:FindFirstChild("InVehicle")
	end

	local function isInVehicle()
		local value = getInVehicleValue()
		return value ~= nil and value:IsA("BoolValue") and value.Value == true
	end

	local function getCurrentVehicleId()
		local folder = getPlayerFolder()
		local alive = folder and folder:FindFirstChild("Alive")
		local current = alive and alive:FindFirstChild("CurrentVehicle")
		if current and current:IsA("StringValue") then
			return current.Value
		end
		return ""
	end

	local function getVehicleById(id)
		if typeof(id) ~= "string" or id == "" then
			return nil
		end
		local vehicles = getVehiclesFolder()
		if not vehicles then
			return nil
		end
		for _, vehicle in vehicles:GetChildren() do
			if vehicle:GetAttribute("Id") == id and vehicle:GetAttribute("Destroyed") ~= true then
				return vehicle
			end
		end
		return nil
	end

	local function getActiveVehicle()
		return getVehicleById(getCurrentVehicleId())
	end

	local function getVehicleSeat(vehicle)
		local seats = vehicle and vehicle:FindFirstChild("Seats")
		local seat = seats and seats:FindFirstChild("VehicleSeat")
		if seat and seat:IsA("VehicleSeat") then
			return seat
		end
		return nil
	end

	local function getDriveRoot(vehicle)
		local chassis = vehicle and vehicle:FindFirstChild("Chassis")
		local root = chassis and chassis:FindFirstChild("Root")
		if root and root:IsA("BasePart") then
			return root
		end
		return nil
	end

	local function findNearestVehicle(maxDistance)
		local root = util.getRoot()
		local vehicles = getVehiclesFolder()
		if not root or not vehicles then
			return nil
		end

		local bestVehicle
		local bestDistance = maxDistance

		for _, vehicle in vehicles:GetChildren() do
			if vehicle:GetAttribute("Destroyed") == true then
				continue
			end
			local seat = getVehicleSeat(vehicle)
			if not seat then
				continue
			end
			local distance = (root.Position - seat.Position).Magnitude
			if distance <= bestDistance then
				bestDistance = distance
				bestVehicle = vehicle
			end
		end

		return bestVehicle, bestDistance
	end

	local function fireVehicleRemote(vehicle, command)
		local root = getDriveRoot(vehicle)
		local remote = root and root:FindFirstChild("RemoteEvent")
		if not remote or not remote:IsA("RemoteEvent") then
			return false, "vehicle remote missing"
		end
		local ok, err = pcall(function()
			if command == nil then
				remote:FireServer()
			else
				remote:FireServer(command)
			end
		end)
		return ok, err
	end

	local function tryEnterVehicle(vehicle)
		if isInVehicle() then
			return true
		end
		if not vehicle then
			return false
		end
		if tick() - enterCooldown < 1.5 then
			return false
		end

		local humanoid = util.getHumanoid()
		local root = util.getRoot()
		local seat = getVehicleSeat(vehicle)
		if not humanoid or not root or not seat then
			return false
		end

		local enterRange = math.clamp(tonumber(Config.VehicleFlyEnterRange) or Constants.VEHICLE_FLY_ENTER_RANGE, 8, 40)
		if (root.Position - seat.Position).Magnitude > enterRange then
			return false
		end

		if humanoid:FindFirstChildOfClass("Tool") or util.getEquippedTool() then
			return false
		end

		enterCooldown = tick()
		local ok = pcall(function()
			humanoid:Sit(seat)
		end)
		if not ok then
			return false
		end

		for _ = 1, 10 do
			task.wait(0.1)
			if isInVehicle() and getActiveVehicle() == vehicle then
				return true
			end
		end

		return isInVehicle()
	end

	local function tryEnterNearest()
		local enterRange = math.clamp(tonumber(Config.VehicleFlyEnterRange) or Constants.VEHICLE_FLY_ENTER_RANGE, 8, 40)
		local vehicle = findNearestVehicle(enterRange)
		if not vehicle then
			return false
		end
		return tryEnterVehicle(vehicle)
	end

	local function getFlyInput()
		local camera = workspace.CurrentCamera
		if not camera then
			return Vector3.zero
		end
		local move = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			move += camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			move -= camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			move -= camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			move += camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			move += Vector3.new(0, 1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			move -= Vector3.new(0, 1, 0)
		end
		if move.Magnitude > 0 then
			return move.Unit
		end
		return Vector3.zero
	end

	local function getFlySpeed()
		local speed = tonumber(Config.FlySpeed) or Constants.SAFE_FLY_SPEED
		if Config.FlySafeSpeed then
			return math.clamp(speed, 8, Constants.SAFE_FLY_SPEED)
		end
		return math.clamp(speed, 8, Constants.MAX_FLY_SPEED)
	end

	local function applyPlaneStyleDrive(vehicle, speed)
		local root = getDriveRoot(vehicle)
		if not root then
			return false
		end
		local bodyVelocity = root:FindFirstChild("BodyVelocity")
		local bodyGyro = root:FindFirstChild("BodyGyro")
		if not bodyVelocity or not bodyVelocity:IsA("BodyVelocity") then
			return false
		end

		local move = getFlyInput()
		if move.Magnitude > 0 then
			local velocity = move * speed
			bodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
			bodyVelocity.Velocity = velocity
			if bodyGyro and bodyGyro:IsA("BodyGyro") then
				bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
				bodyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + move)
			end
		else
			bodyVelocity.Velocity = Vector3.zero
		end
		return true
	end

	local function tickVehicleFly(_dt)
		if Config.VehicleFlyAutoEnter and not isInVehicle() then
			tryEnterNearest()
		end

		local vehicle = getActiveVehicle()
		if not vehicle then
			return false
		end

		local vehicleType = vehicle:GetAttribute("Type")
		local speed = getFlySpeed()
		if vehicleType == "Plane" then
			return applyPlaneStyleDrive(vehicle, speed)
		end

		local root = getDriveRoot(vehicle)
		local bodyVelocity = root and root:FindFirstChild("BodyVelocity")
		if not root or not bodyVelocity then
			return false
		end

		local move = getFlyInput()
		if move.Magnitude > 0 then
			bodyVelocity.MaxForce = Vector3.new(1e7, 1e7, 1e7)
			bodyVelocity.Velocity = move * speed
		else
			bodyVelocity.Velocity = Vector3.zero
		end
		return true
	end

	local function describeVehicle(vehicle)
		if not vehicle then
			return "no vehicle"
		end
		local root = getDriveRoot(vehicle)
		local lines = {
			"Name=" .. vehicle.Name,
			"Id=" .. tostring(vehicle:GetAttribute("Id")),
			"Type=" .. tostring(vehicle:GetAttribute("Type")),
			"Destroyed=" .. tostring(vehicle:GetAttribute("Destroyed")),
		}
		if root then
			table.insert(lines, "Speed=" .. tostring(root:FindFirstChild("Speed") and root.Speed.Value))
			table.insert(lines, "RootY=" .. tostring(math.floor(root.Position.Y)))
		end
		return table.concat(lines, " | ")
	end

	return {
		isInVehicle = isInVehicle,
		getCurrentVehicleId = getCurrentVehicleId,
		getActiveVehicle = getActiveVehicle,
		getVehicleById = getVehicleById,
		findNearestVehicle = findNearestVehicle,
		tryEnterNearest = tryEnterNearest,
		tryEnterVehicle = tryEnterVehicle,
		fireVehicleRemote = fireVehicleRemote,
		tickVehicleFly = tickVehicleFly,
		describeVehicle = describeVehicle,
		getDriveRoot = getDriveRoot,
	}
end

return M
