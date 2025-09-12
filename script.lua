-- ================================================================
-- Mochi Farm (Luarmor-ready & Emulator-stable, no UI)
-- + Fast Hop After Collect
-- + Anti-DEAD
-- + Zero-API Brute Hop (không cần server list)
-- + Loot-aware (chỉ hop sau khi hút sạch gems)
-- + Safe-Landing (chống rơi map khi vừa Teleport)
-- + No-Rejoin-Same-Server (best-effort)
-- (Hardened for all executors incl. Wave/PC)
-- ================================================================

-- ===== CONFIG =====
local Config = {
    -- Các trường cũ vẫn để nguyên cho tương thích
    RegionFilterEnabled     = false,
    RegionList              = { "singapore", "tokyo", "us-east" },
    RetryHttpDelay          = 2,

    StrongholdChestName     = "Stronghold Diamond Chest",
    StrongholdPromptTime    = 6,
    StrongholdDiamondWait   = 10,

    FarmPlaceId             = 126509999114328,
    LobbyCheckInterval      = 2.0,
    FarmTick                = 1.0,
    DiamondTick             = 0.35,

    HopPostDelay            = 0.20,

    -- Anti-DEAD
    DeadHopTimeout          = 6.0,
    DeadUiKeywords          = { "dead", "you died", "respawn", "revive" },

    -- Chống spam fail
    MaxConsecutiveHopFail   = 5,
    ConsecutiveHopCooloff   = 6.0,

    -- ===== Zero-API Hop =====
    ZeroAPIHopEnabled       = true,
    BruteHop_MaxAttempts    = 7,
    BruteHop_PostVerifySec  = 6.5,
    PostTeleportVerifyWait  = 6.5,

    -- ===== Chỉ hop sau khi hút sạch gems =====
    OnlyHopAfterLoot        = true,
    LootDrainMaxWait        = 12.0,
    LootTickInterval        = 0.25,

    -- ===== Safe-Landing chống rơi map khi vừa teleport =====
    SafeLandingEnabled      = true,
    SafeLandingDuration     = 8.0,     -- tối đa giữ dù đã chạm đất
    SafeLandingRayDistance  = 200,     -- raycast xuống để nhận biết mặt đất
    AntiVoidFollowInterval  = 0.10,    -- nhịp cập nhật sàn Anti-Void
    AntiVoidY               = -20,     -- dưới ngưỡng này coi như rơi
    RecoveryRaise           = 8.0,     -- nâng lên mặt đất thêm bao nhiêu stud khi cứu
    AntiVoidPadSize         = Vector3.new(160, 6, 160), -- sàn tàng hình bám chân
    AntiVoidPadTransparency = 1,       -- 1 = hoàn toàn vô hình
    AntiVoidPadColor        = Color3.fromRGB(0, 255, 0), -- chỉ để debug nếu muốn
    TurnOffNoclipWhileLanding = true,  -- tắt noclip trong thời gian “hạ cánh”
    
    -- Watchdog không loot
    WatchdogInterval        = 10,
    WatchdogNoLootTimeout   = 45,
}

-- ===== SERVICES =====
local g               = game
local Players         = g:GetService("Players")
local LocalPlayer     = Players.LocalPlayer
local RS              = g:GetService("ReplicatedStorage")
local RunService      = g:GetService("RunService")
local TeleportService = g:GetService("TeleportService")
local HttpService     = g:GetService("HttpService")
local Workspace       = g:GetService("Workspace")

-- ===== UTILS =====
local function WaitForChar(timeout)
    timeout = timeout or 15
    local t = 0
    while t < timeout do
        local c = LocalPlayer.Character
        if c and c:FindFirstChild("HumanoidRootPart") and c:FindFirstChild("Humanoid") then
            return c
        end
        t += 0.25
        task.wait(0.25)
    end
    return LocalPlayer.Character
end

