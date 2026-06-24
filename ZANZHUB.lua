local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Fly = {enabled=false, flying=false, speed=50}
local ESP = {enabled=false, teamCheck=false, maxDist=3000, txtSize=14}
local Keys = {flyToggle=Enum.KeyCode.F}
local Connections = {}
local ESPData = {}

local function randStr(len)
    local t = {}
    for i = 1, (len or 12) do
        t[i] = string.char(math.random(65, 90) + math.random(0, 1) * 32)
    end
    return table.concat(t)
end

local function cleanup(obj)
    pcall(function()
        if type(obj) == "table" then
            for _, v in pairs(obj) do
                if typeof(v) == "Instance" then pcall(function() v:Destroy() end) end
            end
        elseif typeof(obj) == "Instance" then
            obj:Destroy()
        end
    end)
end

local function disconnect(c)
    if c and typeof(c) == "RBXScriptConnection" then
        pcall(function() c:Disconnect() end)
    end
end

-- ===== FLY =====
local flyParts = {}
local flyConn = nil

local function killFly()
    Fly.flying = false
    disconnect(flyConn)
    flyConn = nil
    cleanup(flyParts)
    flyParts = {}
    pcall(function()
        local c = LocalPlayer.Character
        if c then
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then h.PlatformStand = false end
        end
    end)
end

local function buildFly()
    killFly()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = false end

    local gyro = Instance.new("BodyGyro")
    gyro.MaxTorque = Vector3.new(1/0, 1/0, 1/0)
    gyro.P = 30000
    gyro.D = 500
    gyro.Name = randStr()
    gyro.Parent = root

    local vel = Instance.new("BodyVelocity")
    vel.MaxForce = Vector3.new(1/0, 1/0, 1/0)
    vel.P = 5000
    vel.Velocity = Vector3.zero
    vel.Name = randStr()
    vel.Parent = root

    flyParts = {gyro=gyro, vel=vel}
    Fly.flying = true

    flyConn = RunService.Heartbeat:Connect(function()
        if not Fly.flying then return end
        local c = LocalPlayer.Character
        if not c then return end
        local rp = c:FindFirstChild("HumanoidRootPart")
        if not rp then return end
        local g = rp:FindFirstChildOfClass("BodyGyro")
        local v = rp:FindFirstChildOfClass("BodyVelocity")
        if not g or not v then return end

        local cf = Camera.CFrame
        local dir = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.yAxis end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.yAxis end

        v.Velocity = dir.Magnitude > 0 and dir.Unit * Fly.speed or Vector3.zero
        g.CFrame = CFrame.new(rp.Position, rp.Position + cf.LookVector)
    end)
end

local function toggleFly()
    Fly.enabled = not Fly.enabled
    if Fly.enabled then buildFly() else killFly() end
end

-- ===== ESP =====
local function nukeESP()
    for _, tbl in pairs(ESPData) do cleanup(tbl) end
    ESPData = {}
    for _, cx in ipairs(Connections) do disconnect(cx) end
    Connections = {}
end

