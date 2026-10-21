local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer-- MatchInput: playable third-person football controls + camera

local camera = workspace.CurrentCamera
local cfg = require(game.ReplicatedStorage.RFC27.Modules.MatchConfig)
local Theme = require(game.ReplicatedStorage.RFC27.UIConfig.Theme)
local remotes = game.ReplicatedStorage.RFC27.Remotes
local kickEvent = remotes:WaitForChild("Kick", 20)
local sprintEvent = remotes:WaitForChild("SetSprint", 20)
local tackleEvent = remotes:WaitForChild("Tackle", 20)
local skillEvent = remotes:WaitForChild("SkillMove", 20)
local facingEvent = remotes:WaitForChild("SetFacing", 20)
local ProceduralAnim = require(game.ReplicatedStorage.RFC27.Modules.ProceduralAnim)

-- Local rig uses AnimationConstraint joints that tracks do NOT drive, and the
-- client Animator resets Transform every frame. Detach it and drive procedurally.
-- Server-side writes do NOT reach this client, so the swing MUST run here.
local kickBusy = false
local function localKick(kind)
	if kickBusy then return end
	local char = player.Character
	if not char then return end
	local joints = ProceduralAnim.GetJoints(char)
	if not (joints and joints.RightHip) then return end
	kickBusy = true
	task.spawn(function()
		local ok, err = pcall(function()
			if kind == "shot" then ProceduralAnim.Kick(char) else ProceduralAnim.Pass(char) end
		end)
		kickBusy = false
		if not ok then warn("localKick failed: "..tostring(err)) end
	end)
end

local P = cfg.Player
local C = cfg.Camera

local aimKind = "pass"
local charging = false
local chargeStart = 0
local lastPower = 0

-- ---------- power meter UI ----------
local pg = player:WaitForChild("PlayerGui", 10)
local powerGui = Instance.new("ScreenGui")
powerGui.Name = "PowerMeter"
powerGui.ResetOnSpawn = false
powerGui.IgnoreGuiInset = true
powerGui.DisplayOrder = 25
powerGui.Enabled = false
powerGui.Parent = pg

local meterBg = Instance.new("Frame")
meterBg.Size = UDim2.new(0, 260, 0, 16)
meterBg.Position = UDim2.new(0.5, -130, 1, -110)
meterBg.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
meterBg.BorderSizePixel = 0
meterBg.Parent = powerGui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = meterBg

local meterFill = Instance.new("Frame")
meterFill.Size = UDim2.new(0, 0, 1, 0)
meterFill.BackgroundColor3 = Theme.Colors.accent
meterFill.BorderSizePixel = 0
meterFill.Parent = meterBg
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 8)
fillCorner.Parent = meterFill

local kindLabel = Instance.new("TextLabel")
kindLabel.Size = UDim2.new(0, 260, 0, 24)
kindLabel.Position = UDim2.new(0.5, -130, 1, -136)
kindLabel.BackgroundTransparency = 1
kindLabel.Font = Theme.Fonts.headline
kindLabel.TextSize = 16
kindLabel.TextColor3 = Theme.Colors.text
kindLabel.Text = "PASS"
kindLabel.Parent = powerGui

-- ---------- helpers ----------
local function getRoot()
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

local function getHum()
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChildOfClass("Humanoid")
end

local function aimDirection()
	local root = getRoot()
	if not root then return Vector3.new(0, 0, -1) end
	-- AIM = the direction the PLAYER is facing. With the side-on broadcast camera
	-- the camera's own look vector points across the pitch, which is useless for
	-- aiming, so the player's body direction is the control the user actually has.
	local lv = root.CFrame.LookVector
	local flat = Vector3.new(lv.X, 0, lv.Z)
	if flat.Magnitude < 0.01 then return Vector3.new(0, 0, -1) end
	return flat.Unit
end

local function setKindLabel()
	local names = { pass = "PASS", shot = "SHOOT", cross = "CROSS", through = "THROUGH BALL" }
	kindLabel.Text = names[aimKind] or "KICK"
end

-- ---------- kicking ----------
local function onKickAction(actionName, inputState, inputObject)
	if actionName ~= "RFCKick" then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then
		charging = true
		chargeStart = os.clock()
		powerGui.Enabled = true
		setKindLabel()
		return Enum.ContextActionResult.Sink
	elseif inputState == Enum.UserInputState.End then
		if charging then
			local held = os.clock() - chargeStart
			local power = math.clamp(held / 1.0, 0.15, 1)
			lastPower = power
			localKick(aimKind)
			kickEvent:FireServer(aimKind, aimDirection(), power)
		end
		charging = false
		powerGui.Enabled = false
		meterFill.Size = UDim2.new(0, 0, 1, 0)
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction("RFCKick", onKickAction, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)

-- charge meter + colour update
RunService.RenderStepped:Connect(function()
	if charging then
		local held = os.clock() - chargeStart
		local power = math.clamp(held / 1.0, 0, 1)
		meterFill.Size = UDim2.new(power, 0, 1, 0)
		if power < 0.4 then
			meterFill.BackgroundColor3 = Theme.Colors.accent
		elseif power < 0.75 then
			meterFill.BackgroundColor3 = Theme.Colors.warning
		else
			meterFill.BackgroundColor3 = Theme.Colors.danger
		end
	end
end)