local function HRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function queue_on_teleport_compat(code)
    local f = (syn and syn.queue_on_teleport)
          or  queue_on_teleport
          or  (fluxus and fluxus.queue_on_teleport)
          or  (KRNL_LOADED and queue_on_teleport)
    if f then pcall(f, code) end
end

-- ===== FPS BOOST =====
do
    g.Lighting.GlobalShadows = false
    g.Lighting.Brightness    = 0
    g.Lighting.FogEnd        = 1e10
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    local function optimize(v)
        if v:IsA("BasePart") or v:IsA("MeshPart") then
            v.Material = Enum.Material.Plastic
            v.Reflectance = 0
            v.CastShadow  = false
            if v:IsA("MeshPart") then v.TextureID = "" end
            v.Transparency = 1
        elseif v:IsA("Decal") or v:IsA("Texture") then
            v.Transparency = 1
        elseif v:IsA("Fire") or v:IsA("SpotLight") or v:IsA("Smoke") or v:IsA("Sparkles") then
            v.Enabled = false
        elseif v:IsA("SpecialMesh") or v:IsA("SurfaceAppearance") then
            pcall(function() v:Destroy() end)
        end
    end
    task.spawn(function()
        for _, v in ipairs(g:GetDescendants()) do optimize(v); task.wait(0.0005) end
    end)
    g.DescendantAdded:Connect(optimize)
end

-- ===== STATE =====
local PlaceID            = g.PlaceId
local isTeleporting      = false
local HopRequested       = false
local ConsecutiveHopFail = 0
local LastHopFailAt      = 0

-- VisitedServers
getgenv().VisitedServers = getgenv().VisitedServers or { hour = -1, ids = {} }
local function nowHourUTC() return os.date("!*t").hour end
local function rotateVisitedIfHourChanged()
    local h = nowHourUTC()
    if getgenv().VisitedServers.hour ~= h then
        getgenv().VisitedServers.hour = h
        getgenv().VisitedServers.ids  = {}
    end
end
local function markVisited(sid) rotateVisitedIfHourChanged(); getgenv().VisitedServers.ids[sid] = true end

-- Watchdog / loot clock
local LastLootAt = os.clock()
local function touchLootClock() LastLootAt = os.clock() end

-- ===== DIAMOND HELPERS =====
local function diamondsLeft()
    local items = Workspace:FindFirstChild("Items")
    if not items then return false end
    return items:FindFirstChild("Diamond") ~= nil
end

local function waitNoDiamonds(timeout)
    local t0 = tick()
    while tick() - t0 < (timeout or 1.2) do
        if not diamondsLeft() then return true end
        task.wait(0.1)
    end
    return not diamondsLeft()
end

local function collectAllDiamonds()
    local n = 0
    local items = Workspace:FindFirstChild("Items")
    if not items then return 0 end
    for _, v in ipairs(items:GetChildren()) do
        if v.Name == "Diamond" then
            pcall(function()
                local ev = RS:FindFirstChild("RemoteEvents")
                local re = ev and ev:FindFirstChild("RequestTakeDiamonds")
                if re and re.FireServer then
                    re:FireServer(v)
                    n += 1
                end
            end)
        end
    end
    if n > 0 then touchLootClock() end
    return n
end

-- ================= SAFE-LANDING (Anti-Void + Delay Noclip) =================
local LandingActive = false
local AntiVoidPad   = nil
local AntiVoidConn  = nil
local SavedNoClipDefault = true   -- giá trị mặc định cho getgenv().NoClip sau khi hạ cánh

local function findSafeSpot()
    -- 1) SpawnLocation nếu có
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("SpawnLocation") then
            return inst.CFrame + Vector3.new(0, Config.RecoveryRaise or 8, 0)
        end
    end
    -- 2) Tìm Baseplate/mặt phẳng lớn nhất, anchored
    local best, score = nil, 0
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("BasePart") and inst.Anchored and inst.Size then
            local s = inst.Size.X * inst.Size.Z
            if s > score then best, score = inst, s end
        end
    end
    if best then
        return best.CFrame + Vector3.new(0, (Config.RecoveryRaise or 8), 0)
    end
    -- 3) Bất đắc dĩ: đặt ở (0,100,0)
    return CFrame.new(0, 100, 0)
