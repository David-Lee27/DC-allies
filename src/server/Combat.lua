-- Core combat: damage/heal, status effects, knockback, hit detection and server-simulated projectiles.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Heroes = require(ReplicatedStorage.Shared.Heroes)
local Combatants = require(script.Parent.Combatants)

local Combat = {}

local remotes
local effectsFolder -- non-hittable server visuals (zones, telegraphs)
local constructsFolder -- hittable constructs (walls)
local projectiles = {}
local nextProjectileId = 0

function Combat.Init(remoteFolder)
	remotes = remoteFolder
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "Effects"
	effectsFolder.Parent = workspace
	constructsFolder = Instance.new("Folder")
	constructsFolder.Name = "Constructs"
	constructsFolder.Parent = workspace

	RunService.Heartbeat:Connect(function(dt)
		Combat.StepProjectiles(dt)
		Combat.UpdateStatuses()
	end)
end

function Combat.EffectsFolder()
	return effectsFolder
end

function Combat.ConstructsFolder()
	return constructsFolder
end

function Combat.ClearConstructs()
	effectsFolder:ClearAllChildren()
	constructsFolder:ClearAllChildren()
	table.clear(projectiles)
end

------------------------------------------------------------------ networking helpers
function Combat.FX(kind, data)
	remotes.FX:FireAllClients(kind, data)
end

function Combat.Notify(c, kind, data)
	if c and c.player then
		remotes.Notify:FireClient(c.player, kind, data)
	end
end

function Combat.NotifyAll(kind, data)
	remotes.Notify:FireAllClients(kind, data)
end

------------------------------------------------------------------ statuses
-- types: "slow" / "speed" (walk speed multiplier), "stun", "damageMult", "damageReduction"
function Combat.AddStatus(c, kind, value, duration)
	if not c.alive then
		return
	end
	table.insert(c.statuses, { kind = kind, value = value, expires = os.clock() + duration })
end

function Combat.StatusProduct(c, kind)
	local m = 1
	for _, s in ipairs(c.statuses) do
		if s.kind == kind then
			m *= s.value
		end
	end
	return m
end

function Combat.StatusMax(c, kind)
	local m = 0
	for _, s in ipairs(c.statuses) do
		if s.kind == kind and s.value > m then
			m = s.value
		end
	end
	return m
end

function Combat.IsStunned(c)
	for _, s in ipairs(c.statuses) do
		if s.kind == "stun" then
			return true
		end
	end
	return false
end

function Combat.UpdateStatuses()
	local now = os.clock()
	for _, c in pairs(Combatants.All) do
		if c.alive and c.humanoid and c.heroId then
			for i = #c.statuses, 1, -1 do
				if c.statuses[i].expires <= now then
					table.remove(c.statuses, i)
				end
			end
			local hero = Heroes.Get(c.heroId)
			local stunned = Combat.IsStunned(c)
			local speed = hero.speed * Combat.StatusProduct(c, "speed") * Combat.StatusProduct(c, "slow")
			c.humanoid.WalkSpeed = stunned and 0 or speed
			c.humanoid.JumpPower = stunned and 0 or 50
			if c.entry:GetAttribute("Stunned") ~= stunned then
				c.entry:SetAttribute("Stunned", stunned)
			end
		end
	end
end

------------------------------------------------------------------ damage / heal
function Combat.Damage(attacker, victim, amount, sourceName)
	if not victim.alive or not victim.humanoid or victim.humanoid.Health <= 0 then
		return 0
	end
	if attacker and attacker ~= victim and attacker.team == victim.team then
		return 0
	end
	if attacker then
		amount *= Combat.StatusProduct(attacker, "damageMult")
	end
	amount *= (1 - math.clamp(Combat.StatusMax(victim, "damageReduction"), 0, 0.9))
	local dealt = math.min(victim.humanoid.Health, amount)
	if dealt <= 0 then
		return 0
	end
	if attacker and attacker ~= victim then
		victim.lastDamager = attacker
		victim.lastDamagerTime = os.clock()
		victim.lastDamageSource = sourceName
		Combatants.AddUlt(attacker, dealt * Config.UltPerDamage)
		Combatants.AddStat(attacker, "Damage", math.floor(dealt))
	end
	victim.humanoid.Health -= dealt
	local killed = victim.humanoid.Health <= 0
	if attacker and attacker ~= victim then
		Combat.Notify(attacker, "hit", { pos = victim.root.Position, amount = math.floor(dealt + 0.5), kill = killed })
	end
	Combat.Notify(victim, "hurt", { from = attacker and attacker.root and attacker.root.Position or nil })
	return dealt
end

