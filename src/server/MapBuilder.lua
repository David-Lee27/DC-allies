-- Builds the "Neon Harbor" arena procedurally so the place needs no pre-made assets.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

local GROUND_X, GROUND_Z = 380, 250
local SPAWN_X = 155

local function part(props)
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Concrete
	for k, v in pairs(props) do
		if k ~= "Parent" then
			p[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

local function setupLighting()
	Lighting.ClockTime = 19.2
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(70, 70, 90)
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 100, 140)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Color = Color3.fromRGB(200, 170, 220)
	atmosphere.Decay = Color3.fromRGB(90, 60, 120)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.5
	atmosphere.Parent = Lighting

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.15
	cc.Contrast = 0.08
	cc.Parent = Lighting
end

local function neonStrip(parent, cf, size, color)
	return part({ Parent = parent, CFrame = cf, Size = size, Color = color, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
end

local function building(parent, pos, size, rng)
	local colors = { Color3.fromRGB(45, 45, 60), Color3.fromRGB(60, 55, 70), Color3.fromRGB(40, 50, 65) }
	local b = part({
		Parent = parent,
		Size = size,
		CFrame = CFrame.new(pos + Vector3.new(0, size.Y / 2, 0)),
		Color = colors[rng:NextInteger(1, #colors)],
		Material = Enum.Material.Slate,
	})
	-- neon window bands
	local neon = { Color3.fromRGB(255, 80, 200), Color3.fromRGB(80, 220, 255), Color3.fromRGB(255, 200, 80) }
	local c = neon[rng:NextInteger(1, #neon)]
	for y = 10, size.Y - 6, 14 do
		neonStrip(parent, CFrame.new(pos + Vector3.new(0, y, 0)), Vector3.new(size.X + 0.4, 1, size.Z + 0.4), c)
	end
	return b
end

local function crate(parent, pos, s)
	return part({
		Parent = parent,
		Size = Vector3.new(s, s, s),
		CFrame = CFrame.new(pos + Vector3.new(0, s / 2, 0)),
		Color = Color3.fromRGB(120, 90, 60),
		Material = Enum.Material.WoodPlanks,
	})
end

local function wall(parent, pos, size, color)
	return part({
		Parent = parent,
		Size = size,
		CFrame = CFrame.new(pos + Vector3.new(0, size.Y / 2, 0)),
		Color = color or Color3.fromRGB(90, 90, 105),
	})
end

local function platform(parent, pos, size, rampDir)
	-- raised platform with a ramp on the `rampDir` side
	wall(parent, pos, size, Color3.fromRGB(75, 75, 95))
	neonStrip(parent, CFrame.new(pos + Vector3.new(0, size.Y + 0.05, 0)), Vector3.new(size.X, 0.1, size.Z) - Vector3.new(2, 0, 2), Color3.fromRGB(80, 220, 255)).Transparency = 0.7
	local rampLen = size.Y * 2.2
	local half = (math.abs(rampDir.X) > 0 and size.X or size.Z) / 2
	local rampPos = pos + rampDir * (half + rampLen / 2) + Vector3.new(0, size.Y / 2, 0)
	part({
		ClassName = "WedgePart",
		Parent = parent,
		Size = Vector3.new(10, size.Y, rampLen),
		CFrame = CFrame.lookAt(rampPos, rampPos + rampDir),
		Color = Color3.fromRGB(85, 85, 100),
	})
end

function MapBuilder.Build()
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	setupLighting()

	local map = Instance.new("Model")
	map.Name = "Map"
	local rng = Random.new(42)

	-- ground
	part({ Parent = map, Name = "Ground", Size = Vector3.new(GROUND_X, 2, GROUND_Z), CFrame = CFrame.new(0, -1, 0), Color = Color3.fromRGB(55, 55, 65), Material = Enum.Material.Asphalt })
	-- road lines
	for x = -150, 150, 20 do
		neonStrip(map, CFrame.new(x, 0.03, 0), Vector3.new(8, 0.05, 0.6), Color3.fromRGB(255, 210, 90)).Transparency = 0.4
	end

	-- perimeter walls
	local hx, hz = GROUND_X / 2, GROUND_Z / 2
	wall(map, Vector3.new(0, 0, hz), Vector3.new(GROUND_X, 30, 2))
	wall(map, Vector3.new(0, 0, -hz), Vector3.new(GROUND_X, 30, 2))
	wall(map, Vector3.new(hx, 0, 0), Vector3.new(2, 30, GROUND_Z))
	wall(map, Vector3.new(-hx, 0, 0), Vector3.new(2, 30, GROUND_Z))

	-- skyline backdrop
	for x = -hx, hx, 30 do
		for _, z in ipairs({ hz + 20, -hz - 20 }) do
			building(map, Vector3.new(x + rng:NextNumber(-5, 5), 0, z), Vector3.new(24, rng:NextNumber(50, 130), 24), rng)
		end
	end
	for z = -hz, hz, 30 do
		for _, x in ipairs({ hx + 20, -hx - 20 }) do
			building(map, Vector3.new(x, 0, z + rng:NextNumber(-5, 5)), Vector3.new(24, rng:NextNumber(50, 130), 24), rng)
		end
	end

	-- mirrored cover layout (s = side, t = north/south)
	for _, s in ipairs({ -1, 1 }) do
		for _, t in ipairs({ -1, 1 }) do
			platform(map, Vector3.new(s * 70, 0, t * 62), Vector3.new(24, 8, 24), Vector3.new(-s, 0, 0))
			crate(map, Vector3.new(s * 40, 0, t * 30), 6)
			crate(map, Vector3.new(s * 44, 0, t * 36), 4)
			wall(map, Vector3.new(s * 24, 0, t * 20), Vector3.new(2, 5, 14))
			wall(map, Vector3.new(s * 100, 0, t * 26), Vector3.new(14, 6, 2))
			crate(map, Vector3.new(s * 110, 0, t * 70), 7)
			wall(map, Vector3.new(s * 25, 0, t * 85), Vector3.new(18, 10, 4), Color3.fromRGB(70, 70, 85))
		end
		wall(map, Vector3.new(s * 85, 0, 0), Vector3.new(3, 7, 18))
	end
	-- cover on north/south lanes of the point
	wall(map, Vector3.new(0, 0, 38), Vector3.new(16, 6, 3))
	wall(map, Vector3.new(0, 0, -38), Vector3.new(16, 6, 3))

	-- capture point
	local ring = part({
		ClassName = "Part",
		Parent = map,
		Name = "PointRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, Config.PointRadius * 2, Config.PointRadius * 2),
		CFrame = CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(230, 230, 230),
		Material = Enum.Material.Neon,
		Transparency = 0.6,
		CanCollide = false,
		CastShadow = false,
	})
	local beacon = part({
		Parent = map,
		Name = "PointBeacon",
		Size = Vector3.new(2, 60, 2),
		CFrame = CFrame.new(0, 30, 0),
		Color = Color3.fromRGB(230, 230, 230),
		Material = Enum.Material.Neon,
		Transparency = 0.75,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	for i = 0, 3 do
		local a = math.rad(45 + i * 90)
		local p = Vector3.new(math.cos(a), 0, math.sin(a)) * (Config.PointRadius + 1)
		wall(map, p, Vector3.new(1.5, 9, 1.5), Color3.fromRGB(40, 40, 50))
		local lamp = neonStrip(map, CFrame.new(p + Vector3.new(0, 9.5, 0)), Vector3.new(2, 1, 2), Color3.fromRGB(255, 255, 255))
		lamp.Name = "PointLamp"
		local light = Instance.new("PointLight")
		light.Range = 22
		light.Brightness = 2
		light.Parent = lamp
	end

	-- spawn rooms
	local info = { SpawnPoints = {}, SpawnZones = {}, Barriers = {}, PointCenter = Vector3.new(0, 0, 0), Ring = ring, Beacon = beacon, Map = map }
	for teamName, s in pairs({ Blue = -1, Red = 1 }) do
		local team = Config.Teams[teamName]
		local cx = s * SPAWN_X
		local roomDepth, roomWidth = 40, 44
		local backX = cx + s * roomDepth / 2
		local frontX = cx - s * roomDepth / 2
		wall(map, Vector3.new(backX, 0, 0), Vector3.new(2, 18, roomWidth), Color3.fromRGB(60, 60, 75))
		wall(map, Vector3.new(cx, 0, roomWidth / 2), Vector3.new(roomDepth, 18, 2), Color3.fromRGB(60, 60, 75))
		wall(map, Vector3.new(cx, 0, -roomWidth / 2), Vector3.new(roomDepth, 18, 2), Color3.fromRGB(60, 60, 75))
		part({ Parent = map, Size = Vector3.new(roomDepth, 0.2, roomWidth), CFrame = CFrame.new(cx, 0.1, 0), Color = team.Color, Material = Enum.Material.Neon, Transparency = 0.8, CanCollide = false, CastShadow = false })
		neonStrip(map, CFrame.new(cx, 18.2, roomWidth / 2), Vector3.new(roomDepth, 0.6, 2.4), team.Color)
		neonStrip(map, CFrame.new(cx, 18.2, -roomWidth / 2), Vector3.new(roomDepth, 0.6, 2.4), team.Color)

		local barrier = part({
			Parent = map,
			Name = teamName .. "Barrier",
			Size = Vector3.new(1, 18, roomWidth),
			CFrame = CFrame.new(frontX, 9, 0),
			Color = team.Color,
			Material = Enum.Material.ForceField,
			Transparency = 0.2,
			CanCollide = true,
		})
		info.Barriers[teamName] = barrier

		local spawn = Instance.new("SpawnLocation")
		spawn.Name = teamName .. "Spawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(10, 1, 10)
		spawn.CFrame = CFrame.new(cx + s * 8, 0.5, 0)
		spawn.Neutral = false
		spawn.TeamColor = team.BrickColor
		spawn.Duration = 0
		spawn.AllowTeamChangeOnTouch = false
		spawn.Color = team.Color
		spawn.Material = Enum.Material.Neon
		spawn.Transparency = 0.5
		spawn.CanCollide = false
		spawn.Parent = map

		local points = {}
		for i = -2, 2 do
			for j = 0, 1 do
				local pos = Vector3.new(cx + s * (j * 8 - 2), 3.5, i * 7)
				table.insert(points, CFrame.lookAt(pos, Vector3.new(0, 3.5, pos.Z)))
			end
		end
		info.SpawnPoints[teamName] = points
		info.SpawnZones[teamName] = { Center = Vector3.new(cx, 0, 0), HalfX = roomDepth / 2, HalfZ = roomWidth / 2 }
	end

	map.Parent = workspace
	MapBuilder.Info = info
	return info
end

function MapBuilder.IsInSpawn(teamName, pos)
	local zone = MapBuilder.Info and MapBuilder.Info.SpawnZones[teamName]
	if not zone then
		return false
	end
	local d = pos - zone.Center
	return math.abs(d.X) <= zone.HalfX and math.abs(d.Z) <= zone.HalfZ and pos.Y < 25
end

function MapBuilder.SetBarriers(closed)
	for _, barrier in pairs(MapBuilder.Info.Barriers) do
		barrier.CanCollide = closed
		barrier.Transparency = closed and 0.2 or 1
		barrier.CanQuery = closed
	end
end

return MapBuilder
