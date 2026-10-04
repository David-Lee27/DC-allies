-- Builds each hero's look out of body colors + simple welded parts (no external assets needed).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Heroes = require(ReplicatedStorage.Shared.Heroes)

local HeroOutfits = {}

function HeroOutfits.Description(heroId)
	local hero = Heroes.Get(heroId)
	local o = hero.outfit
	local d = Instance.new("HumanoidDescription")
	d.HeadColor = o.skin
	d.TorsoColor = o.torso
	d.LeftArmColor = o.arms
	d.RightArmColor = o.arms
	d.LeftLegColor = o.legs
	d.RightLegColor = o.legs
	local scale = hero.role == "Vanguard" and 1.1 or (hero.role == "Strategist" and 0.97 or 1)
	d.HeightScale = scale
	d.WidthScale = scale
	d.DepthScale = scale
	return d
end

local function weld(model, attachName, size, offset, color, props)
	local attach = model:FindFirstChild(attachName)
	if not attach then
		return nil
	end
	local p = Instance.new("Part")
	p.Name = "Outfit"
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.CFrame = attach.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0 = attach
	w.Part1 = p
	w.C0 = offset
	w.Parent = p
	p.Parent = model
	return p
end

local neon = { Material = Enum.Material.Neon }
local metal = { Material = Enum.Material.Metal }

local helmets = {
	cowl = function(m, c)
		weld(m, "Head", Vector3.new(1.28, 0.7, 1.28), CFrame.new(0, 0.32, 0.02), c)
		weld(m, "Head", Vector3.new(1.28, 1.25, 0.3), CFrame.new(0, 0, 0.5), c)
		weld(m, "Head", Vector3.new(0.22, 0.55, 0.22), CFrame.new(0.38, 0.85, 0), c)
		weld(m, "Head", Vector3.new(0.22, 0.55, 0.22), CFrame.new(-0.38, 0.85, 0), c)
	end,
	tiara = function(m, c)
		weld(m, "Head", Vector3.new(1.26, 0.18, 1.26), CFrame.new(0, 0.35, 0), c, metal)
		weld(m, "Head", Vector3.new(0.3, 0.3, 0.08), CFrame.new(0, 0.42, -0.64) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(255, 60, 60), neon)
	end,
	visor = function(m, c)
		weld(m, "Head", Vector3.new(1.26, 0.28, 0.2), CFrame.new(0, 0.12, -0.6), c, neon)
	end,
	hood = function(m, c)
		weld(m, "Head", Vector3.new(1.3, 0.6, 1.3), CFrame.new(0, 0.36, 0.02), c)
		weld(m, "Head", Vector3.new(1.3, 1.25, 0.3), CFrame.new(0, 0, 0.52), c)
		weld(m, "Head", Vector3.new(0.08, 0.3, 0.5), CFrame.new(0.67, 0.2, 0) * CFrame.Angles(math.rad(-30), 0, 0), Color3.fromRGB(255, 210, 40), neon)
		weld(m, "Head", Vector3.new(0.08, 0.3, 0.5), CFrame.new(-0.67, 0.2, 0) * CFrame.Angles(math.rad(-30), 0, 0), Color3.fromRGB(255, 210, 40), neon)
	end,
	crown = function(m, c)
		weld(m, "Head", Vector3.new(1.1, 0.3, 1.1), CFrame.new(0, 0.72, 0), c, metal)
		for i = -1, 1 do
			weld(m, "Head", Vector3.new(0.18, 0.4, 0.18), CFrame.new(i * 0.4, 0.98, -0.45), c, metal)
		end
	end,
	mask = function(m, c)
		weld(m, "Head", Vector3.new(1.24, 0.26, 0.1), CFrame.new(0, 0.16, -0.6), c, neon)
	end,
	tophat = function(m, c)
		weld(m, "Head", Vector3.new(1.7, 0.1, 1.7), CFrame.new(0, 0.66, 0), c)
		weld(m, "Head", Vector3.new(1.05, 0.95, 1.05), CFrame.new(0, 1.15, 0), c)
		weld(m, "Head", Vector3.new(1.07, 0.18, 1.07), CFrame.new(0, 0.82, 0), Color3.fromRGB(150, 80, 220))
	end,
}

