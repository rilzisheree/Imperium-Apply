--[[
        CommandBar.client.lua
        LocalScript — StarterPlayerScripts

        Staff command bar — integrates with the existing custom chat system.
        Does NOT use Roblox's default chat, TextChatService, or Player.Chatted.

        Controls:
          ;         — open the command bar
          Escape    — close without executing
          Enter     — execute the current input
          Up/Down   — cycle through command history
          Tab       — accept the top autocomplete suggestion
          Click outside bar — close

        UI Design (v2 — yellow/black administration theme):
          • Dark/black console aesthetic with yellow accents
          • Smooth slide-down + fade-in entrance animation
          • Autocomplete dropdown with command name coloured in accent yellow
          • Arg hint line below the input shows expected argument labels
          • Player suggestion panel (UI-only placeholder)
          • Right-side command notification that slides in from the edge
          • Feedback toasts appear bottom-right
--]]

local Players               = game:GetService("Players")
local ReplicatedStorage     = game:GetService("ReplicatedStorage")
local UserInputService      = game:GetService("UserInputService")
local TweenService          = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local CommandRemotes  = require(ReplicatedStorage:WaitForChild("CommandRemotes"))
local CommandRegistry = require(ReplicatedStorage:WaitForChild("CommandRegistry"))

-- ─── Configuration ─────────────────────────────────────────────────────────────

local CFG = {
        OPEN_KEY         = Enum.KeyCode.Semicolon,

        -- Bar geometry (slightly larger than v1)
        BAR_WIDTH        = 580,
        BAR_HEIGHT       = 52,
        BAR_Y_OPEN       = 82,
        BAR_Y_CLOSED     = 38,
        BAR_CORNER       = 8,

        -- ── Gray / Black theme ────────────────────────────────────────────────────
        BG_DARK          = Color3.fromRGB(10, 10, 12),
        BG_BORDER        = Color3.fromRGB(90, 90, 100),
        BG_TRANS_OPEN    = 0.06,
        BG_TRANS_CLOSED  = 1,

        PROMPT_COLOR     = Color3.fromRGB(190, 190, 200),  -- gray "›"
        CMD_COLOR        = Color3.fromRGB(210, 210, 220),  -- command name highlight
        ARG_COLOR        = Color3.fromRGB(210, 210, 220),  -- arg text
        TEXT_COLOR       = Color3.fromRGB(240, 240, 255),
        PLACEHOLDER_COLOR= Color3.fromRGB(90, 90, 105),
        HINT_COLOR       = Color3.fromRGB(110, 110, 125),

        FONT             = Enum.Font.GothamSemibold,
        FONT_MONO        = Enum.Font.Code,
        TEXT_SIZE        = 15,
        HINT_SIZE        = 12,

        -- Autocomplete dropdown
        AC_MAX_ENTRIES   = 6,
        AC_ROW_HEIGHT    = 34,
        AC_BG            = Color3.fromRGB(12, 12, 14),
        AC_HOVER_BG      = Color3.fromRGB(26, 26, 32),
        AC_BORDER        = Color3.fromRGB(75, 75, 90),
        AC_DESC_COLOR    = Color3.fromRGB(120, 120, 135),

        -- Animation
        ANIM_TIME        = 0.30,

        -- History
        HISTORY_MAX      = 80,

        -- Feedback toast
        TOAST_DURATION   = 3.5,
        TOAST_FADE       = 0.4,

        -- Player suggestion panel
        PS_ROW_HEIGHT    = 36,
        PS_MAX_ENTRIES   = 4,
        PS_BG            = Color3.fromRGB(10, 10, 12),
        PS_HOVER_BG      = Color3.fromRGB(26, 26, 32),
        PS_BORDER        = Color3.fromRGB(75, 75, 90),
        PS_TEXT_COLOR    = Color3.fromRGB(230, 230, 240),

        -- Right-side notification (bottom-right corner)
        NOTIF_WIDTH      = 260,
        NOTIF_HEIGHT     = 52,
        NOTIF_MARGIN     = 16,   -- gap from screen edges
        NOTIF_DURATION   = 3.0,
        NOTIF_FADE       = 0.35,
        NOTIF_SLIDE      = 0.28,
}

-- ─── State ─────────────────────────────────────────────────────────────────────

local isOpen        = false
local history       = {}
local historyIndex  = 0
local savedDraft    = ""
local acMatches     = {}
local acIndex       = 1

-- ─── Tween helper ──────────────────────────────────────────────────────────────

local function tw(target, time, props, style, dir)
        style = style or Enum.EasingStyle.Quint
        dir   = dir   or Enum.EasingDirection.Out
        TweenService:Create(target, TweenInfo.new(time, style, dir), props):Play()
end

-- ─── Build the ScreenGui ───────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name            = "StaffCommandBar"
gui.DisplayOrder    = 50
gui.ResetOnSpawn    = false
gui.IgnoreGuiInset  = true
gui.Enabled         = true
gui.Parent          = PlayerGui

-- ── Root frame (the console panel) ───────────────────────────────────────────