end

local function raycastDown(origin)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    return Workspace:Raycast(origin, Vector3.new(0, -(Config.SafeLandingRayDistance or 200), 0), params)
end

local function ensureAntiVoidPad()
    if AntiVoidPad and AntiVoidPad.Parent then return AntiVoidPad end
    local p = Instance.new("Part")
    p.Name = "_AntiVoidPad"
    p.Anchored = true
    p.CanCollide = true
    p.Transparency = Config.AntiVoidPadTransparency or 1
    p.Color = Config.AntiVoidPadColor or Color3.new(0,1,0)
    p.Size = Config.AntiVoidPadSize or Vector3.new(160, 6, 160)
    p.Material = Enum.Material.ForceField
    p.Parent = Workspace
    AntiVoidPad = p
    return p
end

local function removeAntiVoidPad()
    if AntiVoidConn then AntiVoidConn:Disconnect(); AntiVoidConn = nil end
    if AntiVoidPad then pcall(function() AntiVoidPad:Destroy() end); AntiVoidPad = nil end
end

local function startSafeLanding()
    if not Config.SafeLandingEnabled then return end
    LandingActive = true

    -- Tắt noclip trong thời gian hạ cánh (tránh lọt sàn)
    if Config.TurnOffNoclipWhileLanding then
        SavedNoClipDefault = (getgenv().NoClip ~= false)
        getgenv().NoClip = false
    end

    local startT = os.clock()
    local function stillWithin()
        return (os.clock() - startT) < (Config.SafeLandingDuration or 8.0)
    end

    -- Theo dõi & cứu nếu rơi dưới Y, đặt pad dưới chân đến khi chạm đất
    task.spawn(function()
        while LandingActive and stillWithin() do
            local r = HRP()
            if not r then task.wait(0.1) goto continue end

            -- Nếu tụt quá thấp → cứu về spot an toàn
            if r.Position.Y < (Config.AntiVoidY or -20) then
                local safeCF = findSafeSpot()
                r.CFrame = CFrame.new(safeCF.Position)
            end

            -- Nếu chưa có mặt đất vững dưới chân → đặt pad
            local hit = raycastDown(r.Position + Vector3.new(0,2,0))
            if not hit then
                local pad = ensureAntiVoidPad()
                pad.CFrame = CFrame.new((r.Position + Vector3.new(0, -8, 0)))
            else
                -- Có mặt đất → sau một nhịp ổn định thì kết thúc hạ cánh
                removeAntiVoidPad()
                break
            end

            ::continue::
            task.wait(Config.AntiVoidFollowInterval or 0.10)
        end

        -- Kết thúc hạ cánh
        removeAntiVoidPad()
        LandingActive = false
        if Config.TurnOffNoclipWhileLanding then
            getgenv().NoClip = true  -- bật lại noclip như trước
        end
    end)
end

-- Khi character mới sinh/teleport xong → bắt đầu hạ cánh
LocalPlayer.CharacterAdded:Connect(function()
    task.delay(0.25, startSafeLanding)
end)

-- Teleport đến server mới
pcall(function()
    TeleportService.LocalPlayerArrivedFromTeleport:Connect(function()
        task.delay(0.25, startSafeLanding)
        -- mark visited, reset state
        task.delay(2, function()
            pcall(function()
                if g.JobId and g.JobId ~= "" then markVisited(g.JobId) end
                ConsecutiveHopFail = 0
                isTeleporting      = false
                touchLootClock()
            end)
        end)
    end)
end)

