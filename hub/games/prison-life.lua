--[[
	Prison Life — placeIds 155615604, 4669040
	https://www.roblox.com/games/155615604/Prison-Life
	Reference: VapeV4 games/155615604.lua
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local GAME_BUILD = "2-vape-ref"
warn("[PrisonLife] build", GAME_BUILD)

local TeamGuards = Teams:FindFirstChild("Guards")
local TeamInmates = Teams:FindFirstChild("Inmates")
local TeamCriminals = Teams:FindFirstChild("Criminals")
local TeamNeutral = Teams:FindFirstChild("Neutral")

local HEAL_ITEMS = { Breakfast = true, Lunch = true, Dinner = true }

local TEAM_COLOR = {
	Inmate = "Bright orange",
	Guard = "Bright blue",
	Neutral = "Medium stone grey",
}

local Config = {
	WalkSpeed = 24,
	JumpPower = 60,
	SpeedBoost = false,
	NoJumpCooldown = false,
	AutoReset = false,
	Killaura = false,
	KillauraRange = 12,
	AutoArrest = false,
	AutoArrestRange = 8,
	ArrestHandCheck = true,
	ArrestInmates = true,
	ArrestCriminals = true,
	GunMods = false,
	GunNoSpread = true,
	GunFireRate = 100,
	GunAutomatic = false,
	SilentAim = false,
	SilentAimFOV = 150,
	SilentAimHead = true,
	SilentAimTeamCheck = true,
	AutoReload = false,
	AutoHeal = false,
	AutoPickup = false,
	AntiRiotShield = false,
	VehicleSpeed = false,
	VehicleSpeedValue = 140,
	C4ESP = true,
	ESP = true,
	ESPAllies = true,
	ESPSnaplines = false,
	ESPStatusTags = true,
	ShowHUD = true,
	ESPEnemyColor = Color3.fromRGB(255, 96, 72),
	ESPAllyColor = Color3.fromRGB(72, 168, 255),
	ESPNeutralColor = Color3.fromRGB(180, 180, 180),
	ESPHostileColor = Color3.fromRGB(255, 56, 56),
}

local UILib = shared.__MicroHubUILib
if typeof(UILib) ~= "table" or typeof(UILib.create) ~= "function" then
	error("MicroHub UI library not loaded — run hub/loader.lua", 0)
end

local canDraw = typeof(Drawing) == "table" and typeof(Drawing.new) == "function"
local canHook = typeof(hookfunction) == "function"
	and typeof(getconnections) == "function"
	and typeof(debug) == "table"
	and typeof(debug.getupvalue) == "function"

local WHITE = Color3.fromRGB(248, 250, 252)
local DIM = Color3.fromRGB(148, 156, 168)
local BAR_BG = Color3.fromRGB(10, 12, 16)
local BACKDROP = Color3.fromRGB(8, 10, 14)

local esp: { [Model]: any } = {}
local c4Highlights: { [Instance]: Highlight } = {}
local c4Folder = Instance.new("Folder")
c4Folder.Name = "MicroHubPL_C4"
c4Folder.Parent = workspace

local connections: { RBXScriptConnection } = {}
local loops: { thread } = {}
local arrestCooldown = 0
local jumpConn: RBXScriptConnection? = nil

local gun = {
	Shoot = nil,
	Reload = nil,
	Bullet = nil,
	Equip = nil,
}
local gunDataBackup: { [string]: any }? = nil
local gunDataRef: any = nil
local hookedShoot: any = nil
local hookedBullet: any = nil
local hookedEquip: any = nil
local oldShootFn: any = nil
local oldBulletFn: any = nil
local oldEquipFn: any = nil

local function stopLoop(threadRef: thread?)
	if threadRef then
		pcall(task.cancel, threadRef)
	end
end

local function startLoop(fn: () -> ())
	local threadRef = task.spawn(function()
		while true do
			fn()
			task.wait(0.05)
		end
	end)
	table.insert(loops, threadRef)
	return threadRef
end

local function getRemotes()
	return ReplicatedStorage:FindFirstChild("Remotes")
end

local function getMeleeRemote()
	return ReplicatedStorage:FindFirstChild("meleeEvent")
end

local function switchTeam(colorName: string)
	local remote = workspace:FindFirstChild("Remote")
	if not remote then
		return
	end
	local teamEvent = remote:FindFirstChild("TeamEvent")
	if teamEvent then
		pcall(function()
			teamEvent:FireServer(colorName)
		end)
	end
	local loadchar = remote:FindFirstChild("loadchar")
	if loadchar then
		pcall(function()
			loadchar:InvokeServer(LocalPlayer.Name)
		end)
	end
end

local function getCharacter(player: Player?): Model?
	return player and player.Character
end

local function isAlive(char: Model?): (boolean, Humanoid?, BasePart?)
	if not char then
		return false
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
	if hum and root and hum.Health > 0 then
		return true, hum, root
	end
	return false, hum, root
end

local function isVulnerable(player: Player, char: Model, attackCheck: boolean): boolean
	local alive = isAlive(char)
	if not alive then
		return false
	end
	if char:FindFirstChildWhichIsA("ForceField") then
		return false
	end
	if char:GetAttribute("Arrested") then
		return false
	end

	if attackCheck and LocalPlayer.Team == TeamGuards and player.Team == TeamInmates then
		if not char:GetAttribute("Hostile") then
			return false
		end
	end

	if player.Team == TeamInmates then
		return char:GetAttribute("Trespassing") == true or char:GetAttribute("Hostile") == true
	end
	return true
end

local function sameTeam(a: Player, b: Player): boolean
	return a.Team ~= nil and b.Team ~= nil and a.Team == b.Team
end

local function getRelation(player: Player, char: Model): string
	if player == LocalPlayer then
		return "Ally"
	end
	if sameTeam(player, LocalPlayer) then
		return "Ally"
	end
	if player.Team == TeamNeutral then
		return "Neutral"
	end
	if player.Team == TeamInmates and (char:GetAttribute("Hostile") or char:GetAttribute("Trespassing")) then
		return "Hostile"
	end
	return "Enemy"
end

local function relationColor(relation: string): Color3
	if relation == "Ally" then
		return Config.ESPAllyColor
	end
	if relation == "Neutral" then
		return Config.ESPNeutralColor
	end
	if relation == "Hostile" then
		return Config.ESPHostileColor
	end
	return Config.ESPEnemyColor
end

local function statusSuffix(char: Model): string
	if not Config.ESPStatusTags then
		return ""
	end
	if char:GetAttribute("Arrested") then
		return " [Arrested]"
	end
	if char:GetAttribute("Tased") then
		return " [Tased]"
	end
	if char:GetAttribute("Hostile") then
		return " [Hostile]"
	end
	if char:GetAttribute("Trespassing") then
		return " [Trespassing]"
	end
	return ""
end

local function getEntitiesInRange(range: number, attackCheck: boolean): { { player: Player, char: Model, root: BasePart } }
	local localChar = LocalPlayer.Character
	local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
	if not localRoot then
		return {}
	end

	local list = {}
	for _, player in Players:GetPlayers() do
		if player == LocalPlayer then
			continue
		end
		local char = getCharacter(player)
		if not char then
			continue
		end
		local alive, _, root = isAlive(char)
		if alive and root and isVulnerable(player, char, attackCheck) then
			if (root.Position - localRoot.Position).Magnitude <= range then
				table.insert(list, { player = player, char = char, root = root })
			end
		end
	end

	table.sort(list, function(a, b)
		return (a.root.Position - localRoot.Position).Magnitude < (b.root.Position - localRoot.Position).Magnitude
	end)
	return list
end

local function giveGiverWeapon(weaponName: string)
	local items = workspace:FindFirstChild("Prison_ITEMS")
	local giver = items and items:FindFirstChild("giver")
	local weapon = giver and giver:FindFirstChild(weaponName)
	local pickup = weapon and weapon:FindFirstChild("ITEMPICKUP")
	if not pickup then
		return
	end

	local remote = workspace:FindFirstChild("Remote")
	local handler = remote and remote:FindFirstChild("ItemHandler")
	if handler then
		pcall(function()
			handler:InvokeServer(pickup)
		end)
		return
	end

	local remotes = getRemotes()
	local giverPressed = remotes and remotes:FindFirstChild("GiverPressed")
	if giverPressed and weapon then
		pcall(function()
			giverPressed:FireServer(weapon)
		end)
	end
end

local function applyMovement()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if Config.SpeedBoost then
		hum.WalkSpeed = Config.WalkSpeed
		hum.JumpPower = Config.JumpPower
	else
		hum.WalkSpeed = 16
		hum.JumpPower = 50
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
	else
		if jumpConn then
			jumpConn:Enable()
			jumpConn = nil
		end
	end
end

local function resolveGunController(): boolean
	if gun.Bullet then
		return true
	end
	if not canHook then
		return false
	end

	local gui = LocalPlayer.PlayerGui:FindFirstChild("Home")
	gui = gui and gui:FindFirstChild("hud")
	gui = gui and gui:FindFirstChild("ActionArea")
	if not gui then
		return false
	end

	for _, conn in getconnections(gui.InputBegan) do
		if conn.Function then
			gun.Shoot = debug.getupvalue(conn.Function, 2)
			if gun.Shoot then
				gun.Reload = debug.getupvalue(gun.Shoot, 2)
				gun.Bullet = debug.getupvalue(gun.Shoot, 16)
			end
			break
		end
	end

	for _, conn in getconnections(LocalPlayer.CharacterAdded) do
		if conn.Function and debug.info(conn.Function, "s"):find("GunController", 1, true) then
			gun.Equip = debug.getupvalue(conn.Function, 3)
			break
		end
	end

	return gun.Bullet ~= nil
end

local function getGunData()
	if not gun.Shoot then
		resolveGunController()
	end
	if not gun.Shoot then
		return nil
	end
	return debug.getupvalue(gun.Shoot, 10)
end

local function modifyGunData()
	local data = getGunData()
	if not data or not Config.GunMods then
		return
	end
	if gunDataRef ~= data then
		gunDataRef = data
		gunDataBackup = table.clone(data)
	end
	if not gunDataBackup then
		return
	end

	data.SpreadRadius = Config.GunNoSpread and 0 or gunDataBackup.SpreadRadius
	data.FireRate = (gunDataBackup.FireRate or 0) * (Config.GunFireRate / 100)
	data.AutoFire = Config.GunAutomatic or gunDataBackup.AutoFire
end

local function restoreGunData()
	if gunDataRef and gunDataBackup then
		for key, value in gunDataBackup do
			gunDataRef[key] = value
		end
	end
	gunDataRef = nil
	gunDataBackup = nil
end

local function getSilentTarget(origin: Vector3, fov: number)
	local mousePos = UserInputService:GetMouseLocation()
	local bestPart: BasePart? = nil
	local bestDist = fov * fov
	local partName = if Config.SilentAimHead then "Head" else "HumanoidRootPart"

	for _, player in Players:GetPlayers() do
		if player == LocalPlayer then
			continue
		end
		if Config.SilentAimTeamCheck and sameTeam(player, LocalPlayer) then
			continue
		end
		local char = getCharacter(player)
		if not char or not isVulnerable(player, char, true) then
			continue
		end
		local part = char:FindFirstChild(partName) or char:FindFirstChild("HumanoidRootPart")
		if not part then
			continue
		end
		local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
		if not onScreen or screenPos.Z <= 0 then
			continue
		end
		local distSq = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude ^ 2
		if distSq < bestDist then
			bestDist = distSq
			bestPart = part
		end
	end

	return bestPart
end

local function installGunHooks()
	if not canHook or hookedBullet then
		return
	end
	if not resolveGunController() then
		return
	end

	if Config.GunMods and gun.Equip and not hookedEquip then
		oldEquipFn = gun.Equip
		hookedEquip = hookfunction(gun.Equip, function(...)
			local res = table.pack(oldEquipFn(...))
			modifyGunData()
			return table.unpack(res, 1, res.n)
		end)
	end

	if Config.AutoReload and gun.Shoot and not hookedShoot then
		oldShootFn = gun.Shoot
		hookedShoot = hookfunction(gun.Shoot, function(...)
			local res = table.pack(oldShootFn(...))
			local tool = debug.getupvalue(oldShootFn, 1)
			if tool and tool:GetAttribute("Local_CurrentAmmo") and tool:GetAttribute("Local_CurrentAmmo") <= 0 then
				task.spawn(gun.Reload)
			end
			return table.unpack(res, 1, res.n)
		end)
	end

	if Config.SilentAim and gun.Bullet and not hookedBullet then
		oldBulletFn = gun.Bullet
		hookedBullet = hookfunction(gun.Bullet, function(origin, direction, ...)
			local target = getSilentTarget(origin, Config.SilentAimFOV)
			if target then
				direction = target.Position
			end
			return oldBulletFn(origin, direction, ...)
		end)
	end
end

local function removeGunHooks()
	if hookedBullet and oldBulletFn and gun.Bullet then
		if typeof(restorefunction) == "function" then
			restorefunction(gun.Bullet)
		else
			hookfunction(gun.Bullet, oldBulletFn)
		end
		hookedBullet = nil
		oldBulletFn = nil
	end
	if hookedShoot and oldShootFn and gun.Shoot then
		if typeof(restorefunction) == "function" then
			restorefunction(gun.Shoot)
		else
			hookfunction(gun.Shoot, oldShootFn)
		end
		hookedShoot = nil
		oldShootFn = nil
	end
	if hookedEquip and oldEquipFn and gun.Equip then
		if typeof(restorefunction) == "function" then
			restorefunction(gun.Equip)
		else
			hookfunction(gun.Equip, oldEquipFn)
		end
		hookedEquip = nil
		oldEquipFn = nil
	end
	restoreGunData()
end

local function refreshGunFeatures()
	removeGunHooks()
	if Config.GunMods or Config.SilentAim or Config.AutoReload then
		installGunHooks()
	end
	if Config.GunMods then
		modifyGunData()
	end
end

local function runKillaura()
	if not Config.Killaura then
		return
	end
	local melee = getMeleeRemote()
	if not melee then
		return
	end
	for _, ent in getEntitiesInRange(Config.KillauraRange, true) do
		pcall(function()
			melee:FireServer(ent.player, 1, 1)
		end)
	end
end

local function runAutoArrest()
	if not Config.AutoArrest or os.clock() < arrestCooldown then
		return
	end
	local remotes = getRemotes()
	local arrest = remotes and remotes:FindFirstChild("ArrestPlayer")
	if not arrest then
		return
	end

	if Config.ArrestHandCheck then
		local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
		if not tool or tool.Name ~= "Handcuffs" then
			return
		end
	end

	for _, ent in getEntitiesInRange(Config.AutoArrestRange, false) do
		local player = ent.player
		local char = ent.char
		if char:GetAttribute("Arrested") then
			continue
		end
		if player.Team == TeamInmates and not Config.ArrestInmates then
			continue
		end
		if player.Team == TeamCriminals and not Config.ArrestCriminals then
			continue
		end
		if player.Team == TeamInmates and char:GetAttribute("Hostile") and not char:GetAttribute("Tased") then
			continue
		end

		local ok, arrested = pcall(function()
			return arrest:InvokeServer(player, 1)
		end)
		if ok and arrested then
			arrestCooldown = os.clock() + 7
			break
		end
	end
end

local function runAutoHeal()
	if not Config.AutoHeal then
		return
	end
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health > 85 then
		return
	end

	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	local remotes = getRemotes()
	local eat = remotes and remotes:FindFirstChild("EatFood")
	if not backpack or not eat then
		return
	end

	for _, tool in backpack:GetChildren() do
		if tool:IsA("Tool") and HEAL_ITEMS[tool.Name] then
			if (os.clock() - (tool:GetAttribute("Client_LastConsumedAt") or 0)) < 3 then
				continue
			end
			local equipped = char:FindFirstChildWhichIsA("Tool")
			if equipped then
				equipped.Parent = backpack
			end
			tool.Parent = char
			tool:SetAttribute("Quantity", (tool:GetAttribute("Quantity") or 1) - 1)
			tool:SetAttribute("Client_LastConsumedAt", os.clock())
			pcall(function()
				eat:FireServer()
			end)
			tool.Parent = backpack
			if equipped then
				equipped.Parent = char
			end
			break
		end
	end
end

local pickupItems: { { Instance, boolean } } = {}

local function trackPickup(obj: Instance)
	if obj:IsA("Model") and obj.Name ~= "Model" and obj:GetAttribute("ToolName") then
		table.insert(pickupItems, { obj, obj.Name == "TouchGiver" })
	end
end

local function runAutoPickup()
	if not Config.AutoPickup then
		return
	end
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	local remotes = getRemotes()
	local giverPressed = remotes and remotes:FindFirstChild("GiverPressed")
	if not root or not backpack or not giverPressed then
		return
	end

	for _, entry in pickupItems do
		local model, _touchGiver = entry[1], entry[2]
		if not model.Parent or not model.PrimaryPart then
			continue
		end
		if (model.PrimaryPart.Position - root.Position).Magnitude > 12 then
			continue
		end
		local toolName = model:GetAttribute("ToolName")
		if typeof(toolName) == "string" and not backpack:FindFirstChild(toolName) then
			pcall(function()
				giverPressed:FireServer(model)
			end)
		end
	end
end

local function runAntiRiotShield()
	if not Config.AntiRiotShield then
		return
	end
	for _, player in Players:GetPlayers() do
		local char = getCharacter(player)
		local shield = char and char:FindFirstChild("RiotShieldPart")
		if shield and shield:IsA("BasePart") then
			shield.CanQuery = false
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

local function addC4Highlight(obj: Instance)
	if c4Highlights[obj] then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Adornee = obj
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(255, 72, 72)
	highlight.OutlineColor = Color3.fromRGB(255, 200, 80)
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0.2
	highlight.Parent = c4Folder
	c4Highlights[obj] = highlight
end

local function removeC4Highlight(obj: Instance)
	local highlight = c4Highlights[obj]
	if highlight then
		highlight:Destroy()
		c4Highlights[obj] = nil
	end
end

local function syncC4ESP()
	if not Config.C4ESP then
		for obj in pairs(c4Highlights) do
			removeC4Highlight(obj)
		end
		return
	end
	for _, obj in CollectionService:GetTagged("C4") do
		addC4Highlight(obj)
	end
end

-- ESP drawing (gunfight-arena style)

local espNeedsHide = false

local function hpColor(ratio: number): Color3
	if ratio > 0.55 then
		return Color3.fromRGB(72, 214, 128)
	end
	if ratio > 0.25 then
		return Color3.fromRGB(255, 196, 72)
	end
	return Color3.fromRGB(255, 86, 92)
end

local function formatDistance(studs: number): string
	if studs >= 1000 then
		return string.format("%.1fkm", studs / 1000)
	end
	return string.format("%dm", math.floor(studs))
end

local function box2d(char: Model, root: BasePart): (number?, number?, number?, number?)
	if not char.Parent or not root.Parent then
		return nil
	end
	local head = char:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local top, topOn = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.35, 0))
		local bot, botOn = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 2.6, 0))
		if top.Z > 0 and bot.Z > 0 and (topOn or botOn) then
			local height = math.max(12, bot.Y - top.Y)
			local width = height * 0.52
			return top.X - width * 0.5, top.Y, width, height
		end
	end
	local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
	if onScreen and pos.Z > 0 then
		local height = 56
		local width = height * 0.52
		return pos.X - width * 0.5, pos.Y - height * 0.5, width, height
	end
	return nil
