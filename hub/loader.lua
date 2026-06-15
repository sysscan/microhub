-- MicroHub loader — fetched at latest commit SHA by bootstrap.lua (or an equivalent bootstrap snippet).

local VERSION = "1.7.2"
local OWNER = "sysscan"
local REPO = "microhub"
local BRANCH = "main"
local HUB_DIR = "hub"
local UI_KEY = "__MicroHubUILib"

local GAMES = {
	{ name = "Warfare", path = "games/warfare.lua", placeIds = { 83902709332473 } },
	{ name = "Gunfight Arena", path = "games/gunfight-arena.lua", placeIds = { 15514727567, 14518422161 } },
	{ name = "Prison Life", path = "games/prison-life.lua", placeIds = { 155615604, 4669040 } },
	{ name = "Stud Incremental", path = "games/stud-incremental.lua", placeIds = { 127675063398240 } },
	{ name = "Slime RNG", path = "games/slime-rng.lua", placeIds = { 92416421522960 } },
	{ name = "Shrek In the Backrooms", path = "games/shrek-backrooms.lua", placeIds = { 9534337535 } },
	{ name = "POLYZ", path = "games/polyz.lua", placeIds = { 114291906728616, 135140697106817 } },
	{ name = "Altered Reality", path = "games/altered-reality.lua", placeIds = { 94570841251512 } },
	{ name = "Lumber Tycoon 2", path = "games/lumber-tycoon-2.lua", placeIds = { 13822889 } },
	{
		name = "Deadzone Classic",
		path = "games/deadzone-classic.lua",
		placeIds = { 3221241066, 17772691665, 86444118656057 },
	},
	{ name = "Bloodzone", path = "games/bloodzone.lua", placeIds = { 13955927965 } },
	{
		name = "VV Ultimatum",
		path = "games/vv-ultimatum.lua",
		placeIds = {
			6270290407,
			9861495985,
			10626511620,
			14219489601,
			119777193083785,
			14218523102,
			14321102147,
			15079707729,
			15645525857,
			18972283841,
			11131834995,
			11780443293,
			12337012844,
			11127942816,
			13229243486,
			16914874220,
			17083682617,
			95787471190312,
			121345602945775,
			102123868363969,
			132224751888154,
		},
	},
}

local resolvedSha = nil

local function getGenv()
	if typeof(getgenv) == "function" then
		return getgenv()
	end
	return _G
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
	end)
	return ok and tostring(name or "unknown") or "unknown"
end

local function cacheBust()
	return tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999999))
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

local function responseStatus(res)
	if kind(res) ~= "table" then
		return "non-table"
	end
	return tostring(res.StatusCode or res.StatusMessage or "empty")
end

local function requestPayload(url)
	return {
		Url = url,
		Method = "GET",
		Headers = {
			["Accept"] = "application/vnd.github.raw, application/json, text/plain",
			["Cache-Control"] = "no-cache, no-store, max-age=0",
			["Pragma"] = "no-cache",
			["User-Agent"] = "MicroHub/" .. VERSION,
		},
	}
end

local function looksLikeFetchError(source)
	if kind(source) ~= "string" or #source == 0 then
		return true
	end
	local head = source:sub(1, 96):lower()
	if head:sub(1, 3) == "404" then
		return true
	end
	if head:find("not found", 1, true) then
		return true
	end
	if head:find("<!doctype", 1, true) or head:find("<html", 1, true) then
		return true
	end
	return false
end

local function looksLikeLuaSource(source)
	if looksLikeFetchError(source) then
		return false
	end
	return source:find("function", 1, true) ~= nil
		or source:find("\nlocal ", 1, true) ~= nil
		or source:find("\nreturn ", 1, true) ~= nil
		or source:sub(1, 6) == "--[[" 
		or source:sub(1, 2) == "--"
end

local function acceptBody(body, failures, label)
	body = sanitize(body)
	if kind(body) ~= "string" or #body == 0 then
		table.insert(failures, label .. " empty body")
		return nil
	end
	if not looksLikeLuaSource(body) then
		local preview = body:sub(1, 48):gsub("%s+", " ")
		table.insert(failures, label .. " invalid body: " .. preview)
		return nil
	end
	return body
end