-- ===== NOCLIP (tôn trọng Safe-Landing) =====
getgenv().NoClip = true
RunService.Stepped:Connect(function()
    local c = LocalPlayer.Character
    if not c then return end
    -- Nếu đang hạ cánh → ép collide để khỏi lọt sàn
    local allowNoClip = (not LandingActive) and (getgenv().NoClip ~= false)
    for _, v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then v.CanCollide = not allowNoClip end
    end
end)

-- ===== MOVE =====
local function tpCFrame(cf) local r = HRP(); if r then r.CFrame = cf end end

-- ===== FINDERS =====
local chestTried, strongholdTried = {}, {}

local function findStrongholdChest()
    local items = Workspace:FindFirstChild("Items")
    if not items then return nil end
    return items:FindFirstChild(Config.StrongholdChestName)
end

local function findProximityPromptInChest(chest)
    local main = chest and chest:FindFirstChild("Main")
    if not main then return nil end
    local attach = main:FindFirstChild("ProximityAttachment")
    if not attach then return nil end
    return attach:FindFirstChild("ProximityInteraction")
end

local function findUsableChest()
    local r = HRP(); if not r then return nil end
    local closest, dist
    local items = Workspace:FindFirstChild("Items"); if not items then return nil end
    for _, v in ipairs(items:GetChildren()) do
        if v:IsA("Model") and string.find(v.Name, "Chest") and not string.find(v.Name, "Snow") then
            local id = v:GetDebugId()
            if not chestTried[id] then
                local prox = v:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prox and prox.Enabled then
                    local pv = v:GetPivot()
                    local d = (r.Position - pv.Position).Magnitude
                    if not dist or d < dist then closest, dist = v, d end
                end
            end
        end
    end
    return closest
end

-- =================== ZERO-API BRUTE TELEPORT CORE ===================
local function bruteTeleportOnce()
    if isTeleporting then return false end
    isTeleporting = true
    local before = g.JobId
    local ok, err = pcall(function()
        TeleportService:Teleport(Config.FarmPlaceId, LocalPlayer)
    end)
    task.delay(Config.BruteHop_PostVerifySec or 6.5, function()
        if g.JobId == before then
            isTeleporting      = false
            ConsecutiveHopFail += 1
            LastHopFailAt      = os.clock()
        end
    end)
    if not ok then
        warn("[ZeroAPI] Teleport() error:", tostring(err))
        isTeleporting      = false
        ConsecutiveHopFail += 1
        LastHopFailAt      = os.clock()
        return false
    end
    return true
end

-- ===== Loot-aware helpers (đảm bảo hút sạch trước khi hop) =====
local function _drainAllDiamondsUntilEmpty(timeout)
    local t0, limit = os.clock(), (timeout or Config.LootDrainMaxWait or 12)
    while os.clock() - t0 < limit do
        pcall(function()
            local ev = RS:FindFirstChild("RemoteEvents")
            local re = ev and ev:FindFirstChild("RequestTakeDiamonds")
            local items = Workspace:FindFirstChild("Items")
            if re and re.FireServer and items then
                for _, v in ipairs(items:GetChildren()) do
                    if v.Name == "Diamond" then re:FireServer(v) end
                end
            end
        end)
        if not diamondsLeft() then return true end
        task.wait(Config.LootTickInterval or 0.25)
    end
    return not diamondsLeft()
end

local function preHopLootDrain()
    if Config.OnlyHopAfterLoot and g.PlaceId == (Config.FarmPlaceId or g.PlaceId) then
        if diamondsLeft() then _drainAllDiamondsUntilEmpty(Config.LootDrainMaxWait or 12) end
    end
end

