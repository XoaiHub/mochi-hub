-- ================================================================
-- Mochi Farm (Luarmor-ready & Emulator-stable, no UI)
-- + Fast Hop After Collect
-- + Anti-DEAD + Skip Server Full + No-Rejoin-Same-Server
-- + Watchdog chống đứng (idle) + Quét nhiều trang Asc/Desc
-- + Fix 404/522/429 server list + Prompt-safe + FPSBoost an toàn
-- ================================================================

-- ===== CONFIG =====
local Config = {
    RegionFilterEnabled   = false,
    RegionList            = { "singapore", "tokyo", "us-east" },
    RetryHttpDelay        = 2,

    StrongholdChestName   = "Stronghold Diamond Chest",
    StrongholdPromptTime  = 6,
    StrongholdDiamondWait = 10,

    FarmPlaceId           = 126509999114328, -- map farm
    LobbyCheckInterval    = 2.0,
    FarmTick              = 1.0,
    DiamondTick           = 0.35,
    HopBackoffMin         = 1.5,
    HopBackoffMax         = 3.0,

    -- Fast hop ngay sau khi nhặt xong
    HopAfterStronghold    = true,
    HopAfterNormalChest   = true,
    HopPostDelay          = 0.20,

    -- Anti-DEAD
    DeadHopTimeout        = 6.0,   -- đứng DEAD quá thời gian này -> hop
    DeadUiKeywords        = { "dead", "you died", "respawn", "revive" }, -- chữ trên HUD
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

local function rand(a,b) return a + (b-a)*math.random() end

-- ===== queue_on_teleport (nạp lại loader nếu cần) =====
local function queue_on_teleport_compat(code)
    local f = (syn and syn.queue_on_teleport)
          or  queue_on_teleport
          or  (fluxus and fluxus.queue_on_teleport)
          or  (KRNL_LOADED and queue_on_teleport)
    if f then pcall(f, code) end
end
-- ví dụ: queue_on_teleport_compat([[loadstring(game:HttpGet("https://yourdomain.com/Init.lua"))()]])

-- ===== FPS BOOST (an toàn) =====
do
    local Lighting = g.Lighting
    Lighting.GlobalShadows = false
    Lighting.Brightness = 0
    Lighting.FogEnd = 1e10
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)

    local function optimize(v)
        -- Không đụng PlayerGui/PlayerScripts để tránh phá UI/logic của game
        if Players.LocalPlayer then
            local PG = Players.LocalPlayer:FindFirstChild("PlayerGui")
            local PS = Players.LocalPlayer:FindFirstChild("PlayerScripts")
            if (PG and v:IsDescendantOf(PG)) or (PS and v:IsDescendantOf(PS)) then return end
        end
        -- Chỉ tắt hiệu ứng nặng, không destroy mesh/skin
        if v:IsA("BasePart") or v:IsA("MeshPart") then
            v.Material = Enum.Material.Plastic
            v.Reflectance = 0
            v.CastShadow  = false
        elseif v:IsA("Decal") or v:IsA("Texture") then
            v.Transparency = 1
        elseif v:IsA("Fire") or v:IsA("SpotLight") or v:IsA("Smoke") or v:IsA("Sparkles") or v:IsA("ParticleEmitter") then
            v.Enabled = false
        end
    end

    task.spawn(function()
        for _, v in ipairs(g:GetDescendants()) do optimize(v); task.wait(0.0005) end
    end)
    g.DescendantAdded:Connect(optimize)
end

-- ===== STATE =====
local PlaceID = g.PlaceId
local AllIDs, cursor, isTeleporting = {}, "", false
local strongholdTried, chestTried = {}, {}
local StrongholdCount, NormalChestCount = 0, 0
local BadIDs = {}
local LastAttemptSID = nil
local SortAsc = false

-- ===== TOUCH ALIVE / WATCHDOG =====
local LastActive = tick()
local function touchAlive() LastActive = tick() end

-- ===== DIAMOND HELPERS =====
local function diamondsLeft()
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.ClassName == "Model" and v.Name == "Diamond" then return true end
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
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.ClassName == "Model" and v.Name == "Diamond" then
            pcall(function() RS.RemoteEvents.RequestTakeDiamonds:FireServer(v) end)
            n += 1
        end
    end
    if n > 0 then touchAlive() end
    return n
end

-- ===== PROMPT HELPERS (chống nil) =====
local function promptAlive(p)
    return p and p.Parent and p.Enabled and p:IsDescendantOf(workspace)
end

local function pressPromptWithTimeout(prompt, timeout)
    local t0 = tick()
    while promptAlive(prompt) and (tick()-t0) < (timeout or 6) do
        pcall(function()
            if promptAlive(prompt) then fireproximityprompt(prompt, 1) end
        end)
        task.wait(0.55)
    end
    return not promptAlive(prompt)