end

local function mk(kind: string, props: { [string]: any })
	local d = Drawing.new(kind)
	for k, v in props do
		d[k] = v
	end
	d.Visible = false
	return d
end

local ESP_DRAWABLES = { "backdrop", "name", "hpOutline", "hpFill", "dist", "line" }

local function setVisible(entry: any, visible: boolean)
	for _, key in ESP_DRAWABLES do
		entry[key].Visible = visible and (key ~= "line" or Config.ESPSnaplines)
	end
	for _, corner in entry.corners do
		corner.Visible = visible
	end
end

local function hideAllESP()
	for _, entry in esp do
		setVisible(entry, false)
	end
end

local function destroyEntry(entry: any)
	for _, key in ESP_DRAWABLES do
		entry[key]:Remove()
	end
	for _, corner in entry.corners do
		corner:Remove()
	end
end

local function drawCorners(corners: { any }, x: number, y: number, w: number, h: number, color: Color3)
	local len = math.clamp(math.min(w, h) * 0.24, 7, 16)
	local right, bottom = x + w, y + h
	local segments = {
		{ Vector2.new(x, y), Vector2.new(x + len, y) },
		{ Vector2.new(x, y), Vector2.new(x, y + len) },
		{ Vector2.new(right, y), Vector2.new(right - len, y) },
		{ Vector2.new(right, y), Vector2.new(right, y + len) },
		{ Vector2.new(x, bottom), Vector2.new(x + len, bottom) },
		{ Vector2.new(x, bottom), Vector2.new(x, bottom - len) },
		{ Vector2.new(right, bottom), Vector2.new(right - len, bottom) },
		{ Vector2.new(right, bottom), Vector2.new(right, bottom - len) },
	}
	for i, pair in ipairs(segments) do
		corners[i].From = pair[1]
		corners[i].To = pair[2]
		corners[i].Color = color
		corners[i].Visible = true
	end
