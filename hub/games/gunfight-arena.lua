local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local UILib = shared.__MicroHubUILib
if typeof(UILib) ~= "table" or typeof(UILib.create) ~= "function" then
	error("MicroHub UI library not loaded — run hub/loader.lua", 0)
end

local Config = {
	SilentAim = false,
	TeamCheck = true,
	Prediction = false,
	NoRecoil = false,
	StableAim = false,
	InfiniteAmmo = false,
	RemoveForcefields = false,
	FOVCircle = false,
	FOVRadius = 100,
	Hitchance = 100,
	ProjectileSpeed = 1000,
	HitPart = "Head",
	BoxESP = false,
	NameESP = false,
	DistanceESP = false,
	HealthESP = false,
	TracerESP = false,
	Chams = false,
	ESPDistance = 325,
	TracerOrigin = "Bottom Screen",
	Primary = "",
	Secondary = "",
	PrimaryCamo = "",
	SecondaryCamo = "",
	ShowHUD = true,
}

local sessionConns = {}
local drawingObjects = {}
local espCache = {}
local healthCache = {}
local tracerCache = {}
local chamsCache = {}
local closestTarget = nil
local installedIndexHook = false
local oldIndex = nil

local VORTEX_PATH = { "PlayerScripts", "Vortex" }

local function notify(text, title, duration)
	title = title or "Gunfight Arena"
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = duration or 5,
		})
	end)
	warn("[GunfightArena]", title, "-", text)
end

local function getGenv()
	if typeof(getgenv) == "function" then
		return getgenv()
	end
	return _G
end

local function disconnectAll()
	for _, conn in ipairs(sessionConns) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	table.clear(sessionConns)
end

local function trackDrawing(object)
	table.insert(drawingObjects, object)
	return object
end

local function removeDrawing(object)
	if object then
		pcall(function()
			object:Remove()
		end)
	end
end

local function hasDrawing()
	return typeof(Drawing) == "table" and typeof(Drawing.new) == "function"
end

local function hasHookMetamethod()
	return typeof(hookmetamethod) == "function"
end

local function hasGetsenv()
	return typeof(getsenv) == "function"
end

local function inFireCallstack(maxLevel)
	if not debug or typeof(debug.getinfo) ~= "function" then
		return false
	end
	for level = 2, maxLevel or 8 do
		local info = debug.getinfo(level, "n")
		if not info then
			break
		end
		if info.name == "Fire" then
			return true
		end
	end
	return false
end

local function vector2(x, y)
	return Vector2.new(x, y)
end

local function findPath(root, ...)
	local current = root
	for _, name in ipairs({ ... }) do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

local function getVortex()
	local current = LocalPlayer
	for _, name in ipairs(VORTEX_PATH) do
		current = current and current:FindFirstChild(name)
	end
	return current
end