local function httpGet(url)
	local failures = {}

	if isCallable(request) then
		local ok, res = pcall(request, requestPayload(url))
		if ok and res then
			local body = acceptBody(responseBody(res), failures, "request HTTP " .. responseStatus(res))
			if body and statusOk(res) then
				return body
			end
			if not body then
				-- already logged
			elseif not statusOk(res) then
				table.insert(failures, "request HTTP " .. responseStatus(res))
			end
		else
			table.insert(failures, "request " .. tostring(res))
		end
	end

	local okAsync, bodyAsync = pcall(function()
		return game:HttpGetAsync(url, true)
	end)
	local asyncBody = acceptBody(bodyAsync, failures, "HttpGetAsync")
	if okAsync and asyncBody then
		return asyncBody
	end
	if not okAsync then
		table.insert(failures, "HttpGetAsync " .. tostring(bodyAsync))
	end

	local okSync, bodySync = pcall(function()
		return game:HttpGet(url, true)
	end)
	local syncBody = acceptBody(bodySync, failures, "HttpGet")
	if okSync and syncBody then
		return syncBody
	end
	if not okSync then
		table.insert(failures, "HttpGet " .. tostring(bodySync))
	end

	error("download failed on " .. executorName() .. ": " .. table.concat(failures, " | ") .. " -> " .. url, 0)
end

local function addBust(url)
	local sep = url:find("?", 1, true) and "&" or "?"
	return url .. sep .. "t=" .. cacheBust()
end

local function resolveLatestSha()
	if resolvedSha then
		return resolvedSha
	end
	-- Skip GitHub REST: rate-limited from Roblox/executor IPs; branch refs work on CDN mirrors.
	resolvedSha = BRANCH
	return BRANCH
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

local moduleCache = {}

local function normalizeModulePath(path)
	if not path:match("%.lua$") and not path:match("%.luau$") then
		return path .. ".lua"
	end
	return path
end

local function hubRequire(path)
	path = normalizeModulePath(path)
	if moduleCache[path] ~= nil then
		return moduleCache[path]
	end
	local source = fetch(path)
	local fn, compileErr = loadstring(source, path)
	if not fn then
		error("compile module " .. path .. ": " .. tostring(compileErr), 0)
	end
	local ok, result = pcall(fn)
	if not ok then
		error("run module " .. path .. ": " .. tostring(result), 0)
	end
	moduleCache[path] = result
	return result
end

local function runSource(path)
	path = normalizeModulePath(path)
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
	local needle = tostring(placeId)
	for _, entry in ipairs(GAMES) do
		for _, id in ipairs(entry.placeIds) do
			if tostring(id) == needle then
				return entry
			end
		end
	end
	return nil
end

local function destroyLoaderUI()
	local genv = getGenv()
	if typeof(genv.__MicroHubLoaderUIDestroy) == "function" then
		pcall(genv.__MicroHubLoaderUIDestroy)
	end
	genv.__MicroHubLoaderUIDestroy = nil
end

local function createInstantSplash()
	local ok, splash = pcall(function()
		local gethui = gethui or function()
			return game:GetService("CoreGui")
		end

		local screen = Instance.new("ScreenGui")
		screen.Name = "MicroHubLoaderInstant"
		screen.ResetOnSpawn = false
		screen.IgnoreGuiInset = true
		screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		screen.DisplayOrder = 9999
		screen.Parent = gethui()

		local dim = Instance.new("Frame")
		dim.BackgroundColor3 = Color3.new(0, 0, 0)
		dim.BackgroundTransparency = 0.45
		dim.BorderSizePixel = 0
		dim.Size = UDim2.fromScale(1, 1)
		dim.Parent = screen

		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.fromOffset(220, 28)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 18
		label.TextColor3 = Color3.fromRGB(208, 207, 227)
		label.Text = "MicroHub"
		label.Parent = dim

		return {
			destroy = function()
				if screen.Parent then
					screen:Destroy()
				end
			end,
		}
	end)

	return ok and splash or nil
end

