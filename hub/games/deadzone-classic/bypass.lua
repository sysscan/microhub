--[[ Blocks ChangePosture anti-cheat reports (codes 5–9). ]]

local require = shared.__MicroHubRequire

local ACLib = require("games/deadzone-classic/ac.lua")

local M = {}

function M.create(opts)
	local Config = opts.config
	local ReplicatedStorage = opts.replicatedStorage

	local function debugPrint(...)
		if Config.DebugLivePrint then
			print("[DeadzoneClassic]", ...)
		end
	end

	local function installOpts()
		return {
			config = Config,
			replicatedStorage = ReplicatedStorage,
			debugPrint = if Config.DebugLivePrint then debugPrint else nil,
		}
	end

	local function install()
		return ACLib.install(installOpts())
	end

	local function sync()
		ACLib.sync(installOpts())
	end

	local function waitAndInstall(maxAttempts: number?)
		maxAttempts = maxAttempts or 40
		for _ = 1, maxAttempts do
			if install() then
				return true
			end
			task.wait(0.25)
		end
		debugPrint("AC bypass could not install (ChangePosture missing or no hookfunction)")
		return false
	end

	return {
		install = install,
		sync = sync,
		uninstall = ACLib.uninstall,
		waitAndInstall = waitAndInstall,
		isInstalled = ACLib.isInstalled,
		isClientNeutralized = ACLib.isClientNeutralized,
	}
end

return M
