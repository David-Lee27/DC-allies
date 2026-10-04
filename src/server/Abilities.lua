-- Generic ability handlers. Each hero ability in Heroes.lua points at one of these by `kind`.
-- A handler returns `false` when nothing happened (e.g. grapple hit nothing) so no cooldown is spent.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Heroes = require(ReplicatedStorage.Shared.Heroes)
local Util = require(ReplicatedStorage.Shared.Util)
local Combatants = require(script.Parent.Combatants)
local Combat = require(script.Parent.Combat)

local Abilities = {}
local Kinds = {}

------------------------------------------------------------------ helpers
local function headPos(c)
	local head = c.model and c.model:FindFirstChild("Head")
	return head and head.Position or c.root.Position + Vector3.new(0, 1.5, 0)
end

local function aimDirection(c, origin, aimPos)
	local d = aimPos - origin
	if d.Magnitude < 1 then
		d = c.root.CFrame.LookVector
	end
	return d.Unit
end

local function flatDirection(c, aimPos)
	local d = Util.flat(aimPos - c.root.Position)
	if d.Magnitude < 0.5 then
		d = Util.flat(c.root.CFrame.LookVector)
	end
	return d.Unit
end

local function worldParams()
	local exclude = { Combat.EffectsFolder() }
	for _, c in pairs(Combatants.All) do
		if c.model then
			table.insert(exclude, c.model)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return params
end

local function groundAt(pos)
	local result = workspace:Raycast(pos + Vector3.new(0, 15, 0), Vector3.new(0, -80, 0), worldParams())
	return result and result.Position or Vector3.new(pos.X, 0, pos.Z)
end

local function clampToRange(c, aimPos, range)
	local from = c.root.Position
	local d = aimPos - from
	if d.Magnitude > range then
		aimPos = from + d.Unit * range
	end
	return groundAt(aimPos)
end

local function zonePart(pos, radius, color, height)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.65
	p.Size = Vector3.new(height or 0.4, radius * 2, radius * 2)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = Combat.EffectsFolder()
	return p
end

------------------------------------------------------------------ kinds
function Kinds.hitscan(c, a, aimPos)
	local origin = headPos(c)
	local baseDir = aimDirection(c, origin, aimPos)
	local params = Combat.RayParams(c, a.healAllies ~= nil)
	for _ = 1, a.pellets or 1 do
		local dir = baseDir
		if a.spread then
			local s = math.rad(a.spread)
			dir = (CFrame.lookAt(Vector3.zero, baseDir) * CFrame.Angles((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)).LookVector
		end
		local result = workspace:Raycast(origin, dir * a.range, params)
		local endPos = result and result.Position or origin + dir * a.range
		if result then
			Combat.ApplyHit(c, result.Instance, a)
		end
		Combat.FX("beam", { from = origin, to = endPos, color = a.color, width = 0.25, life = 0.08, owner = c.model })
	end
end

function Kinds.projectile(c, a, aimPos)
	local origin = headPos(c)
	local dir = aimDirection(c, origin, aimPos)
	Combat.FireProjectile(c, origin + dir * 1.5, dir, a)
end

function Kinds.melee(c, a, aimPos)
	local pos = c.root.Position
	local forward = flatDirection(c, aimPos)
	local cosHalf = math.cos(math.rad(a.angle / 2))
	Combat.InRadius(pos, a.range + 2, function(t)
		if t.team ~= c.team then
			local d = Util.flat(t.root.Position - pos)
			if d.Magnitude < 3 or (d.Magnitude <= a.range and forward:Dot(d.Unit) >= cosHalf) then
				Combat.Damage(c, t, a.damage, a.name)
			end
		end
	end)
	Combat.FX("slash", { cf = CFrame.lookAt(pos, pos + forward), range = a.range, color = a.color })
end

function Kinds.dash(c, a, aimPos)
	local dir = flatDirection(c, aimPos)
	Combat.Push(c, dir * a.speed + Vector3.new(0, 2, 0), a.duration)
	Combat.FX("trail", { model = c.model, color = a.color, life = a.duration + 0.2 })
	if a.damage or a.stun then
		task.spawn(function()
			local hit = {}
			local t0 = os.clock()
			while os.clock() - t0 < a.duration + 0.05 and c.alive do
				Combat.InRadius(c.root.Position, a.radius or 6, function(t)
					if t.team ~= c.team and not hit[t] then
						hit[t] = true
						Combat.Damage(c, t, a.damage or 0, a.name)
						if a.stun then
							Combat.AddStatus(t, "stun", 1, a.stun)
						end
						if a.knockback then
							Combat.Knockback(c.root.Position - dir * 2, t, a.knockback)
						end
					end
				end)
				task.wait(0.03)
			end
		end)
	end
end

function Kinds.cone(c, a, aimPos)
	local pos = c.root.Position
	local forward = flatDirection(c, aimPos)
	local cosHalf = math.cos(math.rad(a.angle / 2))
	Combat.InRadius(pos, a.range, function(t)
		if t.team ~= c.team then
			local d = Util.flat(t.root.Position - pos)
			if d.Magnitude < 2 or forward:Dot(d.Unit) >= cosHalf then
				Combat.Damage(c, t, a.damage or 0, a.name)
				if a.slow then
					Combat.AddStatus(t, "slow", a.slow, a.slowDuration or 2)
				end
				if a.knockback then
					Combat.Knockback(pos, t, a.knockback)
				end
			end
		end
	end)
	Combat.FX("cone", { cf = CFrame.lookAt(pos, pos + forward), range = a.range, angle = a.angle, color = a.color })
end

function Kinds.aoe(c, a)
	local pos = c.root.Position
	Combat.InRadius(pos, a.radius, function(t)
		if t.team ~= c.team then
			if a.damage then
				Combat.Damage(c, t, a.damage, a.name)
			end
			if a.stun then
				Combat.AddStatus(t, "stun", 1, a.stun)
			end
			if a.knockback then
				Combat.Knockback(pos, t, a.knockback)
			end
		elseif a.heal then
			Combat.Heal(c, t, a.heal)
			Combat.FX("aura", { model = t.model, color = a.color, life = 0.6 })
		end
	end)
	Combat.FX("burst", { pos = pos, radius = a.radius, color = a.color })
end

function Kinds.zone(c, a, aimPos)
	local center
	if a.placement == "self" then
		center = groundAt(c.root.Position)
	else
		center = clampToRange(c, aimPos, a.range or 40)
	end
	local visual = zonePart(center + Vector3.new(0, 0.2, 0), a.radius, a.color)
	local dome = zonePart(center, a.radius, a.color, a.radius * 0.6)
	dome.Transparency = 0.85
	Debris:AddItem(visual, a.duration)
	Debris:AddItem(dome, a.duration)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < a.duration and not c.removed do
			Combat.InRadius(center, a.radius, function(t)
				if math.abs(t.root.Position.Y - center.Y) > 12 then
					return
				end
				if t.team ~= c.team then
					if a.damagePerTick then
						Combat.Damage(c, t, a.damagePerTick, a.name)
					end
					if a.slow then
						Combat.AddStatus(t, "slow", a.slow, a.tick + 0.1)
					end
					if a.pull then
						local d = Util.flat(center - t.root.Position)
						if d.Magnitude > 2 then
							Combat.Push(t, d.Unit * a.pull, math.min(a.tick, 0.2))
						end
					end
				elseif a.healPerTick then
					Combat.Heal(c, t, a.healPerTick)
				end
			end)
			task.wait(a.tick)
		end
	end)
