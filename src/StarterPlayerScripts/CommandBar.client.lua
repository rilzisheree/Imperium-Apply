--[[
        CommandBar.client.lua
        LocalScript — StarterPlayerScripts

        Press ; to open. Escape to close. Enter to run. Tab to autocomplete.
--]]

-- ─── Services ──────────────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- Remotes loaded async so script never blocks at startup
local CommandRemotes  = nil
local CommandRegistry = nil

-- ─── Config ────────────────────────────────────────────────────────────────────
local OPEN_KEY    = Enum.KeyCode.Semicolon
local ANIM        = 0.25
local BAR_W       = 560
local BAR_H       = 48
local Y_OPEN      = 80
local Y_CLOSED    = 36
local CORNER      = 8
local HISTORY_MAX = 60

local C = {
        bg       = Color3.fromRGB(10, 10, 14),
        border   = Color3.fromRGB(80, 80, 95),
        accent   = Color3.fromRGB(180, 180, 200),
        text     = Color3.fromRGB(235, 235, 250),
        hint     = Color3.fromRGB(100, 100, 115),
        ph       = Color3.fromRGB(80,  80,  98),
        acBg     = Color3.fromRGB(14,  14,  18),
        acHover  = Color3.fromRGB(28,  28,  36),
        acBorder = Color3.fromRGB(70,  70,  88),
        acDesc   = Color3.fromRGB(110, 110, 128),
}

-- ─── State ─────────────────────────────────────────────────────────────────────
local isOpen       = false
local inputFocused = false
local history      = {}
local histIdx      = 0
local draft        = ""
local acMatches    = {}
local acIdx        = 1

-- ─── Tween shorthand ───────────────────────────────────────────────────────────
local function tw(obj, t, props, style, dir)
        TweenService:Create(obj,
                TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
                props):Play()
end

-- ─── Build GUI (synchronous — happens before any yielding code) ────────────────

local gui = Instance.new("ScreenGui")
gui.Name           = "StaffCommandBar"
gui.DisplayOrder   = 100
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.Parent         = PlayerGui

-- Full-screen click blocker
local blocker = Instance.new("ImageButton")
blocker.Size                   = UDim2.new(1,0,1,0)
blocker.BackgroundTransparency = 1
blocker.ZIndex                 = 5
blocker.Visible                = false
blocker.Parent                 = gui

-- Main panel
local panel = Instance.new("Frame")
panel.Name                   = "Panel"
panel.AnchorPoint            = Vector2.new(0.5, 0)
panel.Size                   = UDim2.new(0, BAR_W, 0, BAR_H)
panel.Position               = UDim2.new(0.5, 0, 0, Y_CLOSED)
panel.BackgroundColor3       = C.bg
panel.BackgroundTransparency = 1
panel.BorderSizePixel        = 0
panel.Visible                = false
panel.ZIndex                 = 10
panel.Parent                 = gui

Instance.new("UICorner", panel).CornerRadius = UDim.new(0, CORNER)

local pStroke = Instance.new("UIStroke", panel)
pStroke.Color        = C.border
pStroke.Thickness    = 1.5
pStroke.Transparency = 1
pStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- Accent stripe
local stripe = Instance.new("Frame", panel)
stripe.Size                   = UDim2.new(1,-2,0,2)
stripe.Position               = UDim2.new(0,1,0,0)
stripe.BackgroundColor3       = C.accent
stripe.BackgroundTransparency = 1
stripe.BorderSizePixel        = 0
stripe.ZIndex                 = 11
Instance.new("UICorner", stripe).CornerRadius = UDim.new(0,2)

-- Prompt glyph
local prompt = Instance.new("TextLabel", panel)
prompt.Size                   = UDim2.new(0,30,1,0)
prompt.Position               = UDim2.new(0,10,0,0)
prompt.BackgroundTransparency = 1
prompt.Font                   = Enum.Font.GothamBold
prompt.TextSize               = 18
prompt.TextColor3             = C.accent
prompt.TextTransparency       = 1
prompt.Text                   = "›"
prompt.ZIndex                 = 11

-- Input box
local inputBox = Instance.new("TextBox", panel)
inputBox.Size                   = UDim2.new(1,-46,1,-10)
inputBox.Position               = UDim2.new(0,42,0,5)
inputBox.BackgroundTransparency = 1
inputBox.BorderSizePixel        = 0
inputBox.ClearTextOnFocus       = false
inputBox.Font                   = Enum.Font.Code
inputBox.TextSize               = 15
inputBox.TextColor3             = C.text
inputBox.TextTransparency       = 1
inputBox.PlaceholderText        = "Type a command…"
inputBox.PlaceholderColor3      = C.ph
inputBox.Text                   = ""
inputBox.TextXAlignment         = Enum.TextXAlignment.Left
inputBox.ZIndex                 = 11

