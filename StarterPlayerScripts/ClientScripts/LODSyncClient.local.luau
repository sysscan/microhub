-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local v1 = require(game:GetService("ReplicatedStorage").Framework.Modules.LODSync).new(workspace.World, game:GetService("ReplicatedStorage").LODModels)
local newtrench = v1:scanByTag("NewTrench", "NewTrench")
print("NewTrench:", newtrench, (v1:scanByTag("TreeLOD2", "Tree")))
v1:start()