end

local function ensure(char: Model)
	local entry = esp[char]
	if entry then
		return entry
	end
	local corners = table.create(8)
	for _ = 1, 8 do
		table.insert(corners, mk("Line", { Thickness = 1.2, Transparency = 0.06 }))
	end
	entry = {
		backdrop = mk("Square", { Filled = true, Thickness = 0, Transparency = 0.84 }),
		corners = corners,
		name = mk("Text", { Size = 13, Center = true, Outline = true }),
		hpOutline = mk("Square", { Filled = true, Thickness = 0, Color = BAR_BG }),
		hpFill = mk("Square", { Filled = true, Thickness = 0 }),
		dist = mk("Text", { Size = 10, Center = true, Outline = true, Transparency = 0.12 }),
		line = mk("Line", { Thickness = 1, Transparency = 0.5 }),
	}
	esp[char] = entry
	return entry
end

local function drawTarget(player: Player, char: Model, hum: Humanoid, root: BasePart, camPos: Vector3, snapFrom: Vector2?)
	local rel = getRelation(player, char)
	if rel == "Ally" and not Config.ESPAllies then
		local entry = esp[char]
		if entry then
			setVisible(entry, false)
		end
		return
	end

	local x, y, w, h = box2d(char, root)
	if not x then
		local entry = esp[char]
		if entry then
			setVisible(entry, false)
		end
		return
	end

	local entry = ensure(char)
	local accent = relationColor(rel)
	local cx = x + w * 0.5
	local bottom = y + h
	local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
	local barW = math.max(38, w + 4)
	local barY = bottom + 6

	entry.backdrop.Position = Vector2.new(x - 2, y - 2)
	entry.backdrop.Size = Vector2.new(w + 4, h + 4)
	entry.backdrop.Color = BACKDROP
	entry.backdrop.Visible = true
	drawCorners(entry.corners, x, y, w, h, accent)

	entry.name.Position = Vector2.new(cx, y - 17)
	entry.name.Text = string.format("%s  %d%s", player.DisplayName, math.floor(hum.Health), statusSuffix(char))
	entry.name.Color = WHITE
	entry.name.Visible = true

	entry.hpOutline.Position = Vector2.new(cx - barW * 0.5, barY)
	entry.hpOutline.Size = Vector2.new(barW, 3)
	entry.hpOutline.Visible = true
	entry.hpFill.Position = Vector2.new(cx - barW * 0.5, barY)
	entry.hpFill.Size = Vector2.new(math.max(1, barW * ratio), 3)
	entry.hpFill.Color = hpColor(ratio)
	entry.hpFill.Visible = true

	entry.dist.Position = Vector2.new(cx, barY + 7)
	entry.dist.Text = formatDistance((root.Position - camPos).Magnitude)
	entry.dist.Color = DIM
	entry.dist.Visible = true

	if snapFrom then
		entry.line.From = snapFrom
		entry.line.To = Vector2.new(cx, bottom + 1)
		entry.line.Color = accent
	end
	entry.line.Visible = Config.ESPSnaplines and snapFrom ~= nil