end

function Kinds.buff(c, a)
	local targets = {}
	if a.target == "team" then
		Combat.InRadius(c.root.Position, a.radius or 30, function(t)
			if t.team == c.team then
				table.insert(targets, t)
			end
		end)
	else
		targets = { c }
	end
	for _, t in ipairs(targets) do
		if a.speedMult then
			Combat.AddStatus(t, "speed", a.speedMult, a.duration)
		end
		if a.damageMult then
			Combat.AddStatus(t, "damageMult", a.damageMult, a.duration)
		end
		if a.damageReduction then
			Combat.AddStatus(t, "damageReduction", a.damageReduction, a.duration)
		end
		if a.heal then
			Combat.Heal(c, t, a.heal)
		end
		Combat.FX("aura", { model = t.model, color = a.color, life = a.duration })
	end
	if a.target == "team" then
		Combat.FX("burst", { pos = c.root.Position, radius = a.radius or 30, color = a.color })
	end
end

function Kinds.leapSlam(c, a, aimPos)
	local dir = flatDirection(c, aimPos)
	Combat.Push(c, dir * a.forward + Vector3.new(0, a.up, 0), 0.25)
	Combat.FX("trail", { model = c.model, color = a.color, life = 1.2 })
	task.spawn(function()
		local t0 = os.clock()
		task.wait(0.4)
		local params = worldParams()
		while c.alive and os.clock() - t0 < 2.5 do
			if workspace:Raycast(c.root.Position, Vector3.new(0, -4.5, 0), params) then
				break -- landed
			end
			task.wait()
		end
		if not c.alive then
			return
		end
		local pos = c.root.Position
		Combat.InRadius(pos, a.radius, function(t)
			if t.team ~= c.team then
				Combat.Damage(c, t, a.damage, a.name)
				if a.knockback then
					Combat.Knockback(pos, t, a.knockback)
				end
			end
		end)
		Combat.FX("burst", { pos = pos - Vector3.new(0, 2.5, 0), radius = a.radius, color = a.color, shake = true })
	end)
end

