--[[
	Local development entry — use while testing before pushing to GitHub.

	Requirements:
	  - Executor workspace must point at this repo root (folder containing hub/)
	  - Executor must support readfile / isfile

	Run:
	  loadstring(readfile("hub/dev.lua"))()
]]

local genv = getgenv and getgenv() or _G
genv.HUB_LOCAL = true
genv.HUB_LOCAL_ROOT = "hub"

local loaderSource = readfile("hub/loader.lua")
if not loaderSource then
	error("[Hub] Could not read hub/loader.lua — set executor workspace to the repo root")
end

loadstring(loaderSource, "Hub.Loader")()
