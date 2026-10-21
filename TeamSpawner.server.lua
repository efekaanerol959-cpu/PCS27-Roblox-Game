-- TeamSpawner: stable R15 rigs with procedural animation and AI
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local cfg = require(ReplicatedStorage.RFC27.Modules.MatchConfig)
local TeamData = require(ReplicatedStorage.RFC27.Modules.TeamData)

local remotes = ReplicatedStorage.RFC27:WaitForChild("Remotes", 15)
local startMatch = remotes:WaitForChild("StartMatch", 15)
local matchFolder = workspace:WaitForChild("RFC27_Match", 10)
local ball = matchFolder:WaitForChild("Ball", 10)
local P = cfg.Player
local Pitch = cfg.Pitch
local SKIN = Color3.fromRGB(224, 186, 148)

local teams = {}

local function clearTeams()
	for _, side in pairs(teams) do
		if side.folder then side.folder:Destroy() end
	end
	teams = {}
end

-- Verified assembly: anchor root, set world CFrames, then joint with object-space C0
local PlayersSvc = game:GetService("Players")

local templateCache = nil
local function getTemplate()
	if templateCache and templateCache.Parent then return templateCache end
	local ok, desc = pcall(function() return PlayersSvc:GetHumanoidDescriptionFromUserId(1) end)
	if not ok or not desc then return nil end
	local ok2, model = pcall(function()
		return PlayersSvc:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok2 or not model then return nil end
	templateCache = model
	model.Parent = game.ServerStorage
	return model
end

local function buildRig(name, baseCF, club, isHome)
	local kit = isHome and club.homeKit or club.awayKit
	local template = getTemplate()
	local model = Instance.new("Model")
	model.Name = name

	local function realPart(partName, fallbackSize, color, offset)
		local p = nil
		if template then
			local t = template:FindFirstChild(partName)
			if t and t:IsA("BasePart") then
				p = t:Clone()
				p:ClearAllChildren()
			end
		end
		if not p then
			p = Instance.new("Part")
			p.Size = fallbackSize
		end
		p.Name = partName
		p.Anchored = false
		-- legs, feet and torso MUST collide or the Humanoid cannot walk
		local collides = (partName == "LeftUpperLeg" or partName == "RightUpperLeg" or partName == "LeftLowerLeg" or partName == "RightLowerLeg" or partName == "LeftFoot" or partName == "RightFoot" or partName == "LowerTorso" or partName == "UpperTorso")
		p.CanCollide = collides
		p.Massless = true
		p.Color = color or Color3.new(1,1,1)
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CFrame = baseCF * offset
		p.Parent = model
		return p
	end

	local SKIN2 = Color3.fromRGB(234, 200, 160)

	local root = realPart("HumanoidRootPart", Vector3.new(2,2,1), Color3.new(1,1,1), CFrame.new())
	root.Transparency = 1
	root.Anchored = true
	root.Massless = true
	model.PrimaryPart = root

	-- create parts at origin first, then position them relative to each other's real sizes
	local lower = realPart("LowerTorso", Vector3.new(2,0.8,1), kit.shorts, CFrame.new())
	local upper = realPart("UpperTorso", Vector3.new(2,1.9,1), kit.shirt, CFrame.new())
	local head  = realPart("Head", Vector3.new(1.2,1.2,1.2), SKIN2, CFrame.new())
	local lua = realPart("LeftUpperArm", Vector3.new(0.9,1.2,0.8), kit.shirt, CFrame.new())
	local rua = realPart("RightUpperArm", Vector3.new(0.9,1.2,0.8), kit.shirt, CFrame.new())
	local lla = realPart("LeftLowerArm", Vector3.new(0.8,1.15,0.9), SKIN2, CFrame.new())
	local rla = realPart("RightLowerArm", Vector3.new(0.8,1.15,0.9), SKIN2, CFrame.new())
	local lh  = realPart("LeftHand", Vector3.new(0.75,0.9,0.77), SKIN2, CFrame.new())
	local rh  = realPart("RightHand", Vector3.new(0.75,0.9,0.77), SKIN2, CFrame.new())
	local lul = realPart("LeftUpperLeg", Vector3.new(0.78,1.74,0.85), kit.shorts, CFrame.new())
	local rul = realPart("RightUpperLeg", Vector3.new(0.78,1.74,0.85), kit.shorts, CFrame.new())
	local lll = realPart("LeftLowerLeg", Vector3.new(0.72,1.26,0.85), kit.socks, CFrame.new())
	local rll = realPart("RightLowerLeg", Vector3.new(0.72,1.26,0.85), kit.socks, CFrame.new())
	local lf  = realPart("LeftFoot", Vector3.new(0.72,0.82,1.24), kit.socks, CFrame.new())
	local rf  = realPart("RightFoot", Vector3.new(0.72,0.82,1.24), kit.socks, CFrame.new())

	-- assemble using real sizes so every joint is flush
	local upperY = 0
	local lowerTop = lower.Size.Y / 2
	local upperBottom = upper.Size.Y / 2
	lower.CFrame = baseCF * CFrame.new(0, 0.9, 0)
	upper.CFrame = lower.CFrame * CFrame.new(0, lowerTop + upperBottom, 0)
	head.CFrame = upper.CFrame * CFrame.new(0, upper.Size.Y / 2 + head.Size.Y / 2, 0)

	local function sideX(dir)
		return dir * (upper.Size.X / 2 + lua.Size.X / 2)
	end
	lua.CFrame = upper.CFrame * CFrame.new(sideX(-1), upper.Size.Y / 2 - lua.Size.Y / 2, 0)
	rua.CFrame = upper.CFrame * CFrame.new(sideX(1), upper.Size.Y / 2 - rua.Size.Y / 2, 0)
	lla.CFrame = lua.CFrame * CFrame.new(0, -(lua.Size.Y / 2 + lla.Size.Y / 2), 0)
	rla.CFrame = rua.CFrame * CFrame.new(0, -(rua.Size.Y / 2 + rla.Size.Y / 2), 0)
	lh.CFrame = lla.CFrame * CFrame.new(0, -(lla.Size.Y / 2 + lh.Size.Y / 2), 0)
	rh.CFrame = rla.CFrame * CFrame.new(0, -(rla.Size.Y / 2 + rh.Size.Y / 2), 0)

	local function legX(dir)
		return dir * (lower.Size.X / 4)
	end
	lul.CFrame = lower.CFrame * CFrame.new(legX(-1), -(lower.Size.Y / 2 + lul.Size.Y / 2), 0)
	rul.CFrame = lower.CFrame * CFrame.new(legX(1), -(lower.Size.Y / 2 + rul.Size.Y / 2), 0)
	lll.CFrame = lul.CFrame * CFrame.new(0, -(lul.Size.Y / 2 + lll.Size.Y / 2), 0)
	rll.CFrame = rul.CFrame * CFrame.new(0, -(rul.Size.Y / 2 + rll.Size.Y / 2), 0)
	lf.CFrame = lll.CFrame * CFrame.new(0, -(lll.Size.Y / 2 + lf.Size.Y / 2), -lf.Size.Z / 4)
	rf.CFrame = rll.CFrame * CFrame.new(0, -(rll.Size.Y / 2 + rf.Size.Y / 2), -rf.Size.Z / 4)

	-- Build a simple face from parts (the rbxasset face decal does not render here).
	local faceColor = Color3.fromRGB(30, 26, 24)
	local function facePart(nm, size, offset)
		local p = Instance.new("Part")
		p.Name = nm
		p.Size = size
		p.Color = faceColor
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = false
		p.CanCollide = false
		p.Massless = true
		p.Transparency = 0
		p.CFrame = head.CFrame * offset
		p.Parent = model
		return p
	end
	local eyeY = head.Size.Y * 0.12
	local eyeX = head.Size.X * 0.22
	local faceZ = -(head.Size.Z / 2 + 0.02)
	local eyeL = facePart("EyeLeft", Vector3.new(head.Size.X * 0.16, head.Size.Y * 0.18, 0.08), CFrame.new(-eyeX, eyeY, faceZ))
	local eyeR = facePart("EyeRight", Vector3.new(head.Size.X * 0.16, head.Size.Y * 0.18, 0.08), CFrame.new(eyeX, eyeY, faceZ))
	local mouth = facePart("Mouth", Vector3.new(head.Size.X * 0.34, head.Size.Y * 0.09, 0.08), CFrame.new(0, -head.Size.Y * 0.18, faceZ))

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = 4.4
	hum.WalkSpeed = P.walkSpeed
	hum.JumpPower = 0
	hum.MaxSlopeAngle = 89
	hum.AutoRotate = true
	hum.Parent = model

	local function joint(a, b)
		local m = Instance.new("Motor6D")
		m.Part0 = a
		m.Part1 = b
		m.C0 = a.CFrame:ToObjectSpace(b.CFrame)
		m.C1 = CFrame.new()
		m.Parent = a
		return m
	end

	local rootMotor = joint(root, lower)
	local rootC0 = rootMotor.C0
	joint(lower, upper)
	local headJoint = joint(upper, head)
	-- keep the face parts rigidly attached to the head
	local function weldToHead(part)
		local w = Instance.new("WeldConstraint")
		w.Part0 = head
		w.Part1 = part
		w.Parent = part
	end
	weldToHead(eyeL)
	weldToHead(eyeR)
	weldToHead(mouth)
	local armL = joint(upper, lua)
	local armR = joint(upper, rua)
	joint(lua, lla)
	joint(rua, rla)
	joint(lla, lh)
	joint(rla, rh)
	local legL = joint(lower, lul)
	local legR = joint(lower, rul)
	joint(lul, lll)
	joint(rul, rll)
	joint(lll, lf)
	joint(rll, rf)

	-- force collision on the legs/feet AFTER everything is built, so the Humanoid
	-- has something to push against and can actually walk.
	for _, partName in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot" }) do
		local p = model:FindFirstChild(partName)
		if p then
			p.CanCollide = true
			p.Massless = false
		end
	end
	local lt = model:FindFirstChild("LowerTorso")
	if lt then lt.CanCollide = true; lt.Massless = false end
	root.Massless = false

	model.Parent = matchFolder
	-- Keep AI rigs ANCHORED: they cannot be driven by Humanoid physics, so the
	-- AI moves them purely with PivotTo. Anchoring stops physics pulling them back.
	root.Anchored = true

	return {
		model = model, hum = hum,
		armL = armL, armR = armR, legL = legL, legR = legR,
		armLC0 = armL.C0, armRC0 = armR.C0, legLC0 = legL.C0, legRC0 = legR.C0,
		phase = math.random() * 6.28, moving = false, kicking = 0,
		rootMotor = rootMotor, rootC0 = rootC0, hasBall = false, action = nil, actionTimer = 0, actionLength = 0,
	}
end

local function applyAnim(entry, dt)
	if not entry or not entry.armL then return end

	-- timers for one-shot actions
	if entry.actionTimer and entry.actionTimer > 0 then
		entry.actionTimer -= dt
	end

	local action = entry.action
	local acting = entry.actionTimer and entry.actionTimer > 0

	-- ---------- run / idle cycle ----------
	local swing
	if entry.moving then
		entry.phase += dt * (entry.sprinting and 13 or 9.5)
		swing = math.sin(entry.phase) * (entry.sprinting and 0.95 or 0.72)
	else
		entry.phase += dt * 2
		swing = math.sin(entry.phase) * 0.05
	end

	local armL, armR = swing * 0.9, -swing * 0.9
	local legL, legR = -swing, swing
	local torsoLean = entry.moving and math.rad(6) or 0
	local bob = entry.moving and math.abs(math.sin(entry.phase)) * 0.06 or 0

	-- ---------- DRIBBLE: lean in, arms out for balance, quick touches ----------
	if entry.hasBall and entry.moving then
		torsoLean = math.rad(11)
		armL = armL * 0.45 - 0.35
		armR = armR * 0.45 + 0.35
		-- quick little toe taps
		local tap = math.sin(entry.phase * 1.6) * 0.18
		legR += tap
		legL -= tap
	end

	-- ---------- SHOOT: backswing then strong follow-through ----------
	if acting and action == "shoot" then
		local progress = 1 - (entry.actionTimer / entry.actionLength)
		if progress < 0.35 then
			-- wind up: plant left leg, right leg back
			local t = progress / 0.35
			legR = -0.9 * t
			legL = 0.15 * t
			armL = 0.7 * t
			armR = -0.5 * t
			torsoLean = math.rad(-8) * t
		else
			-- strike and follow through
			local t = (progress - 0.35) / 0.65
			local kick = math.sin(t * math.pi * 0.9)
			legR = -0.9 + kick * 2.1
			legL = 0.15 - t * 0.2
			armL = 0.7 - t * 0.9
			armR = -0.5 + t * 0.8
			torsoLean = math.rad(-8) + t * math.rad(16)
		end
	end

	-- ---------- PASS: side-foot sweep ----------
	if acting and action == "pass" then
		local progress = 1 - (entry.actionTimer / entry.actionLength)
		local swingP = math.sin(progress * math.pi)
		legR = swingP * 1.15
		legL = -swingP * 0.15
		armL = swingP * 0.5
		armR = -swingP * 0.35
		torsoLean = math.rad(4) * swingP
	end

	-- ---------- TACKLE: lunge ----------
	if acting and action == "tackle" then
		local progress = 1 - (entry.actionTimer / entry.actionLength)
		local t = math.sin(progress * math.pi)
		legL = t * 1.3
		legR = -t * 0.25
		armL = -t * 0.8
		armR = t * 0.6
		torsoLean = math.rad(20) * t
	end

	entry.armL.C0 = entry.armLC0 * CFrame.Angles(armL, 0, 0)
	entry.armR.C0 = entry.armRC0 * CFrame.Angles(armR, 0, 0)
	entry.legL.C0 = entry.legLC0 * CFrame.Angles(legL, 0, 0)
	entry.legR.C0 = entry.legRC0 * CFrame.Angles(legR, 0, 0)

	-- torso lean + subtle bob sell the weight shift
	if entry.rootMotor then
		entry.rootMotor.C0 = entry.rootC0 * CFrame.new(0, bob, 0) * CFrame.Angles(0, 0, 0)
		entry.rootMotor.C1 = CFrame.Angles(torsoLean, 0, 0)
	end
end

local function playAction(entry, action, length)
	if not entry then return end
	entry.action = action
	entry.actionLength = length or 0.45
	entry.actionTimer = length or 0.45
end

local currentTeamSize = 5
local spawnGoalkeeper = false
local aggressiveAI = false
local homeAICount = nil   -- nil = use currentTeamSize
local awayAICount = nil
local goalkeeperSide = "both"

local function spawnTeam(club, side, isHome)
	local folder = Instance.new("Folder")
	folder.Name = side
	folder.Parent = matchFolder
	local list = {}
	local count = currentTeamSize
	if side == "home" and homeAICount ~= nil then count = homeAICount end
	if side == "away" and awayAICount ~= nil then count = awayAICount end
	local xSign = (side == "home") and -1 or 1
	local baseX = xSign * (Pitch.length * 0.38)
	for i = 1, count do
		local row = math.floor((i - 1) / 2)
		local col = (i - 1) % 2
		local z = (row - 1) * 34
		local x = baseX - xSign * col * 26
		local entry = buildRig(side .. "_P" .. i, CFrame.new(x, 6, z), club, isHome)
		entry.model.Parent = folder
		entry.model:SetAttribute("Side", side)
		table.insert(list, entry)
	end

	-- dedicated goalkeeper standing on the goal line (tutorial shooting drill)
	if spawnGoalkeeper and (goalkeeperSide == "both" or goalkeeperSide == side) then
		local goalX = xSign * (Pitch.length / 2 - 6)
		local gk = buildRig(side .. "_GK", CFrame.new(goalX, 6, 0), club, isHome)
		gk.model.Parent = folder
		gk.model:SetAttribute("Side", side)
		gk.model:SetAttribute("Goalkeeper", true)
		table.insert(list, gk)
	end

	return { club = club, folder = folder, players = list, side = side, xSign = xSign }
end

-- The hand-built rigs cannot be driven by Humanoid physics (Humanoid:Move and
-- velocity both do nothing on them), so AI movement drives the model directly.
local AI_SPEED = 16
local function aiMove(entry, dt, targetX, targetZ)
	local root = entry.model:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local dx, dz = targetX - root.Position.X, targetZ - root.Position.Z
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist < 0.8 then return false end
	local step = math.min(AI_SPEED * dt, dist)
	local ux, uz = dx / dist, dz / dist
	local p = entry.model:GetPivot()
	local newPos = Vector3.new(root.Position.X + ux * step, p.Position.Y, root.Position.Z + uz * step)
	entry.model:PivotTo(CFrame.lookAt(newPos, newPos + Vector3.new(ux, 0, uz)))
	return true
end

local function tickAI(dt)
	local ballPos = ball.Position
	-- a requested pass is protected for a moment so it can reach the human player
	local noStealUntil = ball:GetAttribute("NoStealUntil")
	local passProtected = noStealUntil and os.clock() < noStealUntil

	-- If a human player is near the ball, AI holds shape and never crowds or steals
	local humanDribbling = false
	local humanSide = nil
	for _, hp in ipairs(game.Players:GetPlayers()) do
		local hroot = hp.Character and hp.Character:FindFirstChild("HumanoidRootPart")
		if hroot then
			humanSide = hp:GetAttribute("Side") or (hroot.Position.X <= 0 and "home" or "away")
			if (hroot.Position - ballPos).Magnitude < 7 then
				humanDribbling = true
			end
		end
	end

	for _, team in pairs(teams) do
		local closest, closestDist = nil, math.huge
		for _, entry in ipairs(team.players) do
			local root = entry.model:FindFirstChild("HumanoidRootPart")
			if root then
				local d = (root.Position - ballPos).Magnitude
				if d < closestDist then closest, closestDist = entry, d end
			end
		end
		for _, entry in ipairs(team.players) do
			local root = entry.model:FindFirstChild("HumanoidRootPart")
			local hum = entry.hum
			if root and hum and hum.Health > 0 then
				entry.moving = false

				-- Called for the ball (Call Ball button): sprint to it
				local comeUntil = entry.model:GetAttribute("ComeToBall")
				if comeUntil and os.clock() < comeUntil then
					aiMove(entry, dt, ballPos.X, ballPos.Z)
					entry.moving = true
					applyAnim(entry, dt)
					continue
				end

				-- Goalkeeper: stay on the goal line, track the ball sideways, and
				-- rush out / dive to smother a close or goal-bound ball.
				if entry.model:GetAttribute("Goalkeeper") then
					local gkGoalX = team.xSign * (Pitch.length / 2 - 6)
					-- predicted Z: if the ball is heading toward our goal, chase its Z
					local gkZ = math.clamp(ballPos.Z, -Pitch.goalWidth / 2 - 4, Pitch.goalWidth / 2 + 4)
					local toBall = (root.Position - ballPos).Magnitude
					-- if the ball is very close to the goal line and on our side, dive at it
					local ballNearGoal = math.abs(ballPos.X - gkGoalX) < 26 and math.abs(ballPos.Z) < Pitch.goalWidth / 2 + 8
					if ballNearGoal and toBall < 40 then
						-- rush to intercept the ball position
						aiMove(entry, dt, ballPos.X, ballPos.Z)
						entry.moving = true
						playAction(entry, "tackle", 0.35)
						-- if it reaches the ball, smother it away from goal
						if toBall < 5 then
							ball:SetAttribute("Possessed", false)
							ball:SetAttribute("StolenUntil", os.clock() + 0.6)
							local clear = Vector3.new(-team.xSign, 0.4, (math.random() - 0.5) * 1.5).Unit
							ball:ApplyImpulse(clear * 90 * ball.AssemblyMass)
						end
					else
						if math.abs(root.Position.X - gkGoalX) > 2 or math.abs(root.Position.Z - gkZ) > 2 then
							aiMove(entry, dt, gkGoalX, gkZ)
							entry.moving = true
						end
					end
					applyAnim(entry, dt)
					continue
				end

				-- In tutorial mode the opponents actively hunt the ball carrier.
				local huntsPlayer = aggressiveAI and team.side ~= humanSide
				if humanDribbling and team.side == humanSide then
					local anchor = Vector3.new(team.xSign * Pitch.length * 0.22, 0, (root.Position.Z > 0 and 22 or -22))
					local dir = Vector3.new(anchor.X - root.Position.X, 0, anchor.Z - root.Position.Z)
					if dir.Magnitude > 3 then
						aiMove(entry, dt, root.Position.X + dir.Unit.X * 12, root.Position.Z + dir.Unit.Z * 12)
						entry.moving = true
					else
						hum:Move(Vector3.zero, false)
					end
				elseif huntsPlayer then
					-- Tutorial: opponents chase the HUMAN player, not just the ball
					local humanPlr = game.Players:GetPlayers()[1]
					local hroot = humanPlr and humanPlr.Character and humanPlr.Character:FindFirstChild("HumanoidRootPart")
					if hroot then
						local chase = Vector3.new(hroot.Position.X - root.Position.X, 0, hroot.Position.Z - root.Position.Z)
						if chase.Magnitude > 3 then
							aiMove(entry, dt, hroot.Position.X, hroot.Position.Z)
							entry.moving = true
						end
						-- reached the ball? win it off the player
						if (root.Position - ballPos).Magnitude < 4.5 then
							ball:SetAttribute("Possessed", false)
							-- freeze possession so the dribble cannot instantly take it back
							ball:SetAttribute("StolenUntil", os.clock() + 1.1)
							local knock = Vector3.new(root.Position.X - ballPos.X, 0, root.Position.Z - ballPos.Z)
							if knock.Magnitude > 0.1 then
								ball:ApplyImpulse((knock.Unit + Vector3.new(0, 0.2, 0)) * 70 * ball.AssemblyMass)
							end
						end
					end
				elseif entry == closest then
					local dir = Vector3.new(ballPos.X - root.Position.X, 0, ballPos.Z - root.Position.Z)
					if dir.Magnitude > 2.5 then
						aiMove(entry, dt, ballPos.X, ballPos.Z)
						entry.moving = true
						-- ALL modes: an opponent that reaches the ball wins it
						if team.side ~= humanSide and dir.Magnitude < 5 and not passProtected then
							ball:SetAttribute("Possessed", false)
							ball:SetAttribute("StolenUntil", os.clock() + 1.1)
							local knock = Vector3.new(root.Position.X - ballPos.X, 0, root.Position.Z - ballPos.Z)
							if knock.Magnitude > 0.1 then
								ball:ApplyImpulse((knock.Unit + Vector3.new(0, 0.2, 0)) * 70 * ball.AssemblyMass)
							end
						end
					else
						local humanHasBall = false
						for _, hp in ipairs(game.Players:GetPlayers()) do
							local hroot = hp.Character and hp.Character:FindFirstChild("HumanoidRootPart")
							if hroot and (hroot.Position - ballPos).Magnitude < 7 then
								humanHasBall = true
								break
							end
						end
						-- Did a human request this ball? If so an AI on their team should
						-- pass it straight to them rather than shoot or hoof it away.
						local requestedUntil = ball:GetAttribute("RequestedUntil")
						local requestedBy = ball:GetAttribute("RequestedBy")
						local reqHuman = nil
						if requestedUntil and os.clock() < requestedUntil and requestedBy then
							local hp = game.Players:GetPlayerByUserId(requestedBy)
							local hr = hp and hp.Character and hp.Character:FindFirstChild("HumanoidRootPart")
							if hr and team.side == (hp:GetAttribute("Side") or (hr.Position.X <= 0 and "home" or "away")) then
								reqHuman = hr
							end
						end
						if humanHasBall and team.side == humanSide then
							hum:Move(Vector3.zero, false)
						elseif reqHuman then
							-- honour the request: pass straight to the human
							local toHuman = reqHuman.Position - ballPos
							toHuman = Vector3.new(toHuman.X, 0.06, toHuman.Z)
							if toHuman.Magnitude > 0.1 then
								local power = math.clamp(toHuman.Magnitude * 0.5 + 12, 24, 95)
								ball:ApplyImpulse(toHuman.Unit * power * ball.AssemblyMass)
								ball:SetAttribute("NoStealUntil", os.clock() + 1.4)
								playAction(entry, "pass", 0.4)
							end
							ball:SetAttribute("RequestedUntil", 0)
							hum:Move(Vector3.zero, false)
						else
							-- AI decision: pass to a teammate if one is open and closer to goal,
							-- otherwise shoot. This makes the team actually keep possession.
							local goalX = (team.side == "home") and (Pitch.length/2) or -(Pitch.length/2)
							local distToGoal = math.abs(goalX - root.Position.X)

							local passMate, passScore = nil, -1
							for _, mate in ipairs(team.players) do
								if mate ~= entry and not mate.model:GetAttribute("Goalkeeper") then
									local mroot = mate.model:FindFirstChild("HumanoidRootPart")
									if mroot then
										local d = (mroot.Position - root.Position).Magnitude
										local mateGoalDist = math.abs(goalX - mroot.Position.X)
										-- pass is attractive when the mate is close and closer to goal
										local score = (d < 90) and (d * -0.3 + (distToGoal - mateGoalDist) * 1.4) or -999
										if score > passScore then passMate, passScore = mroot, score end
									end
								end
							end

							local shouldPass = passMate and distToGoal > 70 and passScore > 5
							if shouldPass then
								local toMate = passMate.Position - ballPos
								toMate = Vector3.new(toMate.X, 0.06, toMate.Z).Unit
								ball:ApplyImpulse(toMate * 70 * ball.AssemblyMass)
								playAction(entry, "pass", 0.4)
							else
								local target = Vector3.new(goalX, 6, (math.random() - 0.5) * Pitch.goalWidth * 0.6)
								local kickDir = (target - ballPos).Unit
								ball:ApplyImpulse(kickDir * 85 * ball.AssemblyMass)
								playAction(entry, "shoot", 0.5)
							end
							ball.AssemblyAngularVelocity = Vector3.zero
							hum:Move(Vector3.zero, false)
						end
					end
				else
					local anchor = Vector3.new(team.xSign * Pitch.length * 0.22, 0, (root.Position.Z > 0 and 22 or -22))
					local dir = Vector3.new(anchor.X - root.Position.X, 0, anchor.Z - root.Position.Z)
					if dir.Magnitude > 12 then
						aiMove(entry, dt, root.Position.X + dir.Unit.X * 12, root.Position.Z + dir.Unit.Z * 12)
						entry.moving = true
					end
				end
				applyAnim(entry, dt)
			end
		end
	end
end

startMatch.OnServerEvent:Connect(function(player, format, homeId, awayId)
	task.wait(0.2)
	clearTeams()
	local fmt = cfg.Formats[format] or cfg.Formats.quick
	currentTeamSize = fmt.teamSize or 5
	spawnGoalkeeper = fmt.spawnGoalkeeper == true
	aggressiveAI = fmt.aggressiveAI == true
	homeAICount = fmt.homeAICount
	awayAICount = fmt.awayAICount
	goalkeeperSide = fmt.goalkeeperSide or "both"
	local homeClub = TeamData.Get(homeId)
	local awayClub = TeamData.Get(awayId)
	if not homeClub or not awayClub then return end
	teams.home = spawnTeam(homeClub, "home", true)
	teams.away = spawnTeam(awayClub, "away", false)
end)

-- Tutorial: hand the ball to the goalkeeper so the player has someone to tackle.
local tutorialRemote = game.ReplicatedStorage.RFC27.Remotes:FindFirstChild("TutorialOpponent")
if not tutorialRemote then
	tutorialRemote = Instance.new("RemoteEvent")
	tutorialRemote.Name = "TutorialOpponent"
	tutorialRemote.Parent = game.ReplicatedStorage.RFC27.Remotes
end

tutorialRemote.OnServerEvent:Connect(function(player)
	if not teams.away then return end
	-- find the goalkeeper rig
	local gk = nil
	for _, entry in ipairs(teams.away.players) do
		if entry.model:GetAttribute("Goalkeeper") then gk = entry break end
	end
	if not gk then return end
	local gkRoot = gk.model:FindFirstChild("HumanoidRootPart")
	local pRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (gkRoot and pRoot) then return end
	-- bring the keeper out in front of the player and give it the ball
	local ahead = pRoot.CFrame.LookVector
	local flat = Vector3.new(ahead.X, 0, ahead.Z)
	if flat.Magnitude < 0.01 then flat = Vector3.new(1,0,0) end
	flat = flat.Unit
	local spot = pRoot.Position + flat * 14
	gk.model:PivotTo(CFrame.new(spot.X, pRoot.Position.Y, spot.Z))
	ball.CFrame = CFrame.new(spot.X, cfg.Ball.radius + 1, spot.Z)
	ball.AssemblyLinearVelocity = Vector3.zero
	ball:SetAttribute("Possessed", false)
	ball:SetAttribute("StolenUntil", os.clock() + 999)  -- AI keeps it until tackled
end)

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	if not teams.home or not teams.away then return end
	acc += dt
	if acc < 0.05 then return end
	tickAI(acc)
	acc = 0
end)

return "TeamSpawner started"
