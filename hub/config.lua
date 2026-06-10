return {
	Name = "MicroHub",
	Version = "1.1.0",
	Repository = "https://raw.githubusercontent.com/sysscan/microhub/main/hub",
	-- Version markers must appear in remote source (see DEBUG_VERSION etc. in each file).
	ModuleVersions = {
		["tools/bronx3-ac-debug.lua"] = "6-inline-flush",
	},
}
