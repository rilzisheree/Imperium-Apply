--!strict
--[[
	CommandBar.client.lua  ·  LocalScript → StarterPlayerScripts

	Opens with:
	  • ' (apostrophe) key          – keyboard shortcut
	  • ; (semicolon)  key          – alternative shortcut
	  • Click the [CMD] button       – always-visible top-right button
	  • Escape to close
	  • Enter to execute
]]

-- ── Services ───────────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")

local LP      = Players.LocalPlayer
local PGui    = LP:WaitForChild("PlayerGui")

-- Loaded async – never block startup
local Remotes   : any = nil
local Registry  : any = nil

-- ── State ──────────────────────────────────────────────────────────────────────
local open    = false
local focused = false
local hist : {string} = {}
local hIdx  = 0
local draft = ""
local acM : {any} = {}
local acI   = 1

-- ── Colours ────────────────────────────────────────────────────────────────────
local BG   = Color3.fromRGB(12, 12, 16)
local FG   = Color3.fromRGB(228, 228, 245)
local DIM  = Color3.fromRGB(90,  90, 110)
local ACC  = Color3.fromRGB(160, 160, 210)
local BOR  = Color3.fromRGB(70,  70,  90)
local ACbg = Color3.fromRGB(16,  16,  22)
local HOV  = Color3.fromRGB(30,  30,  42)

-- ── Tween helper ───────────────────────────────────────────────────────────────
local function tw(obj, t, props, style, dir)
	TweenService:Create(obj,
		TweenInfo.new(t,
			style or Enum.EasingStyle.Quint,
			dir   or Enum.EasingDirection.Out),
		props):Play()
end

-- ── Helper: make UICorner ──────────────────────────────────────────────────────
local function corner(p, r)
	local c = Instance.new("UICorner", p)
	c.CornerRadius = UDim.new(0, r or 7)
end

-- ── Helper: make UIStroke ──────────────────────────────────────────────────────
local function stroke(p, col, th, tr)
	local s = Instance.new("UIStroke", p)
	s.Color = col  s.Thickness = th or 1.2
	s.Transparency = tr or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return s
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- GUI 1 – trigger button  (IgnoreGuiInset=false → safely below CoreGui topbar)
-- ═══════════════════════════════════════════════════════════════════════════════
local btnGui = Instance.new("ScreenGui")
btnGui.Name           = "CmdTrigger"
btnGui.DisplayOrder   = 60
btnGui.ResetOnSpawn   = false
btnGui.IgnoreGuiInset = false   -- positions below the Roblox topbar
btnGui.Parent         = PGui

local trigBtn = Instance.new("TextButton", btnGui)
trigBtn.Name                   = "Open"
trigBtn.AnchorPoint            = Vector2.new(1, 0)
trigBtn.Size                   = UDim2.new(0, 58, 0, 22)
trigBtn.Position               = UDim2.new(1, -6, 0, 6)
trigBtn.BackgroundColor3       = Color3.fromRGB(22, 22, 32)
trigBtn.BackgroundTransparency = 0.15
trigBtn.BorderSizePixel        = 0
trigBtn.Text                   = "[CMD]"
trigBtn.Font                   = Enum.Font.GothamBold
trigBtn.TextSize               = 11
trigBtn.TextColor3             = ACC
trigBtn.ZIndex                 = 10
corner(trigBtn, 5)
stroke(trigBtn, BOR, 1, 0.3)

-- ═══════════════════════════════════════════════════════════════════════════════
-- GUI 2 – command bar  (IgnoreGuiInset=true → we place it manually)
-- ═══════════════════════════════════════════════════════════════════════════════
local barGui = Instance.new("ScreenGui")
barGui.Name           = "StaffCommandBar"
barGui.DisplayOrder   = 80
barGui.ResetOnSpawn   = false
barGui.IgnoreGuiInset = true
barGui.Parent         = PGui

-- Blocker (click-outside to close)
local blocker = Instance.new("ImageButton", barGui)
blocker.Size                   = UDim2.new(1,0,1,0)
blocker.BackgroundTransparency = 1
blocker.ZIndex                 = 5
blocker.Visible                = false

