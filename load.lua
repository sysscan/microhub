local url = "https://raw.githubusercontent.com/sysscan/microhub/main/hub/loader.lua"
local res = request({ Url = url, Method = "GET" })
assert(res.Success, res.StatusMessage or "download failed")
loadstring(res.Body)()
