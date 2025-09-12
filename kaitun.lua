-- ================================================================
-- Mochi Farm (No UI)
-- + Zero-API Brute Hop + Loot-aware + Safe-Landing
-- + Anti-Repeat (avoid same servers) + Anti-DEAD + FPS Boost
-- + Auto Join Lobby + Watchdog + NoClip (respect landing)
-- ================================================================

-- ======================= CONFIG =======================
local Config = {
    Debug                   = true,         -- bật log cảnh báo để debug

    -- Farm
    StrongholdChestName     = "Stronghold Diamond Chest",
    StrongholdPromptTime    = 6,
    StrongholdDiamondWait   = 10,
    FarmPlaceId             = 126509999114328,  -- <<< kiểm tra đúng place farm
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

    -- Zero-API Hop (KHÔNG dùng server list)
    ZeroAPIHopEnabled       = true,
    BruteHop_MaxAttempts    = 8,
    BruteHop_PostVerifySec  = 7.0,
    PostTeleportVerifyWait  = 7.0,

    -- Chỉ hop sau khi hút sạch gems
    OnlyHopAfterLoot        = true,
    LootDrainMaxWait        = 12.0,
    LootTickInterval        = 0.25,

    -- Safe-Landing chống rơi khi teleport
    SafeLandingEnabled      = true,
    SafeLandingDuration     = 10.0,
    SafeLandingRayDistance  = 200,
    AntiVoidFollowInterval  = 0.08,
    AntiVoidY               = -40,
    RecoveryRaise           = 10.0,
    AntiVoidPadSize         = Vector3.new(220, 8, 220),
    AntiVoidPadTransparency = 1,
    TurnOffNoclipWhileLanding = true,

    -- Watchdog không loot
    WatchdogInterval        = 10,
    WatchdogNoLootTimeout   = 45,

    -- ===== Tránh lặp 1 server (Anti-Repeat) =====
    RecentServerTTL               = 15 * 60,  -- 15 phút coi là "vừa ghé"
    RecentServerMax               = 240,      -- tối đa lượng JobId nhớ
    ReHopDelayIfRecent            = 0.8,      -- nếu rơi vào server vừa ghé → re-hop sau Xs
    MaxConsecutiveRecentLandings  = 3,        -- lặp liên tiếp ≥ N → thử bounce

    -- (tuỳ chọn) Bounce qua place phụ rồi quay về farm để reset đường
    BouncePlaceId                 = nil,      -- điền placeId lobby/phụ nếu có; nil = tắt
    BounceTries                   = 2,
}

-- ===================== SERVICES ======================
local g               = game
local Players         = g:GetService("Players")
local LocalPlayer     = Players.LocalPlayer
local RS              = g:GetService("ReplicatedStorage")
local RunService      = g:GetService("RunService")
local TeleportService = g:GetService("TeleportService")
local Workspace       = g:GetService("Workspace")
local HttpService     = g:GetService("HttpService")

local function log(...) if Config.Debug then warn("[Mochi]", ...) end end

-- ======================= UTILS ========================
local function WaitForChar(timeout)
    timeout = timeout or 15
    local t = 0
    while t < timeout do
        local c = LocalPlayer.Character
        if c and c:FindFirstChild("HumanoidRootPart") and c:FindFirstChildOfClass("Humanoid") then
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

-- ===================== FPS BOOST =====================
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

-- ======================= STATE =======================
local isTeleporting      = false
local HopRequested       = false
local ConsecutiveHopFail = 0
local LastHopFailAt      = 0

-- VisitedServers (best-effort, reset theo giờ)
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

-- ===== RECENT SERVERS (TTL) =====
local Recent = { list = {}, hitsInRow = 0 }
local function _pruneRecent(now)
    local ttl = Config.RecentServerTTL or 900
    local n = 0
    for id, t in pairs(Recent.list) do
        if (now - t) > ttl then Recent.list[id] = nil else n = n + 1 end
    end
    if n > (Config.RecentServerMax or 240) then
        local c = 0
        for id,_ in pairs(Recent.list) do
            Recent.list[id] = nil; c = c + 1
            if n - c <= (Config.RecentServerMax or 240) then break end
        end
    end
end
local function markRecent(jobid)
    if not jobid or jobid == "" then return end
    Recent.list[jobid] = os.clock()
    _pruneRecent(os.clock())
end
local function seenRecently(jobid)
    local t = Recent.list[jobid]
    if not t then return false end
    return (os.clock() - t) <= (Config.RecentServerTTL or 900)
