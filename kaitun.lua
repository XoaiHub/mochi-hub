-- mm2 coin farm 🤑 (Lobby-safe + 40-coin exit)
-- YÊU CẦU: chỉ bắt đầu farm khi round MỚI bắt đầu; khi đang ở lobby thì đứng yên
-- Khi đủ 40 coin: tự rời map về lobby (nếu có thể)

-- ================== CONFIG ==================
local Config = {
    CoinBagLimit       = 40,     -- đổi 50 nếu bạn có Elite
    TweenSpeedFactor   = 28,     -- càng lớn càng nhanh (nhưng giới hạn bên dưới để tránh kick)
    TweenMin           = 0.10,   -- giây
    TweenMax           = 2.0,    -- giây
    StickCoinTimeout   = 2.6,    -- giây, bám 1 coin tối đa
    RecheckWait        = 0.18,   -- giây, khi chưa thấy coin
    RoundPollInterval  = 0.25,   -- giây, polling trạng thái round
    NearCollectRadius  = 8.0,    -- chỉ tính là mình nhặt khi ở rất gần lúc coin biến mất
    LobbyTagNames      = {"LobbySpawn","SpawnLocation","Lobby","VoteArea","MapVote"}, -- tìm điểm về lobby
}

-- ================== SERVICES ==================
local g               = game
local TweenService    = g:GetService("TweenService")
local Players         = g:GetService("Players")
local RS              = g:GetService("ReplicatedStorage")
local LP              = Players.LocalPlayer

-- ================== CHARACTER SAFE ==================
local function getChar()
    local char = LP.Character or LP.CharacterAdded:Wait()
    local hrp  = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid")
    return char, hrp, hum
end
local Char, HRP, Humanoid = getChar()
LP.CharacterAdded:Connect(function() Char, HRP, Humanoid = getChar() end)

-- ================== ROUND / MAP DETECT ==================
local function findActiveMap()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:GetAttribute and obj:GetAttribute("MapID") and obj:FindFirstChild("CoinContainer") then
            return obj
        end
    end
    return nil
end

local function inRoundFlag()
    local ok, val = pcall(function()
        local gd = RS:FindFirstChild("GameData")
        local iv = gd and gd:FindFirstChild("InRound")
        return iv and iv.Value
    end)
    if ok and val ~= nil then return val end
    return nil
end

local function isRoundLive()
    -- 1) nếu có GameData.InRound thì dùng
    local f = inRoundFlag()
    if f ~= nil then return f end
    -- 2) fallback: có map và CoinContainer bắt đầu có coin
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

-- Chờ round cũ kết thúc hoàn toàn (đang có round thì đứng yên)
local function waitUntilNoRound()
    while isRoundLive() do
        task.wait(Config.RoundPollInterval)
    end
end

-- Chờ round mới start (có map + đang trong round)
local function waitForNewRoundStart()
    -- bảo đảm đang ở “không round” trước đã (để không nhảy ngang round đang chơi)
    waitUntilNoRound()
    -- đợi tới khi round mới thực sự bắt đầu
    while true do
        local m = findActiveMap()
        if m and isRoundLive() then
            return m
        end
        task.wait(Config.RoundPollInterval)
    end
end

-- ================== LOBBY RETURN ==================
local function tryRemoteToLobby()
    local rems = RS:FindFirstChild("Remotes") or RS:FindFirstChild("Remote") or RS
    if rems then
        for _, n in ipairs({"TeleportToLobby","ReturnToLobby","GoToLobby","TeleportBack"}) do
            local r = rems:FindFirstChild(n)
            if r and r:IsA("RemoteEvent") then
                pcall(function() r:FireServer() end)
                return true
            end
            if r and r:IsA("RemoteFunction") then
                pcall(function() r:InvokeServer() end)
                return true
            end
        end
    end
    return false
end

