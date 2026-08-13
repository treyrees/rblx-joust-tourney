--!strict
-- WheelInput.client.luau — the aim wheel, built programmatically at spawn so the gray-box needs no
-- image assets. Feel comes from Shared.WheelPhysics (the Magnet tune in Constants.WHEEL); this
-- script is only input capture and rendering. The needle animates smoothly; the big label above the
-- wheel is the TELEVISED state and updates in discrete notch ticks (invariant 4). Neutral is the
-- default; tap the hub to return to it (invariant 2).
--
-- Screen mapping (this rig only; a real match mirrors it per rider so "in" faces the opponent):
-- CYCLE index 0 ("up") at the top, sweeping counterclockwise on screen — "in" on the left,
-- "out" on the right. Screen degrees = -cycleNotch * 45.
--
-- Not wired to any commit/lock flow yet — this exists so the feel picked in
-- prototypes/ring-feel.html can be judged on a real device inside Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local WheelPhysics = require(Shared:WaitForChild("WheelPhysics"))

local N = #Constants.CYCLE
local DEG_PER_NOTCH = 360 / N

-- Palette (carried from the feel rig's night-arena look).
local COLOR = {
	ground = Color3.fromHex("201a11"),
	line = Color3.fromHex("3a3226"),
	dim = Color3.fromHex("9a8d72"),
	gold = Color3.fromHex("d9a441"),
	exposure = Color3.fromHex("b8452f"),
	guard = Color3.fromHex("6f94a9"),
}

-- Layout, in fractions of the wheel square (radius 0.5 = the square's edge).
local LAYOUT = {
	TRACK_RADIUS = 0.40,
	BAND_FRACTION = 0.115, -- track band thickness as a fraction of wheel size
	LABEL_RADIUS = 0.485,
	HUB_SIZE = 0.21,
	NOTCH_DOT = 0.020,
	NOTCH_DOT_ACTIVE = 0.032,
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local wheel = WheelPhysics.new()

-- ---- construction helpers ----------------------------------------------------------------------

local function round(inst: Frame | TextButton)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = inst
end

-- Position on the wheel circle: cycle-notch angle -> scale position in the wheel square.
local function onCircle(cycleNotch: number, radius: number): UDim2
	local a = math.rad(-cycleNotch * DEG_PER_NOTCH)
	return UDim2.fromScale(0.5 + math.sin(a) * radius, 0.5 - math.cos(a) * radius)
end

local gui = Instance.new("ScreenGui")
gui.Name = "WheelRig"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

-- The televised readout, above the wheel.
local televised = Instance.new("TextLabel")
televised.Name = "Televised"
televised.AnchorPoint = Vector2.new(0.5, 1)
televised.BackgroundTransparency = 1
televised.Font = Enum.Font.Fondamento -- serif small-caps flavor; gray-box stand-in
televised.Text = "neutral"
televised.TextColor3 = COLOR.dim
televised.TextScaled = true
televised.Parent = gui
local televisedScale = Instance.new("UIScale")
televisedScale.Parent = televised

-- The wheel square, bottom center, mobile-first.
local wheelFrame = Instance.new("Frame")
wheelFrame.Name = "Wheel"
wheelFrame.AnchorPoint = Vector2.new(0.5, 1)
wheelFrame.Position = UDim2.new(0.5, 0, 1, -28)
wheelFrame.Size = UDim2.fromScale(0.85, 0.55)
wheelFrame.BackgroundTransparency = 1
wheelFrame.Parent = gui
local aspect = Instance.new("UIAspectRatioConstraint")
aspect.AspectRatio = 1
aspect.AspectType = Enum.AspectType.FitWithinMaxSize
aspect.Parent = wheelFrame
local maxSize = Instance.new("UISizeConstraint")
maxSize.MaxSize = Vector2.new(420, 420)
maxSize.Parent = wheelFrame

-- The track band: a circle outline whose stroke is the band.
local track = Instance.new("Frame")
track.Name = "Track"
track.AnchorPoint = Vector2.new(0.5, 0.5)
track.Position = UDim2.fromScale(0.5, 0.5)
track.Size = UDim2.fromScale(LAYOUT.TRACK_RADIUS * 2, LAYOUT.TRACK_RADIUS * 2)
track.BackgroundTransparency = 1
track.ZIndex = 1
track.Parent = wheelFrame
round(track)
local trackStroke = Instance.new("UIStroke")
trackStroke.Color = COLOR.ground
trackStroke.Transparency = 0.15
trackStroke.Parent = track

-- Two rotating groups (same rotation each frame): ring chips under the notch dots, needle above.
local function rotatingGroup(name: string, zindex: number): Frame
	local group = Instance.new("Frame")
	group.Name = name
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.fromScale(0.5, 0.5)
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.ZIndex = zindex
	group.Parent = wheelFrame
	return group
end
local chipsGroup = rotatingGroup("RingChips", 2)
local needleGroup = rotatingGroup("Needle", 4)

-- Ring overlay: a chip at every non-normal offset, dragged around by the aim (ADR 0006).
for offset = 0, N - 1 do
	local cell = Constants.RING[offset]
	if cell ~= "normal" then
		local chip = Instance.new("Frame")
		chip.Name = "Chip" .. offset
		chip.AnchorPoint = Vector2.new(0.5, 0.5)
		chip.Position = onCircle(offset, LAYOUT.TRACK_RADIUS)
		chip.Size = UDim2.fromScale(0.055, 0.055)
		chip.BackgroundColor3 = if cell == "crit" then COLOR.exposure else COLOR.guard
		chip.BackgroundTransparency = if cell == "crit" then 0.35 else 0.15
		chip.ZIndex = 2
		chip.Parent = chipsGroup
		round(chip)
	end
end

-- The needle bar and tip.
local needle = Instance.new("Frame")
needle.Name = "Bar"
needle.AnchorPoint = Vector2.new(0.5, 0)
needle.Position = UDim2.fromScale(0.5, 0.145)
needle.Size = UDim2.fromScale(0.02, 0.29)
needle.BackgroundColor3 = COLOR.gold
needle.ZIndex = 4
needle.Parent = needleGroup
round(needle)
local tip = Instance.new("Frame")
tip.Name = "Tip"
tip.AnchorPoint = Vector2.new(0.5, 0.5)
tip.Position = onCircle(0, LAYOUT.TRACK_RADIUS)
tip.Size = UDim2.fromScale(0.035, 0.035)
tip.BackgroundColor3 = COLOR.gold
tip.ZIndex = 4
tip.Parent = needleGroup
round(tip)

-- Notch dots + direction labels (fixed in screen space).
local dots: { Frame } = {}
for i = 0, N - 1 do
	local dot = Instance.new("Frame")
	dot.Name = "Dot" .. i
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = onCircle(i, LAYOUT.TRACK_RADIUS)
	dot.Size = UDim2.fromScale(LAYOUT.NOTCH_DOT, LAYOUT.NOTCH_DOT)
	dot.BackgroundColor3 = COLOR.dim
	dot.BackgroundTransparency = 0.4
	dot.ZIndex = 3
	dot.Parent = wheelFrame
	round(dot)
	dots[i + 1] = dot

	local label = Instance.new("TextLabel")
	label.Name = "Label" .. i
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = onCircle(i, LAYOUT.LABEL_RADIUS)
	label.Size = UDim2.fromScale(0.2, 0.045)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.Text = Constants.CYCLE[i + 1]
	label.TextColor3 = COLOR.dim
	label.TextScaled = true
	label.ZIndex = 3
	label.Parent = wheelFrame
end

-- The hub: the neutral dock.
local hub = Instance.new("TextButton")
hub.Name = "Hub"
hub.AnchorPoint = Vector2.new(0.5, 0.5)
hub.Position = UDim2.fromScale(0.5, 0.5)
hub.Size = UDim2.fromScale(LAYOUT.HUB_SIZE, LAYOUT.HUB_SIZE)
hub.BackgroundColor3 = COLOR.ground
hub.Font = Enum.Font.Gotham
hub.Text = "neutral"
hub.TextColor3 = COLOR.gold
hub.TextScaled = true
hub.AutoButtonColor = false
hub.ZIndex = 5
hub.Parent = wheelFrame
round(hub)
local hubPad = Instance.new("UIPadding")
hubPad.PaddingLeft = UDim.new(0.15, 0)
hubPad.PaddingRight = UDim.new(0.15, 0)
hubPad.PaddingTop = UDim.new(0.3, 0)
hubPad.PaddingBottom = UDim.new(0.3, 0)
hubPad.Parent = hub
local hubStroke = Instance.new("UIStroke")
hubStroke.Color = COLOR.gold
hubStroke.Transparency = 0.2
hubStroke.Parent = hub

-- The input surface: a transparent button under everything decorative, over nothing.
local catcher = Instance.new("TextButton")
catcher.Name = "Catcher"
catcher.AnchorPoint = Vector2.new(0.5, 0.5)
catcher.Position = UDim2.fromScale(0.5, 0.5)
catcher.Size = UDim2.fromScale(1, 1)
catcher.BackgroundTransparency = 1
catcher.Text = ""
catcher.ZIndex = 0
catcher.Parent = wheelFrame

-- Pixel-derived cosmetics: band thickness and the televised label's box track the wheel's real size.
local function relayout()
	local size = wheelFrame.AbsoluteSize.X
	trackStroke.Thickness = size * LAYOUT.BAND_FRACTION
	televised.Position = UDim2.new(0.5, 0, 1, -28 - wheelFrame.AbsoluteSize.Y - 10)
	televised.Size = UDim2.new(0, math.max(200, size), 0, math.max(36, size * 0.12))
end
wheelFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
relayout()

-- The notch tick sound. Built-in asset so the gray-box ships no uploads; PlaybackSpeed jitters so
-- fast crossings don't machine-gun.
local tickSound = Instance.new("Sound")
tickSound.Name = "NotchTick"
tickSound.SoundId = "rbxasset://sounds/snap.mp3"
tickSound.Volume = 0.35
tickSound.Parent = gui

-- ---- input -------------------------------------------------------------------------------------

-- Pointer position -> cycle-notch angle (continuous). Inverse of onCircle's mapping.
local function pointerNotch(position: Vector2): number
	local center = wheelFrame.AbsolutePosition + wheelFrame.AbsoluteSize / 2
	local d = position - center
	local screenNotch = math.atan2(d.X, -d.Y) / math.rad(DEG_PER_NOTCH)
	return -screenNotch % N
end

local activeInput: InputObject? = nil

catcher.InputBegan:Connect(function(input: InputObject)
	if
		input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch
	then
		return
	end
	if activeInput then
		return
	end
	activeInput = input
	wheel:beginDrag(pointerNotch(Vector2.new(input.Position.X, input.Position.Y)), os.clock())
end)

UserInputService.InputChanged:Connect(function(input: InputObject)
	if input ~= activeInput and input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end
	if activeInput == nil or not wheel.dragging then
		return
	end
	-- Mouse drags arrive as MouseMovement, touch drags as the captured Touch input.
	if activeInput.UserInputType == Enum.UserInputType.Touch and input ~= activeInput then
		return
	end
	wheel:drag(pointerNotch(Vector2.new(input.Position.X, input.Position.Y)), os.clock())
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	-- A touch ends as the same InputObject; a mouse release is only guaranteed to match by type.
	local a = activeInput
	if a == nil then
		return
	end
	if input ~= a and input.UserInputType ~= a.UserInputType then
		return
	end
	activeInput = nil
	wheel:endDrag()
end)

hub.Activated:Connect(function()
	wheel:setNeutral()
end)

-- ---- render loop -------------------------------------------------------------------------------

local lastNotch: number? = nil
local rng = Random.new()
local pulseInfo = TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function onNotchChange(idx: number)
	tickSound.PlaybackSpeed = 1.4 + rng:NextNumber(-0.1, 0.1)
	tickSound:Play()
	televised.Text = Constants.CYCLE[idx + 1]
	televised.TextColor3 = COLOR.gold
	televisedScale.Scale = 1.08
	TweenService:Create(televisedScale, pulseInfo, { Scale = 1 }):Play()
end

RunService.RenderStepped:Connect(function(dt: number)
	wheel:step(dt)

	local neutral = wheel.neutral
	local rotation = -wheel:displayTheta() * DEG_PER_NOTCH
	chipsGroup.Rotation = rotation
	needleGroup.Rotation = rotation
	chipsGroup.Visible = not neutral
	needleGroup.Visible = not neutral

	local idx = wheel:notchIndex()
	if idx ~= lastNotch then
		lastNotch = idx
		if idx ~= nil then
			onNotchChange(idx)
		else
			televised.Text = "neutral"
			televised.TextColor3 = COLOR.dim
		end
	end

	for i = 0, N - 1 do
		local dot = dots[i + 1]
		local active = idx == i
		local d = if active then LAYOUT.NOTCH_DOT_ACTIVE else LAYOUT.NOTCH_DOT
		dot.Size = UDim2.fromScale(d, d)
		dot.BackgroundColor3 = if active then COLOR.gold else COLOR.dim
		dot.BackgroundTransparency = if active then 0 else 0.4
	end

	hubStroke.Color = if neutral then COLOR.gold else COLOR.line
	hub.TextColor3 = if neutral then COLOR.gold else COLOR.dim
end)
