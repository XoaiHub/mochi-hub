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
-- 🚂 TELEPORT + CREATE PARTY (THEO CONFIG)
-- ==========================
if not getgenv().EnableTeleport then return end
repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local ZonesFolder = workspace:WaitForChild("PartyZones", 10)
local currentZone = nil
local partyCreated = false

-- Lấy HRP
local function getHRP()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart", 5)
end

-- Đếm số người trong zone
local function getPlayerCountInZone(zoneName)
    local zone = ZonesFolder:FindFirstChild(zoneName)
    if not zone then return math.huge end
    local hitbox = zone:FindFirstChild("Hitbox")
    if not hitbox then return math.huge end

    local count = 0
    for _, p in pairs(Players:GetPlayers()) do
        local char = p.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and (hrp.Position - hitbox.Position).Magnitude <= 15 then
            count += 1
        end
    end
    return count
end

-- Teleport
local function teleportTo(zoneName)
    local zone = ZonesFolder:FindFirstChild(zoneName)
    if not zone then return end
    local hitbox = zone:FindFirstChild("Hitbox")
    if not hitbox then return end

    local hrp = getHRP()
    if hrp then
        hrp.CFrame = CFrame.new(hitbox.Position + Vector3.new(0, getgenv().YOffset or 5, 0))
        currentZone = zoneName
        partyCreated = false
        print("[✅ Teleport đến]:", zoneName)
    end
end

-- Tạo Party (maxMembers lấy từ config tương ứng zone)
local function createParty(mode)
    local maxMembers = getgenv().TargetPlayersPerZone[currentZone] or 1
    maxMembers = math.clamp(maxMembers, 1, 4) -- Giới hạn 1–4 người

    local args = {{
        isPrivate = true,
        maxMembers = maxMembers,
        trainId = "default",
        gameMode = mode
    }}

    ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network")
        :WaitForChild("RemoteEvent"):WaitForChild("CreateParty"):FireServer(unpack(args))

    print(string.format("[🎉 Tạo Party: %s] | Số người: %d", mode, maxMembers))
end

