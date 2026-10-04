-- Simple bot AI so matches are playable solo: push the objective, fight what they see, use kits sensibly.
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Heroes = require(ReplicatedStorage.Shared.Heroes)
local Util = require(ReplicatedStorage.Shared.Util)
local Combatants = require(script.Parent.Combatants)
local Combat = require(script.Parent.Combat)
local Abilities = require(script.Parent.Abilities)
local MapBuilder = require(script.Parent.MapBuilder)

local Bots = {}

Bots.Names = {
	"Ace", "Blitz", "Cobalt", "Dyna", "Echo", "Flux", "Grit", "Halo", "Ion", "Jinx", "Kilo", "Lumen",
	"Mako", "Nova", "Onyx", "Pike", "Quill", "Rook", "Sable", "Talon", "Umbra", "Vex", "Wren", "Zed",
}

local ANIMS = {
	idle = "rbxassetid://507766666",
	walk = "rbxassetid://507777826",
	run = "rbxassetid://507767714",
	jump = "rbxassetid://507765000",
	fall = "rbxassetid://507767968",
}

local THINK_INTERVAL = 0.15
local VIEW_RANGE = 150

local matchState = nil
local function state()
	matchState = matchState or ReplicatedStorage:FindFirstChild("MatchState")
	return matchState and matchState:GetAttribute("State") or ""
end

------------------------------------------------------------------ animation
local function setupAnimations(c)
	local humanoid = c.humanoid
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local tracks = {}
	for name, id in pairs(ANIMS) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok then
			track.Looped = name ~= "jump"
			tracks[name] = track
		end
	end
	local current
	local function play(name, speed)
		local track = tracks[name]
		if not track then
			return
		end
		if current ~= track then
			if current then
				current:Stop(0.15)
			end
			current = track
			track:Play(0.15)
		end
		track:AdjustSpeed(speed or 1)
	end
	play("idle")
	humanoid.Running:Connect(function(speed)
		if humanoid.FloorMaterial == Enum.Material.Air then
			return
		end
		if speed > 0.5 then
			play("run", math.clamp(speed / 16, 0.6, 1.8))
		else
			play("idle")
		end
	end)
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then
			play("jump")
		elseif new == Enum.HumanoidStateType.Freefall then
			play("fall")
		end
	end)
end

------------------------------------------------------------------ perception helpers
local function head(c)
	local h = c.model and c.model:FindFirstChild("Head")
	return h and h.Position or c.root.Position
end

local function canSee(c, t)
	return Combat.HasLineOfSight(head(c), head(t), { c.model, t.model, workspace:FindFirstChild("Bots") })
end

local function findTarget(c)
	local best, bestScore
	Combatants.ForEachAlive(function(t)
		if t.team ~= c.team then
			local d = (t.root.Position - c.root.Position).Magnitude
			if d <= VIEW_RANGE and canSee(c, t) then
				local score = d + (t.humanoid.Health / t.humanoid.MaxHealth) * 20
				if not bestScore or score < bestScore then
					best, bestScore = t, score
				end
			end
		end
	end)
	return best
end

local function lowestAlly(c, radius, threshold)
	local best, bestRatio
	Combat.InRadius(c.root.Position, radius, function(t)
		if t.team == c.team then
			local ratio = t.humanoid.Health / t.humanoid.MaxHealth
			if ratio < threshold and (not bestRatio or ratio < bestRatio) then
				best, bestRatio = t, ratio
			end
		end
	end)
	return best
end

local function countEnemiesNear(c, pos, radius)
	local n = 0
	Combat.InRadius(pos, radius, function(t)
		if t.team ~= c.team then
			n += 1
		end
	end)
	return n
end

