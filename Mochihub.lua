-- Xóa UI cũ nếu có
if game.CoreGui:FindFirstChild("NexonUI") then
    game.CoreGui.NexonUI:Destroy()
end
if game.CoreGui:FindFirstChild("MochiUi") then
    game.CoreGui.MochiUi:Destroy()
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Remote = game:GetService("ReplicatedStorage").RemoteEvents.RequestTakeDiamonds
local Interface = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Interface")
local DiamondCount = Interface:WaitForChild("DiamondCount"):WaitForChild("Count")

-- Rainbow stroke function
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

-- Hop server function
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
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(gameId, server.id, LocalPlayer)
                    end)
                    return
                end
            end
        end
        task.wait(1)
    end
end

-- UI chính giữa
local gui = Instance.new("ScreenGui", CoreGui)
gui.Name = "MochiUi"
gui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame", gui)
mainFrame.Size = UDim2.new(0, 400, 0, 300)
mainFrame.Position = UDim2.new(0.5, 0, 0.4, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true

local corner = Instance.new("UICorner", mainFrame)
corner.CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke", mainFrame)
stroke.Thickness = 2
rainbowStroke(stroke)

-- Tiêu đề
local title = Instance.new("TextLabel", mainFrame)
title.Size = UDim2.new(1, 0, 0, 40)
title.Position = UDim2.new(0, 0, 0, 10)
title.BackgroundTransparency = 1
title.Text = "Farm Diamond | Mochi Hub"
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextColor3 = Color3.new(1, 1, 1)
title.TextStrokeTransparency = 0.6
title.TextXAlignment = Enum.TextXAlignment.Center

-- Số Diamond
local diamondLabel = Instance.new("TextLabel", mainFrame)
diamondLabel.Size = UDim2.new(1, 0, 0, 30)
diamondLabel.Position = UDim2.new(0, 0, 0, 60)
diamondLabel.BackgroundTransparency = 1
diamondLabel.Text = "Diamonds: 0"
diamondLabel.Font = Enum.Font.GothamBold
diamondLabel.TextSize = 18
diamondLabel.TextColor3 = Color3.new(1, 1, 1)
diamondLabel.TextXAlignment = Enum.TextXAlignment.Center

-- Tác giả & link
local author = Instance.new("TextLabel", mainFrame)
author.Size = UDim2.new(1, 0, 0, 25)
author.Position = UDim2.new(0, 0, 0, 220)
author.BackgroundTransparency = 1
author.Text = "Mochi Kaitun"
author.Font = Enum.Font.Gotham
author.TextSize = 18
author.TextColor3 = Color3.new(1, 1, 1)
author.TextXAlignment = Enum.TextXAlignment.Center

local discord = Instance.new("TextLabel", mainFrame)
discord.Size = UDim2.new(1, 0, 0, 25)
discord.Position = UDim2.new(0, 0, 0, 250)
discord.BackgroundTransparency = 1
discord.Text = "gg/comming soon"
discord.Font = Enum.Font.Gotham
discord.TextSize = 16
discord.TextColor3 = Color3.fromRGB(150, 150, 255)
discord.TextXAlignment = Enum.TextXAlignment.Center

-- Update số diamond liên tục
task.spawn(function()
    while task.wait(0.2) do
        pcall(function()
            diamondLabel.Text = "Diamonds: " .. DiamondCount.Text
        end)
    end
end)

-- Chờ character load
repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

-- Tìm chest
local chest = workspace.Items:FindFirstChild("Stronghold Diamond Chest")
if not chest then
    CoreGui:SetCore("SendNotification", {
        Title = "Notification",
        Text = "Chest not found (hop server...)",
        Duration = 3
    })
    hopServer()
    return
end

-- Teleport tới chest
LocalPlayer.Character:PivotTo(CFrame.new(chest:GetPivot().Position))

-- Lấy ProximityPrompt
local proxPrompt
repeat
    task.wait(0.1)
    local prox = chest:FindFirstChild("Main")
    if prox and prox:FindFirstChild("ProximityAttachment") then
        proxPrompt = prox.ProximityAttachment:FindFirstChild("ProximityInteraction")
    end
until proxPrompt

-- Fire ProximityPrompt
local startTime = tick()
while proxPrompt and proxPrompt.Parent and (tick() - startTime) < 10 do
    pcall(function()
        fireproximityprompt(proxPrompt)
    end)
    task.wait(0.2)
end

-- Nếu vẫn tồn tại, thông báo và hop server
if proxPrompt and proxPrompt.Parent then
    CoreGui:SetCore("SendNotification", {
        Title = "Notification",
        Text = "Stronghold is starting, hop server...",
        Duration = 3
    })
    hopServer()
    return
end

-- Lấy tất cả diamond
repeat task.wait(0.1) until workspace:FindFirstChild("Diamond", true)
for _, v in pairs(workspace:GetDescendants()) do
    if v.ClassName == "Model" and v.Name == "Diamond" then
        pcall(function()
            Remote:FireServer(v)
        end)
    end
end

CoreGui:SetCore("SendNotification", {
    Title = "Notification",
    Text = "Collected all diamonds",
    Duration = 3
})

task.wait(1)
hopServer()