local panel = Instance.new("Frame")
panel.Name                  = "Panel"
panel.AnchorPoint           = Vector2.new(0.5, 0)
panel.Size                  = UDim2.new(0, CFG.BAR_WIDTH, 0, 0)
panel.Position              = UDim2.new(0.5, 0, 0, CFG.BAR_Y_CLOSED)
panel.BackgroundColor3      = CFG.BG_DARK
panel.BackgroundTransparency = 1
panel.BorderSizePixel       = 0
panel.Visible               = false
panel.ClipsDescendants      = false
panel.AutomaticSize         = Enum.AutomaticSize.Y
panel.Parent                = gui

local panelPadding = Instance.new("UIPadding")
panelPadding.PaddingTop    = UDim.new(0, 15)
panelPadding.PaddingBottom = UDim.new(0, 15)
panelPadding.Parent        = panel

local panelSizeConstraint = Instance.new("UISizeConstraint")
panelSizeConstraint.MinSize = Vector2.new(CFG.BAR_WIDTH, CFG.BAR_HEIGHT)
panelSizeConstraint.MaxSize = Vector2.new(CFG.BAR_WIDTH, 200)
panelSizeConstraint.Parent  = panel

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, CFG.BAR_CORNER)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color        = CFG.BG_BORDER
panelStroke.Thickness    = 1.5
panelStroke.Transparency = 1
panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
panelStroke.Parent       = panel

-- Yellow top accent line
local accentLine = Instance.new("Frame")
accentLine.Name                  = "AccentLine"
accentLine.Size                  = UDim2.new(1, -2, 0, 2)
accentLine.Position              = UDim2.new(0, 1, 0, 0)
accentLine.BackgroundColor3      = CFG.PROMPT_COLOR
accentLine.BackgroundTransparency = 1
accentLine.BorderSizePixel       = 0
accentLine.ZIndex                = 3
accentLine.Parent                = panel

local accentLineCorner = Instance.new("UICorner")
accentLineCorner.CornerRadius = UDim.new(0, 2)
accentLineCorner.Parent = accentLine

-- ── Prompt symbol "›" ─────────────────────────────────────────────────────────

local promptLabel = Instance.new("TextLabel")
promptLabel.Name                  = "Prompt"
promptLabel.Size                  = UDim2.new(0, 32, 0, 22)
promptLabel.Position              = UDim2.new(0, 10, 0, 0)
promptLabel.BackgroundTransparency = 1
promptLabel.Font                  = CFG.FONT
promptLabel.TextSize              = 18
promptLabel.TextColor3            = CFG.PROMPT_COLOR
promptLabel.TextTransparency      = 1
promptLabel.Text                  = "›"
promptLabel.TextXAlignment        = Enum.TextXAlignment.Center
promptLabel.TextYAlignment        = Enum.TextYAlignment.Center
promptLabel.ZIndex                = 3
promptLabel.Parent                = panel

-- ── Input box ─────────────────────────────────────────────────────────────────

local inputBox = Instance.new("TextBox")
inputBox.Name                   = "Input"
inputBox.Size                   = UDim2.new(1, -48, 0, 22)
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
inputBox.TextYAlignment         = Enum.TextYAlignment.Top
inputBox.MultiLine              = true
inputBox.TextWrapped            = true
inputBox.AutomaticSize          = Enum.AutomaticSize.Y
inputBox.ZIndex                 = 3
inputBox.Parent                 = panel

-- ── Arg hint label ────────────────────────────────────────────────────────────

local hintFrame = Instance.new("Frame")
hintFrame.Name                  = "HintFrame"
hintFrame.Size                  = UDim2.new(1, 0, 0, 20)
hintFrame.Position              = UDim2.new(0, 0, 1, 5)
hintFrame.BackgroundTransparency = 1
hintFrame.BorderSizePixel       = 0
hintFrame.Visible               = false
hintFrame.ZIndex                = 3
hintFrame.Parent                = panel

local hintLabel = Instance.new("TextLabel")
hintLabel.Name                  = "Hint"
hintLabel.Size                  = UDim2.new(1, -42, 1, 0)
hintLabel.Position              = UDim2.new(0, 42, 0, 0)
hintLabel.BackgroundTransparency = 1
hintLabel.Font                  = Enum.Font.Gotham
hintLabel.TextSize              = CFG.HINT_SIZE
hintLabel.TextColor3            = CFG.HINT_COLOR
hintLabel.TextXAlignment        = Enum.TextXAlignment.Left
hintLabel.TextYAlignment        = Enum.TextYAlignment.Center
hintLabel.RichText              = true
hintLabel.Text                  = ""
hintLabel.ZIndex                = 4
hintLabel.Parent                = hintFrame

-- ── Autocomplete dropdown ──────────────────────────────────────────────────────

local dropdown = Instance.new("Frame")
dropdown.Name                  = "Autocomplete"
dropdown.AnchorPoint           = Vector2.new(0, 0)
dropdown.BackgroundColor3      = CFG.AC_BG
dropdown.BackgroundTransparency = 0.04
dropdown.BorderSizePixel       = 0
dropdown.Size                  = UDim2.new(1, 0, 0, 0)
dropdown.Position              = UDim2.new(0, 0, 1, 10)
dropdown.Visible               = false
dropdown.ClipsDescendants      = true
dropdown.ZIndex                = 10
dropdown.Parent                = panel

