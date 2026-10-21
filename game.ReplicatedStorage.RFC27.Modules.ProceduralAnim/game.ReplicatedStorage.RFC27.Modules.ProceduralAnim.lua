-- ProceduralAnim: drives R15 rigs that use AnimationConstraint joints.
-- VERIFIED FACTS about this project's rigs:
--   * Animation TRACKS do not move AnimationConstraint joints (the track reports
--     weight 1 but the rig stays still). Setting constraint.Transform DOES work.
--   * SHOULDER / ELBOW constraints only respond on X and Y. Z rotation is
--     IGNORED - that is why earlier 'arm spread' animations did nothing.
--   * HIP / KNEE respond on X (forward/back swing).
local ProceduralAnim = {}

local function collectJoints(rig)
	local m = {}
	for _, d in ipairs(rig:GetDescendants()) do
		if d.ClassName == "AnimationConstraint" then m[d.Name] = d end
	end
	return m
end

function ProceduralAnim.GetJoints(rig)
	return collectJoints(rig)
end

-- The default Animate script (re)creates an Animator, and the Animator resets every
-- AnimationConstraint.Transform to identity each frame. During a procedural swing we
-- must keep the Humanoid's Animator detached AND remove any recreated one, else the
-- pose is wiped mid-animation and the kick barely shows.
local function suppressAnimator(rig)
	local hum = rig:FindFirstChildOfClass("Humanoid")
	if not hum then return function() end, function() end end
	local saved = {}
	local disabledAnimate = {}
	local function detach()
		for _, a in ipairs(hum:GetChildren()) do
			if a:IsA("Animator") then
				table.insert(saved, {a = a, parent = a.Parent})
				a.Parent = nil
			end
		end
	end
	-- disable the default Animate script so it stops recreating the Animator mid-swing
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("BaseScript") and d.Name == "Animate" then
			d.Disabled = true
			table.insert(disabledAnimate, d)
		end
	end
	detach()
	local function tick() detach() end
	local function restore()
		detach()
		for _, e in ipairs(saved) do
			if e.a and e.a.Parent == nil and e.parent then e.a.Parent = e.parent end
		end
		for _, d in ipairs(disabledAnimate) do
			if d.Parent then d.Disabled = false end
		end
	end
	return tick, restore
end

-- h = { hipR, kneeR, hipL, kneeL, armX, armY, elbow, waist } (degrees)
function ProceduralAnim.Apply(rig, joints, h)
	if not rig or not joints then return end
	local function set(name, cf)
		local j = joints[name]
		if j then j.Transform = cf end
	end
	set("RightHip", CFrame.Angles(math.rad(h.hipR or 0), 0, 0))
	set("RightKnee", CFrame.Angles(math.rad(h.kneeR or 0), 0, 0))
	set("LeftHip", CFrame.Angles(math.rad(h.hipL or 0), 0, 0))
	set("LeftKnee", CFrame.Angles(math.rad(h.kneeL or 0), 0, 0))
	set("Waist", CFrame.Angles(math.rad(h.waist or 0), 0, 0))
	set("LeftShoulder", CFrame.Angles(math.rad(h.armX or 0), math.rad(-(h.armY or 0)), 0))
	set("RightShoulder", CFrame.Angles(math.rad(h.armX or 0), math.rad(h.armY or 0), 0))
	set("LeftElbow", CFrame.Angles(math.rad(h.elbow or 0), 0, 0))
	set("RightElbow", CFrame.Angles(math.rad(h.elbow or 0), 0, 0))
end

function ProceduralAnim.Kick(rig)
	local joints = collectJoints(rig)
	if not joints.RightHip then return false end
	local tick, restore = suppressAnimator(rig)
	local t0 = os.clock()
	local DUR = 0.85
	while os.clock() - t0 < DUR do
		local t = (os.clock() - t0) / DUR
		local h
		if t < 0.22 then
			local k = t / 0.22
			h = { hipR = -62*k, kneeR = -65*k, hipL = 10*k, armX = -8*k, armY = 46*k, waist = -9*k }
		elseif t < 0.45 then
			local k = (t - 0.22) / 0.23
			h = { hipR = -62 + 110*k, kneeR = -65 + 68*k, hipL = 10 - 14*k, armX = -8 + 10*k, armY = 46 - 20*k, waist = -9 + 20*k }
		else
			local k = (t - 0.45) / 0.55
			h = { hipR = 48 + 26*k, kneeR = 3 + 18*k, hipL = -4 + 4*k, armX = 2 + 14*k, armY = 26 + 18*k, waist = 11 - 9*k }
		end
		tick()
		ProceduralAnim.Apply(rig, joints, h)
		task.wait(0.02)
	end
	ProceduralAnim.Apply(rig, joints, {})
	restore()
	return true
end

function ProceduralAnim.Pass(rig)
	local joints = collectJoints(rig)
	if not joints.RightHip then return false end
	local tick, restore = suppressAnimator(rig)
	local t0 = os.clock()
	local DUR = 0.55
	while os.clock() - t0 < DUR do
		local t = (os.clock() - t0) / DUR
		local h
		if t < 0.32 then
			-- plant + draw the right foot back and open the hips
			local k = t / 0.32
			h = { hipR = -40*k, kneeR = -48*k, hipL = 12*k, armX = -6*k, armY = 30*k, waist = -8*k }
		elseif t < 0.55 then
			-- sweep the side-foot through the ball
			local k = (t - 0.32) / 0.23
			h = { hipR = -40 + 95*k, kneeR = -48 + 40*k, hipL = 12 - 16*k, armX = -6 + 8*k, armY = 30 - 14*k, waist = -8 + 14*k }
		else
			-- follow through and settle
			local k = (t - 0.55) / 0.45
			h = { hipR = 55 - 35*k, kneeR = -8 + 8*k, hipL = -4 + 4*k, armX = 2 + 6*k, armY = 16 + 8*k, waist = 6 - 4*k }
		end
		tick()
		ProceduralAnim.Apply(rig, joints, h)
		task.wait(0.02)
	end
	ProceduralAnim.Apply(rig, joints, {})
	restore()
	return true
end

return ProceduralAnim