end

-- (tuỳ chọn) Bounce qua place phụ rồi quay lại farm
local function bounceThenReturn()
    local bounceId = Config.BouncePlaceId
    if not bounceId then return false end
    local ok = false
    local tries = Config.BounceTries or 2
    for i=1,tries do
        ok = pcall(function()
            queue_on_teleport_compat(([[
                task.wait(0.8)
                pcall(function()
                    game:GetService("TeleportService"):Teleport(%d, game:GetService("Players").LocalPlayer)
                end)
            ]]):format(Config.FarmPlaceId))
            game:GetService("TeleportService"):Teleport(bounceId, game:GetService("Players").LocalPlayer)
        end)
        if ok then break end
        task.wait(0.5 + math.random())
    end
    return ok
end

-- ================== DIAMOND HELPERS ==================
local function diamondsFolder()
    return Workspace:FindFirstChild("Items")
        or Workspace:FindFirstChild("items")
        or Workspace:FindFirstChild("Drops")
        or nil
end
local function diamondsLeft()
    local items = diamondsFolder()
    if not items then return false end
    return items:FindFirstChild("Diamond") ~= nil
end
local function collectAllDiamonds()
    local count = 0
    local items = diamondsFolder()
    if not items then return 0 end
    local ev = RS:FindFirstChild("RemoteEvents")
    local re = ev and (ev:FindFirstChild("RequestTakeDiamonds") or ev:FindFirstChild("TakeDiamond") or ev:FindFirstChild("CollectDiamond"))
    if not re or not re.FireServer then return 0 end
    for _, v in ipairs(items:GetChildren()) do
        if v.Name == "Diamond" then pcall(function() re:FireServer(v); count += 1 end) end
    end
    if count > 0 then touchLootClock() end
    return count
end
local function drainDiamondsUntilEmpty(timeout)
    local t0, limit = os.clock(), (timeout or Config.LootDrainMaxWait or 12)
    while os.clock() - t0 < limit do
        collectAllDiamonds()
        if not diamondsLeft() then return true end
        task.wait(Config.LootTickInterval or 0.25)
    end
    return not diamondsLeft()
end

-- ================= SAFE-LANDING ======================
local LandingActive = false
local AntiVoidPad   = nil
local function raycastDown(origin)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    return Workspace:Raycast(origin, Vector3.new(0, -(Config.SafeLandingRayDistance or 200), 0), params)
end
local function findSafeSpot()
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("SpawnLocation") then
            return inst.CFrame + Vector3.new(0, Config.RecoveryRaise or 10, 0)
        end
    end
    local best, score
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("BasePart") and inst.Anchored then
            local s = inst.Size.X * inst.Size.Z
            if (not score) or (s > score) then best, score = inst, s end
        end
    end
    if best then return best.CFrame + Vector3.new(0, Config.RecoveryRaise or 10, 0) end
    return CFrame.new(0, 100, 0)
end
local function ensurePad()
    if AntiVoidPad and AntiVoidPad.Parent then return AntiVoidPad end
    local p = Instance.new("Part")
    p.Name = "_AntiVoidPad"; p.Anchored = true; p.CanCollide = true
    p.Transparency = Config.AntiVoidPadTransparency or 1
    p.Size = Config.AntiVoidPadSize or Vector3.new(220, 8, 220)
    p.Material = Enum.Material.ForceField
    p.Parent = Workspace
    AntiVoidPad = p
    return p
end
local function removePad() if AntiVoidPad then pcall(function() AntiVoidPad:Destroy() end); AntiVoidPad=nil end end
local function startSafeLanding()
    if not Config.SafeLandingEnabled then return end
    LandingActive = true
    if Config.TurnOffNoclipWhileLanding then getgenv().NoClip = false end
    log("SafeLanding start")
    local startT = os.clock()
    task.spawn(function()
        while LandingActive and (os.clock()-startT) < (Config.SafeLandingDuration or 10) do
            local r = HRP()
            if r then
                if r.Position.Y < (Config.AntiVoidY or -40) then
                    log("AntiVoid rescue")
                    r.CFrame = findSafeSpot()
                end
                local hit = raycastDown(r.Position + Vector3.new(0,2,0))
                if not hit then
                    local pad = ensurePad()
                    pad.CFrame = CFrame.new(r.Position.X, r.Position.Y-8, r.Position.Z)
                else
                    removePad()
                    break
                end
            end
            task.wait(Config.AntiVoidFollowInterval or 0.08)
        end
        removePad(); LandingActive=false
        if Config.TurnOffNoclipWhileLanding then getgenv().NoClip = true end
        log("SafeLanding done")
    end)
