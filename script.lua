-- ================================================================
-- Mochi Farm (Luarmor-ready & Emulator-stable, no UI)
-- + Fast Hop After Collect
-- + Anti-DEAD + Skip API (Zero-API Brute Hop) + No-Rejoin-Same-Server (best-effort)
-- (Hardened for all executors incl. Wave)
-- ================================================================

-- ===== CONFIG =====
local Config = {
    RegionFilterEnabled     = false,                         -- (cũ, nay không dùng vì bỏ API server list)
    RegionList              = { "singapore", "tokyo", "us-east" },
    RetryHttpDelay          = 2,

    StrongholdChestName     = "Stronghold Diamond Chest",
    StrongholdPromptTime    = 6,
    StrongholdDiamondWait   = 10,

    FarmPlaceId             = 126509999114328,               -- map farm
    LobbyCheckInterval      = 2.0,
    FarmTick                = 1.0,
    DiamondTick             = 0.35,

    HopPostDelay            = 0.20,                          -- trễ nhỏ cho HopFast sau khi nhặt xong

    -- Anti-DEAD
    DeadHopTimeout          = 6.0,
    DeadUiKeywords          = { "dead", "you died", "respawn", "revive" },

    -- Spam-protection (chung)
    MaxConsecutiveHopFail   = 5,
    ConsecutiveHopCooloff   = 6.0,

    -- ===== Zero-API Hop Mode (KHÔNG dùng API server list) =====
    ZeroAPIHopEnabled       = true,   -- bật brute teleport
    BruteHop_MaxAttempts    = 7,      -- số lần Teleport(placeId) liên tiếp mỗi lượt
    BruteHop_PostVerifySec  = 6.5,    -- chờ sau mỗi lần Teleport để kiểm tra JobId đổi chưa
    PostTeleportVerifyWait  = 6.5,    -- đồng bộ để không còn lỗi nil (dùng nội bộ)
    
    -- Watchdog (chống kẹt server không có loot)
    WatchdogInterval        = 10,     -- mỗi 10s kiểm tra
    WatchdogNoLootTimeout   = 45,     -- >45s không có loot mới → Hop
}

-- ===== SERVICES =====
local g               = game
local Players         = g:GetService("Players")
local LocalPlayer     = Players.LocalPlayer
local RS              = g:GetService("ReplicatedStorage")
local RunService      = g:GetService("RunService")
local HttpService     = g:GetService("HttpService")
local TeleportService = g:GetService("TeleportService")

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

-- queue_on_teleport tương thích
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
local PlaceID               = g.PlaceId
local isTeleporting         = false
local HopRequested          = false
local ConsecutiveHopFail    = 0
local LastHopFailAt         = 0

-- “VisitedServers” (best-effort để hạn chế quay lại cùng JobId)
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

-- Watchdog / loot state
local LastLootAt = os.clock()
local function touchLootClock() LastLootAt = os.clock() end

-- ===== DIAMOND HELPERS =====
local function diamondsLeft()
    local items = workspace:FindFirstChild("Items")
    if not items then return false end
    for _, v in ipairs(items:GetChildren()) do
        if v.Name == "Diamond" then return true end
    end
    return false
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
    local items = workspace:FindFirstChild("Items")
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

-- ===== NOCLIP =====
getgenv().NoClip = true
RunService.Stepped:Connect(function()
    local c = LocalPlayer.Character
    if not c then return end
    local on = getgenv().NoClip
    for _, v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then v.CanCollide = not on end
    end
end)

-- ===== MOVE =====
local function tpCFrame(cf) local r = HRP(); if r then r.CFrame = cf end end

-- ===== FINDERS =====
local function findStrongholdChest()
    local items = workspace:FindFirstChild("Items")
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

local chestTried, strongholdTried = {}, {}
local function findUsableChest()
    local r = HRP(); if not r then return nil end
    local closest, dist
    local items = workspace:FindFirstChild("Items"); if not items then return nil end
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

