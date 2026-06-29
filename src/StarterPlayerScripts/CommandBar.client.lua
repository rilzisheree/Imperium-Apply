--[[
	CommandBar.client.lua  —  LocalScript (StarterPlayerScripts)

	Press ; or ' to open.  Escape to close.  Enter to run.
	Remotes are fetched at the moment you execute, so startup never blocks.
]]

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LP   = Players.LocalPlayer
local PGui = LP:WaitForChild("PlayerGui")

-- ── GUI ────────────────────────────────────────────────────────────────────────
-- IgnoreGuiInset = false  →  Y=0 is below the Roblox topbar (no overlap issues)

local sg = Instance.new("ScreenGui")
sg.Name           = "CmdBarGui"
sg.ResetOnSpawn   = false
sg.IgnoreGuiInset = false
sg.DisplayOrder   = 100
sg.Parent         = PGui

-- Dark bar frame, centered near top
local frame = Instance.new("Frame", sg)
frame.Name                  = "Bar"
frame.AnchorPoint           = Vector2.new(0.5, 0)
frame.Size                  = UDim2.new(0, 520, 0, 46)
frame.Position              = UDim2.new(0.5, 0, 0, 12)
frame.BackgroundColor3      = Color3.fromRGB(12, 12, 18)
frame.BorderSizePixel       = 0
frame.Visible               = false
frame.ZIndex                = 10

local c = Instance.new("UICorner", frame)
c.CornerRadius = UDim.new(0, 8)

local s = Instance.new("UIStroke", frame)
s.Color     = Color3.fromRGB(90, 90, 120)
s.Thickness = 1.5
s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- Prompt label
local prompt = Instance.new("TextLabel", frame)
prompt.Size               = UDim2.new(0, 28, 1, 0)
prompt.Position           = UDim2.new(0, 8, 0, 0)
prompt.BackgroundTransparency = 1
prompt.Font               = Enum.Font.GothamBold
prompt.TextSize           = 18
prompt.TextColor3         = Color3.fromRGB(160, 160, 210)
prompt.Text               = "›"
prompt.TextXAlignment     = Enum.TextXAlignment.Center
prompt.TextYAlignment     = Enum.TextYAlignment.Center
prompt.ZIndex             = 11

-- Text input
local box = Instance.new("TextBox", frame)
box.Size               = UDim2.new(1, -42, 1, -12)
box.Position           = UDim2.new(0, 38, 0, 6)
box.BackgroundTransparency = 1
box.BorderSizePixel    = 0
box.ClearTextOnFocus   = false
box.Font               = Enum.Font.Code
box.TextSize           = 14
box.TextColor3         = Color3.fromRGB(235, 235, 252)
box.PlaceholderText    = "sm  /  im  /  anxiety  …"
box.PlaceholderColor3  = Color3.fromRGB(80, 80, 100)
box.Text               = ""
box.TextXAlignment     = Enum.TextXAlignment.Left
box.TextYAlignment     = Enum.TextYAlignment.Center
box.ZIndex             = 11

-- [CMD] always-visible button so there's always a clickable fallback
local btn = Instance.new("TextButton", sg)
btn.Name              = "OpenBtn"
btn.AnchorPoint       = Vector2.new(1, 0)
btn.Size              = UDim2.new(0, 54, 0, 22)
btn.Position          = UDim2.new(1, -6, 0, 6)
btn.BackgroundColor3  = Color3.fromRGB(18, 18, 28)
btn.BorderSizePixel   = 0
btn.Text              = "[CMD]"
btn.Font              = Enum.Font.GothamBold
btn.TextSize          = 10
btn.TextColor3        = Color3.fromRGB(160, 160, 210)
btn.ZIndex            = 5

local bc = Instance.new("UICorner", btn)
bc.CornerRadius = UDim.new(0, 5)

local bs = Instance.new("UIStroke", btn)
bs.Color = Color3.fromRGB(90, 90, 120)
bs.Thickness = 1
bs.Transparency = 0.4
bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- ── State ──────────────────────────────────────────────────────────────────────

local isOpen = false

-- ── Open / Close ───────────────────────────────────────────────────────────────

local function open()
	if isOpen then return end
	isOpen = true
	frame.Visible = true
	box:CaptureFocus()
	print("[CMD] opened")
end

local function close()
	if not isOpen then return end
	isOpen = false
	frame.Visible = false
	box.Text = ""
	box:ReleaseFocus()
	print("[CMD] closed")
end

-- ── Execute ────────────────────────────────────────────────────────────────────

local function execute()
	local raw = (box.Text:match("^%s*(.-)%s*$") or "")
	if raw == "" then close() return end

	-- Fetch the remote NOW (at execution time, not at startup)
	-- This way startup never blocks waiting for it.
	local remote = ReplicatedStorage:FindFirstChild("CmdExecuted")
	if not remote then
		warn("[CMD] CmdExecuted remote not found in ReplicatedStorage")
		close()
		return
	end

	-- Parse: first word = command, rest = args
	local words = {}
	for w in raw:gmatch("%S+") do table.insert(words, w) end
	local cmdName = table.remove(words, 1):lower()

	remote:FireServer(cmdName, words)
	print("[CMD] fired →", cmdName, words)
	close()
end

-- ── Wire up events ─────────────────────────────────────────────────────────────

box.FocusLost:Connect(function(enter)
	if enter then execute() end
end)

btn.MouseButton1Click:Connect(function()
	if isOpen then close() else open() end
end)

UserInputService.InputBegan:Connect(function(inp, gp)
	if gp then return end                -- respect gameProcessed

	if inp.KeyCode == Enum.KeyCode.Semicolon
	or inp.KeyCode == Enum.KeyCode.Quote then
		if isOpen then close() else open() end
		return
	end

	if isOpen and inp.KeyCode == Enum.KeyCode.Escape then
		close()
		return
	end
end)

-- ── Done ───────────────────────────────────────────────────────────────────────

print("[CMD] Command bar ready — press ; or ' to open")