local function getCharacterRoot(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(character)
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getTargetPart(character)
	if not character then
		return nil
	end
	return character:FindFirstChild(Config.HitPart)
		or character:FindFirstChild("Head")
		or character:FindFirstChild("HumanoidRootPart")
end

local function getTeam(entity)
	local player = Players:GetPlayerFromCharacter(entity)
	if player then
		return player:GetAttribute("Team") or player.Team
	end
	return entity and entity:GetAttribute("Team")
end

local function isSameTeam(character)
	if not Config.TeamCheck then
		return false
	end
	local myTeam = LocalPlayer:GetAttribute("Team") or LocalPlayer.Team
	local targetTeam = getTeam(character)
	return myTeam ~= nil and targetTeam ~= nil and targetTeam == myTeam
end

local function isValidTarget(character)
	if not character or character == LocalPlayer.Character then
		return false
	end
	local humanoid = getHumanoid(character)
	local root = getCharacterRoot(character)
	return humanoid ~= nil and root ~= nil and humanoid.Health > 0 and not isSameTeam(character)
end

local function iterCharacters(callback)
	local seen = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local character = player.Character
			if character and not seen[character] then
				seen[character] = true
				callback(character, player)
			end
		end
	end
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("Model") and child ~= LocalPlayer.Character and not seen[child] then
			if child:FindFirstChild("HumanoidRootPart") and child:FindFirstChildOfClass("Humanoid") then
				seen[child] = true
				callback(child, Players:GetPlayerFromCharacter(child))
			end
		end
	end
end

local function isVisible(character)
	local targetPart = getTargetPart(character)
	if not targetPart or not LocalPlayer.Character then
		return false
	end
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { LocalPlayer.Character }
	params.FilterType = Enum.RaycastFilterType.Blacklist
	local origin = Camera.CFrame.Position
	local result = workspace:Raycast(origin, targetPart.Position - origin, params)
	return not result or result.Instance:IsDescendantOf(character)
end

local function predictedPosition(character)
	local targetPart = getTargetPart(character)
	if not targetPart then
		return nil
	end
	if not Config.Prediction then
		return targetPart.Position
	end
	local root = getCharacterRoot(character)
	local localRoot = getCharacterRoot(LocalPlayer.Character)
	if not root or not localRoot then
		return targetPart.Position
	end
	local distance = (localRoot.Position - targetPart.Position).Magnitude
	local travelTime = distance / math.max(Config.ProjectileSpeed, 1)
	return targetPart.Position + (root.AssemblyLinearVelocity * travelTime)
end

local function inHitchance()
	return math.random(1, 100) <= Config.Hitchance
end

local function getClosestTarget(radius)
	local closest = nil
	local closestDistance = radius or Config.FOVRadius
	iterCharacters(function(character)
		if not isValidTarget(character) then
			return
		end
		local targetPart = getTargetPart(character)
		if not targetPart then
			return
		end
		local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
		if not onScreen then
			return
		end
		local distance = (vector2(screenPos.X, screenPos.Y) - (Camera.ViewportSize / 2)).Magnitude
		if distance <= closestDistance then
			closest = character
			closestDistance = distance
		end
	end)
	return closest
end

local function resetCFrameModifier(modifiers, name)
	local value = modifiers:FindFirstChild(name)
	if value and value:IsA("CFrameValue") then
		value.Value = CFrame.new()
	end
end

local function applyCombatModifiers()
	local vortex = getVortex()
	local modifiers = vortex and vortex:FindFirstChild("Modifiers")
	if not modifiers then
		return
	end
	if Config.NoRecoil then
		local steadiness = modifiers:FindFirstChild("Steadiness")
		if steadiness and steadiness:IsA("NumberValue") and steadiness.Value ~= 0 then
			steadiness.Value = 0
		end
	end
	if Config.NoRecoil or Config.StableAim then
		resetCFrameModifier(modifiers, "Impulse")
		resetCFrameModifier(modifiers, "WeaponMod")
		resetCFrameModifier(modifiers, "CameraMod")
	end
end

local vortexEnv = nil
local lastRestockAt = 0

local function getVortexEnv()
	if not hasGetsenv() then
		return nil
	end
	local vortex = getVortex()
	if not vortex or not vortex.Enabled then
		vortexEnv = nil
		return nil
	end
	if vortexEnv then
		return vortexEnv
	end
	local ok, env = pcall(getsenv, vortex)
	if ok and typeof(env) == "table" then
		vortexEnv = env
		return env
	end
	return nil
end

local function maintainStoredAmmo()
	if not Config.InfiniteAmmo then
		return
	end
	local vortex = getVortex()
	if not vortex then
		return
	end
	for _, inst in ipairs(vortex:GetDescendants()) do
		if inst:IsA("NumberValue") and inst.Name == "StoredAmmo" and inst.Value < 1e9 then
			inst.Value = 1e9
		end
	end
end

local function restockAmmo()
	if not Config.InfiniteAmmo then
		return
	end
	maintainStoredAmmo()
	local now = os.clock()
	if now - lastRestockAt < 0.15 then
		return
	end
	lastRestockAt = now
	local env = getVortexEnv()
	if env and typeof(env.Restock) == "function" then
		pcall(env.Restock)
	end
end

local ALLY_FORCEFIELD_COLOR = Color3.fromRGB(0, 102, 255)

local function removeEnemyForcefields()
	if not Config.RemoveForcefields then
		return
	end
	local env = workspace:FindFirstChild("Env")
	if not env then
		return
	end
	local myTeam = LocalPlayer:GetAttribute("Team")
	for _, object in ipairs(env:GetChildren()) do
		if object:IsA("Model") and object.Name:find("Forcefield", 1, true) and object:FindFirstChild("FullSphere") then
			local isAllyColor = object.FullSphere.Color == ALLY_FORCEFIELD_COLOR
			local isMyTeam = myTeam and object.Name:find(tostring(myTeam), 1, true) ~= nil
			if not isAllyColor and not isMyTeam then
				object:Destroy()
			end
		end
	end
end

local function updateMouseHitSpot()
	if not Config.SilentAim or not closestTarget then
		return
	end
	local position = predictedPosition(closestTarget)
	if position then
		_G.MouseHitSpot = position
	end
end

local function cframeValuePosition(cframeValue)
	if not cframeValue or not cframeValue:IsA("CFrameValue") or not oldIndex then
		return nil
	end
	local ok, cf = pcall(oldIndex, cframeValue, "Value")
	if ok and typeof(cf) == "CFrame" then
		return cf.Position
	end
	return nil
end

local function ensureIndexHook()
	if installedIndexHook or not hasHookMetamethod() or not Config.SilentAim then
		return
	end
	installedIndexHook = true
	local ok, result = pcall(function()
		oldIndex = hookmetamethod(game, "__index", function(self, index)
			if typeof(self) == "Instance" and self:IsA("CFrameValue") then
				if index == "p" or index == "Position" then
					local position = cframeValuePosition(self)
					if position then
						return position
					end
				end
			end
			if Config.SilentAim and closestTarget and index == "LookVector" and inHitchance() and inFireCallstack(8) then
				local position = predictedPosition(closestTarget)
				if position and typeof(self) == "CFrame" then
					local direction = position - self.Position
					if direction.Magnitude > 0.01 then
						return direction.Unit
					end
				end
			end
			if oldIndex then
				return oldIndex(self, index)
			end
			return nil
		end)
	end)
	if not ok then
		installedIndexHook = false
		warn("[GunfightArena] hook failed:", result)
	end
end

local fovCircle = nil
local function ensureFovCircle()
	if fovCircle or not hasDrawing() then
		return
	end
	fovCircle = trackDrawing(Drawing.new("Circle"))
	fovCircle.Thickness = 2
	fovCircle.Transparency = 1
	fovCircle.Filled = false
	fovCircle.Color = Color3.fromRGB(255, 255, 255)
end

local function updateFovCircle()
	ensureFovCircle()
	if not fovCircle then
		return
	end
	fovCircle.Position = Camera.ViewportSize / 2
	fovCircle.Radius = Config.FOVRadius
	fovCircle.Visible = Config.FOVCircle
end

local function makeBoxEsp()
	if not hasDrawing() then
		return nil
	end
	local esp = {
		Box = trackDrawing(Drawing.new("Square")),
		Name = trackDrawing(Drawing.new("Text")),
		Distance = trackDrawing(Drawing.new("Text")),
	}
	esp.Box.Thickness = 2
	esp.Box.Color = Color3.fromRGB(103, 89, 179)
	esp.Box.Filled = false
	esp.Box.Visible = false
	for _, text in ipairs({ esp.Name, esp.Distance }) do
		text.Size = 16
		text.Color = Color3.new(1, 1, 1)
		text.Outline = true
		text.Center = true
		text.Visible = false
	end
	return esp
end

local function clearBoxEsp(character)
	local esp = espCache[character]
	if esp then
		removeDrawing(esp.Box)
		removeDrawing(esp.Name)
		removeDrawing(esp.Distance)
		espCache[character] = nil
	end
end

local function makeHealthEsp()
	if not hasDrawing() then
		return nil
	end
	local health = {
		Back = trackDrawing(Drawing.new("Square")),
		Bar = trackDrawing(Drawing.new("Square")),
		Text = trackDrawing(Drawing.new("Text")),
	}
	health.Back.Size = vector2(50, 5)
	health.Back.Color = Color3.new(0, 0, 0)
	health.Back.Filled = true
	health.Back.Transparency = 0.5
	health.Back.Visible = false
	health.Bar.Size = vector2(50, 5)
	health.Bar.Color = Color3.new(0, 1, 0)
	health.Bar.Filled = true
	health.Bar.Visible = false
	health.Text.Size = 12
	health.Text.Color = Color3.new(1, 1, 1)
	health.Text.Outline = true
	health.Text.Center = true
	health.Text.Visible = false
	return health
end

local function clearHealthEsp(character)
	local health = healthCache[character]
	if health then
		removeDrawing(health.Back)
		removeDrawing(health.Bar)
		removeDrawing(health.Text)
		healthCache[character] = nil
	end
end

local function makeTracer()
	if not hasDrawing() then
		return nil
	end
	local tracer = trackDrawing(Drawing.new("Line"))
	tracer.Thickness = 2
	tracer.Color = Color3.fromRGB(103, 89, 179)
	tracer.Visible = false
	return tracer
end

local function clearTracer(character)
	removeDrawing(tracerCache[character])
	tracerCache[character] = nil
end

local function clearChams(character)
	local highlight = chamsCache[character]
	if highlight then
		highlight:Destroy()
		chamsCache[character] = nil
	end
end

local function hideBoxEsp(esp)
	esp.Box.Visible = false
	esp.Name.Visible = false
	esp.Distance.Visible = false
end

local function updateVisuals()
	local anyBox = Config.BoxESP or Config.NameESP or Config.DistanceESP
	if not (anyBox or Config.HealthESP or Config.TracerESP or Config.Chams) then
		for character in pairs(espCache) do
			clearBoxEsp(character)
		end
		for character in pairs(healthCache) do
			clearHealthEsp(character)
		end
		for character in pairs(tracerCache) do
			clearTracer(character)
		end
		for character in pairs(chamsCache) do
			clearChams(character)
		end
		return
	end

	local localRoot = getCharacterRoot(LocalPlayer.Character)
	if not localRoot then
		return
	end

	iterCharacters(function(character)
		local humanoid = getHumanoid(character)
		local root = getCharacterRoot(character)
		if not isValidTarget(character) or not root then
			clearBoxEsp(character)
			clearHealthEsp(character)
			clearTracer(character)
			clearChams(character)
			return
		end

		local distance = (localRoot.Position - root.Position).Magnitude
		if distance > Config.ESPDistance then
			clearBoxEsp(character)
			clearHealthEsp(character)
			clearTracer(character)
			clearChams(character)
			return
		end

		local rootPos, onScreen = Camera:WorldToViewportPoint(root.Position)
		local head = character:FindFirstChild("Head")
		local headPos = head and Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 1, 0)) or rootPos
		local bottomPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))

		if anyBox then
			if not espCache[character] then
				espCache[character] = makeBoxEsp()
			end
			local esp = espCache[character]
			if esp and onScreen then
				local height = math.abs(headPos.Y - bottomPos.Y)
				local width = height * 0.5
				local center = vector2(rootPos.X, (headPos.Y + bottomPos.Y) / 2)
				esp.Box.Size = vector2(width, height)
				esp.Box.Position = center - vector2(width / 2, height / 2)
				esp.Box.Visible = Config.BoxESP
				esp.Name.Text = (Players:GetPlayerFromCharacter(character) or character).Name
				esp.Name.Position = vector2(rootPos.X, headPos.Y - 20)
				esp.Name.Visible = Config.NameESP
				esp.Distance.Text = tostring(math.floor(distance)) .. " studs"
				esp.Distance.Position = vector2(rootPos.X, bottomPos.Y + 5)
				esp.Distance.Visible = Config.DistanceESP
			elseif esp then
				hideBoxEsp(esp)
			end
		else
			clearBoxEsp(character)
		end

		if Config.HealthESP then
			if not healthCache[character] then
				healthCache[character] = makeHealthEsp()
			end
			local health = healthCache[character]
			if health and onScreen and humanoid then
				local healthPercent = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
				health.Back.Position = vector2(rootPos.X - 25, bottomPos.Y + 22)
				health.Bar.Position = health.Back.Position
				health.Bar.Size = vector2(50 * healthPercent, 5)
				health.Text.Text = tostring(math.floor(humanoid.Health)) .. " HP"
				health.Text.Position = vector2(rootPos.X, bottomPos.Y + 30)
				health.Back.Visible = true
				health.Bar.Visible = true
				health.Text.Visible = true
			elseif health then
				health.Back.Visible = false
				health.Bar.Visible = false
				health.Text.Visible = false
			end
		else
			clearHealthEsp(character)
		end

		if Config.TracerESP then
			if not tracerCache[character] then
				tracerCache[character] = makeTracer()
			end
			local tracer = tracerCache[character]
			if tracer and onScreen then
				local from = Camera.ViewportSize / 2
				if Config.TracerOrigin == "Bottom Screen" then
					from = vector2(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
				elseif Config.TracerOrigin == "Top Screen" then
					from = vector2(Camera.ViewportSize.X / 2, 0)
				elseif Config.TracerOrigin == "Cursor" then
					from = UserInputService:GetMouseLocation()
				end
				tracer.From = from
				tracer.To = vector2(rootPos.X, rootPos.Y)
				tracer.Visible = true
			elseif tracer then
				tracer.Visible = false
			end
		else
			clearTracer(character)
		end

		if Config.Chams then
			if not chamsCache[character] then
				local highlight = Instance.new("Highlight")
				highlight.FillColor = Color3.fromRGB(255, 0, 0)
				highlight.OutlineColor = Color3.new(1, 1, 1)
				highlight.FillTransparency = 0.5
				highlight.OutlineTransparency = 0
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				highlight.Adornee = character
				highlight.Parent = character
				chamsCache[character] = highlight
			end
		else
			clearChams(character)
		end
	end)
