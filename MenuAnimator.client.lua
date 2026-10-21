-- MenuAnimator: drives all menu animations
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui", 10)
local screens = pg:WaitForChild("RFC27", 10):WaitForChild("Screens", 10)
local menu = screens:WaitForChild("MainMenu", 10)

local Theme = require(game.ReplicatedStorage.RFC27.UIConfig.Theme)
local Anim = require(game.ReplicatedStorage.RFC27.UIConfig.Anim)
local C = Theme.Colors

local brand = menu:WaitForChild("Brand", 5)
local kicker = brand:WaitForChild("Kicker", 5)
local title = brand:WaitForChild("Title", 5)
local tagline = brand:WaitForChild("Tagline", 5)
local crest = menu:WaitForChild("Crest", 5)
local crestStroke = crest:WaitForChild("CrestStroke", 5)
local glow = menu:WaitForChild("Glow", 5)
local strip = menu:WaitForChild("Strip", 5)
local buttons = menu:WaitForChild("Buttons", 5)

-- 1. typewriter kicker
local function typewriter(label, text, speed)
	label.Text = ""
	for i = 1, #text do
		if not label.Parent then return end
		label.Text = text:sub(1, i)
		task.wait(speed)
	end
end

-- 2. title entrance: scale + fade from below
local function animateTitle()
	title.TextTransparency = 1
	title.Position = UDim2.new(0, -6, 0, 60)
	TweenService:Create(title, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		Position = UDim2.new(0, -6, 0, 20),
	}):Play()
	task.wait(0.25)
	tagline.TextTransparency = 1
	tagline.Position = UDim2.new(0, 4, 0, 190)
	TweenService:Create(tagline, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		Position = UDim2.new(0, 4, 0, 150),
	}):Play()
end

-- 3. crest breathing pulse + slow rotation of glow
local function animateCrest()
	task.spawn(function()
		while crest.Parent do
			TweenService:Create(crestStroke, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0.05 }):Play()
			TweenService:Create(crest, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Size = UDim2.new(0, 208, 0, 208),
				Position = UDim2.new(1, -294, 0, 76),
			}):Play()
			task.wait(1.6)
			if not crest.Parent then break end
			TweenService:Create(crestStroke, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0.35 }):Play()
			TweenService:Create(crest, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Size = UDim2.new(0, 200, 0, 200),
				Position = UDim2.new(1, -290, 0, 80),
			}):Play()
			task.wait(1.6)
		end
	end)
end

-- 4. glow drift
local function animateGlow()
	task.spawn(function()
		local t = 0
		while glow.Parent do
			t += 0.016
			local x = -350 + math.sin(t * 0.4) * 40
			local y = -400 + math.cos(t * 0.3) * 30
			glow.Position = UDim2.new(0, x, 0, y)
			RunService.RenderStepped:Wait()
		end
	end)
end

-- 5. button stagger entrance + hook Anim.Button
local function animateButtons()
	local list = {}
	for _, c in ipairs(buttons:GetChildren()) do
		if c:IsA("TextButton") then table.insert(list, c) end
	end
	table.sort(list, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	for _, b in ipairs(list) do
		local targetPos = b.Position
		b.BackgroundTransparency = 1
		b.Position = targetPos + UDim2.new(0, -40, 0, 0)
		local label = b:FindFirstChild("Label")
		local sub = b:FindFirstChild("Sub")
		if label then label.TextTransparency = 1 end
		if sub then sub.TextTransparency = 1 end
	end
	task.wait(0.5)
	for i, b in ipairs(list) do
		local targetPos = b.Position - UDim2.new(0, -40, 0, 0)
		local label = b:FindFirstChild("Label")
		local sub = b:FindFirstChild("Sub")
		local accent = b:FindFirstChild("Accent")
		Anim.Button(b, { baseColor = C.panel, hoverColor = C.panelLight, accentBar = accent })
		task.delay(0.07 * (i - 1), function()
			TweenService:Create(b, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				BackgroundTransparency = 0,
				Position = targetPos,
			}):Play()
			if label then TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 0 }):Play() end
			if sub then TweenService:Create(sub, TweenInfo.new(0.35), { TextTransparency = 0 }):Play() end
		end)
	end
end

-- 6. strip shimmer
local function animateStrip()
	task.spawn(function()
		local grad = strip:FindFirstChildOfClass("UIGradient")
		while strip.Parent and grad do
			grad.Offset = Vector2.new(0, math.sin(os.clock() * 0.8) * 0.15)
			RunService.RenderStepped:Wait()
		end
	end)
end

-- run everything
animateTitle()
animateCrest()
animateGlow()
animateStrip()
task.spawn(function()
	typewriter(kicker, "SEASON 2027  /  OFFICIAL", 0.025)
end)
task.delay(0.35, animateButtons)

return "MenuAnimator running"
