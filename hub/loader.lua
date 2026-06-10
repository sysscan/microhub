-- MicroHub simple loader. Remote-only, no workspace cache, no bootstrap, no runtime.

local VERSION = "1.5.0"
local BASE_URL = "https://raw.githubusercontent.com/sysscan/microhub/main/hub"
local UI_KEY = "__MicroHubUILib"

local GAMES = {
	{ name = "Warfare", path = "games/warfare.lua", placeIds = { 83902709332473 } },
	{ name = "Tha Bronx 3", path = "games/tha-bronx3.lua", placeIds = { 16472538603, 18642421777 } },
}

local function getGenv()
	return getgenv and getgenv() or _G
end

local function notify(title, text, duration)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = duration or 5,
		})
	end)
end

local function sanitize(source)
	if typeof(source) ~= "string" then
		return source
	end
	while #source >= 3 and source:byte(1) == 0xEF and source:byte(2) == 0xBB and source:byte(3) == 0xBF do
		source = source:sub(4)
	end
	return source
end

local function requestFn()
	return request or http_request or (syn and syn.request)
end

local function fetch(path)
	local http = requestFn()
	if typeof(http) ~= "function" then
		error("request() unavailable", 0)
	end

	local url = BASE_URL .. "/" .. path .. "?t=" .. tostring(os.time()) .. tostring(math.random(100000, 999999))
	local ok, res = pcall(http, {
		Url = url,
		Method = "GET",
		Headers = { ["Cache-Control"] = "no-cache" },
	})
	if not ok or not res then
		error("fetch failed: " .. path .. " (" .. tostring(res) .. ")", 0)
	end

	local status = tonumber(res.StatusCode)
	local success = res.Success == true or (status and status >= 200 and status < 300)
	if not success or typeof(res.Body) ~= "string" or #res.Body == 0 then
		error("fetch failed: " .. path .. " (" .. tostring(res.StatusCode or res.StatusMessage or "no body") .. ")", 0)
	end

	return sanitize(res.Body)
end

local function runSource(path)
	local source = fetch(path)
	local fn, compileErr = loadstring(source, path)
	if not fn then
		error("compile " .. path .. ": " .. tostring(compileErr), 0)
	end
	local ok, result = pcall(fn)
	if not ok then
		error("run " .. path .. ": " .. tostring(result), 0)
	end
	return result
end

local function findGame(placeId)
	for _, entry in ipairs(GAMES) do
		for _, id in ipairs(entry.placeIds) do
			if tonumber(id) == tonumber(placeId) then
				return entry
			end
		end
	end
	return nil
end

local function unloadOld()
	local genv = getGenv()
	if typeof(genv.__ThaBronx3Unload) == "function" then
		pcall(genv.__ThaBronx3Unload)
	end
	genv.__ThaBronx3Unload = nil
	genv.__ThaBronx3FlyStep = nil
	shared[UI_KEY] = nil
end

local ok, err = pcall(function()
	unloadOld()

	local entry = findGame(game.PlaceId)
	if not entry then
		error("unsupported PlaceId: " .. tostring(game.PlaceId), 0)
	end

	warn("[MicroHub] loader v" .. VERSION .. " loading " .. entry.name)
	notify("MicroHub", "Loading " .. entry.name .. "...")

	local ui = runSource("lib/ui.lua")
	if typeof(ui) ~= "table" or typeof(ui.create) ~= "function" then
		error("lib/ui.lua did not return a UI library", 0)
	end
	shared[UI_KEY] = ui

	runSource(entry.path)

	warn("[MicroHub] loaded " .. entry.name .. " v" .. VERSION)
	notify("MicroHub", entry.name .. " loaded")
end)

if not ok then
	warn("[MicroHub]", err)
	notify("MicroHub", tostring(err))
end
