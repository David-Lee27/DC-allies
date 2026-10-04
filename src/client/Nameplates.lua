-- Name + health bars above every hero. Allies are visible through walls, enemies only in line of sight.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Heroes = require(ReplicatedStorage.Shared.Heroes)
local Util = require(ReplicatedStorage.Shared.Util)
local make = Util.make

local Nameplates = {}
local ctx
local plates = {}

local function myTeam()
	local entry = ctx.MyEntry()
	return entry and entry:GetAttribute("Team")
end

local function attach(model)
	if plates[model] or model == Players.LocalPlayer.Character then
		return
	end
	local head = model:WaitForChild("Head", 5)
	local humanoid = model:WaitForChild("Humanoid", 5)
	if not head or not humanoid or not model.Parent then
		return
	end
	local hero = Heroes.Get(model:GetAttribute("Hero") or "")
	local gui = make("BillboardGui", {
		Name = "Nameplate",
		Size = UDim2.fromOffset(120, 34),
		StudsOffset = Vector3.new(0, 2.8, 0),
		MaxDistance = 160,
		LightInfluence = 0,
		Adornee = head,
	})
	local name = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextStrokeTransparency = 0.4,
		Text = (model:GetAttribute("DisplayName") or model.Name) .. (hero and ("  ·  " .. hero.name) or ""),
		Parent = gui,
	})
	local barBg = make("Frame", {
		Position = UDim2.new(0, 0, 0, 19),
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = Color3.fromRGB(20, 20, 25),
		BorderSizePixel = 0,
		Parent = gui,
	}, { Util.corner(3) })
	local bar = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		Parent = barBg,
	}, { Util.corner(3) })
	gui.Parent = model

	local plate = { gui = gui, name = name, bar = bar, humanoid = humanoid, model = model }
	plates[model] = plate

	local function refresh()
		local h = humanoid.MaxHealth > 0 and humanoid.Health / humanoid.MaxHealth or 0
		bar.Size = UDim2.fromScale(math.clamp(h, 0, 1), 1)
		gui.Enabled = humanoid.Health > 0
	end
	humanoid.HealthChanged:Connect(refresh)
	refresh()
	Nameplates.Recolor(plate)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			plates[model] = nil
		end
	end)
end

function Nameplates.Recolor(plate)
	local team = plate.model:GetAttribute("Team")
	local ally = team == myTeam()
	local color = ally and Color3.fromRGB(110, 190, 255) or Color3.fromRGB(255, 90, 90)
	if team and Config.Teams[team] and not ally then
		color = Config.Teams[team].Color
	end
	plate.name.TextColor3 = color
	plate.bar.BackgroundColor3 = color
	plate.gui.AlwaysOnTop = ally
end

function Nameplates.Init(context)
	ctx = context
	CollectionService:GetInstanceAddedSignal("Combatant"):Connect(function(model)
		task.spawn(attach, model)
	end)
	for _, model in ipairs(CollectionService:GetTagged("Combatant")) do
		task.spawn(attach, model)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			for model, plate in pairs(plates) do
				if model.Parent then
					Nameplates.Recolor(plate)
				else
					plates[model] = nil
				end
			end
		end
	end)
end

return Nameplates
