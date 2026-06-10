--[[
	MicroHub UI v3.0.0 — Cascade-backed adapter.

	The game scripts still call:
		UILib.create({ title, config, pages, onToggle, onChange, ... })

	This file imports Cascade v1.4.0 and maps MicroHub's small schema onto
	Cascade windows, tabs, forms, rows, and controls.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local CASCADE_VERSION = "v1.4.0"
local CASCADE_URL = "https://github.com/cascadeui/Cascade/releases/download/" .. CASCADE_VERSION .. "/dist.luau"
local VERSION = "3.0.0"

local COLOR_PRESETS = {
	{ name = "Red", value = Color3.fromRGB(255, 75, 75) },
	{ name = "Green", value = Color3.fromRGB(75, 220, 120) },
	{ name = "Yellow", value = Color3.fromRGB(255, 220, 80) },
	{ name = "Indigo", value = Color3.fromRGB(99, 102, 241) },
	{ name = "Orange", value = Color3.fromRGB(255, 140, 60) },
	{ name = "Sky", value = Color3.fromRGB(120, 200, 255) },
	{ name = "Purple", value = Color3.fromRGB(220, 120, 255) },
	{ name = "White", value = Color3.fromRGB(255, 255, 255) },
}

local cascadeCache = nil

local function clearTable(tbl)
	if table.clear then
		table.clear(tbl)
		return
	end
	for key in pairs(tbl) do
		tbl[key] = nil
	end
end

local function requestFn()
	if typeof(request) == "function" then
		return request
	end
	if typeof(http_request) == "function" then
		return http_request
	end
	if syn and typeof(syn.request) == "function" then
		return syn.request
	end
	if http and typeof(http.request) == "function" then
		return http.request
	end
	if fluxus and typeof(fluxus.request) == "function" then
		return fluxus.request
	end
	return nil
end

local function statusOk(res)
	local status = tonumber(res.StatusCode or res.Status or res.status_code)
	if res.Success == true then
		return true
	end
	if res.Success == false then
		return false
	end
	return status ~= nil and status >= 200 and status < 300
end

local function fetchUrl(url)
	local http = requestFn()
	if typeof(http) == "function" then
		local ok, res = pcall(http, {
			Url = url .. "?t=" .. tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999)),
			Method = "GET",
			Headers = {
				["Cache-Control"] = "no-cache, no-store",
				["Pragma"] = "no-cache",
				["User-Agent"] = "MicroHub-Cascade/" .. VERSION,
			},
		})
		if ok and res and statusOk(res) and typeof(res.Body or res.body) == "string" then
			return res.Body or res.body
		end
	end

	if game.HttpGetAsync then
		local ok, body = pcall(function()
			return game:HttpGetAsync(url, true)
		end)
		if ok and typeof(body) == "string" and #body > 0 then
			return body
		end
	end

	error("Unable to download Cascade " .. CASCADE_VERSION, 0)
end

local function importCascade()
	if cascadeCache then
		return cascadeCache
	end

	local source = fetchUrl(CASCADE_URL)
	local fn, err = loadstring(source, "Cascade." .. CASCADE_VERSION)
	if not fn then
		error("Cascade compile failed: " .. tostring(err), 0)
	end

	local ok, cascade = pcall(fn)
	if not ok or typeof(cascade) ~= "table" then
		error("Cascade load failed: " .. tostring(cascade), 0)
	end

	cascadeCache = cascade
	return cascade
end

local function shallowCopy(tbl)
	local copy = {}
	for key, value in pairs(tbl or {}) do
		copy[key] = value
	end
	return copy
end

local function normalizeItem(item)
	if item.type then
		return item
	end
	if item.key and item.label then
		local copy = shallowCopy(item)
		copy.type = "toggle"
		return copy
	end
	return item
end

