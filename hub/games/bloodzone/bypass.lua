--[[ Blocks NoNoCheat reports and neutralizes client detectors. ]]

local require = shared.__MicroHubRequire

local ACLib = require("games/bloodzone/ac.lua")

local M = {}

function M.create(opts)
	local Config = opts.config
	local ReplicatedStorage = opts.replicatedStorage

	local function debugPrint(...)
		if Config and Config.DebugLivePrint then
			print("[Bloodzone]", ...)
		end
	end

	local function installOpts()
		return {
			config = Config,
			replicatedStorage = ReplicatedStorage,
			debugPrint = if Config and Config.DebugLivePrint then debugPrint else nil,
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
		debugPrint("AC bypass could not install (PotentialCheat missing or no hookfunction)")
		return false
	end

	return {
		install = install,
		sync = sync,
		uninstall = ACLib.uninstall,
		waitAndInstall = waitAndInstall,
		isInstalled = ACLib.isInstalled,
		isReportHookInstalled = ACLib.isReportHookInstalled,
		isModuleNeutralized = ACLib.isModuleNeutralized,
		getDiagnostics = ACLib.getDiagnostics,
	}
end

return M
