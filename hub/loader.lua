-- MicroHub loader v1.6.4
-- Remote only. Resolves GitHub main -> immutable commit SHA, then loads every file from that SHA.

local VERSION = "1.6.4"
local MIN_UI_VERSION = "3.0.0"
local OWNER = "sysscan"
local REPO = "microhub"
local BRANCH = "main"
local HUB_DIR = "hub"
local UI_KEY = "__MicroHubUILib"

local GAMES = {
	{ name = "Warfare", path = "games/warfare.lua", placeIds = { 83902709332473 } },
	{ name = "Tha Bronx 3", path = "games/tha-bronx3.lua", placeIds = { 16472538603, 18642421777 } },
}

local resolvedSha = nil

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

local function kind(value)
	if typeof then
		return typeof(value)
	end
	return type(value)
end

local function sanitize(source)
	if kind(source) ~= "string" then
		return source
	end
	while #source >= 3 and source:byte(1) == 0xEF and source:byte(2) == 0xBB and source:byte(3) == 0xBF do
		source = source:sub(4)
	end
	return source
end

local function isCallable(value)
	return kind(value) == "function"
end

local function executorName()
	local ok, name = pcall(function()
		if isCallable(identifyexecutor) then
			return identifyexecutor()
		end
		if isCallable(getexecutorname) then
			return getexecutorname()
		end
		if isCallable(get_executor_name) then
			return get_executor_name()
		end
	end)
	return ok and tostring(name or "unknown") or "unknown"
end

local function addCandidate(candidates, label, fn, mode)
	if isCallable(fn) then
		table.insert(candidates, {
			label = label,
			fn = fn,
			mode = mode,
		})
	end
end

local function httpCandidates()
	local candidates = {}
	addCandidate(candidates, "request", request, "request")
	addCandidate(candidates, "http_request", http_request, "request")
	addCandidate(candidates, "httprequest", httprequest, "request")
	addCandidate(candidates, "syn.request", syn and syn.request, "request")
	addCandidate(candidates, "http.request", http and http.request, "request")
	addCandidate(candidates, "http.request_async", http and http.request_async, "request")
	addCandidate(candidates, "fluxus.request", fluxus and fluxus.request, "request")
	addCandidate(candidates, "krnl.request", krnl and krnl.request, "request")
	addCandidate(candidates, "electron.request", electron and electron.request, "request")
	addCandidate(candidates, "getcustomasset_http_request", getcustomasset_http_request, "request")
	addCandidate(candidates, "game.HttpGetAsync", function(url)
		return game:HttpGetAsync(url, true)
	end, "url")
	addCandidate(candidates, "game.HttpGet", function(url)
		return game:HttpGet(url, true)
	end, "url")
	return candidates
end

local function cacheBust()
	return tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999999))
end

local function statusOk(res)
	if kind(res) ~= "table" then
		return true
	end
	local status = tonumber(res.StatusCode or res.Status or res.status_code)
	if status ~= nil then
		return status >= 200 and status < 300
	end
	if res.Success == true then
		return true
	end
	if res.Success == false then
		return false
	end
	return true
end

local function responseBody(res)
	if kind(res) == "string" then
		return res
	end
	if kind(res) ~= "table" then
		return nil
	end
	return res.Body or res.body or res.Response or res.response or res.Data or res.data
end

local function responseStatus(res)
	if kind(res) ~= "table" then
		return "non-table"
	end
	return tostring(res.StatusCode or res.Status or res.status_code or res.StatusMessage or res.status_message or "empty")
end

local function requestPayload(url, withHeaders)
	local payload = {
		Url = url,
		url = url,
		Method = "GET",
		method = "GET",
	}
	if withHeaders then
		payload.Headers = {
			["Accept"] = "application/vnd.github.raw, application/json, text/plain",
			["Cache-Control"] = "no-cache, no-store, max-age=0",
			["Pragma"] = "no-cache",
			["User-Agent"] = "MicroHub/" .. VERSION,
		}
		payload.headers = payload.Headers
	end
	return payload
end

local function tryCandidate(candidate, url)
	if candidate.mode == "request" then
		local ok, res = pcall(candidate.fn, requestPayload(url, true))
		if not ok then
			ok, res = pcall(candidate.fn, requestPayload(url, false))
		end
		return ok, res
	end
	return pcall(candidate.fn, url)
