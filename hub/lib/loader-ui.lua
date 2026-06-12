--[[
	MicroHub loader splash — lightweight ScreenGui shown while hub/loader.lua runs.
	Independent of juanita; destroyed before the game menu opens.
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local cloneref = cloneref or function(value)
	return value
end

local CoreGui = cloneref(game:GetService("CoreGui"))
local gethui = gethui or function()
	return CoreGui
end

local CARD_WIDTH = 380
local PAD_TOP, PAD_RIGHT, PAD_BOTTOM, PAD_LEFT = 18, 20, 18, 20
local SECTION_GAP = 10
local MAX_STEPS_HEIGHT = 108

local THEME = {
	Background = Color3.fromRGB(12, 12, 12),
	Inline = Color3.fromRGB(19, 19, 19),
	Outline = Color3.fromRGB(51, 51, 51),
	Accent = Color3.fromRGB(176, 176, 209),
	Text = Color3.fromRGB(208, 207, 227),
	Muted = Color3.fromRGB(134, 134, 134),
	Success = Color3.fromRGB(75, 220, 120),
	Error = Color3.fromRGB(255, 90, 90),
	Bar = Color3.fromRGB(39, 39, 39),
	BarFill = Color3.fromRGB(176, 176, 209),
}

local TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local FADE = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function tween(instance, props, info)
	local tweenObj = TweenService:Create(instance, info or TWEEN, props)
	tweenObj:Play()
	return tweenObj
end

local function corner(parent, radius)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
	return ui
end

local function stroke(parent, color, thickness)
	local ui = Instance.new("UIStroke")
	ui.Color = color
	ui.Thickness = thickness or 1
	ui.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ui.Parent = parent
	return ui
end

local function padding(parent, top, right, bottom, left)
	local ui = Instance.new("UIPadding")
	ui.PaddingTop = UDim.new(0, top)
	ui.PaddingRight = UDim.new(0, right or top)
	ui.PaddingBottom = UDim.new(0, bottom or top)
	ui.PaddingLeft = UDim.new(0, left or right or top)
	ui.Parent = parent
	return ui
end

local LoaderUI = {}

function LoaderUI.create(options)
	options = options or {}

	local version = tostring(options.version or "?")
	local connections = {}
	local destroyed = false
	local spinnerAngle = 0
	local targetProgress = 0
	local currentProgress = 0

	local screen = Instance.new("ScreenGui")
	screen.Name = "MicroHubLoader"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.DisplayOrder = 9999
	screen.Parent = gethui()

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = screen

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(CARD_WIDTH, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = THEME.Background
	card.BorderSizePixel = 0
	card.Parent = dim
	corner(card, 10)
	stroke(card, THEME.Outline, 1)

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(CARD_WIDTH, 0)
	sizeConstraint.MaxSize = Vector2.new(CARD_WIDTH, 420)
	sizeConstraint.Parent = card

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, 0, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Parent = card
	padding(content, PAD_TOP, PAD_RIGHT, PAD_BOTTOM, PAD_LEFT)

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.FillDirection = Enum.FillDirection.Vertical
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, SECTION_GAP)
	contentLayout.Parent = content

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 28)
	header.LayoutOrder = 1
	header.Parent = content

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -72, 1, 0)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = THEME.Text
	title.Text = "MicroHub"
	title.Parent = header

	local versionBadge = Instance.new("TextLabel")
	versionBadge.Name = "Version"
	versionBadge.AnchorPoint = Vector2.new(1, 0.5)
	versionBadge.Position = UDim2.new(1, 0, 0.5, 0)
	versionBadge.Size = UDim2.fromOffset(64, 22)
	versionBadge.BackgroundColor3 = THEME.Inline
	versionBadge.BorderSizePixel = 0
	versionBadge.Font = Enum.Font.GothamMedium
	versionBadge.TextSize = 12
	versionBadge.TextColor3 = THEME.Muted
	versionBadge.Text = "v" .. version
	versionBadge.Parent = header
	corner(versionBadge, 6)
	stroke(versionBadge, THEME.Outline, 1)

	local statusRow = Instance.new("Frame")
	statusRow.Name = "StatusRow"
	statusRow.BackgroundTransparency = 1
	statusRow.Size = UDim2.new(1, 0, 0, 24)
	statusRow.LayoutOrder = 2
	statusRow.Parent = content

	local spinner = Instance.new("Frame")
	spinner.Name = "Spinner"
	spinner.BackgroundTransparency = 1
	spinner.Size = UDim2.fromOffset(18, 18)
	spinner.Parent = statusRow

	local spinnerArc = Instance.new("Frame")
	spinnerArc.Name = "Arc"
	spinnerArc.AnchorPoint = Vector2.new(0.5, 0.5)
	spinnerArc.Position = UDim2.fromScale(0.5, 0.5)
	spinnerArc.Size = UDim2.fromOffset(16, 16)
	spinnerArc.BackgroundTransparency = 1
	spinnerArc.Parent = spinner
	stroke(spinnerArc, THEME.Accent, 2)

	local spinnerGap = Instance.new("Frame")
	spinnerGap.Name = "Gap"
	spinnerGap.AnchorPoint = Vector2.new(0.5, 0)
	spinnerGap.Position = UDim2.new(0.5, 0, 0, -1)
	spinnerGap.Size = UDim2.fromOffset(6, 4)
	spinnerGap.BackgroundColor3 = THEME.Background
	spinnerGap.BorderSizePixel = 0
	spinnerGap.Parent = spinnerArc

	local statusIcon = Instance.new("TextLabel")
	statusIcon.Name = "Icon"
	statusIcon.BackgroundTransparency = 1
	statusIcon.Size = UDim2.fromOffset(18, 18)
	statusIcon.Font = Enum.Font.GothamBold
	statusIcon.TextSize = 16
	statusIcon.TextColor3 = THEME.Success
	statusIcon.Text = ""
	statusIcon.Visible = false
	statusIcon.Parent = statusRow

	local statusText = Instance.new("TextLabel")
	statusText.Name = "Status"
	statusText.BackgroundTransparency = 1
	statusText.Position = UDim2.new(0, 26, 0, 0)
	statusText.Size = UDim2.new(1, -26, 1, 0)
	statusText.Font = Enum.Font.GothamMedium
	statusText.TextSize = 14
	statusText.TextXAlignment = Enum.TextXAlignment.Left
	statusText.TextColor3 = THEME.Text
	statusText.Text = "Starting..."
	statusText.TextTruncate = Enum.TextTruncate.AtEnd
	statusText.Parent = statusRow

	local detailText = Instance.new("TextLabel")
	detailText.Name = "Detail"
	detailText.BackgroundTransparency = 1
	detailText.Size = UDim2.new(1, 0, 0, 0)
	detailText.AutomaticSize = Enum.AutomaticSize.Y
	detailText.Font = Enum.Font.Gotham
	detailText.TextSize = 12
	detailText.TextXAlignment = Enum.TextXAlignment.Left
	detailText.TextYAlignment = Enum.TextYAlignment.Top
	detailText.TextWrapped = true
	detailText.TextColor3 = THEME.Muted
	detailText.Text = ""
	detailText.Visible = false
	detailText.LayoutOrder = 3
	detailText.Parent = content

	local barTrack = Instance.new("Frame")
	barTrack.Name = "ProgressTrack"
	barTrack.Size = UDim2.new(1, 0, 0, 6)
	barTrack.BackgroundColor3 = THEME.Bar
	barTrack.BorderSizePixel = 0
	barTrack.ClipsDescendants = true
	barTrack.LayoutOrder = 4
	barTrack.Parent = content
	corner(barTrack, 3)

	local barFill = Instance.new("Frame")
	barFill.Name = "ProgressFill"
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = THEME.BarFill
	barFill.BorderSizePixel = 0
	barFill.Parent = barTrack
	corner(barFill, 3)

	local stepsScroll = Instance.new("ScrollingFrame")
	stepsScroll.Name = "StepsScroll"
	stepsScroll.BackgroundTransparency = 1
	stepsScroll.BorderSizePixel = 0
	stepsScroll.ScrollBarThickness = 3
	stepsScroll.ScrollBarImageColor3 = THEME.Outline
	stepsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	stepsScroll.CanvasSize = UDim2.new()
	stepsScroll.Size = UDim2.new(1, 0, 0, 0)
	stepsScroll.Visible = false
	stepsScroll.LayoutOrder = 5
	stepsScroll.Parent = content

	local stepsFrame = Instance.new("Frame")
	stepsFrame.Name = "Steps"
	stepsFrame.BackgroundTransparency = 1
	stepsFrame.Size = UDim2.new(1, 0, 0, 0)
	stepsFrame.AutomaticSize = Enum.AutomaticSize.Y
	stepsFrame.Parent = stepsScroll

	local stepsLayout = Instance.new("UIListLayout")
	stepsLayout.FillDirection = Enum.FillDirection.Vertical
	stepsLayout.Padding = UDim.new(0, 4)
	stepsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stepsLayout.Parent = stepsFrame

	local dismissButton = Instance.new("TextButton")
	dismissButton.Name = "Dismiss"
	dismissButton.Size = UDim2.new(1, 0, 0, 30)
	dismissButton.BackgroundColor3 = THEME.Inline
	dismissButton.BorderSizePixel = 0
	dismissButton.AutoButtonColor = false
	dismissButton.Font = Enum.Font.GothamMedium
	dismissButton.TextSize = 13
	dismissButton.TextColor3 = THEME.Text
	dismissButton.Text = "Dismiss"
	dismissButton.Visible = false
	dismissButton.LayoutOrder = 6
	dismissButton.Parent = content
	corner(dismissButton, 6)
	stroke(dismissButton, THEME.Outline, 1)

	local stepLabels = {}
	local stepOrder = 0

	local function updateStepsScrollHeight()
		local contentHeight = stepsLayout.AbsoluteContentSize.Y
		local height = math.min(contentHeight, MAX_STEPS_HEIGHT)
		stepsScroll.Visible = height > 0
		stepsScroll.Size = UDim2.new(1, 0, 0, height)
	end

	local function destroySelf()
		if destroyed then
			return
		end
		destroyed = true
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		table.clear(connections)
		if screen.Parent then
			screen:Destroy()
		end
	end

	local function fadeOut(delaySeconds)
		task.delay(delaySeconds or 1.4, function()
			if destroyed then
				return
			end
			local fadeTween = tween(dim, { BackgroundTransparency = 1 }, FADE)
			tween(card, { BackgroundTransparency = 1 }, FADE)
			for _, child in ipairs(card:GetDescendants()) do
				if child:IsA("GuiObject") then
					tween(child, { BackgroundTransparency = 1 }, FADE)
				end
				if child:IsA("TextLabel") or child:IsA("TextButton") then
					tween(child, { TextTransparency = 1 }, FADE)
				end
				if child:IsA("UIStroke") then
					tween(child, { Transparency = 1 }, FADE)
				end
			end
			fadeTween.Completed:Wait()
			destroySelf()
		end)
	end

	local function addStep(text, state)
		stepOrder += 1
		local row = Instance.new("TextLabel")
		row.Name = "Step" .. tostring(stepOrder)
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Font = Enum.Font.Gotham
		row.TextSize = 12
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextYAlignment = Enum.TextYAlignment.Top
		row.TextWrapped = true
		row.LayoutOrder = stepOrder
		row.Parent = stepsFrame

		local prefix = "• "
		local color = THEME.Muted
		if state == "done" then
			prefix = "✓ "
			color = THEME.Success
		elseif state == "active" then
			prefix = "› "
			color = THEME.Accent
		elseif state == "error" then
			prefix = "✕ "
			color = THEME.Error
		end

		row.TextColor3 = color
		row.Text = prefix .. text
		stepLabels[#stepLabels + 1] = row
		task.defer(updateStepsScrollHeight)
		return row
	end

	local function markPreviousDone()
		for _, label in ipairs(stepLabels) do
			if label.Text:sub(1, 1) == "›" then
				label.Text = "✓ " .. label.Text:sub(3)
				label.TextColor3 = THEME.Success
			end
		end
	end

	local api = {}

	function api.setStep(text, detail, progress)
		if destroyed then
			return
		end
		markPreviousDone()
		addStep(text, "active")
		statusText.Text = text
		detailText.Text = detail or ""
		detailText.Visible = detailText.Text ~= ""
		if typeof(progress) == "number" then
			targetProgress = math.clamp(progress, 0, 1)
		end
	end

	function api.setProgress(progress)
		if destroyed then
			return
		end
		targetProgress = math.clamp(progress, 0, 1)
	end

	function api.success(gameName, uiVersion)
		if destroyed then
			return
		end
		markPreviousDone()
		addStep("Ready", "done")
		spinner.Visible = false
		statusIcon.Visible = true
		statusIcon.Text = "✓"
		statusIcon.TextColor3 = THEME.Success
		statusText.Text = gameName .. " loaded"
		local detail = uiVersion and ("UI " .. tostring(uiVersion)) or ""
		detailText.Text = detail
		detailText.Visible = detail ~= ""
		detailText.TextColor3 = THEME.Muted
		targetProgress = 1
		barFill.BackgroundColor3 = THEME.Success
		fadeOut(1.6)
	end

	function api.fail(message)
		if destroyed then
			return
		end
		markPreviousDone()
		addStep("Failed", "error")
		spinner.Visible = false
		statusIcon.Visible = true
		statusIcon.Text = "✕"
		statusIcon.TextColor3 = THEME.Error
		statusText.Text = "Load failed"
		detailText.Text = tostring(message)
		detailText.Visible = true
		detailText.TextColor3 = THEME.Error
		targetProgress = 1
		barFill.BackgroundColor3 = THEME.Error
		dismissButton.Visible = true
		task.defer(updateStepsScrollHeight)
	end

	function api.destroy()
		destroySelf()
	end

	table.insert(connections, dismissButton.MouseButton1Click:Connect(destroySelf))
	table.insert(connections, stepsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateStepsScrollHeight))

	table.insert(
		connections,
		RunService.RenderStepped:Connect(function(dt)
			if destroyed then
				return
			end
			spinnerAngle = (spinnerAngle + dt * 280) % 360
			spinnerArc.Rotation = spinnerAngle
			if currentProgress < targetProgress then
				currentProgress = math.min(targetProgress, currentProgress + dt * 0.85)
				barFill.Size = UDim2.new(currentProgress, 0, 1, 0)
			end
		end)
	)

	card.BackgroundTransparency = 1
	dim.BackgroundTransparency = 1
	tween(dim, { BackgroundTransparency = 0.45 })
	tween(card, { BackgroundTransparency = 0 })

	return api
end

return LoaderUI
