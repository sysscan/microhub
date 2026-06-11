local TweenService = game:GetService("TweenService")

local M = {}

function M.create(opts)
	local Config = opts.config
	local Camera = opts.camera
	local LocalPlayer = opts.localPlayer
	local hasDrawing = opts.hasDrawing
	local createDrawing = opts.createDrawing

	local bulletTracerDrawings = {}
	local gunChamHighlights = {}
	local triggerBotLastFire = 0
	local spinbotYaw = 0

	local function spawnBulletTracer(origin, direction)
		if not Config.BulletTracers then
			return
		end
		if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
			return
		end
		local dir = direction.Unit
		local length = tonumber(Config.BulletTracerLength) or 140
		local endPos = origin + dir * length

		if Config.BulletTracerDrawing and hasDrawing() then
			local line = createDrawing("Line")
			if not line then
				return
			end
			line.Thickness = tonumber(Config.BulletTracerThickness) or 2
			line.Color = Config.BulletTracerColor
			line.Transparency = 0
			line.Visible = false
			local lifetime = tonumber(Config.BulletTracerLifetime) or 0.25
			bulletTracerDrawings[line] = {
				startPos = origin,
				endPos = endPos,
				spawnedAt = os.clock(),
				lifetime = lifetime,
			}
			task.delay(lifetime + 0.05, function()
				bulletTracerDrawings[line] = nil
				pcall(function()
					line.Visible = false
					line:Remove()
				end)
			end)
			return
		end

		if not Config.BulletTracerUseParts then
			return
		end

		local part = Instance.new("Part")
		part.Size = Vector3.new(0.08, 0.08, length)
		part.CFrame = CFrame.lookAt(origin + dir * (length * 0.5), endPos)
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Anchored = true
		part.Material = Enum.Material.Neon
		pcall(function()
			part.Material = Enum.Material[Config.BulletTracerMaterial or "Neon"]
		end)
		part.Color = Config.BulletTracerColor
		part.Transparency = 0.35
		part.Parent = workspace:FindFirstChild("ClientTrash") or workspace

		local lifetime = tonumber(Config.BulletTracerLifetime) or 0.25
		if Config.BulletTracerFade then
			TweenService:Create(part, TweenInfo.new(lifetime), { Transparency = 1 }):Play()
		end
		task.delay(lifetime + 0.05, function()
			pcall(part.Destroy, part)
		end)
	end

	local function updateBulletTracerDrawings()
		if not Config.BulletTracers or not Config.BulletTracerDrawing then
			return
		end
		for line, data in bulletTracerDrawings do
			local from, vis1 = Camera:WorldToViewportPoint(data.startPos)
			local to, vis2 = Camera:WorldToViewportPoint(data.endPos)
			if vis1 and vis2 then
				line.Visible = true
				line.From = Vector2.new(from.X, from.Y)
				line.To = Vector2.new(to.X, to.Y)
				if Config.BulletTracerFade then
					local age = os.clock() - data.spawnedAt
					line.Transparency = math.clamp(age / data.lifetime, 0, 1)
				end
			else
				line.Visible = false
			end
		end
	end

	local function clearGunChams()
		for _, highlight in gunChamHighlights do
			pcall(function()
				highlight:Destroy()
			end)
		end
		table.clear(gunChamHighlights)
	end

	local function styleGunHighlight(highlight)
		highlight.FillColor = Config.GunChamColor
		highlight.OutlineColor = Config.GunChamColor
		highlight.FillTransparency = tonumber(Config.GunChamFillTransparency) or 0.45
		highlight.OutlineTransparency = tonumber(Config.GunChamOutlineTransparency) or 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	end

	local function ensureGunHighlight(adornee)
		if not adornee or not adornee.Parent then
			return
		end
		local existing = gunChamHighlights[adornee]
		if existing and existing.Parent then
			existing.Adornee = adornee
			styleGunHighlight(existing)
			return
		end
		local highlight = Instance.new("Highlight")
		highlight.Name = "MicroHub_GunCham"
		highlight.Adornee = adornee
		highlight.Parent = adornee
		styleGunHighlight(highlight)
		gunChamHighlights[adornee] = highlight
	end

	local function updateGunChams(getWeaponState)
		if not Config.GunChams then
			clearGunChams()
			return
		end

		local seen = {}
		local t2 = getWeaponState()
		if t2 and t2.currentTool then
			ensureGunHighlight(t2.currentTool)
			seen[t2.currentTool] = true
		end

		local viewmodel = workspace:FindFirstChild("Viewmodel")
		if viewmodel then
			ensureGunHighlight(viewmodel)
			seen[viewmodel] = true
		end

		for adornee, highlight in gunChamHighlights do
			if not seen[adornee] then
				pcall(function()
					highlight:Destroy()
				end)
				gunChamHighlights[adornee] = nil
			end
		end
	end

	local function updateSpinbot(dt)
		if not Config.Spinbot then
			spinbotYaw = 0
			return
		end
		local character = LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end

		local speed = tonumber(Config.SpinbotSpeed) or 24
		spinbotYaw = (spinbotYaw + math.rad(speed) * dt) % (math.pi * 2)
		local look = root.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		if flatLook.Magnitude < 0.05 then
			flatLook = Vector3.new(0, 0, -1)
		else
			flatLook = flatLook.Unit
		end
		root.CFrame = CFrame.new(root.Position, root.Position + flatLook) * CFrame.Angles(0, spinbotYaw, 0)
	end

	local function updateTriggerBot(getTarget, tryFire, hasLineOfSight)
		if not Config.TriggerBot then
			return
		end
		if typeof(opts.isMenuVisible) == "function" and opts.isMenuVisible() then
			return
		end

		local target = getTarget()
		if not target or not target.part or not target.part.Parent then
			return
		end

		if Config.LineOfSight and typeof(hasLineOfSight) == "function" then
			if not hasLineOfSight(target.part.Position, target.character) then
				return
			end
		end

		local now = tick()
		local delay = tonumber(Config.TriggerBotDelay) or 0.1
		if now - triggerBotLastFire < delay then
			return
		end

		if tryFire() then
			triggerBotLastFire = now
		end
	end

	local function unload()
		for line in bulletTracerDrawings do
			pcall(function()
				line:Remove()
			end)
		end
		table.clear(bulletTracerDrawings)
		clearGunChams()
	end

	return {
		spawnBulletTracer = spawnBulletTracer,
		updateBulletTracerDrawings = updateBulletTracerDrawings,
		updateGunChams = updateGunChams,
		updateSpinbot = updateSpinbot,
		updateTriggerBot = updateTriggerBot,
		unload = unload,
	}
end

return M
