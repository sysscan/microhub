local M = {}

function M.create(opts: {
	config: { [string]: any },
	collectionService: CollectionService,
	parent: Instance?,
})
	local Config = opts.config
	local CollectionService = opts.collectionService

	local highlights: { [Instance]: Highlight } = {}
	local folder = Instance.new("Folder")
	folder.Name = "MicroHubPL_C4"
	folder.Parent = opts.parent or workspace

	local function styleHighlight(highlight: Highlight)
		highlight.FillColor = Config.C4ESPFillColor
		highlight.OutlineColor = Config.C4ESPOutlineColor
		highlight.FillTransparency = Config.C4ESPFillTransparency
		highlight.OutlineTransparency = Config.C4ESPOutlineTransparency
	end

	local function add(obj: Instance)
		if highlights[obj] then
			styleHighlight(highlights[obj])
			return
		end
		local highlight = Instance.new("Highlight")
		highlight.Adornee = obj
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		styleHighlight(highlight)
		highlight.Parent = folder
		highlights[obj] = highlight
	end

	local function refreshStyles()
		for _, highlight in highlights do
			styleHighlight(highlight)
		end
	end

	local function remove(obj: Instance)
		local highlight = highlights[obj]
		if highlight then
			highlight:Destroy()
			highlights[obj] = nil
		end
	end

	local function sync()
		if not Config.C4ESP then
			for obj in pairs(highlights) do
				remove(obj)
			end
			return
		end
		for _, obj in CollectionService:GetTagged("C4") do
			add(obj)
		end
	end

	local function destroy()
		for obj in pairs(highlights) do
			remove(obj)
		end
		if folder then
			folder:Destroy()
		end
	end

	return {
		add = add,
		remove = remove,
		sync = sync,
		refreshStyles = refreshStyles,
		destroy = destroy,
	}
end

return M