-- Main bar frame
local bar = Instance.new("Frame", barGui)
bar.Name                   = "Bar"
bar.AnchorPoint            = Vector2.new(0.5, 0)
bar.Size                   = UDim2.new(0, 520, 0, 44)
bar.Position               = UDim2.new(0.5, 0, 0, 36)   -- below topbar
bar.BackgroundColor3       = BG
bar.BackgroundTransparency = 1
bar.BorderSizePixel        = 0
bar.Visible                = false
bar.ZIndex                 = 10
corner(bar)
local barStroke = stroke(bar, BOR, 1.4, 1)

-- Top accent stripe
local stripe = Instance.new("Frame", bar)
stripe.Size                   = UDim2.new(1,-2,0,2)
stripe.Position               = UDim2.new(0,1,0,0)
stripe.BackgroundColor3       = ACC
stripe.BackgroundTransparency = 1
stripe.BorderSizePixel        = 0
stripe.ZIndex                 = 11
corner(stripe, 2)

-- Prompt glyph
local glyph = Instance.new("TextLabel", bar)
glyph.Size                   = UDim2.new(0,26,1,0)
glyph.Position               = UDim2.new(0,9,0,0)
glyph.BackgroundTransparency = 1
glyph.Font                   = Enum.Font.GothamBold
glyph.TextSize               = 16
glyph.TextColor3             = ACC
glyph.TextTransparency       = 1
glyph.Text                   = "›"
glyph.ZIndex                 = 11

-- Input
local input = Instance.new("TextBox", bar)
input.Size                   = UDim2.new(1,-42,1,-10)
input.Position               = UDim2.new(0,38,0,5)
input.BackgroundTransparency = 1
input.BorderSizePixel        = 0
input.ClearTextOnFocus       = false
input.Font                   = Enum.Font.Code
input.TextSize               = 14
input.TextColor3             = FG
input.TextTransparency       = 1
input.PlaceholderText        = "command…"
input.PlaceholderColor3      = DIM
input.Text                   = ""
input.TextXAlignment         = Enum.TextXAlignment.Left
input.ZIndex                 = 11

-- Autocomplete dropdown
local drop = Instance.new("Frame", bar)
drop.Size                   = UDim2.new(1,0,0,0)
drop.Position               = UDim2.new(0,0,1,4)
drop.BackgroundColor3       = ACbg
drop.BackgroundTransparency = 0.06
drop.BorderSizePixel        = 0
drop.Visible                = false
drop.ClipsDescendants       = true
drop.ZIndex                 = 20
corner(drop)
stroke(drop, BOR, 1, 0.4)
local dropLayout = Instance.new("UIListLayout", drop)
dropLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Hint label
local hintLbl = Instance.new("TextLabel", bar)
hintLbl.Size                   = UDim2.new(1,-40,0,14)
hintLbl.Position               = UDim2.new(0,38,1,3)
hintLbl.BackgroundTransparency = 1
hintLbl.Font                   = Enum.Font.Gotham
hintLbl.TextSize               = 10
hintLbl.TextColor3             = DIM
hintLbl.TextXAlignment         = Enum.TextXAlignment.Left
hintLbl.RichText               = true
hintLbl.Visible                = false
hintLbl.ZIndex                 = 10

-- ═══════════════════════════════════════════════════════════════════════════════
-- GUI 3 – notifications
-- ═══════════════════════════════════════════════════════════════════════════════
local notifGui = Instance.new("ScreenGui")
notifGui.Name           = "CmdNotifs"
notifGui.DisplayOrder   = 85
notifGui.ResetOnSpawn   = false
notifGui.IgnoreGuiInset = false
notifGui.Parent         = PGui

local NW, NH, NM, NG = 230, 42, 10, 4
local notifs: {Frame} = {}

local function slotY(i) return -(NM+(i-1)*(NH+NG)) end
local function reflow()
	for i,f in ipairs(notifs) do
		tw(f,.18,{Position=UDim2.new(1,-NM,1,slotY(i))})
	end
end

