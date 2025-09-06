-- mm2 coin farm 🤑🤑🤑  (auto-run ONLY when in-map)
-- Giữ nguyên chức năng, thêm logic: ở lobby thì đứng yên; chỉ farm khi bản thân đã vào map.

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

-- // === Round / Map detect ===
local function findActiveMap()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:GetAttribute("MapID") and obj:FindFirstChild("CoinContainer") then
            return obj
        end
    end
    return nil
end

-- Ưu tiên GameData.InRound nếu có; fallback theo map/coin
local function isRoundLive()
    local ok, inRound = pcall(function()
        local gd = RS:FindFirstChild("GameData")
        local iv = gd and gd:FindFirstChild("InRound")
        return iv and iv.Value
    end)
    if ok and inRound ~= nil then return inRound end

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

-- [MỚI] Kiểm tra nhân vật có thực sự "ở trong" map không
local function isPlayerInMap(mapModel)
    if not (mapModel and Char and HRP) then return false end

    -- 1) Nếu Character là con của map (nhiều game attach player vào model map)
    if Char:IsDescendantOf(mapModel) then return true end

    -- 2) Dựa trên bounding box của model map
    local ok, cf, size = pcall(function()
        return mapModel:GetModelCFrame(), mapModel:GetExtentsSize()
    end)
    if ok and cf and size then
        local half = size * 0.5
        local rel  = cf:PointToObjectSpace(HRP.Position)
        return math.abs(rel.X) <= half.X + 6 and math.abs(rel.Y) <= half.Y + 6 and math.abs(rel.Z) <= half.Z + 6
    end

    -- 3) Fallback: nếu map có PrimaryPart, cho phép khoảng cách trung tâm
    if mapModel.PrimaryPart then
        local d = (HRP.Position - mapModel.PrimaryPart.Position).Magnitude
        return d <= 150
    end

    return false
end

-- Chờ tới khi: có round + bạn đã được đặt vào map
local function waitUntilYouAreInMap()
    while true do
        local m = findActiveMap()
        if m and isRoundLive() and isPlayerInMap(m) then
            return m
        end
        -- Trường hợp có round nhưng bạn vẫn ở lobby -> đứng yên, đợi hệ thống teleport
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

-- Tween cẩn thận để tránh kick vì di chuyển quá nhanh
local function tp(targetPart)
    if not (HRP and targetPart and targetPart.CFrame) then return end
    if Humanoid then Humanoid:ChangeState(Enum.HumanoidStateType.Physics) end
    local d  = (HRP.Position - targetPart.Position).Magnitude
    local t  = math.clamp(d / 25, 0.10, 2.0) -- hơi chậm lại 1 chút
    local tw = TweenService:Create(HRP, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = targetPart.CFrame})
    tw:Play()
    tw.Completed:Wait()
end

-- // === Main loop ===
while true do
    -- 1) Ở lobby: chờ đến khi bản thân THẬT SỰ vào map
    local currentMap = waitUntilYouAreInMap()

    -- 2) Chỉ farm khi round còn diễn ra VÀ bạn còn ở trong map đó
    while isRoundLive() and currentMap and currentMap.Parent and isPlayerInMap(currentMap) do
        if not (Char and Char.Parent and HRP and HRP.Parent and Humanoid and Humanoid.Parent) then
            Char, HRP, Humanoid = getChar()
        end

        local target = getNearest(currentMap)
        if target then
            tp(target)
            -- giữ sát coin trong thời gian hợp lý; tránh kẹt
            local v = target:FindFirstChild("CoinVisual")
            local t0 = os.clock()
            while isRoundLive() and isPlayerInMap(currentMap) and v and v.Parent and not v:GetAttribute("Collected") do
                local n = getNearest(currentMap)
                if n and n ~= target then break end
                if os.clock() - t0 > 2.5 then break end
                task.wait(0.05)
            end
        else
            task.wait(0.15)
        end
    end

    -- 3) Round xong hoặc bạn bị kéo ra khỏi map -> quay lại chờ ở lobby
    task.wait(0.5)
end


