--[[
	CommandBar.client.lua
	LocalScript — StarterPlayerScripts

	Controls:
	  ; or '   — open the command bar
	  Escape    — close
	  Enter     — execute
	  Up/Down   — history
	  Tab       — autocomplete
	  Click [CMD] button — always-available open
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- Load remotes synchronously — server creates them first, so WaitForChild is instant.
local CommandRemotes  = require(ReplicatedStorage:WaitForChild("CommandRemotes"))
local CommandRegistry = require(ReplicatedStorage:WaitForChild("CommandRegistry"))

-- ─── Config ────────────────────────────────────────────────────────────────────

local CFG = {
	OPEN_KEYS        = { Enum.KeyCode.Semicolon, Enum.KeyCode.Quote },
	BAR_WIDTH        = 560,
	BAR_HEIGHT       = 50,
	BAR_Y_OPEN       = 80,
	BAR_Y_CLOSED     = 56,
	BAR_CORNER       = 8,
	BG_DARK          = Color3.fromRGB(10, 10, 13),
	BG_BORDER        = Color3.fromRGB(85, 85, 100),
	BG_TRANS_OPEN    = 0.06,
	PROMPT_COLOR     = Color3.fromRGB(180, 180, 205),
	TEXT_COLOR       = Color3.fromRGB(235, 235, 250),
	PLACEHOLDER_COLOR= Color3.fromRGB(85, 85, 102),
	HINT_COLOR       = Color3.fromRGB(105, 105, 122),
	AC_BG            = Color3.fromRGB(12, 12, 15),
	AC_HOVER_BG      = Color3.fromRGB(26, 26, 33),
	AC_BORDER        = Color3.fromRGB(70, 70, 88),
	AC_DESC_COLOR    = Color3.fromRGB(110, 110, 128),
	FONT             = Enum.Font.GothamSemibold,
	FONT_MONO        = Enum.Font.Code,
	TEXT_SIZE        = 15,
	ANIM_TIME        = 0.18,
	HISTORY_MAX      = 80,
	AC_MAX           = 6,
	AC_ROW_H         = 32,
}

-- ─── State ─────────────────────────────────────────────────────────────────────

local isOpen       = false
local inputFocused = false
local history      = {}
local historyIndex = 0
local savedDraft   = ""
local acMatches    = {}
local acIndex      = 1

-- ─── Helpers ───────────────────────────────────────────────────────────────────

local function tw(obj, t, props, style, dir)
	TweenService:Create(obj,
		TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		props):Play()
end

local function uiCorner(parent, r)
	local c = Instance.new("UICorner", parent)
	c.CornerRadius = UDim.new(0, r or CFG.BAR_CORNER)
	return c
end

local function uiStroke(parent, col, th)
	local s = Instance.new("UIStroke", parent)
	s.Color = col  s.Thickness = th or 1.3
	s.Transparency = 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return s
end

-- ─── Root ScreenGui ────────────────────────────────────────────────────────────
-- Single ScreenGui, IgnoreGuiInset=true so we control exact Y position.
local gui = Instance.new("ScreenGui")
gui.Name           = "StaffCommandBar"
gui.DisplayOrder   = 50
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.Enabled        = true
gui.Parent         = PlayerGui

-- ── [CMD] open button (positioned below the topbar at Y=40) ───────────────────
local cmdBtn = Instance.new("TextButton", gui)
cmdBtn.Name                   = "CmdBtn"
cmdBtn.AnchorPoint            = Vector2.new(1, 0)
cmdBtn.Size                   = UDim2.new(0, 54, 0, 21)
cmdBtn.Position               = UDim2.new(1, -6, 0, 40)   -- Y=40 clears the Roblox topbar
cmdBtn.BackgroundColor3       = Color3.fromRGB(20, 20, 28)
cmdBtn.BackgroundTransparency = 0.2
cmdBtn.BorderSizePixel        = 0
cmdBtn.Text                   = "[CMD]"
cmdBtn.Font                   = Enum.Font.GothamBold
cmdBtn.TextSize               = 10
cmdBtn.TextColor3             = CFG.PROMPT_COLOR
cmdBtn.ZIndex                 = 5
uiCorner(cmdBtn, 5)
uiStroke(cmdBtn, CFG.BG_BORDER, 1).Transparency = 0.4

-- Click-outside blocker
local blocker = Instance.new("ImageButton", gui)
blocker.Size                   = UDim2.new(1, 0, 1, 0)
blocker.BackgroundTransparency = 1
blocker.ZIndex                 = 8
blocker.Visible                = false

-- ── Main bar panel ─────────────────────────────────────────────────────────────
local panel = Instance.new("Frame", gui)
panel.Name                    = "Panel"
panel.AnchorPoint             = Vector2.new(0.5, 0)
panel.Size                    = UDim2.new(0, CFG.BAR_WIDTH, 0, CFG.BAR_HEIGHT)
panel.Position                = UDim2.new(0.5, 0, 0, CFG.BAR_Y_CLOSED)
panel.BackgroundColor3        = CFG.BG_DARK
panel.BackgroundTransparency  = 1
panel.BorderSizePixel         = 0
panel.Visible                 = false
panel.ZIndex                  = 10
uiCorner(panel)
local panelStroke = uiStroke(panel, CFG.BG_BORDER, 1.5)

-- Top accent stripe
local accentLine = Instance.new("Frame", panel)
accentLine.Size                   = UDim2.new(1, -2, 0, 2)
accentLine.Position               = UDim2.new(0, 1, 0, 0)
accentLine.BackgroundColor3       = CFG.PROMPT_COLOR
accentLine.BackgroundTransparency = 1
accentLine.BorderSizePixel        = 0
accentLine.ZIndex                 = 11
uiCorner(accentLine, 2)

-- Prompt glyph
local promptLabel = Instance.new("TextLabel", panel)
promptLabel.Size                   = UDim2.new(0, 30, 1, 0)
promptLabel.Position               = UDim2.new(0, 10, 0, 0)
promptLabel.BackgroundTransparency = 1
promptLabel.Font                   = CFG.FONT
promptLabel.TextSize               = 18
promptLabel.TextColor3             = CFG.PROMPT_COLOR
promptLabel.TextTransparency       = 1
promptLabel.Text                   = "›"
promptLabel.TextXAlignment         = Enum.TextXAlignment.Center
promptLabel.TextYAlignment         = Enum.TextYAlignment.Center
promptLabel.ZIndex                 = 11

-- Input box
local inputBox = Instance.new("TextBox", panel)
inputBox.Size                   = UDim2.new(1, -46, 1, 0)
inputBox.Position               = UDim2.new(0, 42, 0, 0)
inputBox.BackgroundTransparency = 1
inputBox.BorderSizePixel        = 0
inputBox.ClearTextOnFocus       = false
inputBox.Font                   = CFG.FONT_MONO
inputBox.TextSize               = CFG.TEXT_SIZE
inputBox.TextColor3             = CFG.TEXT_COLOR
inputBox.TextTransparency       = 1
inputBox.PlaceholderText        = "Enter a command…"
inputBox.PlaceholderColor3      = CFG.PLACEHOLDER_COLOR
inputBox.Text                   = ""
inputBox.TextXAlignment         = Enum.TextXAlignment.Left
inputBox.TextYAlignment         = Enum.TextYAlignment.Center
inputBox.ZIndex                 = 11

-- Autocomplete dropdown
local dropdown = Instance.new("Frame", panel)
dropdown.Size                   = UDim2.new(1, 0, 0, 0)
dropdown.Position               = UDim2.new(0, 0, 1, 5)
dropdown.BackgroundColor3       = CFG.AC_BG
dropdown.BackgroundTransparency = 0.06
dropdown.BorderSizePixel        = 0
dropdown.Visible                = false
dropdown.ClipsDescendants       = true
dropdown.ZIndex                 = 20
uiCorner(dropdown)
uiStroke(dropdown, CFG.AC_BORDER, 1).Transparency = 0.4
local dropLayout = Instance.new("UIListLayout", dropdown)
dropLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Hint label (shows argument spec below bar)
local hintFrame = Instance.new("Frame", panel)
hintFrame.Size                   = UDim2.new(1, -42, 0, 16)
hintFrame.Position               = UDim2.new(0, 42, 1, 3)
hintFrame.BackgroundTransparency = 1
hintFrame.BorderSizePixel        = 0
hintFrame.Visible                = false
hintFrame.ZIndex                 = 10

local hintLabel = Instance.new("TextLabel", hintFrame)
hintLabel.Size                   = UDim2.new(1, 0, 1, 0)
hintLabel.BackgroundTransparency = 1
hintLabel.Font                   = Enum.Font.Gotham
hintLabel.TextSize               = 11
hintLabel.TextColor3             = CFG.HINT_COLOR
hintLabel.TextXAlignment         = Enum.TextXAlignment.Left
hintLabel.TextYAlignment         = Enum.TextYAlignment.Center
hintLabel.RichText               = true
hintLabel.ZIndex                 = 10

-- ─── Notifications (bottom-right) ──────────────────────────────────────────────

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

local function showNotif(msg, col)
	while #notifs >= 5 do notifs[#notifs]:Destroy(); table.remove(notifs) end
	local f = Instance.new("Frame", notifGui)
	f.AnchorPoint            = Vector2.new(1, 1)
	f.Size                   = UDim2.new(0, NW, 0, NH)
	f.Position               = UDim2.new(1, NW + NM, 1, slotY(1))
	f.BackgroundColor3       = CFG.BG_DARK
	f.BackgroundTransparency = 0.08
	f.BorderSizePixel        = 0
	f.ZIndex                 = 30
	uiCorner(f, 6)
	uiStroke(f, CFG.BG_BORDER, 1).Transparency = 0.3
	local bar2 = Instance.new("Frame", f)
	bar2.Size = UDim2.new(0, 3, 1, -8)
	bar2.Position = UDim2.new(0, 4, 0, 4)
	bar2.BackgroundColor3 = col or CFG.PROMPT_COLOR
	bar2.BorderSizePixel = 0
	bar2.ZIndex = 31
	uiCorner(bar2, 2)
	local lbl = Instance.new("TextLabel", f)
	lbl.Size = UDim2.new(1, -14, 1, 0)
	lbl.Position = UDim2.new(0, 12, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamSemibold
	lbl.TextSize = 11
	lbl.TextColor3 = CFG.TEXT_COLOR
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextYAlignment = Enum.TextYAlignment.Center
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
	lbl.Text = msg
	lbl.ZIndex = 31
	for i, e in ipairs(notifs) do
		tw(e, 0.18, { Position = UDim2.new(1, -NM, 1, slotY(i + 1)) })
	end
	table.insert(notifs, 1, f)
	tw(f, 0.2, { Position = UDim2.new(1, -NM, 1, slotY(1)) })
	task.delay(4, function()
		local idx = table.find(notifs, f)
		if not idx then return end
		tw(f, 0.18, { Position = UDim2.new(1, NW + NM, 1, slotY(idx)) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		table.remove(notifs, idx)
		task.delay(0.22, function() f:Destroy() reflow() end)
	end)
end

-- ─── Autocomplete rows ─────────────────────────────────────────────────────────

local acRows = {}

local function clearDropdown()
	for _, r in ipairs(acRows) do r.Visible = false end
end

local function getAcRow(i)
	if acRows[i] then return acRows[i] end
	local row = Instance.new("Frame", dropdown)
	row.LayoutOrder            = i
	row.Size                   = UDim2.new(1, 0, 0, CFG.AC_ROW_H)
	row.BackgroundColor3       = CFG.AC_HOVER_BG
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
	nl.TextColor3 = CFG.TEXT_COLOR
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
	dl.TextColor3 = CFG.AC_DESC_COLOR
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
		local m = acMatches[i]
		if m then
			inputBox.Text = m.name .. " "
			inputBox:CaptureFocus()
			task.defer(function() inputBox.CursorPosition = #inputBox.Text + 1 end)
		end
	end)
	btn.MouseEnter:Connect(function()
		acIndex = i
		for j, r in ipairs(acRows) do
			if r.Visible then
				tw(r, 0.05, { BackgroundTransparency = (j == acIndex) and 0.5 or 1 })
			end
		end
	end)

	acRows[i] = row
	return row
end

local function refreshDropdown()
	clearDropdown()
	local n = math.min(#acMatches, CFG.AC_MAX)
	if n == 0 then
		dropdown.Visible = false
		hintFrame.Visible = false
		return
	end
	dropdown.Size    = UDim2.new(1, 0, 0, n * CFG.AC_ROW_H)
	dropdown.Visible = true
	for i = 1, n do
		local m   = acMatches[i]
		local row = getAcRow(i)
		row.Visible = true
		local sel = (i == acIndex)
		tw(row, 0.05, { BackgroundTransparency = sel and 0.5 or 1 })
		local nl = row:FindFirstChild("N")
		local dl = row:FindFirstChild("D")
		if nl then nl.Text = m.name; nl.TextColor3 = sel and Color3.new(1,1,1) or CFG.TEXT_COLOR end
		if dl then dl.Text = m.description or "" end
	end
	local sel = acMatches[acIndex]
	if sel and sel.args and #sel.args > 0 then
		local parts = { "<font color=\"#9898c8\">" .. sel.name .. "</font>" }
		for _, a in ipairs(sel.args) do
			local opt = a:sub(-1) == "?"
			local l   = opt and a:sub(1, -2) or a
			local c   = opt and "#444458" or "#6464800"
			parts[#parts + 1] = "<font color=\"" .. c .. "\">" .. (opt and "[" or "<") .. l .. (opt and "]" or ">") .. "</font>"
		end
		hintLabel.Text  = table.concat(parts, "  ")
		hintFrame.Visible = true
	else
		hintFrame.Visible = false
	end
end

local function updateAutocomplete()
	local text   = inputBox.Text
	local tokens = CommandRegistry.parseArgs(text)
	local query  = tokens[1] or ""
	if text:find("%s") then
		local cmd = CommandRegistry.COMMANDS[query:lower()]
		acMatches = cmd and { { name = query:lower(), description = cmd.description, args = cmd.args } } or {}
		clearDropdown()
		dropdown.Visible = false
		if cmd and #cmd.args > 0 then
			local parts = { "<font color=\"#9898c8\">" .. query:lower() .. "</font>" }
			for _, a in ipairs(cmd.args) do
				local opt = a:sub(-1) == "?"
				local l   = opt and a:sub(1, -2) or a
				local c   = opt and "#444458" or "#646480"
				parts[#parts + 1] = "<font color=\"" .. c .. "\">" .. (opt and "[" or "<") .. l .. (opt and "]" or ">") .. "</font>"
			end
			hintLabel.Text  = table.concat(parts, "  ")
			hintFrame.Visible = true
		else
			hintFrame.Visible = false
		end
		return
	end
	hintFrame.Visible = false
	if query == "" then
		acMatches = {}
		refreshDropdown()
		return
	end
	acMatches = CommandRegistry.getMatches(query)
	acIndex   = 1
	refreshDropdown()
end

-- ─── Open / Close ──────────────────────────────────────────────────────────────

local openTInfo  = TweenInfo.new(CFG.ANIM_TIME, Enum.EasingStyle.Expo, Enum.EasingDirection.Out)
local closeTInfo = TweenInfo.new(CFG.ANIM_TIME, Enum.EasingStyle.Expo, Enum.EasingDirection.In)

local function openBar()
	if isOpen then return end
	isOpen       = true
	historyIndex = 0
	savedDraft   = ""

	panel.Visible   = true
	blocker.Visible = true
	panel.Position  = UDim2.new(0.5, 0, 0, CFG.BAR_Y_CLOSED)
	panel.BackgroundTransparency = 1

	TweenService:Create(panel, openTInfo, {
		Position             = UDim2.new(0.5, 0, 0, CFG.BAR_Y_OPEN),
		BackgroundTransparency = CFG.BG_TRANS_OPEN,
	}):Play()
	tw(panelStroke, CFG.ANIM_TIME, { Transparency = 0.1 })
	tw(accentLine,  CFG.ANIM_TIME, { BackgroundTransparency = 0.2 })
	tw(promptLabel, CFG.ANIM_TIME, { TextTransparency = 0 })
	tw(inputBox,    CFG.ANIM_TIME, { TextTransparency = 0 })

	task.delay(CFG.ANIM_TIME * 0.5, function()
		if isOpen then inputBox:CaptureFocus() end
	end)
end

local function closeBar()
	if not isOpen then return end
	isOpen       = false
	historyIndex = 0

	dropdown.Visible  = false
	hintFrame.Visible = false
	blocker.Visible   = false

	TweenService:Create(panel, closeTInfo, {
		Position             = UDim2.new(0.5, 0, 0, CFG.BAR_Y_CLOSED),
		BackgroundTransparency = 1,
	}):Play()
	tw(panelStroke, CFG.ANIM_TIME, { Transparency = 1 })
	tw(accentLine,  CFG.ANIM_TIME, { BackgroundTransparency = 1 })
	tw(promptLabel, CFG.ANIM_TIME, { TextTransparency = 1 })
	tw(inputBox,    CFG.ANIM_TIME, { TextTransparency = 1 })

	task.delay(CFG.ANIM_TIME, function()
		if not isOpen then
			panel.Visible = false
			inputBox.Text = ""
			acMatches     = {}
		end
	end)

	inputBox:ReleaseFocus()
end

-- ─── Execute ───────────────────────────────────────────────────────────────────

local function executeCommand()
	local raw = inputBox.Text:match("^%s*(.-)%s*$")
	if raw == "" then closeBar() return end

	local tokens  = CommandRegistry.parseArgs(raw)
	local cmdName = tokens[1] and tokens[1]:lower() or ""
	local args    = {}
	for i = 2, #tokens do table.insert(args, tokens[i]) end

	if history[1] ~= raw then
		table.insert(history, 1, raw)
		if #history > CFG.HISTORY_MAX then table.remove(history) end
	end

	CommandRemotes.CommandExecuted:FireServer(cmdName, args)
	showNotif("✓  " .. raw)
	closeBar()
end

-- ─── TextBox events ────────────────────────────────────────────────────────────

inputBox.Focused:Connect(function()    inputFocused = true  end)
inputBox.FocusLost:Connect(function(enter)
	inputFocused = false
	if enter then executeCommand() end
end)

inputBox:GetPropertyChangedSignal("Text"):Connect(function()
	if not isOpen then return end
	if inputBox.Text:find("\t") then
		local cleaned = inputBox.Text:gsub("\t", "")
		inputBox.Text = cleaned
		inputBox.CursorPosition = #cleaned + 1
		return
	end
	updateAutocomplete()
end)

blocker.MouseButton1Click:Connect(function() closeBar() end)

cmdBtn.MouseButton1Click:Connect(function()
	if isOpen then closeBar() else openBar() end
end)

-- ─── Input handler ─────────────────────────────────────────────────────────────

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- Open keys: fire only when no UI element has focus (not gameProcessed)
	for _, key in ipairs(CFG.OPEN_KEYS) do
		if input.KeyCode == key and not gameProcessed then
			if isOpen then closeBar() else openBar() end
			return
		end
	end

	if not isOpen then return end

	if input.KeyCode == Enum.KeyCode.Escape then
		closeBar()
		return
	end

	if not inputFocused then return end

	if input.KeyCode == Enum.KeyCode.Return then
		executeCommand()
		return
	end

	if input.KeyCode == Enum.KeyCode.Up then
		if historyIndex == 0 then savedDraft = inputBox.Text end
		historyIndex = math.min(historyIndex + 1, #history)
		if history[historyIndex] then
			inputBox.Text = history[historyIndex]
			task.defer(function() inputBox.CursorPosition = #inputBox.Text + 1 end)
		end
		return
	end

	if input.KeyCode == Enum.KeyCode.Down then
		if historyIndex > 0 then
			historyIndex -= 1
			inputBox.Text = historyIndex == 0 and savedDraft or history[historyIndex]
			task.defer(function() inputBox.CursorPosition = #inputBox.Text + 1 end)
		end
		return
	end

	if input.KeyCode == Enum.KeyCode.Tab then
		if #acMatches > 0 then
			local match = acMatches[acIndex] or acMatches[1]
			if match then
				inputBox.Text = match.name .. " "
				task.defer(function() inputBox.CursorPosition = #inputBox.Text + 1 end)
			end
		end
		return
	end
end)

-- ─── Startup toast ─────────────────────────────────────────────────────────────
-- Confirms this version of the script is running in Studio.
-- If you do NOT see this, the script hasn't synced to Studio yet.
task.delay(0.8, function()
	showNotif("CMD bar ready  ·  ; or ' or [CMD]")
end)

print("[CommandBar] Loaded — press ; or ' or click [CMD]")
