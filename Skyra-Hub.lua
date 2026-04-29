local SKYRA_VERSION   = "1.0.0"
local BASE_URL        = "https://api.luarmor.net/files/v4/loaders/"
local LUARMOR_SDK_URL = "https://sdkapi-public.luarmor.net/library.lua"
local DISCORD_URL     = "https://discord.gg/uS8u3Z9B4V"

local games = {
    {
        display = "",
        uuid    = "",
        find    = { universe = 1 }
    },
    {
        display = "Build A Farm Factory",
        uuid    = "91ac45f3fe547c6b245ac3e78cb81370",
        find    = { universe = 9839808865 }
    },
}

local function saveKey(key)
    pcall(function()
        if writefile then
            writefile("Skyra-Key.txt", tostring(key))
        end
    end)
end

local function loadSavedKey()
    local ok, result = pcall(function()
        if readfile and isfile and isfile("Skyra-Key.txt") then
            return readfile("Skyra-Key.txt")
        end
        return nil
    end)
    if ok and type(result) == "string" then
        return result:match("^%s*(.-)%s*$")
    end
    return nil
end

local LuarmorAPI = nil

local function initLuarmor(scriptId)
    if LuarmorAPI and LuarmorAPI.script_id == scriptId then return end
    if type(scriptId) ~= "string" or scriptId == "" then return end

    local ok, lib = pcall(function()
        return loadstring(game:HttpGet(LUARMOR_SDK_URL))()
    end)

    if ok and type(lib) == "table" then
        LuarmorAPI           = lib
        LuarmorAPI.script_id = scriptId
    else
        LuarmorAPI = nil
        warn("[Skyra] SDK load failed: " .. tostring(lib))
    end
end

local function validateKey(key, scriptId)
    initLuarmor(scriptId)
    if not LuarmorAPI then return false, "LUARMOR_LOAD_FAILED" end

    local ok, result = pcall(function()
        return LuarmorAPI.check_key(tostring(key))
    end)

    if not ok then return false, "EXCEPTION: " .. tostring(result) end

    if type(result) == "table" then
        if result.code == "KEY_VALID" then return true, "KEY_VALID" end
        return false, tostring(result.code or result.message or "INVALID")
    elseif type(result) == "string" then
        if result:lower():find("valid") then return true, "KEY_VALID" end
        return false, result
    end

    return false, "UNEXPECTED: " .. type(result)
end

local place    = game.PlaceId
local universe = game.GameId

local function list(v)
    return type(v) == "table" and v or { v }
end

local marketName = nil
pcall(function()
    local info = game:GetService("MarketplaceService"):GetProductInfo(place)
    if info and info.Name then marketName = info.Name:lower() end
end)

local function findGame()
    for _, g in ipairs(games) do
        local f = g.find
        if f.universe and table.find(list(f.universe), universe) then return g end
        if f.place    and table.find(list(f.place), place)       then return g end
        if f.name and marketName and marketName:find(f.name:lower()) then return g end
    end
    return nil
end

local function loadGame(selected, key)
    getgenv().script_key = key
    _G.script_key        = key
    script_key           = key

    local url = BASE_URL .. selected.uuid .. ".lua"
    local ok, err = pcall(function()
        loadstring(game:HttpGet(url))()
    end)

    if not ok then
        warn("[Skyra] Load error:", tostring(err))
        return false, tostring(err)
    end

    return true
end

local function tryAutoLogin()
    local key = loadSavedKey()
               or (_G.script_key ~= "PUT-UR-KEY" and _G.script_key)
               or (script_key ~= "PUT-UR-KEY" and script_key)

    if not key or #key < 5 then return false end

    local selected = findGame()
    if not selected then return false end

    print("[Skyra] Saved key found, attempting auto-login...")

    local ok, code = validateKey(key, selected.uuid)
    if not ok then
        warn("[Skyra] Saved key invalid: " .. code .. " — showing UI")
        return false
    end

    print("[Skyra] Auto-login success → Loading " .. selected.display)
    loadGame(selected, key)
    return true
end

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local CoreGui      = game:GetService("CoreGui")
local playerGui    = Players.LocalPlayer:WaitForChild("PlayerGui")

