-- Cấu hình toàn cục
getgenv().AutoTeleportEnabled = true  -- bật/tắt teleport
getgenv().TeleportInterval = 15       -- thời gian lặp lại (giây)
getgenv().HasJoinedMap = false        -- trạng thái đã vào map

-- Lấy dịch vụ Players
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Hàm lấy character và đảm bảo PrimaryPart
local function getCharacter()
    local char = LocalPlayer.Character
    if not char then
        char = LocalPlayer.CharacterAdded:Wait()
    end
    if not char.PrimaryPart then
        char:WaitForChild("HumanoidRootPart")
        char.PrimaryPart = char:FindFirstChild("HumanoidRootPart")
    end
    return char
end

-- Hàm kiểm tra xem đã vào map chưa
local function isInMap()
    -- Giả sử vào map nghĩa là Teleporter2 không còn hoặc có flag nào đó
    return workspace:FindFirstChild("Teleporter2") == nil
end

-- Hàm teleport
local function teleportToEnterPart()
    if not getgenv().AutoTeleportEnabled or getgenv().HasJoinedMap then return end

    local char = getCharacter()
    
    -- Chờ EnterPart tồn tại
    local enterPart
    repeat
        enterPart = workspace:FindFirstChild("Teleporter2") and workspace.Teleporter2:FindFirstChild("EnterPart")
        if not enterPart then
            task.wait(0.5)
        end
    until enterPart or getgenv().HasJoinedMap

    if char.PrimaryPart and enterPart then
        char:SetPrimaryPartCFrame(enterPart.CFrame)
        print("Đã teleport đến EnterPart")
    else
        warn("Nhân vật chưa sẵn sàng hoặc đã vào map")
    end

    -- Kiểm tra xem đã vào map chưa
    if isInMap() then
        getgenv().HasJoinedMap = true
        print("Đã vào map, dừng teleport")
    end
end

-- Kích hoạt teleport khi join map
spawn(function()
    while getgenv().AutoTeleportEnabled and not getgenv().HasJoinedMap do
        teleportToEnterPart()
        task.wait(getgenv().TeleportInterval)
    end
end)

-- Trigger teleport ngay khi Character respawn
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    teleportToEnterPart()
end)



local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Remote = game:GetService("ReplicatedStorage").RemoteEvents.RequestTakeDiamonds
local Interface = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Interface")
local DiamondCount = Interface:WaitForChild("DiamondCount"):WaitForChild("Count")

local a, b, c, d, e, f, g
local chest, proxPrompt
local startTime

local function rainbowStroke(stroke)
    task.spawn(function()
        while task.wait() do
            for hue = 0, 1, 0.01 do
                stroke.Color = Color3.fromHSV(hue, 1, 1)
                task.wait(0.02)
            end
        end
    end)
end

