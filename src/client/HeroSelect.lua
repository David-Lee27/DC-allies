-- Hero select screen (start of match, and mid-match swaps with H while in spawn / dead).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Heroes = require(ReplicatedStorage.Shared.Heroes)
local Util = require(ReplicatedStorage.Shared.Util)
local make, corner, stroke = Util.make, Util.corner, Util.stroke

local HeroSelect = {}

local player = Players.LocalPlayer
local ctx
local gui, container
local r = {}
local isOpen, forced = false, false
local selected = nil
local cards = {}

local DARK = Color3.fromRGB(14, 16, 24)
local PANEL = Color3.fromRGB(26, 29, 40)
local GOLD = Color3.fromRGB(255, 215, 90)

local KIND_TEXT = {
	hitscan = "Beam", projectile = "Projectile", melee = "Melee", dash = "Dash", cone = "Cone blast",
	aoe = "Area burst", zone = "Zone", buff = "Buff", leapSlam = "Leap slam", grapple = "Grapple",
	pull = "Pull", teleport = "Blink", wall = "Barrier", barrage = "Barrage",
}

local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	return make("TextLabel", props)
end

local function myEntry()
	return ctx.MyEntry()
end

local function takenBy(heroId)
	local entry = myEntry()
	if not entry then
		return nil
	end
	for _, e in ipairs(ctx.Roster:GetChildren()) do
		if e ~= entry and e:GetAttribute("Team") == entry:GetAttribute("Team") and e:GetAttribute("Hero") == heroId and not e:GetAttribute("IsBot") then
			return e:GetAttribute("DisplayName")
		end
	end
	return nil
end

local function abilitySummary(a)
	local parts = { KIND_TEXT[a.kind] or a.kind }
	local dmg = a.damage or a.damagePerTick
	if dmg then
		table.insert(parts, (a.damagePerTick and (dmg .. "/tick") or tostring(dmg)) .. " dmg")
	end
	local heal = a.heal or a.healPerTick or a.healAllies
	if heal then
		table.insert(parts, (a.healPerTick and (heal .. "/tick") or tostring(heal)) .. " heal")
	end
	if a.stun then
		table.insert(parts, "stun")
	end
	if a.slow then
		table.insert(parts, "slow")
	end
	return table.concat(parts, " · ")
end

------------------------------------------------------------------ detail panel
local function showDetails(hero)
	selected = hero
	for id, card in pairs(cards) do
		card.stroke.Color = id == hero.id and Color3.new(1, 1, 1) or Color3.fromRGB(0, 0, 0)
		card.stroke.Thickness = id == hero.id and 3 or 1
	end
	r.dName.Text = string.upper(hero.name)
	r.dName.TextColor3 = hero.color:Lerp(Color3.new(1, 1, 1), 0.4)
	r.dRole.Text = string.upper(hero.role) .. "   ·   " .. hero.health .. " HP   ·   SPEED " .. hero.speed
	r.dRole.TextColor3 = Config.RoleColors[hero.role]
	r.dDesc.Text = hero.description
	for _, slot in ipairs(Config.Slots) do
		local a = hero.abilities[slot]
		local row = r.dAbilities[slot]
		row.name.Text = a.name
		local cd = slot == "Ultimate" and "100% charge" or (slot == "Primary" and "" or (a.cooldown .. "s cooldown"))
		row.info.Text = abilitySummary(a) .. (cd ~= "" and ("   ·   " .. cd) or "")
	end
	local entry = myEntry()
	local mine = entry and entry:GetAttribute("Hero") == hero.id
	local taken = takenBy(hero.id)
	r.lock.Text = mine and "LOCKED IN" or (taken and ("TAKEN BY " .. string.upper(taken)) or "LOCK IN")
	r.lock.BackgroundColor3 = mine and GOLD or (taken and Color3.fromRGB(70, 70, 80) or hero.color)
end