local function notify(msg, col)
	while #notifs >= 5 do notifs[#notifs]:Destroy(); table.remove(notifs) end
	local f = Instance.new("Frame", notifGui)
	f.AnchorPoint            = Vector2.new(1,1)
	f.Size                   = UDim2.new(0,NW,0,NH)
	f.Position               = UDim2.new(1,NW+NM,1,slotY(1))
	f.BackgroundColor3       = BG
	f.BackgroundTransparency = 0.08
	f.BorderSizePixel        = 0
	f.ZIndex                 = 30
	corner(f, 6)
	stroke(f, BOR, 1, 0.3)
	local b=Instance.new("Frame",f)
	b.Size=UDim2.new(0,3,1,-8) b.Position=UDim2.new(0,4,0,4)
	b.BackgroundColor3=col or ACC b.BorderSizePixel=0 b.ZIndex=31
	corner(b,2)
	local l=Instance.new("TextLabel",f)
	l.Size=UDim2.new(1,-14,1,0) l.Position=UDim2.new(0,12,0,0)
	l.BackgroundTransparency=1 l.Font=Enum.Font.GothamSemibold
	l.TextSize=11 l.TextColor3=FG l.TextXAlignment=Enum.TextXAlignment.Left
	l.TextYAlignment=Enum.TextYAlignment.Center
	l.TextTruncate=Enum.TextTruncate.AtEnd l.Text=msg l.ZIndex=31
	for i,e in ipairs(notifs) do tw(e,.18,{Position=UDim2.new(1,-NM,1,slotY(i+1))}) end
	table.insert(notifs,1,f)
	tw(f,.2,{Position=UDim2.new(1,-NM,1,slotY(1))})
	task.delay(4,function()
		local idx=table.find(notifs,f) if not idx then return end
		tw(f,.18,{Position=UDim2.new(1,NW+NM,1,slotY(idx))},Enum.EasingStyle.Quint,Enum.EasingDirection.In)
		table.remove(notifs,idx)
		task.delay(.22,function() f:Destroy() reflow() end)
	end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Autocomplete rows
-- ═══════════════════════════════════════════════════════════════════════════════
local ROW_H = 28
local rows: {Frame} = {}

local function clearDrop()
	for _,r in rows do r.Visible=false end
end

local function getRow(i)
	if rows[i] then return rows[i] end
	local r = Instance.new("Frame", drop)
	r.Name=tostring(i) r.LayoutOrder=i
	r.Size=UDim2.new(1,0,0,ROW_H)
	r.BackgroundColor3=HOV r.BackgroundTransparency=1
	r.BorderSizePixel=0 r.ZIndex=20

	local n=Instance.new("TextLabel",r)
	n.Name="N" n.Size=UDim2.new(0,120,1,0) n.Position=UDim2.new(0,36,0,0)
	n.BackgroundTransparency=1 n.Font=Enum.Font.Code n.TextSize=12
	n.TextColor3=FG n.TextXAlignment=Enum.TextXAlignment.Left
	n.TextYAlignment=Enum.TextYAlignment.Center n.ZIndex=21

	local d=Instance.new("TextLabel",r)
	d.Name="D" d.Size=UDim2.new(1,-122,1,0) d.Position=UDim2.new(0,122,0,0)
	d.BackgroundTransparency=1 d.Font=Enum.Font.Gotham d.TextSize=10
	d.TextColor3=DIM d.TextXAlignment=Enum.TextXAlignment.Left
	d.TextYAlignment=Enum.TextYAlignment.Center
	d.TextTruncate=Enum.TextTruncate.AtEnd d.ZIndex=21

	local btn=Instance.new("TextButton",r)
	btn.Size=UDim2.new(1,0,1,0) btn.BackgroundTransparency=1 btn.Text="" btn.ZIndex=22
	btn.MouseButton1Click:Connect(function()
		local m=acM[i] if not m then return end
		input.Text=m.name.." "
		input:CaptureFocus()
		task.defer(function() input.CursorPosition=#input.Text+1 end)
	end)
	btn.MouseEnter:Connect(function()
		acI=i
		for j,row in rows do
			if row and row.Visible then
				tw(row,.05,{BackgroundTransparency=(j==acI)and.5 or 1})
			end
		end
	end)
	rows[i]=r
	return r
end

local function refreshDrop()
	clearDrop()
	local n=math.min(#acM,6)
	if n==0 then drop.Visible=false hintLbl.Visible=false return end
	drop.Size=UDim2.new(1,0,0,n*ROW_H) drop.Visible=true
	for i=1,n do
		local m=acM[i] local r=getRow(i) r.Visible=true
		local sel=(i==acI)
		tw(r,.05,{BackgroundTransparency=sel and .5 or 1})
		local nL=r:FindFirstChild("N") local dL=r:FindFirstChild("D")
		if nL then nL.Text=m.name nL.TextColor3=sel and Color3.new(1,1,1) or FG end
		if dL then dL.Text=m.description or "" end
	end
	local s=acM[acI]
	if s and s.args and #s.args>0 then
		local p={"<font color=\"#9999cc\">"..s.name.."</font>"}
		for _,a in s.args do
			local opt=a:sub(-1)=="?" local l=opt and a:sub(1,-2) or a
			local c=opt and "#44445a" or "#66667c"
			p[#p+1]="<font color=\""..c.."\">".. (opt and "["or"<") ..l.. (opt and "]"or">") .."</font>"
		end
		hintLbl.Text=table.concat(p,"  ") hintLbl.Visible=true
	else
		hintLbl.Visible=false
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Autocomplete update
-- ═══════════════════════════════════════════════════════════════════════════════
local function updateAC()
	if not Registry then return end
	local t=input.Text
	local toks=Registry.parseArgs(t)
	local q=toks[1] or ""
	if t:find("%s") then
		local cmd=Registry.COMMANDS[q:lower()]
		acM=cmd and {{name=q:lower(),description=cmd.description,args=cmd.args}} or {}
		clearDrop() drop.Visible=false
		if cmd and #cmd.args>0 then
			local p={"<font color=\"#9999cc\">"..q:lower().."</font>"}
			for _,a in cmd.args do
				local opt=a:sub(-1)=="?" local l=opt and a:sub(1,-2) or a
				local c=opt and "#44445a" or "#66667c"
				p[#p+1]="<font color=\""..c.."\">".. (opt and "["or"<") ..l.. (opt and "]"or">") .."</font>"
			end
			hintLbl.Text=table.concat(p,"  ") hintLbl.Visible=true
		else hintLbl.Visible=false end
		return
	end
	hintLbl.Visible=false
	if q=="" then acM={} refreshDrop() return end
	acM=Registry.getMatches(q) acI=1 refreshDrop()
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Open / Close
-- ═══════════════════════════════════════════════════════════════════════════════
local OI = TweenInfo.new(.2, Enum.EasingStyle.Expo, Enum.EasingDirection.Out)
local CI = TweenInfo.new(.18,Enum.EasingStyle.Expo, Enum.EasingDirection.In)

local function openBar()
	if open then return end
	open=true hIdx=0 draft=""
	bar.BackgroundTransparency = .06
	bar.Position               = UDim2.new(.5,0,0,36)
	bar.Visible                = true
	blocker.Visible            = true
	barStroke.Transparency     = .12
	stripe.BackgroundTransparency = .2
	glyph.TextTransparency     = 0
	input.TextTransparency     = 0
	TweenService:Create(bar,OI,{Position=UDim2.new(.5,0,0,56)}):Play()
	task.defer(function() input:CaptureFocus() end)
	print("[CMD] opened")
end

local function closeBar()
	if not open then return end
	open=false hIdx=0
	drop.Visible=false hintLbl.Visible=false blocker.Visible=false
	TweenService:Create(bar,CI,{
		Position=UDim2.new(.5,0,0,36),
		BackgroundTransparency=1,
	}):Play()
	tw(barStroke,  .18,{Transparency=1})
	tw(stripe,     .18,{BackgroundTransparency=1})
	tw(glyph,      .18,{TextTransparency=1})
	tw(input,      .18,{TextTransparency=1})
	task.delay(.2,function()
		if not open then
			bar.Visible=false input.Text="" acM={}
		end
	end)
	input:ReleaseFocus()
	print("[CMD] closed")
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Execute
-- ═══════════════════════════════════════════════════════════════════════════════
local function execute()
	local raw=(input.Text:match("^%s*(.-)%s*$") or "")
	if raw=="" then closeBar() return end
	if not Registry then notify("⚠ Loading… try again","") closeBar() return end
	local toks=Registry.parseArgs(raw)
	local cmd=toks[1] and toks[1]:lower() or ""
	local args={} for i=2,#toks do args[#args+1]=toks[i] end
	if hist[1]~=raw then
		table.insert(hist,1,raw)
		if #hist>60 then table.remove(hist) end
	end
	if Remotes and Remotes.CommandExecuted then
		Remotes.CommandExecuted:FireServer(cmd,args)
		notify("✓  "..raw)
	else
		notify("⚠ Remotes not ready yet")
	end
	closeBar()
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- TextBox wiring
-- ═══════════════════════════════════════════════════════════════════════════════
input.Focused:Connect(function() focused=true end)
input.FocusLost:Connect(function(enter) focused=false; if enter then execute() end end)
input:GetPropertyChangedSignal("Text"):Connect(function()
	if not open then return end
	local t=input.Text
	if t:find("[\t\n]") then
		local c=t:gsub("[\t\n]","")
		input.Text=c input.CursorPosition=#c+1
		return
	end
	updateAC()
end)

blocker.MouseButton1Click:Connect(function() closeBar() end)

-- Trigger button
trigBtn.MouseButton1Click:Connect(function()
	print("[CMD] trigger button clicked")
	if open then closeBar() else openBar() end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- INPUT  —  three independent layers so it cannot be missed
-- ═══════════════════════════════════════════════════════════════════════════════

-- Layer 1: InputBegan (ignores gameProcessed for open keys)
UserInputService.InputBegan:Connect(function(inp, _gp)
	local k = inp.KeyCode
	if k == Enum.KeyCode.Quote or k == Enum.KeyCode.Semicolon then
		print("[CMD] open key pressed, open=", open)
		if not open then openBar() end
		return
	end
	if not open then return end
	if k == Enum.KeyCode.Escape then closeBar() return end
	if not focused then return end
	if k == Enum.KeyCode.Return then execute() return end
	if k == Enum.KeyCode.Up then
		if hIdx==0 then draft=input.Text end
		hIdx=math.min(hIdx+1,#hist)
		if hist[hIdx] then
			input.Text=hist[hIdx]
			task.defer(function() input.CursorPosition=#input.Text+1 end)
		end
		return
	end
	if k == Enum.KeyCode.Down then
		if hIdx>0 then
			hIdx-=1 input.Text=hIdx==0 and draft or hist[hIdx]
			task.defer(function() input.CursorPosition=#input.Text+1 end)
		end
		return
	end
	if k == Enum.KeyCode.Tab then
		if #acM>0 then
			local m=acM[acI] or acM[1]
			if m then
				input.Text=m.name.." "
				task.defer(function() input.CursorPosition=#input.Text+1 end)
			end
		end
		return
	end
end)

-- Layer 2: Heartbeat key-state polling (fires even when InputBegan is suppressed)
local prevQ = false
local prevS = false
RunService.Heartbeat:Connect(function()
	local q = UserInputService:IsKeyDown(Enum.KeyCode.Quote)
	local s = UserInputService:IsKeyDown(Enum.KeyCode.Semicolon)
	if (q and not prevQ) or (s and not prevS) then
		if not open then
			print("[CMD] heartbeat detected open key")
			openBar()
		end
	end
	prevQ=q prevS=s
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- Load remotes async (never blocks the handlers above)
-- ═══════════════════════════════════════════════════════════════════════════════
task.spawn(function()
	local ok,err = pcall(function()
		Remotes  = require(ReplicatedStorage:WaitForChild("CommandRemotes",  30))
		Registry = require(ReplicatedStorage:WaitForChild("CommandRegistry", 30))
	end)
	if not ok then
		warn("[CMD] remote load failed:", err)
		return
	end
	if Remotes and Remotes.CommandFeedback then
		Remotes.CommandFeedback.OnClientEvent:Connect(function(success, msg)
			if not success and type(msg)=="string" then notify("✗  "..msg) end
		end)
	end
	print("[CMD] remotes ready")
end)

-- Startup toast – proves THIS version of the script is running in Studio.
-- If you do NOT see this popup, Rojo has not synced yet.
task.delay(0.8, function()
	notify("⌨  CMD bar loaded  ·  ' or ; or [CMD]")
	print("[CMD] script fully started")
end)
