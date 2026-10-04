-- In-match HUD: objective, health, abilities, kill feed, announcements, death screen, scoreboard.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Heroes = require(ReplicatedStorage.Shared.Heroes)
local Util = require(ReplicatedStorage.Shared.Util)
local make, corner, stroke = Util.make, Util.corner, Util.stroke

local HUD = {}

local player = Players.LocalPlayer
local ctx
local gui
local r = {} -- references to UI elements
local deathInfo = nil
local scoreboardHeld = false

local DARK = Color3.fromRGB(16, 18, 26)
local WHITE = Color3.new(1, 1, 1)

local function hex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

local function teamColor(team)
	return Config.Teams[team] and Config.Teams[team].Color or WHITE
end

local function clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextScaled = props.TextScaled ~= false
	return make("TextLabel", props)
end

------------------------------------------------------------------ builders
local function buildCrosshair()
	local holder = make("Frame", { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = gui })
	make("Frame", { Size = UDim2.fromOffset(4, 4), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = holder }, { corner(2), stroke(Color3.new(0, 0, 0), 1, 0.4) })
	for _, d in ipairs({ { 0, -11, 2, 7 }, { 0, 11, 2, 7 }, { -11, 0, 7, 2 }, { 11, 0, 7, 2 } }) do
		make("Frame", { Size = UDim2.fromOffset(d[3], d[4]), Position = UDim2.new(0.5, d[1], 0.5, d[2]), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = WHITE, BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = holder })
	end
	r.crosshair = holder
	local hit = make("Frame", { Size = UDim2.fromOffset(36, 36), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, Parent = gui })
	r.hitLines = {}
	for _, rot in ipairs({ 45, -45 }) do
		table.insert(r.hitLines, make("Frame", { Size = UDim2.fromOffset(30, 3), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = rot, BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = hit }))
	end
	r.hitMarker = hit
	r.status = label({ Size = UDim2.fromOffset(300, 22), Position = UDim2.new(0.5, 0, 0.5, 60), AnchorPoint = Vector2.new(0.5, 0), Text = "", TextColor3 = Color3.fromRGB(255, 220, 90), TextStrokeTransparency = 0.4, Parent = gui })
	r.small = label({ Size = UDim2.fromOffset(400, 24), Position = UDim2.new(0.5, 0, 0.5, 34), AnchorPoint = Vector2.new(0.5, 0), Text = "", TextColor3 = Color3.fromRGB(255, 90, 90), TextStrokeTransparency = 0.3, TextTransparency = 1, Font = Enum.Font.GothamBlack, Parent = gui })
end

