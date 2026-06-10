--[[
	PASTE THIS in Volt — not loader.lua, not a saved script.
	Uses jsDelivr (not raw GitHub) so Volt cannot serve a stale workspace hub/ copy.
]]

getgenv().HUB_USE_LOCAL = false
getgenv().HUB_UI_LOCAL = false

local RELEASE = "v1.4.4"
local MIN_LOADER = 9
local bust = tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999999))

local mirrors = {
	"https://cdn.jsdelivr.net/gh/sysscan/microhub@" .. RELEASE .. "/hub/loader.lua",
	"https://raw.githubusercontent.com/sysscan/microhub/" .. RELEASE .. "/hub/loader.lua",
}

local body, mirror
for _, base in ipairs(mirrors) do
	local ok, res = pcall(function()
		return request({
			Url = base .. "?t=" .. bust,
			Method = "GET",
			Headers = { ["Cache-Control"] = "no-cache, no-store" },
		})
	end)
	if ok and res and res.Success and typeof(res.Body) == "string" and #res.Body > 0 then
		local ver = tonumber(res.Body:match("LOADER_VERSION%s*=%s*(%d+)"))
		if ver and ver >= MIN_LOADER and not res.Body:find("TouchTap", 1, true) then
			body = res.Body
			mirror = base
			break
		end
	end
end

if not body then
	error(
		"[MicroHub] Stale loader download. Delete workspace hub/ folder, then re-paste bootstrap.lua.",
		0
	)
end

warn("[MicroHub] bootstrap ok from", mirror:match("^https?://[^/]+"))
loadstring(body, "MicroHub.Loader")()
