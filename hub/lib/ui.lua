--[[
	MicroHub UI v2.1.0 — Drawing-based menu for PC + mobile.
	Loaded by hub/loader.lua into shared.__MicroHubUILib

	Item types (per section.items or legacy section.toggles):
	  toggle, slider, select, color, number, button, hint, separator, label

	Legacy footer.items still supported (merged into scroll area).
]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

local THEME = {
	bg = Color3.fromRGB(10, 12, 18),
	header = Color3.fromRGB(24, 28, 46),
	accent = Color3.fromRGB(99, 102, 241),
	accentSoft = Color3.fromRGB(68, 72, 120),
	border = Color3.fromRGB(42, 48, 72),
	section = Color3.fromRGB(128, 134, 168),
	on = Color3.fromRGB(72, 220, 130),
	off = Color3.fromRGB(52, 56, 72),
	text = Color3.fromRGB(228, 232, 245),
	muted = Color3.fromRGB(118, 124, 150),
	track = Color3.fromRGB(32, 36, 52),
	trackFill = Color3.fromRGB(99, 102, 241),
	button = Color3.fromRGB(56, 62, 88),
	buttonDanger = Color3.fromRGB(150, 42, 52),
	pill = Color3.fromRGB(38, 42, 60),
	pillActive = Color3.fromRGB(99, 102, 241),
	hudBg = Color3.fromRGB(8, 10, 16),
	hudBorder = Color3.fromRGB(40, 48, 68),
	hudAccent = Color3.fromRGB(72, 220, 130),
	hudTitle = Color3.fromRGB(195, 200, 220),
	hudLine = Color3.fromRGB(80, 255, 140),
	mobileFab = Color3.fromRGB(99, 102, 241),
}

local COLOR_PRESETS = {
	Color3.fromRGB(255, 75, 75),
	Color3.fromRGB(75, 220, 120),
	Color3.fromRGB(255, 220, 80),
	Color3.fromRGB(99, 102, 241),
	Color3.fromRGB(255, 140, 60),
	Color3.fromRGB(120, 200, 255),
	Color3.fromRGB(220, 120, 255),
	Color3.fromRGB(255, 255, 255),
}

local function clearTable(tbl)
	if table.clear then
		table.clear(tbl)
		return
	end
	for key in pairs(tbl) do
		tbl[key] = nil
	end
end

local function sq(props)
	local d = Drawing.new("Square")
	d.Filled = props.Filled ~= false
	d.Thickness = props.Thickness or 1
	d.Color = props.Color or THEME.text
	d.Visible = false
	d.Transparency = props.Transparency or 1
	return d
end

local function txt(props)
	local d = Drawing.new("Text")
	d.Size = props.Size or 14
	d.Color = props.Color or THEME.text
	d.Outline = true
	d.Center = props.Center or false
	d.Visible = false
	d.Transparency = props.Transparency or 1
	return d
end

local function inRect(p, pos, size)
	return p.X >= pos.X and p.X <= pos.X + size.X and p.Y >= pos.Y and p.Y <= pos.Y + size.Y
end

local function pointerPos(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	return UserInputService:GetMouseLocation()
end

local function isMobile()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return true
	end
	return UserInputService:GetLastInputType() == Enum.UserInputType.Touch
end

local function shallowCopy(tbl)
	if table.clone then
		return table.clone(tbl)
	end
	local copy = {}
	for key, value in pairs(tbl) do
		copy[key] = value
	end
	return copy
end

local function normalizeItem(item)
	if item.type then
		return item
	end
	if item.key and item.label then
		return {
			type = "toggle",
			key = item.key,
			label = item.label,
			hud = item.hud,
		}
	end
	return item
end

local function normalizeSection(section)
	local items = {}
	if section.items then
		for _, item in ipairs(section.items) do
			table.insert(items, normalizeItem(item))
		end
	end
	if section.toggles then
		for _, toggle in ipairs(section.toggles) do
			table.insert(items, normalizeItem(toggle))
		end
	end
	return {
		title = section.title,
		collapsed = section.collapsed,
		items = items,
	}
end

local function buildPages(options)
	if typeof(options.pages) == "table" and #options.pages > 0 then
		local pages = {}
		for _, page in ipairs(options.pages) do
			local sections = {}
			for _, section in ipairs(page.sections or {}) do
				table.insert(sections, normalizeSection(section))
			end
			table.insert(pages, { label = page.label or "Page", sections = sections })
		end
		return pages
	end

	local sections = {}
	for _, section in ipairs(options.sections or {}) do
		table.insert(sections, normalizeSection(section))
	end

	local footerItems = (options.footer and options.footer.items) or {}
	if #footerItems > 0 then
		local footerSection = { title = "ACTIONS", items = {} }
		for index, item in ipairs(footerItems) do
			local copy = shallowCopy(item)
			copy._id = copy.id or copy.key or ("footer_" .. index)
			table.insert(footerSection.items, copy)
		end
		table.insert(sections, footerSection)
	end

	return { { label = "Menu", sections = sections } }
end

local HubUI = {}
HubUI.__index = HubUI

function HubUI.new(options)
	local self = setmetatable({}, HubUI)

	self.title = options.title or "MicroHub"
	self.config = options.config
	self.pages = buildPages(options)
	self.toggleKey = options.toggleKey or Enum.KeyCode.RightShift
	self.mobileToggleKey = options.mobileToggleKey or Enum.KeyCode.ButtonY
	self.dragHint = options.dragHint or (isMobile() and "Drag title bar" or "Drag title bar")
	self.onToggle = options.onToggle
	self.onChange = options.onChange
	self.onMenuVisible = options.onMenuVisible
	self.hudShowKey = (options.hud and options.hud.showKey) or "ShowHUD"
	self.hudEnabled = options.hud and options.hud.enabled == true

	self.menuVisible = options.startVisible ~= false
	self.activePage = 1
	self.scrollY = 0
	self.maxScroll = 0
	self.mobile = isMobile()

	self.X = self.mobile and 12 or 16
	self.Y = self.mobile and 48 or 16
	self.Width = options.width or (self.mobile and math.min(340, Camera.ViewportSize.X - 24) or 340)
	self.HeaderHeight = self.mobile and 40 or 36
	self.TabHeight = 30
	self.RowHeight = self.mobile and 30 or 22
	self.SliderHeight = self.mobile and 40 or 34
	self.SelectHeight = self.mobile and 38 or 32
	self.SectionHeader = 20
	self.SectionGap = 8
	self.Padding = 12
	self.Columns = self.mobile and 1 or 2
	self.ColGap = 10
	self.Dragging = false
	self.DragOffset = Vector2.zero
	self.draggingSlider = nil
	self.scrollTouch = nil
	self.savedMouseBehavior = nil
	self._inputConns = {}

	self.toggles = {}
	for _, page in ipairs(self.pages) do
		for _, section in ipairs(page.sections) do
			for _, item in ipairs(section.items) do
				if item.type == "toggle" and item.key then
					table.insert(self.toggles, item)
				end
			end
		end
	end

	self.drawings = {
		bg = sq({ Color = THEME.bg }),
		border = sq({ Filled = false, Color = THEME.border, Thickness = 2 }),
		header = sq({ Color = THEME.header }),
		accent = sq({ Color = THEME.accent }),
		title = txt({ Size = 16 }),
		hint = txt({ Size = 11, Color = THEME.muted }),
		tabs = {},
		fab = sq({ Color = THEME.mobileFab }),
		fabText = txt({ Size = 18, Center = true, Color = THEME.text }),
		scrollTrack = sq({ Color = THEME.track }),
		scrollThumb = sq({ Color = THEME.accentSoft }),
		dynamic = {},
		hud = {
			bg = sq({ Color = THEME.hudBg }),
			border = sq({ Filled = false, Color = THEME.hudBorder }),
			accent = sq({ Color = THEME.hudAccent }),
			title = txt({ Size = 12, Color = THEME.hudTitle }),
			empty = txt({ Size = 12, Color = THEME.muted }),
			lines = {},
		},
	}

	self.hudWidth = 148
	self.hudPadding = 10
	self.hudLineHeight = 15

	self:_bindInput()
	self:setMenuVisible(self.menuVisible)

	self._renderConn = RunService.RenderStepped:Connect(function()
		self:_layout()
		self:_draw()
	end)

	return self
end

function HubUI:_contentWidth()
	return self.Width - self.Padding * 2
end

function HubUI:_columnWidth()
	if self.Columns <= 1 then
		return self:_contentWidth()
	end
	return (self:_contentWidth() - self.ColGap) / self.Columns
end

function HubUI:_itemHeight(item)
	if item.type == "slider" or item.type == "number" then
		return self.SliderHeight
	elseif item.type == "select" or item.type == "color" then
		return self.SelectHeight
	elseif item.type == "button" then
		return self.mobile and 34 or 28
	elseif item.type == "hint" then
		return self.mobile and 18 or 14
	elseif item.type == "separator" then
		return 10
	elseif item.type == "label" then
		return 16
	end
	return self.RowHeight
end

function HubUI:_pageContentHeight(page)
	local h = self.Padding
	for _, section in ipairs(page.sections) do
		if section.title and section.title ~= "" then
			h = h + self.SectionHeader
		end
		local toggles, others = {}, {}
		for _, item in ipairs(section.items) do
			if item.type == "toggle" then
				table.insert(toggles, item)
			else
				table.insert(others, item)
			end
		end
		if self.Columns > 1 then
			h = h + math.ceil(#toggles / self.Columns) * self.RowHeight
		else
			h = h + #toggles * self.RowHeight
		end
		for _, item in ipairs(others) do
			h = h + self:_itemHeight(item)
		end
		h = h + self.SectionGap
	end
	return h
end

function HubUI:_maxBodyHeight()
	return math.floor(Camera.ViewportSize.Y * 0.72)
end

function HubUI:_chromeHeight()
	local tabs = #self.pages > 1 and self.TabHeight or 0
	return self.HeaderHeight + tabs
end

function HubUI:_menuHeight()
	local page = self.pages[self.activePage]
	local body = math.min(self:_pageContentHeight(page), self:_maxBodyHeight())
	self.maxScroll = math.max(0, self:_pageContentHeight(page) - body)
	self.scrollY = math.clamp(self.scrollY, 0, self.maxScroll)
	return self:_chromeHeight() + body + self.Padding
end

function HubUI:_getToggleSlots(page)
	local slots = {}
	local cursorY = 0
	for _, section in ipairs(page.sections) do
		if section.title and section.title ~= "" then
			cursorY = cursorY + self.SectionHeader
		end
		local toggles = {}
		for _, item in ipairs(section.items) do
			if item.type == "toggle" then
				table.insert(toggles, item)
			end
		end
		local colW = self:_columnWidth()
		for index = 1, #toggles, self.Columns do
			local rowY = cursorY
			for col = 0, self.Columns - 1 do
				local toggle = toggles[index + col]
				if toggle then
					table.insert(slots, {
						item = toggle,
						x = self.Padding + col * (colW + self.ColGap),
						y = rowY,
						w = colW,
						h = self.RowHeight,
					})
				end
			end
			cursorY = cursorY + self.RowHeight
		end
		for _, item in ipairs(section.items) do
			if item.type ~= "toggle" then
				cursorY = cursorY + self:_itemHeight(item)
			end
		end
		cursorY = cursorY + self.SectionGap
	end
	return slots
end

function HubUI:_layout()
	-- dynamic layout cache rebuilt each frame in _draw body
end

function HubUI:setMenuVisible(visible)
	self.menuVisible = visible
	if visible then
		self.Dragging = false
		self.draggingSlider = nil
		self.savedMouseBehavior = UserInputService.MouseBehavior
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	else
		self:_hideMenuDrawings()
		self:_hideHud()
		self:_clearDynamic()
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
	for _, conn in ipairs(self._inputConns or {}) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	clearTable(self._inputConns)
	local function rm(d)
		if typeof(d) == "userdata" then
			d:Remove()
		elseif typeof(d) == "table" then
			for _, child in pairs(d) do
				rm(child)
			end
		end
	end
	for _, v in pairs(self.drawings) do
		rm(v)
	end
	clearTable(self.drawings.dynamic)
end

function HubUI:_notifyChange(item, value)
	if item.onChange then
		item.onChange(value)
	end
	if self.onChange then
		self.onChange(item.key, value, item.type)
	end
	if item.type == "toggle" and self.onToggle then
		self.onToggle(item.key, value)
	end
end

function HubUI:_clampSlider(item, value)
	local minV = item.min or 0
	local maxV = item.max or 100
	local step = item.step or 1
	value = math.clamp(value, minV, maxV)
	if step > 0 then
		value = minV + math.floor((value - minV) / step + 0.5) * step
	end
	return math.clamp(value, minV, maxV)
end

function HubUI:_sliderValueFromX(item, trackX, trackW, pointerX)
	local minV = item.min or 0
	local maxV = item.max or 100
	local alpha = math.clamp((pointerX - trackX) / trackW, 0, 1)
	return self:_clampSlider(item, minV + (maxV - minV) * alpha)
end

function HubUI:_cycleColor(current)
	for index, preset in ipairs(COLOR_PRESETS) do
		if preset == current then
			return COLOR_PRESETS[(index % #COLOR_PRESETS) + 1]
		end
	end
	return COLOR_PRESETS[1]
end

function HubUI:_colorPresetIndex(color)
	for index, preset in ipairs(COLOR_PRESETS) do
		if preset == color then
			return index
		end
	end
	return 1
end

function HubUI:_hitTest(pointer)
	if not self.menuVisible then
		if self.mobile and inRect(pointer, self:_fabRect().pos, self:_fabRect().size) then
			return { kind = "fab" }
		end
		return nil
	end

	local x, y = self.X, self.Y
	local h = self:_menuHeight()

	if not inRect(pointer, Vector2.new(x, y), Vector2.new(self.Width, h)) then
		return { kind = "outside" }
	end

	if inRect(pointer, Vector2.new(x, y), Vector2.new(self.Width, self.HeaderHeight)) then
		return { kind = "header" }
	end

	if #self.pages > 1 then
		local tabY = y + self.HeaderHeight
		local tabW = self.Width / #self.pages
		for index = 1, #self.pages do
			if inRect(pointer, Vector2.new(x + (index - 1) * tabW, tabY), Vector2.new(tabW, self.TabHeight)) then
				return { kind = "tab", index = index }
			end
		end
	end

	local bodyY = y + self:_chromeHeight()
	local page = self.pages[self.activePage]
	local cursorY = bodyY + self.Padding - self.scrollY

	for _, section in ipairs(page.sections) do
		cursorY = cursorY + (section.title and section.title ~= "" and self.SectionHeader or 0)

		local toggles = {}
		for _, item in ipairs(section.items) do
			if item.type == "toggle" then
				table.insert(toggles, item)
			end
		end
		local colW = self:_columnWidth()
		for index = 1, #toggles, self.Columns do
			for col = 0, self.Columns - 1 do
				local item = toggles[index + col]
				if item then
					local ix = x + self.Padding + col * (colW + self.ColGap)
					local iy = cursorY
					if inRect(pointer, Vector2.new(ix, iy), Vector2.new(colW, self.RowHeight)) then
						return { kind = "toggle", item = item }
					end
				end
			end
			cursorY = cursorY + self.RowHeight
		end

		for _, item in ipairs(section.items) do
			if item.type == "toggle" then
				-- toggles handled above
			else
			local ih = self:_itemHeight(item)
			local ix = x + self.Padding
			local iw = self:_contentWidth()
				if inRect(pointer, Vector2.new(ix, cursorY), Vector2.new(iw, ih)) then
					return { kind = item.type, item = item, rect = { x = ix, y = cursorY, w = iw, h = ih } }
				end
				cursorY = cursorY + ih
			end
		end
		cursorY = cursorY + self.SectionGap
	end

	return { kind = "body" }
end

function HubUI:_fabRect()
	local size = self.mobile and 46 or 0
	return {
		pos = Vector2.new(14, Camera.ViewportSize.Y - size - 14),
		size = Vector2.new(size, size),
	}
end

function HubUI:_handlePointerDown(pointer)
	local hit = self:_hitTest(pointer)
	if not hit then
		return
	end

	if hit.kind == "fab" then
		self:setMenuVisible(true)
		return
	end

	if hit.kind == "outside" then
		self:setMenuVisible(false)
		return
	end

	if hit.kind == "header" then
		self.Dragging = true
		self.DragOffset = pointer - Vector2.new(self.X, self.Y)
		return
	end

	if hit.kind == "tab" then
		self.activePage = hit.index
		self.scrollY = 0
		return
	end

	if hit.kind == "toggle" and hit.item.key then
		self.config[hit.item.key] = not self.config[hit.item.key]
		self:_notifyChange(hit.item, self.config[hit.item.key])
		return
	end

	if hit.kind == "slider" and hit.item.key then
		local trackX = hit.rect.x
		local trackW = hit.rect.w - (self.mobile and 8 or 4)
		local value = self:_sliderValueFromX(hit.item, trackX, trackW, pointer.X)
		self.config[hit.item.key] = value
		self:_notifyChange(hit.item, value)
		self.draggingSlider = { item = hit.item, trackX = trackX, trackW = trackW }
		return
	end

	if hit.kind == "number" and hit.item.key then
		local rect = hit.rect
		local btn = self.mobile and 34 or 28
		if inRect(pointer, Vector2.new(rect.x + rect.w - btn * 2 - 6, rect.y + 4), Vector2.new(btn, rect.h - 8)) then
			local step = hit.item.step or 1
			self.config[hit.item.key] = self:_clampSlider(hit.item, self.config[hit.item.key] - step)
			self:_notifyChange(hit.item, self.config[hit.item.key])
		elseif inRect(pointer, Vector2.new(rect.x + rect.w - btn - 2, rect.y + 4), Vector2.new(btn, rect.h - 8)) then
			local step = hit.item.step or 1
			self.config[hit.item.key] = self:_clampSlider(hit.item, self.config[hit.item.key] + step)
			self:_notifyChange(hit.item, self.config[hit.item.key])
		end
		return
	end

	if hit.kind == "select" and hit.item.key then
		local options = hit.item.options or {}
		if #options == 0 then
			return
		end
		local rect = hit.rect
		local pillY = rect.y + 16
		local pillH = self.mobile and 22 or 18
		local offsetX = 0
		local iw = rect.w
		for index, option in ipairs(options) do
			local val = typeof(option) == "table" and option.value or option
			local name = typeof(option) == "table" and (option.label or tostring(option.value)) or tostring(option)
			local pw = math.min(math.max(#name * 7 + 14, 42), iw - offsetX)
			if offsetX + pw > iw then
				break
			end
			local px = rect.x + offsetX
			if inRect(pointer, Vector2.new(px, pillY), Vector2.new(pw, pillH)) then
				self.config[hit.item.key] = val
				self:_notifyChange(hit.item, val)
				return
			end
			offsetX = offsetX + pw + 6
		end
		local current = self.config[hit.item.key]
		local nextIndex = 1
		for index, option in ipairs(options) do
			local val = typeof(option) == "table" and option.value or option
			if val == current then
				nextIndex = (index % #options) + 1
				break
			end
		end
		local picked = options[nextIndex]
		local value = typeof(picked) == "table" and picked.value or picked
		self.config[hit.item.key] = value
		self:_notifyChange(hit.item, value)
		return
	end

	if hit.kind == "color" and hit.item.key then
		local swatchSize = self.mobile and 24 or 20
		local rect = hit.rect
		local presets = hit.item.presets or COLOR_PRESETS
		for index = 1, #presets do
			local sx = rect.x + (index - 1) * (swatchSize + 4)
			local sy = rect.y + rect.h - swatchSize - 4
			if inRect(pointer, Vector2.new(sx, sy), Vector2.new(swatchSize, swatchSize)) then
				self.config[hit.item.key] = presets[index]
				self:_notifyChange(hit.item, presets[index])
				return
			end
		end
		self.config[hit.item.key] = self:_cycleColor(self.config[hit.item.key])
		self:_notifyChange(hit.item, self.config[hit.item.key])
		return
	end

	if hit.kind == "button" and hit.item then
		local canClick = not hit.item.canClick or hit.item.canClick()
		if canClick and hit.item.onClick then
			hit.item.onClick()
		end
		return
	end

	if hit.kind == "body" then
		self.scrollTouch = { y = pointer.Y, scroll = self.scrollY }
	end
end

function HubUI:_handlePointerMove(pointer)
	if self.draggingSlider then
		local ds = self.draggingSlider
		local value = self:_sliderValueFromX(ds.item, ds.trackX, ds.trackW, pointer.X)
		if self.config[ds.item.key] ~= value then
			self.config[ds.item.key] = value
			self:_notifyChange(ds.item, value)
		end
	elseif self.Dragging then
		self.X = math.clamp(pointer.X - self.DragOffset.X, 0, Camera.ViewportSize.X - self.Width)
		self.Y = math.clamp(pointer.Y - self.DragOffset.Y, 0, Camera.ViewportSize.Y - self:_menuHeight())
	end
end

function HubUI:_shouldIgnoreProcessed(input, processed)
	if not processed then
		return false
	end
	if input.UserInputType == Enum.UserInputType.Touch then
		return false
	end
	if self.menuVisible and input.UserInputType == Enum.UserInputType.MouseButton1 then
		return false
	end
	return true
end

function HubUI:_bindInput()
	table.insert(self._inputConns, UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == self.toggleKey or input.KeyCode == self.mobileToggleKey then
			self:setMenuVisible(not self.menuVisible)
			return
		end
		if self:_shouldIgnoreProcessed(input, processed) then
			return
		end
		if not self.menuVisible and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self:_handlePointerDown(pointerPos(input))
		end
	end))

	table.insert(self._inputConns, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self.Dragging = false
			self.draggingSlider = nil
			self.scrollTouch = nil
		end
	end))

	table.insert(self._inputConns, UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if self.Dragging or self.draggingSlider then
				self:_handlePointerMove(UserInputService:GetMouseLocation())
			end
		elseif input.UserInputType == Enum.UserInputType.Touch then
			local pointer = pointerPos(input)
			if self.scrollTouch and not self.Dragging and not self.draggingSlider then
				local delta = pointer.Y - self.scrollTouch.y
				self.scrollY = math.clamp(self.scrollTouch.scroll - delta, 0, self.maxScroll)
			elseif self.Dragging or self.draggingSlider then
				self:_handlePointerMove(pointer)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and self.menuVisible then
			self.scrollY = math.clamp(self.scrollY - input.Position.Z * 24, 0, self.maxScroll)
		end
	end))
end

function HubUI:_clearDynamic()
	for _, d in ipairs(self.drawings.dynamic) do
		if typeof(d) == "userdata" then
			d:Remove()
		end
	end
	clearTable(self.drawings.dynamic)
end

function HubUI:_dynSquare(props)
	local d = sq(props)
	table.insert(self.drawings.dynamic, d)
	return d
end

function HubUI:_dynText(props)
	local d = txt(props)
	table.insert(self.drawings.dynamic, d)
	return d
end

function HubUI:_hideMenuDrawings()
	self.drawings.bg.Visible = false
	self.drawings.border.Visible = false
	self.drawings.header.Visible = false
	self.drawings.accent.Visible = false
	self.drawings.title.Visible = false
	self.drawings.hint.Visible = false
	self.drawings.scrollTrack.Visible = false
	self.drawings.scrollThumb.Visible = false
end

function HubUI:_hideHud()
	local hud = self.drawings.hud
	hud.bg.Visible = false
	hud.border.Visible = false
	hud.accent.Visible = false
	hud.title.Visible = false
	hud.empty.Visible = false
	for _, line in ipairs(hud.lines) do
		line.Visible = false
	end
end

function HubUI:_drawHud()
	if not self.hudEnabled or self.menuVisible then
		self:_hideHud()
		return
	end

	local hud = self.drawings.hud
	local modules = {}
	for _, toggle in ipairs(self.toggles) do
		if toggle.hud and self.config[toggle.key] then
			table.insert(modules, toggle.hud)
		end
	end
	while #hud.lines < #modules do
		table.insert(hud.lines, txt({ Size = 13, Color = THEME.hudLine }))
	end
	if not self.config[self.hudShowKey] or #modules == 0 then
		self:_hideHud()
		return
	end
	local count = #modules
	local height = 24 + count * self.hudLineHeight + self.hudPadding
	local hudX = Camera.ViewportSize.X - self.hudWidth - 14
	local hudY = 14
	hud.bg.Position = Vector2.new(hudX, hudY)
	hud.bg.Size = Vector2.new(self.hudWidth, height)
	hud.bg.Visible = true
	hud.border.Position = Vector2.new(hudX, hudY)
	hud.border.Size = Vector2.new(self.hudWidth, height)
	hud.border.Visible = true
	hud.accent.Position = Vector2.new(hudX, hudY)
	hud.accent.Size = Vector2.new(3, height)
	hud.accent.Visible = true
	hud.title.Position = Vector2.new(hudX + self.hudPadding + 4, hudY + 5)
	hud.title.Text = "ACTIVE"
	hud.title.Visible = true
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

function HubUI:_draw()
	self:_clearDynamic()

	if self.mobile then
		local fab = self:_fabRect()
		self.drawings.fab.Position = fab.pos
		self.drawings.fab.Size = fab.size
		self.drawings.fab.Visible = not self.menuVisible
		self.drawings.fabText.Position = fab.pos + fab.size * 0.5
		self.drawings.fabText.Text = "☰"
		self.drawings.fabText.Visible = not self.menuVisible
	else
		self.drawings.fab.Visible = false
		self.drawings.fabText.Visible = false
	end

	if not self.menuVisible then
		self:_hideMenuDrawings()
		self:_drawHud()
		return
	end

	self:_drawHud()

	local visible = true
	local x, y = self.X, self.Y
	local height = self:_menuHeight()
	local page = self.pages[self.activePage]

	self.drawings.bg.Position = Vector2.new(x, y)
	self.drawings.bg.Size = Vector2.new(self.Width, height)
	self.drawings.bg.Visible = visible
	self.drawings.border.Position = Vector2.new(x, y)
	self.drawings.border.Size = Vector2.new(self.Width, height)
	self.drawings.border.Visible = visible
	self.drawings.header.Position = Vector2.new(x, y)
	self.drawings.header.Size = Vector2.new(self.Width, self.HeaderHeight)
	self.drawings.header.Visible = visible
	self.drawings.accent.Position = Vector2.new(x, y + self.HeaderHeight - 2)
	self.drawings.accent.Size = Vector2.new(self.Width, 2)
	self.drawings.accent.Visible = visible
	self.drawings.title.Position = Vector2.new(x + self.Padding, y + (self.mobile and 11 or 9))
	self.drawings.title.Text = self.title
	self.drawings.title.Visible = visible
	self.drawings.hint.Position = Vector2.new(x + self.Width - 88, y + (self.mobile and 13 or 11))
	self.drawings.hint.Text = self.dragHint
	self.drawings.hint.Visible = visible

	if #self.pages > 1 then
		local tabY = y + self.HeaderHeight
		local tabW = self.Width / #self.pages
		for index, tabPage in ipairs(self.pages) do
			local active = index == self.activePage
			local tabBg = self:_dynSquare({
				Color = active and THEME.accentSoft or THEME.pill,
			})
			tabBg.Position = Vector2.new(x + (index - 1) * tabW, tabY)
			tabBg.Size = Vector2.new(tabW, self.TabHeight)
			tabBg.Visible = visible
			local tabText = self:_dynText({
				Size = 13,
				Center = true,
				Color = active and THEME.text or THEME.muted,
			})
			tabText.Position = Vector2.new(x + (index - 1) * tabW + tabW * 0.5, tabY + 8)
			tabText.Text = tabPage.label
			tabText.Visible = visible
		end
	end

	local bodyTop = y + self:_chromeHeight()
	local bodyHeight = height - self:_chromeHeight() - self.Padding
	local cursorY = bodyTop + self.Padding - self.scrollY

	for _, section in ipairs(page.sections) do
		if section.title and section.title ~= "" then
			local label = self:_dynText({ Size = 11, Color = THEME.section })
			label.Position = Vector2.new(x + self.Padding, cursorY)
			label.Text = string.upper(section.title)
			label.Visible = visible and cursorY + self.SectionHeader >= bodyTop and cursorY <= bodyTop + bodyHeight
			local line = self:_dynSquare({ Color = THEME.border })
			line.Position = Vector2.new(x + self.Padding + 64, cursorY + 7)
			line.Size = Vector2.new(self.Width - self.Padding * 2 - 64, 1)
			line.Visible = label.Visible
			cursorY = cursorY + self.SectionHeader
		end

		local toggles = {}
		local others = {}
		for _, item in ipairs(section.items) do
			if item.type == "toggle" then
				table.insert(toggles, item)
			else
				table.insert(others, item)
			end
		end

		local colW = self:_columnWidth()
		for index = 1, #toggles, self.Columns do
			for col = 0, self.Columns - 1 do
				local item = toggles[index + col]
				if item then
				local ix = x + self.Padding + col * (colW + self.ColGap)
				local iy = cursorY
				local onScreen = iy + self.RowHeight >= bodyTop and iy <= bodyTop + bodyHeight
				local enabled = self.config[item.key]
				local pill = self:_dynSquare({
					Color = enabled and THEME.on or THEME.off,
				})
				pill.Position = Vector2.new(ix + colW - (self.mobile and 40 or 34), iy + 4)
				pill.Size = Vector2.new(self.mobile and 36 or 30, self.mobile and 18 or 14)
				pill.Visible = visible and onScreen
				local knob = self:_dynSquare({ Color = THEME.text })
				knob.Size = Vector2.new(self.mobile and 14 or 12, self.mobile and 14 or 12)
				if enabled then
					knob.Position = pill.Position + Vector2.new(pill.Size.X - knob.Size.X - 2, 2)
				else
					knob.Position = pill.Position + Vector2.new(2, 2)
				end
				knob.Visible = pill.Visible
				local label = self:_dynText({ Size = self.mobile and 15 or 14, Color = enabled and THEME.text or THEME.muted })
				label.Position = Vector2.new(ix, iy + 2)
				label.Text = item.label
				label.Visible = visible and onScreen
				end
			end
			cursorY = cursorY + self.RowHeight
		end

		for _, item in ipairs(others) do
			local ih = self:_itemHeight(item)
			local ix = x + self.Padding
			local iw = self:_contentWidth()
			local iy = cursorY
			local onScreen = iy + ih >= bodyTop and iy <= bodyTop + bodyHeight

			if item.type == "slider" or item.type == "number" then
				local value = self.config[item.key]
				local label = self:_dynText({ Size = 13 })
				label.Position = Vector2.new(ix, iy)
				label.Text = (item.label or item.key) .. ": " .. tostring(value)
				label.Visible = visible and onScreen
				local trackY = iy + (item.type == "number" and 18 or 16)
				local trackH = self.mobile and 10 or 8
				local trackW = iw - (item.type == "number" and (self.mobile and 76 or 64) or 0)
				local track = self:_dynSquare({ Color = THEME.track })
				track.Position = Vector2.new(ix, trackY)
				track.Size = Vector2.new(trackW, trackH)
				track.Visible = visible and onScreen
				local minV, maxV = item.min or 0, item.max or 100
				local alpha = (value - minV) / math.max(maxV - minV, 0.001)
				local fill = self:_dynSquare({ Color = THEME.trackFill })
				fill.Position = track.Position
				fill.Size = Vector2.new(trackW * alpha, trackH)
				fill.Visible = track.Visible
				if item.type == "number" then
					for bi, sign in ipairs({ "-", "+" }) do
						local btn = self:_dynSquare({ Color = THEME.button })
						local bw = self.mobile and 34 or 28
						btn.Position = Vector2.new(ix + iw - bw * (3 - bi) - (bi - 1) * 4, iy + 14)
						btn.Size = Vector2.new(bw, ih - 16)
						btn.Visible = visible and onScreen
						local bt = self:_dynText({ Size = 16, Center = true })
						bt.Position = btn.Position + btn.Size * 0.5
						bt.Text = sign
						bt.Visible = btn.Visible
					end
				end
			elseif item.type == "select" then
				local label = self:_dynText({ Size = 13, Color = THEME.muted })
				label.Position = Vector2.new(ix, iy)
				label.Text = item.label or item.key
				label.Visible = visible and onScreen
				local options = item.options or {}
				local pillY = iy + 16
				local offsetX = 0
				for _, option in ipairs(options) do
					local val = typeof(option) == "table" and option.value or option
					local name = typeof(option) == "table" and (option.label or tostring(option.value)) or tostring(option)
					local active = self.config[item.key] == val
					local pw = math.min(math.max(#name * 7 + 14, 42), iw - offsetX)
					if offsetX + pw > iw then
						break
					end
					local pill = self:_dynSquare({ Color = active and THEME.pillActive or THEME.pill })
					pill.Position = Vector2.new(ix + offsetX, pillY)
					pill.Size = Vector2.new(pw, self.mobile and 22 or 18)
					pill.Visible = visible and onScreen
					local pt = self:_dynText({ Size = 12, Center = true, Color = active and THEME.text or THEME.muted })
					pt.Position = pill.Position + pill.Size * 0.5
					pt.Text = name
					pt.Visible = pill.Visible
					offsetX = offsetX + pw + 6
				end
			elseif item.type == "color" then
				local color = self.config[item.key]
				if typeof(color) ~= "Color3" then
					color = COLOR_PRESETS[1]
				end
				local label = self:_dynText({ Size = 13 })
				label.Position = Vector2.new(ix, iy)
				label.Text = item.label or item.key
				label.Visible = visible and onScreen
				local presets = item.presets or COLOR_PRESETS
				local sw = self.mobile and 24 or 20
				for pi, preset in ipairs(presets) do
					local swatch = self:_dynSquare({ Color = preset })
					swatch.Position = Vector2.new(ix + (pi - 1) * (sw + 4), iy + ih - sw - 2)
					swatch.Size = Vector2.new(sw, sw)
					swatch.Visible = visible and onScreen
					if preset == color then
						local ring = self:_dynSquare({ Filled = false, Color = THEME.text, Thickness = 2 })
						ring.Position = swatch.Position - Vector2.new(1, 1)
						ring.Size = swatch.Size + Vector2.new(2, 2)
						ring.Visible = swatch.Visible
					end
				end
			elseif item.type == "button" then
				local labelText = item.getLabel and item.getLabel() or item.label or "Action"
				local btn = self:_dynSquare({ Color = item.color or THEME.buttonDanger })
				btn.Position = Vector2.new(ix, iy)
				btn.Size = Vector2.new(iw, ih)
				btn.Visible = visible and onScreen
				local bt = self:_dynText({ Size = 13, Center = true })
				bt.Position = Vector2.new(ix + iw * 0.5, iy + ih * 0.5 - 6)
				bt.Text = labelText
				bt.Visible = btn.Visible
			elseif item.type == "hint" then
				local label = self:_dynText({ Size = 10, Color = THEME.muted })
				label.Position = Vector2.new(ix, iy)
				label.Text = item.getText and item.getText() or item.text or ""
				label.Visible = visible and onScreen
			elseif item.type == "separator" then
				local line = self:_dynSquare({ Color = THEME.border })
				line.Position = Vector2.new(ix, iy + 4)
				line.Size = Vector2.new(iw, 1)
				line.Visible = visible and onScreen
			elseif item.type == "label" then
				local label = self:_dynText({ Size = 12, Color = THEME.muted })
				label.Position = Vector2.new(ix, iy)
				label.Text = item.text or ""
				label.Visible = visible and onScreen
			end
			cursorY = cursorY + ih
		end
		cursorY = cursorY + self.SectionGap
	end

	if self.maxScroll > 0 and visible then
		local trackH = bodyHeight
		local thumbH = math.max(24, trackH * (trackH / (trackH + self.maxScroll)))
		local thumbY = bodyTop + (self.scrollY / self.maxScroll) * (trackH - thumbH)
		self.drawings.scrollTrack.Position = Vector2.new(x + self.Width - 5, bodyTop)
		self.drawings.scrollTrack.Size = Vector2.new(3, trackH)
		self.drawings.scrollTrack.Visible = true
		self.drawings.scrollThumb.Position = Vector2.new(x + self.Width - 5, thumbY)
		self.drawings.scrollThumb.Size = Vector2.new(3, thumbH)
		self.drawings.scrollThumb.Visible = true
	else
		self.drawings.scrollTrack.Visible = false
		self.drawings.scrollThumb.Visible = false
	end
end

return {
	version = "2.1.0",
	create = function(options)
		return HubUI.new(options)
	end,
	theme = THEME,
	colorPresets = COLOR_PRESETS,
}