local function hopServer()
    local gameId = game.PlaceId
    while true do
        local success, body = pcall(function()
            return game:HttpGet(("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(gameId))
        end)
        if success then
            local data = HttpService:JSONDecode(body)
            for _, server in ipairs(data.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    while true do
                        pcall(function()
                            TeleportService:TeleportToPlaceInstance(gameId, server.id, LocalPlayer)
                        end)
                        task.wait(0.1)
                    end
                end
            end
        end
        task.wait(0.2)
    end
end

task.spawn(function()
    while task.wait(1) do
        for _, char in pairs(workspace.Characters:GetChildren()) do
            if char:FindFirstChild("Humanoid") and char:FindFirstChild("HumanoidRootPart") then
                if char:FindFirstChild("Humanoid").DisplayName == LocalPlayer.DisplayName then
                    hopServer()
                end
            end
        end
    end
end)

-- Xóa UI cũ nếu đã tồn tại
if game.CoreGui:FindFirstChild("MochiUi") then
    game.CoreGui.MochiUi:Destroy()
end

local player = game.Players.LocalPlayer

-- Tạo ScreenGui
local gui = Instance.new("ScreenGui", game.CoreGui)
gui.Name = "MochiUi"
gui.ResetOnSpawn = false

-- Frame chính giữa
local mainFrame = Instance.new("Frame", gui)
mainFrame.Size = UDim2.new(0, 400, 0, 300)
mainFrame.Position = UDim2.new(0.5, 0, 0.35, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundTransparency = 1
mainFrame.ZIndex = 2

-- Tiêu đề Mochi Hub
local title = Instance.new("TextLabel", mainFrame)
title.Size = UDim2.new(1, -20, 0, 50)
title.Position = UDim2.new(0.5, 0, 0, 10)
title.AnchorPoint = Vector2.new(0.5, 0)
title.BackgroundTransparency = 1
title.Text = "Mochi Hub"
title.Font = Enum.Font.GothamBlack
title.TextSize = 36
title.TextColor3 = Color3.new(1, 1, 1)
title.TextStrokeTransparency = 0.6
title.TextXAlignment = Enum.TextXAlignment.Center
title.ZIndex = 2

-- Tác giả
local author = Instance.new("TextLabel", mainFrame)
author.Size = UDim2.new(1, -20, 0, 30)
author.Position = UDim2.new(0.5, 0, 0, 70)
author.AnchorPoint = Vector2.new(0.5, 0)
author.BackgroundTransparency = 1
author.Text = "Kaitun 99 Night"
author.Font = Enum.Font.Gotham
author.TextSize = 20
author.TextColor3 = Color3.new(1, 1, 1)
author.TextXAlignment = Enum.TextXAlignment.Center
author.ZIndex = 2

-- Diamonds
local diamondText = Instance.new("TextLabel", mainFrame)
diamondText.Size = UDim2.new(0.6, 0, 0, 30)
diamondText.Position = UDim2.new(0.5, 0, 0, 110)
diamondText.AnchorPoint = Vector2.new(0.5, 0)
diamondText.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
diamondText.BackgroundTransparency = 0.4
diamondText.TextColor3 = Color3.new(1, 1, 1)
diamondText.Font = Enum.Font.GothamBold
diamondText.TextSize = 18
diamondText.BorderSizePixel = 0
diamondText.ZIndex = 2

local diamondCorner = Instance.new("UICorner")
diamondCorner.CornerRadius = UDim.new(0, 6)
diamondCorner.Parent = diamondText

-- Link Discord
local discord = Instance.new("TextLabel", mainFrame)
discord.Size = UDim2.new(1, -20, 0, 30)
discord.Position = UDim2.new(0.5, 0, 0, 150)
discord.AnchorPoint = Vector2.new(0.5, 0)
discord.BackgroundTransparency = 1
discord.Text = "gg/comming soon"
discord.Font = Enum.Font.Gotham
discord.TextSize = 18
discord.TextColor3 = Color3.fromRGB(150, 150, 255)
discord.TextXAlignment = Enum.TextXAlignment.Center
discord.ZIndex = 2

-- Lấy leaderstats Diamonds và update tự động
local leaderstats = player:WaitForChild("leaderstats", 10)
local diamonds = leaderstats and leaderstats:FindFirstChild("Diamonds")

-- Nếu không có, tạo tạm
if not diamonds then
    diamonds = Instance.new("IntValue")
    diamonds.Name = "Diamonds"
    diamonds.Value = 0
    diamonds.Parent = player
end

-- Cập nhật UI khi diamonds thay đổi
diamondText.Text = "Diamonds: " .. tostring(diamonds.Value)
diamonds.Changed:Connect(function(newValue)
    diamondText.Text = "Diamonds: " .. tostring(newValue)
end)


repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

chest = workspace.Items:FindFirstChild("Stronghold Diamond Chest")
if not chest then
    CoreGui:SetCore("SendNotification", {
        Title = "Notification",
        Text = "chest not found (my fault)",
        Duration = 3
    })
    hopServer()
    return
end

LocalPlayer.Character:PivotTo(CFrame.new(chest:GetPivot().Position))

repeat
    task.wait(0.1)
    local prox = chest:FindFirstChild("Main")
    if prox and prox:FindFirstChild("ProximityAttachment") then
        proxPrompt = prox.ProximityAttachment:FindFirstChild("ProximityInteraction")
    end
until proxPrompt

startTime = tick()
while proxPrompt and proxPrompt.Parent and (tick() - startTime) < 10 do
    pcall(function()
        fireproximityprompt(proxPrompt)
    end)
    task.wait(0.2)
end

if proxPrompt and proxPrompt.Parent then
    CoreGui:SetCore("SendNotification", {
        Title = "Notification",
        Text = "stronghold is starting (auto coming soon) ",
        Duration = 3
    })
    hopServer()
    return
end

repeat task.wait(0.1) until workspace:FindFirstChild("Diamond", true)

for _, v in pairs(workspace:GetDescendants()) do
    if v.ClassName == "Model" and v.Name == "Diamond" then
        Remote:FireServer(v)
    end
end

CoreGui:SetCore("SendNotification", {
    Title = "Notification",
    Text = "take all the diamonds",
    Duration = 3
})
task.wait(1)
hopServer()