-- Hint label (arg guide, below panel)
local hintBar = Instance.new("Frame", panel)
hintBar.Size                   = UDim2.new(1,0,0,18)
hintBar.Position               = UDim2.new(0,0,1,4)
hintBar.BackgroundTransparency = 1
hintBar.BorderSizePixel        = 0
hintBar.Visible                = false
hintBar.ZIndex                 = 10

local hintLbl = Instance.new("TextLabel", hintBar)
hintLbl.Size                   = UDim2.new(1,-44,1,0)
hintLbl.Position               = UDim2.new(0,44,0,0)
hintLbl.BackgroundTransparency = 1
hintLbl.Font                   = Enum.Font.Gotham
hintLbl.TextSize               = 11
hintLbl.TextColor3             = C.hint
hintLbl.TextXAlignment         = Enum.TextXAlignment.Left
hintLbl.RichText               = true
hintLbl.ZIndex                 = 10

-- Autocomplete dropdown
local drop = Instance.new("Frame", panel)
drop.Name                   = "Drop"
drop.AnchorPoint            = Vector2.new(0,0)
drop.Size                   = UDim2.new(1,0,0,0)
drop.Position               = UDim2.new(0,0,1,8)
drop.BackgroundColor3       = C.acBg
drop.BackgroundTransparency = 0.05
drop.BorderSizePixel        = 0
drop.Visible                = false
drop.ClipsDescendants       = true
drop.ZIndex                 = 20
Instance.new("UICorner", drop).CornerRadius = UDim.new(0, CORNER)
local dropStroke = Instance.new("UIStroke", drop)
dropStroke.Color        = C.acBorder
dropStroke.Thickness    = 1
dropStroke.Transparency = 0.4
dropStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
Instance.new("UIListLayout", drop).SortOrder = Enum.SortOrder.LayoutOrder

-- ─── Notifications ────────────────────────────────────────────────────────────
local notifGui = Instance.new("ScreenGui")
notifGui.Name           = "CmdNotifs"
notifGui.DisplayOrder   = 110
notifGui.ResetOnSpawn   = false
notifGui.IgnoreGuiInset = true
notifGui.Parent         = PlayerGui

local NOTIF_W, NOTIF_H, NOTIF_M, NOTIF_GAP = 250, 48, 14, 6
local notifs = {}

local function notifSlotY(i)
        return -(NOTIF_M + (i-1)*(NOTIF_H+NOTIF_GAP))
end

local function reflowNotifs()
        for i,f in ipairs(notifs) do
                tw(f, 0.25, { Position = UDim2.new(1,-NOTIF_M,1,notifSlotY(i)) })
        end
end

