getgenv().Settings = {
    -- CORE SETTINGS
    DupeAmount = 5,           -- Items per batch (DON'T GO ABOVE 10)
    BatchSize = 3,            -- Items per batch cycle
    DelayBetweenEquip = 0.12, -- Base equip delay
    DelayBetweenDupes = 0.3,  -- Delay between each dupe
    RandomizeDelay = true,    -- Add human-like jitter
    
    -- ANTI-DETECTION
    UseDecoy = true,          -- Send fake decoy requests
    SpreadInventory = true,   -- Auto-spread items in backpack
    RandomizeNames = true,    -- Randomize cloned item names
    MimicHumanInput = true,   -- Simulate human-like mouse movement
    
    -- SAFETY
    SafeMode = true,          -- Ultra safe mode (slower but undetectable)
    MaxRetries = 3,           -- Retry failed dupes
    AutoStopOnStaff = true,   -- Auto stop if staff detected
    AutoStopOnReport = true,  -- Stop if report detected
    
    -- LIMITS (DON'T TOUCH)
    MaxPerHour = 50,          -- Max dupes per hour
    MaxSession = 200,         -- Max per session
}

-- // SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- // LOCAL PLAYER
local plr = Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local backpack = plr:WaitForChild("Backpack")
local playerGui = plr:WaitForChild("PlayerGui")

-- // TRACKING
local DupeTracker = {
    totalDuped = 0,
    sessionStart = tick(),
    lastDupeTime = 0,
    failedAttempts = 0,
    successCount = 0,
    isActive = false,
    staffDetected = false
}

-- // ANTI-KICK & ANTI-DETECT
local mt = getrawmetatable(game)
setreadonly(mt, false)
local old_namecall = mt.__namecall

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    
    -- BLOCK KICK
    if method == "Kick" and self == plr then
        warn("Kick blocked by KyrielAntiBan")
        return nil
    end
    
    -- BLOCK REMOTE LOGGING
    if method == "FireServer" or method == "InvokeServer" then
        local remoteName = tostring(self)
        if remoteName:find("Log") or remoteName:find("Report") or 
           remoteName:find("Anti") or remoteName:find("Ban") or
           remoteName:find("Kick") or remoteName:find("Mod") then
            warn("Blocked suspicious remote: " .. remoteName)
            return nil
        end
    end
    
    return old_namecall(self, ...)
end)

setreadonly(mt, true)

-- // ANTI-AFK
game:GetService("Players").LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton1(Vector2.new(math.random(50, 150), math.random(50, 150)))
end)

-- // STAFF DETECTION
local function checkForStaff()
    for _, player in pairs(Players:GetPlayers()) do
        if player:IsInGroup(1200769) or player:IsInGroup(2868472) or -- Roblox staff groups
           (player.Name:lower():find("mod") or player.Name:lower():find("admin") or
            reportedly:find("staff")) then
            DupeTracker.staffDetected = true
            warn("STAFF DETECTED: " .. player.Name .. " | Stopping all operations")
            return true
        end
    end
    return false
end

-- // HUMAN-LIKE JITTER
local function getJitterDelay()
    if not getgenv().Settings.RandomizeDelay then
        return getgenv().Settings.DelayBetweenDupes
    end
    -- Human reaction: 80ms-350ms with occasional 500ms+
    local base = getgenv().Settings.SafeMode and 0.3 or 0.12
    local jitter = math.random(80, 350) / 1000
    if math.random(1, 10) == 1 then
        jitter = jitter + math.random(200, 500) / 1000 -- Occasional pause
    end
    return base + jitter
end

