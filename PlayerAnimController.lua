-- PlayerAnimController: plays real skeletal animations on the human player
-- when they shoot, pass or dribble. Uses AnimationKit's runtime-registered clips.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local kit = require(ReplicatedStorage.RFC27.Modules.AnimationKit)
local ProceduralAnim = require(ReplicatedStorage.RFC27.Modules.ProceduralAnim)
local remotes = ReplicatedStorage.RFC27:WaitForChild("Remotes", 30)
local kickRemote = remotes:WaitForChild("Kick", 30)

local dribbleTracks = {}

local function getAnimator(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	return animator
end

-- Load a FRESH track each time: caching broke after respawn (old animator).
local function play(plr, kind)
	local char = plr.Character
	if not char then return end
	local animator = getAnimator(char)
	if not animator then return end
	local id = kit.Get(kind)
	if not id then return end

	if kind == "dribble" then
		local existing = dribbleTracks[plr]
		if existing and existing.IsPlaying then return end
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, track = pcall(function() return animator:LoadAnimation(a) end)
		if ok and track then
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			track:Play(0.15)
			dribbleTracks[plr] = track
		end
		return
	end

	local a = Instance.new("Animation")
	a.AnimationId = id
	local ok, track = pcall(function() return animator:LoadAnimation(a) end)
	if ok and track then
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = false
		track:Play(0.05)
	end
end

-- This rig uses AnimationConstraint joints, which animation tracks do NOT drive.
-- Worse, the Animator OVERWRITES AnimationConstraint.Transform to identity every
-- frame even with zero tracks playing, so a procedural write is erased instantly.
-- Detaching the Animator lets the procedural write stick (verified: 73 deg leg swing).
local procBusy = {}
local function runProcedural(plr, kind)
	if procBusy[plr] then return true end
	local char = plr.Character
	if not char then return false end
	local joints = ProceduralAnim.GetJoints(char)
	if not (joints and joints.RightHip) then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	procBusy[plr] = true
	task.spawn(function()
		local savedParent = animator and animator.Parent
		if animator then animator.Parent = nil end
		local ok, err = pcall(function()
			if kind == "shot" then
				ProceduralAnim.Kick(char)
			else
				ProceduralAnim.Pass(char)
			end
		end)
		if animator and savedParent then animator.Parent = savedParent end
		procBusy[plr] = nil
		if not ok then warn("ProceduralAnim failed: "..tostring(err)) end
	end)
	return true
end

kickRemote.OnServerEvent:Connect(function(plr, kind, direction, power)
	-- The CLIENT that owns this character runs the procedural swing itself (its
	-- Animator is authoritative there). Touching the same rig from the server only
	-- recreates Animators that reset AnimationConstraint.Transform mid-swing, which
	-- is what cut the visible kick short. So the server stays OUT of the firing
	-- player's own animation entirely; the client path (MatchInput/HUDController
	-- localKick) is what actually moves the leg.
	return
end)

-- start the dribble loop while the player is actually moving with the ball
local RunService = game:GetService("RunService")
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.15 then return end
	acc = 0
	local matchRunning = ReplicatedStorage:GetAttribute("MatchRunning") == true
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if not char then continue end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local mf = workspace:FindFirstChild("RFC27_Match")
		local ball = mf and mf:FindFirstChild("Ball")
		local root = char:FindFirstChild("HumanoidRootPart")
		local shouldDribble = false
		if matchRunning and hum and ball and root then
			shouldDribble = hum.MoveDirection.Magnitude > 0.1 and (ball.Position - root.Position).Magnitude < 8
		end
		if shouldDribble then
			play(plr, "dribble")
		else
			local dt2 = dribbleTracks[plr]
			if dt2 and dt2.IsPlaying then dt2:Stop(0.15) end
		end
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	dribbleTracks[plr] = nil
	procBusy[plr] = nil
end)

return "PlayerAnimController ready"