end

local function updateESP()
	if not canDraw then
		return
	end
	if not Config.ESP then
		if espNeedsHide then
			hideAllESP()
			espNeedsHide = false
		end
		return
	end
	espNeedsHide = true

	local camPos = Camera.CFrame.Position
	local snapFrom = if Config.ESPSnaplines
		then Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y)
		else nil
	local seen: { [Model]: boolean } = {}

	for _, player in Players:GetPlayers() do
		if player == LocalPlayer then
			continue
		end
		local char = getCharacter(player)
		if not char then
			continue
		end
		local alive, hum, root = isAlive(char)
		if alive and hum and root then
			seen[char] = true
			drawTarget(player, char, hum, root, camPos, snapFrom)
		end
	end

	for char, entry in esp do
		if not seen[char] or not char.Parent then
			destroyEntry(entry)
			esp[char] = nil
		end
	end
end

local genv = if typeof(getgenv) == "function" then getgenv() else _G

genv.__PrisonLifeUnload = function()
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	for _, threadRef in loops do
		stopLoop(threadRef)
	end
	table.clear(loops)
	removeGunHooks()
	setNoJumpCooldown(false)
	for char, entry in esp do
		destroyEntry(entry)
		esp[char] = nil
	end
	for obj in pairs(c4Highlights) do
		removeC4Highlight(obj)
	end
	if c4Folder then
		c4Folder:Destroy()
	end