------------------------------------------------------------------ build
local function build()
	gui = make("ScreenGui", { Name = "HeroSelect", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 10, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	local bg = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = DARK, BackgroundTransparency = 0.08, Parent = gui })
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(40, 30, 70), Color3.fromRGB(10, 10, 16)), Parent = bg })

	container = make("Frame", { Size = UDim2.fromOffset(1240, 640), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = gui })
	local scale = make("UIScale", { Parent = container })
	local function rescale()
		local vp = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(1, vp.X / 1300, vp.Y / 700)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	r.title = label({ Size = UDim2.fromOffset(700, 48), Position = UDim2.fromOffset(0, 0), Text = "CHOOSE YOUR HERO", Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = container })
	r.subtitle = label({ Size = UDim2.fromOffset(700, 22), Position = UDim2.fromOffset(2, 52), Text = "", TextColor3 = Color3.fromRGB(200, 200, 220), TextXAlignment = Enum.TextXAlignment.Left, Parent = container })
	label({ Size = UDim2.fromOffset(500, 22), Position = UDim2.new(1, 0, 0, 10), AnchorPoint = Vector2.new(1, 0), Text = Config.GameTitle, Font = Enum.Font.GothamBlack, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Right, Parent = container })
	r.close = make("TextButton", { Size = UDim2.fromOffset(110, 32), Position = UDim2.new(1, 0, 0, 44), AnchorPoint = Vector2.new(1, 0), Text = "CLOSE (H)", Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = PANEL, Parent = container }, { corner(6), make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }) })
	r.close.MouseButton1Click:Connect(function()
		HeroSelect.Close()
	end)

	-- team panel
	local team = make("Frame", { Size = UDim2.fromOffset(250, 540), Position = UDim2.fromOffset(0, 96), BackgroundColor3 = PANEL, BackgroundTransparency = 0.2, Parent = container }, { corner(10) })
	r.teamTitle = label({ Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 10), Text = "YOUR TEAM", Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = team })
	r.teamList = make("Frame", { Size = UDim2.new(1, -20, 1, -50), Position = UDim2.fromOffset(10, 42), BackgroundTransparency = 1, Parent = team })
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = r.teamList })

	-- hero grid
	local grid = make("Frame", { Size = UDim2.fromOffset(510, 540), Position = UDim2.fromOffset(270, 96), BackgroundTransparency = 1, Parent = container })
	for col, role in ipairs(Config.RoleOrder) do
		local x = (col - 1) * 170
		label({ Size = UDim2.fromOffset(160, 24), Position = UDim2.fromOffset(x, 0), Text = string.upper(role) .. "S", Font = Enum.Font.GothamBlack, TextColor3 = Config.RoleColors[role], Parent = grid })
		local row = 0
		for _, hero in ipairs(Heroes.List) do
			if hero.role == role then
				local btn = make("TextButton", {
					Size = UDim2.fromOffset(160, 158),
					Position = UDim2.fromOffset(x, 34 + row * 168),
					BackgroundColor3 = hero.color,
					AutoButtonColor = true,
					Text = "",
					Parent = grid,
				}, { corner(10) })
				local s = stroke(Color3.new(0, 0, 0), 1, 0)
				s.Parent = btn
				make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(90, 90, 110)), Parent = btn })
				label({ Size = UDim2.new(1, 0, 0, 80), Position = UDim2.fromOffset(0, 18), Text = hero.outfit.emblem and hero.outfit.emblem.text or string.sub(hero.name, 1, 1), Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.5, Parent = btn })
				local nameBar = make("Frame", { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 1, -40), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Parent = btn }, { corner(10) })
				label({ Size = UDim2.new(1, -12, 1, -14), Position = UDim2.fromOffset(6, 7), Text = string.upper(hero.name), Font = Enum.Font.GothamBlack, Parent = nameBar })
				local takenLabel = label({ Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 4), Text = "", TextColor3 = Color3.fromRGB(255, 255, 255), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 1, Parent = btn })
				btn.MouseEnter:Connect(function()
					showDetails(hero)
				end)
				btn.MouseButton1Click:Connect(function()
					showDetails(hero)
				end)
				cards[hero.id] = { button = btn, stroke = s, taken = takenLabel }
				row += 1
			end
		end
	end

	-- detail panel
	local detail = make("Frame", { Size = UDim2.fromOffset(440, 540), Position = UDim2.new(1, 0, 0, 96), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = PANEL, BackgroundTransparency = 0.15, Parent = container }, { corner(10) })
	r.dName = label({ Size = UDim2.new(1, -40, 0, 44), Position = UDim2.fromOffset(20, 16), Text = "", Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
	r.dRole = label({ Size = UDim2.new(1, -40, 0, 18), Position = UDim2.fromOffset(20, 64), Text = "", TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
	r.dDesc = label({ Size = UDim2.new(1, -40, 0, 60), Position = UDim2.fromOffset(20, 92), Text = "", TextScaled = false, TextSize = 16, TextWrapped = true, Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(210, 210, 225), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = detail })
	r.dAbilities = {}
	for i, slot in ipairs(Config.Slots) do
		local y = 160 + (i - 1) * 70
		local row = make("Frame", { Size = UDim2.new(1, -40, 0, 62), Position = UDim2.fromOffset(20, y), BackgroundColor3 = DARK, BackgroundTransparency = 0.3, Parent = detail }, { corner(8) })
		local key = make("Frame", { Size = UDim2.fromOffset(62, 46), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = slot == "Ultimate" and GOLD or Color3.fromRGB(60, 64, 80), Parent = row }, { corner(6) })
		label({ Size = UDim2.new(1, -8, 1, -16), Position = UDim2.fromOffset(4, 8), Text = Config.SlotKeys[slot], Font = Enum.Font.GothamBlack, TextColor3 = slot == "Ultimate" and DARK or Color3.new(1, 1, 1), Parent = key })
		local name = label({ Size = UDim2.new(1, -94, 0, 22), Position = UDim2.fromOffset(82, 8), Text = "", Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local info = label({ Size = UDim2.new(1, -94, 0, 16), Position = UDim2.fromOffset(82, 36), Text = "", Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(190, 190, 205), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		r.dAbilities[slot] = { name = name, info = info }
	end
	r.lock = make("TextButton", { Size = UDim2.new(1, -40, 0, 54), Position = UDim2.new(0, 20, 1, -72), Text = "LOCK IN", Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = GOLD, Parent = detail }, { corner(8), make("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }) })
	r.error = label({ Size = UDim2.new(1, -40, 0, 18), Position = UDim2.new(0, 20, 1, -94), Text = "", TextColor3 = Color3.fromRGB(255, 110, 110), Parent = detail })
	r.lock.MouseButton1Click:Connect(function()
		if selected then
			r.error.Text = ""
			ctx.Remotes.PickHero:FireServer(selected.id)
		end
	end)
end

------------------------------------------------------------------ refresh loop
local function refresh()
	local entry = myEntry()
	if not entry then
		return
	end
	local myTeam = entry:GetAttribute("Team")
	local teamColor = Config.Teams[myTeam] and Config.Teams[myTeam].Color or Color3.new(1, 1, 1)
	r.teamTitle.Text = "YOUR TEAM  ·  " .. string.upper(myTeam or "")
	r.teamTitle.TextColor3 = teamColor

	for _, child in ipairs(r.teamList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local order = 0
	for _, e in ipairs(ctx.Roster:GetChildren()) do
		if e:GetAttribute("Team") == myTeam then
			order += 1
			local hero = Heroes.Get(e:GetAttribute("Hero") or "")
			local isMe = e == entry
			local row = make("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = hero and hero.color or Color3.fromRGB(50, 52, 64), BackgroundTransparency = 0.4, LayoutOrder = isMe and 0 or order, Parent = r.teamList }, { corner(6) })
			if isMe then
				stroke(GOLD, 2, 0).Parent = row
			end
			label({ Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 5), Text = (e:GetAttribute("DisplayName") or e.Name), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			label({ Size = UDim2.new(1, -16, 0, 16), Position = UDim2.fromOffset(8, 27), Text = hero and (hero.name .. "  ·  " .. hero.role) or "Selecting...", Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(220, 220, 230), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		end
	end

	if selected then
		showDetails(selected)
	end
	local myHero = entry:GetAttribute("Hero")
	for id, card in pairs(cards) do
		local taken = takenBy(id)
		card.taken.Text = id == myHero and "★ YOU" or (taken and "TAKEN" or "")
		card.button.BackgroundTransparency = (taken and id ~= myHero) and 0.6 or 0
		if id == myHero then
			card.stroke.Color = GOLD
			card.stroke.Thickness = 3
		end
	end

	local s = ctx.State:GetAttribute("State")
	if s == "HeroSelect" then
		local left = math.max(0, math.ceil((ctx.State:GetAttribute("StateEnds") or 0) - Util.now()))
		r.title.Text = "CHOOSE YOUR HERO"
		r.subtitle.Text = "Match starts in " .. left .. "s  ·  3 Vanguards · 3 Duelists · 3 Strategists  ·  bots fill empty slots"
	else
		r.title.Text = forced and "CHOOSE YOUR HERO" or "SWAP HERO"
		r.subtitle.Text = forced and "Pick a hero to join the fight" or "You can swap while dead or inside your spawn room"
	end
	r.close.Visible = not forced and s ~= "HeroSelect"
end

------------------------------------------------------------------ API
function HeroSelect.IsOpen()
	return isOpen
end

function HeroSelect.Open(force)
	forced = force == true
	isOpen = true
	gui.Enabled = true
	local entry = myEntry()
	local current = entry and Heroes.Get(entry:GetAttribute("Hero") or "")
	showDetails(current or selected or Heroes.List[1])
	refresh()
end

function HeroSelect.Close()
	if forced then
		return
	end
	isOpen = false
	gui.Enabled = false
end

function HeroSelect.Toggle()
	local s = ctx.State:GetAttribute("State")
	if s == "HeroSelect" or s == "Waiting" or s == "MatchEnd" then
		return
	end
	if isOpen then
		HeroSelect.Close()
	else
		HeroSelect.Open(false)
	end
end

function HeroSelect.OnPickResult(d)
	if d.ok then
		r.error.Text = ""
		forced = false
		local s = ctx.State:GetAttribute("State")
		if s ~= "HeroSelect" and isOpen then
			HeroSelect.Close()
		end
	else
		r.error.Text = d.reason or "Can't pick that hero"
	end
	if isOpen then
		refresh()
	end
end

function HeroSelect.Init(context)
	ctx = context
	build()
	local function onState()
		local s = ctx.State:GetAttribute("State")
		if s == "HeroSelect" then
			HeroSelect.Open(false)
		elseif isOpen and not forced and gui.Enabled and r.lastState == "HeroSelect" then
			isOpen = false
			gui.Enabled = false
		end
		r.lastState = s
	end
	ctx.State:GetAttributeChangedSignal("State"):Connect(onState)
	onState()
	task.spawn(function()
		while true do
			task.wait(0.3)
			if isOpen then
				refresh()
			end
		end
	end)
end

return HeroSelect
