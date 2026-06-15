-- MicroHub bootstrap — stable entry script. Resolves latest GitHub commit, then runs hub/loader.lua from that SHA.
-- Paste once in your executor; re-run anytime after a push — no version numbers to update.

local OWNER = "sysscan"
local REPO = "microhub"
local BRANCH = "main"
local HUB_DIR = "hub"

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

local function cacheBust(url)
	local sep = url:find("?", 1, true) and "&" or "?"
	return url .. sep .. "t=" .. tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999999))
end

local function statusOk(res)
	if kind(res) ~= "table" then
		return true
	end
	if res.Success == true then
		return true
	end
	if res.Success == false then
		return false
	end
	local status = tonumber(res.StatusCode)
	if status ~= nil then
		return status >= 200 and status < 300
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
	return res.Body
end

local function httpGet(url)
	local failures = {}

	if kind(request) == "function" then
		local ok, res = pcall(request, {
			Url = url,
			Method = "GET",
			Headers = {
				["Accept"] = "application/vnd.github.raw, application/json, text/plain",
				["Cache-Control"] = "no-cache, no-store, max-age=0",
				["Pragma"] = "no-cache",
				["User-Agent"] = "MicroHub-Bootstrap",
			},
		})
		if ok and res then
			local body = responseBody(res)
			if statusOk(res) and kind(body) == "string" and #body > 0 then
				return sanitize(body)
			end
			table.insert(failures, "request HTTP " .. tostring(res.StatusCode or res.StatusMessage or "?"))
		else
			table.insert(failures, "request " .. tostring(res))
		end
	end

	local okAsync, bodyAsync = pcall(function()
		return game:HttpGetAsync(url, true)
	end)
	if okAsync and kind(bodyAsync) == "string" and #bodyAsync > 0 then
		return sanitize(bodyAsync)
	end
	table.insert(failures, "HttpGetAsync " .. tostring(bodyAsync))

	local okSync, bodySync = pcall(function()
		return game:HttpGet(url, true)
	end)
	if okSync and kind(bodySync) == "string" and #bodySync > 0 then
		return sanitize(bodySync)
	end
	table.insert(failures, "HttpGet " .. tostring(bodySync))

	error("download failed: " .. table.concat(failures, " | ") .. " -> " .. url, 0)
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
		local ok, body = pcall(httpGet, cacheBust(url))
		if ok then
			local sha = extractSha(body)
			if sha and #sha >= 7 then
				return sha
			end
			table.insert(failures, "no sha from " .. url)
		else
			table.insert(failures, tostring(body))
		end
	end
	-- GitHub REST is often rate-limited from Roblox/executor IPs; branch refs work on raw + jsdelivr.
	warn(
		"[MicroHub] GitHub API unavailable ("
			.. table.concat(failures, " | ")
			.. "); using branch ref '"
			.. BRANCH
			.. "'"
	)
	return BRANCH
end

local function loaderUrls(sha)
	return {
		"https://raw.githubusercontent.com/" .. OWNER .. "/" .. REPO .. "/" .. sha .. "/" .. HUB_DIR .. "/loader.lua",
		"https://cdn.jsdelivr.net/gh/" .. OWNER .. "/" .. REPO .. "@" .. sha .. "/" .. HUB_DIR .. "/loader.lua",
	}
end

local function isLoaderSource(source)
	return kind(source) == "string"
		and source:find("local GAMES", 1, true)
		and source:find("resolveLatestSha", 1, true)
		and source:find("runSource", 1, true)
end

local sha = resolveLatestSha()
local loaderSource = nil
local failures = {}

for _, url in ipairs(loaderUrls(sha)) do
	local ok, body = pcall(httpGet, cacheBust(url))
	if ok and isLoaderSource(body) then
		loaderSource = body
		break
	end
	table.insert(failures, ok and "invalid loader body" or tostring(body))
end

if not loaderSource then
	error("loader fetch failed @ " .. sha:sub(1, 7) .. ": " .. table.concat(failures, " | "), 0)
end

local fn, compileErr = loadstring(loaderSource, "MicroHub.Loader")
if not fn then
	error("loader compile: " .. tostring(compileErr), 0)
end

local ok, err = pcall(fn)
if not ok then
	error("loader run: " .. tostring(err), 0)
end