function Combat.Heal(healer, target, amount)
	if not target.alive or not target.humanoid or target.humanoid.Health <= 0 then
		return 0
	end
	if healer and healer.team ~= target.team then
		return 0
	end
	local h = target.humanoid
	local healed = math.min(h.MaxHealth - h.Health, amount)
	if healed <= 0 then
		return 0
	end
	h.Health += healed
	if healer then
		Combatants.AddUlt(healer, healed * Config.UltPerHeal)
		Combatants.AddStat(healer, "Healing", math.floor(healed))
		Combat.Notify(healer, "hit", { pos = target.root.Position, amount = math.floor(healed + 0.5), heal = true })
	end
	return healed
end

------------------------------------------------------------------ movement forces
function Combat.Push(c, velocity, duration)
	local root = c.root
	if not root or not root.Parent then
		return
	end
	local att = root:FindFirstChild("RootAttachment")
	if not att then
		att = Instance.new("Attachment")
		att.Name = "RootAttachment"
		att.Parent = root
	end
	local old = root:FindFirstChild("AbilityVelocity")
	if old then
		old:Destroy()
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "AbilityVelocity"
	lv.Attachment0 = att
	lv.MaxForce = math.huge
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.VectorVelocity = velocity
	lv.Parent = root
	Debris:AddItem(lv, duration)
	return lv
end

function Combat.Knockback(source, target, force)
	if not target.root then
		return
	end
	local dir = target.root.Position - source
	dir = Vector3.new(dir.X, 0, dir.Z)
	dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.new(0, 0, 1)
	Combat.Push(target, dir * force + Vector3.new(0, force * 0.35, 0), 0.18)
end

------------------------------------------------------------------ queries
function Combat.InRadius(pos, radius, fn)
	Combatants.ForEachAlive(function(c)
		if (c.root.Position - pos).Magnitude <= radius then
			fn(c)
		end
	end)
end

function Combat.RayParams(owner, includeAllies)
	local exclude = { effectsFolder }
	if owner.model then
		table.insert(exclude, owner.model)
	end
	if not includeAllies then
		for _, c in pairs(Combatants.All) do
			if c.team == owner.team and c.model then
				table.insert(exclude, c.model)
			end
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	return params
end

function Combat.HasLineOfSight(fromPos, toPos, ignoreList)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = { effectsFolder }
	for _, inst in ipairs(ignoreList or {}) do
		table.insert(list, inst)
	end
	params.FilterDescendantsInstances = list
	local result = workspace:Raycast(fromPos, toPos - fromPos, params)
	return result == nil
end

-- Applies a direct hit from `owner` on whatever combatant `part` belongs to.
-- Returns the hit combatant (or nil).
function Combat.ApplyHit(owner, part, ability, damageOverride)
	local target = Combatants.FromPart(part)
	if not target or target == owner then
		return nil
	end
	if target.team ~= owner.team then
		Combat.Damage(owner, target, damageOverride or ability.damage or 0, ability.name)
	elseif ability.healAllies then
		Combat.Heal(owner, target, ability.healAllies)
	end
	return target
end

------------------------------------------------------------------ projectiles
function Combat.FireProjectile(owner, origin, direction, ability)
	nextProjectileId += 1
	local id = nextProjectileId
	local p = {
		id = id,
		owner = owner,
		ability = ability,
		pos = origin,
		vel = direction.Unit * ability.speed,
		traveled = 0,
		range = ability.range or 100,
		radius = math.max(0.5, (ability.size or 1) / 2),
		params = Combat.RayParams(owner, ability.healAllies ~= nil),
	}
	projectiles[id] = p
	Combat.FX("projectile", { id = id, origin = origin, velocity = p.vel, color = ability.color, size = ability.size or 1, range = p.range })
	return p
end

local function explode(p, pos, directTarget)
	local a = p.ability
	if a.splashRadius then
		Combat.InRadius(pos, a.splashRadius, function(c)
			if c ~= directTarget and c.team ~= p.owner.team then
				Combat.Damage(p.owner, c, a.splashDamage or 0, a.name)
			end
		end)
		Combat.FX("burst", { pos = pos, radius = a.splashRadius, color = a.color })
	end
end

function Combat.StepProjectiles(dt)
	for id, p in pairs(projectiles) do
		if p.owner.removed then
			projectiles[id] = nil
			continue
		end
		local step = p.vel * dt
		local result = workspace:Spherecast(p.pos, p.radius, step, p.params)
		if result then
			local target = Combat.ApplyHit(p.owner, result.Instance, p.ability)
			explode(p, result.Position, target)
			Combat.FX("projEnd", { id = id, pos = result.Position, color = p.ability.color })
			projectiles[id] = nil
		else
			p.pos += step
			p.traveled += step.Magnitude
			if p.traveled >= p.range then
				Combat.FX("projEnd", { id = id, pos = p.pos })
				projectiles[id] = nil
			end
		end
	end
end

return Combat