-- Main loop
task.spawn(function()
    local zoneList = {}
    for name, _ in pairs(getgenv().TargetPlayersPerZone) do
        table.insert(zoneList, name)
    end
    table.sort(zoneList)

    while getgenv().EnableTeleport do
        if not partyCreated then
            for _, zoneName in ipairs(zoneList) do
                local target = getgenv().TargetPlayersPerZone[zoneName]
                local current = getPlayerCountInZone(zoneName)

                print(string.format("🔍 [%s]: %d/%d", zoneName, current, target))

                if current < target then
                    if currentZone ~= zoneName then
                        teleportTo(zoneName)
                    end

                    task.wait(1)

                    if currentZone == zoneName and not partyCreated then
                        if getgenv().EnableParty then
                            if getgenv().EnableParty["Normal"] then createParty("Normal") end
                            if getgenv().EnableParty["ScorchedEarth"] then createParty("Scorched Earth") end
                            if getgenv().EnableParty["Nightmare"] then createParty("Nightmare") end
                        end
                        partyCreated = true
                    end
                    break
                end
            end
        end

        task.wait(getgenv().TeleportInterval or 5)
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
bondLabel.Size = UDim2.new(0, 300, 0, 50)  -- Width: 300px, Height: 50px (có thể tùy chỉnh)
bondLabel.Position = UDim2.new(0.5, 0, 0.5, 0)  -- Giữa bondFrame
bondLabel.AnchorPoint = Vector2.new(0.5, 0.5)  -- Căn giữa theo toạ độ gốc
bondLabel.BackgroundTransparency = 1
bondLabel.Text = "Bond (+0)"
bondLabel.TextSize = 40
bondLabel.Font = Enum.Font.Gotham
bondLabel.TextColor3 = Color3.new(1, 1, 1)
bondLabel.TextXAlignment = Enum.TextXAlignment.Center
bondLabel.TextYAlignment = Enum.TextYAlignment.Center

-- ==========================
-- 🔁 Bond, Auto Farm, MaximGun, Train
-- ==========================
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

-- Chờ nhân vật load và UI biến mất
repeat task.wait() until player.Character and player.PlayerGui:FindFirstChild("LoadingScreenPrefab") == nil

-- Hàm chờ nhân vật mới khi respawn
local function waitForCharacter()
    repeat task.wait() until player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    return player.Character
end

-- Gọi lại play again
ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EndDecision"):FireServer(false)

-- Biến theo dõi Bond
_G.Bond = 0

-- Theo dõi Bond mới sinh
workspace:WaitForChild("RuntimeItems").ChildAdded:Connect(function(v)
    if v.Name:find("Bond") and v:FindFirstChild("Part") then
        v.Destroying:Connect(function()
            _G.Bond += 1
        end)
    end
end)

-- Cập nhật UI
spawn(function()
    while bondLabel do
        bondLabel.Text = "Bond (+" .. tostring(_G.Bond) .. ")"
        task.wait(2)
    end
end)

-- Đảm bảo camera
player.CameraMode = "Classic"
player.CameraMaxZoomDistance = math.huge
player.CameraMinZoomDistance = 30

-- Teleport xuống dưới map + chờ MaximGun
local char = waitForCharacter()
local hrp = char:WaitForChild("HumanoidRootPart")
hrp.Anchored = true
hrp.CFrame = CFrame.new(80, 3, -9000)

repeat task.wait() until workspace.RuntimeItems:FindFirstChild("MaximGun")

-- Ngồi vào MaximGun
for _, v in pairs(workspace.RuntimeItems:GetChildren()) do
    if v.Name == "MaximGun" and v:FindFirstChild("VehicleSeat") then
        local seat = v.VehicleSeat
        seat.Disabled = false
        seat:SetAttribute("Disabled", false)
        seat:Sit(char:FindFirstChild("Humanoid"))
    end
end

-- Teleport lại gần để chắc chắn
task.wait(0.5)
for _, v in pairs(workspace.RuntimeItems:GetChildren()) do
    if v.Name == "MaximGun" and v:FindFirstChild("VehicleSeat") and (hrp.Position - v.VehicleSeat.Position).Magnitude < 250 then
        hrp.CFrame = v.VehicleSeat.CFrame
    end
end

-- Chuẩn bị bay lên
task.wait(1)
hrp.Anchored = false
repeat wait() until char.Humanoid.Sit == true
task.wait(0.5)
char.Humanoid.Sit = false
task.wait(0.5)

-- Teleport lại cho chắc chắn ngồi
repeat task.wait()
    for _, v in pairs(workspace.RuntimeItems:GetChildren()) do
        if v.Name == "MaximGun" and v:FindFirstChild("VehicleSeat") and (hrp.Position - v.VehicleSeat.Position).Magnitude < 250 then
            hrp.CFrame = v.VehicleSeat.CFrame
        end
    end
until char.Humanoid.Sit == true

-- Bay đến Conductor
task.wait(0.9)
for _, v in pairs(workspace:GetChildren()) do
    if v:IsA("Model") and v:FindFirstChild("RequiredComponents") then
        local seat = v.RequiredComponents:FindFirstChild("Controls") and v.RequiredComponents.Controls:FindFirstChild("ConductorSeat") and v.RequiredComponents.Controls.ConductorSeat:FindFirstChild("VehicleSeat")
        if seat then
            local tween = TweenService:Create(hrp, TweenInfo.new(35, Enum.EasingStyle.Quad), {CFrame = seat.CFrame * CFrame.new(0, 20, 0)})
            tween:Play()
            local bv = Instance.new("BodyVelocity")
            bv.Name = "VelocityHandler"
            bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = hrp
            tween.Completed:Wait()
            bv:Destroy()
        end
    end
end

-- Lặp auto farm Bond
task.wait(0.9)
while true do
    if char and char:FindFirstChild("Humanoid") and char.Humanoid.Sit then
        -- Teleport vào khu farm
        local tp = TweenService:Create(hrp, TweenInfo.new(30, Enum.EasingStyle.Quad), {CFrame = CFrame.new(0.5, -78, -49429)})
        tp:Play()

        local bv = Instance.new("BodyVelocity")
        bv.Name = "VelocityHandler"
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.Parent = hrp

        -- Đợi bond xuất hiện
        repeat wait() until workspace.RuntimeItems:FindFirstChild("Bond")
        tp:Cancel()
        bv:Destroy()

        -- Nhặt từng bond
        for _, bond in pairs(workspace.RuntimeItems:GetChildren()) do
            if bond.Name:find("Bond") and bond:FindFirstChild("Part") then
                repeat task.wait()
                    if bond and bond:FindFirstChild("Part") then
                        hrp.CFrame = bond.Part.CFrame
                        ReplicatedStorage.Shared.Network.RemotePromise.Remotes.C_ActivateObject:FireServer(bond)
                    end
                until not bond:FindFirstChild("Part")
            end
        end
    end
    task.wait(1)
end

-- ==========================
-- auto Rejoin tránh lỗi
-- ==========================
if not getgenv().AutoRejoinConfig or not getgenv().AutoRejoinConfig["Enabled"] then return end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local placeId = game.PlaceId

-- chỉnh ở ngoài config
local minutes = tonumber(getgenv().AutoRejoinConfig["RejoinDelay"]) or 60
minutes = math.clamp(minutes, 1, 9999)

local totalSeconds = minutes * 60
local startTime = os.time()

task.spawn(function()
    while true do
        task.wait(1)
        local elapsed = os.time() - startTime
        if elapsed >= totalSeconds then
            pcall(function()
                LocalPlayer:Kick("Auto Rejoin sau " .. minutes .. " phút.")
            end)
            task.wait(3)
            TeleportService:Teleport(placeId, LocalPlayer)
            break
        end
    end
end)
