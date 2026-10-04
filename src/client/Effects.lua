-- Client-side visuals for server FX events: beams, projectiles, bursts, slashes, auras, damage numbers.
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Effects = {}

local folder
local projectiles = {}
local shakeUntil, shakeIntensity = 0, 0

local function fxPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = folder
	return p
end

local function fade(inst, time, goal)
	goal = goal or {}
	goal.Transparency = 1
	TweenService:Create(inst, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(inst, time + 0.05)
end

local function muzzleOf(model, fallback)
	if model and model.Parent then
		local hand = model:FindFirstChild("RightHand") or model:FindFirstChild("Head")
		if hand then
			return hand.Position
		end
	end
	return fallback
end

local Handlers = {}

function Handlers.beam(d)
	local from = muzzleOf(d.owner, d.from)
	local to = d.to
	local width = d.width or 0.25
	local function place(p, a, b)
		local len = (b - a).Magnitude
		p.Size = Vector3.new(width, width, math.max(len, 0.1))
		p.CFrame = CFrame.lookAt((a + b) / 2, b)
	end
	local beam = fxPart({ Color = d.color or Color3.new(1, 1, 1), Transparency = 0.15 })
	place(beam, from, to)
	if d.follow and d.owner then
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if os.clock() - t0 > (d.life or 0.3) or not beam.Parent then
				conn:Disconnect()
				return
			end
			place(beam, muzzleOf(d.owner, from), to)
		end)
	end
	fade(beam, d.life or 0.1)
	local spark = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * width * 4, CFrame = CFrame.new(to), Color = beam.Color, Transparency = 0.3 })
	fade(spark, 0.15, { Size = Vector3.one * width * 8 })
end

function Handlers.projectile(d)
	local size = d.size or 1
	local p = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = CFrame.new(d.origin), Color = d.color })
	local tail = fxPart({ Size = Vector3.new(size * 0.5, size * 0.5, size * 3), Color = d.color, Transparency = 0.5 })
	local light = Instance.new("PointLight")
	light.Color = d.color
	light.Range = 8
	light.Brightness = 2
	light.Parent = p
	projectiles[d.id] = { part = p, tail = tail, origin = d.origin, velocity = d.velocity, range = d.range, t0 = os.clock() }
end

local function endProjectile(id)
	local proj = projectiles[id]
	if proj then
		proj.part:Destroy()
		proj.tail:Destroy()
		projectiles[id] = nil
	end
end

function Handlers.projEnd(d)
	endProjectile(d.id)
	if d.color then
		local p = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one, CFrame = CFrame.new(d.pos), Color = d.color, Transparency = 0.2 })
		fade(p, 0.2, { Size = Vector3.one * 3 })
	end
end

function Handlers.burst(d)
	local p = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one, CFrame = CFrame.new(d.pos), Color = d.color, Transparency = 0.35 })
	fade(p, 0.4, { Size = Vector3.one * d.radius * 2 })
	local ring = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 1, 1),
		CFrame = CFrame.new(d.pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = d.color,
		Transparency = 0.2,
	})
	fade(ring, 0.5, { Size = Vector3.new(0.2, d.radius * 2.2, d.radius * 2.2) })
	if d.shake then
		local cam = workspace.CurrentCamera
		if (cam.CFrame.Position - d.pos).Magnitude < 60 then
			Effects.Shake(0.35, 0.6)
		end
	end
end

function Handlers.slash(d)
	local range = d.range or 8
	local blade = fxPart({ Size = Vector3.new(0.15, 0.4, range), Color = d.color, Transparency = 0.2 })
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - t0) / 0.15
		if t >= 1 then
			conn:Disconnect()
			fade(blade, 0.1)
			return
		end
		local rot = math.rad(-60 + 120 * t)
		blade.CFrame = d.cf * CFrame.Angles(0, rot, 0) * CFrame.new(0, 0.5, -range / 2)
	end)
end

function Handlers.cone(d)
	local rays = 6
	for i = 0, rays - 1 do
		local a = math.rad(-d.angle / 2 + d.angle * (i / (rays - 1)))
		local p = fxPart({ Size = Vector3.new(1.2, 1.2, 1), Color = d.color, Transparency = 0.3 })
		local cf = d.cf * CFrame.Angles(0, a, 0)
		p.CFrame = cf * CFrame.new(0, 0, -0.5)
		fade(p, 0.35, { Size = Vector3.new(2.5, 2.5, d.range), CFrame = cf * CFrame.new(0, 0, -d.range / 2) })
	end
end

function Handlers.trail(d)
	local model = d.model
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1.2, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1.2, 0)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(d.color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = 0.35
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Parent = root
	Debris:AddItem(trail, d.life or 0.5)
	Debris:AddItem(a0, (d.life or 0.5) + 0.4)
	Debris:AddItem(a1, (d.life or 0.5) + 0.4)
end

function Handlers.aura(d)
	local model = d.model
	if not model or not model.Parent then
		return
	end
	local h = Instance.new("Highlight")
	h.FillColor = d.color
	h.OutlineColor = d.color
	h.FillTransparency = 0.6
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	Debris:AddItem(h, d.life or 1)
end

function Handlers.strike(d)
	local top = d.pos + Vector3.new(math.random(-6, 6), 70, math.random(-6, 6))
	local bolt = fxPart({ Size = Vector3.new(0.8, 0.8, (top - d.pos).Magnitude), CFrame = CFrame.lookAt((top + d.pos) / 2, d.pos), Color = d.color })
	fade(bolt, 0.25)
	Handlers.burst({ pos = d.pos, radius = d.radius, color = d.color })
end

------------------------------------------------------------------ damage numbers
function Effects.DamageNumber(pos, amount, heal, kill)
	local att = Instance.new("Attachment")
	att.WorldPosition = pos + Vector3.new(math.random(-10, 10) / 10, 3, math.random(-10, 10) / 10)
	att.Parent = workspace.Terrain
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(80, 30)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = att
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = (heal and "+" or "") .. tostring(amount)
	label.TextColor3 = heal and Color3.fromRGB(110, 255, 140) or (kill and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(255, 240, 200))
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	TweenService:Create(gui, TweenInfo.new(0.7), { StudsOffset = Vector3.new(0, 2, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(att, 0.75)
end

function Effects.Shake(duration, intensity)
	shakeUntil = os.clock() + duration
	shakeIntensity = intensity
end

function Effects.Handle(kind, data)
	local h = Handlers[kind]
	if h then
		local ok, err = pcall(h, data)
		if not ok then
			warn("FX error", kind, err)
		end
	end
end

function Effects.Init()
	folder = Instance.new("Folder")
	folder.Name = "ClientFX"
	folder.Parent = workspace

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for id, proj in pairs(projectiles) do
			local t = now - proj.t0
			local offset = proj.velocity * t
			if offset.Magnitude >= proj.range or t > 5 then
				endProjectile(id)
			else
				local pos = proj.origin + offset
				local dir = proj.velocity.Unit
				proj.part.CFrame = CFrame.new(pos)
				proj.tail.CFrame = CFrame.lookAt(pos - dir * proj.tail.Size.Z / 2, pos)
			end
		end
	end)

	RunService:BindToRenderStep("DCAlliesShake", Enum.RenderPriority.Camera.Value + 1, function()
		if os.clock() < shakeUntil then
			local cam = workspace.CurrentCamera
			local i = shakeIntensity * ((shakeUntil - os.clock()) / 0.35)
			cam.CFrame = cam.CFrame * CFrame.Angles(math.rad((math.random() - 0.5) * i), math.rad((math.random() - 0.5) * i), 0)
		end
	end)
end

return Effects