local function unloadOld()
	local genv = getGenv()
	destroyLoaderUI()
	if typeof(genv.__PrisonLifeUnload) == "function" then
		pcall(genv.__PrisonLifeUnload)
	end
	if typeof(genv.__GunfightArenaUnload) == "function" then
		pcall(genv.__GunfightArenaUnload)
	end
	if typeof(genv.__WarfareUnload) == "function" then
		pcall(genv.__WarfareUnload)
	end
	if typeof(genv.__StudIncrementalUnload) == "function" then
		pcall(genv.__StudIncrementalUnload)
	end
	if typeof(genv.__SlimeRNGUnload) == "function" then
		pcall(genv.__SlimeRNGUnload)
	end
	if typeof(genv.__ShrekBackroomsUnload) == "function" then
		pcall(genv.__ShrekBackroomsUnload)
	end
	if typeof(genv.__POLYZUnload) == "function" then
		pcall(genv.__POLYZUnload)
	end
	if typeof(genv.__AlteredRealityUnload) == "function" then
		pcall(genv.__AlteredRealityUnload)
	end
	if typeof(genv.__LumberTycoon2Unload) == "function" then
		pcall(genv.__LumberTycoon2Unload)
	end
	if typeof(genv.__VVUltimatumUnload) == "function" then
		pcall(genv.__VVUltimatumUnload)
	end
	if typeof(genv.__DeadzoneClassicUnload) == "function" then
		pcall(genv.__DeadzoneClassicUnload)
	end
	if typeof(genv.__BloodzoneUnload) == "function" then
		pcall(genv.__BloodzoneUnload)
	end
	genv.__PrisonLifeUnload = nil
	genv.__GunfightArenaUnload = nil
	genv.__WarfareUnload = nil
	genv.__StudIncrementalUnload = nil
	genv.__SlimeRNGUnload = nil
	genv.__ShrekBackroomsUnload = nil
	genv.__POLYZUnload = nil
	genv.__AlteredRealityUnload = nil
	genv.__LumberTycoon2Unload = nil
	genv.__VVUltimatumUnload = nil
	genv.__DeadzoneClassicUnload = nil
	genv.__BloodzoneUnload = nil
	genv.__BloodzoneBypass = nil
	genv.__BloodzoneConfig = nil
	if typeof(genv.Library) == "table" and typeof(genv.Library.Exit) == "function" then
		pcall(function()
			genv.Library:Exit()
		end)
	end
	genv.Library = nil
	shared.__JuanitaLibrary = nil
	shared[UI_KEY] = nil
	shared.__MicroHubRequire = nil
	moduleCache = {}
end

local loaderUI = nil
local instantSplash = createInstantSplash()

local ok, err = pcall(function()
	unloadOld()
	local sha = resolveLatestSha()

	local LoaderUIModule = runSource("lib/loader-ui.lua")
	if typeof(LoaderUIModule) ~= "table" or typeof(LoaderUIModule.create) ~= "function" then
		error("lib/loader-ui.lua did not return a loader UI module", 0)
	end

	if instantSplash then
		instantSplash.destroy()
		instantSplash = nil
	end

	loaderUI = LoaderUIModule.create({ version = VERSION })
	getGenv().__MicroHubLoaderUIDestroy = function()
		if loaderUI then
			loaderUI.destroy()
			loaderUI = nil
		end
	end

	loaderUI.setStep("Version resolved", "commit " .. sha:sub(1, 7), 0.12)

	local entry = findGame(game.PlaceId)
	if not entry then
		error("unsupported PlaceId: " .. tostring(game.PlaceId), 0)
	end

	loaderUI.setStep("Matched game", entry.name, 0.22)
	warn("[MicroHub] v" .. VERSION .. " @ " .. sha:sub(1, 7) .. " -> " .. entry.name)

	shared.__MicroHubRequire = hubRequire

	if entry.path == "games/bloodzone.lua" then
		loaderUI.setStep("Neutralizing client AC", nil, 0.28)
		pcall(function()
			local genv = getGenv()
			genv.__BloodzoneConfig = hubRequire("games/bloodzone/config.lua")
			hubRequire("games/bloodzone/ac.lua").install({
				config = genv.__BloodzoneConfig,
				timeout = 10,
			})
		end)
	end

	loaderUI.setStep("Loading UI framework", nil, 0.38)
	local juanita = runSource("lib/juanita/Library.lua")
	if typeof(juanita) ~= "table" then
		error("lib/juanita/Library.lua did not return a UI library", 0)
	end
	shared.__JuanitaLibrary = juanita

	loaderUI.setStep("Loading hub UI", nil, 0.55)
	local ui = runSource("lib/ui.lua")
	if typeof(ui) ~= "table" or typeof(ui.create) ~= "function" then
		error("lib/ui.lua did not return a UI library", 0)
	end
	local uiVersion = tostring(ui.version or "?")
	shared[UI_KEY] = ui

	loaderUI.setStep("Loading " .. entry.name, nil, 0.72)
	runSource(entry.path)

	warn("[MicroHub] ready — UI " .. uiVersion)
	loaderUI.success(entry.name, uiVersion)
end)

if instantSplash then
	instantSplash.destroy()
	instantSplash = nil
end

if not ok then
	warn("[MicroHub]", err)
	if loaderUI then
		loaderUI.fail(tostring(err))
	end
end
