--[[
	CommandEffects.client.lua
	LocalScript — StarterPlayerScripts
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local TextService       = game:GetService("TextService")
local Lighting          = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ── Colour map ─────────────────────────────────────────────────────────────────

local COLOR_MAP = {
	red    = Color3.fromRGB(255,  90,  90),
	blue   = Color3.fromRGB(110, 160, 255),
	green  = Color3.fromRGB( 90, 220,  90),
	yellow = Color3.fromRGB(255, 230,  80),
	orange = Color3.fromRGB(255, 160,  60),
	purple = Color3.fromRGB(190, 110, 255),
	pink   = Color3.fromRGB(255, 140, 210),
	white  = Color3.fromRGB(255, 255, 255),
	cyan   = Color3.fromRGB( 90, 225, 255),
	lime   = Color3.fromRGB(140, 255,  90),
}
local DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)

local function resolveColor(name: string?): Color3
	if name and COLOR_MAP[name:lower()] then
		return COLOR_MAP[name:lower()]
	end
	return DEFAULT_COLOR
end

-- ── Tween helper ───────────────────────────────────────────────────────────────

local function tw(target, time, props, style, dir)
	style = style or Enum.EasingStyle.Quint
	dir   = dir   or Enum.EasingDirection.Out
	TweenService:Create(target, TweenInfo.new(time, style, dir), props):Play()
end

-- ── Root ScreenGui ─────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name           = "CommandEffects"
gui.DisplayOrder   = 55
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.Parent         = PlayerGui

-- ── Blur (SM only) ─────────────────────────────────────────────────────────────

local blur = Instance.new("BlurEffect")
blur.Size   = 0
blur.Parent = Lighting

-- ── SM labels ──────────────────────────────────────────────────────────────────

local smHeader = Instance.new("TextLabel")
smHeader.Name                   = "SMHeader"
smHeader.AnchorPoint            = Vector2.new(0.5, 1)
smHeader.Position               = UDim2.new(0.5, 0, 0.11, -4)
smHeader.Size                   = UDim2.new(0.75, 0, 0, 38)
smHeader.BackgroundTransparency = 1
smHeader.TextColor3             = DEFAULT_COLOR
smHeader.TextTransparency       = 0
smHeader.TextSize               = 36
smHeader.Font                   = Enum.Font.Merriweather
smHeader.Text                   = "[ Server Message ]"
smHeader.TextXAlignment         = Enum.TextXAlignment.Center
smHeader.TextYAlignment         = Enum.TextYAlignment.Center
smHeader.ZIndex                 = 10
smHeader.Visible                = false
smHeader.Parent                 = gui

local smBody = Instance.new("TextLabel")
smBody.Name                   = "SMBody"
smBody.AnchorPoint            = Vector2.new(0.5, 0)
smBody.Position               = UDim2.new(0.5, 0, 0.11, 4)
smBody.Size                   = UDim2.new(0.70, 0, 0, 0)
smBody.AutomaticSize          = Enum.AutomaticSize.Y
smBody.BackgroundTransparency = 1
smBody.TextColor3             = DEFAULT_COLOR
smBody.TextTransparency       = 0
smBody.TextSize               = 28
smBody.Font                   = Enum.Font.Merriweather
smBody.Text                   = ""
smBody.TextWrapped            = true
smBody.TextScaled             = false
smBody.TextXAlignment         = Enum.TextXAlignment.Center
smBody.TextYAlignment         = Enum.TextYAlignment.Top
smBody.ZIndex                 = 10
smBody.Visible                = false
smBody.Parent                 = gui

-- ── IM label ───────────────────────────────────────────────────────────────────

local imLabel = Instance.new("TextLabel")
imLabel.Name                   = "IMLabel"
imLabel.AnchorPoint            = Vector2.new(0.5, 0.5)
imLabel.Position               = UDim2.new(0.5, 0, 0.66, 0)
imLabel.Size                   = UDim2.new(0.50, 0, 0, 0)
imLabel.AutomaticSize          = Enum.AutomaticSize.Y
imLabel.BackgroundTransparency = 1
imLabel.TextColor3             = DEFAULT_COLOR
imLabel.TextTransparency       = 0
imLabel.TextSize               = 25
imLabel.Font                   = Enum.Font.Merriweather
imLabel.Text                   = ""
imLabel.TextWrapped            = true
imLabel.TextXAlignment         = Enum.TextXAlignment.Center
imLabel.TextYAlignment         = Enum.TextYAlignment.Center
imLabel.ZIndex                 = 10
imLabel.Visible                = false
imLabel.Parent                 = gui

-- ── Hold time ──────────────────────────────────────────────────────────────────

local function calcHold(text: string): number
	local words = select(2, text:gsub("%S+", "")) + 1
	return math.clamp(words * 0.45, 4, 10)
end

-- ── Per-character bounce ───────────────────────────────────────────────────────
-- Creates individual TextLabels for each character of `label`, positioned to
-- match the label's location.  Each letter hops up independently with a phase
-- offset, giving a wave-bounce effect.
--
-- Uses math.max(0, sin) so characters only go UP, then snap back to baseline —
-- a sharp hop rather than a smooth drift.
--
-- Call the returned stop() before doing any fade-out tween on `label`.

local BOUNCE_AMP   = 9     -- pixels each letter jumps upward
local BOUNCE_SPEED = 3.2   -- radians/sec (higher = faster bouncing)
local BOUNCE_PHASE = 0.38  -- radians of phase between adjacent characters

local function startCharacterBounce(label: TextLabel): () -> ()
	local text     = label.Text
	local font     = label.Font
	local fontSize = label.TextSize
	local color    = label.TextColor3
	local zindex   = label.ZIndex

	if #text == 0 then return function() end end

	-- Measure each character's pixel width
	local chars      = {}
	local totalWidth = 0
	for i = 1, #text do
		local ch = text:sub(i, i)
		local w  = TextService:GetTextSize(ch, fontSize, font, Vector2.new(9999, 9999)).X
		w = math.max(w, 5)   -- spaces can report 0 — give them at least 5px
		table.insert(chars, { ch = ch, w = w })
		totalWidth += w
	end

	local EXTRA_H = BOUNCE_AMP + 6  -- extra height so letters don't clip at the top

	-- Container frame: same anchor + position as the original label,
	-- width = measured text width so it's perfectly centred.
	local container = Instance.new("Frame")
	container.AnchorPoint      = label.AnchorPoint
	container.Position         = label.Position
	container.Size             = UDim2.new(0, totalWidth, 0, fontSize + EXTRA_H * 2)
	container.BackgroundTransparency = 1
	container.ClipsDescendants = false
	container.ZIndex           = zindex
	container.Parent           = gui

	-- UIListLayout handles horizontal spacing — no manual X math needed
	local layout = Instance.new("UIListLayout", container)
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder     = Enum.SortOrder.LayoutOrder
	layout.Padding       = UDim.new(0, 0)

	-- Build a wrapper Frame per character; the TextLabel inside animates in Y
	local charLabels = {}
	for i, c in ipairs(chars) do
		local wrapper = Instance.new("Frame")
		wrapper.Size                   = UDim2.new(0, c.w, 1, 0)
		wrapper.BackgroundTransparency = 1
		wrapper.ClipsDescendants       = false
		wrapper.LayoutOrder            = i
		wrapper.Parent                 = container

		local lbl = Instance.new("TextLabel")
		lbl.Size              = UDim2.new(1, 0, 0, fontSize)
		lbl.Position          = UDim2.new(0, 0, 0.5, 0)
		lbl.AnchorPoint       = Vector2.new(0, 0.5)
		lbl.BackgroundTransparency = 1
		lbl.Text              = c.ch
		lbl.Font              = font
		lbl.TextSize          = fontSize
		lbl.TextColor3        = color
		lbl.TextTransparency  = 0
		lbl.ZIndex            = zindex + 1
		lbl.Parent            = wrapper

		charLabels[i] = lbl
	end

	-- Hide the original label (char labels are now visually identical)
	label.TextTransparency = 1

	-- Animate: each letter hops on a sine wave, positive only → jumps up only
	local t    = 0
	local conn = RunService.RenderStepped:Connect(function(dt)
		t += dt
		for i, lbl in ipairs(charLabels) do
			local phase = (i - 1) * BOUNCE_PHASE
			local jump  = math.max(0, math.sin(t * BOUNCE_SPEED + phase)) * BOUNCE_AMP
			lbl.Position = UDim2.new(0, 0, 0.5, -jump)
		end
	end)

	-- stop() — call before any fade-out tween on the original label
	return function()
		conn:Disconnect()
		container:Destroy()
		label.TextTransparency = 0   -- restore so the caller's fade-out works
	end
end

-- ── SM queue ───────────────────────────────────────────────────────────────────

local smQueue: { { text: string, color: Color3, colorName: string? } } = {}
local smBusy = false

local function processSmQueue()
	if smBusy or #smQueue == 0 then return end
	smBusy = true

	local entry     = table.remove(smQueue, 1)
	local text      = entry.text
	local color     = entry.color
	local colorName = entry.colorName
	local hold      = calcHold(text)

	smBody.Text               = text
	smBody.TextColor3         = color
	smHeader.TextColor3       = color
	smHeader.TextTransparency = 1
	smBody.TextTransparency   = 1
	smHeader.Visible          = true
	smBody.Visible            = true
	blur.Size                 = 0

	tw(blur,     0.6, { Size = 5 })
	tw(smHeader, 0.6, { TextTransparency = 0 })
	tw(smBody,   0.6, { TextTransparency = 0 })

	local stopHeader, stopBody

	if colorName then
		-- Wait for fade-in to finish before swapping to per-character labels
		task.delay(0.62, function()
			stopHeader = startCharacterBounce(smHeader)
			stopBody   = startCharacterBounce(smBody)
		end)
	end

	task.delay(0.6 + hold, function()
		-- Restore originals BEFORE tweening them out
		if stopHeader then stopHeader() end
		if stopBody   then stopBody()   end

		tw(blur,     0.5, { Size = 0 })
		tw(smHeader, 0.5, { TextTransparency = 1 })
		tw(smBody,   0.5, { TextTransparency = 1 })
		task.delay(0.55, function()
			smHeader.Visible          = false
			smHeader.TextTransparency = 0
			smBody.Visible            = false
			smBody.TextTransparency   = 0
			blur.Size                 = 0
			smBusy = false
			processSmQueue()
		end)
	end)
end

local function showSM(text: string, colorName: string?)
	table.insert(smQueue, {
		text      = text,
		color     = resolveColor(colorName),
		colorName = colorName,
	})
	processSmQueue()
end

-- ── IM ─────────────────────────────────────────────────────────────────────────

local function showIM(text: string, colorName: string?)
	local color = resolveColor(colorName)
	local hold  = calcHold(text)

	imLabel.Text             = text
	imLabel.TextColor3       = color
	imLabel.TextTransparency = 1
	imLabel.Visible          = true

	tw(imLabel, 0.6, { TextTransparency = 0 })

	local stopIM

	if colorName then
		task.delay(0.62, function()
			stopIM = startCharacterBounce(imLabel)
		end)
	end

	task.delay(0.6 + hold, function()
		if stopIM then stopIM() end

		tw(imLabel, 0.5, { TextTransparency = 1 })
		task.delay(0.55, function()
			imLabel.Visible          = false
			imLabel.TextTransparency = 0
		end)
	end)
end

-- ── Remote listeners ───────────────────────────────────────────────────────────

local CommandRemotes = require(ReplicatedStorage:WaitForChild("CommandRemotes"))

if CommandRemotes.SM then
	CommandRemotes.SM.OnClientEvent:Connect(function(message: string, colorName: string?)
		if typeof(message) == "string" and message ~= "" then
			showSM(message, colorName)
		end
	end)
end

if CommandRemotes.IM then
	CommandRemotes.IM.OnClientEvent:Connect(function(message: string, colorName: string?)
		if typeof(message) == "string" and message ~= "" then
			showIM(message, colorName)
		end
	end)
end

print("[CommandEffects] Ready.")
