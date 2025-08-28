-- Khởi tạo biến toàn cục
getgenv().AutoTeleport = true -- bật/tắt teleport
getgenv().TeleporterIndex = 3 -- Chọn teleporter thứ mấy
getgenv().TeleporterMaxCapacity = 5 -- Số người tối đa mỗi teleporter

-- Lấy dịch vụ
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Remote = game:GetService("ReplicatedStorage").RemoteEvents.RequestTakeDiamonds

local Interface = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Interface")
local DiamondCount = Interface:WaitForChild("DiamondCount"):WaitForChild("Count")

-- Hàm lấy HumanoidRootPart hiện tại
local function getHRP()
    local char = LocalPlayer.Character
    if char then
        return char:FindFirstChild("HumanoidRootPart")
    end
end

-- Hàm kiểm tra số người trên teleporter
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

-- Hàm lấy teleporter đúng index (lấy BasePart nếu là Model)
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

-- Hàm rainbow stroke cho UI
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

-- Hàm hop server
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

-- Tạo UI
local gui = Instance.new("ScreenGui", game.CoreGui)
gui.Name = "DiamondFarmUI"

local mainFrame = Instance.new("Frame", gui)
mainFrame.Size = UDim2.new(0, 200, 0, 90)
mainFrame.Position = UDim2.new(0, 80, 0, 100)
mainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true

local corner = Instance.new("UICorner", mainFrame)
corner.CornerRadius = UDim.new(0, 8)

local stroke = Instance.new("UIStroke", mainFrame)
stroke.Thickness = 1.5
rainbowStroke(stroke)

local title = Instance.new("TextLabel", mainFrame)
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "Farm Diamond | CÃ¡o Mod"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextStrokeTransparency = 0.6

local diamondText = Instance.new("TextLabel", mainFrame)
diamondText.Size = UDim2.new(1, -20, 0, 35)
diamondText.Position = UDim2.new(0, 10, 0, 40)
diamondText.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
diamondText.TextColor3 = Color3.new(1, 1, 1)
diamondText.Font = Enum.Font.GothamBold
diamondText.TextSize = 14
diamondText.BorderSizePixel = 0

local diamondCorner = Instance.new("UICorner", diamondText)
diamondCorner.CornerRadius = UDim.new(0, 6)

task.spawn(function()
    while task.wait(0.2) do
        diamondText.Text = "Diamonds: " .. DiamondCount.Text
    end
end)

-- Loop AutoTeleport + farm diamond
RunService.Heartbeat:Connect(function()
    if getgenv().AutoTeleport then
        local hrp = getHRP()
        if hrp then
            local teleporter = getTeleporter()
            if teleporter then
                if getTeleporterCount(teleporter) >= getgenv().TeleporterMaxCapacity then
                    -- Nếu full người, teleport sang Teleporter2.EnterPart
                    local tele2 = workspace:FindFirstChild("Teleporter2")
                    if tele2 and tele2:FindFirstChild("EnterPart") then
                        hrp.CFrame = tele2.EnterPart.CFrame
                    else
                        warn("Không tìm thấy Teleporter2.EnterPart!")
                    end
                else
                    -- Nếu chưa full, teleport bình thường
                    hrp.CFrame = teleporter.CFrame
                end
            else
                warn("Teleporter thứ " .. getgenv().TeleporterIndex .. " không tồn tại!")
            end
        end
    end
end)

-- Auto farm diamond
task.spawn(function()
    repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    local chest = workspace.Items:FindFirstChild("Stronghold Diamond Chest")
    if not chest then
        CoreGui:SetCore("SendNotification", {
            Title = "Notification",
            Text = "Chest not found",
            Duration = 3
        })
        hopServer()
        return
    end

    LocalPlayer.Character:PivotTo(CFrame.new(chest:GetPivot().Position))

    local proxPrompt
    repeat
        task.wait(0.1)
        local prox = chest:FindFirstChild("Main")
        if prox and prox:FindFirstChild("ProximityAttachment") then
            proxPrompt = prox.ProximityAttachment:FindFirstChild("ProximityInteraction")
        end
    until proxPrompt

    local startTime = tick()
    while proxPrompt and proxPrompt.Parent and (tick() - startTime) < 10 do
        pcall(function()
            fireproximityprompt(proxPrompt)
        end)
        task.wait(0.2)
    end

    if proxPrompt and proxPrompt.Parent then
        CoreGui:SetCore("SendNotification", {
            Title = "Notification",
            Text = "Stronghold is starting (auto coming soon)",
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
        Text = "Take all the diamonds",
        Duration = 3
    })

    task.wait(1)
    hopServer()
end)