end

local function updateAim()
	if Config.SilentAim then
		ensureIndexHook()
		closestTarget = getClosestTarget(Config.FOVRadius)
		updateMouseHitSpot()
	else
		closestTarget = nil
	end
end

local function getNames(folderName)
	local results = {}
	local folder = ReplicatedStorage:FindFirstChild(folderName)
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			table.insert(results, child.Name)
		end
	end
	table.sort(results)
	if #results == 0 then
		table.insert(results, "None")
	end
	return results
end

local weaponOptions = getNames("Weapons")
local camoOptions = getNames("Camos")
Config.Primary = weaponOptions[1]
Config.Secondary = weaponOptions[1]
Config.PrimaryCamo = camoOptions[1]
Config.SecondaryCamo = camoOptions[1]

local function resetCharacter()
	local humanoid = getHumanoid(LocalPlayer.Character)
	if humanoid then
		humanoid.Health = 0
	end
end

local function applyAttribute(name, value)
	if value and value ~= "" and value ~= "None" then
		LocalPlayer:SetAttribute(name, value)
		resetCharacter()
		notify(name .. " set to " .. value .. ". Rejoin if it does not apply.", "Loadout", 5)
	end
end

local function cleanup()
	disconnectAll()
	vortexEnv = nil
	lastRestockAt = 0
	if fovCircle then
		removeDrawing(fovCircle)
		fovCircle = nil
	end
	for character in pairs(espCache) do
		clearBoxEsp(character)
	end
	for character in pairs(healthCache) do
		clearHealthEsp(character)
	end
	for character in pairs(tracerCache) do
		clearTracer(character)
	end
	for character in pairs(chamsCache) do
		clearChams(character)
	end
	for _, object in ipairs(drawingObjects) do
		removeDrawing(object)
	end
	table.clear(drawingObjects)
