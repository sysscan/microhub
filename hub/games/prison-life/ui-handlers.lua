local M = {}

function M.create(m: {
	config: { [string]: any },
	movement: any,
	combat: any,
	automation: any,
	c4ESP: any,
	visuals: any,
	pickup: any,
})
	local Config = m.config

	local function onToggle(key: string, value: any)
		if key == "SpeedBoost" or key == "NoJumpCooldown" or key == "AlwaysSprint" then
			m.movement.applyMovement()
			m.movement.setNoJumpCooldown(Config.NoJumpCooldown)
		end
		if
			key == "SpeedBoost"
			or key == "NoJumpCooldown"
			or key == "Noclip"
			or key == "AlwaysSprint"
			or key == "VehicleSpeed"
			or key == "Disabler"
		then
			m.movement.syncMovementDisabler()
		end
		if key == "SilentAim" or key == "AutoReload" or key == "AutoReloadSwap" then
			m.combat.refreshGunFeatures()
		end
		if key == "AutoArrestCooldownBar" then
			m.automation.syncArrestCooldownBar(value)
		end
		if key == "C4ESP" then
			m.c4ESP.sync()
		end
		if key == "FullBright" then
			m.movement.applyFullBright()
		end
		if key == "AntiKillPlane" then
			m.movement.syncKillPlane()
		end
		if key == "AntiTaze" then
			m.movement.setAntiTaze(value)
		end
		if key == "VehicleWallbang" and not value then
			m.movement.runVehicleWallbang()
		end
		if key == "VehicleFly" or (key == "VehicleFlyMode" and Config.VehicleFly) then
			m.movement.syncVehicleFly(Config.VehicleFly)
		end
		if key == "AntiInvisible" then
			m.visuals.syncAntiInvisible(value)
		end
		if key == "CameraPhase" then
			m.visuals.syncCameraPhase(value)
		end
		if key == "BulletTracers" then
			m.visuals.syncBulletTracers(value)
		end
		if key == "DamageIndicator" then
			m.visuals.syncDamageIndicator(value)
		end
		if key == "HitSound" then
			m.visuals.syncHitSound(value)
		end
		if key == "Viewmodel" then
			m.visuals.syncViewmodel(value)
		end
		if key == "Crosshair" then
			m.visuals.syncCrosshair(value)
		end
		if key == "SilentAimRangeCircle" or key == "SilentAimMode" then
			m.combat.syncSilentAimCircle()
		end
		local vmTool = m.visuals.getViewmodelRealTool()
		if key == "ViewmodelForceField" and Config.Viewmodel and vmTool then
			m.visuals.onViewmodelToolAdded(vmTool)
		end
	end

	local function onChange(key: string)
		if key == "WalkSpeed" or key == "JumpPower" then
			m.movement.applyMovement()
		end
		if
			key == "SilentAimCircleColor"
			or key == "SilentAimCircleTransparency"
			or key == "SilentAimCircleFilled"
			or key == "SilentAimRange"
		then
			m.combat.syncSilentAimCircle()
		end
		if
			key == "C4ESPFillColor"
			or key == "C4ESPOutlineColor"
			or key == "C4ESPFillTransparency"
			or key == "C4ESPOutlineTransparency"
		then
			m.c4ESP.refreshStyles()
		end
		if
			key == "GuardPickup1"
			or key == "GuardPickup2"
			or key == "PrisonerPickup1"
			or key == "PrisonerPickup2"
			or key == "CriminalPickup1"
			or key == "CriminalPickup2"
		then
			m.pickup.rebuildSortedPickups()
		end
		if key == "BulletTracerMaterial" and Config.BulletTracers then
			m.visuals.syncBulletTracers(true)
		end
		local vmTool = m.visuals.getViewmodelRealTool()
		if key == "ViewmodelForceFieldColor" and Config.Viewmodel and vmTool then
			m.visuals.onViewmodelToolAdded(vmTool)
		end
	end

	return { onToggle = onToggle, onChange = onChange }
end

return M
