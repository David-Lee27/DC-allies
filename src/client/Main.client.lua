-- Client entry point: wires remotes to UI, effects and controls.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local State = ReplicatedStorage:WaitForChild("MatchState")
local Roster = ReplicatedStorage:WaitForChild("Roster")

local Effects = require(script.Parent.Effects)
local HUD = require(script.Parent.HUD)
local HeroSelect = require(script.Parent.HeroSelect)
local Controls = require(script.Parent.Controls)
local Nameplates = require(script.Parent.Nameplates)

for _, coreType in ipairs({ Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Health, Enum.CoreGuiType.Backpack }) do
	pcall(function()
		StarterGui:SetCoreGuiEnabled(coreType, false)
	end)
end

local ctx = {
	Remotes = Remotes,
	State = State,
	Roster = Roster,
}

function ctx.MyEntry()
	return Roster:FindFirstChild(tostring(player.UserId))
end

function ctx.MenuOpen()
	return HeroSelect.IsOpen()
end

function ctx.ToggleHeroSelect()
	HeroSelect.Toggle()
end

function ctx.ShowScoreboard(show)
	HUD.ShowScoreboard(show)
end

Effects.Init(ctx)
HUD.Init(ctx)
HeroSelect.Init(ctx)
Controls.Init(ctx)
Nameplates.Init(ctx)

Remotes.FX.OnClientEvent:Connect(function(kind, data)
	Effects.Handle(kind, data)
end)

Remotes.Notify.OnClientEvent:Connect(function(kind, data)
	if kind == "hit" then
		Effects.DamageNumber(data.pos, data.amount, data.heal, data.kill)
		if not data.heal then
			HUD.HitMarker(data.kill)
		end
	elseif kind == "hurt" then
		HUD.Hurt()
	elseif kind == "killfeed" then
		HUD.KillFeed(data)
	elseif kind == "announce" then
		HUD.Announce(data)
	elseif kind == "announceSmall" then
		HUD.AnnounceSmall(data.text)
	elseif kind == "death" then
		HUD.ShowDeath(data)
	elseif kind == "ultimate" then
		HUD.UltCast(data)
	elseif kind == "pickResult" then
		HeroSelect.OnPickResult(data)
	elseif kind == "openSelect" then
		HeroSelect.Open(data and data.force)
	elseif kind == "matchEnd" then
		HUD.Announce({ text = string.upper(data.winner) .. " TEAM WINS!", color = Color3.fromRGB(255, 215, 90) })
	end
end)
