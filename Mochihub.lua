
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

    local allObjects = workspace:GetDescendants()

    -- 🧹 Xoá object theo tên
    if cfg["Object Removal"] and cfg["Object Removal"]["Enabled"] then
        for _, obj in ipairs(allObjects) do
            for _, name in ipairs(cfg["Object Removal"]["Targets"]) do
                if string.find(obj.Name:lower(), name:lower()) then
                    pcall(function() obj:Destroy() end)
                    break
                end
            end
        end
    end

    -- 💨 Xoá hiệu ứng
    if cfg["Remove Effects"] then
        for _, v in ipairs(allObjects) do
            if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                pcall(function() v:Destroy() end)
            end
        end
    end

    -- 🔇 Xoá âm thanh
    if cfg["Remove Sounds"] then
        for _, sound in ipairs(allObjects) do
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

task.spawn(function()
    while true do
        pcall(optimizeGame)
        task.wait(10)
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
    return character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart")
end

local function getHitbox()
    local zoneName = getgenv().TeleportZoneName or "PartyZone2"
    return workspace:WaitForChild("PartyZones", 10):WaitForChild(zoneName, 10):WaitForChild("Hitbox", 10)
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
-- 🔁 Auto Bond & MaximGun
-- ==========================
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

task.spawn(function()
    while task.wait(0.5) do
        if player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("BondUI") then
            local label = player.PlayerGui.BondUI:FindFirstChildWhichIsA("TextLabel", true)
            if label then
                label.Text = "Bond (+" .. tostring(_G.Bond) .. ")"
            end
        end
    end
end)

player.CameraMode = "Classic"
player.CameraMaxZoomDistance = math.huge
player.CameraMinZoomDistance = 30

-- Anchor & Teleport to gun
local hrp = getCharacter()
hrp.Anchored = true
wait(0.2)
repeat task.wait() until workspace.RuntimeItems:FindFirstChild("MaximGun")
hrp.CFrame = CFrame.new(80, 3, -9000)

task.wait(0.1)
for _, v in pairs(workspace.RuntimeItems:GetChildren()) do
    if v.Name == "MaximGun" and v:FindFirstChild("VehicleSeat") then
        v.VehicleSeat.Disabled = false
        v.VehicleSeat:SetAttribute("Disabled", false)
        v.VehicleSeat:Sit(player.Character:FindFirstChild("Humanoid"))
    end
end

wait(1)
hrp.Anchored = false
repeat wait() until player.Character.Humanoid.Sit == true
wait(0.5)
player.Character.Humanoid.Sit = false

-- ==========================
-- ✅ Done
-- ==========================
