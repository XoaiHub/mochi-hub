-- ==========================
-- ⚙️ BOOST SERVER + LOCK FPS
-- ==========================
local cfg = getgenv().Settings

-- 🔒 Lock FPS thủ công
if cfg["Lock FPS"] and cfg["Lock FPS"]["Enabled"] then
    setfpscap(cfg["Lock FPS"]["FPS"])
end

-- ⚙️ Boost Server Script
local function optimizeGame()
    if not cfg["Boost Server"] then return end

    -- 🧹 Xoá object theo tên
    if cfg["Object Removal"] and cfg["Object Removal"]["Enabled"] then
        for _, obj in ipairs(workspace:GetDescendants()) do
            for _, name in ipairs(cfg["Object Removal"]["Targets"]) do
                if string.find(obj.Name:lower(), name:lower()) then
                    pcall(function() obj:Destroy() end)
                end
            end
        end
    end

    -- 💨 Xoá hiệu ứng
    if cfg["Remove Effects"] then
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                pcall(function() v:Destroy() end)
            end
        end
    end

    -- 🔇 Xoá âm thanh
    if cfg["Remove Sounds"] then
        for _, sound in ipairs(workspace:GetDescendants()) do
            if sound:IsA("Sound") and sound.Looped then
                pcall(function() sound:Stop(); sound:Destroy() end)
            end
        end
    end

    -- 🌙 Tối giản ánh sáng
    if cfg["Simplify Lighting"] then
        local lighting = game:GetService("Lighting")
        lighting.FogEnd = 1000000
        lighting.Brightness = 0
        lighting.GlobalShadows = false
    end
end

spawn(function()
    while true do
        optimizeGame()
        task.wait(5)
    end
end)

-- ==========================
-- 🚂 TELEPORT + CREATE PARTY
-- ==========================
if not getgenv().EnableTeleport then return end

repeat task.wait() until game:IsLoaded()
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function getCharacter()
    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart")
    return hrp
end

local function getHitbox()
    local zoneName = getgenv().TeleportZoneName or "PartyZone2"
    local hitbox = workspace:WaitForChild("PartyZones", 10):WaitForChild(zoneName, 10):WaitForChild("Hitbox", 10)
    return hitbox
end

local function createParty(mode)
    local args = {{
        isPrivate = true,
        maxMembers = 1,
        trainId = "default",
        gameMode = mode
    }}
    game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Network")
        :WaitForChild("RemoteEvent"):WaitForChild("CreateParty"):FireServer(unpack(args))
end

local success, err = pcall(function()
    local hrp = getCharacter()
    local hitbox = getHitbox()
    if hrp and hitbox then
        local yOffset = getgenv().YOffset or 5
        hrp.CFrame = CFrame.new(hitbox.Position + Vector3.new(0, yOffset, 0))
    else
        warn("Không tìm thấy HRP hoặc Hitbox")
    end
end)

if not success then warn("Teleport bị lỗi:", err) end

task.delay(5, function()
    if getgenv().EnableParty then
        if getgenv().EnableParty.Normal then createParty("Normal") end
        if getgenv().EnableParty.ScorchedEarth then createParty("Scorched Earth") end
        if getgenv().EnableParty.Nightmare then createParty("Nightmare") end
    end
end)
-- ==========================
-- 🧩 UI Mochi Hub
-- có thể tự xóa ui
-- ==========================
if game.CoreGui:FindFirstChild("MochiUI") then
    game.CoreGui.NexonUI:Destroy()
end