------------------------------------------------------------------ ability decisions
-- returns aimPos if the bot should use the ability now, else nil
local function decide(c, a, target, dist, isUlt)
	local hpRatio = c.humanoid.Health / c.humanoid.MaxHealth
	local tpos = target and target.root.Position
	local kind = a.kind
	if kind == "hitscan" or kind == "projectile" then
		if target and dist <= a.range then
			return tpos
		end
	elseif kind == "melee" then
		if target and dist <= a.range + 1 then
			return tpos
		end
	elseif kind == "dash" then
		if a.damage or a.stun then
			if target and dist > 4 and dist <= a.speed * a.duration + 2 then
				return tpos
			end
		elseif target and hpRatio < 0.35 then
			return c.root.Position + (c.root.Position - tpos) -- escape
		elseif not target and math.random() < 0.04 then
			return MapBuilder.Info.PointCenter
		end
	elseif kind == "cone" then
		if target and dist <= a.range * 0.9 then
			return tpos
		end
	elseif kind == "aoe" then
		if a.heal then
			local need = isUlt and 0.45 or 0.7
			local ally = lowestAlly(c, a.radius, need)
			if ally then
				return ally.root.Position
			end
		elseif target and countEnemiesNear(c, c.root.Position, a.radius * 0.8) >= 1 then
			return tpos
		end
	elseif kind == "zone" then
		if a.healPerTick then
			local ally = lowestAlly(c, a.placement == "self" and a.radius or (a.range or 40), isUlt and 0.5 or 0.7)
			if ally then
				return ally.root.Position
			end
		elseif target and dist <= (a.range or 40) then
			return tpos
		end
	elseif kind == "buff" then
		if a.target == "team" then
			local ally = lowestAlly(c, a.radius or 30, 0.6)
			if target and (ally or dist < 30) then
				return tpos
			end
		elseif target and (dist < 45 or hpRatio < 0.4) then
			return tpos
		end
	elseif kind == "leapSlam" then
		if target and dist > 6 and dist <= (a.forward * 0.7) then
			if countEnemiesNear(c, tpos, a.radius) >= 1 then
				return tpos
			end
		end
	elseif kind == "grapple" then
		if target and dist > 20 and dist < a.range then
			return tpos - Vector3.new(0, 2.5, 0)
		end
	elseif kind == "pull" then
		if target and dist > 8 and dist <= a.range * 0.9 then
			return tpos
		end
	elseif kind == "teleport" then
		if target and hpRatio < 0.4 then
			return c.root.Position + (c.root.Position - tpos)
		elseif target and dist > 12 and dist < a.range + 5 and Heroes.Get(c.heroId).role == "Duelist" then
			return tpos
		end
	elseif kind == "wall" then
		if target and hpRatio < 0.6 and dist < 50 then
			return tpos
		end
	elseif kind == "barrage" then
		if a.placement == "self" then
			if countEnemiesNear(c, c.root.Position, a.radius) >= 1 then
				return c.root.Position
			end
		elseif target and dist <= (a.range or 80) then
			return tpos
		end
	end
	return nil
end

------------------------------------------------------------------ brain
local function preferredDistance(hero)
	local p = hero.abilities.Primary
	if p.kind == "melee" then
		return 3
	end
	if hero.role == "Strategist" then
		return math.min(p.range * 0.5, 30)
	end
	return math.min(p.range * 0.4, 28)
end

