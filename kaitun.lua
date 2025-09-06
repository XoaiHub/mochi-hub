-- mm2 coin farm (Lobby-safe + MoveTo-first + 40 coin)
-- Chỉ farm khi round mới start & bạn đã vào map; đủ 40 coin tự về lobby.

-- ================== CONFIG ==================
local Config = {
    CoinBagLimit       = 40,     -- đổi 50 nếu có Elite
    MoveToTimeout      = 2.0,    -- s tối đa bám 1 coin bằng MoveTo
    RecheckWait        = 0.15,   -- s khi không thấy coin
    RoundPollInterval  = 0.25,   -- s kiểm tra trạng thái round
    NearCollectRadius  = 8.0,    -- bán kính coi như “đã nhặt”
    TweenFallbackSpeed = 28,     -- tốc Tween fallback
    TweenMin           = 0.12,
    TweenMax           = 1.8,
    LobbyKeywords      = {"Lobby","Vote","Spawn"}, -- để phân biệt lobby/map
    CoinNamePatterns   = {"coin","cash","token"},  -- tìm theo tên (lowercase)
    CoinContainerHints = {"CoinContainer","Coins","Drops"},
}

-- ================== SERVICES ==================
local g               = game
local Players         = g:GetService("Players")
local TweenService    = g:GetService("TweenService")
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
local function inRoundFlag()
    local ok, val = pcall(function()
        local gd = RS:FindFirstChild("GameData")
        local iv = gd and gd:FindFirstChild("InRound")
        return iv and iv.Value
    end)
    if ok and val ~= nil then return val end
    return nil
end

local function looksLikeLobbyPart(part)
    for _, k in ipairs(Config.LobbyKeywords) do
        if string.find(string.lower(part.Name), string.lower(k)) then
            return true
        end
    end
    return false
end

-- đoán bạn đã “ở map” (xa khu lobby / không đứng trong khu đặt tên lobby)
local function isInsideMap()
    if not (HRP and HRP.Parent) then return false end
    -- Nếu gần các part tên lobby -> coi là lobby
    local nearLobby = false
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") and looksLikeLobbyPart(d) then
            if (HRP.Position - d.Position).Magnitude <= 60 then
                nearLobby = true
                break
            end
        end
    end
    return not nearLobby
end

-- Tìm “map đang active”: ưu tiên model có attribute MapID; nếu không, model có nhiều coin
local function findActiveMap()
    local best, bestCoinCount = nil, 0

    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") then
            if obj:GetAttribute and obj:GetAttribute("MapID") then
                return obj
            end
            -- đếm coin dựa trên hints/patterns
            local count = 0
            for _, hint in ipairs(Config.CoinContainerHints) do
                local c = obj:FindFirstChild(hint, true)
                if c and c:IsA("Folder") then
                    count = count + #c:GetChildren()
                end
            end
            if count > bestCoinCount then
                bestCoinCount = count
                best = obj
            end
        end
    end
    return best
end

local function isRoundLive()
    local f = inRoundFlag()
    if f ~= nil then return f end
    local m = findActiveMap()
    if not m then return false end
    -- nếu map có coin xuất hiện -> coi như đang round
    local cc = 0
    for _, hint in ipairs(Config.CoinContainerHints) do
        local c = m:FindFirstChild(hint, true)
        if c then cc = cc + #c:GetChildren() end
    end
    return cc > 0
end

local function waitUntilNoRound()
    while isRoundLive() do task.wait(Config.RoundPollInterval) end
end

local function waitForNewRoundStart()
    -- không nhảy vào round đang chạy
    waitUntilNoRound()
    -- đợi round mới VÀ bạn đã được thả vào map (không còn ở lobby)
    while true do
        if isRoundLive() and isInsideMap() then
            local m = findActiveMap()
            if m then return m end
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
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") and looksLikeLobbyPart(d) then
            return d.CFrame
        end
    end
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("SpawnLocation") then return d.CFrame end
    end
    return CFrame.new(0,50,0)
end

local function returnToLobby()
    if tryRemoteToLobby() then return end
    local cf = findLobbySpawnCF()
    if Char and HRP then
        if Humanoid then pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.Physics) end) end
        HRP.CFrame = cf + Vector3.new(0,3,0)
    end
end

-- ================== COIN FIND ==================
local function isCoinPart(p)
    if not (p and p:IsA("BasePart")) then return false end
    local lname = string.lower(p.Name)
    for _, kw in ipairs(Config.CoinNamePatterns) do
        if string.find(lname, kw) then return true end
    end
    -- coin hay có child kiểu “CoinVisual”, “TouchInterest”
    if p:FindFirstChild("CoinVisual") or p:FindFirstChildOfClass("TouchTransmitter") then
        return true
    end
    return false