-- ===== PROMPT HELPERS =====
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
        firePromptSafe(prompt)
        task.wait(0.3)
    end
    return not (prompt and prompt.Parent and prompt.Enabled)
end

local function waitDiamonds(timeout)
    local t0 = tick()
    while (tick()-t0) < (timeout or 2.0) do
        local items = workspace:FindChildOfClass("Folder")
        local ok = workspace:FindFirstChild("Items")
        if ok and ok:FindFirstChild("Diamond") then return true end
        task.wait(0.2)
    end
    return false
end

-- ===== AUTO JOIN / CREATE (Lobby) =====
local function autoJoinOrCreate()
    local joined = false
    for _, obj in ipairs(workspace:GetChildren()) do
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
        for _, obj in ipairs(workspace:GetChildren()) do
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

-- ======= ZERO-API BRUTE TELEPORT HOP =======
local function bruteTeleportOnce()
    if isTeleporting then return false end
    isTeleporting = true
    local before = g.JobId
    local ok, err = pcall(function()
        -- KHÔNG chọn instance → Roblox tự chọn public server (thường khác JobId)
        TeleportService:Teleport(Config.FarmPlaceId, LocalPlayer)
    end)
    task.delay(Config.BruteHop_PostVerifySec or 6.5, function()
        -- Nếu vẫn ở cùng JobId ⇒ coi là fail lần này
        if g.JobId == before then
            isTeleporting   = false
            ConsecutiveHopFail += 1
            LastHopFailAt   = os.clock()
        end
    end)
    if not ok then
        warn("[ZeroAPI] Teleport() error:", tostring(err))
        isTeleporting   = false
        ConsecutiveHopFail += 1
        LastHopFailAt   = os.clock()
        return false
    end
    return true
end

function Hop(reason)
    if isTeleporting then return end
    if not Config.ZeroAPIHopEnabled then Config.ZeroAPIHopEnabled = true end

    warn(("[Hop/ZeroAPI] %s"):format(tostring(reason or "")))

    if ConsecutiveHopFail >= (Config.MaxConsecutiveHopFail or 5) then
        local since = os.clock() - (LastHopFailAt or 0)
        local cool  = (Config.ConsecutiveHopCooloff or 6)
        if since < cool then task.wait(cool - since) end
        ConsecutiveHopFail = 0
    end

    local startJob = g.JobId
    local attempts = 0
    while attempts < (Config.BruteHop_MaxAttempts or 7) do
        attempts += 1
        bruteTeleportOnce()
        local t0 = os.clock()
        local waitSec = Config.BruteHop_PostVerifySec or 6.5
        while os.clock() - t0 < waitSec do
            if g.JobId ~= startJob then
                -- Đã rời phòng → đánh dấu visited + reset fail
                pcall(function() if g.JobId and g.JobId ~= "" then markVisited(g.JobId) end end)
                ConsecutiveHopFail = 0
                isTeleporting      = false
                touchLootClock()
                return
            end
            task.wait(0.25)
        end
        -- nếu chưa rời phòng, vòng lặp thử tiếp
    end

    -- vẫn chưa rời phòng sau N lần → nghỉ ngắn, thử lại
    isTeleporting = false
    task.wait(1 + math.random())
    pcall(function() Hop("retry-zeroapi") end)
end

-- Hop nhanh sau khi nhặt xong
local function HopFast(reason)
    if isTeleporting or HopRequested then return end
    HopRequested = true
    task.spawn(function()
        task.wait(Config.HopPostDelay)
        if not isTeleporting then Hop(reason or "fast") end
        HopRequested = false
    end)
end

-- Sự kiện Teleport lỗi → thử lại
pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(_, result, msg)
        warn("[ZeroAPI Hop] TeleportInitFailed:", tostring(result), msg or "")
        isTeleporting = false
        ConsecutiveHopFail += 1
        LastHopFailAt = os.clock()
        task.delay(0.5, function() Hop("init-failed") end)
    end)
end)

-- Tới server mới → mark visited, reset flag
pcall(function()
    TeleportService.LocalPlayerArrivedFromTeleport:Connect(function()
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


