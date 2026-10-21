-- BallController: server-authoritative ball physics for RFC 27
local RunService = game:GetService("RunService")
local cfg = require(game.ReplicatedStorage.RFC27.Modules.MatchConfig)

local B = cfg.Ball
local matchFolder = workspace:WaitForChild("RFC27_Match", 10)
if not matchFolder then return end
local ball = matchFolder:WaitForChild("Ball", 10)
-- Real football mass. Without this the ball is density 1.6 -> mass ~14.7,
-- far too heavy, which makes kicks barely move it.
ball.CustomPhysicalProperties = PhysicalProperties.new(0.18, 0.35, 0.6, 1, 1)
if not ball then return end

local HEARTBEAT = 1 / 120
local accum = 0
local gravity = Vector3.new(0, -cfg.Physics.gravity * 0.85 * cfg.Physics.ballGravityScale, 0)

local function step(dt)
	-- while a player has the ball, PlayerController owns its position - do not fight it
	if ball:GetAttribute("Possessed") then
		return
	end
	local v = ball.AssemblyLinearVelocity
	-- air drag (quadratic, capped). Stronger so shots visibly decelerate.
	local speed = v.Magnitude
	if speed > 0.01 then
		local dragForce = -v.Unit * math.min(B.drag * speed * speed, speed * 6)
		ball:ApplyImpulse(dragForce * ball.AssemblyMass * dt)
	end
	-- extra gravity for a snappier, football-like arc
	ball:ApplyImpulse(gravity * ball.AssemblyMass * dt)

	-- rolling resistance when on the ground (stronger so the ball settles)
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = { ball }
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(ball.Position, Vector3.new(0, -(B.radius + 0.6), 0), rayParams)
	if result then
		local hv = Vector3.new(v.X, 0, v.Z)
		if hv.Magnitude > 0.1 then
			local resist = -hv.Unit * math.min(B.friction * 8 + hv.Magnitude * 0.5, hv.Magnitude / math.max(dt, 1e-4) * 0.25)
			ball:ApplyImpulse(resist * ball.AssemblyMass * dt)
		end
	end

	-- clamp max speed
	local sp = ball.AssemblyLinearVelocity
	if sp.Magnitude > B.maxSpeed then
		ball.AssemblyLinearVelocity = sp.Unit * B.maxSpeed
	end
end

-- Safety net: if the ball ever leaves the PITCH, put it back near the centre
-- with zero velocity so it can never sail off the map.
RunService.Heartbeat:Connect(function(dt)
	if not ball or not ball.Parent then return end
	local p = ball.Position
	if math.abs(p.X) > 200 or math.abs(p.Z) > 140 or p.Y < -15 then
		ball.AssemblyLinearVelocity = Vector3.zero
		ball.AssemblyAngularVelocity = Vector3.zero
		ball.CFrame = CFrame.new(0, B.radius + 2, 0)
		ball:SetAttribute("Possessed", false)
		ball:SetAttribute("BallFrozen", os.clock() + 0.6)
	end
end)

RunService.Heartbeat:Connect(function(dt)
	accum += dt
	local steps = 0
	while accum >= HEARTBEAT and steps < 8 do
		step(HEARTBEAT)
		accum -= HEARTBEAT
		steps += 1
	end
	if steps >= 8 then accum = 0 end
end)

-- Public API on the server for kicks
local kickEvent = Instance.new("BindableEvent")
kickEvent.Name = "BallKick"
kickEvent.Parent = script
kickEvent.Event:Connect(function(direction, power, spin)
	if typeof(direction) ~= "Vector3" then return end
	direction = direction.Unit
	local impulse = direction * math.clamp(power, 0, B.maxSpeed) * ball.AssemblyMass
	ball:ApplyImpulse(impulse)
	if typeof(spin) == "Vector3" then
		ball.AssemblyAngularVelocity = spin
	end
end)

return "BallController started"