end

local function getAllCoins(mapModel)
    local out = {}
    if not (mapModel and mapModel.Parent) then return out end

    -- 1) ưu tiên container hints
    for _, hint in ipairs(Config.CoinContainerHints) do
        local c = mapModel:FindFirstChild(hint, true)
        if c then
            for _, ch in ipairs(c:GetChildren()) do
                if isCoinPart(ch) then table.insert(out, ch) end
            end
        end
    end
    -- 2) fallback: quét toàn bộ model
    if #out == 0 then
        for _, d in ipairs(mapModel:GetDescendants()) do
            if isCoinPart(d) then table.insert(out, d) end
        end
    end
    return out
end

local function getNearest(mapModel)
    local coins = getAllCoins(mapModel)
    local closest, dist = nil, math.huge
    for _, coin in ipairs(coins) do
        -- skip coin đã “Collected” nếu có cờ
        local v = coin:FindFirstChild("CoinVisual")
        if not (v and v:GetAttribute and v:GetAttribute("Collected")) then
            local d = (HRP.Position - coin.Position).Magnitude
            if d < dist then
                closest = coin; dist = d
            end
        end
    end
    return closest
end

-- ================== MOVEMENT ==================
local function moveToCoin(coin)
    if not (coin and coin.Parent and Humanoid and HRP) then return false end
    local reached = false
    local done = false

    -- 1) MoveTo “hợp lệ” để chạm coin
    Humanoid:MoveTo(coin.Position)
    local start = os.clock()
    while os.clock() - start < Config.MoveToTimeout do
        if not (coin and coin.Parent) then
            reached = true; break
        end
        if (HRP.Position - coin.Position).Magnitude <= Config.NearCollectRadius then
            -- thường khi sát coin 1-2 khung là biến mất
            task.wait(0.05)
            if not (coin and coin.Parent) then
                reached = true; break
            end
        end
        task.wait(0.05)
    end
    done = reached

    -- 2) Fallback Tween (nhẹ) nếu MoveTo không “ăn”
    if not done and coin and coin.Parent then
        local d   = (HRP.Position - coin.Position).Magnitude
        local dur = math.clamp(d / Config.TweenFallbackSpeed, Config.TweenMin, Config.TweenMax)
        local tw  = TweenService:Create(HRP, TweenInfo.new(dur, Enum.EasingStyle.Linear), {CFrame = coin.CFrame})
        tw:Play(); tw.Completed:Wait()
        task.wait(0.05)
        done = not (coin and coin.Parent)
    end

    -- 3) Lắc nhẹ quanh coin (±1.5 studs) để chắc chắn chạm
    if not done and coin and coin.Parent then
        local offsets = {
            Vector3.new(1.5, 0, 0), Vector3.new(-1.5, 0, 0),
            Vector3.new(0, 0, 1.5), Vector3.new(0, 0, -1.5),
        }
        for _, off in ipairs(offsets) do
            Humanoid:MoveTo(coin.Position + off)
            task.wait(0.12)
            if not (coin and coin.Parent) then break end
        end
        done = not (coin and coin.Parent)
    end

    return done
end

-- ================== FARM 1 ROUND ==================
local function farmRound(mapModel)
    local bag = 0
    local seen = {}

    while isRoundLive() and mapModel and mapModel.Parent do
        if not (Char and Char.Parent and HRP and HRP.Parent and Humanoid and Humanoid.Parent) then
            Char, HRP, Humanoid = getChar()
        end
        if bag >= Config.CoinBagLimit then break end

        local coin = getNearest(mapModel)
        if coin and not seen[coin] then
            seen[coin] = true
            local ok = moveToCoin(coin)
            if ok then
                bag = bag + 1
            else
                task.wait(0.07)
            end
        else
            task.wait(Config.RecheckWait)
        end
    end

    return bag
end

-- ================== MAIN LOOP ==================
while true do
    -- Chỉ start khi round mới & bạn đã ở trong map (không phải lobby)
    local currentMap = waitForNewRoundStart()

    local got = farmRound(currentMap)

    -- đủ 40 coin hoặc hết round -> về lobby
    if got >= Config.CoinBagLimit then
        returnToLobby()
        waitUntilNoRound()
    else
        waitUntilNoRound()
    end

    task.wait(0.4)
end


