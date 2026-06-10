local function stripBom(source)
	while typeof(source) == "string" and #source >= 3
		and source:byte(1) == 0xEF
		and source:byte(2) == 0xBB
		and source:byte(3) == 0xBF do
		source = source:sub(4)
	end
	return source
end

local function getGenv()
	return getgenv and getgenv() or _G
end

local function ensureLocalRoot()
	if typeof(getgenv) ~= "function" then
		return
	end

	local genv = getGenv()
	if typeof(genv.HUB_LOCAL_ROOT) == "string" and genv.HUB_LOCAL_ROOT ~= "" then
		return
	end
	if typeof(isfile) ~= "function" then
		return
	end

	local candidates = { "hub", "Warfare/hub", "microhub/hub" }
	for _, root in ipairs(candidates) do
		if isfile(root .. "/loader.lua") then
			genv.HUB_LOCAL_ROOT = root
			return
		end
	end
end

local function readLocalLoader()
	if getGenv().HUB_USE_LOCAL ~= true then
		return nil
	end
	if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then
		return nil
	end

	ensureLocalRoot()

	local candidates = {}
	local root = getGenv().HUB_LOCAL_ROOT
	if typeof(root) == "string" and root ~= "" then
		table.insert(candidates, root:gsub("/+$", "") .. "/loader.lua")
	end

	for _, path in ipairs({ "hub/loader.lua", "Warfare/hub/loader.lua", "microhub/hub/loader.lua" }) do
		table.insert(candidates, path)
	end

	for _, path in ipairs(candidates) do
		if isfile(path) then
			local body = readfile(path)
			if typeof(body) == "string" and #body > 0 then
				return stripBom(body), "MicroHub.Loader.Local"
			end
		end
	end

	return nil
end

ensureLocalRoot()

local source, chunkName = readLocalLoader()
if not source then
	local url = "https://raw.githubusercontent.com/sysscan/microhub/main/hub/loader.lua"
	local res = request({ Url = url .. "?t=" .. tostring(os.time()), Method = "GET" })
	assert(res and res.Success, (res and res.StatusMessage) or "download failed")
	source = stripBom(res.Body)
	chunkName = "MicroHub.Loader.Remote"
end

local fn, err = loadstring(source, chunkName)
assert(fn, err or "compile failed")
fn()