local function showNotif(msg)
        while #notifs >= 4 do
                notifs[#notifs]:Destroy()
                table.remove(notifs, #notifs)
        end

        local f = Instance.new("Frame")
        f.AnchorPoint            = Vector2.new(1,1)
        f.Size                   = UDim2.new(0,NOTIF_W,0,NOTIF_H)
        f.Position               = UDim2.new(1, NOTIF_W+NOTIF_M, 1, notifSlotY(1))
        f.BackgroundColor3       = C.bg
        f.BackgroundTransparency = 0.08
        f.BorderSizePixel        = 0
        f.ZIndex                 = 30
        f.Parent                 = notifGui
        Instance.new("UICorner",f).CornerRadius = UDim.new(0,8)
        local fs = Instance.new("UIStroke",f)
        fs.Color=C.border fs.Thickness=1.2 fs.Transparency=0.2
        fs.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
        local bar = Instance.new("Frame",f)
        bar.Size=UDim2.new(0,3,1,-10) bar.Position=UDim2.new(0,5,0,5)
        bar.BackgroundColor3=C.accent bar.BorderSizePixel=0 bar.ZIndex=31
        Instance.new("UICorner",bar).CornerRadius=UDim.new(0,2)
        local lbl = Instance.new("TextLabel",f)
        lbl.Size=UDim2.new(1,-18,1,0) lbl.Position=UDim2.new(0,14,0,0)
        lbl.BackgroundTransparency=1 lbl.Font=Enum.Font.GothamSemibold
        lbl.TextSize=12 lbl.TextColor3=C.text lbl.TextXAlignment=Enum.TextXAlignment.Left
        lbl.TextYAlignment=Enum.TextYAlignment.Center lbl.TextTruncate=Enum.TextTruncate.AtEnd
        lbl.Text=msg lbl.ZIndex=31

        for i,ex in ipairs(notifs) do
                tw(ex, 0.25, { Position = UDim2.new(1,-NOTIF_M,1,notifSlotY(i+1)) })
        end
        table.insert(notifs,1,f)
        tw(f, 0.25, { Position = UDim2.new(1,-NOTIF_M,1,notifSlotY(1)) })

        task.delay(3.5, function()
                local idx = table.find(notifs,f)
                if not idx then return end
                tw(f, 0.25, { Position = UDim2.new(1,NOTIF_W+NOTIF_M,1,notifSlotY(idx)) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                table.remove(notifs,idx)
                task.delay(0.3, function() f:Destroy() reflowNotifs() end)
        end)
end

-- ─── Autocomplete rows ────────────────────────────────────────────────────────
local AC_ROW_H = 32
local acRowCache = {}

local function clearDrop()
        for _,r in acRowCache do r.Visible = false end
end

local function getAcRow(i)
        if acRowCache[i] then return acRowCache[i] end

        local row = Instance.new("Frame")
        row.Name                   = "AcRow"..i
        row.LayoutOrder            = i
        row.Size                   = UDim2.new(1,0,0,AC_ROW_H)
        row.BackgroundColor3       = C.acHover
        row.BackgroundTransparency = 1
        row.BorderSizePixel        = 0
        row.ZIndex                 = 20
        row.Parent                 = drop

        local nl = Instance.new("TextLabel", row)
        nl.Name="N" nl.Size=UDim2.new(0,140,1,0) nl.Position=UDim2.new(0,40,0,0)
        nl.BackgroundTransparency=1 nl.Font=Enum.Font.Code nl.TextSize=14
        nl.TextColor3=C.text nl.TextXAlignment=Enum.TextXAlignment.Left
        nl.TextYAlignment=Enum.TextYAlignment.Center nl.ZIndex=21

        local dl = Instance.new("TextLabel", row)
        dl.Name="D" dl.Size=UDim2.new(1,-144,1,0) dl.Position=UDim2.new(0,144,0,0)
        dl.BackgroundTransparency=1 dl.Font=Enum.Font.Gotham dl.TextSize=11
        dl.TextColor3=C.acDesc dl.TextXAlignment=Enum.TextXAlignment.Left
        dl.TextYAlignment=Enum.TextYAlignment.Center dl.TextTruncate=Enum.TextTruncate.AtEnd
        dl.ZIndex=21

        local div = Instance.new("Frame", row)
        div.Name="Div" div.Size=UDim2.new(1,-40,0,1) div.Position=UDim2.new(0,40,1,-1)
        div.BackgroundColor3=C.acBorder div.BackgroundTransparency=0.5 div.BorderSizePixel=0 div.ZIndex=21

        local btn = Instance.new("TextButton", row)
        btn.Size=UDim2.new(1,0,1,0) btn.BackgroundTransparency=1 btn.Text="" btn.ZIndex=22

        btn.MouseButton1Click:Connect(function()
                local m = acMatches[i]
                if m then
                        inputBox.Text = m.name.." "
                        inputBox:CaptureFocus()
                        task.defer(function() inputBox.CursorPosition = #inputBox.Text+1 end)
                end
        end)
        btn.MouseEnter:Connect(function()
                acIdx = i
                for j,r in acRowCache do
                        if r and r.Visible then
                                tw(r, 0.06, {BackgroundTransparency=(j==acIdx) and 0.55 or 1})
                        end
                end
        end)

        acRowCache[i] = row
        return row
end

local function refreshDrop()
        clearDrop()
        local n = math.min(#acMatches, 6)
        if n == 0 then
                drop.Visible  = false
                hintBar.Visible = false
                return
        end
        drop.Size    = UDim2.new(1,0,0, n*AC_ROW_H)
        drop.Visible = true

        for i = 1, n do
                local m   = acMatches[i]
                local row = getAcRow(i)
                row.Visible = true
                local sel = (i == acIdx)
                tw(row, 0.06, {BackgroundTransparency = sel and 0.55 or 1})
                local nl = row:FindFirstChild("N")
                local dl = row:FindFirstChild("D")
                local dv = row:FindFirstChild("Div")
                if nl then nl.Text=m.name nl.TextColor3=sel and Color3.new(1,1,1) or C.text end
                if dl then dl.Text=m.description or "" end
                if dv then dv.Visible=(i~=n) end
        end

        local sel = acMatches[acIdx]
        if sel and sel.args and #sel.args > 0 then
                local parts = {'<font color="#b0b0c8">'..sel.name.."</font>"}
                for _, arg in sel.args do
                        local opt   = arg:sub(-1)=="?"
                        local lbl   = opt and arg:sub(1,-2) or arg
                        local col   = opt and "#555566" or "#777788"
                        local o,c   = opt and "[" or "<", opt and "]" or ">"
                        table.insert(parts,'<font color="'..col..'">'..o..lbl..c.."</font>")
                end
                hintLbl.Text    = table.concat(parts,"  ")
                hintBar.Visible = true
        else
                hintBar.Visible = false
        end
end

-- ─── Autocomplete logic ────────────────────────────────────────────────────────
local function updateAc()
        if not CommandRegistry then return end
        local text   = inputBox.Text
        local tokens = CommandRegistry.parseArgs(text)
        local q      = tokens[1] or ""

        if text:find("%s") then
                local cmd = CommandRegistry.COMMANDS[q:lower()]
                acMatches = cmd and {{name=q:lower(), description=cmd.description, args=cmd.args}} or {}
                clearDrop()
                drop.Visible = false
                if cmd and #cmd.args>0 then
                        local hasSp = text:sub(-1)==" "
                        local pos   = math.max(1, hasSp and #tokens or #tokens-1)
                        local filt  = hasSp and "" or (tokens[#tokens] or "")
                        local argLbl= cmd.args[pos] or ""
                        -- hint
                        local parts = {'<font color="#b0b0c8">'..q:lower().."</font>"}
                        for _,a in cmd.args do
                                local opt=a:sub(-1)=="?" local l=opt and a:sub(1,-2) or a
                                local col=opt and "#555566" or "#777788" local o,c=opt and "[" or "<",opt and "]" or ">"
                                table.insert(parts,'<font color="'..col..'">'..o..l..c.."</font>")
                        end
                        hintLbl.Text    = table.concat(parts,"  ")
                        hintBar.Visible = true
                else
                        hintBar.Visible = false
                end
                return
        end

        if q=="" then acMatches={} refreshDrop() return end
        acMatches = CommandRegistry.getMatches(q)
        acIdx     = 1
        refreshDrop()
end

-- ─── Open / Close ──────────────────────────────────────────────────────────────
local openInfo  = TweenInfo.new(ANIM, Enum.EasingStyle.Expo, Enum.EasingDirection.Out)
local closeInfo = TweenInfo.new(ANIM, Enum.EasingStyle.Expo, Enum.EasingDirection.In)

local function openBar()
        if isOpen then return end
        isOpen   = true
        histIdx  = 0
        draft    = ""

        panel.BackgroundTransparency      = 0.06
        panel.Position                    = UDim2.new(0.5,0,0,Y_CLOSED)
        panel.Visible                     = true
        blocker.Visible                   = true
        pStroke.Transparency              = 0.1
        stripe.BackgroundTransparency     = 0.2
        prompt.TextTransparency           = 0
        inputBox.TextTransparency         = 0

        TweenService:Create(panel, openInfo, { Position = UDim2.new(0.5,0,0,Y_OPEN) }):Play()
        inputBox:CaptureFocus()
end

local function closeBar()
        if not isOpen then return end
        isOpen = false
        histIdx = 0

        drop.Visible           = false
        hintBar.Visible        = false
        blocker.Visible        = false

        TweenService:Create(panel, closeInfo, {
                Position             = UDim2.new(0.5,0,0,Y_CLOSED),
                BackgroundTransparency = 1,
        }):Play()
        tw(pStroke, ANIM, {Transparency=1})
        tw(stripe,  ANIM, {BackgroundTransparency=1})
        tw(prompt,  ANIM, {TextTransparency=1})
        tw(inputBox,ANIM, {TextTransparency=1})

        task.delay(ANIM, function()
                if not isOpen then
                        panel.Visible = false
                        inputBox.Text = ""
                        acMatches     = {}
                end
        end)
        inputBox:ReleaseFocus()
end

-- ─── Execute ───────────────────────────────────────────────────────────────────
local function execute()
        local raw = inputBox.Text:match("^%s*(.-)%s*$")
        if raw == "" then closeBar() return end

        if not CommandRegistry then
                showNotif("⚠  Still connecting, try again shortly")
                closeBar()
                return
        end

        local tokens  = CommandRegistry.parseArgs(raw)
        local cmdName = tokens[1] and tokens[1]:lower() or ""
        local args    = {}
        for i=2,#tokens do args[#args+1]=tokens[i] end

        if history[1]~=raw then
                table.insert(history,1,raw)
                if #history>HISTORY_MAX then table.remove(history) end
        end

        if CommandRemotes and CommandRemotes.CommandExecuted then
                CommandRemotes.CommandExecuted:FireServer(cmdName, args)
                showNotif("✓  Sent: "..raw)
        else
                showNotif("⚠  Remotes not ready")
        end
        closeBar()
end

-- ─── TextBox wiring ────────────────────────────────────────────────────────────
inputBox.Focused:Connect(function() inputFocused=true end)

inputBox.FocusLost:Connect(function(enter)
        inputFocused=false
        if enter then execute() end
end)

inputBox:GetPropertyChangedSignal("Text"):Connect(function()
        if not isOpen then return end
        local t = inputBox.Text
        if t:find("[\t\n]") then
                local c = t:gsub("[\t\n]","")
                inputBox.Text=c
                inputBox.CursorPosition=#c+1
                return
        end
        updateAc()
end)

blocker.MouseButton1Click:Connect(closeBar)

-- ─── INPUT HANDLER — registered before any async code ─────────────────────────
-- No gameProcessed guard on OPEN_KEY: we want ; to open the bar regardless of
-- whether the chat box or any other UI element has focus.

UserInputService.InputBegan:Connect(function(input, _gameProcessed)
        local k = input.KeyCode

        -- Semicolon: open the bar (from anywhere)
        if k == OPEN_KEY then
                if not isOpen then openBar() end
                return
        end

        if not isOpen then return end

        -- Escape: close
        if k == Enum.KeyCode.Escape then
                closeBar()
                return
        end

        if not inputFocused then return end

        -- Enter
        if k == Enum.KeyCode.Return then
                execute()
                return
        end

        -- Up/Down: history
        if k == Enum.KeyCode.Up then
                if histIdx==0 then draft=inputBox.Text end
                histIdx = math.min(histIdx+1, #history)
                if history[histIdx] then
                        inputBox.Text=history[histIdx]
                        task.defer(function() inputBox.CursorPosition=#inputBox.Text+1 end)
                end
                return
        end
        if k == Enum.KeyCode.Down then
                if histIdx>0 then
                        histIdx-=1
                        inputBox.Text = histIdx==0 and draft or history[histIdx]
                        task.defer(function() inputBox.CursorPosition=#inputBox.Text+1 end)
                end
                return
        end

        -- Tab: autocomplete
        if k == Enum.KeyCode.Tab then
                if #acMatches>0 then
                        local m = acMatches[acIdx] or acMatches[1]
                        if m then
                                inputBox.Text=m.name.." "
                                task.defer(function() inputBox.CursorPosition=#inputBox.Text+1 end)
                        end
                end
                return
        end
end)

-- Heartbeat fallback: catches the key even if InputBegan is suppressed
-- (e.g. another TextBox had focus and the event fired with gameProcessed=true,
-- but we skipped it above — the polling catches the rising edge instead).
local prevDown = false
RunService.Heartbeat:Connect(function()
        local down = UserInputService:IsKeyDown(OPEN_KEY)
        if down and not prevDown and not isOpen then
                openBar()
        end
        prevDown = down
end)

-- ─── Async remote load ─────────────────────────────────────────────────────────
task.spawn(function()
        local ok, err = pcall(function()
                CommandRemotes  = require(ReplicatedStorage:WaitForChild("CommandRemotes",  30))
                CommandRegistry = require(ReplicatedStorage:WaitForChild("CommandRegistry", 30))
        end)
        if not ok then
                warn("[CommandBar] Remote load failed:", err)
                return
        end
        if CommandRemotes and CommandRemotes.CommandFeedback then
                CommandRemotes.CommandFeedback.OnClientEvent:Connect(function(success, msg)
                        if not success and type(msg)=="string" then
                                showNotif("✗  "..msg)
                        end
                end)
        end
        print("[CommandBar] Remotes loaded OK")
end)

print("[CommandBar] Ready — press ; to open")
