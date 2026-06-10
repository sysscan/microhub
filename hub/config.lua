return {
	Name = "MicroHub",
	Version = "1.1.5",
	Repository = "https://raw.githubusercontent.com/sysscan/microhub/main/hub",
	-- Version markers must appear in remote source (see DEBUG_VERSION etc. in each file).
	ModuleVersions = {
		["games/tha-bronx3.lua"] = "9-fly-before-bypass",
		["tools/bronx3-ac-debug.lua"] = "8-idempotent-start",
	},
}
