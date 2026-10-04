--[[
	Hero roster. All heroes are ORIGINAL characters (archetypes only, no licensed names/logos).

	Every ability has a `kind` that maps to a generic handler in server/Abilities.lua.
	Supported kinds and their fields:
	  hitscan    damage, range, [healAllies], [pellets, spread]
	  projectile damage, speed, range, [size], [splashRadius, splashDamage], [healAllies]
	  melee      damage, range, angle
	  dash       speed, duration, [damage, radius, knockback, stun]
	  cone       damage, range, angle, [slow, slowDuration, knockback]
	  aoe        radius, [damage, heal, stun, knockback]                (centered on caster)
	  zone       radius, duration, tick, [placement "aim"/"self", range, damagePerTick, healPerTick, slow, pull]
	  buff       target "self"/"team", duration, [radius, speedMult, damageMult, damageReduction, heal]
	  leapSlam   up, forward, radius, damage, [knockback]
	  grapple    range, speed
	  pull       range, damage, [stun]
	  teleport   range
	  wall       width, height, duration
	  barrage    count, radius, strikeRadius, damage, interval, [placement "aim"/"self", range]
	Every non-primary ability has `cooldown`; the Ultimate costs 100% charge instead.
]]

local Heroes = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Heroes.List = {
	------------------------------------------------------------------ VANGUARDS
	{
		id = "TitanPrime",
		name = "Titan Prime",
		role = "Vanguard",
		health = 650,
		speed = 16,
		color = rgb(40, 90, 220),
		description = "An invulnerable powerhouse from a fallen star. Charges into fights and slams the ground with solar fury.",
		outfit = {
			skin = rgb(234, 184, 146), torso = rgb(35, 75, 200), arms = rgb(35, 75, 200), legs = rgb(35, 75, 200),
			cape = rgb(200, 30, 40), emblem = { text = "T", color = rgb(220, 30, 40), bg = rgb(255, 210, 40) },
			glow = rgb(255, 220, 120),
		},
		abilities = {
			Primary = { name = "Heat Vision", kind = "hitscan", damage = 8, cooldown = 0.1, range = 70, color = rgb(255, 80, 40) },
			Ability1 = { name = "Sky Charge", kind = "dash", cooldown = 8, speed = 90, duration = 0.4, damage = 35, radius = 7, knockback = 70, color = rgb(120, 170, 255) },
			Ability2 = { name = "Frost Breath", kind = "cone", cooldown = 10, range = 22, angle = 70, damage = 40, slow = 0.5, slowDuration = 2.5, color = rgb(180, 230, 255) },
			Ultimate = { name = "Solar Slam", kind = "leapSlam", up = 70, forward = 60, radius = 20, damage = 160, knockback = 90, color = rgb(255, 200, 60) },
		},
	},
	{
		id = "Valkyra",
		name = "Valkyra",
		role = "Vanguard",
		health = 600,
		speed = 17,
		color = rgb(200, 40, 50),
		description = "A warrior princess of a hidden island. Shield-bashes enemies, lassoes stragglers and rallies her allies.",
		outfit = {
			skin = rgb(205, 150, 110), torso = rgb(190, 30, 40), arms = rgb(205, 150, 110), legs = rgb(30, 50, 140),
			helmet = "tiara", helmetColor = rgb(255, 200, 50), emblem = { text = "W", color = rgb(255, 200, 50), bg = rgb(190, 30, 40) },
			weapon = "sword", weaponColor = rgb(210, 210, 220), shield = rgb(200, 160, 40), glow = rgb(255, 210, 120),
		},
		abilities = {
			Primary = { name = "Blade Sweep", kind = "melee", damage = 38, cooldown = 0.55, range = 10, angle = 110, color = rgb(255, 230, 180) },
			Ability1 = { name = "Shield Bash", kind = "dash", cooldown = 7, speed = 85, duration = 0.35, damage = 30, radius = 6, stun = 0.8, knockback = 30, color = rgb(255, 200, 60) },
			Ability2 = { name = "Binding Lasso", kind = "pull", cooldown = 10, range = 35, damage = 20, stun = 0.6, color = rgb(255, 210, 60) },
			Ultimate = { name = "Aegis Rally", kind = "buff", target = "team", radius = 30, duration = 6, damageReduction = 0.4, heal = 150, color = rgb(255, 220, 100) },
		},
	},
	{
		id = "Ironclad",
		name = "Ironclad",
		role = "Vanguard",
		health = 700,
		speed = 15,
		color = rgb(150, 160, 175),
		description = "Half man, half machine. Fires explosive arm-cannon shells, deploys barriers and calls down orbital strikes.",
		outfit = {
			skin = rgb(120, 80, 60), torso = rgb(160, 165, 175), arms = rgb(160, 165, 175), legs = rgb(90, 95, 105),
			helmet = "visor", helmetColor = rgb(255, 50, 50), emblem = { text = "◉", color = rgb(255, 60, 60), bg = rgb(60, 65, 75) },
			weapon = "cannon", weaponColor = rgb(80, 85, 95), glow = rgb(255, 80, 80),
		},
		abilities = {
			Primary = { name = "Arm Cannon", kind = "projectile", damage = 25, cooldown = 0.45, speed = 140, range = 120, size = 1.2, splashRadius = 6, splashDamage = 15, color = rgb(255, 120, 60) },
			Ability1 = { name = "Rocket Leap", kind = "leapSlam", cooldown = 9, up = 60, forward = 50, radius = 10, damage = 40, knockback = 40, color = rgb(255, 150, 60) },
			Ability2 = { name = "Barrier Wall", kind = "wall", cooldown = 14, width = 14, height = 9, duration = 6, color = rgb(120, 200, 255) },
			Ultimate = { name = "Orbital Barrage", kind = "barrage", placement = "aim", range = 80, count = 14, radius = 18, strikeRadius = 7, damage = 45, interval = 0.15, color = rgb(255, 80, 60) },
		},
	},
	------------------------------------------------------------------ DUELISTS
	{
		id = "Nightwarden",
		name = "Nightwarden",
		role = "Duelist",
		health = 275,
		speed = 18,
		color = rgb(45, 45, 60),
		description = "A masked detective of the night. Throws razor wing-blades, grapples across rooftops and strikes from the shadows.",
		outfit = {
			skin = rgb(230, 180, 140), torso = rgb(60, 60, 70), arms = rgb(60, 60, 70), legs = rgb(60, 60, 70),
			cape = rgb(25, 25, 30), helmet = "cowl", helmetColor = rgb(25, 25, 30),
			emblem = { text = "◆", color = rgb(20, 20, 20), bg = rgb(255, 210, 40) }, glow = rgb(140, 140, 255),
		},
		abilities = {
			Primary = { name = "Wing Blades", kind = "projectile", damage = 30, cooldown = 0.35, speed = 180, range = 120, size = 0.8, color = rgb(200, 200, 220) },
			Ability1 = { name = "Grapple Line", kind = "grapple", cooldown = 7, range = 60, speed = 110, color = rgb(160, 160, 180) },
			Ability2 = { name = "Smoke Bomb", kind = "zone", cooldown = 12, placement = "aim", range = 40, radius = 12, duration = 4, tick = 0.5, damagePerTick = 8, slow = 0.6, color = rgb(90, 90, 110) },
			Ultimate = { name = "Night Raid", kind = "leapSlam", up = 80, forward = 80, radius = 16, damage = 200, knockback = 60, color = rgb(120, 110, 255) },
		},
	},
	{
		id = "Volt",
		name = "Volt",
		role = "Duelist",
		health = 250,
		speed = 20,
		color = rgb(230, 40, 40),
		description = "The fastest hero alive. Blurs between targets with lightning jabs and unleashes a storm around himself.",
		outfit = {
			skin = rgb(234, 184, 146), torso = rgb(200, 25, 30), arms = rgb(200, 25, 30), legs = rgb(200, 25, 30),
			helmet = "hood", helmetColor = rgb(200, 25, 30), emblem = { text = "⚡", color = rgb(255, 220, 40), bg = rgb(255, 255, 255) },
			glow = rgb(255, 220, 60),
		},
		abilities = {
			Primary = { name = "Rapid Jabs", kind = "melee", damage = 14, cooldown = 0.15, range = 8, angle = 90, color = rgb(255, 230, 80) },
			Ability1 = { name = "Speed Burst", kind = "buff", target = "self", cooldown = 8, duration = 3, speedMult = 1.8, color = rgb(255, 220, 60) },
			Ability2 = { name = "Static Shock", kind = "aoe", cooldown = 10, radius = 12, damage = 50, stun = 0.7, color = rgb(255, 240, 120) },
			Ultimate = { name = "Lightning Storm", kind = "barrage", placement = "self", count = 20, radius = 22, strikeRadius = 7, damage = 40, interval = 0.12, color = rgb(255, 240, 90) },
		},
	},
	{
		id = "Tidecaller",
		name = "Tidecaller",
		role = "Duelist",
		health = 300,
		speed = 17,
		color = rgb(40, 170, 120),
		description = "Monarch of the deep seas. Hurls trident bolts, rides the riptide and summons a crushing maelstrom.",
		outfit = {
			skin = rgb(234, 184, 146), torso = rgb(230, 150, 30), arms = rgb(234, 184, 146), legs = rgb(30, 140, 90),
			helmet = "crown", helmetColor = rgb(255, 200, 40), emblem = { text = "Ψ", color = rgb(30, 140, 90), bg = rgb(230, 150, 30) },
			weapon = "trident", weaponColor = rgb(255, 200, 40), glow = rgb(60, 220, 200),
		},
		abilities = {
			Primary = { name = "Trident Bolt", kind = "projectile", damage = 40, cooldown = 0.55, speed = 150, range = 100, size = 1, color = rgb(60, 220, 220) },
			Ability1 = { name = "Riptide Blink", kind = "teleport", cooldown = 8, range = 30, color = rgb(60, 200, 255) },
			Ability2 = { name = "Wave Surge", kind = "cone", cooldown = 9, range = 20, angle = 80, damage = 45, knockback = 70, color = rgb(60, 180, 255) },
			Ultimate = { name = "Maelstrom", kind = "zone", placement = "aim", range = 50, radius = 18, duration = 5, tick = 0.25, damagePerTick = 10, pull = 25, slow = 0.5, color = rgb(40, 140, 255) },
		},
	},
	------------------------------------------------------------------ STRATEGISTS
	{
		id = "EmeraldSentinel",
		name = "Emerald Sentinel",
		role = "Strategist",
		health = 275,
		speed = 17,
		color = rgb(40, 200, 80),
		description = "Bearer of a ring powered by willpower. Builds light constructs to shield and heal the team.",
		outfit = {
			skin = rgb(170, 120, 90), torso = rgb(30, 160, 60), arms = rgb(25, 25, 30), legs = rgb(25, 25, 30),
			helmet = "mask", helmetColor = rgb(30, 200, 70), emblem = { text = "◎", color = rgb(255, 255, 255), bg = rgb(30, 160, 60) },
			weapon = "ring", weaponColor = rgb(60, 255, 100), glow = rgb(60, 255, 100),
		},
		abilities = {
			Primary = { name = "Construct Bolts", kind = "projectile", damage = 18, healAllies = 18, cooldown = 0.25, speed = 160, range = 110, size = 0.8, color = rgb(60, 255, 100) },
			Ability1 = { name = "Light Barrier", kind = "wall", cooldown = 12, width = 12, height = 8, duration = 5, color = rgb(60, 255, 100) },
			Ability2 = { name = "Healing Glow", kind = "aoe", cooldown = 9, radius = 20, heal = 90, color = rgb(100, 255, 140) },
			Ultimate = { name = "Willpower Dome", kind = "zone", placement = "self", radius = 22, duration = 6, tick = 0.5, healPerTick = 35, color = rgb(60, 255, 100) },
		},
	},
	{
		id = "Arcanist",
		name = "Arcanist",
		role = "Strategist",
		health = 250,
		speed = 17,
		color = rgb(140, 70, 220),
		description = "A stage magician who wields real sorcery. Arcane orbs harm foes and mend allies; runes restore the team.",
		outfit = {
			skin = rgb(234, 184, 146), torso = rgb(30, 30, 40), arms = rgb(30, 30, 40), legs = rgb(30, 30, 40),
			cape = rgb(120, 50, 200), helmet = "tophat", helmetColor = rgb(25, 25, 30),
			emblem = { text = "✦", color = rgb(190, 140, 255), bg = rgb(30, 30, 40) }, weapon = "staff", weaponColor = rgb(190, 140, 255),
			glow = rgb(170, 110, 255),
		},
		abilities = {
			Primary = { name = "Arcane Orb", kind = "projectile", damage = 22, healAllies = 30, cooldown = 0.4, speed = 110, range = 100, size = 1.2, color = rgb(190, 120, 255) },
			Ability1 = { name = "Mystic Blink", kind = "teleport", cooldown = 7, range = 25, color = rgb(190, 120, 255) },
			Ability2 = { name = "Mending Rune", kind = "zone", cooldown = 12, placement = "aim", range = 40, radius = 12, duration = 5, tick = 0.5, healPerTick = 15, color = rgb(200, 150, 255) },
			Ultimate = { name = "Ankh of Renewal", kind = "aoe", radius = 30, heal = 300, color = rgb(230, 200, 255) },
		},
	},
	{
		id = "Circuit",
		name = "Circuit",
		role = "Strategist",
		health = 275,
		speed = 17,
		color = rgb(255, 170, 30),
		description = "A teen tech genius in a jet-powered suit. Sonic blasts hurt enemies and patch up friends; Overclock supercharges the team.",
		outfit = {
			skin = rgb(160, 110, 80), torso = rgb(255, 160, 30), arms = rgb(60, 60, 70), legs = rgb(60, 60, 70),
			helmet = "visor", helmetColor = rgb(80, 220, 255), emblem = { text = "⚙", color = rgb(60, 60, 70), bg = rgb(255, 160, 30) },
			weapon = "cannon", weaponColor = rgb(255, 160, 30), glow = rgb(80, 220, 255),
		},
		abilities = {
			Primary = { name = "Sonic Blaster", kind = "hitscan", damage = 10, healAllies = 10, cooldown = 0.12, range = 60, color = rgb(80, 220, 255) },
			Ability1 = { name = "Rocket Boost", kind = "dash", cooldown = 6, speed = 80, duration = 0.35, color = rgb(255, 170, 60) },
			Ability2 = { name = "Repair Pulse", kind = "aoe", cooldown = 8, radius = 18, heal = 70, color = rgb(80, 220, 255) },
			Ultimate = { name = "Overclock", kind = "buff", target = "team", radius = 35, duration = 8, speedMult = 1.3, damageMult = 1.3, heal = 100, color = rgb(255, 200, 60) },
		},
	},
}

Heroes.ById = {}
for _, hero in ipairs(Heroes.List) do
	Heroes.ById[hero.id] = hero
end

function Heroes.Get(id)
	return Heroes.ById[id]
end

function Heroes.IsHealing(ability)
	return (ability.heal or ability.healPerTick or ability.healAllies) ~= nil
end

return Heroes