end

-- ===== HOP (forward declare) =====
local HopRequested = false
local function Hop(reason) end

local function HopFast(reason)
    if isTeleporting or HopRequested then return end
    if getgenv and getgenv().PauseHop then
        local t0 = os.clock()
        while getgenv().PauseHop and os.clock()-t0 < 10 do task.wait(0.25) end
    end
    HopRequested = true
    task.spawn(function()
        task.wait(Config.HopPostDelay)
        if not isTeleporting then
            warn("[HopFast]", tostring(reason or ""))
            pcall(function() _G._force_hop = true end)
            Hop("fast")
        end
        HopRequested = false
    end)
end

-- ===== SERVER HOP (no rejoin same server, anti-dead-hop, anti-stall) =====
do
    getgenv().VisitedServers = getgenv().VisitedServers or { hour = -1, ids = {} }
end
local function nowHourUTC() return os.date("!*t").hour end
local function rotateVisitedIfHourChanged()
    local h = nowHourUTC()
    if getgenv().VisitedServers.hour ~= h then
        getgenv().VisitedServers.hour = h
        getgenv().VisitedServers.ids  = {}
    end
end
local function wasVisited(sid) rotateVisitedIfHourChanged(); return getgenv().VisitedServers.ids[sid] == true end
local function markVisited(sid) rotateVisitedIfHourChanged(); getgenv().VisitedServers.ids[sid] = true end

local function resetState()
    AllIDs, cursor = {}, ""
    isTeleporting = false
    LastAttemptSID = nil
end

local function dictCount(t) local c=0; for _ in pairs(t) do c+=1 end; return c end

-- fetchServerPage: backoff + cache-bust + đổi hướng
local function fetchServerPage(nextCursor, sortAsc)
    local sortOrder = sortAsc and "Asc" or "Desc"
    local base = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=%s&excludeFullGames=true&limit=100"):format(PlaceID, sortOrder)
    local cursorQ = (nextCursor ~= "" and ("&cursor="..nextCursor) or "")
    local tries, delay = 0, (Config.RetryHttpDelay or 2)
    while tries < 6 do
        tries += 1
        local url = base .. cursorQ .. "&_t=" .. HttpService:GenerateGUID(false)
        local ok, data = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url))
        end)
        if ok and data and data.data then
            return data
        end
        task.wait(delay)
        delay = math.min(delay * 1.6, 8)
        if tries % 2 == 0 then SortAsc = not SortAsc end
        if tries >= 4 then cursor = "" end
    end
    return nil
end

local function regionMatch(entry)
    if not Config.RegionFilterEnabled then return true end
    local raw = tostring(entry.region or entry.ping or ""):lower()
    for _, key in ipairs(Config.RegionList) do
        if raw:find(tostring(key):lower(), 1, true) then return true end
    end
    return false
end

-- Mark visited khi bắt đầu teleport + fallback state changed
Players.LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Started then
        if LastAttemptSID then markVisited(LastAttemptSID) end
        resetState()
    end
end)
pcall(function()
    TeleportService.TeleportStateChanged:Connect(function(player, state, _)
        if player == LocalPlayer and state == Enum.TeleportState.Started then
            if LastAttemptSID then markVisited(LastAttemptSID) end
            resetState()
        end
    end)
end)

TeleportService.TeleportInitFailed:Connect(function(_, teleportResult, msg)
    warn("[Hop] TeleportInitFailed:", teleportResult, msg)
    if LastAttemptSID then BadIDs[LastAttemptSID] = true end
    isTeleporting = false
    task.delay(0.75, function()
        if not isTeleporting then Hop("retry-after-fail") end
    end)
end)

-- sau khi đến server mới: đánh dấu JobId hiện tại
task.delay(2.0, function()
    pcall(function()
        if g.JobId and g.JobId ~= "" then markVisited(g.JobId) end
    end)
end)

-- queue_on_teleport: đảm bảo visited tồn tại ở server mới (tùy chọn nạp loader)
queue_on_teleport_compat([[
    task.wait(1.0)
    pcall(function()
        getgenv().VisitedServers = getgenv().VisitedServers or { hour = -1, ids = {} }
        local h = os.date("!*t").hour
        if getgenv().VisitedServers.hour ~= h then
            getgenv().VisitedServers.hour = h
            getgenv().VisitedServers.ids = {}
        end
        if game.JobId and game.JobId ~= "" then
            getgenv().VisitedServers.ids[game.JobId] = true
        end
    end)
    -- loadstring(game:HttpGet("https://your-cdn/Init.lua"))()
]])