end

local function httpGet(url)
	local failures = {}

	for _, candidate in ipairs(httpCandidates()) do
		local ok, res = tryCandidate(candidate, url)
		if ok and res then
			local body = responseBody(res)
			if statusOk(res) and kind(body) == "string" and #body > 0 then
				return sanitize(body)
			end
			table.insert(failures, candidate.label .. " HTTP " .. responseStatus(res))
		else
			table.insert(failures, candidate.label .. " " .. tostring(res))
		end
	end

	error("download failed on " .. executorName() .. ": " .. table.concat(failures, " | ") .. " -> " .. url, 0)
end

local function addBust(url)
	local sep = url:find("?", 1, true) and "&" or "?"
	return url .. sep .. "t=" .. cacheBust()
end

local function extractSha(body)
	return body:match('"sha"%s*:%s*"([0-9a-fA-F]+)"')
		or body:match('"object"%s*:%s*{%s*"sha"%s*:%s*"([0-9a-fA-F]+)"')
end

local function resolveLatestSha()
	local urls = {
		"https://api.github.com/repos/" .. OWNER .. "/" .. REPO .. "/commits/" .. BRANCH,
		"https://api.github.com/repos/" .. OWNER .. "/" .. REPO .. "/git/ref/heads/" .. BRANCH,
	}
	local failures = {}
	for _, url in ipairs(urls) do
		local ok, body = pcall(httpGet, addBust(url))
		if ok then
			local sha = extractSha(body)
			if sha and #sha >= 7 then
				resolvedSha = sha
				return sha
			end
			table.insert(failures, "no sha from " .. url)
		else
			table.insert(failures, tostring(body))
		end
	end
	error("could not resolve latest GitHub commit: " .. table.concat(failures, " | "), 0)
end

local function rawUrl(sha, path)
	return "https://raw.githubusercontent.com/" .. OWNER .. "/" .. REPO .. "/" .. sha .. "/" .. HUB_DIR .. "/" .. path
end

local function jsdelivrUrl(sha, path)
	return "https://cdn.jsdelivr.net/gh/" .. OWNER .. "/" .. REPO .. "@" .. sha .. "/" .. HUB_DIR .. "/" .. path
end

local function fetch(path)
	local sha = resolvedSha or resolveLatestSha()
	local urls = {
		rawUrl(sha, path),
		jsdelivrUrl(sha, path),
	}
	local failures = {}
	for _, url in ipairs(urls) do
		local ok, body = pcall(httpGet, addBust(url))
		if ok then
			return body
		end
		table.insert(failures, tostring(body))
	end
	error("fetch failed: " .. path .. " @ " .. sha .. " — " .. table.concat(failures, " | "), 0)
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

local function versionAtLeast(actual, minimum)
	local ai, mi = 1, 1
	while true do
		local av
		av, ai = tostring(actual):match("(%d+)%.?()", ai)
		local mv
		mv, mi = tostring(minimum):match("(%d+)%.?()", mi)
		if not av and not mv then
			return true
		end
		av = tonumber(av) or 0
		mv = tonumber(mv) or 0
		if av > mv then
			return true
		elseif av < mv then
			return false
		end
	end
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
	local sha = resolveLatestSha()

	local entry = findGame(game.PlaceId)
	if not entry then
		error("unsupported PlaceId: " .. tostring(game.PlaceId), 0)
	end

	warn("[MicroHub] v" .. VERSION .. " @ " .. sha:sub(1, 7) .. " -> " .. entry.name)

	local ui = runSource("lib/ui.lua")
	if typeof(ui) ~= "table" or typeof(ui.create) ~= "function" then
		error("lib/ui.lua did not return a UI library", 0)
	end
	local uiVersion = tostring(ui.version or "?")
	if not versionAtLeast(uiVersion, MIN_UI_VERSION) then
		error("stale UI " .. uiVersion .. " (need " .. MIN_UI_VERSION .. "+) — re-run loader snippet", 0)
	end
	shared[UI_KEY] = ui

	runSource(entry.path)

	warn("[MicroHub] ready — UI " .. uiVersion)
	notify("MicroHub", entry.name .. " loaded")
end)

if not ok then
	warn("[MicroHub]", err)
	notify("MicroHub", tostring(err))
end
