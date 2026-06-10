--[[
	MicroHub UI v4.0.0 — juanitahaxx-backed adapter.

	Game scripts call:
		UILib.create({ title, config, pages, onToggle, onChange, ... })

	This file maps MicroHub's schema onto
	https://github.com/sametexe001/juanitahaxx (Library.lua vendored in lib/juanita/).
]]

local UserInputService = game:GetService("UserInputService")

local VERSION = "4.0.1"
local JUANITA_SOURCE = "lib/juanita/Library.lua"

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

local function importJuanita()
	local lib = shared.__JuanitaLibrary
	if typeof(lib) == "table" then
		return lib
	end
	error("Juanita UI library not loaded — run hub/loader.lua", 0)
end

local function clearTable(tbl)
	if table.clear then
		table.clear(tbl)
		return
	end
	for key in pairs(tbl) do
		tbl[key] = nil
	end
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

local function findOptionLabel(options, value)
	for _, option in ipairs(options or {}) do
		if optionValue(option) == value then
			return optionLabel(option)
		end
	end
	local first = options and options[1]
	return first and optionLabel(first) or ""
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

local function sanitizeNumber(value, minV, maxV, step)
	local number = tonumber(value)
	if number == nil or number ~= number then
		number = minV
	end
	return snap(number, minV, maxV, step)
end

local function normalizeSliderRange(minV, maxV)
	minV = tonumber(minV) or 0
	maxV = tonumber(maxV) or minV + 1
	if maxV <= minV then
		maxV = minV + 1
	end
	return minV, maxV
end

local function stepDecimals(step)
	step = step or 1
	local text = tostring(step)
	local dot = text:find("%.")
	if not dot then
		return 0
	end
	return #text - dot
end

local function colorIndex(color, presets)
	for index, preset in ipairs(presets) do
		if preset.value == color then
			return index
		end
	end
	return 1
end

local function createCompactHud(title, accent)
	local gethuiFn = gethui or function()
		return game:GetService("CoreGui")
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "\0"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = gethuiFn()

	local frame = Instance.new("Frame")
	frame.Name = "\0"
	frame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -8, 0, 8)
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(40, 40, 40)
	stroke.Thickness = 1
	stroke.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 3)
	padding.PaddingBottom = UDim.new(0, 3)
	padding.PaddingLeft = UDim.new(0, 5)
	padding.PaddingRight = UDim.new(0, 5)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 1)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "\0"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamMedium
	titleLabel.TextSize = 10
	titleLabel.TextColor3 = accent or Color3.fromRGB(176, 176, 209)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = title
	titleLabel.AutomaticSize = Enum.AutomaticSize.XY
	titleLabel.Parent = frame

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "\0"
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 9
	statusLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Text = "idle"
	statusLabel.AutomaticSize = Enum.AutomaticSize.XY
	statusLabel.Parent = frame

	local hud = {
		gui = gui,
		statusLabel = statusLabel,
	}

	function hud:SetVisibility(visible)
		gui.Enabled = visible == true
	end

	function hud:SetStatus(text)
		statusLabel.Text = tostring(text)
	end

	function hud:Destroy()
		gui:Destroy()
	end

	return hud
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
	if item.type == "toggle" and self._refreshHud then
		self:_refreshHud(item.key)
	end
end

function HubUI:_flag(item)
	if item.key then
		return "mh_" .. tostring(item.key)
	end
	if item.id then
		return "mh_" .. tostring(item.id)
	end
	return "mh_" .. tostring(item.label or item.type)
end

function HubUI:_addToggle(section, item)
	local initial = self.config[item.key] == true
	self.config[item.key] = initial

	if item.hud then
		table.insert(self.hudEntries, {
			key = item.key,
			label = tostring(item.hud),
		})
	end

	section:Toggle({
		Name = item.label or item.key,
		Flag = self:_flag(item),
		Default = initial,
		Callback = function(value)
			self.config[item.key] = value == true
			self:_notify(item, self.config[item.key])
		end,
	})
end

function HubUI:_addSlider(section, item)
	local minV, maxV = normalizeSliderRange(item.min, item.max)
	local step = tonumber(item.step) or 1
	if step <= 0 then
		step = 1
	end
	local initial = sanitizeNumber(self.config[item.key], minV, maxV, step)
	self.config[item.key] = initial

	local slider = section:Slider({
		Name = item.label or item.key,
		Flag = self:_flag(item),
		Min = minV,
		Max = maxV,
		Default = initial,
		Decimals = stepDecimals(step),
		Suffix = item.suffix or "",
		Callback = function(value)
			local nextValue = sanitizeNumber(value, minV, maxV, step)
			self.config[item.key] = nextValue
			self:_notify(item, nextValue)
		end,
	})
	slider:Set(initial)
end

function HubUI:_addNumber(section, item)
	self:_addSlider(section, item)
end

function HubUI:_addSelect(section, item)
	local options = item.options or {}
	local labels = {}
	local labelToValue = {}

	for _, option in ipairs(options) do
		local label = optionLabel(option)
		table.insert(labels, label)
		labelToValue[label] = optionValue(option)
	end

	local selected = findOptionLabel(options, self.config[item.key])
	if self.config[item.key] == nil and labels[1] then
		self.config[item.key] = labelToValue[labels[1]]
	end

	section:Dropdown({
		Name = item.label or item.key,
		Flag = self:_flag(item),
		Items = labels,
		Default = selected,
		Multi = false,
		Callback = function(value)
			local mapped = labelToValue[value]
			if mapped == nil then
				return
			end
			self.config[item.key] = mapped
			self:_notify(item, mapped)
		end,
	})