local function buildObjective()
	local panel = make("Frame", { Size = UDim2.fromOffset(560, 64), Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = gui })
	local function teamBar(team, side)
		local frame = make("Frame", {
			Size = UDim2.fromOffset(220, 26),
			Position = side == "left" and UDim2.new(0, 0, 0, 8) or UDim2.new(1, 0, 0, 8),
			AnchorPoint = side == "left" and Vector2.new(0, 0) or Vector2.new(1, 0),
			BackgroundColor3 = DARK,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			Parent = panel,
		}, { corner(6), stroke(teamColor(team), 2, 0.2) })
		local fill = make("Frame", {
			Size = UDim2.fromScale(0, 1),
			Position = side == "left" and UDim2.fromScale(1, 0) or UDim2.fromScale(0, 0),
			AnchorPoint = side == "left" and Vector2.new(1, 0) or Vector2.new(0, 0),
			BackgroundColor3 = teamColor(team),
			BorderSizePixel = 0,
			Parent = frame,
		}, { corner(6) })
		local pct = label({ Size = UDim2.new(1, -16, 1, -6), Position = UDim2.fromOffset(8, 3), Text = "0%", TextXAlignment = side == "left" and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right, TextStrokeTransparency = 0.5, ZIndex = 2, Parent = frame })
		local tag = label({ Size = UDim2.fromOffset(60, 14), Position = side == "left" and UDim2.new(0, 2, 1, 4) or UDim2.new(1, -2, 1, 4), AnchorPoint = side == "left" and Vector2.new(0, 0) or Vector2.new(1, 0), Text = string.upper(team), TextColor3 = teamColor(team), TextXAlignment = side == "left" and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right, Parent = frame })
		local pips = {}
		for i = 1, Config.RoundsToWin do
			local x = side == "left" and (220 - i * 18) or (i * 18 - 14)
			pips[i] = make("Frame", { Size = UDim2.fromOffset(12, 12), Position = UDim2.new(0, x, 1, 5), BackgroundColor3 = DARK, BorderSizePixel = 0, Parent = frame }, { corner(3), stroke(teamColor(team), 1.5, 0) })
		end
		return { fill = fill, pct = pct, tag = tag, pips = pips }
	end
	r.blue = teamBar("Blue", "left")
	r.red = teamBar("Red", "right")
	local pointFrame = make("Frame", { Size = UDim2.fromOffset(56, 56), Position = UDim2.new(0.5, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = DARK, BackgroundTransparency = 0.1, BorderSizePixel = 0, Parent = panel }, { corner(28) })
	r.pointStroke = stroke(WHITE, 3, 0)
	r.pointStroke.Parent = pointFrame
	r.pointFill = make("Frame", { Size = UDim2.fromScale(1, 0), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = pointFrame }, { corner(28) })
	r.pointText = label({ Size = UDim2.new(1, -14, 1, -14), Position = UDim2.fromOffset(7, 7), Text = "A", Font = Enum.Font.GothamBlack, ZIndex = 2, Parent = pointFrame })
	r.stateText = label({ Size = UDim2.fromOffset(400, 20), Position = UDim2.new(0.5, 0, 0, 76), AnchorPoint = Vector2.new(0.5, 0), Text = "", TextStrokeTransparency = 0.5, Parent = gui })
	r.onPoint = label({ Size = UDim2.fromOffset(400, 16), Position = UDim2.new(0.5, 0, 0, 98), AnchorPoint = Vector2.new(0.5, 0), Text = "", RichText = true, TextStrokeTransparency = 0.5, Font = Enum.Font.Gotham, Parent = gui })
	r.objective = panel
end

local function buildHealth()
	local panel = make("Frame", { Size = UDim2.fromOffset(340, 92), Position = UDim2.new(0, 24, 1, -24), AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = DARK, BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = gui }, { corner(10) })
	r.heroName = label({ Size = UDim2.new(1, -24, 0, 26), Position = UDim2.fromOffset(12, 8), Text = "", Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	r.heroRole = label({ Size = UDim2.new(1, -24, 0, 14), Position = UDim2.fromOffset(12, 36), Text = "", TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	local bg = make("Frame", { Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 58), BackgroundColor3 = Color3.fromRGB(40, 40, 50), BorderSizePixel = 0, Parent = panel }, { corner(5) })
	r.hpFill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(240, 240, 240), BorderSizePixel = 0, Parent = bg }, { corner(5) })
	r.hpText = label({ Size = UDim2.new(1, -10, 1, -4), Position = UDim2.fromOffset(5, 2), Text = "", TextColor3 = DARK, ZIndex = 2, Parent = bg })
	r.healthPanel = panel
end

local function buildAbilities()
	local panel = make("Frame", { Size = UDim2.fromOffset(380, 110), Position = UDim2.new(1, -24, 1, -24), AnchorPoint = Vector2.new(1, 1), BackgroundTransparency = 1, Parent = gui })
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel })
	r.slots = {}
	for i, slot in ipairs(Config.Slots) do
		local size = slot == "Ultimate" and 82 or 66
		local holder = make("Frame", { Size = UDim2.fromOffset(size, size + 22), BackgroundTransparency = 1, LayoutOrder = i, Parent = panel })
		local box = make("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = DARK, BackgroundTransparency = 0.2, BorderSizePixel = 0, ClipsDescendants = true, Parent = holder }, { corner(slot == "Ultimate" and size / 2 or 10) })
		local s = stroke(WHITE, 2, 0.5)
		s.Parent = box
		local overlay = make("Frame", { Size = UDim2.fromScale(1, 0), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 2, Parent = box })
		local key = label({ Size = UDim2.fromOffset(size - 8, 14), Position = UDim2.fromOffset(4, 4), Text = Config.SlotKeys[slot], TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 200, 210), ZIndex = 3, Parent = box })
		local big = label({ Size = UDim2.new(1, -16, 0, 26), Position = UDim2.new(0, 8, 0.5, -6), Text = "", Font = Enum.Font.GothamBlack, ZIndex = 3, Parent = box })
		local name = label({ Size = UDim2.new(1, 20, 0, 14), Position = UDim2.new(0.5, 0, 1, -16), AnchorPoint = Vector2.new(0.5, 0), Text = "", TextColor3 = Color3.fromRGB(220, 220, 230), TextStrokeTransparency = 0.5, Parent = holder })
		r.slots[slot] = { box = box, stroke = s, overlay = overlay, big = big, name = name, key = key }
	end
	r.abilityPanel = panel
