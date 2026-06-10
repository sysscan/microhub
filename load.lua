local url = "https://raw.githubusercontent.com/sysscan/microhub/main/hub/loader.lua"
local res = request({ Url = url, Method = "GET" })
assert(res and res.Success, (res and res.StatusMessage) or "download failed")

local body = res.Body
if #body >= 3 and body:byte(1) == 0xEF and body:byte(2) == 0xBB and body:byte(3) == 0xBF then
	body = body:sub(4)
end

local fn, err = loadstring(body, "MicroHub.Loader")
assert(fn, err or "compile failed")
fn()
