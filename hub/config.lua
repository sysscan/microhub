--[[
	Hub configuration.
	Update Repository after publishing to GitHub (raw URL, no trailing slash).
]]

return {
	Name = "MicroHub",
	Version = "1.0.0",
	Author = "microsys",

	-- Raw GitHub base: https://raw.githubusercontent.com/USER/REPO/BRANCH/hub
	Repository = "https://raw.githubusercontent.com/sysscan/microhub/main/hub",

	-- Optional Discord / support links shown on unsupported games
	Links = {
		Discord = "",
		GitHub = "",
	},

	-- HttpGet timeout behavior (seconds, used by bootstrap retry)
	HttpTimeout = 10,
	HttpRetries = 2,
}