end

local function buildKillfeed()
	local feed = make("Frame", { Size = UDim2.fromOffset(380, 220), Position = UDim2.new(1, -16, 0, 16), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, Parent = gui })
	make("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = feed })
	r.feed = feed
	r.feedCount = 0
end

local function buildAnnounce()
	r.announce = label({ Size = UDim2.fromOffset(800, 54), Position = UDim2.new(0.5, 0, 0.24, 0), AnchorPoint = Vector2.new(0.5, 0.5), Text = "", Font = Enum.Font.GothamBlack, TextTransparency = 1, TextStrokeTransparency = 1, Parent = gui })
	r.announceSub = label({ Size = UDim2.fromOffset(600, 24), Position = UDim2.new(0.5, 0, 0.24, 40), AnchorPoint = Vector2.new(0.5, 0.5), Text = "", TextTransparency = 1, TextStrokeTransparency = 1, Parent = gui })
end

local function buildDeath()
	local frame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(30, 0, 0), BackgroundTransparency = 0.55, Visible = false, ZIndex = 5, Parent = gui })
	r.deathTitle = label({ Size = UDim2.fromOffset(700, 50), Position = UDim2.fromScale(0.5, 0.4), AnchorPoint = Vector2.new(0.5, 0.5), Text = "ELIMINATED", Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 80, 80), ZIndex = 6, Parent = frame })
	r.deathBy = label({ Size = UDim2.fromOffset(700, 26), Position = UDim2.new(0.5, 0, 0.4, 42), AnchorPoint = Vector2.new(0.5, 0.5), Text = "", ZIndex = 6, Parent = frame })
	r.deathTimer = label({ Size = UDim2.fromOffset(700, 30), Position = UDim2.new(0.5, 0, 0.4, 84), AnchorPoint = Vector2.new(0.5, 0.5), Text = "", Font = Enum.Font.GothamBlack, ZIndex = 6, Parent = frame })
	label({ Size = UDim2.fromOffset(700, 20), Position = UDim2.new(0.5, 0, 0.4, 120), AnchorPoint = Vector2.new(0.5, 0.5), Text = "Press H to change hero", TextColor3 = Color3.fromRGB(220, 220, 220), ZIndex = 6, Parent = frame })
	r.death = frame
	r.flash = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4, Parent = gui })
end

local function buildScoreboard()
	local frame = make("Frame", { Size = UDim2.fromOffset(820, 440), Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = DARK, BackgroundTransparency = 0.1, Visible = false, ZIndex = 10, Parent = gui }, { corner(12) })
	r.sbTitle = label({ Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 10), Text = "SCOREBOARD", Font = Enum.Font.GothamBlack, ZIndex = 11, Parent = frame })
	r.sbLists = {}
	for i, team in ipairs({ "Blue", "Red" }) do
		local col = make("Frame", { Size = UDim2.new(0.5, -24, 1, -60), Position = UDim2.new((i - 1) * 0.5, 12, 0, 50), BackgroundTransparency = 1, ZIndex = 11, Parent = frame })
		make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = col })
		r.sbLists[team] = col
	end
	r.scoreboard = frame
end

local function buildMatchEnd()
	r.matchEnd = label({ Size = UDim2.fromOffset(900, 110), Position = UDim2.fromScale(0.5, 0.12), AnchorPoint = Vector2.new(0.5, 0), Text = "", Font = Enum.Font.GothamBlack, TextStrokeTransparency = 0.2, Visible = false, ZIndex = 12, Parent = gui })
end

local function buildHints()
	r.hints = label({
		Size = UDim2.fromOffset(700, 16),
		Position = UDim2.new(0.5, 0, 1, -8),
		AnchorPoint = Vector2.new(0.5, 1),
		Text = "LMB Fire   SHIFT Ability 1   E Ability 2   Q Ultimate   H Swap Hero (in spawn)   TAB Scores   ALT Free Cursor",
		TextColor3 = Color3.fromRGB(200, 200, 210),
		TextTransparency = 0.3,
		Font = Enum.Font.Gotham,
		Parent = gui,
	})
end

