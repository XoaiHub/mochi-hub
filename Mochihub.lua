-- MM2 Farm (Lobby-safe + Segmented Tween anti-267)
-- Flow: Lobby idle -> vào MAP thật sự -> farm tới 40 coin -> hop -> lặp

-- ============ CONFIG ============
local Config = {
    -- Lobby idle
    IdleInLobby        = true,
    IdleMethod         = "walkspeed",  -- "walkspeed" hoặc "anchor"
    IdleWalkSpeed      = 0,
    IdleJumpPower      = 0,
    RestoreWalkSpeed   = 16,
    RestoreJumpPower   = 50,

    -- Farm target
    TargetCoins        = 40,

    -- Tốc độ/độ an toàn tween (đi theo đoạn ngắn)
    TweenSpeedDiv      = 32,   -- lớn = nhanh hơn (gợi ý 30–36)
    TweenMinTime       = 0.12, -- đừng < 0.10
    TweenMaxTime       = 2.2,
    MaxSegmentDist     = 18,   -- chiều dài 1 đoạn tween
    SegmentPause       = 0.03, -- nghỉ rất ngắn giữa các đoạn
    MaxVerticalDelta   = 7,    -- hạn chế nhảy trục Y
    GroundOffset       = 2.5,  -- bám sàn

    CoinLockTime       = 2.0,  -- bám 1 coin tối đa
    DelayBetweenCoins  = 0.10,
    RoundPollDelay     = 0.25,
}

-- ============ SERVICES ============
local g               = game
local Players         = g:GetService("Players")
local RS              = g:GetService("ReplicatedStorage")
local TweenService    = g:GetService("TweenService")
local TeleportService = g:GetService("TeleportService")
local HttpService     = g:GetService("HttpService")
local RunService      = g:GetService("RunService")
local LP              = Players.LocalPlayer
local PlaceId         = g.PlaceId

-- ============ CHARACTER ============
local function getChar()
    local char = LP.Character or LP.CharacterAdded:Wait()
    local hrp  = char:WaitForChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid")
    return char, hrp, hum
end
local Char, HRP, Humanoid = getChar()
LP.CharacterAdded:Connect(function() Char, HRP, Humanoid = getChar() end)

-- ============ LOBBY IDLE ============
local function applyIdle(state)
    if not Humanoid or not HRP then return end
    if state then
        if Config.IdleMethod == "walkspeed" then
            Humanoid.WalkSpeed = Config.IdleWalkSpeed
            Humanoid.JumpPower = Config.IdleJumpPower
        else
            HRP.Anchored = true
        end
    else
        if Config.IdleMethod == "walkspeed" then
            Humanoid.WalkSpeed = Config.RestoreWalkSpeed
            Humanoid.JumpPower = Config.RestoreJumpPower
        else
            HRP.Anchored = false
        end
    end
end

-- ============ ROUND / MAP DETECT ============
local function findActiveMap()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:GetAttribute("MapID") and obj:FindFirstChild("CoinContainer") then
            return obj
        end
    end
end

local function getInRoundFlag()
    local ok, v = pcall(function()
        local gd = RS:FindFirstChild("GameData")
        local iv = gd and gd:FindFirstChild("InRound")
        return iv and iv.Value
    end)
    return ok and v or nil
end

local function isRoundLive()
    local f = getInRoundFlag()
    if f ~= nil then return f end
    return findActiveMap() ~= nil
end

-- mình có THỰC SỰ ở TRONG map chưa (không còn ở lobby)
local function isInsideMap(mapModel, margin)
    margin = margin or 12
    if not (mapModel and HRP) then return false end
    local cf, size = mapModel:GetBoundingBox()
    local rel = cf:PointToObjectSpace(HRP.Position)
    local half = size * 0.5
    return math.abs(rel.X) <= half.X + margin
        and math.abs(rel.Y) <= half.Y + margin
        and math.abs(rel.Z) <= half.Z + margin
end

-- Chờ tới khi: round chạy VÀ mình đang đứng trong map
local function waitUntilActuallyInMap()
    if Config.IdleInLobby then applyIdle(true) end
    while true do
        local m = findActiveMap()
        if m and isRoundLive() and isInsideMap(m, 12) then
            if Config.IdleInLobby then applyIdle(false) end
            return m
        end
        task.wait(Config.RoundPollDelay)
    end
end