-- =================== HOP (loot-aware + safe-landing) ===================
function Hop(reason)
    if isTeleporting then return end
    preHopLootDrain()

    if ConsecutiveHopFail >= (Config.MaxConsecutiveHopFail or 5) then
        local since = os.clock() - (LastHopFailAt or 0)
        local cool  = (Config.ConsecutiveHopCooloff or 6.0)
        if since < cool then task.wait(cool - since) end
        ConsecutiveHopFail = 0
    end

    if not Config.ZeroAPIHopEnabled then Config.ZeroAPIHopEnabled = true end
    local startJob = g.JobId
    local attempts = 0
    local maxA     = Config.BruteHop_MaxAttempts or 7
    while attempts < maxA do
        attempts += 1
        bruteTeleportOnce()

        local t0 = os.clock()
        local waitSec = Config.BruteHop_PostVerifySec or 6.5
        while os.clock() - t0 < waitSec do
            if g.JobId ~= startJob then
                -- bắt đầu Safe-Landing ngay khi qua server mới
                task.spawn(startSafeLanding)
                pcall(function() if g.JobId and g.JobId ~= "" then markVisited(g.JobId) end end)
                ConsecutiveHopFail = 0
                isTeleporting      = false
                touchLootClock()
                return
            end
            task.wait(0.25)
        end
    end

    isTeleporting = false
    task.wait(1 + math.random())
    pcall(function() Hop("retry-zeroapi") end)
end

function HopFast(reason)
    if isTeleporting or HopRequested then return end
    HopRequested = true
    task.spawn(function()
        task.wait(Config.HopPostDelay or 0.2)
        preHopLootDrain()
        if not isTeleporting then Hop((reason or "fast") .. "-after-loot") end
        HopRequested = false
    end)
end

-- Teleport error → thử lại
pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(_, result, msg)
        warn("[ZeroAPI Hop] TeleportInitFailed:", tostring(result), msg or "")
        isTeleporting = false
        ConsecutiveHopFail += 1
        LastHopFailAt = os.clock()
        task.delay(0.5, function() Hop("init-failed") end)
    end)
end)

-- Bảo hiểm nếu executor không bắn ArrivedFromTeleport
queue_on_teleport_compat([[
    task.wait(1)
    pcall(function()
        getgenv().VisitedServers = getgenv().VisitedServers or { hour = -1, ids = {} }
        local h = os.date("!*t").hour
        if getgenv().VisitedServers.hour ~= h then
            getgenv().VisitedServers.hour = h
            getgenv().VisitedServers.ids  = {}
        end
        if game.JobId and game.JobId ~= "" then
            getgenv().VisitedServers.ids[game.JobId] = true
        end
    end)
]])

-- ===== AUTO JOIN / CREATE (Lobby) =====
local function autoJoinOrCreate()
    local joined = false
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and (obj.Name=="Teleporter1" or obj.Name=="Teleporter2" or obj.Name=="Teleporter3") then
            local gui  = obj:FindFirstChild("BillboardHolder")
            local board= gui and gui:FindFirstChild("BillboardGui")
            local lab  = board and board:FindFirstChild("Players")
            if lab and typeof(lab.Text) == "string" then
                local x, y = lab.Text:match("(%d+)/(%d+)")
                x, y = tonumber(x), tonumber(y)
                if x and y and x >= 2 and x < y then
                    local enter = obj:FindFirstChildWhichIsA("BasePart")
                    if enter and HRP() then
                        tpCFrame(enter.CFrame + Vector3.new(0, 3, 0))
                        joined = true
                        break
                    end
                end
            end
        end
    end
    if not joined then
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Model") and (obj.Name=="Teleporter1" or obj.Name=="Teleporter2" or obj.Name=="Teleporter3") then
                local enter = obj:FindFirstChildWhichIsA("BasePart")
                if enter and HRP() then tpCFrame(enter.CFrame + Vector3.new(0, 3, 0)); break end
            end
        end
    end
end

task.spawn(function()
    while task.wait(Config.LobbyCheckInterval) do
        if g.PlaceId ~= Config.FarmPlaceId then pcall(autoJoinOrCreate) end
    end
end)

-- ===== ANTI-DEAD =====
local IsDead, DeadSince = false, 0

