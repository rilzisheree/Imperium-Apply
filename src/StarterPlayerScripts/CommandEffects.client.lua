--[[
        CommandEffects.client.lua
        LocalScript — StarterPlayerScripts
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ─── Tween helper ─────────────────────────────────────────────────────────────

local function tw(target, time, props)
        TweenService:Create(target, TweenInfo.new(time, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props):Play()
end

-- ─── Root ScreenGui ───────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name           = "CommandEffects"
gui.DisplayOrder   = 55
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.Parent         = PlayerGui

-- ─── Blur (SM only) ───────────────────────────────────────────────────────────

local blur = Instance.new("BlurEffect")
blur.Size   = 0
blur.Parent = Lighting

-- ─── SM labels ────────────────────────────────────────────────────────────────

local smHeader = Instance.new("TextLabel")
smHeader.Name                   = "SMHeader"
smHeader.AnchorPoint            = Vector2.new(0.5, 1)
smHeader.Position               = UDim2.new(0.5, 0, 0.11, -4)
smHeader.Size                   = UDim2.new(0.75, 0, 0, 38)
smHeader.BackgroundTransparency = 1
smHeader.TextColor3             = Color3.fromRGB(255, 255, 255)
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
smBody.Size                   = UDim2.new(0.70, 0, 0, 110)
smBody.BackgroundTransparency = 1
smBody.TextColor3             = Color3.fromRGB(255, 255, 255)
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

-- ─── IM label ─────────────────────────────────────────────────────────────────

local imLabel = Instance.new("TextLabel")
imLabel.Name                   = "IMLabel"
imLabel.AnchorPoint            = Vector2.new(0.5, 0.5)
imLabel.Position               = UDim2.new(0.5, 0, 0.66, 0)
imLabel.Size                   = UDim2.new(0.50, 0, 0, 100)
imLabel.BackgroundTransparency = 1
imLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
imLabel.TextTransparency       = 0
imLabel.TextSize               = 24
imLabel.Font                   = Enum.Font.Merriweather
imLabel.Text                   = ""
imLabel.TextWrapped            = true
imLabel.TextXAlignment         = Enum.TextXAlignment.Center
imLabel.TextYAlignment         = Enum.TextYAlignment.Center
imLabel.ZIndex                 = 10
imLabel.Visible                = false
imLabel.Parent                 = gui

-- ─── Hold time ────────────────────────────────────────────────────────────────

local function calcHold(text: string): number
        local words = select(2, text:gsub("%S+", "")) + 1
        return math.clamp(words * 0.45, 4, 10)
end

-- ─── SM ───────────────────────────────────────────────────────────────────────

local function showSM(text: string)
        smBody.Text               = text
        smHeader.TextTransparency = 1
        smBody.TextTransparency   = 1
        smHeader.Visible          = true
        smBody.Visible            = true
        blur.Size                 = 0

        tw(blur,     0.6, { Size = 5 })
        tw(smHeader, 0.6, { TextTransparency = 0 })
        tw(smBody,   0.6, { TextTransparency = 0 })

        task.delay(0.6 + calcHold(text), function()
                tw(blur,     0.5, { Size = 0 })
                tw(smHeader, 0.5, { TextTransparency = 1 })
                tw(smBody,   0.5, { TextTransparency = 1 })
                task.delay(0.55, function()
                        smHeader.Visible          = false
                        smHeader.TextTransparency = 0
                        smBody.Visible            = false
                        smBody.TextTransparency   = 0
                        blur.Size                 = 0
                end)
        end)
end

-- ─── IM ───────────────────────────────────────────────────────────────────────

local function showIM(text: string)
        imLabel.Text             = text
        imLabel.TextTransparency = 1
        imLabel.Visible          = true

        tw(imLabel, 0.6, { TextTransparency = 0 })

        task.delay(0.6 + calcHold(text), function()
                tw(imLabel, 0.5, { TextTransparency = 1 })
                task.delay(0.55, function()
                        imLabel.Visible          = false
                        imLabel.TextTransparency = 0
                end)
        end)
end

-- ─── Remote listeners ─────────────────────────────────────────────────────────

local CommandRemotes = require(ReplicatedStorage:WaitForChild("CommandRemotes"))

if CommandRemotes.SM then
        CommandRemotes.SM.OnClientEvent:Connect(function(message: string)
                if typeof(message) == "string" and message ~= "" then
                        showSM(message)
                end
        end)
end

if CommandRemotes.IM then
        CommandRemotes.IM.OnClientEvent:Connect(function(message: string)
                if typeof(message) == "string" and message ~= "" then
                        showIM(message)
                end
        end)
end

print("[CommandEffects] Ready.")
