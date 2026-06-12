local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local remotes = opts.remotes
	local LocalPlayer = opts.localPlayer

	local lastShopAt = 0
	local openedSerials = {}

	local function getBoxTools()
		local tools = {}
		local function scan(container)
			if not container then
				return
			end
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("serial") then
					table.insert(tools, child)
				end
			end
		end
		scan(LocalPlayer.Character)
		scan(LocalPlayer:FindFirstChild("Backpack"))
		return tools
	end

	local function tryOpenBoxes()
		for _, tool in getBoxTools() do
			local serial = tool:GetAttribute("serial")
			if serial and not openedSerials[serial] then
				if remotes.openBox(serial) then
					openedSerials[serial] = true
				end
			end
		end
	end

	local function trySpinWheel()
		remotes.checkMysteryWheel()
		task.wait(0.1)
		remotes.spinMysteryWheel("Weapons", Config.SpinWheelSubtype or "Classic Box")
	end

	local function tryToolShopBuy()
		remotes.requestToolShopPrices()
		task.wait(0.15)
		local item = Config.ToolShopItem
		if item and item ~= "" then
			remotes.buyToolShopItem(item)
		end
	end

	local function tryRobuxBoxBuy()
		remotes.requestBoxPurchase(Config.RobuxBoxName, Config.RobuxBoxPack)
	end

	local function tickShop()
		local now = os.clock()
		if now - lastShopAt < (tonumber(Config.ShopInterval) or 2) then
			return
		end
		lastShopAt = now

		if Config.AutoOpenBoxes then
			tryOpenBoxes()
		end
		if Config.AutoSpinWheel then
			trySpinWheel()
		end
		if Config.AutoToolShopBuy then
			tryToolShopBuy()
		end
		if Config.AutoBuyRobuxBoxes then
			tryRobuxBoxBuy()
		end
	end

	return {
		tickShop = tickShop,
		tryOpenBoxes = tryOpenBoxes,
		trySpinWheel = trySpinWheel,
		tryToolShopBuy = tryToolShopBuy,
	}
end

return M
