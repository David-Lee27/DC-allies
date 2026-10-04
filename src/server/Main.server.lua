-- Server entry point.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Config = require(ReplicatedStorage.Shared.Config)
local MapBuilder = require(script.Parent.MapBuilder)
local Combatants = require(script.Parent.Combatants)
local Combat = require(script.Parent.Combat)
local Match = require(script.Parent.Match)

Players.CharacterAutoLoads = false
Players.RespawnTime = 1e6
game:GetService("StarterPlayer").EnableMouseLockOption = false -- Shift is an ability key

-- Teams (for the player list / spawn locations)
for _, info in pairs(Config.Teams) do
	local team = Teams:FindFirstChild(info.Name) or Instance.new("Team")
	team.Name = info.Name
	team.TeamColor = info.BrickColor
	team.AutoAssignable = false
	team.Parent = Teams
end

-- Remotes
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in ipairs({ "UseAbility", "PickHero", "FX", "Notify" }) do
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
end
remotes.Parent = ReplicatedStorage

MapBuilder.Build()
Combatants.Init()
Combat.Init(remotes)
Match.Start(remotes)

print(Config.GameTitle .. " server started")