end
LocalPlayer.CharacterAdded:Connect(function() task.delay(0.25, startSafeLanding) end)

-- =================== NOCLIP Loop =====================
getgenv().NoClip = true
RunService.Stepped:Connect(function()
    local c = LocalPlayer.Character
    if not c then return end
    local allowNoClip = (not LandingActive) and (getgenv().NoClip ~= false)
    for _, v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then v.CanCollide = not allowNoClip end
    end
end)

-- =================== MOVE helper =====================
local function tpCFrame(cf) local r = HRP(); if r then r.CFrame = cf end end

-- =================== FINDERS ========================
local chestTried, strongholdTried = {}, {}
local function findStrongholdChest()
    local items = Workspace:FindFirstChild("Items"); if not items then return nil end
    return items:FindFirstChild(Config.StrongholdChestName)
end
local function findProximityPromptInChest(chest)
    local main = chest and chest:FindFirstChild("Main"); if not main then return nil end
    local attach = main:FindFirstChild("ProximityAttachment"); if not attach then return nil end
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
local function firePromptSafe(prompt)
    if typeof(fireproximityprompt) == "function" then
        pcall(function() fireproximityprompt(prompt, 1) end)
    else
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and prompt and prompt.HoldDuration == 0 then
                hum:MoveTo(prompt.Parent and prompt.Parent.Position or HRP().Position)
            end
        end)
    end
end
local function pressPromptWithTimeout(prompt, timeout)
    local t0 = tick()
    while prompt and prompt.Parent and prompt.Enabled and (tick()-t0) < (timeout or 6) do
        firePromptSafe(prompt); task.wait(0.3)
    end
    return not (prompt and prompt.Parent and prompt.Enabled)
end
local function waitDiamonds(timeout)
    local t0 = tick()
    while (tick()-t0) < (timeout or 2.0) do
        local items = diamondsFolder()
        if items and items:FindFirstChild("Diamond") then return true end
        task.wait(0.2)
    end
    return false
end

-- ================ ZERO-API HOP CORE ==================
local function bruteTeleportOnce()
    if isTeleporting then return false end
    isTeleporting = true
    local before = g.JobId
    local ok, err = pcall(function()
        TeleportService:Teleport(Config.FarmPlaceId, LocalPlayer)
    end)
    task.delay(Config.BruteHop_PostVerifySec or 7.0, function()
        if g.JobId == before then
            isTeleporting      = false
            ConsecutiveHopFail += 1
            LastHopFailAt      = os.clock()
            log("Teleport issued but still same JobId → mark fail")
        end
    end)
    if not ok then
        isTeleporting      = false
        ConsecutiveHopFail += 1
        LastHopFailAt      = os.clock()
        log("Teleport() error:", tostring(err))
        return false
    end
    return true
end

-- Loot-aware guard
local function preHopLootDrain()
    if not Config.OnlyHopAfterLoot then return end
    if g.PlaceId ~= (Config.FarmPlaceId or g.PlaceId) then return end
    local items = diamondsFolder()
    if not items then return end
    if not RS:FindFirstChild("RemoteEvents") then return end
    if diamondsLeft() then drainDiamondsUntilEmpty(Config.LootDrainMaxWait or 12) end
end

