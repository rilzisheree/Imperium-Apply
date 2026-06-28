--[[
        CommandBar.client.lua  —  LocalScript (StarterPlayerScripts)

        Opens the staff command bar.

        HOW TO OPEN:
          ' (apostrophe)  — keyboard shortcut
          Click the "]" button (top-right corner)  — always works
          Escape  — close
          Enter   — execute
          Tab     — autocomplete
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- Remotes loaded in background — never block startup
local CommandRemotes  = nil
local CommandRegistry = nil

-- ─── Constants ─────────────────────────────────────────────────────────────────
local OPEN_KEY    = Enum.KeyCode.Quote        -- ' key  (change here if needed)
local ANIM        = 0.22
local BAR_W       = 540
local BAR_H       = 46
local Y_OPEN      = 72
local Y_CLOSED    = 32
local CORNER      = 7
local HIST_MAX    = 60
local AC_ROW_H    = 30
local AC_MAX      = 6
local NOTIF_W     = 240
local NOTIF_H     = 44
local NOTIF_M     = 12
local NOTIF_GAP   = 5

local BG      = Color3.fromRGB(10,  10,  14)
local BORDER  = Color3.fromRGB(80,  80,  96)
local ACCENT  = Color3.fromRGB(170, 170, 195)
local TEXT    = Color3.fromRGB(232, 232, 248)
local HINT    = Color3.fromRGB( 96,  96, 112)
local PLACEHOLDER = Color3.fromRGB(75, 75, 92)
local AC_BG   = Color3.fromRGB(12,  12,  18)
local AC_HOV  = Color3.fromRGB(26,  26,  34)
local AC_BOR  = Color3.fromRGB(64,  64,  82)
local AC_DESC = Color3.fromRGB(104, 104, 122)

-- ─── State ─────────────────────────────────────────────────────────────────────
local isOpen       = false
local inputFocused = false
local history      = {}
local histIdx      = 0
local draft        = ""
local acMatches    = {}
local acIdx        = 1

-- ─── Helpers ───────────────────────────────────────────────────────────────────
local function tw(obj, t, props, style, dir)
        TweenService:Create(obj,
                TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
                props):Play()
end

local function uiCorner(parent, r)
        local c = Instance.new("UICorner", parent)
        c.CornerRadius = UDim.new(0, r or CORNER)
        return c
end

local function uiStroke(parent, color, thick, trans)
        local s = Instance.new("UIStroke", parent)
        s.Color = color  s.Thickness = thick or 1.4
        s.Transparency = trans or 0  s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        return s
end

-- ─── Root ScreenGui ────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name           = "StaffCommandBar"
gui.DisplayOrder   = 120
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.Parent         = PlayerGui

-- ─── Top-right trigger button (always visible, guaranteed to work) ──────────────
local triggerBtn = Instance.new("TextButton", gui)
triggerBtn.Name                   = "TriggerBtn"
triggerBtn.AnchorPoint            = Vector2.new(1, 0)
triggerBtn.Size                   = UDim2.new(0, 32, 0, 22)
triggerBtn.Position               = UDim2.new(1, -6, 0, 6)
triggerBtn.BackgroundColor3       = Color3.fromRGB(18, 18, 24)
triggerBtn.BackgroundTransparency = 0.3
triggerBtn.BorderSizePixel        = 0
triggerBtn.Text                   = "]"
triggerBtn.Font                   = Enum.Font.GothamBold
triggerBtn.TextSize               = 13
triggerBtn.TextColor3             = ACCENT
triggerBtn.ZIndex                 = 200
uiCorner(triggerBtn, 5)
uiStroke(triggerBtn, BORDER, 1, 0.4)

-- ─── Click-outside blocker ─────────────────────────────────────────────────────
local blocker = Instance.new("ImageButton", gui)
blocker.Size                   = UDim2.new(1,0,1,0)
blocker.BackgroundTransparency = 1
blocker.ZIndex                 = 8
blocker.Visible                = false

-- ─── Main panel ────────────────────────────────────────────────────────────────
local panel = Instance.new("Frame", gui)
panel.Name                   = "Panel"
panel.AnchorPoint            = Vector2.new(0.5, 0)
panel.Size                   = UDim2.new(0, BAR_W, 0, BAR_H)
panel.Position               = UDim2.new(0.5, 0, 0, Y_CLOSED)
panel.BackgroundColor3       = BG
panel.BackgroundTransparency = 1
panel.BorderSizePixel        = 0
panel.Visible                = false
panel.ZIndex                 = 10
uiCorner(panel)
local pStroke = uiStroke(panel, BORDER, 1.4, 1)

-- Top accent stripe
local stripe = Instance.new("Frame", panel)
stripe.Size                   = UDim2.new(1,-2,0,2)
stripe.Position               = UDim2.new(0,1,0,0)
stripe.BackgroundColor3       = ACCENT
stripe.BackgroundTransparency = 1
stripe.BorderSizePixel        = 0
stripe.ZIndex                 = 11
uiCorner(stripe, 2)

-- Prompt glyph
local prompt = Instance.new("TextLabel", panel)
prompt.Size                   = UDim2.new(0,28,1,0)
prompt.Position               = UDim2.new(0,10,0,0)
prompt.BackgroundTransparency = 1
prompt.Font                   = Enum.Font.GothamBold
prompt.TextSize               = 17
prompt.TextColor3             = ACCENT
prompt.TextTransparency       = 1
prompt.Text                   = "›"
prompt.ZIndex                 = 11

-- Input TextBox
local inputBox = Instance.new("TextBox", panel)
inputBox.Size                   = UDim2.new(1,-44,1,-8)
inputBox.Position               = UDim2.new(0,40,0,4)
inputBox.BackgroundTransparency = 1
inputBox.BorderSizePixel        = 0
inputBox.ClearTextOnFocus       = false
inputBox.Font                   = Enum.Font.Code
inputBox.TextSize               = 14
inputBox.TextColor3             = TEXT
inputBox.TextTransparency       = 1
inputBox.PlaceholderText        = "Enter command…"
inputBox.PlaceholderColor3      = PLACEHOLDER
inputBox.Text                   = ""
inputBox.TextXAlignment         = Enum.TextXAlignment.Left
inputBox.ZIndex                 = 11

-- Hint bar (shown below panel)
local hintBar = Instance.new("Frame", panel)
hintBar.Size                   = UDim2.new(1,0,0,16)
hintBar.Position               = UDim2.new(0,0,1,4)
hintBar.BackgroundTransparency = 1
hintBar.BorderSizePixel        = 0
hintBar.Visible                = false
hintBar.ZIndex                 = 10

local hintLbl = Instance.new("TextLabel", hintBar)
hintLbl.Size                   = UDim2.new(1,-42,1,0)
hintLbl.Position               = UDim2.new(0,42,0,0)
hintLbl.BackgroundTransparency = 1
hintLbl.Font                   = Enum.Font.Gotham
hintLbl.TextSize               = 11
hintLbl.TextColor3             = HINT
hintLbl.TextXAlignment         = Enum.TextXAlignment.Left
hintLbl.RichText               = true
hintLbl.ZIndex                 = 10

-- Autocomplete dropdown
local drop = Instance.new("Frame", panel)
drop.Name                   = "Drop"
drop.Size                   = UDim2.new(1,0,0,0)
drop.Position               = UDim2.new(0,0,1,6)
drop.BackgroundColor3       = AC_BG
drop.BackgroundTransparency = 0.05
drop.BorderSizePixel        = 0
drop.Visible                = false
drop.ClipsDescendants       = true
drop.ZIndex                 = 20
uiCorner(drop)
uiStroke(drop, AC_BOR, 1, 0.4)
local dropLayout = Instance.new("UIListLayout", drop)
dropLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- ─── Notification system ───────────────────────────────────────────────────────
local notifGui = Instance.new("ScreenGui")
notifGui.Name           = "CmdNotifs"
notifGui.DisplayOrder   = 130
notifGui.ResetOnSpawn   = false
notifGui.IgnoreGuiInset = true
notifGui.Parent         = PlayerGui

local notifs = {}

local function slotY(i) return -(NOTIF_M + (i-1)*(NOTIF_H+NOTIF_GAP)) end

local function reflow()
        for i,f in ipairs(notifs) do
                tw(f, 0.2, { Position = UDim2.new(1,-NOTIF_M,1,slotY(i)) })
        end
end

local function showNotif(msg, color)
        while #notifs >= 5 do notifs[#notifs]:Destroy() table.remove(notifs) end

        local f = Instance.new("Frame", notifGui)
        f.AnchorPoint            = Vector2.new(1,1)
        f.Size                   = UDim2.new(0,NOTIF_W,0,NOTIF_H)
        f.Position               = UDim2.new(1,NOTIF_W+NOTIF_M,1,slotY(1))
        f.BackgroundColor3       = BG
        f.BackgroundTransparency = 0.1
        f.BorderSizePixel        = 0
        f.ZIndex                 = 30
        uiCorner(f, 7)
        uiStroke(f, BORDER, 1.2, 0.25)

        local bar = Instance.new("Frame", f)
        bar.Size=UDim2.new(0,3,1,-8) bar.Position=UDim2.new(0,5,0,4)
        bar.BackgroundColor3=color or ACCENT bar.BorderSizePixel=0 bar.ZIndex=31
        uiCorner(bar, 2)

        local lbl = Instance.new("TextLabel", f)
        lbl.Size=UDim2.new(1,-16,1,0) lbl.Position=UDim2.new(0,13,0,0)
        lbl.BackgroundTransparency=1 lbl.Font=Enum.Font.GothamSemibold
        lbl.TextSize=11 lbl.TextColor3=TEXT
        lbl.TextXAlignment=Enum.TextXAlignment.Left
        lbl.TextYAlignment=Enum.TextYAlignment.Center
        lbl.TextTruncate=Enum.TextTruncate.AtEnd lbl.Text=msg lbl.ZIndex=31

        for i,ex in ipairs(notifs) do
                tw(ex, 0.2, { Position = UDim2.new(1,-NOTIF_M,1,slotY(i+1)) })
        end
        table.insert(notifs, 1, f)
        tw(f, 0.22, { Position = UDim2.new(1,-NOTIF_M,1,slotY(1)) })

        task.delay(4, function()
                local idx = table.find(notifs, f)
                if not idx then return end
                tw(f, 0.2, { Position = UDim2.new(1,NOTIF_W+NOTIF_M,1,slotY(idx)) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                table.remove(notifs, idx)
                task.delay(0.25, function() f:Destroy() reflow() end)
        end)
end

-- ─── Autocomplete rows ─────────────────────────────────────────────────────────
local acRows = {}

local function clearDrop()
        for _,r in acRows do r.Visible = false end
end

local function getAcRow(i)
        if acRows[i] then return acRows[i] end

        local row = Instance.new("Frame", drop)
        row.Name                   = "R"..i
        row.LayoutOrder            = i
        row.Size                   = UDim2.new(1,0,0,AC_ROW_H)
        row.BackgroundColor3       = AC_HOV
        row.BackgroundTransparency = 1
        row.BorderSizePixel        = 0
        row.ZIndex                 = 20

        local nl = Instance.new("TextLabel", row)
        nl.Name="N" nl.Size=UDim2.new(0,130,1,0) nl.Position=UDim2.new(0,38,0,0)
        nl.BackgroundTransparency=1 nl.Font=Enum.Font.Code nl.TextSize=13
        nl.TextColor3=TEXT nl.TextXAlignment=Enum.TextXAlignment.Left
        nl.TextYAlignment=Enum.TextYAlignment.Center nl.ZIndex=21

        local dl = Instance.new("TextLabel", row)
        dl.Name="D" dl.Size=UDim2.new(1,-136,1,0) dl.Position=UDim2.new(0,136,0,0)
        dl.BackgroundTransparency=1 dl.Font=Enum.Font.Gotham dl.TextSize=10
        dl.TextColor3=AC_DESC dl.TextXAlignment=Enum.TextXAlignment.Left
        dl.TextYAlignment=Enum.TextYAlignment.Center
        dl.TextTruncate=Enum.TextTruncate.AtEnd dl.ZIndex=21

        local dv = Instance.new("Frame", row)
        dv.Name="Dv" dv.Size=UDim2.new(1,-38,0,1) dv.Position=UDim2.new(0,38,1,-1)
        dv.BackgroundColor3=AC_BOR dv.BackgroundTransparency=0.5
        dv.BorderSizePixel=0 dv.ZIndex=21

        local btn = Instance.new("TextButton", row)
        btn.Size=UDim2.new(1,0,1,0) btn.BackgroundTransparency=1 btn.Text="" btn.ZIndex=22
        btn.MouseButton1Click:Connect(function()
                local m = acMatches[i]
                if m then
                        inputBox.Text = m.name.." "
                        inputBox:CaptureFocus()
                        task.defer(function() inputBox.CursorPosition=#inputBox.Text+1 end)
                end
        end)
        btn.MouseEnter:Connect(function()
                acIdx = i
                for j,r in acRows do
                        if r and r.Visible then
                                tw(r, 0.05, {BackgroundTransparency=(j==acIdx) and 0.5 or 1})
                        end
                end
        end)

        acRows[i] = row
        return row
end

local function refreshDrop()
        clearDrop()
        local n = math.min(#acMatches, AC_MAX)
        if n == 0 then drop.Visible=false hintBar.Visible=false return end

        drop.Size    = UDim2.new(1,0,0, n*AC_ROW_H)
        drop.Visible = true

        for i=1,n do
                local m   = acMatches[i]
                local row = getAcRow(i)
                row.Visible = true
                local sel = (i==acIdx)
                tw(row, 0.05, {BackgroundTransparency=sel and 0.5 or 1})
                local nl=row:FindFirstChild("N") local dl=row:FindFirstChild("D") local dv=row:FindFirstChild("Dv")
                if nl then nl.Text=m.name nl.TextColor3=sel and Color3.new(1,1,1) or TEXT end
                if dl then dl.Text=m.description or "" end
                if dv then dv.Visible=(i~=n) end
        end

        local sel = acMatches[acIdx]
        if sel and sel.args and #sel.args>0 then
                local parts={"<font color=\"#aaaacc\">"..sel.name.."</font>"}
                for _,a in sel.args do
                        local opt=a:sub(-1)=="?"
                        local l=opt and a:sub(1,-2) or a
                        local c=opt and "#555568" or "#6e6e88"
                        local o,cl=opt and "[" or "<",opt and "]" or ">"
                        parts[#parts+1]="<font color=\""..c.."\">"..o..l..cl.."</font>"
                end
                hintLbl.Text=table.concat(parts,"  ") hintBar.Visible=true
        else
                hintBar.Visible=false
        end
end

-- ─── Autocomplete update ───────────────────────────────────────────────────────
local function updateAc()
        if not CommandRegistry then return end
        local text=inputBox.Text
        local tokens=CommandRegistry.parseArgs(text)
        local q=tokens[1] or ""

        if text:find("%s") then
                local cmd=CommandRegistry.COMMANDS[q:lower()]
                acMatches=cmd and {{name=q:lower(),description=cmd.description,args=cmd.args}} or {}
                clearDrop() drop.Visible=false
                if cmd and #cmd.args>0 then
                        local parts={"<font color=\"#aaaacc\">"..q:lower().."</font>"}
                        for _,a in cmd.args do
                                local opt=a:sub(-1)=="?" local l=opt and a:sub(1,-2) or a
                                local c=opt and "#555568" or "#6e6e88" local o,cl=opt and "[" or "<",opt and "]" or ">"
                                parts[#parts+1]="<font color=\""..c.."\">"..o..l..cl.."</font>"
                        end
                        hintLbl.Text=table.concat(parts,"  ") hintBar.Visible=true
                else
                        hintBar.Visible=false
                end
                return
        end

        hintBar.Visible=false
        if q=="" then acMatches={} refreshDrop() return end
        acMatches=CommandRegistry.getMatches(q) acIdx=1 refreshDrop()
end

-- ─── Open / Close ──────────────────────────────────────────────────────────────
local openInfo  = TweenInfo.new(ANIM, Enum.EasingStyle.Expo, Enum.EasingDirection.Out)
local closeInfo = TweenInfo.new(ANIM, Enum.EasingStyle.Expo, Enum.EasingDirection.In)

local function openBar()
        if isOpen then return end
        isOpen=true histIdx=0 draft=""

        panel.BackgroundTransparency  = 0.06
        panel.Position                = UDim2.new(0.5,0,0,Y_CLOSED)
        panel.Visible                 = true
        blocker.Visible               = true
        pStroke.Transparency          = 0.1
        stripe.BackgroundTransparency = 0.2
        prompt.TextTransparency       = 0
        inputBox.TextTransparency     = 0

        TweenService:Create(panel, openInfo, {Position=UDim2.new(0.5,0,0,Y_OPEN)}):Play()
        inputBox:CaptureFocus()
end

local function closeBar()
        if not isOpen then return end
        isOpen=false histIdx=0
        drop.Visible=false hintBar.Visible=false blocker.Visible=false

        TweenService:Create(panel, closeInfo, {
                Position=UDim2.new(0.5,0,0,Y_CLOSED),
                BackgroundTransparency=1,
        }):Play()
        tw(pStroke, ANIM, {Transparency=1})
        tw(stripe,  ANIM, {BackgroundTransparency=1})
        tw(prompt,  ANIM, {TextTransparency=1})
        tw(inputBox,ANIM, {TextTransparency=1})

        task.delay(ANIM, function()
                if not isOpen then
                        panel.Visible=false inputBox.Text="" acMatches={}
                end
        end)
        inputBox:ReleaseFocus()
end

-- ─── Execute command ───────────────────────────────────────────────────────────
local function execute()
        local raw = inputBox.Text:match("^%s*(.-)%s*$")
        if raw=="" then closeBar() return end
        if not CommandRegistry then showNotif("⚠ Still loading…") closeBar() return end

        local tokens=CommandRegistry.parseArgs(raw)
        local cmdName=tokens[1] and tokens[1]:lower() or ""
        local args={}
        for i=2,#tokens do args[#args+1]=tokens[i] end

        if history[1]~=raw then
                table.insert(history,1,raw)
                if #history>HIST_MAX then table.remove(history) end
        end

        if CommandRemotes and CommandRemotes.CommandExecuted then
                CommandRemotes.CommandExecuted:FireServer(cmdName, args)
                showNotif("✓  "..raw)
        else
                showNotif("⚠ Remotes not ready")
        end
        closeBar()
end

-- ─── TextBox events ────────────────────────────────────────────────────────────
inputBox.Focused:Connect(function() inputFocused=true end)

inputBox.FocusLost:Connect(function(enter)
        inputFocused=false
        if enter then execute() end
end)

inputBox:GetPropertyChangedSignal("Text"):Connect(function()
        if not isOpen then return end
        local t=inputBox.Text
        if t:find("[\t\n]") then
                local c=t:gsub("[\t\n]","")
                inputBox.Text=c inputBox.CursorPosition=#c+1
                return
        end
        updateAc()
end)

blocker.MouseButton1Click:Connect(closeBar)
triggerBtn.MouseButton1Click:Connect(function()
        if isOpen then closeBar() else openBar() end
end)

-- ─── INPUT — registered immediately, before any async work ────────────────────
--
-- Strategy: three layers so the open CANNOT be missed.
--   1. UserInputService.InputBegan  — standard
--   2. RunService.Heartbeat polling — catches rising edge even if InputBegan fired
--      with gameProcessed=true (e.g. chat textbox had focus)
--   3. The "]" button above         — 100% reliable click target

-- Layer 1: event-driven
UserInputService.InputBegan:Connect(function(input, _gp)
        -- Open key fires regardless of gameProcessed
        if input.KeyCode == OPEN_KEY then
                if not isOpen then openBar() end
                return
        end

        if not isOpen then return end

        if input.KeyCode == Enum.KeyCode.Escape then
                closeBar()
                return
        end

        if not inputFocused then return end

        if input.KeyCode == Enum.KeyCode.Return then execute() return end

        if input.KeyCode == Enum.KeyCode.Up then
                if histIdx==0 then draft=inputBox.Text end
                histIdx=math.min(histIdx+1,#history)
                if history[histIdx] then
                        inputBox.Text=history[histIdx]
                        task.defer(function() inputBox.CursorPosition=#inputBox.Text+1 end)
                end
                return
        end
        if input.KeyCode == Enum.KeyCode.Down then
                if histIdx>0 then
                        histIdx-=1
                        inputBox.Text=histIdx==0 and draft or history[histIdx]
                        task.defer(function() inputBox.CursorPosition=#inputBox.Text+1 end)
                end
                return
        end
        if input.KeyCode == Enum.KeyCode.Tab then
                if #acMatches>0 then
                        local m=acMatches[acIdx] or acMatches[1]
                        if m then
                                inputBox.Text=m.name.." "
                                task.defer(function() inputBox.CursorPosition=#inputBox.Text+1 end)
                        end
                end
                return
        end
end)

-- Layer 2: heartbeat polling (catches rising edge even when events are suppressed)
local prevDown = false
RunService.Heartbeat:Connect(function()
        local down = UserInputService:IsKeyDown(OPEN_KEY)
        if down and not prevDown and not isOpen then
                openBar()
        end
        prevDown = down
end)

-- ─── Startup notification ──────────────────────────────────────────────────────
-- This fires ~0.5s after spawn so you can confirm this script version is running.
-- If you do NOT see this toast in-game, Rojo has not synced yet.
task.delay(0.5, function()
        showNotif("Command Bar ready  ( ' key or ] button )")
end)

-- ─── Load remotes in background — never blocks the input handler above ─────────
task.spawn(function()
        local ok, err = pcall(function()
                CommandRemotes  = require(ReplicatedStorage:WaitForChild("CommandRemotes",  30))
                CommandRegistry = require(ReplicatedStorage:WaitForChild("CommandRegistry", 30))
        end)
        if not ok then
                warn("[CommandBar] Remote load failed:", err)
                showNotif("⚠ Server remotes failed to load")
                return
        end
        if CommandRemotes and CommandRemotes.CommandFeedback then
                CommandRemotes.CommandFeedback.OnClientEvent:Connect(function(ok2, msg)
                        if not ok2 and type(msg)=="string" then showNotif("✗  "..msg) end
                end)
        end
        print("[CommandBar] Remotes loaded.")
end)

print("[CommandBar] Script started — press ' or click ] to open")
