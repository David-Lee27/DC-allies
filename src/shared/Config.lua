-- Global game tuning. Everything balance-related lives here or in Heroes.lua.
local Config = {}

Config.GameTitle = "ALLIES: HERO CLASH"

-- Teams
Config.TeamSize = 6 -- per team; empty slots are filled with bots
Config.FillWithBots = true
Config.Teams = {
	Blue = { Name = "Blue", Color = Color3.fromRGB(70, 150, 255), BrickColor = BrickColor.new("Really blue") },
	Red = { Name = "Red", Color = Color3.fromRGB(255, 75, 75), BrickColor = BrickColor.new("Really red") },
}

-- Match flow (seconds)
Config.HeroSelectTime = 25
Config.PrepTime = 10
Config.RoundEndTime = 6
Config.MatchEndTime = 12
Config.RoundsToWin = 2
Config.RespawnTime = 6

-- Domination point
Config.PointRadius = 16
Config.CaptureTime = 8 -- seconds for one hero to capture a neutral/enemy point
Config.ScoreTime = 80 -- seconds of uninterrupted control to win a round (0 -> 100%)

-- Spawn rooms
Config.SpawnHealPerSecond = 80
Config.SpawnEnemyDamagePerSecond = 150

-- Ultimate charge
Config.UltPerDamage = 0.06 -- ult % gained per point of damage dealt
Config.UltPerHeal = 0.06 -- ult % gained per point of healing done
Config.UltPassivePerSecond = 0.4

Config.RoleOrder = { "Vanguard", "Duelist", "Strategist" }
Config.RoleColors = {
	Vanguard = Color3.fromRGB(90, 170, 255),
	Duelist = Color3.fromRGB(255, 110, 90),
	Strategist = Color3.fromRGB(110, 230, 140),
}

Config.Slots = { "Primary", "Ability1", "Ability2", "Ultimate" }
Config.SlotKeys = { Primary = "LMB", Ability1 = "SHIFT", Ability2 = "E", Ultimate = "Q" }

return Config
