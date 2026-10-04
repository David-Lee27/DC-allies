-- Match flow: Hero Select -> rounds of Domination (best of 3) -> Match End -> repeat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Heroes = require(ReplicatedStorage.Shared.Heroes)
local Util = require(ReplicatedStorage.Shared.Util)
local Combatants = require(script.Parent.Combatants)
local Combat = require(script.Parent.Combat)
local Abilities = require(script.Parent.Abilities)
local MapBuilder = require(script.Parent.MapBuilder)
local Spawner = require(script.Parent.Spawner)
local Bots = require(script.Parent.Bots)

local Match = {}

local state -- MatchState Configuration (replicated)
local botCounter = 0

local function getState()
	return state:GetAttribute("State")
end

local function setState(name, duration)
	state:SetAttribute("State", name)
	state:SetAttribute("StateEnds", Util.now() + (duration or 0))
end

local function respawnAllowed()
	local s = getState()
	return s == "Preparing" or s == "InProgress"
end

local function otherTeam(team)
	return team == "Blue" and "Red" or "Blue"
end

------------------------------------------------------------------ hero picking
local function heroTaken(team, heroId, except)
	for _, c in pairs(Combatants.All) do
		if c ~= except and c.team == team and c.heroId == heroId then
			return c
		end
	end
	return nil
end

