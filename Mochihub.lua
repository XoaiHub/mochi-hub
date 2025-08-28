-- Khởi tạo biến toàn cục
getgenv().AutoTeleport = true
getgenv().TeleporterIndex = 3
getgenv().TeleporterMaxCapacity = 5

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Remote = game:GetService("ReplicatedStorage").RemoteEvents.RequestTakeDiamonds

-- Wait Interface & DiamondCount
local Interface = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Interface")
local DiamondCount = Interface:WaitForChild("DiamondCount"):WaitForChild("Count")

-- Hàm lấy HRP
local function getHRP()
    local char = LocalPlayer.Character
    if char then
        return char:FindFirstChild("HumanoidRootPart")
    end
end

-- Hàm đếm người trên teleporter
local function getTeleporterCount(teleporterPart)
    local count = 0
    for _, player in pairs(Players:GetPlayers()) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and (hrp.Position - teleporterPart.Position).Magnitude < 5 then
            count = count + 1
        end
    end
    return count
end

-- Hàm lấy teleporter đúng index
local function getTeleporter()
    local teleporter3 = workspace:FindFirstChild("Teleporter3")
    if teleporter3 then
        local children = teleporter3:GetChildren()
        local t = children[getgenv().TeleporterIndex]
        if t then
            if t:IsA("Model") then
                return t:FindFirstChildWhichIsA("BasePart")
            elseif t:IsA("BasePart") then
                return t
            end
        end
    end
end

-- Rainbow Stroke UI
local function rainbowStroke(stroke)
    task.spawn(function()
        while task.wait() do
            for hue = 0,1,0.01 do
                stroke.Color = Color3.fromHSV(hue,1,1)
                task.wait(0.02)
            end
        end
    end)
end

-- Server Hop
local function hopServer()
    local gameId = game.PlaceId
    local success, body = pcall(function()
        return game:HttpGet(("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(gameId))
    end)
    if success then
        local data = HttpService:JSONDecode(body)
        for _, server in ipairs(data.data) do
            if server.playing < server.maxPlayers and server.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(gameId, server.id, LocalPlayer)
            end
        end
    end
end

-- Tạo UI
local gui = Instance.new("ScreenGui", CoreGui)
gui.Name = "DiamondFarmUI"

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0,200,0,90)
frame.Position = UDim2.new(0,80,0,100)
frame.BackgroundColor3 = Color3.fromRGB(35,35,35)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true

local corner = Instance.new("UICorner", frame)
corner.CornerRadius = UDim.new(0,8)

local stroke = Instance.new("UIStroke", frame)
stroke.Thickness = 1.5
rainbowStroke(stroke)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1,0,0,30)
title.BackgroundTransparency = 1
title.Text = "Farm Diamond | CÃ¡o Mod"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextStrokeTransparency = 0.6

local diamondText = Instance.new("TextLabel", frame)
diamondText.Size = UDim2.new(1,-20,0,35)
diamondText.Position = UDim2.new(0,10,0,40)
diamondText.BackgroundColor3 = Color3.fromRGB(0,0,0)
diamondText.TextColor3 = Color3.new(1,1,1)
diamondText.Font = Enum.Font.GothamBold
diamondText.TextSize = 14
diamondText.BorderSizePixel = 0
local diamondCorner = Instance.new("UICorner", diamondText)
diamondCorner.CornerRadius = UDim.new(0,6)

task.spawn(function()
    while task.wait(0.2) do
        pcall(function()
            diamondText.Text = "Diamonds: " .. DiamondCount.Text
        end)
    end
end)

-- AutoTeleport Loop
task.spawn(function()
    repeat task.wait() until LocalPlayer.Character and getHRP()
    while true do
        task.wait(0.1)
        if getgenv().AutoTeleport then
            local hrp = getHRP()
            if hrp then
                local teleporter = getTeleporter()
                if teleporter then
                    if getTeleporterCount(teleporter) >= getgenv().TeleporterMaxCapacity then
                        local tele2 = workspace:FindFirstChild("Teleporter2")
                        if tele2 and tele2:FindFirstChild("EnterPart") then
                            hrp.CFrame = tele2.EnterPart.CFrame
                        end
                    else
                        hrp.CFrame = teleporter.CFrame
                    end
                end
            end
        end
    end
end)

-- Auto Farm Diamond Loop
task.spawn(function()
    repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    while true do
        task.wait(0.5)
        local chest = workspace.Items:FindFirstChild("Stronghold Diamond Chest")
        if not chest then
            hopServer()
            break
        end
        local hrp = getHRP()
        if hrp then
            hrp.CFrame = CFrame.new(chest:GetPivot().Position)
        end

        local proxPrompt
        local main = chest:FindFirstChild("Main")
        if main and main:FindFirstChild("ProximityAttachment") then
            proxPrompt = main.ProximityAttachment:FindFirstChild("ProximityInteraction")
        end

        if proxPrompt then
            local startTime = tick()
            while proxPrompt.Parent and (tick()-startTime)<10 do
                pcall(function() fireproximityprompt(proxPrompt) end)
                task.wait(0.2)
            end
        end

        for _, v in pairs(workspace:GetDescendants()) do
            if v.ClassName=="Model" and v.Name=="Diamond" then
                pcall(function() Remote:FireServer(v) end)
            end
        end
    end
end)