------------------------------------------------------------------ scoreboard
local function refreshScoreboard()
	for _, team in ipairs({ "Blue", "Red" }) do
		for _, child in ipairs(r.sbLists[team]:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
	end
	local function row(parent, order, cells, color, bold)
		local f = make("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = color, BackgroundTransparency = bold and 1 or 0.75, BorderSizePixel = 0, LayoutOrder = order, ZIndex = 11, Parent = parent }, { corner(4) })
		local widths = { 0.34, 0.26, 0.1, 0.1, 0.1, 0.1 }
		local x = 0
		for i, text in ipairs(cells) do
			label({ Size = UDim2.new(widths[i], -6, 1, -8), Position = UDim2.new(x, 6, 0, 4), Text = tostring(text), TextXAlignment = i <= 2 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center, Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamBold, ZIndex = 12, Parent = f })
			x += widths[i]
		end
	end
	local entries = { Blue = {}, Red = {} }
	for _, e in ipairs(ctx.Roster:GetChildren()) do
		local team = e:GetAttribute("Team")
		if entries[team] then
			table.insert(entries[team], e)
		end
	end
	for team, list in pairs(entries) do
		table.sort(list, function(a, b)
			return (a:GetAttribute("Kills") or 0) > (b:GetAttribute("Kills") or 0)
		end)
		row(r.sbLists[team], 0, { string.upper(team) .. " TEAM", "HERO", "K", "D", "DMG", "HEAL" }, teamColor(team), true)
		for i, e in ipairs(list) do
			local hero = Heroes.Get(e:GetAttribute("Hero") or "")
			local isMe = e.Name == tostring(player.UserId)
			row(r.sbLists[team], i, {
				(isMe and "▶ " or "") .. (e:GetAttribute("DisplayName") or e.Name),
				hero and hero.name or "-",
				e:GetAttribute("Kills") or 0,
				e:GetAttribute("Deaths") or 0,
				e:GetAttribute("Damage") or 0,
				e:GetAttribute("Healing") or 0,
			}, teamColor(team), false)
		end
	end
end

------------------------------------------------------------------ public API
function HUD.HitMarker(kill)
	for _, line in ipairs(r.hitLines) do
		line.BackgroundColor3 = kill and Color3.fromRGB(255, 60, 60) or WHITE
	end
	r.hitMarker.Visible = true
	local token = {}
	r.hitToken = token
	task.delay(0.12, function()
		if r.hitToken == token then
			r.hitMarker.Visible = false
		end
	end)
end

function HUD.Hurt()
	r.flash.BackgroundTransparency = 0.82
	TweenService:Create(r.flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
end

local function pushFeed(richText)
	r.feedCount += 1
	local entry = make("Frame", { Size = UDim2.fromOffset(380, 26), BackgroundColor3 = DARK, BackgroundTransparency = 0.3, BorderSizePixel = 0, LayoutOrder = -r.feedCount, Parent = r.feed }, { corner(5) })
	label({ Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), Text = richText, RichText = true, TextXAlignment = Enum.TextXAlignment.Right, Parent = entry })
	local items = {}
	for _, child in ipairs(r.feed:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(items, child)
		end
	end
	table.sort(items, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 7, #items do
		items[i]:Destroy()
	end
	task.delay(7, function()
		if entry.Parent then
			entry:Destroy()
		end
	end)
end

function HUD.KillFeed(d)
	local victim = string.format('<font color="%s">%s</font>', hex(teamColor(d.victimTeam)), d.victim)
	if d.killer then
		local killer = string.format('<font color="%s">%s</font>', hex(teamColor(d.killerTeam)), d.killer)
		pushFeed(killer .. '  <font color="#BBBBBB">[' .. (d.source or "KO") .. "]</font>  " .. victim)
	else
		pushFeed(victim .. ' <font color="#BBBBBB">was eliminated</font>')
	end
end

function HUD.UltCast(d)
	pushFeed(string.format('<font color="%s">%s</font> <font color="#FFD95A"><b>%s!</b></font>', hex(teamColor(d.team)), d.name, string.upper(d.ability)))
end

function HUD.Announce(d)
	r.announce.Text = d.text or ""
	r.announce.TextColor3 = d.color or WHITE
	r.announceSub.Text = d.sub or ""
	for _, l in ipairs({ r.announce, r.announceSub }) do
		l.TextTransparency = 0
		l.TextStrokeTransparency = 0.3
	end
	local token = {}
	r.announceToken = token
	task.delay(2.8, function()
		if r.announceToken == token then
			for _, l in ipairs({ r.announce, r.announceSub }) do
				TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
		end
	end)
end

function HUD.AnnounceSmall(text)
	r.small.Text = text
	r.small.TextTransparency = 0
	TweenService:Create(r.small, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
end

function HUD.ShowDeath(d)
	deathInfo = d
end

function HUD.ShowScoreboard(show)
	scoreboardHeld = show
	if show then
		refreshScoreboard()
	end
end

------------------------------------------------------------------ per-frame update
local lastScoreboardRefresh = 0

local function update()
	local st = ctx.State
	local s = st:GetAttribute("State") or "Waiting"
	local now = Util.now()
	local remaining = (st:GetAttribute("StateEnds") or 0) - now
	local entry = ctx.MyEntry()
	local myTeam = entry and entry:GetAttribute("Team")

	-- objective
	local blue, red = st:GetAttribute("BlueScore") or 0, st:GetAttribute("RedScore") or 0
	r.blue.fill.Size = UDim2.fromScale(blue / 100, 1)
	r.red.fill.Size = UDim2.fromScale(red / 100, 1)
	r.blue.pct.Text = string.format("%d%%", math.floor(blue))
	r.red.pct.Text = string.format("%d%%", math.floor(red))
	r.blue.tag.Text = myTeam == "Blue" and "BLUE (YOU)" or "BLUE"
	r.red.tag.Text = myTeam == "Red" and "RED (YOU)" or "RED"
	for i = 1, Config.RoundsToWin do
		r.blue.pips[i].BackgroundColor3 = (st:GetAttribute("BlueRounds") or 0) >= i and teamColor("Blue") or DARK
		r.red.pips[i].BackgroundColor3 = (st:GetAttribute("RedRounds") or 0) >= i and teamColor("Red") or DARK
	end
	local owner = st:GetAttribute("PointOwner") or ""
	local capTeam = st:GetAttribute("CaptureTeam") or ""
	local capProgress = st:GetAttribute("CaptureProgress") or 0
	local contested = st:GetAttribute("Contested")
	r.pointStroke.Color = owner ~= "" and teamColor(owner) or WHITE
	r.pointFill.BackgroundColor3 = capTeam ~= "" and teamColor(capTeam) or WHITE
	r.pointFill.Size = UDim2.fromScale(1, capProgress / 100)
	r.pointText.Text = capProgress > 0 and tostring(capProgress) or "A"

	local stateText = ""
	if s == "HeroSelect" then
		stateText = "HERO SELECT  " .. clock(remaining)
	elseif s == "Preparing" then
		stateText = "ROUND " .. (st:GetAttribute("Round") or 1) .. " STARTS IN " .. clock(remaining)
	elseif s == "InProgress" then
		if contested then
			local ownerScore = owner == "Blue" and blue or (owner == "Red" and red or 0)
			stateText = ownerScore >= 99 and "OVERTIME" or "CONTESTED"
		elseif owner == "" then
			stateText = "CAPTURE THE POINT"
		else
			stateText = (owner == myTeam and "HOLD THE POINT" or "TAKE THE POINT BACK")
		end
	elseif s == "RoundEnd" then
		stateText = "ROUND OVER"
	elseif s == "MatchEnd" then
		stateText = "NEXT MATCH IN " .. clock(remaining)
	else
		stateText = "WAITING FOR PLAYERS"
	end
	r.stateText.Text = stateText
	r.stateText.TextColor3 = contested and Color3.fromRGB(255, 200, 80) or WHITE
	local bOn, rOn = st:GetAttribute("BlueOnPoint") or 0, st:GetAttribute("RedOnPoint") or 0
	r.onPoint.Text = s == "InProgress" and string.format('<font color="%s">%d</font>  on point  <font color="%s">%d</font>', hex(teamColor("Blue")), bOn, hex(teamColor("Red")), rOn) or ""

	-- local hero
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local aliveNow = entry and entry:GetAttribute("Alive") and hum and hum.Health > 0
	local hero = entry and Heroes.Get(entry:GetAttribute("Hero") or "")
	r.healthPanel.Visible = aliveNow and hero ~= nil
	r.abilityPanel.Visible = aliveNow and hero ~= nil
	r.crosshair.Visible = aliveNow and not ctx.MenuOpen()
	if aliveNow and hero then
		r.heroName.Text = string.upper(hero.name)
		r.heroRole.Text = string.upper(hero.role)
		r.heroRole.TextColor3 = Config.RoleColors[hero.role]
		local ratio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
		r.hpFill.Size = UDim2.fromScale(ratio, 1)
		r.hpFill.BackgroundColor3 = ratio < 0.3 and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(240, 240, 240)
		r.hpText.Text = string.format("%d / %d", math.ceil(hum.Health), hum.MaxHealth)

		for _, slot in ipairs(Config.Slots) do
			local ui = r.slots[slot]
			local a = hero.abilities[slot]
			ui.name.Text = a.name
			if slot == "Ultimate" then
				local ult = entry:GetAttribute("Ult") or 0
				ui.overlay.Size = UDim2.fromScale(1, 1 - ult / 100)
				ui.big.Text = ult >= 100 and "READY" or string.format("%d%%", math.floor(ult))
				ui.stroke.Color = ult >= 100 and Color3.fromRGB(255, 215, 90) or WHITE
				ui.stroke.Transparency = ult >= 100 and 0 or 0.5
				ui.stroke.Thickness = ult >= 100 and 3 + math.sin(os.clock() * 8) or 2
			elseif slot == "Primary" then
				ui.overlay.Size = UDim2.fromScale(1, 0)
				ui.big.Text = "●"
			else
				local ready = entry:GetAttribute("CD_" .. slot) or 0
				local max = entry:GetAttribute("CDMax_" .. slot) or 1
				local left = ready - now
				if left > 0 then
					ui.overlay.Size = UDim2.fromScale(1, math.clamp(left / max, 0, 1))
					ui.big.Text = left >= 1 and tostring(math.ceil(left)) or string.format("%.1f", left)
					ui.stroke.Transparency = 0.7
				else
					ui.overlay.Size = UDim2.fromScale(1, 0)
					ui.big.Text = "✓"
					ui.stroke.Transparency = 0.2
				end
			end
		end
		r.status.Text = entry:GetAttribute("Stunned") and "STUNNED" or ""
	else
		r.status.Text = ""
	end

	-- death screen
	local showDeath = entry and hero and not aliveNow and (s == "InProgress" or s == "Preparing") and not ctx.MenuOpen()
	r.death.Visible = showDeath == true
	if showDeath then
		local respawnAt = entry:GetAttribute("RespawnAt") or 0
		local killerHero = deathInfo and deathInfo.killerHero and Heroes.Get(deathInfo.killerHero)
		r.deathBy.Text = deathInfo and deathInfo.killer and ("by " .. deathInfo.killer .. (killerHero and (" (" .. killerHero.name .. ")") or "")) or ""
		r.deathTimer.Text = respawnAt > now and ("RESPAWNING IN " .. math.ceil(respawnAt - now)) or "RESPAWNING..."
	end

	-- scoreboard & match end
	local showBoard = scoreboardHeld or s == "MatchEnd"
	r.scoreboard.Visible = showBoard and not ctx.MenuOpen()
	if r.scoreboard.Visible and os.clock() - lastScoreboardRefresh > 0.5 then
		lastScoreboardRefresh = os.clock()
		refreshScoreboard()
	end
	if s == "MatchEnd" then
		local winner = st:GetAttribute("Winner") or ""
		r.matchEnd.Visible = true
		r.matchEnd.Text = winner == myTeam and "VICTORY" or "DEFEAT"
		r.matchEnd.TextColor3 = winner == myTeam and Color3.fromRGB(255, 215, 90) or Color3.fromRGB(255, 80, 80)
		r.sbTitle.Text = string.upper(winner) .. " TEAM WINS THE MATCH"
	else
		r.matchEnd.Visible = false
		r.sbTitle.Text = "SCOREBOARD"
	end
	r.objective.Visible = s ~= "HeroSelect" and s ~= "Waiting"
end

function HUD.Init(context)
	ctx = context
	gui = make("ScreenGui", { Name = "HUD", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1, Parent = player:WaitForChild("PlayerGui") })
	buildCrosshair()
	buildObjective()
	buildHealth()
	buildAbilities()
	buildKillfeed()
	buildAnnounce()
	buildDeath()
	buildScoreboard()
	buildMatchEnd()
	buildHints()
	local lastWarn = 0
	RunService.RenderStepped:Connect(function()
		local ok, err = pcall(update)
		if not ok and os.clock() - lastWarn > 2 then
			lastWarn = os.clock()
			warn("HUD update error:", err)
		end
	end)
end

return HUD