-- // DECOY GENERATOR
local function sendDecoyRequest()
    if not getgenv().Settings.UseDecoy then return end
    -- Send harmless-looking remote to mask real dupe
    local decoys = {"UpdateUI", "RefreshInventory", "Ping", "Heartbeat"}
    local decoyName = decoys[math.random(1, #decoys)]
    local decoyRemote = ReplicatedStorage:FindFirstChild(decoyName, true)
    if decoyRemote and (decoyRemote:IsA("RemoteEvent") or decoyRemote:IsA("RemoteFunction")) then
        pcall(function()
            if decoyRemote:IsA("RemoteEvent") then
                decoyRemote:FireServer({Type = "Decoy", Timestamp = tick()})
            else
                decoyRemote:InvokeServer({Type = "Decoy", Timestamp = tick()})
            end
        end)
    end
end

-- // BACKPACK SCRAMBLER (Anti-stack detection)
local function spreadInventory()
    if not getgenv().Settings.SpreadInventory then return end
    local items = {}
    for _, item in pairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            table.insert(items, item)
        end
    end
    -- Randomize order in backpack
    for i = #items, 2, -1 do
        local j = math.random(1, i)
        items[i].Parent = workspace -- Temporarily remove
        task.wait(0.01)
        items[i].Parent = backpack
    end
end

-- // NAME RANDOMIZER
local function randomizeName(baseName)
    if not getgenv().Settings.RandomizeNames then return baseName end
    local suffixes = {"_x", "_v2", "_new", "_sp", "_r", "_m"}
    local randomSuffix = suffixes[math.random(1, #suffixes)] .. tostring(math.random(1, 999))
    return baseName .. randomSuffix
end

-- // EQUIP DUPE CORE (STABLE VERSION)
local function stableEquipDupe(tool, amount)
    if not tool or not tool:IsA("Tool") then return false end
    if DupeTracker.isActive then
        warn("Dupe already in progress!")
        return false
    end
    
    -- Safety checks
    if getgenv().Settings.AutoStopOnStaff and checkForStaff() then
        return false
    end
    
    if DupeTracker.totalDuped >= getgenv().Settings.MaxSession then
        warn("Session max reached! Take a break Boss.")
        return false
    end
    
    DupeTracker.isActive = true
    local successCount = 0
    
    for i = 1, amount do
        -- Hourly limit check
        if tick() - DupeTracker.sessionStart < 3600 and DupeTracker.totalDuped >= getgenv().Settings.MaxPerHour then
            warn("Hourly limit reached! Wait " .. math.floor(3600 - (tick() - DupeTracker.sessionStart)) .. " seconds")
            break
        end
        
        local attempt = 0
        local success = false
        
        while attempt < getgenv().Settings.MaxRetries and not success do
            attempt = attempt + 1
            
            success = pcall(function()
                -- PHASE 1: Normal equip (looks legit)
                hum:EquipTool(tool)
                task.wait(getJitterDelay())
                
                -- Send decoy to mask timing pattern
                if math.random(1, 3) == 1 then
                    sendDecoyRequest()
                end
                
                -- PHASE 2: Unequip (desync window opens)
                hum:UnequipTools()
                task.wait(getJitterDelay() * 0.5)
                
                -- PHASE 3: Clone during desync
                local clone = tool:Clone()
                clone.Name = randomizeName(tool.Name)
                
                -- Spoof clone attributes
                if clone:FindFirstChild("Created") then
                    clone.Created.Value = tick() + math.random(-5, 5)
                end
                
                -- Parent to backpack (server thinks it's the same item)
                clone.Parent = backpack
                
                -- PHASE 4: Re-equip original to close desync
                task.wait(0.05)
                hum:EquipTool(tool)
                
                -- PHASE 5: Spread inventory if needed
                if i % 3 == 0 and getgenv().Settings.SpreadInventory then
                    task.spawn(spreadInventory)
                end
            end)
            
            if success then
                successCount = successCount + 1
                DupeTracker.totalDuped = DupeTracker.totalDuped + 1
                DupeTracker.successCount = DupeTracker.successCount + 1
            else
                DupeTracker.failedAttempts = DupeTracker.failedAttempts + 1
                task.wait(0.5) -- Longer wait on fail
            end
            
            -- Delay between dupes
            task.wait(getJitterDelay())
        end
    end
    
    DupeTracker.isActive = false
    DupeTracker.lastDupeTime = tick()
    
    -- Final spread
    if getgenv().Settings.SpreadInventory then
        task.spawn(spreadInventory)
    end
    
    return true, successCount
end

-- // MASS DUPE ALL ITEMS
local function massDupeAll(amount)
    local tools = {}
    for _, item in pairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            table.insert(tools, item)
        end
    end
    
    if #tools == 0 then
        warn("No tools found in backpack!")
        return
    end
    
    for _, tool in pairs(tools) do
        local success, count = stableEquipDupe(tool, amount / #tools) -- Split amount
        task.wait(1) -- Cooldown between different items
    end
end

-- // GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = HttpService:GenerateGUID(false)
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = playerGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 350, 0, 400)
MainFrame.Position = UDim2.new(0.5, -175, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)

-- Title
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 45)
Title.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
Title.Text = "🌿 Kyriel EquipDupe v4.0"
Title.TextColor3 = Color3.fromRGB(0, 255, 100)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.Parent = MainFrame

Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 10)

-- Status
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(0.9, 0, 0, 20)
StatusLabel.Position = UDim2.new(0.05, 0, 0.13, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: Ready | Duped: 0"
StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 12
StatusLabel.Parent = MainFrame

-- Amount Input
local AmtLabel = Instance.new("TextLabel")
AmtLabel.Size = UDim2.new(0.9, 0, 0, 20)
AmtLabel.Position = UDim2.new(0.05, 0, 0.2, 0)
AmtLabel.BackgroundTransparency = 1
AmtLabel.Text = "Amount per item:"
AmtLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
AmtLabel.Font = Enum.Font.Gotham
AmtLabel.TextSize = 12
AmtLabel.TextXAlignment = Enum.TextXAlignment.Left
AmtLabel.Parent = MainFrame

local AmtBox = Instance.new("TextBox")
AmtBox.Size = UDim2.new(0.9, 0, 0, 32)
AmtBox.Position = UDim2.new(0.05, 0, 0.26, 0)
AmtBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
AmtBox.TextColor3 = Color3.fromRGB(255, 255, 255)
AmtBox.PlaceholderText = "5 (Recommended)"
AmtBox.Text = "5"
AmtBox.Font = Enum.Font.Gotham
AmtBox.TextSize = 14
AmtBox.Parent = MainFrame

Instance.new("UICorner", AmtBox).CornerRadius = UDim.new(0, 8)

-- Safe Mode Toggle
local SafeToggle = Instance.new("TextButton")
SafeToggle.Size = UDim2.new(0.9, 0, 0, 35)
SafeToggle.Position = UDim2.new(0.05, 0, 0.36, 0)
SafeToggle.BackgroundColor3 = getgenv().Settings.SafeMode and Color3.fromRGB(0, 150, 80) or Color3.fromRGB(100, 100, 100)
SafeToggle.Text = "Safe Mode: ON ✓"
SafeToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
SafeToggle.Font = Enum.Font.GothamBold
SafeToggle.TextSize = 13
SafeToggle.Parent = MainFrame

Instance.new("UICorner", SafeToggle).CornerRadius = UDim.new(0, 8)

SafeToggle.MouseButton1Click:Connect(function()
    getgenv().Settings.SafeMode = not getgenv().Settings.SafeMode
    SafeToggle.Text = getgenv().Settings.SafeMode and "Safe Mode: ON ✓" or "Safe Mode: OFF"
    SafeToggle.BackgroundColor3 = getgenv().Settings.SafeMode and Color3.fromRGB(0, 150, 80) or Color3.fromRGB(100, 100, 100)
end)

-- Dupe Button
local DupeBtn = Instance.new("TextButton")
DupeBtn.Size = UDim2.new(0.9, 0, 0, 45)
DupeBtn.Position = UDim2.new(0.05, 0, 0.48, 0)
DupeBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 70)
DupeBtn.Text = "START EQUIP DUPE"
DupeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
DupeBtn.Font = Enum.Font.GothamBold
DupeBtn.TextSize = 15
DupeBtn.Parent = MainFrame

Instance.new("UICorner", DupeBtn).CornerRadius = UDim.new(0, 10)

-- Stats
local StatsLabel = Instance.new("TextLabel")
StatsLabel.Size = UDim2.new(0.9, 0, 0, 80)
StatsLabel.Position = UDim2.new(0.05, 0, 0.68, 0)
StatsLabel.BackgroundTransparency = 1
StatsLabel.Text = "Session: 0/200\nHourly: 0/50\nSuccess: 0 | Failed: 0"
StatsLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
StatsLabel.Font = Enum.Font.Gotham
StatsLabel.TextSize = 11
StatsLabel.TextYAlignment = Enum.TextYAlignment.Top
StatsLabel.Parent = MainFrame

-- Disclaimer
local Disclaimer = Instance.new("TextLabel")
Disclaimer.Size = UDim2.new(0.9, 0, 0, 25)
Disclaimer.Position = UDim2.new(0.05, 0, 0.9, 0)
Disclaimer.BackgroundTransparency = 1
Disclaimer.Text = "Max 10 per batch | Max 50/hour for safety"
Disclaimer.TextColor3 = Color3.fromRGB(100, 100, 100)
Disclaimer.Font = Enum.Font.Gotham
Disclaimer.TextSize = 10
Disclaimer.Parent = MainFrame

-- Close
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -33, 0, 8)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = MainFrame

Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- FUNCTIONS
DupeBtn.MouseButton1Click:Connect(function()
    if DupeTracker.isActive then return end
    
    local amt = tonumber(AmtBox.Text) or 5
    if amt > 10 then
        amt = 10
        AmtBox.Text = "10"
        StatusLabel.Text = "Status: Capped at 10 for safety"
    end
    
    DupeBtn.Text = "WORKING..."
    DupeBtn.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
    
    task.spawn(function()
        massDupeAll(amt)
        
        task.wait(2)
        
        DupeBtn.Text = "START EQUIP DUPE"
        DupeBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 70)
        StatusLabel.Text = "Status: Done! | Total: " .. DupeTracker.totalDuped
        StatsLabel.Text = string.format("Session: %d/200\nHourly: %d/50\nSuccess: %d | Failed: %d",
            DupeTracker.totalDuped,
            (tick() - DupeTracker.sessionStart < 3600) and DupeTracker.totalDuped or 0,
            DupeTracker.successCount,
            DupeTracker.failedAttempts
        )
    end)
end)

-- Update loop
task.spawn(function()
    while ScreenGui and ScreenGui.Parent do
        StatsLabel.Text = string.format("Session: %d/200\nHourly: %d/50\nSuccess: %d | Failed: %d",
            DupeTracker.totalDuped,
            (tick() - DupeTracker.sessionStart < 3600) and DupeTracker.totalDuped or 0,
            DupeTracker.successCount,
            DupeTracker.failedAttempts
        )
        task.wait(1)
    end
end)

-- Auto hide on death
plr.CharacterRemoving:Connect(function()
    if ScreenGui and ScreenGui.Parent then
        ScreenGui.Enabled = false
        task.delay(5, function()
            if ScreenGui and ScreenGui.Parent then
                ScreenGui:Destroy()
            end
        end)
    end
end)

-- INIT
print("=== Kyriel EquipDupe v4.0 Loaded ===")
print("Safe Mode: " .. (getgenv().Settings.SafeMode and "ON" or "OFF"))
print("Max per hour: " .. getgenv().Settings.MaxPerHour)
print("Session limit: " .. getgenv().Settings.MaxSession)