local weapons = {
	sword = function(m, c)
		weld(m, "RightHand", Vector3.new(0.9, 0.15, 0.2), CFrame.new(0, -0.15, -0.15), Color3.fromRGB(200, 160, 40), metal)
		weld(m, "RightHand", Vector3.new(0.2, 0.08, 3.6), CFrame.new(0, -0.15, -2.0), c, metal)
	end,
	trident = function(m, c)
		weld(m, "RightHand", Vector3.new(0.2, 6, 0.2), CFrame.new(0, 0.8, 0), c, metal)
		weld(m, "RightHand", Vector3.new(1.0, 0.15, 0.15), CFrame.new(0, 3.8, 0), c, metal)
		for i = -1, 1 do
			weld(m, "RightHand", Vector3.new(0.15, 0.9, 0.15), CFrame.new(i * 0.42, 4.3, 0), c, metal)
		end
	end,
	staff = function(m, c)
		weld(m, "RightHand", Vector3.new(0.18, 5, 0.18), CFrame.new(0, 0.6, 0), Color3.fromRGB(40, 30, 50))
		weld(m, "RightHand", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 3.3, 0), c, { Material = Enum.Material.Neon, Shape = Enum.PartType.Ball })
	end,
	cannon = function(m, c)
		weld(m, "RightLowerArm", Vector3.new(0.8, 1.3, 0.8), CFrame.new(0, -0.2, 0), c, metal)
		local muzzle = weld(m, "RightLowerArm", Vector3.new(0.55, 0.12, 0.55), CFrame.new(0, -0.9, 0), Color3.fromRGB(255, 120, 60), neon)
		if muzzle then
			local light = Instance.new("PointLight")
			light.Range = 6
			light.Color = muzzle.Color
			light.Parent = muzzle
		end
	end,
	ring = function(m, c)
		local ring = weld(m, "RightHand", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, -0.1, -0.2), c, { Material = Enum.Material.Neon, Shape = Enum.PartType.Ball })
		if ring then
			local light = Instance.new("PointLight")
			light.Range = 10
			light.Brightness = 2
			light.Color = c
			light.Parent = ring
		end
	end,
}

function HeroOutfits.Apply(model, heroId)
	local hero = Heroes.Get(heroId)
	local o = hero.outfit

	for _, inst in ipairs(model:GetChildren()) do
		if inst:IsA("Accessory") or inst:IsA("Shirt") or inst:IsA("Pants") or inst:IsA("ShirtGraphic") or inst.Name == "Outfit" then
			inst:Destroy()
		end
	end

	if o.cape then
		weld(model, "UpperTorso", Vector3.new(1.9, 3.3, 0.12), CFrame.new(0, -0.95, 0.62) * CFrame.Angles(math.rad(8), 0, 0), o.cape, { Material = Enum.Material.Fabric })
	end
	if o.emblem then
		local emblem = weld(model, "UpperTorso", Vector3.new(0.95, 0.95, 0.08), CFrame.new(0, 0.15, -0.53), o.emblem.bg)
		if emblem then
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Front
			gui.CanvasSize = Vector2.new(100, 100)
			gui.LightInfluence = 0
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = o.emblem.text
			label.TextColor3 = o.emblem.color
			label.TextScaled = true
			label.Font = Enum.Font.GothamBlack
			label.Parent = gui
			gui.Parent = emblem
		end
	end
	if o.helmet and helmets[o.helmet] then
		helmets[o.helmet](model, o.helmetColor or hero.color)
	end
	if o.weapon and weapons[o.weapon] then
		weapons[o.weapon](model, o.weaponColor or hero.color)
	end
	if o.shield then
		weld(model, "LeftLowerArm", Vector3.new(0.2, 2.3, 2.3), CFrame.new(-0.4, 0, 0), o.shield, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal })
	end
	if o.glow then
		local torso = model:FindFirstChild("UpperTorso")
		if torso then
			local light = Instance.new("PointLight")
			light.Name = "HeroGlow"
			light.Range = 9
			light.Brightness = 0.8
			light.Color = o.glow
			light.Parent = torso
		end
	end
end

return HeroOutfits
