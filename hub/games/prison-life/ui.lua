local M = {}

function M.build(opts: {
	config: { [string]: any },
	pickupWeaponOptions: { string },
	requestTeamChange: (string) -> (),
	giveGiverWeapon: (string) -> (),
	onToggle: (string, any) -> (),
	onChange: (string) -> (),
})
	local Config = opts.config
	local PICKUP_WEAPON_OPTIONS = opts.pickupWeaponOptions

	return {
		title = "PRISON LIFE",
		config = Config,
		pages = {
			{
				label = "Combat",
				sections = {
					{
						title = "MELEE",
						items = {
							{ type = "toggle", key = "Killaura", label = "Killaura", hud = "Killaura" },
							{ type = "slider", key = "KillauraRange", label = "Killaura Range", min = 1, max = 12, step = 1 },
						},
					},
					{
						title = "GUARD",
						items = {
							{ type = "toggle", key = "AutoArrest", label = "Auto Arrest", hud = "Auto Arrest" },
							{ type = "slider", key = "AutoArrestRange", label = "Arrest Range", min = 1, max = 8, step = 1 },
							{ type = "toggle", key = "ArrestHandCheck", label = "Handcuffs Only", hud = "Handcuffs" },
							{ type = "toggle", key = "ArrestInmates", label = "Arrest Inmates", hud = "Arrest Inmates" },
							{ type = "toggle", key = "ArrestCriminals", label = "Arrest Criminals", hud = "Arrest Criminals" },
							{ type = "toggle", key = "AutoArrestCooldownBar", label = "Cooldown Bar", hud = "Arrest CD" },
						},
					},
					{
						title = "GUNS",
						items = {
							{ type = "toggle", key = "SilentAim", label = "Silent Aim", hud = "Silent Aim" },
							{ type = "select", key = "SilentAimMode", label = "Aim Mode", options = { "Mouse", "Position" } },
							{ type = "slider", key = "SilentAimRange", label = "Aim Range", min = 1, max = 1000, step = 5 },
							{ type = "slider", key = "SilentAimHitChance", label = "Hit Chance %", min = 0, max = 100, step = 1 },
							{ type = "slider", key = "SilentAimHeadshotChance", label = "Headshot %", min = 0, max = 100, step = 1 },
							{ type = "toggle", key = "SilentAimHead", label = "Head Priority", hud = "Head Aim" },
							{ type = "toggle", key = "SilentAimTeamCheck", label = "Team Check", hud = "Team Check" },
							{ type = "toggle", key = "SilentAimWallCheck", label = "Wall Check", hud = "Wall Check" },
							{ type = "toggle", key = "SilentAimWallbang", label = "Wallbang", hud = "Wallbang" },
							{ type = "toggle", key = "SilentAimRangeCircle", label = "Range Circle", hud = "Aim Circle" },
							{ type = "color", key = "SilentAimCircleColor", label = "Circle Color" },
							{ type = "slider", key = "SilentAimCircleTransparency", label = "Circle Alpha", min = 0, max = 1, step = 0.05 },
							{ type = "toggle", key = "SilentAimCircleFilled", label = "Circle Filled", hud = "Circle Fill" },
							{ type = "toggle", key = "AutoReload", label = "Auto Reload", hud = "Auto Reload" },
							{ type = "toggle", key = "AutoReloadSwap", label = "Reload Weapon Swap", hud = "Reload Swap" },
							{ type = "toggle", key = "AutoFire", label = "Auto Fire", hud = "Auto Fire" },
							{ type = "slider", key = "AutoFireRate", label = "Auto Fire Hz", min = 1, max = 120, step = 1 },
							{ type = "toggle", key = "InfiniteAmmo", label = "Infinite Ammo", hud = "Inf Ammo" },
							{ type = "hint", text = "Gun hooks need hookfunction + getconnections. Wall Check prevents shots through walls (better hit reg)." },
						},
					},
				},
			},
			{
				label = "Player",
				sections = {
					{
						title = "MOVEMENT",
						items = {
							{ type = "toggle", key = "SpeedBoost", label = "Speed Boost", hud = "Speed Boost" },
							{ type = "slider", key = "WalkSpeed", label = "Walk Speed", min = 16, max = 26, step = 1 },
							{ type = "slider", key = "JumpPower", label = "Jump Power", min = 50, max = 55, step = 1 },
							{ type = "toggle", key = "NoJumpCooldown", label = "No Jump Cooldown", hud = "No Jump CD" },
							{ type = "toggle", key = "Noclip", label = "Noclip", hud = "Noclip" },
							{ type = "toggle", key = "AlwaysSprint", label = "Hold Sprint Speed", hud = "Sprint" },
							{ type = "slider", key = "SprintSpeed", label = "Sprint Speed", min = 16, max = 26, step = 1 },
							{ type = "toggle", key = "AutoReset", label = "Auto Reset (Criminal)", hud = "Auto Reset" },
							{ type = "toggle", key = "AntiTaze", label = "Anti Taze", hud = "Anti Taze" },
							{ type = "toggle", key = "Disabler", label = "Phase Fix", hud = "Phase Fix" },
							{ type = "toggle", key = "AntiKillPlane", label = "Anti Kill Plane", hud = "Kill Plane" },
							{ type = "hint", text = "Speed/jump capped near game anti-cheat limits. Noclip can still trigger kicks." },
						},
					},
					{
						title = "VEHICLE",
						items = {
							{ type = "toggle", key = "VehicleSpeed", label = "Vehicle Speed", hud = "Vehicle Speed" },
							{ type = "slider", key = "VehicleSpeedValue", label = "Max Speed", min = 80, max = 200, step = 5 },
							{ type = "toggle", key = "VehicleWallbang", label = "Shoot Through Cars", hud = "Car Wallbang" },
							{ type = "toggle", key = "VehicleFly", label = "Vehicle Fly", hud = "Vehicle Fly" },
							{ type = "select", key = "VehicleFlyMode", label = "Fly Mode", options = { "CFrame", "Part" } },
							{ type = "slider", key = "VehicleFlySpeed", label = "Fly Speed", min = 1, max = 100, step = 1 },
						},
					},
					{
						title = "UTILITY",
						items = {
							{ type = "toggle", key = "AntiInvisible", label = "Anti Invisible", hud = "Anti Invis" },
							{ type = "toggle", key = "CheatDetector", label = "Cheat Detector", hud = "Cheat Detect" },
							{ type = "toggle", key = "CameraPhase", label = "Camera Phase", hud = "Cam Phase" },
						},
					},
				},
			},
			{
				label = "Team",
				sections = {
					{
						title = "SWITCH",
						items = {
							{ type = "button", label = "Inmate", onClick = function()
								opts.requestTeamChange("Inmates")
							end },
							{ type = "button", label = "Guard", onClick = function()
								opts.requestTeamChange("Guards")
							end },
							{ type = "button", label = "Neutral", onClick = function()
								opts.requestTeamChange("Neutral")
							end },
							{ type = "hint", text = "Uses Remotes.RequestTeamChange (Guards cap at 9)." },
						},
					},
				},
			},
			{
				label = "Items",
				sections = {
					{
						title = "WEAPONS",
						items = {
							{ type = "button", label = "M9", onClick = function()
								opts.giveGiverWeapon("M9")
							end },
							{ type = "button", label = "Remington 870", onClick = function()
								opts.giveGiverWeapon("Remington 870")
							end },
							{ type = "button", label = "AK-47", onClick = function()
								opts.giveGiverWeapon("AK-47")
							end },
							{ type = "button", label = "Taser", onClick = function()
								opts.giveGiverWeapon("Taser")
							end },
							{ type = "button", label = "MP5", onClick = function()
								opts.giveGiverWeapon("MP5")
							end },
							{ type = "button", label = "FAL", onClick = function()
								opts.giveGiverWeapon("FAL")
							end },
							{ type = "button", label = "M4A1", onClick = function()
								opts.giveGiverWeapon("M4A1")
							end },
							{ type = "button", label = "M700", onClick = function()
								opts.giveGiverWeapon("M700")
							end },
							{ type = "button", label = "Revolver", onClick = function()
								opts.giveGiverWeapon("Revolver")
							end },
						},
					},
					{
						title = "AUTOMATION",
						items = {
							{ type = "toggle", key = "AutoHeal", label = "Auto Heal", hud = "Auto Heal" },
							{ type = "toggle", key = "AutoArmor", label = "Auto Armor", hud = "Auto Armor" },
							{ type = "toggle", key = "AutoPickup", label = "Auto Pickup", hud = "Auto Pickup" },
							{ type = "toggle", key = "AutoDetonate", label = "Auto Detonate C4", hud = "Auto C4" },
							{ type = "toggle", key = "AutoDetonateSafe", label = "C4 Safety Check", hud = "C4 Safe" },
							{ type = "toggle", key = "AntiRiotShield", label = "Anti Riot Shield", hud = "Anti Shield" },
							{ type = "toggle", key = "C4ESP", label = "C4 ESP", hud = "C4 ESP" },
							{ type = "color", key = "C4ESPFillColor", label = "C4 Fill" },
							{ type = "color", key = "C4ESPOutlineColor", label = "C4 Outline" },
							{ type = "slider", key = "C4ESPFillTransparency", label = "C4 Fill Alpha", min = 0, max = 1, step = 0.05 },
							{ type = "slider", key = "C4ESPOutlineTransparency", label = "C4 Outline Alpha", min = 0, max = 1, step = 0.05 },
						},
					},
					{
						title = "PICKUP PRIORITY",
						items = {
							{ type = "select", key = "GuardPickup1", label = "Guard #1", options = PICKUP_WEAPON_OPTIONS },
							{ type = "select", key = "GuardPickup2", label = "Guard #2", options = PICKUP_WEAPON_OPTIONS },
							{ type = "select", key = "PrisonerPickup1", label = "Prisoner #1", options = PICKUP_WEAPON_OPTIONS },
							{ type = "select", key = "PrisonerPickup2", label = "Prisoner #2", options = PICKUP_WEAPON_OPTIONS },
							{ type = "select", key = "CriminalPickup1", label = "Criminal #1", options = PICKUP_WEAPON_OPTIONS },
							{ type = "select", key = "CriminalPickup2", label = "Criminal #2", options = PICKUP_WEAPON_OPTIONS },
						},
					},
				},
			},
			{
				label = "Visual",
				sections = {
					{
						title = "ESP",
						items = {
							{ type = "toggle", key = "ESP", label = "ESP", hud = "ESP" },
							{ type = "toggle", key = "ESPAllies", label = "ESP Allies", hud = "ESP Allies" },
							{ type = "toggle", key = "ESPSnaplines", label = "Snaplines", hud = "Snaplines" },
							{ type = "toggle", key = "ESPStatusTags", label = "Status Tags", hud = "Status Tags" },
							{ type = "color", key = "ESPEnemyColor", label = "Enemy" },
							{ type = "color", key = "ESPAllyColor", label = "Ally" },
							{ type = "color", key = "ESPNeutralColor", label = "Neutral" },
							{ type = "color", key = "ESPHostileColor", label = "Hostile Inmate" },
							{ type = "toggle", key = "FullBright", label = "Full Bright", hud = "Full Bright" },
							{ type = "toggle", key = "KillNotify", label = "Death Notify", hud = "Death Notify" },
							{ type = "toggle", key = "ShowHUD", label = "Module HUD", hud = nil },
						},
					},
					{
						title = "LEGIT",
						items = {
							{ type = "toggle", key = "BulletTracers", label = "Bullet Tracers", hud = "Tracers" },
							{ type = "toggle", key = "BulletTracerDrawing", label = "Drawing Tracers", hud = "Draw Tracers" },
							{ type = "select", key = "BulletTracerMaterial", label = "Tracer Material", options = {
								"SmoothPlastic", "Neon", "Glass", "Metal", "ForceField", "Plastic", "Wood", "Concrete",
							} },
							{ type = "slider", key = "BulletTracerLifetime", label = "Tracer Life", min = 0.05, max = 0.5, step = 0.05 },
							{ type = "toggle", key = "BulletTracerFade", label = "Tracer Fade", hud = "Tracer Fade" },
							{ type = "color", key = "BulletTracerColor", label = "Tracer Color" },
							{ type = "toggle", key = "DamageIndicator", label = "Damage Indicator", hud = "Dmg Ind" },
							{ type = "color", key = "DamageIndicatorColor", label = "Damage Color" },
							{ type = "toggle", key = "HitSound", label = "Hit Sound", hud = "Hit Sound" },
							{ type = "slider", key = "HitSoundVolume", label = "Hit Volume", min = 0, max = 2, step = 0.1 },
							{ type = "toggle", key = "HitSoundPitchShift", label = "Hit Pitch Shift", hud = "Hit Pitch" },
							{ type = "toggle", key = "KillSound", label = "Kill Sound", hud = "Kill Sound" },
							{ type = "slider", key = "KillSoundVolume", label = "Kill Volume", min = 0, max = 2, step = 0.1 },
							{ type = "toggle", key = "KillSoundPitchShift", label = "Kill Pitch Shift", hud = "Kill Pitch" },
							{ type = "toggle", key = "Viewmodel", label = "Viewmodel", hud = "Viewmodel" },
							{ type = "slider", key = "ViewmodelDepth", label = "VM Depth", min = 0, max = 3, step = 0.1 },
							{ type = "slider", key = "ViewmodelHorizontal", label = "VM Horizontal", min = 0, max = 2, step = 0.1 },
							{ type = "slider", key = "ViewmodelVertical", label = "VM Vertical", min = -1.5, max = 2, step = 0.1 },
							{ type = "toggle", key = "ViewmodelSway", label = "VM Sway", hud = "VM Sway" },
							{ type = "toggle", key = "ViewmodelForceField", label = "VM ForceField", hud = "VM FF" },
							{ type = "color", key = "ViewmodelForceFieldColor", label = "VM FF Color" },
							{ type = "toggle", key = "Crosshair", label = "Custom Crosshair", hud = "Crosshair" },
							{ type = "hint", text = "Crosshair image: set CrosshairImage in config (rbxassetid) when custom crosshair is enabled." },
						},
					},
				},
			},
		},
		hud = { showKey = "ShowHUD" },
		onToggle = opts.onToggle,
		onChange = opts.onChange,
	}
end

return M