-- =================== HOP FUNCS ======================
function Hop(reason)
    if isTeleporting then return end
    log("Hop:", reason or "")

    -- đánh dấu server sắp rời (để tránh quay lại ngay)
    pcall(function() if g.JobId and g.JobId ~= "" then markRecent(g.JobId) end end)

    preHopLootDrain()

    if ConsecutiveHopFail >= (Config.MaxConsecutiveHopFail or 5) then
        local since = os.clock() - (LastHopFailAt or 0)
        local cool  = (Config.ConsecutiveHopCooloff or 6)
        if since < cool then task.wait(cool - since) end
        ConsecutiveHopFail = 0
    end

    if not Config.ZeroAPIHopEnabled then Config.ZeroAPIHopEnabled = true end
    local startJob = g.JobId
    local attempts = 0
    local maxA     = Config.BruteHop_MaxAttempts or 8
    while attempts < maxA do
        attempts += 1
        log(("Teleport attempt %d/%d"):format(attempts, maxA))
        bruteTeleportOnce()
        local t0 = os.clock()
        local waitSec = Config.BruteHop_PostVerifySec or 7.0
        while os.clock() - t0 < waitSec do
            if g.JobId ~= startJob then
                -- Sang server mới
                task.spawn(startSafeLanding)
                pcall(function()
                    if g.JobId and g.JobId ~= "" then
                        markVisited(g.JobId); markRecent(g.JobId)
                    end
                end)
                ConsecutiveHopFail = 0
                isTeleporting      = false
                touchLootClock()

                -- Anti-Repeat: nếu là server vừa ghé → re-hop ngắn
                if seenRecently(g.JobId) then
                    Recent.hitsInRow = (Recent.hitsInRow or 0) + 1
                    warn(("[Anti-Repeat] Landed on RECENT server (%s), re-hop in %.1fs. Chain=%d")
                         :format(g.JobId, Config.ReHopDelayIfRecent or 0.8, Recent.hitsInRow))
                    task.delay(Config.ReHopDelayIfRecent or 0.8, function() HopFast("recent-server") end)
                    if Recent.hitsInRow >= (Config.MaxConsecutiveRecentLandings or 3) and Config.BouncePlaceId then
                        Recent.hitsInRow = 0
                        task.delay(0.2, function() bounceThenReturn() end)
                    end
                else
                    Recent.hitsInRow = 0
                end
                return
            end
            task.wait(0.25)
        end
    end

    isTeleporting = false
    task.wait(1 + math.random())
    log("Retry hop (still same JobId)")
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

-- Teleport events
pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(_, result, msg)
        log("TeleportInitFailed:", tostring(result), msg or "")
        isTeleporting = false
        ConsecutiveHopFail += 1
        LastHopFailAt = os.clock()
        task.delay(0.5, function() Hop("init-failed") end)
    end)
    TeleportService.LocalPlayerArrivedFromTeleport:Connect(function()
        task.delay(0.25, startSafeLanding)
        task.delay(2, function()
            pcall(function()
                if g.JobId and g.JobId ~= "" then
                    markVisited(g.JobId); markRecent(g.JobId)
                end
                ConsecutiveHopFail = 0
                isTeleporting      = false
                touchLootClock()
            end)
            if seenRecently(g.JobId) then
                Recent.hitsInRow = (Recent.hitsInRow or 0) + 1
                task.delay(Config.ReHopDelayIfRecent or 0.8, function() HopFast("recent-server-arrived") end)
                if Recent.hitsInRow >= (Config.MaxConsecutiveRecentLandings or 3) and Config.BouncePlaceId then
                    Recent.hitsInRow = 0
                    task.delay(0.1, bounceThenReturn)
                end
            else
                Recent.hitsInRow = 0
            end
        end)
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

-- ================== AUTO JOIN LOBBY ==================
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

-- ==================== ANTI-DEAD ======================
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
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.Died:Connect(function() IsDead = true; DeadSince = tick() end)
end
if LocalPlayer.Character then bindDeathWatcher(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(function(c)
    IsDead = false; DeadSince = 0; task.wait(0.5); bindDeathWatcher(c)
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

-- ==================== MAIN FARM ======================
local StrongholdCount, NormalChestCount = 0, 0
task.spawn(function()
    while task.wait(Config.FarmTick) do
        if g.PlaceId ~= Config.FarmPlaceId then continue end
        WaitForChar()

        -- Stronghold
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
                            collectAllDiamonds(); task.wait(0.1)
                            if not diamondsLeft() then touchLootClock() end
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

        -- Chest thường
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
                task.wait(0.1); if not diamondsLeft() then touchLootClock() end
                HopFast("after-normalchest-collect")
            else
                chestTried[id] = true
            end
        end
    end
end)

-- Diamonds song song
task.spawn(function()
    while task.wait(Config.DiamondTick) do
        if g.PlaceId == Config.FarmPlaceId then
            if collectAllDiamonds() > 0 then touchLootClock() end
        end
    end
end)

-- Watchdog không loot
task.spawn(function()
    while task.wait(Config.WatchdogInterval) do
        if g.PlaceId ~= Config.FarmPlaceId then continue end
        local since = os.clock() - LastLootAt
        if since >= Config.WatchdogNoLootTimeout then
            log(("Watchdog: %ds no loot -> Hop"):format(math.floor(since)))
            HopFast("watchdog-no-loot")
        end
    end
end)

-- Smoke-test tiện kiểm tra hop
getgenv().MochiTestHop = function()
    warn("[Mochi] SMOKE TEST: forcing Hop in 1s")
    task.wait(1); Hop("smoke-test")
end


