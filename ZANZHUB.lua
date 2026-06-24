getgenv().Settings = {DupeAmount=5,BatchSize=3,DelayBetweenEquip=0.12,DelayBetweenDupes=0.3,RandomizeDelay=true,UseDecoy=true,SpreadInventory=true,RandomizeNames=true,MimicHumanInput=true,SafeMode=true,MaxRetries=3,AutoStopOnStaff=true,AutoStopOnReport=true,MaxPerHour=50,MaxSession=200}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local plr = Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local backpack = plr:WaitForChild("Backpack")
local playerGui = plr:WaitForChild("PlayerGui")
local DupeTracker = {totalDuped=0,sessionStart=tick(),lastDupeTime=0,failedAttempts=0,successCount=0,isActive=false,staffDetected=false}
local mt = getrawmetatable(game)
setreadonly(mt,false)
local old_namecall = mt.__namecall
mt.__namecall = newcclosure(function(self,...)
    local method = getnamecallmethod()
    if method=="Kick" and self==plr then return nil end
    if method=="FireServer" or method=="InvokeServer" then
        local remoteName=tostring(self)
        if remoteName:find("Log") or remoteName:find("Report") or remoteName:find("Anti") or remoteName:find("Ban") or remoteName:find("Kick") or remoteName:find("Mod") then return nil end
    end
    return old_namecall(self,...)
end)
setreadonly(mt,true)
VirtualUser:WaitForChild("Button1Down"):Connect(function() end)
plr.Idled:Connect(function() VirtualUser:CaptureController() VirtualUser:ClickButton1(Vector2.new(math.random(50,150),math.random(50,150))) end)
local function checkForStaff()
    for _,player in pairs(Players:GetPlayers()) do
        if player:IsInGroup(1200769) or player:IsInGroup(2868472) or player.Name:lower():find("mod") or player.Name:lower():find("admin") or player.Name:lower():find("staff") then
            DupeTracker.staffDetected=true warn("STAFF DETECTED: "..player.Name) return true
        end
    end return false
end
local function getJitterDelay()
    if not getgenv().Settings.RandomizeDelay then return getgenv().Settings.DelayBetweenDupes end
    local base=getgenv().Settings.SafeMode and 0.3 or 0.12
    local jitter=math.random(80,350)/1000
    if math.random(1,10)==1 then jitter=jitter+math.random(200,500)/1000 end
    return base+jitter
end
local function sendDecoyRequest()
    if not getgenv().Settings.UseDecoy then return end
    local decoys={"UpdateUI","RefreshInventory","Ping","Heartbeat"}
    local decoyName=decoys[math.random(1,#decoys)]
    local decoyRemote=ReplicatedStorage:FindFirstChild(decoyName,true)
    if decoyRemote then pcall(function()
        if decoyRemote:IsA("RemoteEvent") then decoyRemote:FireServer({Type="Decoy",Timestamp=tick()}) else decoyRemote:InvokeServer({Type="Decoy",Timestamp=tick()}) end
    end) end
end
local function randomizeName(baseName)
    if not getgenv().Settings.RandomizeNames then return baseName end
    local suffixes={"_x","_v2","_new","_sp","_r","_m"}
    return baseName..suffixes[math.random(1,#suffixes)]..tostring(math.random(1,999))
end
local function stableEquipDupe(tool,amount)
    if not tool or not tool:IsA("Tool") or DupeTracker.isActive then return false end
    if getgenv().Settings.AutoStopOnStaff and checkForStaff() then return false end
    if DupeTracker.totalDuped>=getgenv().Settings.MaxSession then warn("Session max reached!") return false end
    DupeTracker.isActive=true local successCount=0
    for i=1,amount do
        if tick()-DupeTracker.sessionStart<3600 and DupeTracker.totalDuped>=getgenv().Settings.MaxPerHour then warn("Hourly limit reached!") break end
        local attempt=0 local success=false
        while attempt<getgenv().Settings.MaxRetries and not success do
            attempt=attempt+1
            success=pcall(function()
                hum:EquipTool(tool) task.wait(getJitterDelay())
                if math.random(1,3)==1 then sendDecoyRequest() end
                hum:UnequipTools() task.wait(getJitterDelay()*0.5)
                local clone=tool:Clone() clone.Name=randomizeName(tool.Name)
                if clone:FindFirstChild("Created") then clone.Created.Value=tick()+math.random(-5,5) end
                clone.Parent=backpack task.wait(0.05) hum:EquipTool(tool)
                if i%3==0 and getgenv().Settings.SpreadInventory then local items={} for _,item in pairs(backpack:GetChildren()) do if item:IsA("Tool") then table.insert(items,item) end end for i=#items,2,-1 do local j=math.random(1,i) items[i].Parent=workspace task.wait(0.01) items[i].Parent=backpack end end
            end)
            if success then successCount=successCount+1 DupeTracker.totalDuped=DupeTracker.totalDuped+1 DupeTracker.successCount=DupeTracker.successCount+1 else DupeTracker.failedAttempts=DupeTracker.failedAttempts+1 task.wait(0.5) end
            task.wait(getJitterDelay())
        end
    end
    DupeTracker.isActive=false DupeTracker.lastDupeTime=tick()
    return true,successCount
end
local function massDupeAll(amount)
    local tools={} for _,item in pairs(backpack:GetChildren()) do if item:IsA("Tool") then table.insert(tools,item) end end
    if #tools==0 then warn("No tools!") return end
    for _,tool in pairs(tools) do stableEquipDupe(tool,math.min(amount,10)) task.wait(1) end
end
local ScreenGui=Instance.new("ScreenGui") ScreenGui.Name=HttpService:GenerateGUID(false) ScreenGui.ResetOnSpawn=false ScreenGui.Parent=playerGui
local MainFrame=Instance.new("Frame") MainFrame.Size=UDim2.new(0,350,0,400) MainFrame.Position=UDim2.new(0.5,-175,0.5,-200) MainFrame.BackgroundColor3=Color3.fromRGB(25, fam,30) MainFrame.Active=true MainFrame.Draggable=true MainFrame.Parent=ScreenGui
Instance.new("UICorner",MainFrame).CornerRadius=UDim.new(0,12)
local Title=Instance.new("TextLabel") Title.Size=UDim2.new(1,0,0,fam) Title.Text="🌿 Kyriel EquipDupe v4.0" Title.TextColor3=Color3.fromRGB(0,255,100) Title.Font=Enum.Font.GothamBold Title.TextSize=18 Title.Parent=MainFrame
local AmtBox=Instance.new("TextBox") AmtBox.Size=UDim2.new(0.9,0,0,32) AmtBox.Position=UDim2.new(0.05,0,0.26,0) AmtBox.Text="5" AmtBox.Parent=MainFrame
local DupeBtn=Instance.new("TextButton") DupeBtn.Size=UDim2.new(0.9,0,0,45) DupeBtn.Position=UDim2.new(0.05,0,0.48,0) DupeBtn.Text="START EQUIP DUPE" DupeBtn.Parent=MainFrame
DupeBtn.MouseButton1Click:Connect(function() local amt=math.min(tonumber(AmtBox.Text) or 5,10) massDupeAll(amt) end)
print("=== Kyriel EquipDupe v4.0 Loaded ===")