local dropdownCorner = Instance.new("UICorner")
dropdownCorner.CornerRadius = UDim.new(0, CFG.BAR_CORNER)
dropdownCorner.Parent = dropdown

local dropdownStroke = Instance.new("UIStroke")
dropdownStroke.Color        = CFG.AC_BORDER
dropdownStroke.Thickness    = 1
dropdownStroke.Transparency = 0.3
dropdownStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
dropdownStroke.Parent       = dropdown

local dropdownLayout = Instance.new("UIListLayout")
dropdownLayout.FillDirection    = Enum.FillDirection.Vertical
dropdownLayout.SortOrder        = Enum.SortOrder.LayoutOrder
dropdownLayout.Padding          = UDim.new(0, 0)
dropdownLayout.Parent           = dropdown

-- ── Player suggestion panel ────────────────────────────────────────────────────
-- Shows real server players filtered as you type a player-type argument.
-- Appears below the command bar only when the current arg expects a player.

local playerSuggestPanel = Instance.new("Frame")
playerSuggestPanel.Name                  = "PlayerSuggestions"
playerSuggestPanel.AnchorPoint           = Vector2.new(0.5, 0)
playerSuggestPanel.Size                  = UDim2.new(0, CFG.BAR_WIDTH, 0, CFG.PS_ROW_HEIGHT * CFG.PS_MAX_ENTRIES)
playerSuggestPanel.Position              = UDim2.new(0.5, 0, 1, 10)
playerSuggestPanel.BackgroundColor3      = CFG.PS_BG
playerSuggestPanel.BackgroundTransparency = 0.04
playerSuggestPanel.BorderSizePixel       = 0
playerSuggestPanel.Visible               = false
playerSuggestPanel.ClipsDescendants      = true
playerSuggestPanel.ZIndex                = 9
playerSuggestPanel.Parent                = panel

local pspCorner = Instance.new("UICorner")
pspCorner.CornerRadius = UDim.new(0, CFG.BAR_CORNER)
pspCorner.Parent = playerSuggestPanel

local pspStroke = Instance.new("UIStroke")
pspStroke.Color        = CFG.PS_BORDER
pspStroke.Thickness    = 1
pspStroke.Transparency = 0.3
pspStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
pspStroke.Parent = playerSuggestPanel

local pspScroll = Instance.new("ScrollingFrame")
pspScroll.Size                  = UDim2.new(1, 0, 1, 0)
pspScroll.BackgroundTransparency = 1
pspScroll.BorderSizePixel       = 0
pspScroll.ScrollBarThickness    = 3
pspScroll.ScrollBarImageColor3  = CFG.PROMPT_COLOR
pspScroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
pspScroll.ZIndex                = 10
pspScroll.Parent                = playerSuggestPanel

local pspScrollLayout = Instance.new("UIListLayout")
pspScrollLayout.FillDirection = Enum.FillDirection.Vertical
pspScrollLayout.SortOrder     = Enum.SortOrder.LayoutOrder
pspScrollLayout.Padding       = UDim.new(0, 0)
pspScrollLayout.Parent        = pspScroll

-- ─── Player suggestion state & helpers ────────────────────────────────────────

local filteredPlayers: { string } = {}   -- current Name list shown
local playerSuggestIndex = 1             -- highlighted row (for Tab)
local psRows: { Frame } = {}             -- reusable row frames

local PLAYER_ARG_LABELS = { player = true, from = true, to = true }

local function isPlayerArg(label: string): boolean
        return PLAYER_ARG_LABELS[label:lower():gsub("%?", "")] == true
end

