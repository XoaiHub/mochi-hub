-- Khởi tạo biến toàn cục
getgenv().AutoTeleport = true -- bật/tắt teleport
getgenv().TeleporterIndex = 3 -- Chọn teleporter thứ mấy
getgenv().TeleporterMaxCapacity = 5 -- Số người tối đa mỗi teleporter

-- Lấy dịch vụ
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")

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

-- Loop kiểm tra AutoTeleport
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
