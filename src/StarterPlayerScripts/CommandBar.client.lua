--[[
	CommandBar.client.lua
	LocalScript — StarterPlayerScripts

	Controls:
	  ;  or  '   — open / close
	  Escape      — close
	  Enter        — execute
	  Up / Down   — history
	  Tab          — autocomplete
	  [CMD] button — always-visible fallback
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ── Remotes loaded in background — NEVER block startup ────────────────────────
-- The GUI builds and ALL key handlers connect before this finishes.
local CommandRemotes  = nil
local CommandRegistry = nil

task.spawn(function()
	local ok, err = pcall(function()
		CommandRemotes  = require(ReplicatedStorage:WaitForChild("CommandRemotes",  30))
		CommandRegistry = require(ReplicatedStorage:WaitForChild("CommandRegistry", 30))
	end)
	if not ok then
		warn("[CommandBar] Remote load failed:", err)
	else
		-- Listen for server feedback once remotes are ready
		if CommandRemotes and CommandRemotes.CommandFeedback then
			CommandRemotes.CommandFeedback.OnClientEvent:Connect(function(success, msg)
				if not success and type(msg) == "string" then
					showNotif("✗  " .. msg, Color3.fromRGB(200, 80, 80))
				end
			end)
		end
		print("[CommandBar] Remotes ready.")
	end
end)

-- ── Config ─────────────────────────────────────────────────────────────────────

local OPEN_KEYS  = { Enum.KeyCode.Semicolon, Enum.KeyCode.Quote }
local BAR_W      = 560
local BAR_H      = 50
local BAR_Y_OPEN = 80
local BAR_Y_SHUT = 56
local ANIM       = 0.18
local HIST_MAX   = 80
local AC_MAX     = 6
local AC_ROW_H   = 32

local C_BG    = Color3.fromRGB(10,  10,  13)
local C_BOR   = Color3.fromRGB(85,  85, 100)
local C_ACC   = Color3.fromRGB(175, 175, 208)
local C_TXT   = Color3.fromRGB(235, 235, 250)
local C_DIM   = Color3.fromRGB(90,  90, 108)
local C_ACBG  = Color3.fromRGB(12,  12,  15)
local C_HOV   = Color3.fromRGB(26,  26,  34)
local C_ABOR  = Color3.fromRGB(68,  68,  86)

-- ── State ──────────────────────────────────────────────────────────────────────

local isOpen       = false
local inputFocused = false
local history      = {}
local histIdx      = 0
local draft        = ""
local acM          = {}
local acI          = 1

-- ── Helpers ────────────────────────────────────────────────────────────────────

local function tw(obj, t, props, style, dir)
	TweenService:Create(obj,
		TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		props):Play()
end

local function corner(p, r)
	local c = Instance.new("UICorner", p)
	c.CornerRadius = UDim.new(0, r or 7)
end

local function stroke(p, col, th, transparency)
	local s = Instance.new("UIStroke", p)
	s.Color = col
	s.Thickness = th or 1.3
	s.Transparency = transparency or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return s
end

-- ── Root ScreenGui ─────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name           = "StaffCommandBar"
gui.DisplayOrder   = 50
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.Parent         = PlayerGui

-- ── [CMD] open button ──────────────────────────────────────────────────────────
-- Y=40 is below the Roblox CoreGui topbar when IgnoreGuiInset=true

local cmdBtn = Instance.new("TextButton", gui)
cmdBtn.Name                   = "CmdBtn"
cmdBtn.AnchorPoint            = Vector2.new(1, 0)
cmdBtn.Size                   = UDim2.new(0, 54, 0, 22)
cmdBtn.Position               = UDim2.new(1, -6, 0, 40)
cmdBtn.BackgroundColor3       = Color3.fromRGB(18, 18, 26)
cmdBtn.BackgroundTransparency = 0.1
cmdBtn.BorderSizePixel        = 0
cmdBtn.Text                   = "[CMD]"
cmdBtn.Font                   = Enum.Font.GothamBold
cmdBtn.TextSize               = 10
cmdBtn.TextColor3             = C_ACC
cmdBtn.ZIndex                 = 5
corner(cmdBtn, 5)
stroke(cmdBtn, C_BOR, 1, 0.35)

-- ── Click-outside blocker ──────────────────────────────────────────────────────

local blocker = Instance.new("ImageButton", gui)
blocker.Size                   = UDim2.new(1, 0, 1, 0)
blocker.BackgroundTransparency = 1
blocker.ZIndex                 = 8
blocker.Visible                = false

-- ── Main bar panel ─────────────────────────────────────────────────────────────

local panel = Instance.new("Frame", gui)
panel.Name                   = "Panel"
panel.AnchorPoint            = Vector2.new(0.5, 0)
panel.Size                   = UDim2.new(0, BAR_W, 0, BAR_H)
panel.Position               = UDim2.new(0.5, 0, 0, BAR_Y_SHUT)
panel.BackgroundColor3       = C_BG
panel.BackgroundTransparency = 1
panel.BorderSizePixel        = 0
panel.Visible                = false
panel.ZIndex                 = 10
corner(panel)
local panelStroke = stroke(panel, C_BOR, 1.5)

local accentLine = Instance.new("Frame", panel)
accentLine.Size                   = UDim2.new(1, -2, 0, 2)
accentLine.Position               = UDim2.new(0, 1, 0, 0)
accentLine.BackgroundColor3       = C_ACC
accentLine.BackgroundTransparency = 1
accentLine.BorderSizePixel        = 0
accentLine.ZIndex                 = 11
corner(accentLine, 2)

local promptLbl = Instance.new("TextLabel", panel)
promptLbl.Size                   = UDim2.new(0, 30, 1, 0)
promptLbl.Position               = UDim2.new(0, 10, 0, 0)
promptLbl.BackgroundTransparency = 1
promptLbl.Font                   = Enum.Font.GothamBold
promptLbl.TextSize               = 18
promptLbl.TextColor3             = C_ACC
promptLbl.TextTransparency       = 1
promptLbl.Text                   = "›"
promptLbl.TextXAlignment         = Enum.TextXAlignment.Center
promptLbl.TextYAlignment         = Enum.TextYAlignment.Center
promptLbl.ZIndex                 = 11

local inputBox = Instance.new("TextBox", panel)
inputBox.Size                   = UDim2.new(1, -46, 1, 0)
inputBox.Position               = UDim2.new(0, 42, 0, 0)
inputBox.BackgroundTransparency = 1
inputBox.BorderSizePixel        = 0
inputBox.ClearTextOnFocus       = false
inputBox.Font                   = Enum.Font.Code
inputBox.TextSize               = 15
inputBox.TextColor3             = C_TXT
inputBox.TextTransparency       = 1
inputBox.PlaceholderText        = "Enter a command…"
inputBox.PlaceholderColor3      = C_DIM
inputBox.Text                   = ""
inputBox.TextXAlignment         = Enum.TextXAlignment.Left
inputBox.TextYAlignment         = Enum.TextYAlignment.Center
inputBox.ZIndex                 = 11

-- ── Autocomplete dropdown ──────────────────────────────────────────────────────

local dropdown = Instance.new("Frame", panel)
dropdown.Size                   = UDim2.new(1, 0, 0, 0)
dropdown.Position               = UDim2.new(0, 0, 1, 5)
dropdown.BackgroundColor3       = C_ACBG
dropdown.BackgroundTransparency = 0.06
dropdown.BorderSizePixel        = 0
dropdown.Visible                = false
dropdown.ClipsDescendants       = true
dropdown.ZIndex                 = 20
corner(dropdown)
stroke(dropdown, C_ABOR, 1, 0.4)
local dropLayout = Instance.new("UIListLayout", dropdown)
dropLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- ── Hint label ─────────────────────────────────────────────────────────────────

local hintFrame = Instance.new("Frame", panel)
hintFrame.Size                   = UDim2.new(1, -42, 0, 16)
hintFrame.Position               = UDim2.new(0, 42, 1, 3)
hintFrame.BackgroundTransparency = 1
hintFrame.BorderSizePixel        = 0
hintFrame.Visible                = false
hintFrame.ZIndex                 = 10

local hintLbl = Instance.new("TextLabel", hintFrame)
hintLbl.Size                   = UDim2.new(1, 0, 1, 0)
hintLbl.BackgroundTransparency = 1
hintLbl.Font                   = Enum.Font.Gotham
hintLbl.TextSize               = 11
hintLbl.TextColor3             = C_DIM
hintLbl.TextXAlignment         = Enum.TextXAlignment.Left
hintLbl.TextYAlignment         = Enum.TextYAlignment.Center
hintLbl.RichText               = true
hintLbl.ZIndex                 = 10

-- ── Notifications ──────────────────────────────────────────────────────────────

local notifGui = Instance.new("ScreenGui")
notifGui.Name           = "CmdNotifs"
notifGui.DisplayOrder   = 55
notifGui.ResetOnSpawn   = false
notifGui.IgnoreGuiInset = true
notifGui.Parent         = PlayerGui

local NW, NH, NM, NG = 240, 44, 14, 5
local notifs = {}

local function slotY(i) return -(NM + (i - 1) * (NH + NG)) end

local function reflow()
	for i, f in ipairs(notifs) do
		tw(f, 0.18, { Position = UDim2.new(1, -NM, 1, slotY(i)) })
	end
end

-- forward declare so it can be used before definition
showNotif = nil

showNotif = function(msg, col)
	while #notifs >= 5 do
		notifs[#notifs]:Destroy()
		table.remove(notifs)
	end
	local f = Instance.new("Frame", notifGui)
	f.AnchorPoint            = Vector2.new(1, 1)
	f.Size                   = UDim2.new(0, NW, 0, NH)
	f.Position               = UDim2.new(1, NW + NM, 1, slotY(1))
	f.BackgroundColor3       = C_BG
	f.BackgroundTransparency = 0.08
	f.BorderSizePixel        = 0
	f.ZIndex                 = 30
	corner(f, 6)
	stroke(f, C_BOR, 1, 0.3)

	local bar = Instance.new("Frame", f)
	bar.Size             = UDim2.new(0, 3, 1, -8)
	bar.Position         = UDim2.new(0, 4, 0, 4)
	bar.BackgroundColor3 = col or C_ACC
	bar.BorderSizePixel  = 0
	bar.ZIndex           = 31
	corner(bar, 2)

	local lbl = Instance.new("TextLabel", f)
	lbl.Size               = UDim2.new(1, -14, 1, 0)
	lbl.Position           = UDim2.new(0, 12, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font               = Enum.Font.GothamSemibold
	lbl.TextSize           = 11
	lbl.TextColor3         = C_TXT
	lbl.TextXAlignment     = Enum.TextXAlignment.Left
	lbl.TextYAlignment     = Enum.TextYAlignment.Center
	lbl.TextTruncate       = Enum.TextTruncate.AtEnd
	lbl.Text               = msg
	lbl.ZIndex             = 31

	for i, e in ipairs(notifs) do
		tw(e, 0.18, { Position = UDim2.new(1, -NM, 1, slotY(i + 1)) })
	end
	table.insert(notifs, 1, f)
	tw(f, 0.2, { Position = UDim2.new(1, -NM, 1, slotY(1)) })

	task.delay(4, function()
		local idx = table.find(notifs, f)
		if not idx then return end
		tw(f, 0.18, { Position = UDim2.new(1, NW + NM, 1, slotY(idx)) },
			Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		table.remove(notifs, idx)
		task.delay(0.22, function() f:Destroy() reflow() end)
	end)
end

-- ── Autocomplete ───────────────────────────────────────────────────────────────

local acRows = {}

local function clearDrop()
	for _, r in ipairs(acRows) do r.Visible = false end
end

local function getRow(i)
	if acRows[i] then return acRows[i] end
	local row = Instance.new("Frame", dropdown)
	row.LayoutOrder            = i
	row.Size                   = UDim2.new(1, 0, 0, AC_ROW_H)
	row.BackgroundColor3       = C_HOV
	row.BackgroundTransparency = 1
	row.BorderSizePixel        = 0
	row.ZIndex                 = 20

	local nl = Instance.new("TextLabel", row)
	nl.Name = "N"
	nl.Size = UDim2.new(0, 120, 1, 0)
	nl.Position = UDim2.new(0, 36, 0, 0)
	nl.BackgroundTransparency = 1
	nl.Font = Enum.Font.Code
	nl.TextSize = 12
	nl.TextColor3 = C_TXT
	nl.TextXAlignment = Enum.TextXAlignment.Left
	nl.TextYAlignment = Enum.TextYAlignment.Center
	nl.ZIndex = 21

	local dl = Instance.new("TextLabel", row)
	dl.Name = "D"
	dl.Size = UDim2.new(1, -122, 1, 0)
	dl.Position = UDim2.new(0, 122, 0, 0)
	dl.BackgroundTransparency = 1
	dl.Font = Enum.Font.Gotham
	dl.TextSize = 10
	dl.TextColor3 = Color3.fromRGB(110, 110, 128)
	dl.TextXAlignment = Enum.TextXAlignment.Left
	dl.TextYAlignment = Enum.TextYAlignment.Center
	dl.TextTruncate = Enum.TextTruncate.AtEnd
	dl.ZIndex = 21

	local btn = Instance.new("TextButton", row)
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.ZIndex = 22
	btn.MouseButton1Click:Connect(function()
		local m = acM[i]
		if m then
			inputBox.Text = m.name .. " "
			inputBox:CaptureFocus()
			task.defer(function() inputBox.CursorPosition = #inputBox.Text + 1 end)
		end
	end)
	btn.MouseEnter:Connect(function()
		acI = i
		for j, r in ipairs(acRows) do
			if r.Visible then
				tw(r, 0.05, { BackgroundTransparency = (j == acI) and 0.5 or 1 })
			end
		end
	end)

	acRows[i] = row
	return row
end

local function refreshDrop()
	clearDrop()
	local n = math.min(#acM, AC_MAX)
	if n == 0 then
		dropdown.Visible  = false
		hintFrame.Visible = false
		return
	end
	dropdown.Size    = UDim2.new(1, 0, 0, n * AC_ROW_H)
	dropdown.Visible = true
	for i = 1, n do
		local m   = acM[i]
		local row = getRow(i)
		row.Visible = true
		local sel = (i == acI)
		tw(row, 0.05, { BackgroundTransparency = sel and 0.5 or 1 })
		local nl = row:FindFirstChild("N")
		local dl = row:FindFirstChild("D")
		if nl then nl.Text = m.name; nl.TextColor3 = sel and Color3.new(1,1,1) or C_TXT end
		if dl then dl.Text = m.description or "" end
	end
	local sel = acM[acI]
	if sel and sel.args and #sel.args > 0 then
		local parts = { "<font color=\"#9898c8\">" .. sel.name .. "</font>" }
		for _, a in ipairs(sel.args) do
			local opt = a:sub(-1) == "?"
			local l   = opt and a:sub(1, -2) or a
			local c   = opt and "#444458" or "#646480"
			parts[#parts + 1] = "<font color=\"" .. c .. "\">"
				.. (opt and "[" or "<") .. l .. (opt and "]" or ">")
				.. "</font>"
		end
		hintLbl.Text      = table.concat(parts, "  ")
		hintFrame.Visible = true
	else
		hintFrame.Visible = false
	end
end

local function updateAC()
	if not CommandRegistry then return end
	local text   = inputBox.Text
	local tokens = CommandRegistry.parseArgs(text)
	local query  = tokens[1] or ""

	if text:find("%s") then
		local cmd = CommandRegistry.COMMANDS[query:lower()]
		acM = cmd and { { name = query:lower(), description = cmd.description, args = cmd.args } } or {}
		clearDrop()
		dropdown.Visible = false
		if cmd and #cmd.args > 0 then
			local parts = { "<font color=\"#9898c8\">" .. query:lower() .. "</font>" }
			for _, a in ipairs(cmd.args) do
				local opt = a:sub(-1) == "?"
				local l   = opt and a:sub(1, -2) or a
				local c   = opt and "#444458" or "#646480"
				parts[#parts + 1] = "<font color=\"" .. c .. "\">"
					.. (opt and "[" or "<") .. l .. (opt and "]" or ">")
					.. "</font>"
			end
			hintLbl.Text      = table.concat(parts, "  ")
			hintFrame.Visible = true
		else
			hintFrame.Visible = false
		end
		return
	end

	hintFrame.Visible = false
	if query == "" then acM = {}; refreshDrop(); return end
	acM = CommandRegistry.getMatches(query)
	acI = 1
	refreshDrop()
end

-- ── Open / Close ───────────────────────────────────────────────────────────────

local OI = TweenInfo.new(ANIM, Enum.EasingStyle.Expo, Enum.EasingDirection.Out)
local CI = TweenInfo.new(ANIM, Enum.EasingStyle.Expo, Enum.EasingDirection.In)

local function openBar()
	if isOpen then return end
	isOpen  = true
	histIdx = 0
	draft   = ""

	panel.Visible   = true
	blocker.Visible = true
	panel.Position  = UDim2.new(0.5, 0, 0, BAR_Y_SHUT)
	panel.BackgroundTransparency = 1

	TweenService:Create(panel, OI, {
		Position             = UDim2.new(0.5, 0, 0, BAR_Y_OPEN),
		BackgroundTransparency = 0.06,
	}):Play()
	tw(panelStroke, ANIM, { Transparency = 0.1 })
	tw(accentLine,  ANIM, { BackgroundTransparency = 0.2 })
	tw(promptLbl,   ANIM, { TextTransparency = 0 })
	tw(inputBox,    ANIM, { TextTransparency = 0 })

	task.delay(ANIM * 0.5, function()
		if isOpen then inputBox:CaptureFocus() end
	end)
end

local function closeBar()
	if not isOpen then return end
	isOpen  = false
	histIdx = 0

	dropdown.Visible  = false
	hintFrame.Visible = false
	blocker.Visible   = false

	TweenService:Create(panel, CI, {
		Position             = UDim2.new(0.5, 0, 0, BAR_Y_SHUT),
		BackgroundTransparency = 1,
	}):Play()
	tw(panelStroke, ANIM, { Transparency = 1 })
	tw(accentLine,  ANIM, { BackgroundTransparency = 1 })
	tw(promptLbl,   ANIM, { TextTransparency = 1 })
	tw(inputBox,    ANIM, { TextTransparency = 1 })

	task.delay(ANIM, function()
		if not isOpen then
			panel.Visible = false
			inputBox.Text = ""
			acM = {}
		end
	end)
	inputBox:ReleaseFocus()
end

-- ── Execute ────────────────────────────────────────────────────────────────────

local function executeCommand()
	local raw = inputBox.Text:match("^%s*(.-)%s*$")
	if raw == "" then closeBar() return end

	if not CommandRemotes or not CommandRegistry then
		showNotif("⚠ Still loading — try again in a moment", Color3.fromRGB(200, 160, 60))
		closeBar()
		return
	end

	local tokens  = CommandRegistry.parseArgs(raw)
	local cmdName = tokens[1] and tokens[1]:lower() or ""
	local args    = {}
	for i = 2, #tokens do table.insert(args, tokens[i]) end

	if history[1] ~= raw then
		table.insert(history, 1, raw)
		if #history > HIST_MAX then table.remove(history) end
	end

	CommandRemotes.CommandExecuted:FireServer(cmdName, args)
	showNotif("✓  " .. raw, C_ACC)
	closeBar()
end

-- ── TextBox events ─────────────────────────────────────────────────────────────

inputBox.Focused:Connect(function()  inputFocused = true  end)
inputBox.FocusLost:Connect(function(enter)
	inputFocused = false
	if enter then executeCommand() end
end)

inputBox:GetPropertyChangedSignal("Text"):Connect(function()
	if not isOpen then return end
	if inputBox.Text:find("\t") then
		local c = inputBox.Text:gsub("\t", "")
		inputBox.Text = c
		inputBox.CursorPosition = #c + 1
		return
	end
	updateAC()
end)

blocker.MouseButton1Click:Connect(function() closeBar() end)

cmdBtn.MouseButton1Click:Connect(function()
	if isOpen then closeBar() else openBar() end
end)

-- ── Key handler ────────────────────────────────────────────────────────────────

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end   -- don't fire when chat or other UI has focus

	for _, key in ipairs(OPEN_KEYS) do
		if input.KeyCode == key then
			if isOpen then closeBar() else openBar() end
			return
		end
	end

	if not isOpen then return end

	if input.KeyCode == Enum.KeyCode.Escape then closeBar() return end

	if not inputFocused then return end

	if input.KeyCode == Enum.KeyCode.Return then executeCommand() return end

	if input.KeyCode == Enum.KeyCode.Up then
		if histIdx == 0 then draft = inputBox.Text end
		histIdx = math.min(histIdx + 1, #history)
		if history[histIdx] then
			inputBox.Text = history[histIdx]
			task.defer(function() inputBox.CursorPosition = #inputBox.Text + 1 end)
		end
		return
	end

	if input.KeyCode == Enum.KeyCode.Down then
		if histIdx > 0 then
			histIdx -= 1
			inputBox.Text = histIdx == 0 and draft or history[histIdx]
			task.defer(function() inputBox.CursorPosition = #inputBox.Text + 1 end)
		end
		return
	end

	if input.KeyCode == Enum.KeyCode.Tab then
		if #acM > 0 then
			local m = acM[acI] or acM[1]
			if m then
				inputBox.Text = m.name .. " "
				task.defer(function() inputBox.CursorPosition = #inputBox.Text + 1 end)
			end
		end
		return
	end
end)

-- ── Startup toast ──────────────────────────────────────────────────────────────
-- If you see this in-game, the latest script version is running.

task.delay(0.5, function()
	showNotif("CMD bar ready  ·  ; or ' or [CMD]")
end)

print("[CommandBar] Script loaded — handlers connected immediately.")
