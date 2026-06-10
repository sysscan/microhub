--[[
	MicroHub loader
	Docs: https://docs.voltbz.net/docs/miscellaneous (request)
]]

local DEFAULT_BASE = "https://raw.githubusercontent.com/sysscan/microhub/main/hub"
local LOADED_KEY = "__MicroHubLoaded"

local function notify(title, text)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = 5,
		})
	end)
end

local function fetch(base, path)
	if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile("hub/" .. path) then
		return readfile("hub/" .. path)
	end

	local url = base .. "/" .. path
	local res = request({ Url = url, Method = "GET" })
	if res and res.Success and typeof(res.Body) == "string" and #res.Body > 0 then
		return res.Body
	end

	local msg = res and (res.StatusMessage or res.StatusCode) or "no response"
	error("HTTP failed (" .. tostring(msg) .. "): " .. url, 0)
end

local function loadTable(base, path)
	local source = fetch(base, path)
	local fn, err = loadstring(source, path)
	if not fn then
		error("compile " .. path .. ": " .. tostring(err), 0)
	end
	local ok, result = pcall(fn)
	if not ok then
		error("run " .. path .. ": " .. tostring(result), 0)
	end
	if typeof(result) ~= "table" then
		error(path .. " must return a table", 0)
	end
	return result
end

local function runScript(base, path)
	local source = fetch(base, path)
	local fn, err = loadstring(source, path)
	if not fn then
		error("compile " .. path .. ": " .. tostring(err), 0)
	end
	local ok, runErr = pcall(fn)
	if not ok then
		error("run " .. path .. ": " .. tostring(runErr), 0)
	end
end

local function findGame(manifest, placeId)
	for _, gameEntry in ipairs(manifest) do
		if typeof(gameEntry.placeIds) == "table" then
			for _, id in ipairs(gameEntry.placeIds) do
				if id == placeId then
					return gameEntry
				end
			end
		end
	end
	return nil
end

local success, err = pcall(function()
	local base = DEFAULT_BASE
	local config = loadTable(base, "config.lua")
	base = config.Repository or base
	local hubName = config.Name or "MicroHub"

	if shared[LOADED_KEY] == hubName then
		notify(hubName, "Already loaded")
		return
	end

	local manifest = loadTable(base, "manifest.lua")
	local placeId = game.PlaceId
	local entry = findGame(manifest, placeId)

	if not entry then
		notify(hubName, "Unsupported game — PlaceId " .. tostring(placeId))
		warn("[" .. hubName .. "] Unsupported PlaceId:", placeId)
		return
	end

	notify(hubName, "Loading " .. (entry.name or "script") .. "...")
	runScript(base, entry.module)
	shared[LOADED_KEY] = hubName
	notify(hubName, (entry.name or "Game") .. " loaded")
end)

if not success then
	warn("[MicroHub]", err)
	notify("MicroHub", tostring(err))
end