local function pickFreeHero(team, except)
	local roleCount = { Vanguard = 0, Duelist = 0, Strategist = 0 }
	for _, c in pairs(Combatants.All) do
		if c ~= except and c.team == team and c.heroId then
			local h = Heroes.Get(c.heroId)
			roleCount[h.role] += 1
		end
	end
	local roles = table.clone(Config.RoleOrder)
	for i = #roles, 2, -1 do -- shuffle so ties break randomly, then sort by how many picked each role
		local j = math.random(1, i)
		roles[i], roles[j] = roles[j], roles[i]
	end
	local tiebreak = {}
	for i, role in ipairs(roles) do
		tiebreak[role] = i
	end
	table.sort(roles, function(a, b)
		if roleCount[a] == roleCount[b] then
			return tiebreak[a] < tiebreak[b]
		end
		return roleCount[a] < roleCount[b]
	end)
	for _, role in ipairs(roles) do
		local options = {}
		for _, h in ipairs(Heroes.List) do
			if h.role == role and not heroTaken(team, h.id, except) then
				table.insert(options, h.id)
			end
		end
		if #options > 0 then
			return options[math.random(1, #options)]
		end
	end
	return Heroes.List[math.random(1, #Heroes.List)].id
end

------------------------------------------------------------------ bots
local function addBot(team)
	botCounter += 1
	local name = Bots.Names[(botCounter - 1) % #Bots.Names + 1]
	local c = Combatants.Create("Bot_" .. botCounter, name .. " [BOT]", team, nil)
	Combatants.SetHero(c, pickFreeHero(team, c))
	return c
end

local function removeOneBot(team)
	for _, c in pairs(Combatants.All) do
		if c.isBot and c.team == team then
			Combatants.Remove(c)
			return true
		end
	end
	return false
end

local function fillBots()
	if not Config.FillWithBots then
		return
	end
	for _, team in ipairs({ "Blue", "Red" }) do
		while Combatants.CountTeam(team) < Config.TeamSize do
			addBot(team)
		end
	end
end

local function removeAllBots()
	for _, c in pairs(Combatants.All) do
		if c.isBot then
			Combatants.Remove(c)
		end
	end
end

------------------------------------------------------------------ players
local function chooseTeamForNewPlayer()
	local blue, red = Combatants.CountHumans("Blue"), Combatants.CountHumans("Red")
	if blue ~= red then
		return blue < red and "Blue" or "Red"
	end
	return Combatants.CountTeam("Blue") <= Combatants.CountTeam("Red") and "Blue" or "Red"
end

local function onPlayerAdded(player)
	local team = chooseTeamForNewPlayer()
	if Combatants.CountTeam(team) >= Config.TeamSize then
		if not removeOneBot(team) then
			team = otherTeam(team)
			removeOneBot(team)
		end
	end
	local c = Combatants.Create(tostring(player.UserId), player.DisplayName, team, player)
	Combatants.SetTeam(c, team)
	local s = getState()
	if s ~= "HeroSelect" and s ~= "Waiting" then
		task.delay(1, function()
			Combat.Notify(c, "openSelect", { force = true })
		end)
	end
end

local function onPlayerRemoving(player)
	local c = Combatants.All[tostring(player.UserId)]
	if not c then
		return
	end
	local team = c.team
	Combatants.Remove(c)
	if Config.FillWithBots and respawnAllowed() and #Players:GetPlayers() > 1 then
		local bot = addBot(team)
		Spawner.Spawn(bot)
	end
end

local function onPickHero(player, heroId)
	local c = Combatants.All[tostring(player.UserId)]
	if not c or typeof(heroId) ~= "string" or not Heroes.Get(heroId) then
		return
	end
	local holder = heroTaken(c.team, heroId, c)
	if holder and not holder.isBot then
		Combat.Notify(c, "pickResult", { ok = false, reason = holder.name .. " already picked that hero" })
		return
	end
	local s = getState()
	if s ~= "HeroSelect" and c.alive and not MapBuilder.IsInSpawn(c.team, c.root.Position) then
		Combat.Notify(c, "pickResult", { ok = false, reason = "You can only swap heroes in your spawn room" })
		return
	end
	if holder then
		Combatants.SetHero(holder, pickFreeHero(holder.team, holder))
		if holder.alive and s ~= "HeroSelect" then
			task.spawn(Spawner.Spawn, holder)
		end
	end
	Combatants.SetHero(c, heroId)
	Combat.Notify(c, "pickResult", { ok = true, hero = heroId })

	if s == "HeroSelect" or s == "Waiting" then
		return
	end
	-- mid-match: swap immediately if alive in spawn or never spawned; otherwise applies on respawn
	local pendingRespawn = (c.entry:GetAttribute("RespawnAt") or 0) > Util.now()
	if c.alive or (not pendingRespawn and s ~= "MatchEnd") then
		Spawner.Spawn(c)
	end
end

------------------------------------------------------------------ objective
local point = { owner = nil, captureTeam = nil, progress = 0, scores = { Blue = 0, Red = 0 } }

local function paintPoint(color)
	local info = MapBuilder.Info
	info.Ring.Color = color
	info.Beacon.Color = color
	for _, p in ipairs(info.Map:GetChildren()) do
		if p.Name == "PointLamp" then
			p.Color = color
			local light = p:FindFirstChildOfClass("PointLight")
			if light then
				light.Color = color
			end
		end
	end
end

local function resetPoint()
	point.owner = nil
	point.captureTeam = nil
	point.progress = 0
	point.scores.Blue = 0
	point.scores.Red = 0
	paintPoint(Color3.fromRGB(230, 230, 230))
end

local function publishPoint(onPoint, contested)
	state:SetAttribute("PointOwner", point.owner or "")
	state:SetAttribute("CaptureTeam", point.captureTeam or "")
	state:SetAttribute("CaptureProgress", math.floor(point.progress))
	state:SetAttribute("BlueScore", math.floor(point.scores.Blue * 10) / 10)
	state:SetAttribute("RedScore", math.floor(point.scores.Red * 10) / 10)
	state:SetAttribute("BlueOnPoint", onPoint.Blue)
	state:SetAttribute("RedOnPoint", onPoint.Red)
	state:SetAttribute("Contested", contested)
end

local function updatePoint(dt)
	local center = MapBuilder.Info.PointCenter
	local onPoint = { Blue = 0, Red = 0 }
	Combatants.ForEachAlive(function(c)
		local d = c.root.Position - center
		if Vector3.new(d.X, 0, d.Z).Magnitude <= Config.PointRadius and d.Y < 12 then
			onPoint[c.team] += 1
		end
	end)
	local contested = onPoint.Blue > 0 and onPoint.Red > 0
	local solo = (onPoint.Blue > 0 and not contested and "Blue") or (onPoint.Red > 0 and not contested and "Red") or nil

	if solo and solo ~= point.owner then
		if point.captureTeam ~= solo then
			-- enemy progress must drain first
			point.progress -= dt * (100 / Config.CaptureTime) * 1.5
			if point.progress <= 0 then
				point.progress = 0
				point.captureTeam = solo
			end
		else
			local mult = math.min(1 + 0.25 * (onPoint[solo] - 1), 1.75)
			point.progress += dt * (100 / Config.CaptureTime) * mult
			if point.progress >= 100 then
				point.owner = solo
				point.captureTeam = nil
				point.progress = 0
				paintPoint(Config.Teams[solo].Color)
				Combat.NotifyAll("announce", { text = string.upper(solo) .. " TEAM CAPTURED THE POINT", color = Config.Teams[solo].Color })
			end
		end
	elseif not solo and not contested and point.progress > 0 then
		point.progress = math.max(0, point.progress - dt * 10)
		if point.progress == 0 then
			point.captureTeam = nil
		end
	end

	if point.owner then
		local s = point.scores[point.owner] + dt * (100 / Config.ScoreTime)
		local enemyOnPoint = onPoint[otherTeam(point.owner)] > 0
		if enemyOnPoint and s >= 99 then
			s = 99 -- overtime: can't win while the point is contested
		end
		point.scores[point.owner] = math.min(s, 100)
	end
	publishPoint(onPoint, contested)

	if point.scores.Blue >= 100 then
		return "Blue"
	elseif point.scores.Red >= 100 then
		return "Red"
	end
	return nil
end

local function spawnRoomEffects(dt)
	Combatants.ForEachAlive(function(c)
		local pos = c.root.Position
		if MapBuilder.IsInSpawn(c.team, pos) then
			Combat.Heal(nil, c, Config.SpawnHealPerSecond * dt)
		elseif MapBuilder.IsInSpawn(otherTeam(c.team), pos) then
			Combat.Damage(nil, c, Config.SpawnEnemyDamagePerSecond * dt, "Spawn Defense")
		end
		Combatants.AddUlt(c, Config.UltPassivePerSecond * dt)
	end)
end

------------------------------------------------------------------ flow
local function waitUntil(endTime, earlyExit)
	while Util.now() < endTime do
		if earlyExit and earlyExit() then
			return
		end
		task.wait(0.2)
	end
end

local function allHumansPicked()
	local any = false
	for _, c in pairs(Combatants.All) do
		if not c.isBot then
			any = true
			if not c.heroId then
				return false
			end
		end
	end
	return any
end

local function resetMatch()
	Combat.ClearConstructs()
	MapBuilder.SetBarriers(true)
	removeAllBots()
	for _, c in pairs(Combatants.All) do
		Spawner.Despawn(c)
		Combatants.SetHero(c, nil)
		c.ult = 0
		for _, stat in ipairs({ "Kills", "Deaths", "Damage", "Healing", "Ult" }) do
			c.entry:SetAttribute(stat, 0)
		end
	end
	-- rebalance humans
	local humans = {}
	for _, c in pairs(Combatants.All) do
		table.insert(humans, c)
	end
	for i = #humans, 2, -1 do
		local j = math.random(1, i)
		humans[i], humans[j] = humans[j], humans[i]
	end
	for i, c in ipairs(humans) do
		Combatants.SetTeam(c, i % 2 == 1 and "Blue" or "Red")
	end
	resetPoint()
	publishPoint({ Blue = 0, Red = 0 }, false)
	state:SetAttribute("BlueRounds", 0)
	state:SetAttribute("RedRounds", 0)
	state:SetAttribute("Round", 0)
	state:SetAttribute("Winner", "")
end

local function playRound(round)
	state:SetAttribute("Round", round)
	Combat.ClearConstructs()
	resetPoint()
	publishPoint({ Blue = 0, Red = 0 }, false)
	MapBuilder.SetBarriers(true)

	for _, c in pairs(Combatants.All) do
		if not c.heroId then
			Combatants.SetHero(c, pickFreeHero(c.team, c))
		end
		task.spawn(Spawner.Spawn, c)
	end

	setState("Preparing", Config.PrepTime)
	Combat.NotifyAll("announce", { text = "ROUND " .. round, sub = "Prepare to fight! Swap heroes with H", color = Color3.new(1, 1, 1) })
	waitUntil(state:GetAttribute("StateEnds"))

	MapBuilder.SetBarriers(false)
	setState("InProgress", 0)
	Combat.NotifyAll("announce", { text = "FIGHT!", sub = "Capture and hold the point", color = Color3.fromRGB(255, 220, 90) })

	local winner
	local last = os.clock()
	while not winner do
		task.wait(0.1)
		local now = os.clock()
		local dt = now - last
		last = now
		spawnRoomEffects(dt)
		winner = updatePoint(dt)
	end

	local key = winner .. "Rounds"
	state:SetAttribute(key, state:GetAttribute(key) + 1)
	setState("RoundEnd", Config.RoundEndTime)
	Combat.NotifyAll("announce", { text = string.upper(winner) .. " WINS ROUND " .. round, color = Config.Teams[winner].Color })
	waitUntil(state:GetAttribute("StateEnds"))
	return winner
end

local function runMatch()
	resetMatch()
	if #Players:GetPlayers() == 0 then
		setState("Waiting", 0)
		repeat
			task.wait(1)
		until #Players:GetPlayers() > 0
	end

	setState("HeroSelect", Config.HeroSelectTime)
	local selectStart = Util.now()
	waitUntil(state:GetAttribute("StateEnds"), function()
		return Util.now() - selectStart > 4 and allHumansPicked()
	end)
	for _, c in pairs(Combatants.All) do
		if not c.heroId then
			Combatants.SetHero(c, pickFreeHero(c.team, c))
			Combat.Notify(c, "pickResult", { ok = true, hero = c.heroId, auto = true })
		end
	end
	fillBots()

	local round = 0
	while state:GetAttribute("BlueRounds") < Config.RoundsToWin and state:GetAttribute("RedRounds") < Config.RoundsToWin do
		round += 1
		playRound(round)
	end

	local winner = state:GetAttribute("BlueRounds") >= Config.RoundsToWin and "Blue" or "Red"
	state:SetAttribute("Winner", winner)
	setState("MatchEnd", Config.MatchEndTime)
	Combat.NotifyAll("matchEnd", { winner = winner })
	waitUntil(state:GetAttribute("StateEnds"))
end

function Match.Start(remotes)
	state = Instance.new("Configuration")
	state.Name = "MatchState"
	state:SetAttribute("State", "Waiting")
	state:SetAttribute("StateEnds", 0)
	state.Parent = ReplicatedStorage

	Spawner.OnDeath = function(c)
		if respawnAllowed() then
			Spawner.ScheduleRespawn(c, Config.RespawnTime, respawnAllowed)
		end
	end

	remotes.PickHero.OnServerEvent:Connect(onPickHero)
	remotes.UseAbility.OnServerEvent:Connect(function(player, slot, aimPos)
		if typeof(slot) ~= "string" or not table.find(Config.Slots, slot) then
			return
		end
		local s = getState()
		if s == "HeroSelect" or s == "Waiting" or s == "MatchEnd" then
			return
		end
		local c = Combatants.All[tostring(player.UserId)]
		if c then
			Abilities.Use(c, slot, typeof(aimPos) == "Vector3" and aimPos or nil)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayerAdded(p)
	end

	task.spawn(function()
		while true do
			local ok, err = pcall(runMatch)
			if not ok then
				warn("Match loop error:", err)
				task.wait(2)
			end
		end
	end)
end

return Match
