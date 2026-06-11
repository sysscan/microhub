local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local M = {}

function M.create(opts: {
	config: { [string]: any },
	localPlayer: Player,
	camera: Camera,
	util: { getCharacter: (Player?) -> Model?, isAlive: (Model?) -> (boolean, Humanoid?, BasePart?) },
	teams: { sameTeam: (Player, Player) -> boolean },
	teamGuards: Team?,
	teamInmates: Team?,
	spawnTimes: { [Model]: number },
	canHook: boolean,
	canDebug: boolean,
	canDraw: boolean,
	gunPriority: { [string]: number },
})
	local Config = opts.config
	local LocalPlayer = opts.localPlayer
	local Camera = opts.camera
	local getCharacter = opts.util.getCharacter
	local isAlive = opts.util.isAlive
	local sameTeam = opts.teams.sameTeam
	local TeamGuards = opts.teamGuards
	local TeamInmates = opts.teamInmates
	local spawnTimes = opts.spawnTimes
	local canHook = opts.canHook
	local canDebug = opts.canDebug
	local canDraw = opts.canDraw
	local GUN_PRIORITY = opts.gunPriority

	local aimRand = Random.new()
	local aimTimer, shootTimer, aimVec = os.clock(), os.clock(), Vector3.zero

	local gun = { Shoot = nil, Reload = nil, Bullet = nil, Equip = nil }
	local hookedShoot, hookedBullet = false, false
	local oldShootFn, oldBulletFn = nil, nil
	local autoFireCooldown = 0

	local bulletRayParams = RaycastParams.new()
	bulletRayParams.CollisionGroup = "ClientBullet"
	bulletRayParams.FilterType = Enum.RaycastFilterType.Exclude

	local overlapBulletParams = OverlapParams.new()
	overlapBulletParams.CollisionGroup = "ClientBullet"
	overlapBulletParams.FilterType = Enum.RaycastFilterType.Exclude

	local originRayParams = RaycastParams.new()
	originRayParams.CollisionGroup = "ClientBullet"
	originRayParams.FilterType = Enum.RaycastFilterType.Exclude

	local OriginScanner = { Cache = {} }
	OriginScanner.Ray = originRayParams

	local silentAimCircle: any = nil

	local GunTracers: any = nil
	pcall(function()
		GunTracers = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GunTracers"))
	end)

	local TracerHook = { Hooks = {} }
	local oldTracerBullet, oldTracerSniper = nil, nil

	local Spring = {}
	Spring.__index = Spring
	function Spring.new(props: { [string]: any }?)
		props = props or {}
		return setmetatable({
			Target = Vector3.zero,
			Position = Vector3.zero,
			Velocity = Vector3.zero,
			Mass = props.Mass or 5,
			Force = props.Force or 50,
			Damping = props.Damping or 4,
			Speed = props.Speed or 4,
		}, Spring)
	end
	function Spring:Update(dt: number): Vector3
		local iterations = math.max(1, math.round(dt / ((1 / 60) / 8)))
		local scaledDt = dt * self.Speed / iterations
		for _ = 1, iterations do
			local force = self.Target - self.Position
			local acceleration = (force * self.Force) / self.Mass - self.Velocity * self.Damping
			self.Velocity += acceleration * scaledDt
			self.Position += self.Velocity * scaledDt
		end
		return self.Position
	end

	local moveSpring = Spring.new()
	local aimSpring = Spring.new({ Speed = 15 })

	local function getMousePosition(): Vector2
		if UserInputService.TouchEnabled then
			return Camera.ViewportSize / 2
		end
		return UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
	end

	local function checkPoint(pos: Vector3, params: OverlapParams): boolean
		for _, part in workspace:GetPartBoundsInRadius(pos, 0, params) do
			if part.CanCollide and (part:GetClosestPointOnSurface(pos) - pos).Magnitude <= 0 then
				return false
			end
		end
		return true
	end

	local function updateOriginIgnore()
		local ignore = { LocalPlayer.Character }
		for _, player in Players:GetPlayers() do
			if player ~= LocalPlayer and player.Character then
				table.insert(ignore, player.Character)
			end
		end
		originRayParams.FilterDescendantsInstances = ignore
		overlapBulletParams.FilterDescendantsInstances = ignore
	end

	local ORIGIN_POSITIONS = {
		Vector3.new(0, 1, 0), Vector3.new(1, 0, 0), Vector3.new(0.7, -0.5, -0.5),
		Vector3.new(-0.1, -0.8, -0.8), Vector3.new(-0.8, -0.5, -0.5), Vector3.new(-1, 0, 0),
		Vector3.new(-0.8, 0.4, 0.4), Vector3.new(0, 0.7, 0.7), Vector3.new(0.7, 0.5, 0.5),
		Vector3.new(0.7, 0, -0.8), Vector3.new(-0.1, 0, -1), Vector3.new(0, 0, 1),
		Vector3.new(0, -1, 0),
	}

	function OriginScanner:Scan(origin: Vector3, target: Vector3, extra: Vector3?, part: Instance)
		if self.Cache[part] then
			return table.unpack(self.Cache[part])
		end
		local scanPositions = {}
		local hitboxPositions = {}
		local diff = CFrame.lookAt(origin * Vector3.new(1, 0, 1), target * Vector3.new(1, 0, 1)).LookVector
		if extra then
			if (origin - extra).Magnitude < 7.5 then
				table.insert(scanPositions, extra)
			else
				table.insert(hitboxPositions, target)
				for _, normal in Enum.NormalId:GetEnumItems() do
					local vec = Vector3.fromNormalId(normal)
					if (vec * Vector3.new(1, 0, 1)):Dot(-diff) > -0.5 then
						local pos = target + vec * 6
						if checkPoint(pos, overlapBulletParams) then
							table.insert(hitboxPositions, pos)
						end
					end
				end
			end
		end
		if #scanPositions <= 0 then
			for _, offset in ORIGIN_POSITIONS do
				if (offset * Vector3.new(1, 0, 1)):Dot(diff) > -0.5 then
					table.insert(scanPositions, origin + offset * 6)
				end
			end
		end
		if #hitboxPositions > 0 then
			for _, hitbox in hitboxPositions do
				for _, pos in scanPositions do
					if workspace:Raycast(hitbox, pos - hitbox, originRayParams) == nil and checkPoint(pos, overlapBulletParams) then
						self.Cache[part] = { pos, hitbox }
						return pos, hitbox
					end
				end
			end
		else
			for _, pos in scanPositions do
				if workspace:Raycast(target, pos - target, originRayParams) == nil and checkPoint(pos, overlapBulletParams) then
					self.Cache[part] = { pos }
					return pos
				end
			end
		end
	end

	local function wallcheck(origin: Vector3, position: Vector3, wallbang: Vector3?, part: Instance?): boolean
		local ray = workspace:Raycast(position, origin - position, originRayParams)
		if ray then
			return not wallbang or not OriginScanner:Scan(wallbang, position, ray.Position + ray.Normal * 0.01, part or workspace)
		end
		return false
	end

	local function getPlayerPart(player: Player, partName: string): BasePart?
		local char = getCharacter(player)
		if not char then
			return nil
		end
		local part = char:FindFirstChild(partName) or char:FindFirstChild("HumanoidRootPart")
		return if part and part:IsA("BasePart") then part else nil
	end

	local function isVulnerable(player: Player, char: Model, attackCheck: boolean): boolean
		local alive = isAlive(char)
		if not alive then
			return false
		end
		local spawnedAt = spawnTimes[char]
		if spawnedAt and spawnedAt > os.clock() then
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

	local function selectCombatTarget(settings: {
		origin: Vector3,
		range: number,
		rangePosition: number?,
		attackCheck: boolean,
		wallcheck: boolean?,
		wallbang: Vector3?,
		part: string,
		mode: string,
	}): (Player?, BasePart?)
		local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not localRoot or not localRoot:IsA("BasePart") then
			return nil, nil
		end
		local mousePos = getMousePosition()
		local origin = settings.origin
		local bestPlayer: Player? = nil
		local bestPart: BasePart? = nil
		local bestMag = math.huge

		for _, player in Players:GetPlayers() do
			if player == LocalPlayer then
				continue
			end
			if Config.SilentAimTeamCheck and sameTeam(player, LocalPlayer) then
				continue
			end
			local char = getCharacter(player)
			if not char or not isVulnerable(player, char, settings.attackCheck) then
				continue
			end
			local part = getPlayerPart(player, settings.part)
			if not part then
				continue
			end
			local worldMag = (part.Position - origin).Magnitude
			if settings.rangePosition and worldMag > settings.rangePosition then
				continue
			end
			local screenMag = math.huge
			if settings.mode == "Mouse" then
				local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
				if not onScreen or screenPos.Z <= 0 then
					continue
				end
				screenMag = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
				if screenMag > settings.range then
					continue
				end
			else
				local dist = (part.Position - localRoot.Position).Magnitude
				if dist > settings.range then
					continue
				end
				screenMag = dist
			end
			if settings.wallcheck and wallcheck(origin, part.Position, settings.wallbang, part) then
				continue
			end
			if screenMag < bestMag then
				bestMag = screenMag
				bestPlayer = player
				bestPart = part
			end
		end
		return bestPlayer, bestPart
	end

	local function getCombatTarget(origin: Vector3, gunData: any?): (Player?, BasePart?)
		if not Config.AutoFire and aimRand:NextNumber(0, 100) > Config.SilentAimHitChance then
			return nil, nil
		end
		local headChance = if Config.AutoFire then 100 else Config.SilentAimHeadshotChance
		local partName = if Config.SilentAimHead and aimRand:NextNumber(0, 100) < headChance then "Head" else "HumanoidRootPart"
		local limit = if gunData and gunData.Range then gunData.Range else 1000
		local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		return selectCombatTarget({
			origin = origin,
			range = if Config.SilentAimMode == "Position" then math.min(Config.SilentAimRange, limit) else Config.SilentAimRange,
			rangePosition = limit,
			attackCheck = not gunData or gunData.Behavior ~= "Taser",
			wallcheck = Config.SilentAimWallCheck,
			wallbang = if Config.SilentAimWallbang and localRoot and localRoot:IsA("BasePart") then localRoot.Position else nil,
			part = partName,
			mode = Config.SilentAimMode,
		})
	end

	local function getEntitiesInRange(range: number, mode: string)
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
			if not alive or not root then
				continue
			end
			if (root.Position - localRoot.Position).Magnitude > range then
				continue
			end
			if mode == "arrest" then
				if sameTeam(player, LocalPlayer) then
					continue
				end
				if char:GetAttribute("Arrested") then
					continue
				end
			elseif mode == "combat" then
				if not isVulnerable(player, char, true) then
					continue
				end
			elseif not isVulnerable(player, char, false) then
				continue
			end
			table.insert(list, { player = player, char = char, root = root })
		end
		table.sort(list, function(a, b)
			return (a.root.Position - localRoot.Position).Magnitude < (b.root.Position - localRoot.Position).Magnitude
		end)
		return list
	end

	local function tracerHookDispatch(...)
		if debug.info(3, "s") ~= "ReplicatedStorage.Scripts.Replication.ClientReplicator" then
			for _, hook in TracerHook.Hooks do
				if hook[2](...) then
					return true
				end
			end
		end
		return false
	end

	function TracerHook:Add(key: string, fn: any, priority: number?)
		if not canHook or not GunTracers then
			return
		end
		table.insert(self.Hooks, { key, fn, priority or 0 })
		table.sort(self.Hooks, function(a, b)
			return a[3] < b[3]
		end)
		if GunTracers and not oldTracerBullet then
			oldTracerBullet = hookfunction(GunTracers.createBullet, function(...)
				if tracerHookDispatch(...) then
					return
				end
				return oldTracerBullet(...)
			end)
			oldTracerSniper = hookfunction(GunTracers.createSniper, function(...)
				if tracerHookDispatch(...) then
					return
				end
				return oldTracerSniper(...)
			end)
		end
	end

	function TracerHook:Remove(key: string)
		for i, hook in self.Hooks do
			if hook[1] == key then
				table.remove(self.Hooks, i)
				break
			end
		end
		if #self.Hooks == 0 and GunTracers and oldTracerBullet then
			if typeof(restorefunction) == "function" then
				restorefunction(GunTracers.createBullet)
				restorefunction(GunTracers.createSniper)
			else
				hookfunction(GunTracers.createBullet, oldTracerBullet)
				hookfunction(GunTracers.createSniper, oldTracerSniper)
			end
			oldTracerBullet = nil
			oldTracerSniper = nil
		end
	end

	local function getBestBackupGun(): Tool?
		local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
		if not backpack then
			return nil
		end
		local items: { Tool } = {}
		for _, child in backpack:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("FireRate") and child.Name ~= "Taser" and child.Name ~= "M700" then
				if (child:GetAttribute("Local_ReloadSession") or 0) <= 0 then
					table.insert(items, child)
				end
			end
		end
		table.sort(items, function(a, b)
			return (GUN_PRIORITY[a.Name] or 100) < (GUN_PRIORITY[b.Name] or 100)
		end)
		return items[1]
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
		pcall(function()
			for _, conn in getconnections(gui.InputBegan) do
				if not conn.Function then
					continue
				end
				local ok1, shoot = pcall(debug.getupvalue, conn.Function, 2)
				if not ok1 or typeof(shoot) ~= "function" then
					continue
				end
				gun.Shoot = shoot
				local ok2, reload = pcall(debug.getupvalue, shoot, 2)
				if ok2 and typeof(reload) == "function" then
					gun.Reload = reload
				end
				local ok3, bullet = pcall(debug.getupvalue, shoot, 16)
				if ok3 and typeof(bullet) == "function" then
					gun.Bullet = bullet
				end
				if not gun.Bullet then
					for i = 3, 25 do
						local okN, val = pcall(debug.getupvalue, shoot, i)
						if not okN then
							break
						end
						if typeof(val) == "function" and val ~= shoot and val ~= gun.Reload then
							gun.Bullet = val
							break
						end
					end
				end
				break
			end
		end)
		pcall(function()
			for _, conn in getconnections(LocalPlayer.CharacterAdded) do
				if not conn.Function then
					continue
				end
				local src = debug.info(conn.Function, "s")
				if not src or not src:find("GunController", 1, true) then
					continue
				end
				local ok, equip = pcall(debug.getupvalue, conn.Function, 3)
				if ok and typeof(equip) == "function" then
					gun.Equip = equip
				end
				break
			end
		end)
		return gun.Bullet ~= nil
	end

	local function getGunData()
		if not gun.Shoot then
			resolveGunController()
		end
		if not gun.Shoot then
			return nil
		end
		local fn = oldShootFn or gun.Shoot
		local ok10, val10 = pcall(debug.getupvalue, fn, 10)
		if ok10 and typeof(val10) == "table" then
			return val10
		end
		for i = 1, 25 do
			if i == 10 then
				continue
			end
			local ok, val = pcall(debug.getupvalue, fn, i)
			if not ok then
				break
			end
			if typeof(val) == "table" and (val.Range or val.FireRate or val.SpreadRadius or val.AutoFire ~= nil) then
				return val
			end
		end
		return nil
	end

	local function hookSilentBullet(...)
		local args = table.pack(...)
		local origin = args[1]
		if typeof(origin) ~= "Vector3" then
			return oldBulletFn(table.unpack(args, 1, args.n))
		end
		local gunData = getGunData()
		local _, targetPart = getCombatTarget(origin, gunData)
		if not targetPart then
			return oldBulletFn(table.unpack(args, 1, args.n))
		end
		args[2] = targetPart.Position
		aimTimer = os.clock() + 0.3
		aimVec = args[2]
		if Config.SilentAimWallbang then
			local ignore = { LocalPlayer.Character }
			for _, player in Players:GetPlayers() do
				if player.Character then
					table.insert(ignore, player.Character)
				end
			end
			bulletRayParams.FilterDescendantsInstances = ignore
			local ray = workspace:Raycast(args[2], origin - args[2], bulletRayParams)
			if ray then
				local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				if localRoot and localRoot:IsA("BasePart") then
					local newOrigin, hitbox = OriginScanner:Scan(localRoot.Position, args[2], ray.Position + ray.Normal * 0.01, targetPart)
					if newOrigin and canDebug then
						pcall(function()
							for i = 1, 40 do
								if debug.getstack(3, i) == origin then
									debug.setstack(3, i, newOrigin)
								end
							end
						end)
						args[1] = newOrigin
						if hitbox then
							return targetPart, hitbox
						end
					end
				end
			end
		end
		return oldBulletFn(table.unpack(args, 1, args.n))
	end

	local function installGunHooks()
		if not canHook then
			return
		end
		resolveGunController()
		if not gun.Shoot and not gun.Equip and not gun.Bullet then
			return
		end
		if Config.AutoReload and gun.Shoot and not hookedShoot then
			oldShootFn = hookfunction(gun.Shoot, function(...)
				local res = table.pack(oldShootFn(...))
				local ok, tool = pcall(debug.getupvalue, oldShootFn, 1)
				if ok and typeof(tool) == "Instance" and tool:IsA("Tool") then
					if (tool:GetAttribute("Local_CurrentAmmo") or 0) <= 0 then
						task.spawn(gun.Reload)
						if Config.AutoReloadSwap then
							local swap = getBestBackupGun()
							if swap then
								tool.Parent = LocalPlayer.Backpack
								swap.Parent = LocalPlayer.Character
							end
						end
					end
				end
				return table.unpack(res, 1, res.n)
			end)
			hookedShoot = true
		end
		if Config.SilentAim and gun.Bullet and not hookedBullet then
			oldBulletFn = hookfunction(gun.Bullet, hookSilentBullet)
			hookedBullet = true
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
	end

	local function tryAutoFire()
		if not Config.AutoFire or not gun.Shoot then
			return
		end
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			return
		end
		local tool = char:FindFirstChildWhichIsA("Tool")
		if not tool or (tool:GetAttribute("Local_CurrentAmmo") or 0) <= 0 then
			return
		end
		if tool:GetAttribute("Local_IsShooting") then
			return
		end
		local data = getGunData()
		local head = char:FindFirstChild("Head")
		local origin = if head and head:IsA("BasePart") then head.Position else char:GetPivot().Position
		local _, target = getCombatTarget(origin, data)
		if not target then
			return
		end
		if data and data.Behavior == "Taser" and target.Parent and target.Parent:GetAttribute("Tased") then
			return
		end
		local input = {
			UserInputState = Enum.UserInputState.Begin,
			UserInputType = Enum.UserInputType.MouseButton1,
			Position = Vector3.zero,
		}
		task.spawn(gun.Shoot, input)
		input.UserInputState = Enum.UserInputState.End
	end

	local function refreshGunFeatures()
		removeGunHooks()
		if Config.SilentAim or Config.AutoReload then
			installGunHooks()
		end
	end

	local function applyInfiniteAmmo()
		if not Config.InfiniteAmmo then
			return
		end
		local function patchTool(tool: Instance)
			if not tool:IsA("Tool") or not tool:GetAttribute("FireRate") then
				return
			end
			local maxAmmo = tool:GetAttribute("MaxAmmo") or 30
			local currentAmmo = tool:GetAttribute("Local_CurrentAmmo") or 0
			if currentAmmo < maxAmmo then
				tool:SetAttribute("Local_CurrentAmmo", maxAmmo)
			end
			local storedAmmo = tool:GetAttribute("StoredAmmo")
			if storedAmmo ~= nil and storedAmmo < maxAmmo then
				tool:SetAttribute("StoredAmmo", maxAmmo * 10)
			end
		end
		local char = LocalPlayer.Character
		if char then
			for _, child in char:GetChildren() do
				patchTool(child)
			end
		end
		local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
		if backpack then
			for _, child in backpack:GetChildren() do
				patchTool(child)
			end
		end
	end

	local function syncSilentAimCircle()
		if not canDraw then
			return
		end
		if Config.SilentAim and Config.SilentAimRangeCircle and Config.SilentAimMode == "Mouse" then
			if not silentAimCircle then
				silentAimCircle = Drawing.new("Circle")
				silentAimCircle.NumSides = 64
				silentAimCircle.Thickness = 1
			end
			silentAimCircle.Filled = Config.SilentAimCircleFilled
			silentAimCircle.Color = Config.SilentAimCircleColor
			silentAimCircle.Transparency = Config.SilentAimCircleTransparency
			silentAimCircle.Position = getMousePosition()
			silentAimCircle.Radius = Config.SilentAimRange
			silentAimCircle.Visible = true
		elseif silentAimCircle then
			silentAimCircle.Visible = false
		end
	end

	local function destroySilentAimCircle()
		if silentAimCircle then
			pcall(function()
				silentAimCircle:Remove()
			end)
			silentAimCircle = nil
		end
	end

	return {
		OriginScanner = OriginScanner,
		TracerHook = TracerHook,
		moveSpring = moveSpring,
		aimSpring = aimSpring,
		gun = gun,
		getAimState = function()
			return aimTimer, shootTimer, aimVec
		end,
		setAimVec = function(v: Vector3)
			aimVec = v
		end,
		setShootTimer = function(t: number)
			shootTimer = t
		end,
		updateOriginIgnore = updateOriginIgnore,
		clearOriginCache = function()
			table.clear(OriginScanner.Cache)
		end,
		isVulnerable = isVulnerable,
		getEntitiesInRange = getEntitiesInRange,
		selectCombatTarget = selectCombatTarget,
		getCombatTarget = getCombatTarget,
		getGunData = getGunData,
		resolveGunController = resolveGunController,
		refreshGunFeatures = refreshGunFeatures,
		removeGunHooks = removeGunHooks,
		tryAutoFire = tryAutoFire,
		applyInfiniteAmmo = applyInfiniteAmmo,
		syncSilentAimCircle = syncSilentAimCircle,
		destroySilentAimCircle = destroySilentAimCircle,
		getAutoFireCooldown = function()
			return autoFireCooldown
		end,
		setAutoFireCooldown = function(t: number)
			autoFireCooldown = t
		end,
		unloadTracerHooks = function()
			for _, key in { "BulletTracers", "DamageIndicator", "HitSound", "Viewmodel" } do
				TracerHook:Remove(key)
			end
		end,
	}
end

return M
