--[[
	MicroHub Drawing UI library — shared menu + module HUD for all games.
	Loaded by hub/loader.lua into shared.__MicroHubUILib before game scripts run.
]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Camera = workspace.CurrentCamera

local THEME = {
	bg = Color3.fromRGB(10, 12, 18),
	header = Color3.fromRGB(24, 28, 46),
	accent = Color3.fromRGB(99, 102, 241),
	border = Color3.fromRGB(42, 48, 72),
	section = Color3.fromRGB(128, 134, 168),
	on = Color3.fromRGB(72, 220, 130),
	off = Color3.fromRGB(52, 56, 72),
	text = Color3.fromRGB(228, 232, 245),
	muted = Color3.fromRGB(118, 124, 150),
	buttonDanger = Color3.fromRGB(150, 42, 52),
	hudBg = Color3.fromRGB(8, 10, 16),
	hudBorder = Color3.fromRGB(40, 48, 68),
	hudAccent = Color3.fromRGB(72, 220, 130),
	hudTitle = Color3.fromRGB(195, 200, 220),
	hudLine = Color3.fromRGB(80, 255, 140),
}

local function createSquare(props)
	local sq = Drawing.new("Square")
	sq.Filled = props.Filled or false
	sq.Thickness = props.Thickness or 1
	sq.Color = props.Color or Color3.fromRGB(255, 255, 255)
	sq.Visible = false
	if props.Transparency ~= nil then
		sq.Transparency = props.Transparency
	end
	return sq
end

local function createText(props)
	local txt = Drawing.new("Text")
	txt.Size = props.Size or 14
	txt.Color = props.Color or Color3.fromRGB(255, 255, 255)
	txt.Outline = true
	txt.Center = props.Center or false
	txt.Visible = false
	return txt
end

local function pointInRect(point, pos, size)
	return point.X >= pos.X
		and point.X <= pos.X + size.X
		and point.Y >= pos.Y
		and point.Y <= pos.Y + size.Y
end

local function getFooterHeight(items)
	local height = 8
	for _, item in ipairs(items) do
		if item.type == "slider" then
			height += 22
		elseif item.type == "button" then
			height += 22
		elseif item.type == "hint" then
			height += 14
		end
	end
	return height
end

local uiBlockedInputs = {
	Enum.UserInputType.MouseButton1,
	Enum.UserInputType.MouseButton2,
	Enum.UserInputType.MouseButton3,
	Enum.UserInputType.MouseMovement,
	Enum.UserInputType.MouseWheel,
}
for _, action in ipairs(Enum.PlayerActions:GetEnumItems()) do
	table.insert(uiBlockedInputs, action)
end

local function uiInputSink()
	return Enum.ContextActionResult.Sink
end

local HubUI = {}
HubUI.__index = HubUI

function HubUI.new(options)
	local self = setmetatable({}, HubUI)

	self.title = options.title or "MicroHub"
	self.config = options.config
	self.sections = options.sections or {}
	self.toggleKey = options.toggleKey or Enum.KeyCode.RightShift
	self.dragHint = options.dragHint or "RightShift"
	self.onToggle = options.onToggle
	self.onMenuVisible = options.onMenuVisible
	self.footerItems = (options.footer and options.footer.items) or {}
	self.hudShowKey = (options.hud and options.hud.showKey) or "ShowHUD"

	self.menuVisible = options.startVisible ~= false
	self.savedMouseBehavior = nil
	self.inputBlockName = "MicroHubUI_" .. self.title:gsub("%s+", "")

	self.X = 16
	self.Y = 16
	self.Width = options.width or 318
	self.HeaderHeight = 36
	self.RowHeight = 20
	self.SectionGap = 6
	self.Padding = 12
	self.ColGap = 10
	self.Columns = 2
	self.Dragging = false
	self.DragOffset = Vector2.zero
	self.footerHeight = getFooterHeight(self.footerItems)

	self.toggles = {}
	for _, section in ipairs(self.sections) do
		for _, toggle in ipairs(section.toggles or {}) do
			table.insert(self.toggles, toggle)
		end
	end

	self.drawings = {
		background = createSquare({ Filled = true, Color = THEME.bg, Thickness = 1, Transparency = 0.05 }),
		modalOverlay = createSquare({
			Filled = true,
			Color = Color3.fromRGB(0, 0, 0),
			Thickness = 1,
			Transparency = 0.5,
		}),
		border = createSquare({ Filled = false, Color = THEME.border, Thickness = 1 }),
		header = createSquare({ Filled = true, Color = THEME.header, Thickness = 1, Transparency = 0.1 }),
		accentLine = createSquare({ Filled = true, Color = THEME.accent, Thickness = 1 }),
		title = createText({ Size = 16, Color = THEME.text }),
		dragHint = createText({ Size = 11, Color = THEME.muted }),
		sectionLabels = {},
		sectionDots = {},
		sectionLines = {},
		toggleIndicators = {},
		toggleLabels = {},
		footer = {},
		hud = {
			background = createSquare({ Filled = true, Color = THEME.hudBg, Transparency = 0.22 }),
			border = createSquare({ Filled = false, Color = THEME.hudBorder, Thickness = 1 }),
			accent = createSquare({ Filled = true, Color = THEME.hudAccent }),
			title = createText({ Size = 12, Color = THEME.hudTitle }),
			empty = createText({ Size = 12, Color = THEME.muted }),
			lines = {},
		},
	}

	for sectionIndex in ipairs(self.sections) do
		self.drawings.sectionLabels[sectionIndex] = createText({ Size = 11, Color = THEME.section })
		self.drawings.sectionDots[sectionIndex] = createSquare({ Filled = true, Color = THEME.accent, Thickness = 1 })
		self.drawings.sectionLines[sectionIndex] = createSquare({ Filled = true, Color = THEME.border, Thickness = 1 })
	end

	for _, toggle in ipairs(self.toggles) do
		self.drawings.toggleIndicators[toggle.key] = createSquare({ Filled = true, Thickness = 1 })
		self.drawings.toggleLabels[toggle.key] = createText({ Size = 14 })
	end

	for index, item in ipairs(self.footerItems) do
		local id = item.id or item.key or ("footer_" .. index)
		item._id = id
		if item.type == "slider" then
			self.drawings.footer[id .. "_label"] = createText({ Size = 13, Color = THEME.text })
			self.drawings.footer[id .. "_minus"] = createSquare({ Filled = true, Color = THEME.border })
			self.drawings.footer[id .. "_plus"] = createSquare({ Filled = true, Color = THEME.border })
			self.drawings.footer[id .. "_minusText"] = createText({ Size = 15, Center = true, Color = THEME.text })
			self.drawings.footer[id .. "_plusText"] = createText({ Size = 15, Center = true, Color = THEME.text })
		elseif item.type == "button" then
			self.drawings.footer[id .. "_button"] = createSquare({
				Filled = true,
				Color = item.color or THEME.buttonDanger,
			})
			self.drawings.footer[id .. "_text"] = createText({ Size = 13, Color = THEME.text, Center = true })
		elseif item.type == "hint" then
			self.drawings.footer[id .. "_hint"] = createText({ Size = 10, Color = THEME.muted })
		end
	end

	self.hudWidth = 148
	self.hudPadding = 10
	self.hudLineHeight = 15

	self:_bindInput()
	self:setMenuVisible(self.menuVisible)

	self._renderConn = RunService.RenderStepped:Connect(function()
		self:_drawMenu()
		self:_drawHud()
		if self.Dragging then
			local mouse = UserInputService:GetMouseLocation()
			self.X = math.clamp(mouse.X - self.DragOffset.X, 0, Camera.ViewportSize.X - self.Width)
			self.Y = math.clamp(mouse.Y - self.DragOffset.Y, 0, Camera.ViewportSize.Y - self:_getContentHeight())
		end
	end)

	return self
end

function HubUI:_getColumnWidth()
	return (self.Width - self.Padding * 2 - self.ColGap) / self.Columns
end

function HubUI:_getContentHeight()
	local height = self.HeaderHeight + self.Padding
	for _, section in ipairs(self.sections) do
		height += 18 + math.ceil(#(section.toggles or {}) / self.Columns) * self.RowHeight + self.SectionGap
	end
	return height + self.footerHeight
end

function HubUI:_getToggleRowPositions()
	local rows = {}
	local cursorY = self.Y + self.HeaderHeight + self.Padding
	local colWidth = self:_getColumnWidth()

	for _, section in ipairs(self.sections) do
		cursorY += 18
		local toggles = section.toggles or {}
		for index = 1, #toggles, self.Columns do
			local rowY = cursorY
			local left = toggles[index]
			local right = toggles[index + 1]

			if left then
				table.insert(rows, {
					key = left.key,
					y = rowY,
					x = self.X + self.Padding,
					width = colWidth,
				})
			end
			if right then
				table.insert(rows, {
					key = right.key,
					y = rowY,
					x = self.X + self.Padding + colWidth + self.ColGap,
					width = colWidth,
				})
			end
			cursorY += self.RowHeight
		end
		cursorY += self.SectionGap
	end
	return rows
end

function HubUI:_getFooterStartY()
	return self.Y + self:_getContentHeight() - self.footerHeight + 2
end

function HubUI:_setIndicatorColor(indicator, enabled)
	indicator.Color = enabled and THEME.on or THEME.off
end

function HubUI:_setInputBlocked(blocked)
	if blocked then
		ContextActionService:BindActionAtPriority(
			self.inputBlockName,
			uiInputSink,
			false,
			3000,
			table.unpack(uiBlockedInputs)
		)
	else
		ContextActionService:UnbindAction(self.inputBlockName)
	end
end

function HubUI:setMenuVisible(visible)
	self.menuVisible = visible
	if visible then
		self.Dragging = false
		self.savedMouseBehavior = UserInputService.MouseBehavior
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		self:_setInputBlocked(true)
	else
		self:_setInputBlocked(false)
		if self.savedMouseBehavior then
			UserInputService.MouseBehavior = self.savedMouseBehavior
			self.savedMouseBehavior = nil
		end
	end
	if self.onMenuVisible then
		self.onMenuVisible(visible)
	end
end

function HubUI:isMenuVisible()
	return self.menuVisible
end

function HubUI:destroy()
	if self._renderConn then
		self._renderConn:Disconnect()
		self._renderConn = nil
	end
	self:_setInputBlocked(false)

	local function removeDrawing(drawing)
		if typeof(drawing) == "userdata" then
			drawing:Remove()
		end
	end

	for _, value in pairs(self.drawings) do
		if typeof(value) == "userdata" then
			removeDrawing(value)
		elseif typeof(value) == "table" then
			for _, nested in pairs(value) do
				removeDrawing(nested)
			end
		end
	end
end

function HubUI:_drawToggle(visible, toggle, posX, posY)
	local indicator = self.drawings.toggleIndicators[toggle.key]
	local label = self.drawings.toggleLabels[toggle.key]
	local enabled = self.config[toggle.key]

	indicator.Position = Vector2.new(posX, posY + 2)
	indicator.Size = Vector2.new(10, 10)
	self:_setIndicatorColor(indicator, enabled)
	indicator.Visible = visible

	label.Position = Vector2.new(posX + 14, posY)
	label.Text = toggle.label
	label.Color = enabled and THEME.text or THEME.muted
	label.Visible = visible
end

function HubUI:_drawFooter(visible, startY)
	local x = self.X
	local cursorY = startY

	for _, item in ipairs(self.footerItems) do
		local id = item._id
		if item.type == "slider" then
			local value = self.config[item.key]
			local label = self.drawings.footer[id .. "_label"]
			label.Position = Vector2.new(x + self.Padding, cursorY)
			label.Text = item.label .. ": " .. tostring(value)
			label.Visible = visible

			self.drawings.footer[id .. "_minus"].Position = Vector2.new(x + self.Width - 58, cursorY - 2)
			self.drawings.footer[id .. "_minus"].Size = Vector2.new(22, 18)
			self.drawings.footer[id .. "_minus"].Visible = visible

			self.drawings.footer[id .. "_minusText"].Position = Vector2.new(x + self.Width - 47, cursorY + 1)
			self.drawings.footer[id .. "_minusText"].Text = "-"
			self.drawings.footer[id .. "_minusText"].Visible = visible

			self.drawings.footer[id .. "_plus"].Position = Vector2.new(x + self.Width - 32, cursorY - 2)
			self.drawings.footer[id .. "_plus"].Size = Vector2.new(22, 18)
			self.drawings.footer[id .. "_plus"].Visible = visible

			self.drawings.footer[id .. "_plusText"].Position = Vector2.new(x + self.Width - 21, cursorY + 1)
			self.drawings.footer[id .. "_plusText"].Text = "+"
			self.drawings.footer[id .. "_plusText"].Visible = visible

			cursorY += 22
		elseif item.type == "button" then
			local labelText = item.getLabel and item.getLabel() or item.label or "Action"
			self.drawings.footer[id .. "_button"].Position = Vector2.new(x + self.Padding, cursorY)
			self.drawings.footer[id .. "_button"].Size = Vector2.new(self.Width - self.Padding * 2, 22)
			self.drawings.footer[id .. "_button"].Visible = visible

			self.drawings.footer[id .. "_text"].Position = Vector2.new(x + self.Width * 0.5, cursorY + 4)
			self.drawings.footer[id .. "_text"].Text = labelText
			self.drawings.footer[id .. "_text"].Visible = visible

			cursorY += 22
		elseif item.type == "hint" then
			local text = item.getText and item.getText() or item.text or ""
			self.drawings.footer[id .. "_hint"].Position = Vector2.new(x + self.Padding, cursorY)
			self.drawings.footer[id .. "_hint"].Text = text
			self.drawings.footer[id .. "_hint"].Visible = visible

			cursorY += 14
		end
	end
end

function HubUI:_drawMenu()
	local visible = self.menuVisible
	local x, y = self.X, self.Y
	local height = self:_getContentHeight()
	local colWidth = self:_getColumnWidth()
	local leftX = x + self.Padding
	local rightX = leftX + colWidth + self.ColGap
	local viewport = Camera.ViewportSize
	local d = self.drawings

	if visible then
		d.modalOverlay.Position = Vector2.new(0, 0)
		d.modalOverlay.Size = viewport
		d.modalOverlay.Visible = true
	else
		d.modalOverlay.Visible = false
	end

	d.background.Position = Vector2.new(x, y)
	d.background.Size = Vector2.new(self.Width, height)
	d.background.Visible = visible

	d.border.Position = Vector2.new(x, y)
	d.border.Size = Vector2.new(self.Width, height)
	d.border.Visible = visible

	d.header.Position = Vector2.new(x, y)
	d.header.Size = Vector2.new(self.Width, self.HeaderHeight)
	d.header.Visible = visible

	d.accentLine.Position = Vector2.new(x, y + self.HeaderHeight - 2)
	d.accentLine.Size = Vector2.new(self.Width, 2)
	d.accentLine.Visible = visible

	d.title.Position = Vector2.new(x + self.Padding, y + 9)
	d.title.Text = self.title
	d.title.Visible = visible

	d.dragHint.Position = Vector2.new(x + self.Width - 78, y + 11)
	d.dragHint.Text = self.dragHint
	d.dragHint.Visible = visible

	local cursorY = y + self.HeaderHeight + self.Padding
	for sectionIndex, section in ipairs(self.sections) do
		local sectionLabel = d.sectionLabels[sectionIndex]
		local sectionDot = d.sectionDots[sectionIndex]
		local sectionLine = d.sectionLines[sectionIndex]
		local toggles = section.toggles or {}

		sectionDot.Position = Vector2.new(x + self.Padding, cursorY + 3)
		sectionDot.Size = Vector2.new(4, 4)
		sectionDot.Visible = visible

		sectionLabel.Position = Vector2.new(x + self.Padding + 8, cursorY)
		sectionLabel.Text = section.title or ""
		sectionLabel.Visible = visible

		sectionLine.Position = Vector2.new(x + self.Padding + 68, cursorY + 7)
		sectionLine.Size = Vector2.new(self.Width - self.Padding * 2 - 68, 1)
		sectionLine.Visible = visible

		cursorY += 18

		for index = 1, #toggles, self.Columns do
			local left = toggles[index]
			local right = toggles[index + 1]
			if left then
				self:_drawToggle(visible, left, leftX, cursorY)
			end
			if right then
				self:_drawToggle(visible, right, rightX, cursorY)
			end
			cursorY += self.RowHeight
		end

		cursorY += self.SectionGap
	end

	self:_drawFooter(visible, self:_getFooterStartY())
end

function HubUI:_getEnabledHudModules()
	local modules = {}
	for _, toggle in ipairs(self.toggles) do
		if toggle.hud and self.config[toggle.key] then
			table.insert(modules, toggle.hud)
		end
	end
	return modules
end

function HubUI:_ensureHudLines(count)
	local lines = self.drawings.hud.lines
	while #lines < count do
		table.insert(lines, createText({ Size = 13, Color = THEME.hudLine }))
	end
end

function HubUI:_drawHud()
	local hud = self.drawings.hud
	if not self.config[self.hudShowKey] then
		hud.background.Visible = false
		hud.border.Visible = false
		hud.accent.Visible = false
		hud.title.Visible = false
		hud.empty.Visible = false
		for _, line in ipairs(hud.lines) do
			line.Visible = false
		end
		return
	end

	local modules = self:_getEnabledHudModules()
	self:_ensureHudLines(#modules)

	local viewport = Camera.ViewportSize
	local moduleCount = math.max(#modules, 1)
	local height = 24 + moduleCount * self.hudLineHeight + self.hudPadding
	local hudX = viewport.X - self.hudWidth - 14
	local hudY = 14

	hud.background.Position = Vector2.new(hudX, hudY)
	hud.background.Size = Vector2.new(self.hudWidth, height)
	hud.background.Visible = true

	hud.border.Position = Vector2.new(hudX, hudY)
	hud.border.Size = Vector2.new(self.hudWidth, height)
	hud.border.Visible = true

	hud.accent.Position = Vector2.new(hudX, hudY)
	hud.accent.Size = Vector2.new(3, height)
	hud.accent.Visible = true

	hud.title.Position = Vector2.new(hudX + self.hudPadding + 4, hudY + 5)
	hud.title.Text = "ACTIVE"
	hud.title.Visible = true

	if #modules == 0 then
		hud.empty.Position = Vector2.new(hudX + self.hudPadding + 6, hudY + 22)
		hud.empty.Text = "none"
		hud.empty.Visible = true
		for _, line in ipairs(hud.lines) do
			line.Visible = false
		end
		return
	end

	hud.empty.Visible = false
	for index, name in ipairs(modules) do
		local line = hud.lines[index]
		line.Position = Vector2.new(hudX + self.hudPadding + 6, hudY + 20 + (index - 1) * self.hudLineHeight)
		line.Text = name
		line.Visible = true
	end
	for index = #modules + 1, #hud.lines do
		hud.lines[index].Visible = false
	end
end

function HubUI:_handleClick(mouse)
	if not self.menuVisible or self.Dragging then
		return
	end

	local height = self:_getContentHeight()
	if not pointInRect(mouse, Vector2.new(self.X, self.Y), Vector2.new(self.Width, height)) then
		return
	end

	for _, row in ipairs(self:_getToggleRowPositions()) do
		if pointInRect(mouse, Vector2.new(row.x, row.y - 2), Vector2.new(row.width, 16)) then
			local key = row.key
			self.config[key] = not self.config[key]
			if self.onToggle then
				self.onToggle(key, self.config[key])
			end
			return
		end
	end

	local footerY = self:_getFooterStartY()
	local x = self.X
	for _, item in ipairs(self.footerItems) do
		if item.type == "slider" then
			if pointInRect(mouse, Vector2.new(x + self.Width - 58, footerY - 2), Vector2.new(22, 18)) then
				local step = item.step or 1
				local min = item.min or 0
				local newValue = self.config[item.key] - step
				if newValue >= min then
					self.config[item.key] = newValue
					if item.onChange then
						item.onChange(newValue)
					end
				end
				return
			elseif pointInRect(mouse, Vector2.new(x + self.Width - 32, footerY - 2), Vector2.new(22, 18)) then
				local step = item.step or 1
				local max = item.max or math.huge
				local newValue = self.config[item.key] + step
				if newValue <= max then
					self.config[item.key] = newValue
					if item.onChange then
						item.onChange(newValue)
					end
				end
				return
			end
			footerY += 22
		elseif item.type == "button" then
			local canClick = not item.canClick or item.canClick()
			if canClick and pointInRect(mouse, Vector2.new(x + self.Padding, footerY), Vector2.new(self.Width - self.Padding * 2, 22)) then
				if item.onClick then
					item.onClick()
				end
				return
			end
			footerY += 22
		elseif item.type == "hint" then
			footerY += 14
		end
	end
end

function HubUI:_bindInput()
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == self.toggleKey then
			self:setMenuVisible(not self.menuVisible)
			return
		end
		if not self.menuVisible then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local mouse = UserInputService:GetMouseLocation()
			if pointInRect(mouse, Vector2.new(self.X, self.Y), Vector2.new(self.Width, self.HeaderHeight)) then
				self.Dragging = true
				self.DragOffset = mouse - Vector2.new(self.X, self.Y)
				return
			end
			self:_handleClick(mouse)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.Dragging = false
		end
	end)
end

return {
	create = function(options)
		return HubUI.new(options)
	end,
	theme = THEME,
}