local function tryFindAndTeleport(maxPages)
    maxPages = maxPages or 6
    local pagesTried = 0
    local localJob = g.JobId

    while pagesTried < maxPages do
        local page = fetchServerPage(cursor, SortAsc)
        if not page or not page.data then
            cursor = ""
            pagesTried += 1
            continue
        end

        cursor = page.nextPageCursor or ""
        pagesTried += 1

        for _, v in ipairs(page.data) do
            local sid     = tostring(v.id)
            local playing = tonumber(v.playing)
            local maxp    = tonumber(v.maxPlayers)
            if playing and maxp and playing < maxp then
                if sid ~= localJob
                   and not wasVisited(sid)
                   and not BadIDs[sid]
                   and not AllIDs[sid]
                   and regionMatch(v)
                then
                    AllIDs[sid]    = true
                    isTeleporting  = true
                    LastAttemptSID = sid

                    task.wait(rand(Config.HopBackoffMin, Config.HopBackoffMax))
                    local ok, err = pcall(function()
                        TeleportService:TeleportToPlaceInstance(PlaceID, sid, LocalPlayer)
                    end)
                    if not ok then
                        warn("[Hop] Teleport error:", err)
                        isTeleporting  = false
                        BadIDs[sid]    = true
                    end
                    return true
                end
            else
                if sid then BadIDs[sid] = true end
            end
        end
    end

    -- Không tìm được server phù hợp sau nhiều trang ⇒ đảo thứ tự, reset cursor
    SortAsc = not SortAsc
    cursor  = ""
    return false
end

function Hop(reason)
    if isTeleporting then return end
    local hrp = (LocalPlayer.Character or {}).HumanoidRootPart
    if not hrp then
        local t0 = os.clock()
        while (not ((LocalPlayer.Character or {}).HumanoidRootPart)) and os.clock()-t0 < 8 do task.wait(0.25) end
    end

    -- nếu BAD bị bão hoà (quá nhiều), làm mới nhẹ
    if dictCount(BadIDs) > 200 then
        BadIDs = {}
    end

    local ok = tryFindAndTeleport(8)
    if not ok then
        ok = tryFindAndTeleport(12)
        if not ok then
            AllIDs, cursor = {}, ""
            task.wait(1.0 + math.random())
        end
    end
end

-- Watchdog chống đứng: nếu ở map farm quá lâu không có hoạt động => hop
task.spawn(function()
    local IdleHopTimeout = math.max(12, (Config.DeadHopTimeout or 6) * 2)  -- mặc định ~12s+
    while task.wait(2.0) do
        if g.PlaceId ~= Config.FarmPlaceId then
            touchAlive()
        else
            if (tick() - LastActive) > IdleHopTimeout and not isTeleporting then
                warn("[Hop] Idle too long -> hop")
                Hop("idle-watchdog")
                touchAlive()
            end
        end
    end
end)

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

local function findUsableChest()
    local r = HRP(); if not r then return nil end
    local closest, dist
    local items = workspace:FindFirstChild("Items"); if not items then return nil end
    for _, v in pairs(items:GetDescendants()) do
        if v:IsA("Model") and v.Name:find("Chest") and not v.Name:find("Snow") then
            local id = v:GetDebugId()
            if not chestTried[id] then
                local prox = v:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prox and prox.Enabled then
                    local d = (r.Position - v:GetPivot().Position).Magnitude
                    if not dist or d < dist then closest, dist = v, d end
                end
            end
        end
    end
    return closest
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

-- ===== ANTI-DEAD (phát hiện & hop) =====
local IsDead, DeadSince = false, 0

local function hasDeadUi()
    local pg = LocalPlayer:FindChild("PlayerGui") or LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end
    local lower = string.lower
    for _, gui in ipairs(pg:GetDescendants()) do
        if gui:IsA("TextLabel") or gui:IsA("TextButton") then
            local t = tostring(gui.Text or "")
            t = t:gsub("%s+", " ")
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
            touchAlive()
        end
    end
end)

-- ===== MAIN FARM =====
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
                            touchAlive()
                            waitNoDiamonds(1.1)
                            StrongholdCount += 1
                            if Config.HopAfterStronghold then HopFast("after-stronghold-collect") end
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
            local okOpen = false
            local deadline = os.clock() + 10
            while os.clock() < deadline do
                local prox = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
                if not promptAlive(prox) then break end
                tpCFrame(CFrame.new(chest:GetPivot().Position))
                pcall(function() if promptAlive(prox) then fireproximityprompt(prox, 1) end end)
                task.wait(0.6)
                if not promptAlive(prox) then okOpen = true break end
            end
            if okOpen then
                NormalChestCount += 1
                collectAllDiamonds()
                touchAlive()
                waitNoDiamonds(1.0)
                if Config.HopAfterNormalChest then HopFast("after-normalchest-collect") end
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
            local c = collectAllDiamonds()
            if c > 0 then touchAlive() end
        end
    end
end)
