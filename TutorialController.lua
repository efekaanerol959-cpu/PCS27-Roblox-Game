-- TutorialController: 4-step interactive tutorial driving the HUD StepHeader
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui", 15)
local screens = pg:WaitForChild("RFC27", 15):WaitForChild("Screens", 15)
local hud = screens:WaitForChild("MatchHUD", 20)

local Theme = require(ReplicatedStorage.RFC27.UIConfig.Theme)
local C = Theme.Colors
local remotes = ReplicatedStorage.RFC27:WaitForChild("Remotes", 20)
local kickEvent = remotes:WaitForChild("Kick", 25)

local stepFrame = hud:WaitForChild("StepHeader", 30)
local scoreboard = hud:FindFirstChild("Scoreboard")
local clockStrip = hud:FindFirstChild("ClockStrip")
local stepTitle = stepFrame:WaitForChild("StepTitle", 10)
local stepBody = stepFrame:WaitForChild("StepBody", 10)
local stepCount = stepFrame:WaitForChild("StepCount", 10)
local countLabel = stepFrame:WaitForChild("CountLabel", 10)
local chips = stepFrame:WaitForChild("Chips", 10)
local pips = stepFrame:WaitForChild("Pips", 10)
local skipBtn = stepFrame:WaitForChild("Skip", 10)

local STEPS = {
	{
		title = "STEP 1 OF 4 · MOVE & SPRINT",
		body = "Run with the ball onto the three glowing markers.",
		countLabel = "MARKERS",
		goal = 3,
		chips = { { key = "W A S D", label = "Move" }, { key = "SHIFT", label = "Sprint" } },
		check = "move",
	},
	{
		title = "STEP 2 OF 4 · SHORT PASSING",
		body = "Point toward a teammate and pass the ball. Make 3 passes.",
		countLabel = "PASSES",
		goal = 3,
		chips = { { key = "AIM", label = "Aim with camera" }, { key = "PASS", label = "Pass" } },
		check = "pass",
	},
	{
		title = "STEP 3 OF 4 · SHOOTING",
		body = "Aim at a corner and shoot. Score 2 goals.",
		countLabel = "GOALS",
		goal = 2,
		chips = { { key = "SHOOT", label = "Shoot" } },
		check = "shot",
	},
	{
		title = "STEP 4 OF 4 · TACKLING",
		body = "Win the ball back from an opponent with a tackle.",
		countLabel = "TACKLES",
		goal = 1,
		chips = { { key = "E", label = "Tackle" } },
		check = "tackle",
	},
}

local current = 1
local progress = 0
local running = false
local moveAccum = 0
local markers = {}
local markersHit = {}

local function clearChips()
	for _, c in ipairs(chips:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
end

local function addChip(key, label)
	local chip = Instance.new("Frame")
	chip.Size = UDim2.new(0, 0, 0, 24)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.BackgroundColor3 = Color3.fromRGB(30, 36, 48)
	chip.BorderSizePixel = 0
	chip.Parent = chips
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 4)
	cc.Parent = chip
	local k = Instance.new("TextLabel")
	k.Size = UDim2.new(0, 0, 1, 0)
	k.AutomaticSize = Enum.AutomaticSize.X
	k.Position = UDim2.new(0, 8, 0, 0)
	k.BackgroundTransparency = 1
	k.Font = Theme.Fonts.headline
	k.Text = key
	k.TextSize = 11
	k.TextColor3 = C.text
	k.Parent = chip
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(0, 0, 1, 0)
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Position = UDim2.new(0, 0, 0, 0)
	l.AnchorPoint = Vector2.new(1, 0)
	l.BackgroundTransparency = 1
	l.Font = Theme.Fonts.body
	l.Text = "  " .. label .. "  "
	l.TextSize = 11
	l.TextColor3 = C.textMuted
	l.Parent = chip
end

local function updatePips()
	local idx = 1
	for _, pip in ipairs(pips:GetChildren()) do
		if pip:IsA("Frame") then
			pip.BackgroundColor3 = (idx <= current) and C.accent or Color3.fromRGB(40, 48, 62)
			idx += 1
		end
	end
end

local opponentRemote = remotes:FindFirstChild("TutorialOpponent")