function Kinds.grapple(c, a, aimPos)
	local origin = headPos(c)
	local dir = aimDirection(c, origin, aimPos)
	local result = workspace:Raycast(origin, dir * a.range, worldParams())
	if not result then
		return false
	end
	local target = result.Position - dir * 2 + Vector3.new(0, 2, 0)
	local dist = (target - c.root.Position).Magnitude
	local duration = math.clamp(dist / a.speed, 0.1, 0.8)
	Combat.Push(c, (target - c.root.Position).Unit * a.speed, duration)
	Combat.FX("beam", { from = origin, to = result.Position, color = a.color, width = 0.12, life = duration, owner = c.model, follow = true })
	return true
end

function Kinds.pull(c, a, aimPos)
	local origin = headPos(c)
	local dir = aimDirection(c, origin, aimPos)
	local result = workspace:Spherecast(origin, 1.5, dir * a.range, Combat.RayParams(c, false))
	local endPos = result and result.Position or origin + dir * a.range
	Combat.FX("beam", { from = origin, to = endPos, color = a.color, width = 0.2, life = 0.35, owner = c.model })
	if not result then
		return
	end
	local t = Combatants.FromPart(result.Instance)
	if t and t.team ~= c.team then
		Combat.Damage(c, t, a.damage or 0, a.name)
		if a.stun then
			Combat.AddStatus(t, "stun", 1, a.stun)
		end
		local dest = c.root.Position + Util.flat(t.root.Position - c.root.Position).Unit * 4
		Combat.Push(t, (dest - t.root.Position) / 0.25 + Vector3.new(0, 8, 0), 0.25)
	end
end

function Kinds.teleport(c, a, aimPos)
	local dir = flatDirection(c, aimPos)
	local from = c.root.Position
	local result = workspace:Raycast(from, dir * a.range, worldParams())
	local dest = result and (result.Position - dir * 2.5) or (from + dir * a.range)
	Combat.FX("burst", { pos = from, radius = 4, color = a.color })
	c.model:PivotTo(CFrame.lookAt(dest, dest + dir))
	Combat.FX("burst", { pos = dest, radius = 4, color = a.color })
end

function Kinds.wall(c, a, aimPos)
	local dir = flatDirection(c, aimPos)
	local base = groundAt(c.root.Position + dir * 9)
	local wallPart = Instance.new("Part")
	wallPart.Name = "Barrier"
	wallPart.Anchored = true
	wallPart.Size = Vector3.new(a.width, a.height, 1.5)
	wallPart.CFrame = CFrame.lookAt(base + Vector3.new(0, a.height / 2, 0), base + Vector3.new(0, a.height / 2, 0) + dir)
	wallPart.Color = a.color
	wallPart.Material = Enum.Material.ForceField
	wallPart.Transparency = 0.1
	wallPart:SetAttribute("Team", c.team)
	wallPart.Parent = Combat.ConstructsFolder()
	Debris:AddItem(wallPart, a.duration)
	Combat.FX("burst", { pos = base, radius = a.width / 2, color = a.color })
end

function Kinds.barrage(c, a, aimPos)
	local fixedCenter = a.placement ~= "self" and clampToRange(c, aimPos, a.range or 80) or nil
	task.spawn(function()
		for _ = 1, a.count do
			if not c.alive and a.placement == "self" then
				break
			end
			local center = fixedCenter or groundAt(c.root.Position)
			local ang = math.random() * math.pi * 2
			local r = math.sqrt(math.random()) * a.radius
			local pos = groundAt(center + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r))
			Combat.FX("strike", { pos = pos, radius = a.strikeRadius, color = a.color })
			Combat.InRadius(pos, a.strikeRadius, function(t)
				if t.team ~= c.team then
					Combat.Damage(c, t, a.damage, a.name)
				end
			end)
			task.wait(a.interval)
		end
	end)
end

------------------------------------------------------------------ entry point
function Abilities.Use(c, slot, aimPos)
	if not c.alive or not c.heroId or not c.root or not c.humanoid or c.humanoid.Health <= 0 then
		return false
	end
	if Combat.IsStunned(c) then
		return false
	end
	local hero = Heroes.Get(c.heroId)
	local a = hero and hero.abilities[slot]
	if not a then
		return false
	end
	if not Util.isFiniteVector(aimPos) then
		aimPos = c.root.Position + c.root.CFrame.LookVector * 50
	end
	if slot == "Ultimate" then
		if c.ult < 100 then
			return false
		end
	elseif not Combatants.IsReady(c, slot) then
		return false
	end

	local handler = Kinds[a.kind]
	if not handler then
		warn("Unknown ability kind", a.kind)
		return false
	end
	local ok, result = pcall(handler, c, a, aimPos)
	if not ok then
		warn("Ability error", hero.name, slot, result)
		return false
	end
	if result == false then
		return false
	end

	if slot == "Ultimate" then
		Combatants.AddUlt(c, -100)
		Combat.NotifyAll("ultimate", { name = c.name, team = c.team, hero = hero.name, ability = a.name })
	else
		Combatants.SetCooldown(c, slot, a.cooldown or 1)
	end
	return true
end

return Abilities