end

function HubUI:_addColor(section, item)
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

	local initial = self.config[item.key]
	if typeof(initial) ~= "Color3" then
		initial = presets[colorIndex(initial, presets)].value
		self.config[item.key] = initial
	end

	local label = section:Label({ Name = item.label or item.key })
	label:Colorpicker({
		Flag = self:_flag(item),
		Default = initial,
		Callback = function(color)
			self.config[item.key] = color
			self:_notify(item, color)
		end,
	})
end

function HubUI:_addButton(section, item)
	section:Button({
		Name = item.getLabel and item.getLabel() or item.label or item.id or "Run",
		Callback = function()
			if item.canClick and not item.canClick() then
				return
			end
			if item.onClick then
				item.onClick()
			end
		end,
	})
end

function HubUI:_addText(section, item)
	section:Label({
		Name = item.text or item.label or "",
	})
end

function HubUI:_addItem(section, item)
	if item.type == "toggle" and item.key then
		self:_addToggle(section, item)
	elseif item.type == "slider" and item.key then
		self:_addSlider(section, item)
	elseif item.type == "number" and item.key then
		self:_addNumber(section, item)
	elseif item.type == "select" and item.key then
		self:_addSelect(section, item)
	elseif item.type == "color" and item.key then
		self:_addColor(section, item)
	elseif item.type == "button" then
		self:_addButton(section, item)
	elseif item.type == "hint" or item.type == "label" then
		self:_addText(section, item)
	elseif item.type == "separator" then
		self:_addText(section, { text = " " })
	end
end

function HubUI:_setupHud()
	if not self.hud then
		return
	end

	self.hudShowKey = (self.hudOptions and self.hudOptions.showKey) or "ShowHUD"
	self._hudShown = nil

	function self:_refreshHud(changedKey)
		local showKey = self.hudShowKey
		local show = self.config[showKey] == true

		if changedKey == showKey or self._hudShown ~= show then
			self._hudShown = show
			self.hud:SetVisibility(show)
		end

		if not show then
			return
		end

		local active = {}
		for _, entry in ipairs(self.hudEntries) do
			if self.config[entry.key] == true then
				table.insert(active, entry.label)
			end
		end

		if #active == 0 then
			self.hud:SetStatus("idle")
		else
			self.hud:SetStatus(table.concat(active, " | "))
		end
	end

	self:_refreshHud(self.hudShowKey)
end

function HubUI:_build()
	local Library = importJuanita()
	self.library = Library

	Library.MenuKeybind = tostring(self.toggleKey)

	self.window = Library:Window({ Name = self.title })
	-- Custom compact HUD — avoid juanita Watermark (settings tab fights ShowHUD visibility).
	self.window.Watermark = false
	self.hud = createCompactHud(self.title, Library.Theme and Library.Theme.Accent)
	-- Init() toggles Self.KeybindList visibility; without this call the Window
	-- metatable exposes Library.KeybindList (a function) and SetVisibility errors.
	self.keybindList = self.window:KeybindList()
	self.keybindList:SetVisibility(false)
	self.hudEntries = {}

	local builtPages = {}
	for pageIndex, page in ipairs(self.pages) do
		local jPage = self.window:Page({ Name = page.label })
		builtPages[pageIndex] = jPage

		local side = 1
		for _, section in ipairs(page.sections or {}) do
			local jSection = jPage:Section({
				Name = section.title or "General",
				Side = side,
			})
			side = side == 1 and 2 or 1

			for _, item in ipairs(section.items or {}) do
				self:_addItem(jSection, item)
			end
		end
	end

	local active = builtPages[self.activePage] or builtPages[1]
	if active then
		active:Turn()
	end

	self.window:Init()

	if not self.menuVisible then
		self.window:SetOpen(false)
	end

	self:_setupHud()
end

function HubUI:setMenuVisible(visible)
	self.menuVisible = visible == true
	if self.window then
		self.window:SetOpen(self.menuVisible)
	end
	if self.onMenuVisible then
		self.onMenuVisible(self.menuVisible)
	end
end

function HubUI:isMenuVisible()
	if self.window then
		return self.window.IsOpen == true
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

	if self.library and typeof(self.library.Exit) == "function" then
		pcall(function()
			self.library:Exit()
		end)
	end

	self.window = nil
	if self.hud then
		pcall(function()
			self.hud:Destroy()
		end)
	end
	self.hud = nil
	self.keybindList = nil
	self.library = nil
end

local function create(options)
	options = options or {}
	local self = setmetatable({
		title = options.title or "MicroHub",
		config = options.config or {},
		pages = buildPages(options),
		activePage = options.activePage or 1,
		menuVisible = options.startVisible ~= false,
		toggleKey = options.toggleKey or Enum.KeyCode.RightShift,
		mobileToggleKey = options.mobileToggleKey or Enum.KeyCode.ButtonY,
		hudOptions = options.hud,
		onToggle = options.onToggle,
		onChange = options.onChange,
		onMenuVisible = options.onMenuVisible,
		connections = {},
		hudEntries = {},
	}, HubUI)

	self:_build()

	if UserInputService.TouchEnabled then
		table.insert(self.connections, UserInputService.InputEnded:Connect(function(input, gameProcessed)
			if gameProcessed and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			if input.KeyCode == self.mobileToggleKey then
				self:setMenuVisible(not self:isMenuVisible())
			end
		end))
	end

	return self
end

return {
	version = VERSION,
	juanitaSource = JUANITA_SOURCE,
	create = create,
	colorPresets = COLOR_PRESETS,
}
