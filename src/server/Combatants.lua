-- Registry of everyone in the match (players and bots). A combatant persists across deaths;
-- its `model` changes every time it respawns.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = require(ReplicatedStorage.Shared.Util)

local Combatants = {}
Combatants.All = {} -- id -> combatant
Combatants.ByModel = {} -- model -> combatant

local rosterFolder

function Combatants.Init()
	rosterFolder = ReplicatedStorage:FindFirstChild("Roster") or Instance.new("Folder")
	rosterFolder.Name = "Roster"
	rosterFolder.Parent = ReplicatedStorage
end

function Combatants.Create(id, name, team, player)
	local entry = Instance.new("Configuration")
	entry.Name = id
	entry:SetAttribute("DisplayName", name)
	entry:SetAttribute("Team", team)
	entry:SetAttribute("IsBot", player == nil)
	entry:SetAttribute("Hero", "")
	entry:SetAttribute("Kills", 0)
	entry:SetAttribute("Deaths", 0)
	entry:SetAttribute("Damage", 0)
	entry:SetAttribute("Healing", 0)
	entry:SetAttribute("Ult", 0)
	entry:SetAttribute("Alive", false)
	entry:SetAttribute("RespawnAt", 0)
	entry.Parent = rosterFolder

	local c = {
		id = id,
		name = name,
		team = team,
		player = player,
		isBot = player == nil,
		heroId = nil,
		model = nil,
		humanoid = nil,
		root = nil,
		alive = false,
		cooldowns = {},
		ult = 0,
		statuses = {},
		entry = entry,
		lastDamager = nil,
		lastDamagerTime = 0,
		spawnToken = 0,
	}
	Combatants.All[id] = c
	return c
end

function Combatants.Remove(c)
	if c.model then
		Combatants.ByModel[c.model] = nil
		c.model:Destroy()
	end
	c.alive = false
	c.removed = true
	c.entry:Destroy()
	Combatants.All[c.id] = nil
end

function Combatants.SetTeam(c, team)
	c.team = team
	c.entry:SetAttribute("Team", team)
	if c.player then
		c.player.Team = game:GetService("Teams"):FindFirstChild(team)
	end
end

function Combatants.SetHero(c, heroId)
	c.heroId = heroId
	c.entry:SetAttribute("Hero", heroId or "")
end

function Combatants.AttachModel(c, model)
	if c.model and c.model ~= model then
		Combatants.ByModel[c.model] = nil
	end
	c.model = model
	c.humanoid = model:FindFirstChildOfClass("Humanoid")
	c.root = model:FindFirstChild("HumanoidRootPart")
	c.alive = true
	c.statuses = {}
	c.lastDamager = nil
	c.cooldowns = {}
	model:SetAttribute("Team", c.team)
	model:SetAttribute("CombatantId", c.id)
	model:SetAttribute("Hero", c.heroId)
	model:SetAttribute("DisplayName", c.name)
	CollectionService:AddTag(model, "Combatant")
	Combatants.ByModel[model] = c
	c.entry:SetAttribute("Alive", true)
	for _, slot in ipairs({ "Primary", "Ability1", "Ability2", "Ultimate" }) do
		c.entry:SetAttribute("CD_" .. slot, 0)
		c.entry:SetAttribute("CDMax_" .. slot, 1)
	end
end

function Combatants.FromPart(part)
	local node = part
	while node and node ~= workspace do
		local c = Combatants.ByModel[node]
		if c then
			return c
		end
		node = node.Parent
	end
	return nil
end

function Combatants.ForEachAlive(fn)
	for _, c in pairs(Combatants.All) do
		if c.alive and c.root and c.humanoid and c.humanoid.Health > 0 then
			fn(c)
		end
	end
end

function Combatants.CountTeam(team, botsOnly)
	local n = 0
	for _, c in pairs(Combatants.All) do
		if c.team == team and (not botsOnly or c.isBot) then
			n += 1
		end
	end
	return n
end

function Combatants.CountHumans(team)
	local n = 0
	for _, c in pairs(Combatants.All) do
		if c.team == team and not c.isBot then
			n += 1
		end
	end
	return n
end

function Combatants.AddStat(c, stat, amount)
	c.entry:SetAttribute(stat, (c.entry:GetAttribute(stat) or 0) + amount)
end

function Combatants.AddUlt(c, amount)
	if not c.alive and amount > 0 then
		return
	end
	c.ult = math.clamp(c.ult + amount, 0, 100)
	c.entry:SetAttribute("Ult", math.floor(c.ult * 10) / 10)
end

function Combatants.SetCooldown(c, slot, duration)
	c.cooldowns[slot] = Util.now() + duration
	c.entry:SetAttribute("CD_" .. slot, c.cooldowns[slot])
	c.entry:SetAttribute("CDMax_" .. slot, duration)
end

function Combatants.IsReady(c, slot)
	return Util.now() >= (c.cooldowns[slot] or 0) - 0.06
end

return Combatants
