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
        print("[✅ Đã teleport đến]:", zoneName)
    end
end

-- Create Party
local function createParty(mode)
    local args = {{
        isPrivate = true,
        maxMembers = 1,
        trainId = "default",
        gameMode = mode
    }}
    ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network")
        :WaitForChild("RemoteEvent"):WaitForChild("CreateParty"):FireServer(unpack(args))
    print("[🎉 Đã tạo Party]:", mode)
end

-- Main loop
task.spawn(function()
    local zoneList = {}
    for name, _ in pairs(getgenv().TargetPlayersPerZone) do
        table.insert(zoneList, name)
    end
    table.sort(zoneList)

    while getgenv().EnableTeleport do
        local teleported = false

        for _, zoneName in ipairs(zoneList) do
            local target = getgenv().TargetPlayersPerZone[zoneName]
            local current = getPlayerCountInZone(zoneName)

            print(string.format("🔍 [%s]: %d/%d", zoneName, current, target))

            if current < target then
                if currentZone ~= zoneName then
                    teleportTo(zoneName)
                end

                teleported = true

                -- Đợi ổn định rồi tạo party
                task.wait(1)

                if currentZone == zoneName and not partyCreated then
                    local partyModes = getgenv().EnableParty
                    if partyModes then
                        if partyModes["Normal"] then createParty("Normal") end
                        if partyModes["ScorchedEarth"] then createParty("Scorched Earth") end
                        if partyModes["Nightmare"] then createParty("Nightmare") end
                    end
                    partyCreated = true
                end
                break
            end
        end

        if not teleported then
            currentZone = nil
            print("⚠️ Không tìm được zone phù hợp, thử lại sau...")
        end

        task.wait(getgenv().TeleportInterval or 5)
    end
end)

-- ==========================
-- 🧩 UI BondCheck + Farm Bond
-- ==========================
if not game:IsLoaded() then
    game.Loaded:Wait()
end
repeat task.wait() until game.Players.LocalPlayer.Character and game.Players.LocalPlayer.PlayerGui:FindFirstChild("LoadingScreenPrefab") == nil
game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("EndDecision"):FireServer(false)
if game.CoreGui:FindFirstChild("BondCheck") == nil then
local gui = Instance.new("ScreenGui", game.CoreGui)
gui.Name = "BondCheck"

local Frame = Instance.new("Frame")
Frame.Name = "Bond"
Frame.Size = UDim2.new(0.13, 0, 0.1, 0)
Frame.Position = UDim2.new(0.03, 0, 0.05, 0)
Frame.BackgroundColor3 = Color3.new(1, 1, 1)
Frame.BorderColor3 = Color3.new(0, 0, 0)
Frame.BorderSizePixel = 1
Frame.Active = true
Frame.BackgroundTransparency = 0.3
Frame.Draggable = true
Frame.Parent = gui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(1, 0)
UICorner.Parent = Frame

local UICorner = Instance.new("UIStroke")
UICorner.Color = Color3.new(0, 0, 0)
UICorner.Thickness = 2.3
UICorner.Parent = Frame