local gui = Instance.new("ScreenGui", game.CoreGui)
gui.Name = "MochiUi"
gui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame", gui)
mainFrame.Size = UDim2.new(0, 400, 0, 300)
mainFrame.Position = UDim2.new(0.5, 0, 0.4, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundTransparency = 1

local bondFrame = Instance.new("Frame", mainFrame)
bondFrame.Name = "BondUI"
bondFrame.Size = UDim2.new(0, 180, 0, 30)
bondFrame.Position = UDim2.new(0.5, 0, 0, 227)
bondFrame.AnchorPoint = Vector2.new(0.5, 0)
bondFrame.BackgroundTransparency = 1
bondFrame.BorderSizePixel = 0
bondFrame.Draggable = false
bondFrame.Active = true

local logo = Instance.new("ImageLabel", bondFrame)
logo.Size = UDim2.new(0, 24, 0, 24)
logo.Position = UDim2.new(0, 0, 0.5, 0)
logo.AnchorPoint = Vector2.new(0, 0.5)
logo.BackgroundTransparency = 1
logo.Image = "rbxassetid://..."
logo.ScaleType = Enum.ScaleType.Fit

local bondLabel = Instance.new("TextLabel", bondFrame)
bondLabel.Size = UDim2.new(1, -30, 1, 0)
bondLabel.Position = UDim2.new(0, 50, 0, -50)
bondLabel.BackgroundTransparency = 1
bondLabel.Text = "Bond (+0)"
bondLabel.TextSize = 40
bondLabel.Font = Enum.Font.Gotham
bondLabel.TextColor3 = Color3.new(1, 1, 1)
bondLabel.TextXAlignment = Enum.TextXAlignment.Left
bondLabel.TextYAlignment = Enum.TextYAlignment.Center

-- ==========================
-- 🔁 Bond, Auto Farm, MaximGun, Train
-- ==========================
if not game:IsLoaded() then game.Loaded:Wait() end
repeat task.wait() until player.Character and player.PlayerGui:FindFirstChild("LoadingScreenPrefab") == nil

game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("EndDecision"):FireServer(false)

_G.Bond = 0
workspace.RuntimeItems.ChildAdded:Connect(function(v)
    if v.Name:find("Bond") and v:FindFirstChild("Part") then
        v.Destroying:Connect(function()
            _G.Bond += 1
        end)
    end
end)

spawn(function()
    while bondLabel do
        bondLabel.Text = "Bond (+" .. tostring(_G.Bond) .. ")"
        task.wait(2)
    end
end)

player.CameraMode = "Classic"
player.CameraMaxZoomDistance = math.huge
player.CameraMinZoomDistance = 30
player.Character.HumanoidRootPart.Anchored = true
wait(0.3)

repeat task.wait()
    player.Character.HumanoidRootPart.Anchored = true
    player.Character.HumanoidRootPart.CFrame = CFrame.new(80, 3, -9000)
until workspace.RuntimeItems:FindFirstChild("MaximGun")

task.wait(0.3)
for _, v in pairs(workspace.RuntimeItems:GetChildren()) do
    if v.Name == "MaximGun" and v:FindFirstChild("VehicleSeat") then
        v.VehicleSeat.Disabled = false
        v.VehicleSeat:SetAttribute("Disabled", false)
        v.VehicleSeat:Sit(player.Character:FindFirstChild("Humanoid"))
    end
end

task.wait(0.5)
for _, v in pairs(workspace.RuntimeItems:GetChildren()) do
    if v.Name == "MaximGun" and v:FindFirstChild("VehicleSeat") and (player.Character.HumanoidRootPart.Position - v.VehicleSeat.Position).Magnitude < 250 then
        player.Character.HumanoidRootPart.CFrame = v.VehicleSeat.CFrame
    end
end

wait(1)
player.Character.HumanoidRootPart.Anchored = false
repeat wait() until player.Character.Humanoid.Sit == true
wait(0.5)
player.Character.Humanoid.Sit = false
wait(0.5)

repeat task.wait()
    for _, v in pairs(workspace.RuntimeItems:GetChildren()) do
        if v.Name == "MaximGun" and v:FindFirstChild("VehicleSeat") and (player.Character.HumanoidRootPart.Position - v.VehicleSeat.Position).Magnitude < 250 then
            player.Character.HumanoidRootPart.CFrame = v.VehicleSeat.CFrame
        end
    end
until player.Character.Humanoid.Sit == true

wait(0.9)
for _, v in pairs(workspace:GetChildren()) do
    if v:IsA("Model") and v:FindFirstChild("RequiredComponents") and v.RequiredComponents:FindFirstChild("Controls") and v.RequiredComponents.Controls:FindFirstChild("ConductorSeat") then
        local seat = v.RequiredComponents.Controls.ConductorSeat:FindFirstChild("VehicleSeat")
        if seat then
            local TpTrain = game:GetService("TweenService"):Create(player.Character.HumanoidRootPart, TweenInfo.new(35, Enum.EasingStyle.Quad), {CFrame = seat.CFrame * CFrame.new(0, 20, 0)})
            TpTrain:Play()
            local bv = Instance.new("BodyVelocity")
            bv.Name = "VelocityHandler"
            bv.Parent = player.Character.HumanoidRootPart
            bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bv.Velocity = Vector3.new(0, 0, 0)
            TpTrain.Completed:Wait()
        end
    end
end

wait(1)
while true do
    if player.Character.Humanoid.Sit then
        local TpEnd = game:GetService("TweenService"):Create(player.Character.HumanoidRootPart, TweenInfo.new(30, Enum.EasingStyle.Quad), {CFrame = CFrame.new(0.5, -78, -49429)})
        TpEnd:Play()
        local bv = Instance.new("BodyVelocity")
        bv.Name = "VelocityHandler"
        bv.Parent = player.Character.HumanoidRootPart
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Velocity = Vector3.new(0, 0, 0)
        repeat wait() until workspace.RuntimeItems:FindFirstChild("Bond")
        TpEnd:Cancel()
        for _, v in pairs(workspace.RuntimeItems:GetChildren()) do
            if v.Name:find("Bond") and v:FindFirstChild("Part") then
                repeat task.wait()
                    if v:FindFirstChild("Part") then
                        player.Character.HumanoidRootPart.CFrame = v.Part.CFrame
                        game:GetService("ReplicatedStorage").Shared.Network.RemotePromise.Remotes.C_ActivateObject:FireServer(v)
                    end
                until not v:FindFirstChild("Part")
            end
        end
    end
    task.wait()
end