local C = {
    bg          = Color3.fromRGB(10, 14, 26),
    bgCard      = Color3.fromRGB(16, 22, 40),
    bgHeader    = Color3.fromRGB(14, 20, 38),
    bgInput     = Color3.fromRGB(20, 28, 52),
    bgHover     = Color3.fromRGB(30, 42, 72),
    bgSuccess   = Color3.fromRGB(10, 30, 40),
    bgError     = Color3.fromRGB(34, 14, 20),
    bgInfo      = Color3.fromRGB(18, 26, 50),
    blue        = Color3.fromRGB(100, 180, 255),
    blueBright  = Color3.fromRGB(140, 200, 255),
    blueDim     = Color3.fromRGB(60, 120, 200),
    blueGlow    = Color3.fromRGB(80, 150, 230),
    textMain    = Color3.fromRGB(220, 235, 255),
    textSub     = Color3.fromRGB(140, 165, 210),
    textMuted   = Color3.fromRGB(80, 105, 155),
    textHint    = Color3.fromRGB(60, 85, 130),
    green       = Color3.fromRGB(80, 220, 160),
    red         = Color3.fromRGB(255, 100, 110),
    white       = Color3.fromRGB(255, 255, 255),
    black       = Color3.fromRGB(0, 0, 0),
}

local function tw(obj, props, t, style, dir)
    TweenService:Create(obj, TweenInfo.new(
        t     or 0.18,
        style or Enum.EasingStyle.Quad,
        dir   or Enum.EasingDirection.Out
    ), props):Play()
end

local function corner(p, r)
    local c = Instance.new("UICorner", p)
    c.CornerRadius = UDim.new(0, r or 8)
    return c
end

local function stroke(p, col, trans, thick)
    local s = Instance.new("UIStroke", p)
    s.Color        = col   or C.blue
    s.Transparency = trans or 0.7
    s.Thickness    = thick or 0.5
    return s
end

local function label(parent, props)
    local l = Instance.new("TextLabel", parent)
    l.BackgroundTransparency = 1
    l.BorderSizePixel        = 0
    for k, v in pairs(props) do l[k] = v end
    return l
end

local function makeDraggable(frame, handle)
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = inp.Position
            startPos  = frame.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local d = inp.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
end

local function createSpinner(parent)
    local holder = Instance.new("Frame", parent)
    holder.Size                   = UDim2.fromOffset(36, 12)
    holder.Position               = UDim2.new(0, 0, 0.5, -6)
    holder.BackgroundTransparency = 1
    holder.BorderSizePixel        = 0

    local dots = {}
    for i = 1, 3 do
        local dot = Instance.new("Frame", holder)
        dot.Size              = UDim2.fromOffset(6, 6)
        dot.Position          = UDim2.fromOffset((i - 1) * 10, 3)
        dot.BackgroundColor3  = C.blue
        dot.BackgroundTransparency = 0.2
        dot.BorderSizePixel   = 0
        corner(dot, 50)
        dots[i] = dot
    end

    local running = true
    task.spawn(function()
        local i = 0
        while running do
            i = (i % 3) + 1
            for j, d in ipairs(dots) do
                tw(d, {
                    BackgroundTransparency = j == i and 0 or 0.7,
                    Size     = j == i and UDim2.fromOffset(8, 8) or UDim2.fromOffset(6, 6),
                    Position = j == i
                        and UDim2.fromOffset((j-1)*10 - 1, 2)
                        or  UDim2.fromOffset((j-1)*10, 3),
                }, 0.2)
            end
            task.wait(0.35)
        end
    end)

    return holder, function() running = false end
end

