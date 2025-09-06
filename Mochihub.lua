-- mm2 coin farm 🤑🤑🤑 (chỉ farm khi đang ở TRONG map mới)
-- Yêu cầu: Ở lobby -> KHÔNG teleport vào map người khác đang chơi.
-- Chỉ khi hệ thống đưa vào map (bạn đứng thật sự trong map) mới bắt đầu farm.

-- // === Services / Refs ===
local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local LP           = Players.LocalPlayer

-- Bảo đảm Character/HRP luôn hợp lệ (respawn an toàn)
local function getChar()
    local char = LP.Character or LP.CharacterAdded:Wait()
    local hrp  = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid")
    return char, hrp, hum
end
local Char, HRP, Humanoid = getChar()
LP.CharacterAdded:Connect(function()
    Char, HRP, Humanoid = getChar()
end)

-- // === Map / Round detect ===
local function findActiveMap()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:GetAttribute("MapID") and obj:FindFirstChild("CoinContainer") then
            return obj
        end
    end
    return nil
end

-- Bool: có round đang diễn ra không?
local function isRoundLive()
    -- 1) Ưu tiên GameData.InRound nếu có
    local ok, inRound = pcall(function()
        local gd = RS:FindFirstChild("GameData")
        local iv = gd and gd:FindFirstChild("InRound")
        return iv and iv.Value
    end)
    if ok and inRound ~= nil then return inRound end

    -- 2) Fallback: có Map + có Coin
    local m = findActiveMap()
    if not m then return false end
    local cc = m:FindFirstChild("CoinContainer")
    if not cc then return false end
    if #cc:GetChildren() > 0 then return true end
    local t0 = os.clock()
    while os.clock() - t0 < 2 do
        if #cc:GetChildren() > 0 then return true end
        task.wait(0.1)
    end
    return false
end

-- Kiểm tra: nhân vật đang đứng BÊN TRONG map chưa?
local function isPlayerInsideMap(mapModel)
    if not (mapModel and HRP) then return false end
    -- Dùng bounding box của map để kiểm tra vị trí
    local cf, size = mapModel:GetBoundingBox()
    -- Nới biên một chút để tránh lệch
    local pad = Vector3.new(6, 6, 6)
    size = size + pad
    local localPos = cf:PointToObjectSpace(HRP.Position)
    local half = size / 2
    return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

-- Chờ đến khi round thật sự bắt đầu VÀ người chơi đang Ở TRONG map
local function waitForRoundStartInside()
    while true do
        local m = findActiveMap()
        if m and isRoundLive() and isPlayerInsideMap(m) then
            return m
        end
        -- Nếu đang ở lobby (không ở trong map), tuyệt đối KHÔNG tp vào map
        task.wait(0.25)
    end
end

-- // === Coin logic ===
local function getNearest(mapModel)
    local cc = mapModel and mapModel:FindFirstChild("CoinContainer")
    if not cc then return nil end
    local closest, dist = nil, math.huge
    for _, coin in ipairs(cc:GetChildren()) do
        if coin and coin:IsA("BasePart") then
            local v = coin:FindFirstChild("CoinVisual")
            if v and not v:GetAttribute("Collected") then
                local d = (HRP.Position - coin.Position).Magnitude
                if d < dist then
                    closest = coin
                    dist = d
                end
            end
        end
    end
    return closest
end

local function safeTP(targetPart)
    if not (HRP and targetPart and targetPart.CFrame and Humanoid) then return end
    -- Chế độ Physics giúp tween mượt, giảm anti-cheat
    Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    local d = (HRP.Position - targetPart.Position).Magnitude
    local dur = math.clamp(d / 28, 0.10, 2.2) -- tốc độ vừa phải, tránh quá nhanh bị kick
    local tw = TweenService:Create(HRP, TweenInfo.new(dur, Enum.EasingStyle.Linear), {CFrame = targetPart.CFrame})
    tw:Play()
    tw.Completed:Wait()
end

-- // === Main loop ===
while true do
    -- Chỉ bắt đầu khi: có round + BẠN ĐANG Ở TRONG MAP
    local currentMap = waitForRoundStartInside()

    -- Farm cho tới khi round kết thúc hoặc bị đẩy khỏi map
    while isRoundLive() and currentMap and currentMap.Parent do
        -- nếu chết/respawn thì cập nhật ref
        if not (Char and Char.Parent and HRP and HRP.Parent and Humanoid and Humanoid.Parent) then
            Char, HRP, Humanoid = getChar()
        end

        -- Nếu bất chợt bị đưa ra lobby giữa chừng -> dừng farm ngay
        if not isPlayerInsideMap(currentMap) then
            break
        end

        local target = getNearest(currentMap)
        if target then
            -- Chỉ dịch chuyển khi vẫn còn ở trong map (thêm lớp an toàn trước mỗi tp)
            if isPlayerInsideMap(currentMap) then
                safeTP(target)
            else
                break
            end

            -- giữ sát coin đó đến khi collected hoặc coin biến mất/round đổi
            local v = target:FindFirstChild("CoinVisual")
            local t0 = os.clock()
            while isRoundLive() and isPlayerInsideMap(currentMap) and v and v.Parent and not v:GetAttribute("Collected") do
                -- nếu có coin gần hơn thì thoát để chuyển mục tiêu
                local n = getNearest(currentMap)
                if n and n ~= target then break end
                -- tránh kẹt quá lâu 1 coin
                if os.clock() - t0 > 2.5 then break end
                task.wait(0.05)
            end
        else
            -- không thấy coin -> chờ chút rồi check lại
            task.wait(0.15)
        end
    end

    -- Round xong hoặc bị đưa ra lobby → quay lại chờ map mới
    task.wait(0.5)
end