local function findLobbySpawnCF()
    -- ưu tiên các Part/Spawn có tên gợi ý
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            for _, key in ipairs(Config.LobbyTagNames) do
                if string.find(string.lower(obj.Name), string.lower(key)) then
                    return obj.CFrame
                end
            end
        end
    end
    -- fallback: SpawnLocation bất kỳ
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("SpawnLocation") then
            return obj.CFrame
        end
    end
    -- fallback cuối: gốc thế giới
    return CFrame.new(0, 50, 0)
end

local function returnToLobby()
    -- 1) thử remote (nếu game hỗ trợ)
    if tryRemoteToLobby() then return end
    -- 2) tele về khu lobby/spawn
    local cf = findLobbySpawnCF()
    if Char and HRP then
        if Humanoid then pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.Physics) end) end
        HRP.CFrame = cf + Vector3.new(0, 3, 0)
    end
end

-- ================== COIN LOGIC ==================
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

local function smartTweenTo(part)
    if not (HRP and part and part.CFrame) then return end
    if Humanoid then pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.Physics) end) end
    local d   = (HRP.Position - part.Position).Magnitude
    local dur = math.clamp(d / Config.TweenSpeedFactor, Config.TweenMin, Config.TweenMax)
    local tw  = TweenService:Create(HRP, TweenInfo.new(dur, Enum.EasingStyle.Linear), {CFrame = part.CFrame})
    tw:Play()
    tw.Completed:Wait()
end

-- ước lượng coin đã nhặt trong round: tăng khi coin biến mất ngay cạnh mình
local function farmRound(mapModel)
    local coinCount = 0
    local seen      = {} -- tránh double count cùng 1 coin

    while isRoundLive() and mapModel and mapModel.Parent do
        -- refresh char refs nếu respawn
        if not (Char and Char.Parent and HRP and HRP.Parent and Humanoid and Humanoid.Parent) then
            Char, HRP, Humanoid = getChar()
        end
        if coinCount >= Config.CoinBagLimit then
            break
        end

        local target = getNearest(mapModel)
        if target and not seen[target] then
            seen[target] = true
            local startPos = HRP.Position
            smartTweenTo(target)

            local v  = target:FindFirstChild("CoinVisual")
            local t0 = os.clock()
            while isRoundLive() and v and v.Parent and not v:GetAttribute("Collected") do
                -- nếu xuất hiện coin gần hơn rõ rệt thì chuyển mục tiêu
                local n = getNearest(mapModel)
                if n and n ~= target then break end
                if os.clock() - t0 > Config.StickCoinTimeout then break end
                task.wait(0.05)
            end

            -- nếu coin biến mất ngay gần mình -> coi như mình đã nhặt
            if not (target and target.Parent) then
                local dist = (HRP.Position - startPos).Magnitude
                -- chỉ cộng khi mình thực sự đã tới rất gần coin
                if dist < 100 and (HRP.Position - (target and target.Position or HRP.Position)).Magnitude <= Config.NearCollectRadius then
                    coinCount = coinCount + 1
                end
            elseif v and v:GetAttribute("Collected") then
                -- visual báo Collected
                coinCount = coinCount + 1
            end
        else
            task.wait(Config.RecheckWait)
        end
    end

    return coinCount
end

-- ================== MAIN LOOP ==================
while true do
    -- Đang có round nhưng bạn ở lobby -> đứng yên, chờ round đó kết thúc
    -- (đảm bảo KHÔNG nhảy vào map đang chơi)
    local currentMap = waitForNewRoundStart()

    -- Round mới đã bắt đầu -> farm
    local got = farmRound(currentMap)

    -- đủ 40 coin (hoặc hết round)
    if got >= Config.CoinBagLimit then
        -- cố gắng quay về lobby ngay (nếu game cho phép)
        returnToLobby()
        -- đợi round kết thúc thực sự để sync trạng thái trước khi lặp
        waitUntilNoRound()
    else
        -- nếu chưa đủ mà round đã hết -> tự nhiên sẽ về lobby, chỉ chờ sync
        waitUntilNoRound()
    end

    task.wait(0.4)
end


