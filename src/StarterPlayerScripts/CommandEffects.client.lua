--[[
        CommandEffects.client.lua
        LocalScript — StarterPlayerScripts
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
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

-- ── Colour VFX ─────────────────────────────────────────────────────────────────
-- Creates a coloured screen-edge glow + subtle tint that lasts `holdDuration`
-- seconds then fades out automatically. Only called when a colour is set.
--
-- allSides = true  → SM: glow on all 4 edges, stronger effect
-- allSides = false → IM: glow on left/right only, subtler effect

local function showColorVFX(color: Color3, holdDuration: number, allSides: boolean)
        local FADE_IN  = 0.55
        local FADE_OUT = 0.55
        -- How opaque the glow frames get at peak (lower = more visible)
        local peakTrans = allSides and 0.42 or 0.58

        -- Vignette data: {size, position, gradientRotation}
        local vigData = allSides and {
                { UDim2.new(1, 0, 0.38, 0), UDim2.new(0,    0, 0,    0), 90  },  -- top
                { UDim2.new(1, 0, 0.38, 0), UDim2.new(0,    0, 0.62, 0), 270 },  -- bottom
                { UDim2.new(0.28, 0, 1, 0), UDim2.new(0,    0, 0,    0), 0   },  -- left
                { UDim2.new(0.28, 0, 1, 0), UDim2.new(0.72, 0, 0,    0), 180 },  -- right
        } or {
                { UDim2.new(0.22, 0, 1, 0), UDim2.new(0,    0, 0,    0), 0   },  -- left
                { UDim2.new(0.22, 0, 1, 0), UDim2.new(0.78, 0, 0,    0), 180 },  -- right
        }

        local frames = {}
        for _, data in vigData do
                local f = Instance.new("Frame")
                f.Size                   = data[1]
                f.Position               = data[2]
                f.BackgroundColor3       = color
                f.BackgroundTransparency = 1
                f.BorderSizePixel        = 0
                f.ZIndex                 = 8
                f.Parent                 = gui

                local g = Instance.new("UIGradient")
                g.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0,    0),
                        NumberSequenceKeypoint.new(0.45, 0.55),
                        NumberSequenceKeypoint.new(1,    1),
                })
                g.Rotation = data[3]
                g.Parent   = f

                table.insert(frames, f)
                tw(f, FADE_IN, { BackgroundTransparency = peakTrans })
        end

        -- Brief initial flash — quick dip to a brighter transparency then settle
        task.delay(FADE_IN * 0.35, function()
                for _, f in frames do
                        tw(f, 0.12, { BackgroundTransparency = peakTrans - 0.12 },
                                Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                end
                task.delay(0.14, function()
                        for _, f in frames do
                                tw(f, 0.25, { BackgroundTransparency = peakTrans },
                                        Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                        end
                end)
        end)

        -- Subtle color correction tint matching the color
        local cc = Instance.new("ColorCorrectionEffect")
        cc.TintColor = Color3.new(1, 1, 1)
        cc.Brightness = 0
        cc.Parent = Lighting

        local tintStrength = allSides and 0.12 or 0.06
        local tintTarget = Color3.new(
                1 - tintStrength + tintStrength * color.R,
                1 - tintStrength + tintStrength * color.G,
                1 - tintStrength + tintStrength * color.B
        )
        tw(cc, FADE_IN, { TintColor = tintTarget })

        -- ── Fade out after hold ────────────────────────────────────────────────────

        task.delay(FADE_IN + holdDuration, function()
                for _, f in frames do
                        tw(f, FADE_OUT, { BackgroundTransparency = 1 })
                end
                tw(cc, FADE_OUT, { TintColor = Color3.new(1, 1, 1) })
                task.delay(FADE_OUT + 0.15, function()
                        for _, f in frames do
                                if f.Parent then f:Destroy() end
                        end
                        cc:Destroy()
                end)
        end)
end

-- ── SM queue ───────────────────────────────────────────────────────────────────
-- Each entry: { text: string, color: Color3, colorName: string? }

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

        -- VFX only when a colour was specified
        if colorName then
                showColorVFX(color, hold, true)
        end

        task.delay(0.6 + hold, function()
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

        -- VFX only when a colour was specified
        if colorName then
                showColorVFX(color, hold, false)
        end

        task.delay(0.6 + hold, function()
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