-- ============ HOP SERVER ============
local function hopServer()
    local servers, cursor = {}, nil
    local base = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(PlaceId)
    while true do
        local res = game:HttpGet(base .. (cursor and "&cursor="..cursor or ""))
        local data = HttpService:JSONDecode(res)
        for _, s in ipairs(data.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                table.insert(servers, s.id)
            end
        end
        cursor = data.nextPageCursor
        if not cursor then break end
    end
    if #servers > 0 then
        TeleportService:TeleportToPlaceInstance(PlaceId, servers[math.random(1, #servers)], LP)
    else
        TeleportService:Teleport(PlaceId, LP)
    end
end

-- ============ COIN HELPERS ============
local function getNearest(mapModel)
    local cc = mapModel and mapModel:FindFirstChild("CoinContainer")
    if not cc then return nil end
    local nearest, dist = nil, math.huge
    for _, coin in ipairs(cc:GetChildren()) do
        if coin:IsA("BasePart") then
            local v = coin:FindFirstChild("CoinVisual")
            if v and not v:GetAttribute("Collected") then
                local d = (HRP.Position - coin.Position).Magnitude
                if d < dist then
                    nearest, dist = coin, d
                end
            end
        end
    end
    return nearest
end

-- ============ SEGMENTED TWEEN (ANTI-267) ============
local function groundSnap(pos)
    local ray = Ray.new(pos + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0))
    local hit, hitPos = workspace:FindPartOnRayWithIgnoreList(ray, { Char })
    if hit then
        return Vector3.new(hitPos.X, hitPos.Y + Config.GroundOffset, hitPos.Z)
    end
    return pos
end

local currentTween
local function cancelTween()
    if currentTween then pcall(function() currentTween:Cancel() end); currentTween = nil end
end

local function tweenOnce(destPos)
    local here = HRP.Position
    local dvec = destPos - here
    local dist = dvec.Magnitude
    if dist < 0.5 then return end

    -- hạn chế thay đổi trục Y & bám sàn
    local dy = math.clamp(destPos.Y - here.Y, -Config.MaxVerticalDelta, Config.MaxVerticalDelta)
    destPos = Vector3.new(destPos.X, here.Y + dy, destPos.Z)
    destPos = groundSnap(destPos)

    local t = math.clamp(dist / Config.TweenSpeedDiv, Config.TweenMinTime, Config.TweenMaxTime)
    cancelTween()
    currentTween = TweenService:Create(HRP, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = CFrame.new(destPos) })
    currentTween:Play()
    currentTween.Completed:Wait()
    task.wait(Config.SegmentPause)
end

local function tpTo(targetPart)
    if not (HRP and targetPart and targetPart.Position) then return end
    local target = targetPart.Position

    while true do
        if not targetPart.Parent then break end -- coin biến mất
        local here = HRP.Position
        local delta = target - here
        local dist  = delta.Magnitude

        if dist <= (Config.MaxSegmentDist + 2) then
            tweenOnce(target) -- đoạn cuối
            break
        else
            local step = delta.Unit * Config.MaxSegmentDist
            tweenOnce(here + step)
        end

        -- coin có thể dịch chuyển → cập nhật
        target = targetPart.Position
    end
end

-- ============ MAIN LOOP ============
while true do
    -- 1) Lobby: đứng yên tới khi mình THỰC SỰ ở trong map
    local map = waitUntilActuallyInMap()
    local collected = 0

    -- 2) Ở trong map + round chạy => farm
    while isRoundLive() and map and map.Parent and isInsideMap(map, 12) do
        if not (Char and HRP and Humanoid) then Char, HRP, Humanoid = getChar() end

        local coin = getNearest(map)
        if coin then
            tpTo(coin)

            -- chờ coin picked hoặc timeout
            local v = coin:FindFirstChild("CoinVisual")
            local t0 = os.clock()
            while v and v.Parent and not v:GetAttribute("Collected") and (os.clock() - t0 < Config.CoinLockTime) do
                task.wait(0.05)
            end

            collected = collected + 1
            if collected >= Config.TargetCoins then break end
            task.wait(Config.DelayBetweenCoins)
        else
            task.wait(0.18)
        end
    end

    cancelTween()

    -- 3) Đủ mục tiêu thì hop, không thì quay về lobby chờ round sau
    if collected >= Config.TargetCoins then
        hopServer()
        break
    else
        task.wait(0.5)
    end
end