end

UILib.create({
	title = "PRISON LIFE",
	config = Config,
	pages = {
		{
			label = "Combat",
			sections = {
				{
					title = "MELEE",
					items = {
						{ type = "toggle", key = "Killaura", label = "Killaura", hud = "Killaura" },
						{ type = "slider", key = "KillauraRange", label = "Killaura Range", min = 1, max = 12, step = 1 },
					},
				},
				{
					title = "GUARD",
					items = {
						{ type = "toggle", key = "AutoArrest", label = "Auto Arrest", hud = "Auto Arrest" },
						{ type = "slider", key = "AutoArrestRange", label = "Arrest Range", min = 1, max = 8, step = 1 },
						{ type = "toggle", key = "ArrestHandCheck", label = "Handcuffs Only", hud = "Handcuffs" },
						{ type = "toggle", key = "ArrestInmates", label = "Arrest Inmates", hud = "Arrest Inmates" },
						{ type = "toggle", key = "ArrestCriminals", label = "Arrest Criminals", hud = "Arrest Criminals" },
					},
				},
				{
					title = "GUNS",
					items = {
						{ type = "toggle", key = "SilentAim", label = "Silent Aim", hud = "Silent Aim" },
						{ type = "slider", key = "SilentAimFOV", label = "Aim FOV", min = 20, max = 500, step = 10 },
						{ type = "toggle", key = "SilentAimHead", label = "Head Priority", hud = "Head Aim" },
						{ type = "toggle", key = "SilentAimTeamCheck", label = "Team Check", hud = "Team Check" },
						{ type = "toggle", key = "GunMods", label = "Gun Mods", hud = "Gun Mods" },
						{ type = "toggle", key = "GunNoSpread", label = "No Spread", hud = "No Spread" },
						{ type = "slider", key = "GunFireRate", label = "Fire Rate %", min = 1, max = 100, step = 1 },
						{ type = "toggle", key = "GunAutomatic", label = "Full Auto", hud = "Full Auto" },
						{ type = "toggle", key = "AutoReload", label = "Auto Reload", hud = "Auto Reload" },
						{ type = "hint", text = "Gun hooks need hookfunction + getconnections (executor)." },
					},
				},
			},
		},
		{
			label = "Player",
			sections = {
				{
					title = "MOVEMENT",
					items = {
						{ type = "toggle", key = "SpeedBoost", label = "Speed Boost", hud = "Speed Boost" },
						{ type = "slider", key = "WalkSpeed", label = "Walk Speed", min = 16, max = 200, step = 1 },
						{ type = "slider", key = "JumpPower", label = "Jump Power", min = 50, max = 200, step = 1 },
						{ type = "toggle", key = "NoJumpCooldown", label = "No Jump Cooldown", hud = "No Jump CD" },
						{ type = "toggle", key = "AutoReset", label = "Auto Reset (Criminal)", hud = "Auto Reset" },
					},
				},
				{
					title = "VEHICLE",
					items = {
						{ type = "toggle", key = "VehicleSpeed", label = "Vehicle Speed", hud = "Vehicle Speed" },
						{ type = "slider", key = "VehicleSpeedValue", label = "Max Speed", min = 80, max = 200, step = 5 },
					},
				},
			},
		},
		{
			label = "Team",
			sections = {
				{
					title = "SWITCH",
					items = {
						{ type = "button", label = "Inmate", onClick = function()
							switchTeam(TEAM_COLOR.Inmate)
						end },
						{ type = "button", label = "Guard", onClick = function()
							switchTeam(TEAM_COLOR.Guard)
						end },
						{ type = "button", label = "Neutral", onClick = function()
							switchTeam(TEAM_COLOR.Neutral)
						end },
						{ type = "hint", text = "Guard team caps at 8 players." },
					},
				},
			},
		},
		{
			label = "Items",
			sections = {
				{
					title = "WEAPONS",
					items = {
						{ type = "button", label = "M9", onClick = function()
							giveGiverWeapon("M9")
						end },
						{ type = "button", label = "Remington 870", onClick = function()
							giveGiverWeapon("Remington 870")
						end },
						{ type = "button", label = "AK-47", onClick = function()
							giveGiverWeapon("AK-47")
						end },
						{ type = "button", label = "Taser", onClick = function()
							giveGiverWeapon("Taser")
						end },
					},
				},
				{
					title = "AUTOMATION",
					items = {
						{ type = "toggle", key = "AutoHeal", label = "Auto Heal", hud = "Auto Heal" },
						{ type = "toggle", key = "AutoPickup", label = "Auto Pickup", hud = "Auto Pickup" },
						{ type = "toggle", key = "AntiRiotShield", label = "Anti Riot Shield", hud = "Anti Shield" },
						{ type = "toggle", key = "C4ESP", label = "C4 ESP", hud = "C4 ESP" },
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
						{ type = "toggle", key = "ESP", label = "ESP", hud = "ESP" },
						{ type = "toggle", key = "ESPAllies", label = "ESP Allies", hud = "ESP Allies" },
						{ type = "toggle", key = "ESPSnaplines", label = "Snaplines", hud = "Snaplines" },
						{ type = "toggle", key = "ESPStatusTags", label = "Status Tags", hud = "Status Tags" },
						{ type = "color", key = "ESPEnemyColor", label = "Enemy" },
						{ type = "color", key = "ESPAllyColor", label = "Ally" },
						{ type = "color", key = "ESPNeutralColor", label = "Neutral" },
						{ type = "color", key = "ESPHostileColor", label = "Hostile Inmate" },
						{ type = "toggle", key = "ShowHUD", label = "Module HUD", hud = nil },
					},
				},
			},
		},
	},
	hud = { showKey = "ShowHUD" },
	onToggle = function(key, value)
		if key == "SpeedBoost" or key == "NoJumpCooldown" then
			applyMovement()
			setNoJumpCooldown(Config.NoJumpCooldown)
		end
		if key == "SilentAim" or key == "GunMods" or key == "AutoReload" or key == "GunNoSpread" or key == "GunAutomatic" then
			refreshGunFeatures()
		end
		if key == "C4ESP" then
			syncC4ESP()
		end
	end,
	onChange = function(key)
		if key == "WalkSpeed" or key == "JumpPower" then
			applyMovement()
		end
		if key == "GunFireRate" then
			modifyGunData()
		end
	end,
})