local function buildUI()
    local old = CoreGui:FindFirstChild("SkyraHub") or playerGui:FindFirstChild("SkyraHub")
    if old then old:Destroy() end

    local scr = Instance.new("ScreenGui")
    scr.Name           = "SkyraHub"
    scr.IgnoreGuiInset = true
    scr.ResetOnSpawn   = false
    scr.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() scr.Parent = CoreGui end)
    if scr.Parent ~= CoreGui then scr.Parent = playerGui end

    local card = Instance.new("Frame", scr)
    card.Name             = "Card"
    card.Size             = UDim2.fromOffset(420, 0)
    card.AutomaticSize    = Enum.AutomaticSize.Y
    card.Position         = UDim2.new(0.5, -210, 0.5, -160)
    card.BackgroundColor3 = C.bgCard
    card.BorderSizePixel  = 0
    card.BackgroundTransparency = 1
    corner(card, 18)
    stroke(card, C.blueGlow, 0.65, 1)

    local innerHL = Instance.new("Frame", card)
    innerHL.Size             = UDim2.new(1, -2, 0, 1)
    innerHL.Position         = UDim2.fromOffset(1, 1)
    innerHL.BackgroundColor3 = C.blueBright
    innerHL.BackgroundTransparency = 0.7
    innerHL.BorderSizePixel  = 0

    tw(card, { BackgroundTransparency = 0 }, 0.3)

    local header = Instance.new("Frame", card)
    header.Size             = UDim2.new(1, 0, 0, 58)
    header.BackgroundColor3 = C.bgHeader
    header.BorderSizePixel  = 0
    corner(header, 18)

    local hFix = Instance.new("Frame", header)
    hFix.Size             = UDim2.new(1, 0, 0.5, 0)
    hFix.Position         = UDim2.new(0, 0, 0.5, 0)
    hFix.BackgroundColor3 = C.bgHeader
    hFix.BorderSizePixel  = 0

    local hBorder = Instance.new("Frame", header)
    hBorder.Size             = UDim2.new(1, -32, 0, 1)
    hBorder.Position         = UDim2.new(0, 16, 1, -1)
    hBorder.BackgroundColor3 = C.blue
    hBorder.BackgroundTransparency = 0.8
    hBorder.BorderSizePixel  = 0

    local iconBg = Instance.new("Frame", header)
    iconBg.Size             = UDim2.fromOffset(34, 34)
    iconBg.Position         = UDim2.new(0, 14, 0.5, -17)
    iconBg.BackgroundColor3 = C.blue
    iconBg.BackgroundTransparency = 0.82
    iconBg.BorderSizePixel  = 0
    corner(iconBg, 10)
    stroke(iconBg, C.blue, 0.55, 0.5)
    label(iconBg, {
        Size = UDim2.fromScale(1, 1),
        Text = "S", Font = Enum.Font.GothamBold,
        TextSize = 17, TextColor3 = C.blueBright,
    })

    label(header, {
        Size = UDim2.new(1, -120, 0, 22),
        Position = UDim2.new(0, 56, 0, 8),
        Text = "Skyra Hub", Font = Enum.Font.GothamBold,
        TextSize = 16, TextColor3 = C.textMain,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local verBadge = Instance.new("Frame", header)
    verBadge.Size             = UDim2.fromOffset(110, 18)
    verBadge.Position         = UDim2.new(0, 56, 0, 32)
    verBadge.BackgroundColor3 = C.blue
    verBadge.BackgroundTransparency = 0.82
    verBadge.BorderSizePixel  = 0
    corner(verBadge, 6)
    label(verBadge, {
        Size = UDim2.fromScale(1, 1),
        Text = "v" .. SKYRA_VERSION .. "  ·  Key System",
        Font = Enum.Font.GothamSemibold, TextSize = 10,
        TextColor3 = C.blue, TextTransparency = 0.1,
    })

    local ctrlColors = {
        Color3.fromRGB(255, 95, 86),
        Color3.fromRGB(255, 189, 46),
        Color3.fromRGB(39, 201, 63),
    }
    local winCtrl = Instance.new("Frame", header)
    winCtrl.Size             = UDim2.fromOffset(56, 12)
    winCtrl.Position         = UDim2.new(1, -68, 0.5, -6)
    winCtrl.BackgroundTransparency = 1
    winCtrl.BorderSizePixel  = 0

    for i, col in ipairs(ctrlColors) do
        local dot = Instance.new("Frame", winCtrl)
        dot.Size             = UDim2.fromOffset(10, 10)
        dot.Position         = UDim2.fromOffset((i-1)*16, 1)
        dot.BackgroundColor3 = col
        dot.BackgroundTransparency = 0.3
        dot.BorderSizePixel  = 0
        corner(dot, 50)
        if i == 1 then
            local btn = Instance.new("TextButton", dot)
            btn.Size = UDim2.fromScale(1, 1)
            btn.BackgroundTransparency = 1
            btn.Text = ""
            btn.BorderSizePixel = 0
            btn.MouseButton1Click:Connect(function() scr:Destroy() end)
        end
    end

    makeDraggable(card, header)

    local body = Instance.new("Frame", card)
    body.Size             = UDim2.new(1, 0, 0, 0)
    body.Position         = UDim2.fromOffset(0, 58)
    body.AutomaticSize    = Enum.AutomaticSize.Y
    body.BackgroundTransparency = 1
    body.BorderSizePixel  = 0

    local pad = Instance.new("UIPadding", body)
    pad.PaddingLeft   = UDim.new(0, 18)
    pad.PaddingRight  = UDim.new(0, 18)
    pad.PaddingTop    = UDim.new(0, 16)
    pad.PaddingBottom = UDim.new(0, 20)

    local bodyList = Instance.new("UIListLayout", body)
    bodyList.Padding   = UDim.new(0, 10)
    bodyList.SortOrder = Enum.SortOrder.LayoutOrder

    local statusWrap = Instance.new("Frame", body)
    statusWrap.Name             = "StatusWrap"
    statusWrap.Size             = UDim2.new(1, 0, 0, 36)
    statusWrap.BackgroundColor3 = C.bgInfo
    statusWrap.BorderSizePixel  = 0
    statusWrap.Visible          = false
    statusWrap.LayoutOrder      = 0
    corner(statusWrap, 8)
    local statusStroke = stroke(statusWrap, C.blue, 0.7, 0.5)

    local statusAccent = Instance.new("Frame", statusWrap)
    statusAccent.Size             = UDim2.new(0, 3, 1, -8)
    statusAccent.Position         = UDim2.fromOffset(0, 4)
    statusAccent.BackgroundColor3 = C.blue
    statusAccent.BorderSizePixel  = 0
    corner(statusAccent, 3)

    local statusLbl = label(statusWrap, {
        Size = UDim2.new(1, -52, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        Font = Enum.Font.GothamSemibold, TextSize = 13,
        TextColor3 = C.textSub,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = "",
    })

    local spinnerHolder = Instance.new("Frame", statusWrap)
    spinnerHolder.Size             = UDim2.fromOffset(36, 36)
    spinnerHolder.Position         = UDim2.new(1, -42, 0.5, -18)
    spinnerHolder.BackgroundTransparency = 1
    spinnerHolder.BorderSizePixel  = 0
    spinnerHolder.Visible          = false

    local stopSpinner = nil

    local sep = Instance.new("Frame", body)
    sep.Size             = UDim2.new(1, 0, 0, 1)
    sep.BackgroundColor3 = C.blue
    sep.BackgroundTransparency = 0.85
    sep.BorderSizePixel  = 0
    sep.LayoutOrder      = 1

    local keySection = Instance.new("Frame", body)
    keySection.Size             = UDim2.new(1, 0, 0, 0)
    keySection.AutomaticSize    = Enum.AutomaticSize.Y
    keySection.BackgroundTransparency = 1
    keySection.BorderSizePixel  = 0
    keySection.LayoutOrder      = 2

    local keySectionList = Instance.new("UIListLayout", keySection)
    keySectionList.Padding   = UDim.new(0, 7)
    keySectionList.SortOrder = Enum.SortOrder.LayoutOrder

    local keyRow = Instance.new("Frame", keySection)
    keyRow.Size             = UDim2.new(1, 0, 0, 16)
    keyRow.BackgroundTransparency = 1
    keyRow.BorderSizePixel  = 0
    keyRow.LayoutOrder      = 0

    label(keyRow, {
        Size = UDim2.new(0.5, 0, 1, 0),
        Text = "LICENSE KEY", Font = Enum.Font.GothamBold,
        TextSize = 11, TextColor3 = C.blue,
        TextTransparency = 0.3,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local gameBadgeFrame = Instance.new("Frame", keyRow)
    gameBadgeFrame.Size             = UDim2.new(0.5, 0, 1, 2)
    gameBadgeFrame.Position         = UDim2.new(0.5, 0, 0, -1)
    gameBadgeFrame.BackgroundTransparency = 1
    gameBadgeFrame.BorderSizePixel  = 0

    local detectedGame = findGame()
    label(gameBadgeFrame, {
        Size = UDim2.fromScale(1, 1),
        Text = detectedGame and ("▸  " .. detectedGame.display) or "Game not supported",
        Font = Enum.Font.GothamSemibold, TextSize = 10,
        TextColor3 = detectedGame and C.blue or C.red,
        TextTransparency = 0.35,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local inputWrap = Instance.new("Frame", keySection)
    inputWrap.Size             = UDim2.new(1, 0, 0, 42)
    inputWrap.BackgroundColor3 = C.bgInput
    inputWrap.BorderSizePixel  = 0
    inputWrap.LayoutOrder      = 1
    corner(inputWrap, 10)
    local inputStroke = stroke(inputWrap, C.blue, 0.72, 0.5)

    label(inputWrap, {
        Size = UDim2.fromOffset(18, 42),
        Position = UDim2.fromOffset(12, 0),
        Text = "🔑", Font = Enum.Font.Gotham,
        TextSize = 14, TextColor3 = C.blue,
        TextTransparency = 0.5,
    })

    local keyInput = Instance.new("TextBox", inputWrap)
    keyInput.Size              = UDim2.new(1, -40, 1, 0)
    keyInput.Position          = UDim2.fromOffset(55, 0)
    keyInput.BackgroundTransparency = 1
    keyInput.BorderSizePixel   = 0
    keyInput.Text              = ""
    keyInput.PlaceholderText   = "Enter your license key..."
    keyInput.PlaceholderColor3 = C.textHint
    keyInput.Font              = Enum.Font.Code
    keyInput.TextSize          = 13
    keyInput.TextColor3        = C.textMain
    keyInput.ClearTextOnFocus  = false
    keyInput.TextXAlignment    = Enum.TextXAlignment.Left

    keyInput.Focused:Connect(function()
        tw(inputStroke, { Transparency = 0.2, Thickness = 1 })
        tw(inputWrap, { BackgroundColor3 = C.bgHover })
    end)
    keyInput.FocusLost:Connect(function()
        tw(inputStroke, { Transparency = 0.72, Thickness = 0.5 })
        tw(inputWrap, { BackgroundColor3 = C.bgInput })
    end)

    local btnWrap = Instance.new("Frame", body)
    btnWrap.Size             = UDim2.new(1, 0, 0, 42)
    btnWrap.BackgroundTransparency = 1
    btnWrap.BorderSizePixel  = 0
    btnWrap.LayoutOrder      = 3

    local btnList = Instance.new("UIListLayout", btnWrap)
    btnList.FillDirection = Enum.FillDirection.Horizontal
    btnList.Padding       = UDim.new(0, 10)

    local submitBtn = Instance.new("TextButton", btnWrap)
    submitBtn.Size             = UDim2.new(0.6, -5, 1, 0)
    submitBtn.BackgroundColor3 = C.blueGlow
    submitBtn.BorderSizePixel  = 0
    submitBtn.Text             = "Submit key"
    submitBtn.Font             = Enum.Font.GothamBold
    submitBtn.TextSize         = 14
    submitBtn.TextColor3       = C.white
    submitBtn.AutoButtonColor  = false
    corner(submitBtn, 10)

    local btnHL = Instance.new("Frame", submitBtn)
    btnHL.Size             = UDim2.new(1, 0, 0.5, 0)
    btnHL.BackgroundColor3 = C.white
    btnHL.BackgroundTransparency = 0.88
    btnHL.BorderSizePixel  = 0
    corner(btnHL, 10)

    local getKeyBtn = Instance.new("TextButton", btnWrap)
    getKeyBtn.Size             = UDim2.new(0.4, -5, 1, 0)
    getKeyBtn.BackgroundColor3 = C.bgInput
    getKeyBtn.BorderSizePixel  = 0
    getKeyBtn.Text             = "Get key  ↗"
    getKeyBtn.Font             = Enum.Font.GothamBold
    getKeyBtn.TextSize         = 13
    getKeyBtn.TextColor3       = C.textSub
    getKeyBtn.AutoButtonColor  = false
    corner(getKeyBtn, 10)
    stroke(getKeyBtn, C.blue, 0.72, 0.5)

    label(body, {
        Size = UDim2.new(1, 0, 0, 13),
        LayoutOrder = 4,
        Text = "Don't have a key? Join our Discord to get one free.",
        Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = C.textHint,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    local function setStatus(msg, statusType, spinning)
        statusWrap.Visible = true

        if stopSpinner then stopSpinner() stopSpinner = nil end
        spinnerHolder.Visible = false
        for _, c in ipairs(spinnerHolder:GetChildren()) do c:Destroy() end

        statusLbl.Text = msg

        if statusType == "success" then
            statusWrap.BackgroundColor3   = C.bgSuccess
            statusAccent.BackgroundColor3 = C.green
            statusStroke.Color            = C.green
            statusLbl.TextColor3          = C.green
        elseif statusType == "error" then
            statusWrap.BackgroundColor3   = C.bgError
            statusAccent.BackgroundColor3 = C.red
            statusStroke.Color            = C.red
            statusLbl.TextColor3          = C.red
        else
            statusWrap.BackgroundColor3   = C.bgInfo
            statusAccent.BackgroundColor3 = C.blue
            statusStroke.Color            = C.blue
            statusLbl.TextColor3          = C.textSub
        end

        if spinning then
            spinnerHolder.Visible = true
            local _, stopFn = createSpinner(spinnerHolder)
            stopSpinner = stopFn
        end
    end

    local function closeUI()
        tw(card, {
            Position = UDim2.new(0.5, -210, 0.55, -160),
            BackgroundTransparency = 1,
        }, 0.35)
        task.delay(0.4, function()
            if scr and scr.Parent then scr:Destroy() end
        end)
    end

    submitBtn.MouseEnter:Connect(function()
        tw(submitBtn, { BackgroundColor3 = C.blueBright })
    end)
    submitBtn.MouseLeave:Connect(function()
        tw(submitBtn, { BackgroundColor3 = C.blueGlow })
    end)
    submitBtn.MouseButton1Down:Connect(function()
        tw(submitBtn, { BackgroundColor3 = C.blueDim })
    end)
    submitBtn.MouseButton1Up:Connect(function()
        tw(submitBtn, { BackgroundColor3 = C.blueGlow })
    end)
    getKeyBtn.MouseEnter:Connect(function()
        tw(getKeyBtn, { BackgroundColor3 = C.bgHover })
    end)
    getKeyBtn.MouseLeave:Connect(function()
        tw(getKeyBtn, { BackgroundColor3 = C.bgInput })
    end)

    getKeyBtn.MouseButton1Click:Connect(function()
        setStatus("Discord link copied!", "info")
        if setclipboard then setclipboard(DISCORD_URL) end
        task.delay(2, function()
            if statusWrap and statusWrap.Parent then
                statusWrap.Visible = false
            end
        end)
    end)

    submitBtn.MouseButton1Click:Connect(function()
        local key = keyInput.Text:match("^%s*(.-)%s*$")

        if key == "" or key == "PUT-UR-KEY" then
            setStatus("Please enter your license key.", "error")
            return
        end

        local selected = findGame()
        if not selected then
            setStatus("Unsupported game  ·  Universe: " .. tostring(universe), "error")
            return
        end

        submitBtn.Active = false
        submitBtn.Text   = "Validating..."
        tw(submitBtn, { BackgroundColor3 = C.blueDim })
        setStatus("Connecting to Luarmor...", "info", true)

        task.spawn(function()
            local ok, code = validateKey(key, selected.uuid)

            if not ok then
                setStatus("Invalid key  ·  " .. code, "error")
                submitBtn.Active = true
                submitBtn.Text   = "Submit key"
                tw(submitBtn, { BackgroundColor3 = C.blueGlow })
                return
            end

            saveKey(key)

            setStatus("Key verified ✓  ·  Loading " .. selected.display, "success")
            task.wait(0.5)
            setStatus("Loading " .. selected.display .. "...", "info", true)
            local old = CoreGui:FindFirstChild("SkyraHub") or playerGui:FindFirstChild("SkyraHub")
            if old then old:Destroy() end

            local loadOk, loadErr = loadGame(selected, key)

            if not loadOk then
                setStatus("Load failed: " .. tostring(loadErr), "error")
                submitBtn.Active = true
                submitBtn.Text   = "Submit key"
                tw(submitBtn, { BackgroundColor3 = C.blueGlow })
                return
            end

            setStatus("Launched " .. selected.display .. " ✓", "success")
            task.delay(1, closeUI)
        end)
    end)

    local savedKey = loadSavedKey()
                  or (_G.script_key ~= "PUT-UR-KEY" and _G.script_key or nil)
                  or (type(script_key) == "string" and script_key ~= "PUT-UR-KEY" and script_key or nil)

    if savedKey and #savedKey > 4 then
        keyInput.Text = savedKey
    end
end

task.spawn(function()
    local success = tryAutoLogin()
    if not success then
        buildUI()
    end
end)
