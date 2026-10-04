-- Over-the-shoulder camera, aiming and ability input (keyboard/mouse, gamepad and touch buttons).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Heroes = require(ReplicatedStorage.Shared.Heroes)
local Util = require(ReplicatedStorage.Shared.Util)

local Controls = {}

local ctx
local player = Players.LocalPlayer
local firing = false
local nextPrimary = 0
local freeCursor = false
local SHOULDER = Vector3.new(1.8, 0.8, 0)

local function getCharacter()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then
		return char, hum, root
	end
	return nil
end

local function myHero()
	local entry = ctx.MyEntry()
	return entry and Heroes.Get(entry:GetAttribute("Hero") or ""), entry
end

function Controls.GetAim()
	local cam = workspace.CurrentCamera
	local vp = cam.ViewportSize
	local ray = cam:ViewportPointToRay(vp.X / 2, vp.Y / 2)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { workspace:FindFirstChild("ClientFX"), workspace:FindFirstChild("Effects") }
	if player.Character then
		table.insert(exclude, player.Character)
	end
	params.FilterDescendantsInstances = exclude
	local result = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	return result and result.Position or ray.Origin + ray.Direction * 600
end

local function canAct()
	if ctx.MenuOpen() then
		return false
	end
	local s = ctx.State:GetAttribute("State")
	if s == "HeroSelect" or s == "Waiting" or s == "MatchEnd" then
		return false
	end
	return getCharacter() ~= nil
end

local function tryUse(slot)
	if not canAct() then
		return
	end
	local hero, entry = myHero()
	if not hero then
		return
	end
	if slot == "Ultimate" then
		if (entry:GetAttribute("Ult") or 0) < 100 then
			return
		end
	elseif Util.now() < (entry:GetAttribute("CD_" .. slot) or 0) - 0.05 then
		return
	end
	ctx.Remotes.UseAbility:FireServer(slot, Controls.GetAim())
end

local function bindActions()
	local high = Enum.ContextActionPriority.High.Value
	ContextActionService:BindActionAtPriority("DCA_Primary", function(_, inputState)
		firing = inputState == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, true, high, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("DCA_Primary", "FIRE")

	local slots = {
		{ "DCA_Ability1", "Ability1", { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL1 }, "A1" },
		{ "DCA_Ability2", "Ability2", { Enum.KeyCode.E, Enum.KeyCode.ButtonR1 }, "A2" },
		{ "DCA_Ultimate", "Ultimate", { Enum.KeyCode.Q, Enum.KeyCode.ButtonY }, "ULT" },
	}
	for _, s in ipairs(slots) do
		ContextActionService:BindActionAtPriority(s[1], function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				tryUse(s[2])
			end
			return Enum.ContextActionResult.Sink
		end, true, high, table.unpack(s[3]))
		ContextActionService:SetTitle(s[1], s[4])
	end

	ContextActionService:BindAction("DCA_HeroSelect", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			ctx.ToggleHeroSelect()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.H, Enum.KeyCode.ButtonSelect)
	ContextActionService:SetTitle("DCA_HeroSelect", "HERO")

	ContextActionService:BindAction("DCA_Scoreboard", function(_, inputState)
		ctx.ShowScoreboard(inputState == Enum.UserInputState.Begin)
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Tab)

	ContextActionService:BindAction("DCA_FreeCursor", function(_, inputState)
		freeCursor = inputState == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.LeftAlt)
end

function Controls.Init(context)
	ctx = context
	player.CameraMinZoomDistance = 7
	player.CameraMaxZoomDistance = 18
	pcall(function()
		player.DevEnableMouseLock = false -- Shift is an ability key, not shift-lock
	end)
	bindActions()

	RunService:BindToRenderStep("DCAlliesShoulderCam", Enum.RenderPriority.Camera.Value - 1, function()
		local char, hum, root = getCharacter()
		local lock = char ~= nil and not ctx.MenuOpen() and not freeCursor and not UserInputService.TouchEnabled
		if lock then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
		elseif UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		if not lock then
			UserInputService.MouseIconEnabled = true
		end

		if char then
			hum.CameraOffset = hum.CameraOffset:Lerp(SHOULDER, 0.2)
			local stunned = (ctx.MyEntry() and ctx.MyEntry():GetAttribute("Stunned")) == true
			if lock and not stunned then
				hum.AutoRotate = false
				local look = workspace.CurrentCamera.CFrame.LookVector
				local yaw = math.atan2(-look.X, -look.Z)
				root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
			else
				hum.AutoRotate = true
			end
		end
	end)

	RunService.Heartbeat:Connect(function()
		if not firing or not canAct() then
			return
		end
		local hero = myHero()
		if not hero then
			return
		end
		local now = os.clock()
		if now >= nextPrimary then
			nextPrimary = now + hero.abilities.Primary.cooldown
			ctx.Remotes.UseAbility:FireServer("Primary", Controls.GetAim())
		end
	end)
end

return Controls