-- ---------- kick type + sprint ----------
local kinds = {
	[Enum.KeyCode.One] = "pass",
	[Enum.KeyCode.Two] = "shot",
	[Enum.KeyCode.Three] = "cross",
	[Enum.KeyCode.Four] = "through",
}

local sprinting = false
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	local k = kinds[input.KeyCode]
	if k then aimKind = k; setKindLabel() end
	if input.KeyCode == Enum.KeyCode.LeftShift and not sprinting then
		sprinting = true
		if sprintEvent then sprintEvent:FireServer(true) end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift and sprinting then
		sprinting = false
		if sprintEvent then sprintEvent:FireServer(false) end
	end
end)

-- Tackle and skill moves via ContextActionService (reliable, not blocked by GUI focus)
local function onTackleAction(name, state)
	if state == Enum.UserInputState.Begin then
		if tackleEvent then tackleEvent:FireServer() end
	end
	return Enum.ContextActionResult.Sink
end
local function onSkillAction(name, state)
	if state == Enum.UserInputState.Begin then
		local map = { SkillStepover = "stepover", SkillRoulette = "roulette", SkillNutmeg = "nutmeg" }
		if skillEvent then skillEvent:FireServer(map[name] or "stepover") end
	end
	return Enum.ContextActionResult.Sink
end

-- Keyboard bindings (primary)
ContextActionService:BindAction("Tackle", onTackleAction, false, Enum.KeyCode.E, Enum.KeyCode.F)
ContextActionService:BindAction("SkillStepover", onSkillAction, false, Enum.KeyCode.Q)
ContextActionService:BindAction("SkillRoulette", onSkillAction, false, Enum.KeyCode.R)
ContextActionService:BindAction("SkillNutmeg", onSkillAction, false, Enum.KeyCode.C)

-- Also bind to UserInputService as a fallback so input is never swallowed by GUI focus
UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.F then
			if tackleEvent then tackleEvent:FireServer() end
		elseif input.KeyCode == Enum.KeyCode.Q then
			if skillEvent then skillEvent:FireServer("stepover") end
		elseif input.KeyCode == Enum.KeyCode.R then
			if skillEvent then skillEvent:FireServer("roulette") end
		elseif input.KeyCode == Enum.KeyCode.C then
			if skillEvent then skillEvent:FireServer("nutmeg") end
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		-- right-click also triggers a skill for mouse-only players
		if skillEvent then skillEvent:FireServer("stepover") end
	end
end)

-- ---------- report facing + movement to server ----------
local facingAccum = 0
RunService.Heartbeat:Connect(function(dt)
	facingAccum += dt
	if facingAccum < 0.06 then return end
	facingAccum = 0

	local root = getRoot()
	local hum = getHum()
	if not root then return end

	-- facing = where the camera is looking, flattened (this is where the player aims)
	local look = camera.CFrame.LookVector
	-- FACING MUST BE THE PLAYER'S MOVEMENT DIRECTION, not the camera.
	-- With the side-on broadcast camera the look vector points at the touchline,
	-- which put the ball beside the player and made them walk into it.
	local flat
	local moving = false
	if hum and hum.MoveDirection.Magnitude > 0.1 then
		flat = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z).Unit
		moving = true
	else
		-- standing still: keep using the body's own facing
		local cf = root.CFrame.LookVector
		flat = Vector3.new(cf.X, 0, cf.Z)
		if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
		flat = flat.Unit
	end

	if facingEvent then
		facingEvent:FireServer(flat, moving)
	end
end)

-- ---------- third-person follow camera ----------
local CAM_HEIGHT = 26      -- broadcast angle, pulled back to show the goal
local CAM_SIDE = 82        -- distance out from the touchline
local CAM_LOOK_AHEAD = 0   -- straight across, no lead
local CAM_SENS = 0.0       -- no manual rotation: the camera always faces the pitch
local smoothing = 0.18

local camYaw = 0
local currentPos = nil

local matchActive = false
task.spawn(function()
	local hud = pg:WaitForChild("RFC27", 20):WaitForChild("Screens", 20):WaitForChild("MatchHUD", 30)
	while true do
		task.wait(0.5)
		matchActive = hud.Enabled
		if matchActive then
			if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
				UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			end
			if UserInputService.MouseIconEnabled then
				UserInputService.MouseIconEnabled = false
			end
		else
			if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end
			if not UserInputService.MouseIconEnabled then
				UserInputService.MouseIconEnabled = true
			end
		end
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not matchActive then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		camYaw -= input.Delta.X * CAM_SENS
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if not matchActive then
		if camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Custom
		end
		return
	end
	local root = getRoot()
	if not root then return end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	local desired = Vector3.new(root.Position.X, CAM_HEIGHT, CAM_SIDE)
	local focus = Vector3.new(root.Position.X, 4, 0)

	local a = math.clamp(dt / smoothing, 0, 1)
	if currentPos then
		currentPos = currentPos:Lerp(desired, a)
	else
		currentPos = desired
	end
	camera.CFrame = CFrame.lookAt(currentPos, focus)
end)

player.CharacterAdded:Connect(function()
	currentPos = nil
end)

return "MatchInput (playable) started"
