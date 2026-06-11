local M = {}

function M.create(opts: {
	replicatedStorage: ReplicatedStorage,
	teams: Teams,
	localPlayer: Player,
	teamColor: { [string]: string },
})
	local ReplicatedStorage = opts.replicatedStorage
	local Teams = opts.teams
	local LocalPlayer = opts.localPlayer
	local TEAM_COLOR = opts.teamColor

	local function getRemotes()
		return ReplicatedStorage:FindFirstChild("Remotes")
	end

	local function getMeleeRemote()
		return ReplicatedStorage:FindFirstChild("meleeEvent")
	end

	local function switchTeamLegacy(colorName: string)
		local remote = workspace:FindFirstChild("Remote")
		if not remote then
			return
		end
		local teamEvent = remote:FindFirstChild("TeamEvent")
		if teamEvent then
			pcall(function()
				teamEvent:FireServer(colorName)
			end)
		end
		task.wait(0.2)
		local loadchar = remote:FindFirstChild("loadchar")
		if loadchar then
			pcall(function()
				loadchar:InvokeServer(LocalPlayer.Name)
			end)
		end
	end

	local function requestTeamChange(teamName: string)
		local team = Teams:FindFirstChild(teamName)
		if not team then
			return
		end

		local remotes = getRemotes()
		if remotes then
			local req = remotes:FindFirstChild("RequestTeamChange")
			if req then
				pcall(function()
					if req:IsA("RemoteFunction") then
						req:InvokeServer(team)
					else
						req:FireServer(team)
					end
				end)
				task.wait(0.3)
				if LocalPlayer.Team == team then
					return
				end
			end

			local teamSelect = remotes:FindFirstChild("TeamSelect")
			if teamSelect then
				pcall(function()
					if teamSelect:IsA("RemoteFunction") then
						teamSelect:InvokeServer(teamName)
					else
						teamSelect:FireServer(teamName)
					end
				end)
				task.wait(0.3)
				if LocalPlayer.Team == team then
					return
				end
			end
		end

		local colorName = if teamName == "Guards" then TEAM_COLOR.Guard
			elseif teamName == "Inmates" then TEAM_COLOR.Inmate
			else TEAM_COLOR.Neutral
		switchTeamLegacy(colorName)
	end

	return {
		getRemotes = getRemotes,
		getMeleeRemote = getMeleeRemote,
		requestTeamChange = requestTeamChange,
	}
end

return M
