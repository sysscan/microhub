local HUB_RELEASE = "v1.4.3"

return {
	Name = "MicroHub",
	Version = "1.4.3",
	Release = HUB_RELEASE,
	Repository = "https://cdn.jsdelivr.net/gh/sysscan/microhub@" .. HUB_RELEASE .. "/hub",
	Mirrors = {
		"https://cdn.jsdelivr.net/gh/sysscan/microhub@" .. HUB_RELEASE .. "/hub",
		"https://raw.githubusercontent.com/sysscan/microhub/" .. HUB_RELEASE .. "/hub",
	},
}