local function attachESP(plr)
    if plr == LocalPlayer then return end

    local function wire(char)
        local hl = Instance.new("Highlight")
        hl.Name = randStr(14)
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillTransparency = 0.85
        hl.OutlineTransparency = 0
        hl.Parent = char

        local bg = Instance.new("BillboardGui")
        bg.Name = randStr(14)
        bg.AlwaysOnTop = true
        bg.Size = UDim2.new(0, 220, 0, 50)
        bg.StudsOffset = Vector3.new(0, 3.2, 0)
        bg.Adornee = char:WaitForChild("Head", 5)

        local tl = Instance.new("TextLabel")
        tl.BackgroundTransparency = 1
        tl.TextStrokeTransparency = 0
        tl.TextStrokeColor3 = Color3.new()
        tl.Font = Enum.Font.SourceSansBold
        tl.TextSize = ESP.txtSize
        tl.Size = UDim2.new(1, 0, 1, 0)
        tl.Parent = bg

        ESPData[plr] = {hl=hl, bg=bg, tl=tl}

        local tick = RunService.RenderStepped:Connect(function()
            if not ESP.enabled then return end
            local ourChar = LocalPlayer.Character
            local ourRoot = ourChar and ourChar:FindFirstChild("HumanoidRootPart")
            local theirChar = plr.Character
            if not theirChar then return end
            local theirRoot = theirChar:FindFirstChild("HumanoidRootPart")
            local theirHead = theirChar:FindFirstChild("Head")
            local theirHum = theirChar:FindFirstChildOfClass("Humanoid")
            if not theirRoot or not theirHead or not theirHum then return end

            local dist = ourRoot and (ourRoot.Position - theirRoot.Position).Magnitude or 99999
            local vis = dist <= ESP.maxDist

            bg.Enabled = vis
            hl.Enabled = vis
            if not vis then return end

            local hp = math.floor(theirHum.Health)
            local mhp = math.floor(theirHum.MaxHealth)
            local clr = Color3.fromRGB(255, 80, 80)
            local nmClr = Color3.fromRGB(255, 100, 100)

            if ESP.teamCheck and plr.Team == LocalPlayer.Team then
                clr = Color3.fromRGB(80, 255, 80)
                nmClr = Color3.fromRGB(80, 255, 100)
            end

            hl.FillColor = clr
            hl.OutlineColor = clr
            tl.TextColor3 = nmClr
            tl.Text = string.format("%s  |  %d/%d HP  |  %.0f st", plr.Name, hp, mhp, dist)
        end)
        table.insert(Connections, tick)
    end

    if plr.Character then wire(plr.Character) end
    table.insert(Connections, plr.CharacterAdded:Connect(wire))
end

local function refreshESP()
    nukeESP()
    if not ESP.enabled then return end
    for _, p in ipairs(Players:GetPlayers()) do attachESP(p) end
    table.insert(Connections, Players.PlayerAdded:Connect(function(p)
        if ESP.enabled then attachESP(p) end
    end))
    table.insert(Connections, Players.PlayerRemoving:Connect(function(p)
        if ESPData[p] then cleanup(ESPData[p]); ESPData[p] = nil end
    end))
end

local function toggleESP()
    ESP.enabled = not ESP.enabled
    refreshESP()
end

-- ===== KEYBIND =====
local function bindKey(keyRef, cb)
    table.insert(Connections, UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Keys[keyRef] then cb() end
    end))
end

bindKey("flyToggle", function() toggleFly(); syncUI() end)

-- ===== UI =====
local gui = Instance.new("ScreenGui")
gui.Name = randStr(12)
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
gui.ResetOnSpawn = false

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 340, 0, 500)
main.Position = UDim2.new(0.5, -170, 0.5, -250)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 23)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui

local uic = Instance.new("UICorner")
uic.CornerRadius = UDim.new(0, 8)
uic.Parent = main

local uis = Instance.new("UIStroke")
uis.Color = Color3.fromRGB(160, 50, 50)
uis.Thickness = 1.5
uis.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 38)
title.BackgroundColor3 = Color3.fromRGB(26, 26, 33)
title.TextColor3 = Color3.fromRGB(255, 100, 100)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 18
title.Text = "  ZANZ HUB v2"
title.TextXAlignment = Enum.TextXAlignment.Left
title.BorderSizePixel = 0
title.Parent = main

local tc = Instance.new("UICorner")
tc.CornerRadius = UDim.new(0, 8)
tc.Parent = title

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -36, 0, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(190, 45, 45)
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.TextSize = 18
closeBtn.Text = "X"
closeBtn.BorderSizePixel = 0
closeBtn.Parent = title
closeBtn.MouseButton1Click:Connect(function()
    gui:Destroy()
    nukeESP()
    killFly()
end)