local function buildPsRow(index: number): Frame
        if psRows[index] then return psRows[index] end

        local row = Instance.new("Frame")
        row.Name                   = "PSRow" .. index
        row.LayoutOrder            = index
        row.Size                   = UDim2.new(1, 0, 0, CFG.PS_ROW_HEIGHT)
        row.BackgroundColor3       = CFG.PS_HOVER_BG
        row.BackgroundTransparency = 1
        row.BorderSizePixel        = 0
        row.ZIndex                 = 10
        row.Parent                 = pspScroll

        local icon = Instance.new("TextLabel")
        icon.Name                   = "Icon"
        icon.Size                   = UDim2.new(0, 36, 1, 0)
        icon.Position               = UDim2.new(0, 0, 0, 0)
        icon.BackgroundTransparency = 1
        icon.Font                   = CFG.FONT
        icon.TextSize               = 13
        icon.TextColor3             = CFG.PROMPT_COLOR
        icon.Text                   = "⬡"
        icon.TextXAlignment         = Enum.TextXAlignment.Center
        icon.TextYAlignment         = Enum.TextYAlignment.Center
        icon.ZIndex                 = 11
        icon.Parent                 = row

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name                   = "PlayerName"
        nameLabel.Size                   = UDim2.new(1, -44, 1, 0)
        nameLabel.Position               = UDim2.new(0, 44, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font                   = CFG.FONT
        nameLabel.TextSize               = CFG.TEXT_SIZE - 1
        nameLabel.TextColor3             = CFG.PS_TEXT_COLOR
        nameLabel.TextXAlignment         = Enum.TextXAlignment.Left
        nameLabel.TextYAlignment         = Enum.TextYAlignment.Center
        nameLabel.ZIndex                 = 11
        nameLabel.Parent                 = row

        local divider = Instance.new("Frame")
        divider.Name                  = "Divider"
        divider.Size                  = UDim2.new(1, -44, 0, 1)
        divider.Position              = UDim2.new(0, 44, 1, -1)
        divider.BackgroundColor3      = CFG.PS_BORDER
        divider.BackgroundTransparency = 0.6
        divider.BorderSizePixel       = 0
        divider.ZIndex                = 11
        divider.Parent                = row

        local hitBtn = Instance.new("TextButton")
        hitBtn.Size                   = UDim2.new(1, 0, 1, 0)
        hitBtn.BackgroundTransparency = 1
        hitBtn.Text                   = ""
        hitBtn.ZIndex                 = 12
        hitBtn.Parent                 = row

        -- Click: insert player name into the input box
        hitBtn.MouseButton1Click:Connect(function()
                local chosen = filteredPlayers[index]
                if not chosen then return end
                local name   = chosen:gsub(" %(me%)$", "")
                local prefix = inputBox.Text:match("^(.*%s)") or ""
                inputBox.Text = prefix .. name .. " "
                inputBox:CaptureFocus()
                task.defer(function() inputBox.CursorPosition = #inputBox.Text + 1 end)
        end)

        hitBtn.MouseEnter:Connect(function()
                playerSuggestIndex = index
                tw(row, 0.07, { BackgroundTransparency = 0.55 })
                local nl = row:FindFirstChild("PlayerName")
                if nl then tw(nl, 0.07, { TextColor3 = CFG.PROMPT_COLOR }) end
        end)
        hitBtn.MouseLeave:Connect(function()
                if playerSuggestIndex ~= index then
                        tw(row, 0.07, { BackgroundTransparency = 1 })
                        local nl = row:FindFirstChild("PlayerName")
                        if nl then tw(nl, 0.07, { TextColor3 = CFG.PS_TEXT_COLOR }) end
                end
        end)

        psRows[index] = row
        return row
end

local function highlightPsRow(targetIndex: number)
        playerSuggestIndex = targetIndex
        local count = math.min(#filteredPlayers, CFG.PS_MAX_ENTRIES)
        for i = 1, count do
                local row = psRows[i]
                if row and row.Visible then
                        local nl  = row:FindFirstChild("PlayerName")
                        local sel = (i == targetIndex)
                        tw(row, 0.07, { BackgroundTransparency = sel and 0.55 or 1 })
                        if nl then tw(nl, 0.07, { TextColor3 = sel and CFG.PROMPT_COLOR or CFG.PS_TEXT_COLOR }) end
                end
        end
end

local function refreshPlayerSuggestions(filter: string)
        -- Collect and filter players from the server
        local all = Players:GetPlayers()
        local lower = filter:lower()
        local matched: { string } = {}

        for _, p in all do
                if p ~= LocalPlayer then  -- skip self
                        if lower == ""
                                or p.Name:lower():sub(1, #lower) == lower
                                or p.DisplayName:lower():sub(1, #lower) == lower
                        then
                                table.insert(matched, p.Name)
                        end
                end
        end

        -- Also allow "me" to refer to yourself
        if lower == "" or ("me"):sub(1, #lower) == lower then
                table.insert(matched, 1, LocalPlayer.Name .. " (me)")
        end

        filteredPlayers = matched
        playerSuggestIndex = 1

        local count = math.min(#matched, CFG.PS_MAX_ENTRIES)

        if count == 0 then
                playerSuggestPanel.Visible = false
                return
        end

        -- Hide all rows first
        for _, row in psRows do
                row.Visible = false
        end

        -- Show / update rows
        for i = 1, count do
                local row = buildPsRow(i)
                row.Visible = true

                local nl  = row:FindFirstChild("PlayerName")
                local div = row:FindFirstChild("Divider")
                local isSelected = (i == 1)  -- first entry highlighted by default

                tw(row, 0.07, { BackgroundTransparency = isSelected and 0.55 or 1 })
                if nl then
                        nl.Text       = matched[i]
                        nl.TextColor3 = isSelected and CFG.PROMPT_COLOR or CFG.PS_TEXT_COLOR
                end
                if div then div.Visible = (i ~= count) end
        end

        local totalH = count * CFG.PS_ROW_HEIGHT
        playerSuggestPanel.Size     = UDim2.new(0, CFG.BAR_WIDTH, 0, totalH)
        pspScroll.CanvasSize        = UDim2.new(0, 0, 0, totalH)
        playerSuggestPanel.Visible  = true
end

local function hidePlayerSuggestions()
        playerSuggestPanel.Visible = false
        filteredPlayers = {}
end

-- ── Click-outside blocker ──────────────────────────────────────────────────────

local blocker = Instance.new("ImageButton")
blocker.Name                   = "Blocker"
blocker.Size                   = UDim2.new(1, 0, 1, 0)
blocker.Position               = UDim2.new(0, 0, 0, 0)
blocker.BackgroundTransparency = 1
blocker.ZIndex                 = 2
blocker.Visible                = false
blocker.Parent                 = gui

-- ─── Stacking notification system ───────────────────────────────────────────────
-- Each showNotification() call spawns a card that slides in from the right.
-- Cards stack upward from the bottom-right corner. When one leaves, the rest reflow.

local notifGui = Instance.new("ScreenGui")
notifGui.Name           = "CmdNotification"
notifGui.DisplayOrder   = 56
notifGui.ResetOnSpawn   = false
notifGui.IgnoreGuiInset = true
notifGui.Parent         = PlayerGui

local NOTIF_GAP  = 8
local MAX_NOTIFS = 5

-- notifFrames[1] = bottom-most (newest), notifFrames[n] = top-most (oldest)
local notifFrames = {}

local function slotY(i)
        -- i=1 → flush to bottom margin; each higher slot steps up by HEIGHT+GAP
        return -(CFG.NOTIF_MARGIN + (i - 1) * (CFG.NOTIF_HEIGHT + NOTIF_GAP))
end

local function reflowFrames()
        for i, f in ipairs(notifFrames) do
                tw(f, CFG.NOTIF_SLIDE,
                        { Position = UDim2.new(1, -CFG.NOTIF_MARGIN, 1, slotY(i)) },
                        Enum.EasingStyle.Quint)
        end
end

local function showNotification(message)
        -- Evict oldest when at capacity
        if #notifFrames >= MAX_NOTIFS then
                local oldest = notifFrames[#notifFrames]
                table.remove(notifFrames, #notifFrames)
                oldest:Destroy()
        end

        -- Build card — parent LAST so position is set before first render
        local f = Instance.new("Frame")
        f.Name                   = "Notif"
        f.AnchorPoint            = Vector2.new(1, 1)
        f.Size                   = UDim2.new(0, CFG.NOTIF_WIDTH, 0, CFG.NOTIF_HEIGHT)
        f.BackgroundColor3       = Color3.fromRGB(10, 10, 12)
        f.BackgroundTransparency = 0.08
        f.BorderSizePixel        = 0
        f.ZIndex                 = 20
        -- Start off-screen right at slot-1 height so there's no positional jump
        f.Position               = UDim2.new(1, CFG.NOTIF_WIDTH + CFG.NOTIF_MARGIN, 1, slotY(1))

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = f

        local stroke = Instance.new("UIStroke")
        stroke.Color           = CFG.BG_BORDER
        stroke.Thickness       = 1.5
        stroke.Transparency    = 0.2
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent          = f

        local accent = Instance.new("Frame")
        accent.Size                   = UDim2.new(0, 3, 1, -12)
        accent.Position               = UDim2.new(0, 6, 0, 6)
        accent.BackgroundColor3       = CFG.PROMPT_COLOR
        accent.BackgroundTransparency = 0
        accent.BorderSizePixel        = 0
        accent.ZIndex                 = 21
        accent.Parent                 = f

        local accentCorner = Instance.new("UICorner")
        accentCorner.CornerRadius = UDim.new(0, 2)
        accentCorner.Parent = accent

        local lbl = Instance.new("TextLabel")
        lbl.Size                   = UDim2.new(1, -22, 1, 0)
        lbl.Position               = UDim2.new(0, 18, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font                   = CFG.FONT
        lbl.TextSize               = 13
        lbl.TextColor3             = Color3.fromRGB(220, 220, 235)
        lbl.TextXAlignment         = Enum.TextXAlignment.Left
        lbl.TextYAlignment         = Enum.TextYAlignment.Center
        lbl.TextTruncate           = Enum.TextTruncate.AtEnd
        lbl.Text                   = message
        lbl.ZIndex                 = 21
        lbl.Parent                 = f

        -- Parent card now — position is already set off-screen so no flash
        f.Parent = notifGui

        -- Push existing cards up one slot
        for i, existing in ipairs(notifFrames) do
                tw(existing, CFG.NOTIF_SLIDE,
                        { Position = UDim2.new(1, -CFG.NOTIF_MARGIN, 1, slotY(i + 1)) },
                        Enum.EasingStyle.Quint)
        end

        -- New card is bottom (index 1)
        table.insert(notifFrames, 1, f)

        -- Slide new card in from the right
        tw(f, CFG.NOTIF_SLIDE,
                { Position = UDim2.new(1, -CFG.NOTIF_MARGIN, 1, slotY(1)) },
                Enum.EasingStyle.Quint)

        -- Auto-dismiss
        task.delay(CFG.NOTIF_DURATION, function()
                local idx = table.find(notifFrames, f)
                if not idx then return end  -- already evicted

                -- Slide the card off to the right from its current slot
                tw(f, CFG.NOTIF_SLIDE,
                        { Position = UDim2.new(1, CFG.NOTIF_WIDTH + CFG.NOTIF_MARGIN, 1, slotY(idx)) },
                        Enum.EasingStyle.Quint, Enum.EasingDirection.In)

                table.remove(notifFrames, idx)

                task.delay(CFG.NOTIF_SLIDE + 0.05, function()
                        f:Destroy()
                        reflowFrames()  -- close the gap left by the dismissed card
                end)
        end)
end

-- ─── Autocomplete rows (reusable) ─────────────────────────────────────────────

local acRows = {}

local function clearDropdown()
        for _, row in acRows do
                row.Visible = false
        end
end

local function buildDropdownRow(index: number): Frame
        local row = acRows[index]
        if row then return row end

        row = Instance.new("Frame")
        row.Name                  = "Row" .. index
        row.LayoutOrder           = index
        row.Size                  = UDim2.new(1, 0, 0, CFG.AC_ROW_HEIGHT)
        row.BackgroundColor3      = CFG.AC_HOVER_BG
        row.BackgroundTransparency = 1
        row.BorderSizePixel       = 0
        row.ZIndex                = 10
        row.Parent                = dropdown

        local pad = Instance.new("UIPadding")
        pad.PaddingLeft   = UDim.new(0, 42)
        pad.PaddingRight  = UDim.new(0, 12)
        pad.Parent = row

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name                  = "CmdName"
        nameLabel.Size                  = UDim2.new(0, 130, 1, 0)
        nameLabel.Position              = UDim2.new(0, 0, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font                  = CFG.FONT_MONO
        nameLabel.TextSize              = CFG.TEXT_SIZE - 1
        nameLabel.TextColor3            = CFG.CMD_COLOR
        nameLabel.TextXAlignment        = Enum.TextXAlignment.Left
        nameLabel.TextYAlignment        = Enum.TextYAlignment.Center
        nameLabel.ZIndex                = 11
        nameLabel.RichText              = true
        nameLabel.Parent                = row

        local descLabel = Instance.new("TextLabel")
        descLabel.Name                  = "Desc"
        descLabel.Size                  = UDim2.new(1, -134, 1, 0)
        descLabel.Position              = UDim2.new(0, 134, 0, 0)
        descLabel.BackgroundTransparency = 1
        descLabel.Font                  = Enum.Font.Gotham
        descLabel.TextSize              = CFG.HINT_SIZE
        descLabel.TextColor3            = CFG.AC_DESC_COLOR
        descLabel.TextXAlignment        = Enum.TextXAlignment.Left
        descLabel.TextYAlignment        = Enum.TextYAlignment.Center
        descLabel.TextTruncate          = Enum.TextTruncate.AtEnd
        descLabel.ZIndex                = 11
        descLabel.Parent                = row

        local divider = Instance.new("Frame")
        divider.Name                  = "Divider"
        divider.Size                  = UDim2.new(1, -42, 0, 1)
        divider.Position              = UDim2.new(0, 0, 1, -1)
        divider.BackgroundColor3      = CFG.AC_BORDER
        divider.BackgroundTransparency = 0.5
        divider.BorderSizePixel       = 0
        divider.ZIndex                = 11
        divider.Parent                = row

        local btn = Instance.new("TextButton")
        btn.Name                   = "HitBtn"
        btn.Size                   = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text                   = ""
        btn.ZIndex                 = 12
        btn.Parent                 = row

        btn.MouseButton1Click:Connect(function()
                if acMatches[index] then
                        inputBox.Text = acMatches[index].name .. " "
                        inputBox:CaptureFocus()
                        task.defer(function()
                                inputBox.CursorPosition = #inputBox.Text + 1
                        end)
                end
        end)

        btn.MouseEnter:Connect(function()
                acIndex = index
                -- Refresh highlights without a full rebuild
                for i, r in acRows do
                        if r and r.Visible then
                                tw(r, 0.06, { BackgroundTransparency = (i == acIndex) and 0.55 or 1 })
                                local nl = r:FindFirstChild("CmdName")
                                if nl then nl.TextColor3 = (i == acIndex) and Color3.fromRGB(230, 230, 245) or CFG.CMD_COLOR end
                        end
                end
        end)

        acRows[index] = row
        return row
end

function refreshDropdown()
        clearDropdown()

        local count = math.min(#acMatches, CFG.AC_MAX_ENTRIES)
        if count == 0 then
                dropdown.Visible  = false
                hintFrame.Visible = false
                return
        end

        dropdown.Size    = UDim2.new(1, 0, 0, count * CFG.AC_ROW_HEIGHT)
        dropdown.Visible = true

        for i = 1, count do
                local match = acMatches[i]
                local row   = buildDropdownRow(i)
                row.Visible  = true

                local nameL      = row:FindFirstChild("CmdName")
                local descL      = row:FindFirstChild("Desc")
                local isSelected = (i == acIndex)

                tw(row, 0.08, { BackgroundTransparency = isSelected and 0.55 or 1 })

                if nameL then
                        nameL.TextColor3 = isSelected and Color3.fromRGB(230, 230, 245) or CFG.CMD_COLOR
                        nameL.Text       = match.name
                end
                if descL then
                        descL.Text = match.entry.description
                end

                local div = row:FindFirstChild("Divider")
                if div then div.Visible = (i ~= count) end
        end

        -- Update arg hint
        local selected = acMatches[acIndex]
        if selected and #selected.entry.args > 0 then
                local parts = {}
                table.insert(parts, '<font color="#c8c8d8">' .. selected.entry.name .. "</font>")
                for _, arg in selected.entry.args do
                        local isOptional = arg:sub(-1) == "?"
                        local label = isOptional and arg:sub(1, -2) or arg
                        local color = isOptional and "#606070" or "#808090"
                        local wrap  = isOptional and "[" or "<"
                        local wrapE = isOptional and "]" or ">"
                        table.insert(parts, '<font color="' .. color .. '">' .. wrap .. label .. wrapE .. "</font>")
                end
                hintLabel.Text    = table.concat(parts, "  ")
                hintFrame.Visible = true
        else
                hintFrame.Visible = false
        end
end

-- ─── Autocomplete update ───────────────────────────────────────────────────────

local function updateAutocomplete()
        local text   = inputBox.Text
        local tokens = CommandRegistry.parseArgs(text)
        local query  = tokens[1] or ""

        local hasSpace = text:find("%s")
        if hasSpace then
                local chosen = CommandRegistry.COMMANDS[query:lower()]
                if chosen then
                        acMatches = { { name = query:lower(), entry = chosen } }
                        acIndex   = 1
                else
                        acMatches = {}
                end
                clearDropdown()
                dropdown.Visible = false

                if chosen and #chosen.args > 0 then
                        -- Build the hint line
                        local parts = {}
                        for _, arg in chosen.args do
                                local isOptional = arg:sub(-1) == "?"
                                local label = isOptional and arg:sub(1, -2) or arg
                                local color = isOptional and "#606070" or "#808090"
                                local wrap  = isOptional and "[" or "<"
                                local wrapE = isOptional and "]" or ">"
                                table.insert(parts, '<font color="' .. color .. '">' .. wrap .. label .. wrapE .. "</font>")
                        end
                        hintLabel.Text    = '<font color="#c8c8d8">' .. query:lower() .. "</font>  " .. table.concat(parts, "  ")
                        hintFrame.Visible = true

                        -- Determine which arg slot the user is currently filling
                        -- tokens[1] = command, tokens[2..] = args typed so far
                        local hasTrailingSpace = text:sub(-1) == " "
                        -- argPos: 1-based index into chosen.args
                        local argPos = hasTrailingSpace and (#tokens - 1 + 1) or (#tokens - 1)
                        argPos = math.max(1, argPos)

                        local currentFilter = hasTrailingSpace and "" or (tokens[#tokens] or "")

                        -- Show player suggestions only when the current arg expects a player
                        local argLabel = chosen.args[argPos] or ""
                        if isPlayerArg(argLabel) then
                                refreshPlayerSuggestions(currentFilter)
                        else
                                hidePlayerSuggestions()
                        end
                else
                        hintFrame.Visible = false
                        hidePlayerSuggestions()
                end
                return
        end

        -- Command name still being typed — hide player suggestions
        hidePlayerSuggestions()

        if query == "" then
                acMatches = {}
                refreshDropdown()
                return
        end

        acMatches = CommandRegistry.getMatches(query)
        acIndex   = 1
        refreshDropdown()
end

-- ─── Open / Close ─────────────────────────────────────────────────────────────

local openTInfo  = TweenInfo.new(CFG.ANIM_TIME, Enum.EasingStyle.Expo, Enum.EasingDirection.Out)
local closeTInfo = TweenInfo.new(CFG.ANIM_TIME, Enum.EasingStyle.Expo, Enum.EasingDirection.In)

local function openBar()
        if isOpen then return end
        isOpen = true
        historyIndex = 0
        savedDraft   = ""

        -- Show panel immediately — fully opaque from the start so it's never invisible
        panel.BackgroundTransparency = CFG.BG_TRANS_OPEN
        panel.Position               = UDim2.new(0.5, 0, 0, CFG.BAR_Y_CLOSED)
        panel.Visible                = true
        blocker.Visible              = true
        panelStroke.Transparency     = 0.1
        accentLine.BackgroundTransparency = 0.2
        promptLabel.TextTransparency = 0
        inputBox.TextTransparency    = 0

        -- Animate slide down into open position
        TweenService:Create(panel, openTInfo, {
                Position = UDim2.new(0.5, 0, 0, CFG.BAR_Y_OPEN),
        }):Play()

        inputBox:CaptureFocus()
end

local function closeBar()
        if not isOpen then return end
        isOpen = false
        historyIndex = 0

        dropdown.Visible          = false
        hintFrame.Visible         = false
        blocker.Visible           = false
        playerSuggestPanel.Visible = false

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

-- ─── Command execution ─────────────────────────────────────────────────────────

local function executeCommand()
        local raw = inputBox.Text:match("^%s*(.-)%s*$")
        if raw == "" then
                closeBar()
                return
        end

        local tokens  = CommandRegistry.parseArgs(raw)
        local cmdName = tokens[1] and tokens[1]:lower() or ""
        local args    = {}
        for i = 2, #tokens do
                table.insert(args, tokens[i])
        end

        if history[1] ~= raw then
                table.insert(history, 1, raw)
                if #history > CFG.HISTORY_MAX then
                        table.remove(history, #history)
                end
        end

        CommandRemotes.CommandExecuted:FireServer(cmdName, args)

        -- Fire success notification immediately on the client — no server round-trip needed.
        showNotification("✓  Command Executed")

        closeBar()
end


-- ─── Input event handling ──────────────────────────────────────────────────────

local inputFocused = false

inputBox.Focused:Connect(function()
        inputFocused = true
end)

inputBox.FocusLost:Connect(function(enterPressed)
        inputFocused = false
        if enterPressed then
                executeCommand()
        end
end)

inputBox:GetPropertyChangedSignal("Text"):Connect(function()
        if not isOpen then return end
        local text = inputBox.Text
        -- Strip tab characters (inserted by Tab key) and newlines (inserted by Enter in MultiLine mode)
        if text:find("[\t\n]") then
                local cleaned = text:gsub("[\t\n]", "")
                inputBox.Text = cleaned
                inputBox.CursorPosition = #cleaned + 1
                return
        end
        updateAutocomplete()
end)

blocker.MouseButton1Click:Connect(function()
        closeBar()
end)

-- ─── Single, simple input handler ─────────────────────────────────────────────
--
-- No ContextActionService: BindActionAtPriority is unreliable across Studio
-- versions and causes silent double-fire issues. UIS alone is sufficient.
--
-- Open key (; by default):
--   • gameProcessed = false  → bar is closed, nothing is focused → open
--   • gameProcessed = true   → a TextBox has focus (chat etc.) → ignore,
--                              don't steal focus away from what the player is typing
--   • bar is already open    → the command TextBox is focused so gameProcessed
--                              is true; use Escape or click-outside to close
--
-- All other keys only fire when the bar is open.

UserInputService.InputBegan:Connect(function(input, gameProcessed)

        -- ── Toggle open ──────────────────────────────────────────────────────────
        if input.KeyCode == CFG.OPEN_KEY then
                if not gameProcessed and not isOpen then
                        openBar()
                end
                return
        end

        -- ── Everything below only matters while the bar is open ──────────────────
        if not isOpen then return end

        -- Escape always closes, even while the TextBox is focused
        if input.KeyCode == Enum.KeyCode.Escape then
                closeBar()
                return
        end

        -- Keys that require the command TextBox to be focused
        if not inputFocused then return end

        if input.KeyCode == Enum.KeyCode.Return then
                executeCommand()
                return
        end

        -- Up/Down: navigate player suggestions when panel is open, else scroll history
        if input.KeyCode == Enum.KeyCode.Up then
                if playerSuggestPanel.Visible and #filteredPlayers > 0 then
                        local count = math.min(#filteredPlayers, CFG.PS_MAX_ENTRIES)
                        highlightPsRow(((playerSuggestIndex - 2) % count) + 1)
                else
                        if historyIndex == 0 then savedDraft = inputBox.Text end
                        historyIndex = math.min(historyIndex + 1, #history)
                        if history[historyIndex] then
                                inputBox.Text = history[historyIndex]
                                task.defer(function() inputBox.CursorPosition = #inputBox.Text + 1 end)
                        end
                end
                return
        end

        if input.KeyCode == Enum.KeyCode.Down then
                if playerSuggestPanel.Visible and #filteredPlayers > 0 then
                        local count = math.min(#filteredPlayers, CFG.PS_MAX_ENTRIES)
                        highlightPsRow((playerSuggestIndex % count) + 1)
                else
                        if historyIndex > 0 then
                                historyIndex -= 1
                                inputBox.Text = historyIndex == 0 and savedDraft or history[historyIndex]
                                task.defer(function() inputBox.CursorPosition = #inputBox.Text + 1 end)
                        end
                end
                return
        end

        -- Tab: complete player name if panel visible, otherwise complete command name
        if input.KeyCode == Enum.KeyCode.Tab then
                if playerSuggestPanel.Visible and #filteredPlayers > 0 then
                        local chosen = filteredPlayers[playerSuggestIndex] or filteredPlayers[1]
                        if chosen then
                                local name   = chosen:gsub(" %(me%)$", "")
                                local prefix = inputBox.Text:match("^(.*%s)") or ""
                                inputBox.Text = prefix .. name .. " "
                                task.defer(function() inputBox.CursorPosition = #inputBox.Text + 1 end)
                        end
                elseif #acMatches > 0 then
                        local match = acMatches[acIndex] or acMatches[1]
                        if match then
                                inputBox.Text = match.name .. " "
                                task.defer(function() inputBox.CursorPosition = #inputBox.Text + 1 end)
                        end
                end
                return
        end

        -- Ctrl+N / Ctrl+P: cycle autocomplete dropdown
        if input.KeyCode == Enum.KeyCode.N and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                if #acMatches > 0 then
                        acIndex = (acIndex % #acMatches) + 1
                        refreshDropdown()
                end
                return
        end

        if input.KeyCode == Enum.KeyCode.P and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                if #acMatches > 0 then
                        acIndex = ((acIndex - 2) % #acMatches) + 1
                        refreshDropdown()
                end
                return
        end
end)

-- ─── Server feedback toasts ────────────────────────────────────────────────────
-- Show success/failure messages returned by the server as right-side notifications.
-- Guarded: if the remote timed out (server not running), skip gracefully.

if CommandRemotes.CommandFeedback then
        CommandRemotes.CommandFeedback.OnClientEvent:Connect(function(success, msg)
                -- Success is handled immediately in executeCommand — only surface server errors here.
                if not success and typeof(msg) == "string" then
                        showNotification("✗  " .. msg)
                end
        end)
end

print("[CommandBar] Staff command bar active. Press ; to open.")
