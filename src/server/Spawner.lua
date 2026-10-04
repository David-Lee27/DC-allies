-- Spawns / despawns hero bodies for players and bots, and reports deaths.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Heroes = require(ReplicatedStorage.Shared.Heroes)
local Util = require(ReplicatedStorage.Shared.Util)
local Combatants = require(script.Parent.Combatants)
local Combat = require(script.Parent.Combat)
local HeroOutfits = require(script.Parent.HeroOutfits)
local MapBuilder = require(script.Parent.MapBuilder)
local Bots = require(script.Parent.Bots)

local Spawner = {}
Spawner.OnDeath = nil -- set by Match: function(c)

local botFolder

local function spawnCFrame(team)
	local points = MapBuilder.Info.SpawnPoints[team]
	local cf = points[math.random(1, #points)]
	return cf + Vector3.new(math.random(-15, 15) / 10, 0, math.random(-15, 15) / 10)
end

local function handleDeath(c, model)
	if c.model ~= model or not c.alive then
		return
	end
	c.alive = false
	c.statuses = {}
	c.entry:SetAttribute("Alive", false)
	Combatants.AddStat(c, "Deaths", 1)

	local killer = c.lastDamager
	if killer and (os.clock() - c.lastDamagerTime) > 10 then
		killer = nil
	end
	if killer and killer.removed then
		killer = nil
	end
	if killer then
		Combatants.AddStat(killer, "Kills", 1)
		Combat.Notify(killer, "announceSmall", { text = "ELIMINATED " .. string.upper(c.name) })
	end
	Combat.NotifyAll("killfeed", {
		killer = killer and killer.name or nil,
		killerTeam = killer and killer.team or nil,
		killerHero = killer and killer.heroId or nil,
		victim = c.name,
		victimTeam = c.team,
		victimHero = c.heroId,
		source = c.lastDamageSource,
	})
	Combat.Notify(c, "death", { killer = killer and killer.name or nil, killerHero = killer and killer.heroId or nil })

	if c.isBot then
		task.delay(3, function()
			if c.model == model then
				Combatants.ByModel[model] = nil
				model:Destroy()
				if c.model == model then
					c.model = nil
				end
			end
		end)
	end
	if Spawner.OnDeath then
		Spawner.OnDeath(c)
	end
end

local function setup(c, model, cf)
	local hero = Heroes.Get(c.heroId)
	local humanoid = model:WaitForChild("Humanoid", 5)
	local root = model:WaitForChild("HumanoidRootPart", 5)
	if not humanoid or not root then
		return
	end
	HeroOutfits.Apply(model, c.heroId)
	humanoid.MaxHealth = hero.health
	humanoid.Health = hero.health
	humanoid.WalkSpeed = hero.speed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 50
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	model:PivotTo(cf)

	Combatants.AttachModel(c, model)
	c.entry:SetAttribute("RespawnAt", 0)

	humanoid.Died:Connect(function()
		handleDeath(c, model)
	end)
	if c.isBot then
		root:SetNetworkOwner(nil)
		Bots.Attach(c)
	end
end

function Spawner.Spawn(c, cf)
	if c.removed or not c.heroId then
		return
	end
	c.spawnToken += 1
	local token = c.spawnToken
	cf = cf or spawnCFrame(c.team)
	c.alive = false
	local desc = HeroOutfits.Description(c.heroId)

	if c.player then
		if c.model then
			Combatants.ByModel[c.model] = nil
		end
		local ok, err = pcall(function()
			c.player:LoadCharacterWithHumanoidDescription(desc)
		end)
		if not ok then
			warn("LoadCharacter failed:", err)
			return
		end
		if c.spawnToken ~= token or c.removed then
			return
		end
		setup(c, c.player.Character, cf)
	else
		if c.model then
			Combatants.ByModel[c.model] = nil
			c.model:Destroy()
			c.model = nil
		end
		local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		model.Name = c.name
		local animate = model:FindFirstChild("Animate")
		if animate then
			animate:Destroy()
		end
		if not botFolder or not botFolder.Parent then
			botFolder = Instance.new("Folder")
			botFolder.Name = "Bots"
			botFolder.Parent = workspace
		end
		model:PivotTo(cf)
		model.Parent = botFolder
		setup(c, model, cf)
	end
end

function Spawner.Despawn(c)
	c.spawnToken += 1
	c.alive = false
	c.entry:SetAttribute("Alive", false)
	if c.model then
		Combatants.ByModel[c.model] = nil
		c.model:Destroy()
		c.model = nil
	end
	if c.player then
		c.player.Character = nil
	end
end

function Spawner.ScheduleRespawn(c, delay, canSpawn)
	local token = c.spawnToken
	c.entry:SetAttribute("RespawnAt", Util.now() + delay)
	task.delay(delay, function()
		if c.spawnToken == token and not c.removed and not c.alive and canSpawn() then
			Spawner.Spawn(c)
		end
	end)
end

return Spawner