local cc = Instance.new("UICorner")
cc.CornerRadius = UDim.new(0, 8)
cc.Parent = closeBtn

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -16, 1, -50)
scroll.Position = UDim2.new(0, 8, 0, 46)
scroll.CanvasSize = UDim2.new(0, 0, 0, 520)
scroll.ScrollBarThickness = 4
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.Parent = main

local function makeSection(parent, titleText, y, h)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -8, 0, h)
    f.Position = UDim2.new(0, 4, 0, y)
    f.BackgroundColor3 = Color3.fromRGB(26, 26, 33)
    f.BorderSizePixel = 0
    f.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = f
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -20, 0, 22)
    l.Position = UDim2.new(0, 10, 0, 6)
    l.BackgroundTransparency = 1
    l.TextColor3 = Color3.fromRGB(255, 140, 80)
    l.Font = Enum.Font.SourceSansBold
    l.TextSize = 14
    l.Text = " " .. titleText
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
    return f
end

local function makeBtn(parent, x, y, w, h, txt, bg, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, h)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = bg
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 12
    b.Text = txt
    b.BorderSizePixel = 0
    b.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 5)
    c.Parent = b
    if cb then b.MouseButton1Click:Connect(cb) end
    return b
end

local function makeLabel(parent, x, y, w, h, txt, sz)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0, w, 0, h)
    l.Position = UDim2.new(0, x, 0, y)
    l.BackgroundTransparency = 1
    l.TextColor3 = Color3.fromRGB(200, 200, 200)
    l.Font = Enum.Font.SourceSans
    l.TextSize = sz or 12
    l.Text = txt
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local function makeInput(parent, x, y, w, h, txt, cb)
    local b = Instance.new("TextBox")
    b.Size = UDim2.new(0, w, 0, h)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(38, 38, 45)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.SourceSans
    b.TextSize = 12
    b.Text = txt
    b.BorderSizePixel = 0
    b.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = b
    if cb then b.FocusLost:Connect(function(enter) cb(b, enter) end) end
    return b
end

local captureMode = false
local captureTarget = nil

-- FLY SECTION
local flySec = makeSection(scroll, "FLIGHT", 4, 170)
local flyBtn = makeBtn(flySec, 10, 32, 130, 30, "FLY: OFF", Color3.fromRGB(180, 55, 55), function()
    toggleFly()
    syncUI()
end)
makeLabel(flySec, 150, 32, 60, 30, "Speed:", 12)
local speedBox = makeInput(flySec, 210, 34, 70, 24, tostring(Fly.speed), function(box)
    local n = tonumber(box.Text)
    if n then Fly.speed = math.clamp(n, 1, 1000); speedBox.Text = tostring(Fly.speed) end
end)

makeLabel(flySec, 10, 75, 120, 20, "Fly Toggle Key:", 12)
local flyKeyBtn = makeBtn(flySec, 130, 72, 140, 24, "[" .. Keys.flyToggle.Name .. "]", Color3.fromRGB(55, 55, 65), function()
    captureMode = true
    captureTarget = "flyToggle"
    flyKeyBtn.Text = "... press any key ..."
    flyKeyBtn.BackgroundColor3 = Color3.fromRGB(220, 150, 30)
end)

makeLabel(flySec, 10, 110, 160, 20, "WASD = move | SPACE = up | SHIFT = down", 10)

-- ESP SECTION
local espSec = makeSection(scroll, "WALLHACK (ESP)", 188, 160)
local espBtn = makeBtn(espSec, 10, 32, 130, 30, "ESP: OFF", Color3.fromRGB(180, 55, 55), function()
    toggleESP()
    syncUI()
end)
makeBtn(espSec, 150, 32, 140, 30, "Refresh ESP", Color3.fromRGB(90, 55, 170), function()
    if ESP.enabled then refreshESP() end
end)

local tcBtn = makeBtn(espSec, 10, 72, 240, 26, "Team Check: OFF", Color3.fromRGB(38, 38, 45), function()
    ESP.teamCheck = not ESP.teamCheck
    tcBtn.Text = ESP.teamCheck and "Team Check: ON" or "Team Check: OFF"
    tcBtn.BackgroundColor3 = ESP.teamCheck and Color3.fromRGB(55, 90, 170) or Color3.fromRGB(38, 38, 45)
    if ESP.enabled then refreshESP() end
end)