local function renderStep()
	local s = STEPS[current]
	if not s then return end
	-- the tackling drill needs an opponent holding the ball
	if s.check == "tackle" and opponentRemote then
		opponentRemote:FireServer()
	end
	stepTitle.Text = s.title
	stepBody.Text = s.body
	countLabel.Text = s.countLabel
	progress = 0
	stepCount.Text = "0/" .. s.goal
	clearChips()
	for _, c in ipairs(s.chips) do addChip(c.key, c.label) end
	updatePips()
end

-- ===== glowing pitch markers =====
local function clearMarkers()
	for _, m in ipairs(markers) do
		if m and m.Parent then m:Destroy() end
	end
	markers = {}
	markersHit = {}
end

local function spawnMarkers(count)
	clearMarkers()
	local matchFolder = workspace:FindFirstChild("RFC27_Match")
	if not matchFolder then return end
	local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not playerRoot then return end
	local basePos = playerRoot.Position
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local pos = basePos + Vector3.new(math.cos(angle) * 40, 0, math.sin(angle) * 40)
		local marker = Instance.new("Part")
		marker.Name = "TutorialMarker" .. i
		marker.Shape = Enum.PartType.Cylinder
		marker.Size = Vector3.new(1, 20, 20)
		marker.CFrame = CFrame.new(pos.X, 0.8, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
		marker.Anchored = true
		marker.CanCollide = false
		marker.Material = Enum.Material.Neon
		marker.Color = C.accent
		marker.Transparency = 0.35
		marker.Parent = matchFolder
		markers[i] = marker
	end
end

-- ===== step completion =====
local function advanceProgress()
	if not running then return end
	progress += 1
	local s = STEPS[current]
	stepCount.Text = progress .. "/" .. s.goal
	if progress >= s.goal then
		task.wait(0.35)
		current += 1
		if current > #STEPS then
			finishTutorial()
		else
			renderStep()
			if STEPS[current].check == "move" then spawnMarkers(STEPS[current].goal) else clearMarkers() end
		end
	end
end

function finishTutorial()	-- unlock the rest of the modes
	pcall(function()
		player:SetAttribute("TutorialCompleted", true)
	end)
	running = false
	stepFrame.Visible = false
	if scoreboard then scoreboard.Visible = true end
	if clockStrip then clockStrip.Visible = true end
	clearMarkers()
end

skipBtn.MouseButton1Click:Connect(finishTutorial)

-- ===== start =====
local function startTutorial()
	current = 1
	running = true
	renderStep()
	stepFrame.Visible = true
	-- the tutorial banner replaces the scoreboard while it is running
	if scoreboard then scoreboard.Visible = false end
	if clockStrip then clockStrip.Visible = false end
	spawnMarkers(STEPS[1].goal)
end

-- hook kick / tackle events to progress the right steps


-- progress driven by real actions
local lastKick = 0
UserInputService.InputEnded:Connect(function(input, processed)
	if not running then return end
	-- (no `processed` guard: the on-screen PASS/SHOOT buttons count)
	-- NOTE: do NOT bail on `processed` here. Clicking the on-screen PASS/SHOOT
	-- button counts as processed input, which previously blocked tutorial progress.
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local s = STEPS[current]
		if s and (s.check == "pass" or s.check == "shot") then
			local now = os.clock()
			if now - lastKick > 0.4 then
				lastKick = now
				advanceProgress()
			end
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if not running then return end
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.F then
		if STEPS[current] and STEPS[current].check == "tackle" then
			advanceProgress()
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	if not running then return end
	local s = STEPS[current]
	if not s then return end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")

	if s.check == "move" then
		if hum and hum.MoveDirection.Magnitude > 0.1 then
			moveAccum += dt
		end
		-- check marker hits
		if root then
			for i, m in ipairs(markers) do
				if m and m.Parent and not markersHit[i] then
					local d = Vector3.new(root.Position.X - m.Position.X, 0, root.Position.Z - m.Position.Z).Magnitude
					if d < 9 then
						markersHit[i] = true
						m.Color = Color3.fromRGB(255, 255, 255)
						task.delay(0.15, function() if m then m:Destroy() end end)
						advanceProgress()
					end
				end
			end
		end
	end
end)

-- expose start via BindableEvent in the HUD
local starter = hud:FindFirstChild("StartTutorial")
if not starter then
	starter = Instance.new("BindableEvent")
	starter.Name = "StartTutorial"
	starter.Parent = hud
end
starter.Event:Connect(startTutorial)

return "TutorialController ready"
