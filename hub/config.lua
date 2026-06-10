return {
	Name = "MicroHub",
	Version = "1.1.1",
	Repository = "https://raw.githubusercontent.com/sysscan/microhub/main/hub",
	-- Version markers must appear in remote source (see DEBUG_VERSION etc. in each file).
	ModuleVersions = {
		["tools/bronx3-ac-debug.lua"] = "7-sync-fix",
	},
}
