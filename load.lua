--[[
	Repo entry point — redirects to the hub loader.

	Local (executor workspace = this repo):
	  loadstring(readfile("load.lua"))()

	Public (after publishing to GitHub):
	  loadstring(game:HttpGet("https://raw.githubusercontent.com/sysscan/microhub/main/hub/main.lua", true))()
]]

if readfile and isfile and isfile("hub/dev.lua") then
	loadstring(readfile("hub/dev.lua"), "Hub.Dev")()
else
	loadstring(game:HttpGet("https://raw.githubusercontent.com/sysscan/microhub/main/hub/main.lua", true))()
end
