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

local gui = Instance.new("ScreenGui", game.CoreGui)
gui.Name = "gg"

-- Frame chính (căn giữa màn hình)
local b = Instance.new("Frame", gui)
b.Size = UDim2.new(0, 260, 0, 130)
b.Position = UDim2.new(0.5, 0, 0.5, 0) -- Giữa màn hình
b.AnchorPoint = Vector2.new(0.5, 0.5) -- Căn tâm
b.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
b.BorderSizePixel = 0
b.Active = true
b.Draggable = true

local c = Instance.new("UICorner", b)
c.CornerRadius = UDim.new(0, 10)

local d = Instance.new("UIStroke", b)
d.Thickness = 1.5
rainbowStroke(d) -- Hàm đổi màu viền (có sẵn ở bạn)

-- Tiêu đề
local title = Instance.new("TextLabel", b)
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "Kaitun 99 Night"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextStrokeTransparency = 0.6

-- Diamonds counter
local diamondLabel = Instance.new("TextLabel", b)
diamondLabel.Size = UDim2.new(1, -20, 0, 35)
diamondLabel.Position = UDim2.new(0, 10, 0, 40)
diamondLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
diamondLabel.TextColor3 = Color3.new(1, 1, 1)
diamondLabel.Font = Enum.Font.GothamBold
diamondLabel.TextSize = 14
diamondLabel.BorderSizePixel = 0

local g = Instance.new("UICorner", diamondLabel)
g.CornerRadius = UDim.new(0, 6)

-- Discord Info (có thêm icon)
local discordFrame = Instance.new("Frame", b)
discordFrame.Size = UDim2.new(1, -10, 0, 25)
discordFrame.Position = UDim2.new(0, 5, 1, -30)
discordFrame.BackgroundTransparency = 1

local discordIcon = Instance.new("ImageLabel", discordFrame)
discordIcon.Size = UDim2.new(0, 18, 0, 18)
discordIcon.Position = UDim2.new(0, 0, 0.5, -9)
discordIcon.BackgroundTransparency = 1
discordIcon.Image = "rbxassetid://6034982499" -- icon Discord

local discordLabel = Instance.new("TextLabel", discordFrame)
discordLabel.Size = UDim2.new(1, -25, 1, 0)
discordLabel.Position = UDim2.new(0, 25, 0, 0)
discordLabel.BackgroundTransparency = 1
discordLabel.Text = "Join Discord: discord.gg/mochihub"
discordLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
discordLabel.Font = Enum.Font.Gotham
discordLabel.TextSize = 12
discordLabel.TextStrokeTransparency = 0.8
discordLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Update diamonds
task.spawn(function()
    while task.wait(0.2) do
        diamondLabel.Text = "Diamonds: " .. (DiamondCount and DiamondCount.Text or "0")
    end
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