end

local genv = getGenv()
if typeof(genv.__GunfightArenaUnload) == "function" then
	pcall(genv.__GunfightArenaUnload)
end
genv.__GunfightArenaUnload = cleanup

if not hasDrawing() then
	notify("Drawing API missing — ESP and FOV circle will be unavailable.", "Compatibility", 6)
end
if not hasHookMetamethod() then
	notify("hookmetamethod missing — silent aim is unavailable.", "Compatibility", 6)
end

UILib.create({
	title = "GUNFIGHT ARENA",
	config = Config,
	pages = {
		{
			label = "Rage",
			sections = {
				{
					title = "AIM",
					items = {
						{ type = "toggle", key = "SilentAim", label = "Silent Aim", hud = "Silent Aim" },
						{ type = "toggle", key = "Prediction", label = "Prediction", hud = "Prediction" },
						{ type = "toggle", key = "FOVCircle", label = "FOV Circle", hud = "FOV Circle" },
						{ type = "select", key = "HitPart", label = "Hit Part", options = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" } },
						{ type = "slider", key = "FOVRadius", label = "FOV Radius", min = 10, max = 1000, step = 10 },
						{ type = "slider", key = "Hitchance", label = "Hitchance", min = 0, max = 100, step = 5 },
						{ type = "slider", key = "ProjectileSpeed", label = "Projectile Speed", min = 100, max = 3000, step = 100 },
					},
				},
			},
		},
		{
			label = "Visual",
			sections = {
				{
					title = "ESP",
					items = {
						{ type = "toggle", key = "BoxESP", label = "Box ESP", hud = "Box ESP" },
						{ type = "toggle", key = "NameESP", label = "Name ESP", hud = "Name ESP" },
						{ type = "toggle", key = "DistanceESP", label = "Distance ESP", hud = "Distance ESP" },
						{ type = "toggle", key = "HealthESP", label = "Health ESP", hud = "Health ESP" },
						{ type = "toggle", key = "TracerESP", label = "Tracer ESP", hud = "Tracer ESP" },
						{ type = "toggle", key = "Chams", label = "Chams", hud = "Chams" },
						{ type = "toggle", key = "TeamCheck", label = "Team Check", hud = "Team Check" },
						{ type = "select", key = "TracerOrigin", label = "Tracer Origin", options = { "Bottom Screen", "Cursor", "Top Screen" } },
						{ type = "slider", key = "ESPDistance", label = "ESP Distance", min = 50, max = 1500, step = 25 },
					},
				},
			},
		},
		{
			label = "Exploits",
			sections = {
				{
					title = "COMBAT",
					items = {
						{ type = "toggle", key = "NoRecoil", label = "No Recoil", hud = "No Recoil" },
						{ type = "toggle", key = "StableAim", label = "Stable Aim", hud = "Stable Aim" },
						{ type = "toggle", key = "InfiniteAmmo", label = "Infinite Ammo", hud = "Infinite Ammo" },
						{ type = "toggle", key = "RemoveForcefields", label = "No Forcefields", hud = "No Forcefields" },
						{ type = "button", id = "applyRespawn", label = "Respawn", onClick = resetCharacter },
					},
				},
			},
		},
		{
			label = "Weapons",
			sections = {
				{
					title = "PRIMARY",
					items = {
						{ type = "select", key = "Primary", label = "Weapon", options = weaponOptions },
						{ type = "select", key = "PrimaryCamo", label = "Camo", options = camoOptions },
						{ type = "button", id = "applyPrimary", label = "Apply Primary", onClick = function()
							applyAttribute("Primary", Config.Primary)
						end },
						{ type = "button", id = "applyPrimaryCamo", label = "Apply Primary Camo", onClick = function()
							applyAttribute("PrimaryCamo", Config.PrimaryCamo)
						end },
					},
				},
				{
					title = "SECONDARY",
					items = {
						{ type = "select", key = "Secondary", label = "Weapon", options = weaponOptions },
						{ type = "select", key = "SecondaryCamo", label = "Camo", options = camoOptions },
						{ type = "button", id = "applySecondary", label = "Apply Secondary", onClick = function()
							applyAttribute("Secondary", Config.Secondary)
						end },
						{ type = "button", id = "applySecondaryCamo", label = "Apply Secondary Camo", onClick = function()
							applyAttribute("SecondaryCamo", Config.SecondaryCamo)
						end },
					},
				},
			},
		},
		{
			label = "Client",
			sections = {
				{
					title = "MENU",
					items = {
						{ type = "toggle", key = "ShowHUD", label = "Module HUD", hud = nil },
						{ type = "button", id = "cleanup", label = "Unload Features", onClick = cleanup },
					},
				},
			},
		},
	},
	hud = { showKey = "ShowHUD" },
	onToggle = function(key, value)
		if (key == "NoRecoil" or key == "StableAim") and value then
			applyCombatModifiers()
		elseif key == "SilentAim" and value then
			ensureIndexHook()
			if not hasHookMetamethod() then
				notify("hookmetamethod missing — silent aim needs it for first-person shots.", "Compatibility", 6)
			end
		elseif key == "InfiniteAmmo" then
			if value then
				maintainStoredAmmo()
				if not hasGetsenv() then
					notify("getsenv missing — restock fallback disabled; reserve ammo is still raised directly.", "Compatibility", 6)
				end
			else
				vortexEnv = nil
			end
		end
	end,
})

table.insert(sessionConns, RunService.RenderStepped:Connect(function()
	Camera = workspace.CurrentCamera
	updateFovCircle()
	updateAim()
	applyCombatModifiers()
	restockAmmo()
	removeEnemyForcefields()
	updateVisuals()
end))

table.insert(sessionConns, Players.PlayerRemoving:Connect(function(player)
	local character = player.Character
	if character then
		clearBoxEsp(character)
		clearHealthEsp(character)
		clearTracer(character)
		clearChams(character)
	end
end))

print("[MicroHub] Gunfight Arena loaded")