makeLabel(espSec, 10, 108, 80, 20, "Max Dist:", 12)
local distBox = makeInput(espSec, 80, 110, 80, 22, tostring(ESP.maxDist), function(box)
    local n = tonumber(box.Text)
    if n then ESP.maxDist = math.clamp(n, 100, 99999) end
end)

makeLabel(espSec, 10, 138, 80, 20, "Text Size:", 12)
makeInput(espSec, 80, 140, 50, 20, tostring(ESP.txtSize), function(box)
    local n = tonumber(box.Text)
    if n then ESP.txtSize = math.clamp(n, 8, 24) end
end)

-- HOTKEY SECTION
local hkSec = makeSection(scroll, "CUSTOM HOTKEYS", 362, 140)
makeLabel(hkSec, 10, 32, 200, 20, "Fly Toggle Key:", 12)
local hkFlyBtn = makeBtn(hkSec, 150, 30, 150, 24, "[" .. Keys.flyToggle.Name .. "]", Color3.fromRGB(55, 55, 65), function()
    captureMode = true
    captureTarget = "flyToggle"
    hkFlyBtn.Text = "... press any key ..."
    hkFlyBtn.BackgroundColor3 = Color3.fromRGB(220, 150, 30)
end)
makeLabel(hkSec, 10, 65, 300, 20, "Rebind any key by clicking the button then pressing a key", 10)
makeLabel(hkSec, 10, 90, 300, 16, "Keybinds save for session only.", 10)

-- SYNC UI STATE
function syncUI()
    flyBtn.Text = Fly.enabled and "FLY: ON" or "FLY: OFF"
    flyBtn.BackgroundColor3 = Fly.enabled and Color3.fromRGB(55, 180, 55) or Color3.fromRGB(180, 55, 55)
    espBtn.Text = ESP.enabled and "ESP: ON" or "ESP: OFF"
    espBtn.BackgroundColor3 = ESP.enabled and Color3.fromRGB(55, 180, 55) or Color3.fromRGB(180, 55, 55)
    hkFlyBtn.Text = "[" .. Keys.flyToggle.Name .. "]"
    flyKeyBtn.Text = "[" .. Keys.flyToggle.Name .. "]"
end

-- GLOBAL KEY CAPTURE
table.insert(Connections, UIS.InputBegan:Connect(function(input, gpe)
    if not captureMode then return end
    captureMode = false
    if not input or input.UserInputType == Enum.UserInputType.MouseButton1 then return end
    local kc = input.KeyCode
    if kc == Enum.KeyCode.Unknown then return end
    if captureTarget and Keys[captureTarget] then
        Keys[captureTarget] = kc
    end
    syncUI()
    hkFlyBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
    flyKeyBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
    task.wait(0.1)
    for _, cx in ipairs(Connections) do disconnect(cx) end
    Connections = {}
    bindKey("flyToggle", function() toggleFly(); syncUI() end)
end))

-- RESPAWN HANDLER
table.insert(Connections, LocalPlayer.CharacterAdded:Connect(function()
    if Fly.enabled then
        killFly()
        task.wait(0.15)
        buildFly()
    end
end))

-- INIT
for _, p in ipairs(Players:GetPlayers()) do
    if ESP.enabled then attachESP(p) end
end

-- TELEPORT CLEANUP
LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Started then
        nukeESP()
        killFly()
    end
end)

-- PROTECT GUI
pcall(function()
    if syn and syn.protect_gui then
        syn.protect_gui(gui)
    end
end)

-- NOTIFY
pcall(function()
    game.StarterGui:SetCore("SendNotification", {
        Title = "ZANZ HUB v2",
        Text = "Loaded | F = Fly | Rebind in menu",
        Duration = 5,
    })
end)