local function normalizeSection(section)
	local items = {}
	for _, item in ipairs(section.items or {}) do
		table.insert(items, normalizeItem(item))
	end
	for _, item in ipairs(section.toggles or {}) do
		table.insert(items, normalizeItem(item))
	end
	return {
		title = section.title,
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
			table.insert(pages, {
				label = page.label or "Page",
				sections = sections,
			})
		end
		return pages
	end

	local sections = {}
	for _, section in ipairs(options.sections or {}) do
		table.insert(sections, normalizeSection(section))
	end

	local footerItems = (options.footer and options.footer.items) or {}
	if #footerItems > 0 then
		local footer = { title = "ACTIONS", items = {} }
		for _, item in ipairs(footerItems) do
			table.insert(footer.items, normalizeItem(item))
		end
		table.insert(sections, footer)
	end

	return { { label = "Menu", sections = sections } }
end

local function optionValue(option)
	return typeof(option) == "table" and option.value or option
end

local function optionLabel(option)
	if typeof(option) == "table" then
		return tostring(option.label or option.value)
	end
	return tostring(option)
end

local function findOptionIndex(options, value)
	for index, option in ipairs(options or {}) do
		if optionValue(option) == value then
			return index
		end
	end
	return 1
end

local function colorIndex(color, presets)
	for index, preset in ipairs(presets) do
		if preset.value == color then
			return index
		end
	end
	return 1
end

local function clamp(value, minV, maxV)
	if value < minV then
		return minV
	elseif value > maxV then
		return maxV
	end
	return value
end

local function snap(value, minV, maxV, step)
	value = clamp(value, minV, maxV)
	if step and step > 0 then
		value = minV + math.floor((value - minV) / step + 0.5) * step
	end
	return clamp(value, minV, maxV)
end

local HubUI = {}
HubUI.__index = HubUI

function HubUI:_notify(item, value)
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

function HubUI:_row(form, title, subtitle)
	local row = form:Row({ SearchIndex = title })
	local left = row:Left()
	if left.TitleStack then
		left:TitleStack({
			Title = title,
			Subtitle = subtitle,
		})
	else
		left:Label({ Text = title })
	end
	return row
end

function HubUI:_addToggle(form, item)
	local row = self:_row(form, item.label or item.key, item.subtitle)
	row:Right():Toggle({
		Value = self.config[item.key] == true,
		ValueChanged = function(_, value)
			self.config[item.key] = value == true
			self:_notify(item, self.config[item.key])
		end,
	})
end

function HubUI:_addSlider(form, item)
	local minV = item.min or 0
	local maxV = item.max or 100
	local step = item.step or 1
	local initial = snap(tonumber(self.config[item.key]) or minV, minV, maxV, step)
	self.config[item.key] = initial

	local row = self:_row(form, item.label or item.key, item.subtitle)
	local valueLabel = row:Right():Label({ Text = tostring(initial) })
	row:Right():Slider({
		Minimum = minV,
		Maximum = maxV,
		Value = initial,
		ValueChanged = function(component, value)
			local nextValue = snap(tonumber(value) or minV, minV, maxV, step)
			self.config[item.key] = nextValue
			valueLabel.Text = tostring(nextValue)
			if component and component.Value ~= nextValue then
				component.Value = nextValue
			end
			self:_notify(item, nextValue)
		end,
	})
end

function HubUI:_addNumber(form, item)
	local minV = item.min or 0
	local maxV = item.max or 100
	local step = item.step or 1
	local initial = snap(tonumber(self.config[item.key]) or minV, minV, maxV, step)
	self.config[item.key] = initial

	local row = self:_row(form, item.label or item.key, item.subtitle)
	row:Right():Stepper({
		Minimum = minV,
		Maximum = maxV,
		Step = step,
		Fielded = true,
		Value = initial,
		ValueChanged = function(component, value)
			local nextValue = snap(tonumber(value) or minV, minV, maxV, step)
			self.config[item.key] = nextValue
			if component and component.Value ~= nextValue then
				component.Value = nextValue
			end
			self:_notify(item, nextValue)
		end,
	})
end

function HubUI:_addSelect(form, item)
	local options = item.options or {}
	local labels = {}
	for _, option in ipairs(options) do
		table.insert(labels, optionLabel(option))
	end
	local selected = findOptionIndex(options, self.config[item.key])

	local row = self:_row(form, item.label or item.key, item.subtitle)
	row:Right():PopUpButton({
		Options = labels,
		Value = selected,
		ValueChanged = function(_, index)
			local option = options[index]
			if option == nil then
				return
			end
			local value = optionValue(option)
			self.config[item.key] = value
			self:_notify(item, value)
		end,
	})
end

function HubUI:_addColor(form, item)
	local presets = {}
	for _, preset in ipairs(item.presets or COLOR_PRESETS) do
		if typeof(preset) == "Color3" then
			table.insert(presets, { name = "Color " .. tostring(#presets + 1), value = preset })
		elseif typeof(preset) == "table" then
			table.insert(presets, {
				name = tostring(preset.name or preset.label or ("Color " .. tostring(#presets + 1))),
				value = preset.value or preset.color or COLOR_PRESETS[1].value,
			})
		end
	end
	if #presets == 0 then
		presets = COLOR_PRESETS
	end

	local labels = {}
	for _, preset in ipairs(presets) do
		table.insert(labels, preset.name)
	end
	local selected = colorIndex(self.config[item.key], presets)

	local row = self:_row(form, item.label or item.key, item.subtitle or "Color preset")
	row:Right():PopUpButton({
		Options = labels,
		Value = selected,
		ValueChanged = function(_, index)
			local preset = presets[index]
			if not preset then
				return
			end
			self.config[item.key] = preset.value
			self:_notify(item, preset.value)
		end,
	})
end

function HubUI:_addButton(form, item)
	local row = self:_row(form, item.label or item.id or "Action", item.subtitle)
	row:Right():Button({
		Label = item.getLabel and item.getLabel() or item.label or "Run",
		State = item.danger == false and "Primary" or (item.state or "Secondary"),
		Pushed = function()
			if item.canClick and not item.canClick() then
				return
			end
			if item.onClick then
				item.onClick()
			end
		end,
	})
end

function HubUI:_addText(form, item)
	local row = form:Row({ SearchIndex = item.text or item.label or "" })
	row:Left():Label({
		Text = item.text or item.label or "",
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

function HubUI:_addItem(form, item)
	if item.type == "toggle" and item.key then
		self:_addToggle(form, item)
	elseif item.type == "slider" and item.key then
		self:_addSlider(form, item)
	elseif item.type == "number" and item.key then
		self:_addNumber(form, item)
	elseif item.type == "select" and item.key then
		self:_addSelect(form, item)
	elseif item.type == "color" and item.key then
		self:_addColor(form, item)
	elseif item.type == "button" then
		self:_addButton(form, item)
	elseif item.type == "hint" or item.type == "label" then
		self:_addText(form, item)
	elseif item.type == "separator" then
		self:_addText(form, { text = " " })
	end
end

function HubUI:_build()
	local cascade = importCascade()
	self.cascade = cascade

	self.app = cascade.New({
		WindowPill = true,
		Theme = cascade.Themes.Dark,
		Accent = cascade.Accents.Blue,
	})

	local size = UserInputService.TouchEnabled
		and UDim2.fromOffset(540, 360)
		or UDim2.fromOffset(820, 520)

	self.window = self.app:Window({
		Title = self.title,
		Subtitle = "MicroHub",
		Size = size,
		Draggable = true,
		Resizable = true,
		CanExit = false,
		CanMinimize = true,
		CanZoom = true,
		Minimized = not self.menuVisible,
		Dropshadow = true,
		UIBlur = false,
	})

	local tabSection = self.window:Section({
		Title = self.title,
		Disclosure = false,
	})

	for pageIndex, page in ipairs(self.pages) do
		local tab = tabSection:Tab({
			Title = page.label,
			Selected = pageIndex == self.activePage,
			Icon = self.cascade.Symbols.squareStack3dUp,
		})

		for _, section in ipairs(page.sections or {}) do
			local formParent = tab
			if section.title and section.title ~= "" and tab.PageSection then
				formParent = tab:PageSection({ Title = section.title })
			end
			local form = formParent:Form()
			for _, item in ipairs(section.items or {}) do
				self:_addItem(form, item)
			end
		end
	end
end

function HubUI:setMenuVisible(visible)
	self.menuVisible = visible == true
	if self.window then
		self.window.Minimized = not self.menuVisible
	end
	if self.onMenuVisible then
		self.onMenuVisible(self.menuVisible)
	end
end

function HubUI:isMenuVisible()
	if self.window then
		return self.window.Minimized ~= true
	end
	return self.menuVisible
end

function HubUI:destroy()
	for _, conn in ipairs(self.connections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	clearTable(self.connections)

	if self.window then
		pcall(function()
			self.window:Destroy()
		end)
		self.window = nil
	end
	if self.app then
		pcall(function()
			self.app:Destroy()
		end)
		self.app = nil
	end
end

local function create(options)
	options = options or {}
	local self = setmetatable({
		title = options.title or "MicroHub",
		config = options.config or {},
		pages = buildPages(options),
		activePage = 1,
		menuVisible = options.startVisible ~= false,
		toggleKey = options.toggleKey or Enum.KeyCode.RightShift,
		mobileToggleKey = options.mobileToggleKey or Enum.KeyCode.ButtonY,
		onToggle = options.onToggle,
		onChange = options.onChange,
		onMenuVisible = options.onMenuVisible,
		connections = {},
	}, HubUI)

	self:_build()

	table.insert(self.connections, UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if input.KeyCode == self.toggleKey or input.KeyCode == self.mobileToggleKey then
			self:setMenuVisible(not self:isMenuVisible())
		end
	end))

	return self
end

return {
	version = VERSION,
	cascadeVersion = CASCADE_VERSION,
	create = create,
	colorPresets = COLOR_PRESETS,
}
