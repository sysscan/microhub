local hubRequire = shared.__MicroHubRequire
local PlayerESP = hubRequire("lib/esp/player-v2.lua")

local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local LocalPlayer = opts.localPlayer
	local Util = opts.util
	local canDraw = opts.canDraw == true

	local playerEsp
	local woodLabels = {}
	local woodScanAt = 0
	local woodTargets = {}
	local MAX_WOOD_ESP_TARGETS = 80

	local function getCamera()
		return workspace.CurrentCamera or opts.camera
	end

	if canDraw then
		playerEsp = PlayerESP.create({
			config = Config,
			camera = getCamera(),
			localPlayer = LocalPlayer,
			canDraw = true,
			getCharacter = function(player)
				return player and player.Character
			end,
			isAlive = function(char)
				if not char then
					return false
				end
				local humanoid = char:FindFirstChildOfClass("Humanoid")
				local root = char:FindFirstChild("HumanoidRootPart")
				return humanoid ~= nil and root ~= nil and humanoid.Health > 0, humanoid, root
			end,
			getAccent = function()
				return Color3.fromRGB(120, 200, 120)
			end,
			getNameSuffix = function()
				return ""
			end,
		})
	end

	local function mkWoodLabel()
		if not canDraw then
			return nil
		end
		local label = Drawing.new("Text")
		label.Center = true
		label.Outline = true
		label.Size = 14
		label.Visible = false
		return label
	end

	local function releaseWoodLabels()
		for _, label in woodLabels do
			pcall(function()
				label:Remove()
			end)
		end
		table.clear(woodLabels)
		table.clear(woodTargets)
	end

	local function shouldShowWood(className: string?): boolean
		if not className or className == "" then
			return false
		end
		if Config.WoodESPAll then
			return true
		end
		if className == "Generic" then
			return false
		end
		return Constants.RARE_WOODS[className] == true
	end

	local function scanWoodTargets()
		table.clear(woodTargets)

		local root = Util.getRoot(LocalPlayer)
		if not root then
			return
		end

		local maxRange = math.clamp(tonumber(Config.WoodESPRange) or 400, 50, 2000)
		local origin = root.Position

		local function consider(model: Instance)
			if not model:IsA("Model") then
				return
			end
			local className = Util.getTreeClass(model)
			if not shouldShowWood(className) then
				return
			end
			local section = model:FindFirstChild("WoodSection", true)
			if not section or not section:IsA("BasePart") then
				return
			end
			if Util.distance(origin, section.Position) > maxRange then
				return
			end
			table.insert(woodTargets, {
				part = section,
				className = className,
			})
		end

		local treeRegion = workspace:FindFirstChild("TreeRegion")
		if treeRegion then
			for _, child in treeRegion:GetChildren() do
				consider(child)
			end
		end

		local logModels = workspace:FindFirstChild("LogModels")
		if logModels then
			for _, child in logModels:GetChildren() do
				consider(child)
			end
		end

		local playerModels = workspace:FindFirstChild("PlayerModels")
		if playerModels then
			for _, child in playerModels:GetChildren() do
				consider(child)
			end
		end

		table.sort(woodTargets, function(a, b)
			return Util.distanceSq(origin, a.part.Position) < Util.distanceSq(origin, b.part.Position)
		end)
		while #woodTargets > MAX_WOOD_ESP_TARGETS do
			table.remove(woodTargets)
		end
	end

	local function drawWoodEsp()
		if not canDraw or not Config.WoodESP then
			for _, label in woodLabels do
				label.Visible = false
			end
			return
		end

		local now = os.clock()
		if now - woodScanAt >= 1 then
			woodScanAt = now
			scanWoodTargets()
		end

		while #woodLabels < #woodTargets do
			local label = mkWoodLabel()
			if label then
				table.insert(woodLabels, label)
			else
				break
			end
		end

		local camera = getCamera()
		if not camera then
			return
		end

		for index, label in woodLabels do
			local target = woodTargets[index]
			if not target or not target.part.Parent then
				label.Visible = false
				continue
			end

			local screenPos, onScreen = camera:WorldToViewportPoint(target.part.Position)
			if not onScreen or screenPos.Z < 0 then
				label.Visible = false
				continue
			end

			label.Position = Vector2.new(screenPos.X, screenPos.Y)
			label.Text = target.className
			label.Color = Constants.WOOD_ESP_COLORS[target.className] or Color3.fromRGB(255, 220, 120)
			label.Visible = true
		end
	end

	local function needsEspTick()
		return Config.ESP or Config.WoodESP
	end

	local function tick()
		if playerEsp then
			playerEsp.update()
		end
		drawWoodEsp()
	end

	local function destroy()
		if playerEsp then
			playerEsp.destroy()
		end
		releaseWoodLabels()
	end

	return {
		tick = tick,
		destroy = destroy,
	}
end

return M