function Bots.Attach(c)
	local token = c.spawnToken
	local model = c.model
	local humanoid = c.humanoid
	local root = c.root
	local hero = Heroes.Get(c.heroId)
	setupAnimations(c)

	local brain = {
		target = nil,
		targetSince = 0,
		nextTargetScan = 0,
		destination = nil,
		nextDestPick = 0,
		waypoints = nil,
		waypointIndex = 0,
		nextPath = 0,
		strafeSign = 1,
		nextStrafeFlip = 0,
		lastPos = root.Position,
		stuckTime = 0,
	}
	local path = PathfindingService:CreatePath({ AgentRadius = 2.5, AgentHeight = 6, AgentCanJump = true, WaypointSpacing = 8 })

	local function alive()
		return c.spawnToken == token and c.alive and c.model == model and humanoid.Health > 0 and not c.removed
	end

	local function walkTo(dest, usePath)
		if not usePath then
			brain.waypoints = nil
			humanoid:MoveTo(dest)
			return
		end
		local now = os.clock()
		if not brain.waypoints or now >= brain.nextPath or (brain.destination and (brain.destination - dest).Magnitude > 12) then
			brain.destination = dest
			brain.nextPath = now + 1.5
			local ok = pcall(function()
				path:ComputeAsync(root.Position, dest)
			end)
			if ok and path.Status == Enum.PathStatus.Success then
				brain.waypoints = path:GetWaypoints()
				brain.waypointIndex = math.min(2, #brain.waypoints)
			else
				brain.waypoints = nil
			end
		end
		if brain.waypoints and brain.waypoints[brain.waypointIndex] then
			local wp = brain.waypoints[brain.waypointIndex]
			humanoid:MoveTo(wp.Position)
			if wp.Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end
			if Util.flat(wp.Position - root.Position).Magnitude < 4 then
				brain.waypointIndex += 1
			end
		else
			humanoid:MoveTo(dest)
		end
	end

	task.spawn(function()
		task.wait(math.random() * 0.5)
		while alive() do
			local now = os.clock()
			local s = state()

			if s == "InProgress" or s == "Preparing" or s == "RoundEnd" then
				-- target acquisition
				if now >= brain.nextTargetScan then
					brain.nextTargetScan = now + 0.4
					local t = findTarget(c)
					if t ~= brain.target then
						brain.target = t
						brain.targetSince = now
					end
				end
				local target = brain.target
				if target and (not target.alive or not target.root or not target.root.Parent) then
					target = nil
					brain.target = nil
				end
				local dist = target and (target.root.Position - root.Position).Magnitude or math.huge

				-- movement
				if s == "Preparing" then
					humanoid:MoveTo(root.Position)
				elseif target and dist < 70 then
					if now >= brain.nextStrafeFlip then
						brain.nextStrafeFlip = now + math.random(10, 25) / 10
						brain.strafeSign = -brain.strafeSign
					end
					local away = Util.flat(root.Position - target.root.Position)
					away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
					local side = Vector3.new(-away.Z, 0, away.X) * brain.strafeSign
					local want = target.root.Position + away * preferredDistance(hero) + side * 6
					walkTo(want, false)
				else
					if now >= brain.nextDestPick or not brain.objective then
						brain.nextDestPick = now + 4
						local ang = math.random() * math.pi * 2
						local r = math.random() * Config.PointRadius * 0.6
						brain.objective = MapBuilder.Info.PointCenter + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
					end
					walkTo(brain.objective, true)
				end

				-- facing
				if target then
					humanoid.AutoRotate = false
					local look = Vector3.new(target.root.Position.X, root.Position.Y, target.root.Position.Z)
					if (look - root.Position).Magnitude > 0.5 then
						root.CFrame = CFrame.lookAt(root.Position, look)
					end
				else
					humanoid.AutoRotate = true
				end

				-- stuck detection
				local moved = (root.Position - brain.lastPos).Magnitude
				brain.lastPos = root.Position
				if s ~= "Preparing" and moved < 0.3 and humanoid.MoveDirection.Magnitude > 0.1 then
					brain.stuckTime += THINK_INTERVAL
					if brain.stuckTime > 0.8 then
						humanoid.Jump = true
						brain.stuckTime = 0
						brain.waypoints = nil
					end
				else
					brain.stuckTime = 0
				end

				-- combat (small reaction delay after acquiring a target)
				if s ~= "Preparing" and now - brain.targetSince > 0.35 then
					for _, slot in ipairs({ "Ultimate", "Ability1", "Ability2", "Primary" }) do
						local a = hero.abilities[slot]
						local ready = (slot == "Ultimate" and c.ult >= 100) or (slot ~= "Ultimate" and Combatants.IsReady(c, slot))
						if ready then
							local aim = decide(c, a, target, dist, slot == "Ultimate")
							if aim then
								if target and aim == target.root.Position then
									local miss = dist * 0.035
									aim += Vector3.new((math.random() - 0.5) * miss, 1 + (math.random() - 0.5) * miss, (math.random() - 0.5) * miss)
								end
								if Abilities.Use(c, slot, aim) and slot ~= "Primary" then
									break
								end
							end
						end
					end
				end
			else
				humanoid:MoveTo(root.Position)
			end
			task.wait(THINK_INTERVAL)
		end
	end)
end

return Bots