local function hasDeadUi()
    local pg = LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return false end
    local lower = string.lower
    for _, gui in ipairs(pg:GetDescendants()) do
        if gui:IsA("TextLabel") or gui:IsA("TextButton") then
            local t = tostring(gui.Text or ""):gsub("%s+", " ")
            for _, k in ipairs(Config.DeadUiKeywords) do
                if lower(t):find(lower(k), 1, true) then return true end
            end
        end
    end
    return false
end

local function bindDeathWatcher(char)
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end
    hum.Died:Connect(function()
        IsDead = true
        DeadSince = tick()
    end)
end

if LocalPlayer.Character then bindDeathWatcher(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(function(c)
    IsDead = false
    DeadSince = 0
    task.wait(0.5)
    bindDeathWatcher(c)
end)

task.spawn(function()
    while task.wait(0.5) do
        if g.PlaceId ~= Config.FarmPlaceId then continue end
        if not IsDead and not hasDeadUi() then continue end
        if DeadSince == 0 then DeadSince = tick() end
        if tick() - DeadSince >= Config.DeadHopTimeout then
            HopFast("anti-dead")
        end
    end
end)

-- ===== MAIN FARM =====
local StrongholdCount, NormalChestCount = 0, 0

task.spawn(function()
    while task.wait(Config.FarmTick) do
        if g.PlaceId ~= Config.FarmPlaceId then continue end
        WaitForChar()

        -- 1) Stronghold
        local sh = findStrongholdChest()
        if sh then
            local sid = sh:GetDebugId()
            if not strongholdTried[sid] then
                local prox = findProximityPromptInChest(sh)
                if prox and prox.Enabled then
                    tpCFrame(CFrame.new(sh:GetPivot().Position + Vector3.new(0,3,0)))
                    local opened = pressPromptWithTimeout(prox, Config.StrongholdPromptTime)
                    prox = findProximityPromptInChest(sh)
                    if not opened and (prox and prox.Parent and prox.Enabled) then
                        strongholdTried[sid] = true
                    else
                        if waitDiamonds(Config.StrongholdDiamondWait) then
                            collectAllDiamonds()
                            waitNoDiamonds(1.1)
                            touchLootClock()
                            StrongholdCount += 1
                            HopFast("after-stronghold-collect")
                        else
                            strongholdTried[sid] = true
                        end
                    end
                else
                    strongholdTried[sid] = true
                end
            end
        end

        -- 2) Chest thường
        local chest = findUsableChest()
        if not chest then
            Hop("no-chest")
        else
            local id   = chest:GetDebugId()
            local prox = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
            local t0   = os.clock()
            local okOpen = false
            while prox and prox.Parent and prox.Enabled and (os.clock() - t0) < 10 do
                tpCFrame(CFrame.new(chest:GetPivot().Position))
                firePromptSafe(prox)
                task.wait(0.45)
                prox = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
            end
            if not (prox and prox.Parent and prox.Enabled) then okOpen = true end
            if okOpen then
                NormalChestCount += 1
                collectAllDiamonds()
                waitNoDiamonds(1.0)
                touchLootClock()
                HopFast("after-normalchest-collect")
            else
                chestTried[id] = true
            end
        end
    end
end)

-- 3) Diamonds song song
task.spawn(function()
    while task.wait(Config.DiamondTick) do
        if g.PlaceId == Config.FarmPlaceId then
            if collectAllDiamonds() > 0 then touchLootClock() end
        end
    end
end)

-- ===== WATCHDOG KẸT SERVER =====
task.spawn(function()
    while task.wait(Config.WatchdogInterval) do
        if g.PlaceId ~= Config.FarmPlaceId then continue end
        local since = os.clock() - LastLootAt
        if since >= Config.WatchdogNoLootTimeout then
            warn(("[Watchdog] %ds không có loot mới → Hop"):format(math.floor(since)))
            HopFast("watchdog-no-loot")
        end
    end
end)