table.insert(connections, LocalPlayer.CharacterAdded:Connect(function()
	task.defer(function()
		applyMovement()
		setNoJumpCooldown(Config.NoJumpCooldown)
		resolveGunController()
		refreshGunFeatures()
	end)
end))

table.insert(connections, LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
	if Config.AutoReset and LocalPlayer.Team == TeamCriminals then
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:ChangeState(Enum.HumanoidStateType.Dead)
		end
	end
end))

table.insert(connections, workspace.ChildAdded:Connect(trackPickup))
table.insert(connections, workspace.ChildRemoved:Connect(function(obj)
	for i, entry in pickupItems do
		if entry[1] == obj then
			table.remove(pickupItems, i)
			break
		end
	end
end))

table.insert(connections, CollectionService:GetInstanceAddedSignal("C4"):Connect(function(obj)
	if Config.C4ESP then
		addC4Highlight(obj)
	end
end))
table.insert(connections, CollectionService:GetInstanceRemovedSignal("C4"):Connect(removeC4Highlight))

for _, obj in workspace:GetChildren() do
	trackPickup(obj)
end
for _, obj in workspace:GetDescendants() do
	if obj:IsA("Model") and obj:FindFirstChild("TouchGiver") then
		trackPickup(obj)
	end
end
syncC4ESP()

startLoop(function()
	runKillaura()
	runAutoArrest()
	runAutoHeal()
	runAutoPickup()
	runAntiRiotShield()
end)

table.insert(
	connections,
	RunService.RenderStepped:Connect(function()
		applyMovement()
		modifyGunData()
		runVehicleSpeed()
		updateESP()
	end)
)

task.defer(function()
	resolveGunController()
	refreshGunFeatures()
end)

print(
	"[MicroHub] Prison Life",
	GAME_BUILD,
	"— Drawing:",
	canDraw,
	"— Hooks:",
	canHook,
	"— Team:",
	LocalPlayer.Team and LocalPlayer.Team.Name or "?"
)