local TextLabel = Instance.new("TextLabel")
TextLabel.Size = UDim2.new(1, 0, 1, 0)
TextLabel.Position = UDim2.new(0, 0, 0, 0)
TextLabel.BackgroundColor3 = Color3.new(255, 255, 255)
TextLabel.BorderColor3 = Color3.new(0, 0, 0)
TextLabel.BorderSizePixel = 1
TextLabel.Text = "Really"
TextLabel.TextSize = 20
TextLabel.FontFace = Font.new("rbxassetid://12187372175", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
TextLabel.BackgroundTransparency = 1
TextLabel.TextColor3 = Color3.new(0, 0, 0)
TextLabel.Parent = Frame
end
_G.Bond = 0
workspace.RuntimeItems.ChildAdded:Connect(function(v)
	if v.Name:find("Bond") and v:FindFirstChild("Part") then
		v.Destroying:Connect(function()
			_G.Bond += 1
		end)
	end
end)
spawn(function()
repeat task.wait()
if game.CoreGui.BondCheck:FindFirstChild("Bond") and game.CoreGui.BondCheck.Bond:FindFirstChild("TextLabel") then
game.CoreGui.BondCheck.Bond:FindFirstChild("TextLabel").Text = "Bond (+".._G.Bond..")"
end
until game.CoreGui:FindFirstChild("BondCheck") == nil
end)
if game.Players.LocalPlayer.Character:FindFirstChild("Humanoid") then
game.Workspace.CurrentCamera.CameraSubject = game.Players.LocalPlayer.Character:FindFirstChild("Humanoid")
end
game.Players.LocalPlayer.CameraMode = "Classic"
game.Players.LocalPlayer.CameraMaxZoomDistance = math.huge
game.Players.LocalPlayer.CameraMinZoomDistance = 30
game.Players.LocalPlayer.Character.HumanoidRootPart.Anchored = true
wait(0.3)
repeat task.wait()
game.Players.LocalPlayer.Character.HumanoidRootPart.Anchored = true
wait(0.3)
game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(80, 3, -9000)
repeat task.wait() until workspace.RuntimeItems:FindFirstChild("MaximGun")
wait(0.2)
for i, v in pairs(workspace.RuntimeItems:GetChildren()) do
if v.Name == "MaximGun" and v:FindFirstChild("VehicleSeat") then
v.VehicleSeat.Disabled = false
v.VehicleSeat:SetAttribute("Disabled", false)
v.VehicleSeat:Sit(game.Players.LocalPlayer.Character:FindFirstChild("Humanoid"))
end
end
wait(0.5)
for i, v in pairs(workspace.RuntimeItems:GetChildren()) do
if v.Name == "MaximGun" and v:FindFirstChild("VehicleSeat") and (game.Players.LocalPlayer.Character.HumanoidRootPart.Position - v.VehicleSeat.Position).Magnitude < 400 then
game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = v.VehicleSeat.CFrame
end
end
wait(1)
game.Players.LocalPlayer.Character.HumanoidRootPart.Anchored = false
until game.Players.LocalPlayer.Character:FindFirstChild("Humanoid").Sit == true
wait(0.5)
game.Players.LocalPlayer.Character:FindFirstChild("Humanoid").Sit = false
wait(0.5)
repeat task.wait()
for i, v in pairs(workspace.RuntimeItems:GetChildren()) do
if v.Name == "MaximGun" and v:FindFirstChild("VehicleSeat") and (game.Players.LocalPlayer.Character.HumanoidRootPart.Position - v.VehicleSeat.Position).Magnitude < 400 then
game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = v.VehicleSeat.CFrame
end
end
until game.Players.LocalPlayer.Character:FindFirstChild("Humanoid").Sit == true
wait(0.9)
for i, v in pairs(workspace:GetChildren()) do
if v:IsA("Model") and v:FindFirstChild("RequiredComponents") then
if v.RequiredComponents:FindFirstChild("Controls") and v.RequiredComponents.Controls:FindFirstChild("ConductorSeat") and v.RequiredComponents.Controls.ConductorSeat:FindFirstChild("VehicleSeat") then
TpTrain = game:GetService("TweenService"):Create(game.Players.LocalPlayer.Character.HumanoidRootPart, TweenInfo.new(25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CFrame = v.RequiredComponents.Controls.ConductorSeat:FindFirstChild("VehicleSeat").CFrame * CFrame.new(0, 20, 0)})
TpTrain:Play()
if game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid") and game.Players.LocalPlayer.Character.Humanoid.RootPart and game.Players.LocalPlayer.Character.HumanoidRootPart:FindFirstChild("VelocityHandler") == nil then
local bv = Instance.new("BodyVelocity")
bv.Name = "VelocityHandler"
bv.Parent = game.Players.LocalPlayer.Character.HumanoidRootPart
bv.MaxForce = Vector3.new(100000, 100000, 100000)
bv.Velocity = Vector3.new(0, 0, 0)
end
TpTrain.Completed:Wait()
end
end
end
wait(1)
while true do
if game.Players.LocalPlayer.Character:FindFirstChild("Humanoid").Sit == true then
TpEnd = game:GetService("TweenService"):Create(game.Players.LocalPlayer.Character.HumanoidRootPart, TweenInfo.new(17, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CFrame = CFrame.new(0.5, -78, -49429)})
TpEnd:Play()
if game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid") and game.Players.LocalPlayer.Character.Humanoid.RootPart and game.Players.LocalPlayer.Character.HumanoidRootPart:FindFirstChild("VelocityHandler") == nil then
local bv = Instance.new("BodyVelocity")
bv.Name = "VelocityHandler"
bv.Parent = game.Players.LocalPlayer.Character.HumanoidRootPart
bv.MaxForce = Vector3.new(100000, 100000, 100000)
bv.Velocity = Vector3.new(0, 0, 0)
end
repeat task.wait() until workspace.RuntimeItems:FindFirstChild("Bond")
TpEnd:Cancel()
for i, v in pairs(workspace.RuntimeItems:GetChildren()) do
if v.Name:find("Bond") and v:FindFirstChild("Part") then
repeat task.wait()
if v:FindFirstChild("Part") then
game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = v:FindFirstChild("Part").CFrame
game:GetService("ReplicatedStorage").Shared.Network.RemotePromise.Remotes.C_ActivateObject:FireServer(v)
end
until v:FindFirstChild("Part") == nil
end
end
end
task.wait()
end
