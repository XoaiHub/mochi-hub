-- ================================================================
-- Mochi Farm (Luarmor-ready & Emulator-stable, no UI)
-- + Fast Hop After Collect
-- + Anti-DEAD + Skip Server Full + No-Rejoin-Same-Server
-- (Hardened for all executors / clients)
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
    DeadHopTimeout        = 6.0,
    DeadUiKeywords        = { "dead", "you died", "respawn", "revive" },

    -- [HARDEN] Ngắt hop spam nếu thất bại liên tục
    MaxConsecutiveHopFail = 5,
    ConsecutiveHopCooloff = 6.0, -- giây

    -- [HARDEN] Giới hạn tìm server / trang
    MaxPagesPrimary       = 8,
    MaxPagesFallback      = 12,

    -- [HARDEN] Delay tối đa khi Teleport ném lỗi
    TeleportFailBackoffMax = 8,
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

-- [HARDEN] HTTP getter tương thích đa executor (PC/emulator)
local function http_get(url)
    -- ưu tiên game:HttpGet (nhanh/đơn giản)
    local ok1, res1 = pcall(function() return g:HttpGet(url) end)
    if ok1 and type(res1) == "string" and #res1 > 0 then return res1 end

    -- fallback qua request() (synapse/krnl/fluxus…)
    local req = (syn and syn.request) or (http and http.request) or (request)
    if req then
        local ok2, res2 = pcall(function() return req({Url = url, Method = "GET"}) end)
        if ok2 and res2 and res2.Success and type(res2.Body) == "string" then
            return res2.Body
        end
    end
    return nil
end

-- ===== queue_on_teleport (nạp lại loader nếu cần) =====
local function queue_on_teleport_compat(code)
    local f = (syn and syn.queue_on_teleport)
          or  queue_on_teleport
          or  (fluxus and fluxus.queue_on_teleport)
          or  (KRNL_LOADED and queue_on_teleport)
    if f then pcall(f, code) end
end
-- ví dụ: queue_on_teleport_compat([[loadstring(game:HttpGet("https://yourdomain.com/Init.lua"))()]])

-- ===== FPS BOOST =====
do
    g.Lighting.GlobalShadows = false
    g.Lighting.Brightness = 0
    g.Lighting.FogEnd = 1e10
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
local PlaceID = g.PlaceId
local AllIDs, cursor, isTeleporting = {}, "", false
local strongholdTried, chestTried = {}, {}
local StrongholdCount, NormalChestCount = 0, 0
local BadIDs = {}
local LastAttemptSID = nil
local HopRequested = false

-- [HARDEN] đếm số lần hop fail liên tục để “hạ nhiệt”
local ConsecutiveHopFail = 0
local LastHopFailAt = 0

-- ===== DIAMOND HELPERS =====
local function diamondsLeft()
    -- [PERF] tránh GetDescendants full map mỗi tick
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
    return n
end

-- ===== FAST HOP =====
local function Hop(reason) end -- forward declare

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

-- =================================================================
-- ===== SERVER HOP (đÃ FIX: không dừng, không rejoin same server) ==
-- =================================================================
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

local SortAsc = false

local function resetHopState()
    AllIDs, cursor = {}, ""
    isTeleporting  = false
    LastAttemptSID = nil
end

-- [HARDEN] fetch server page với excludeFullGames=true & retry backoff
local function fetchServerPage(nextCursor, sortAsc)
    local sortOrder = sortAsc and "Asc" or "Desc"
    local base = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=%s&excludeFullGames=true&limit=100"):format(PlaceID, sortOrder)
    local cursorQ = (nextCursor ~= "" and ("&cursor="..nextCursor) or "")
    local tries, delay = 0, (Config.RetryHttpDelay or 2)
    while tries < 6 do
        tries += 1
        local url = base .. cursorQ .. "&_t=" .. HttpService:GenerateGUID(false)
        local body = http_get(url)
        if body then
            local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
            if ok and data and data.data then return data end
        end
        task.wait(delay)
        delay = math.min(delay * 1.6, Config.TeleportFailBackoffMax)
        if tries >= 2 then cursor = "" end          -- reset cursor sớm
        if tries == 4 then SortAsc = not SortAsc end-- đổi hướng quét
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

local function tryFindAndTeleport(maxPages)
    maxPages = maxPages or Config.MaxPagesPrimary
    local pagesTried = 0
    local localJob   = g.JobId

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
            -- excludeFullGames=true đã bật, nhưng vẫn tự check để chắc chắn
            if playing and maxp and playing < maxp then
                if sid ~= localJob
                   and not wasVisited(sid)
                   and not BadIDs[sid]
                   and not AllIDs[sid]
                   and regionMatch(v) then
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
                        ConsecutiveHopFail += 1
                        LastHopFailAt = os.clock()
                    else
                        ConsecutiveHopFail = 0
                    end
                    return true
                end
            else
                if sid then BadIDs[sid] = true end
            end
        end
    end

    -- Hết trang ⇒ đảo hướng & reset để mở phạm vi
    SortAsc = not SortAsc
    cursor  = ""
    return false
end

function Hop()
    if isTeleporting then return end

    -- [HARDEN] Nếu vừa fail nhiều lần, tạm “nghỉ” để tránh spam-hop
    if ConsecutiveHopFail >= Config.MaxConsecutiveHopFail then
        local since = os.clock() - LastHopFailAt
        if since < Config.ConsecutiveHopCooloff then
            task.wait(Config.ConsecutiveHopCooloff - since)
        end
        ConsecutiveHopFail = 0
    end

    -- nhẹ nhàng làm mới BadIDs nếu bão hoà
    local cnt=0 for _ in pairs(BadIDs) do cnt+=1 end
    if cnt > 200 then BadIDs = {} end

    local ok = tryFindAndTeleport(Config.MaxPagesPrimary)
    if not ok then
        ok = tryFindAndTeleport(Config.MaxPagesFallback)
        if not ok then
            AllIDs, cursor = {}, ""
            task.wait(1 + math.random())
        end
    end
end

-- Mark visited CHỈ khi teleport bắt đầu (tránh trừ slot oan)
LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Started then
        if LastAttemptSID then markVisited(LastAttemptSID) end
        resetHopState()
    end
end)

-- Nếu init fail → đánh dấu bad & gọi lại Hop
TeleportService.TeleportInitFailed:Connect(function(_, result, msg)
    warn("[Hop] TeleportInitFailed:", result, msg)
    if LastAttemptSID then BadIDs[LastAttemptSID] = true end
    isTeleporting = false
    ConsecutiveHopFail += 1
    LastHopFailAt = os.clock()
    task.defer(Hop)
end)

-- Khi đã tới server mới (2s) → đánh dấu JobId hiện tại để không quay lại
task.delay(2, function()
    pcall(function()
        if g.JobId and g.JobId ~= "" then markVisited(g.JobId) end
    end)
end)

-- Bảo hiểm: nếu executor không bắn OnTeleport, vẫn mark visited khi tới
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
    -- [PERF] chỉ quét trực tiếp children thay vì Descendants nặng
    for _, v in ipairs(items:GetChildren()) do
        if v:IsA("Model") and v.Name:find("Chest") and not v.Name:find("Snow") then
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
    -- [HARDEN] Một số executor không có fireproximityprompt
    if typeof(fireproximityprompt) == "function" then
        pcall(function() fireproximityprompt(prompt, 1) end)
    else
        -- Fallback: thử kích Humanoid Interact (ít game hỗ trợ)
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and prompt and prompt.HoldDuration == 0 then
                -- nhảy vào hitbox prompt
                hum:MoveTo(prompt.Parent and prompt.Parent.Position or HRP().Position)
            end
        end)
    end
end

local function pressPromptWithTimeout(prompt, timeout)
    local t0 = tick()
    while prompt and prompt.Parent and prompt.Enabled and (tick()-t0) < (timeout or 6) do
        firePromptSafe(prompt) -- [FIX] dùng wrapper an toàn
        task.wait(0.3)
    end
    return not (prompt and prompt.Parent and prompt.Enabled)
end

local function waitDiamonds(timeout)
    local t0 = tick()
    while (tick()-t0) < (timeout or 2.0) do
        local items = workspace:FindFirstChild("Items")
        if items and items:FindFirstChild("Diamond") then return true end
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

-- ===== ANTI-DEAD =====
local IsDead = false
local DeadSince = 0

local function hasDeadUi()
    local pg = LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return false end
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
            local prox = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
            local t0   = os.clock()
            local okOpen = false
            while prox and prox.Parent and prox.Enabled and (os.clock() - t0) < 10 do
                tpCFrame(CFrame.new(chest:GetPivot().Position))
                firePromptSafe(prox) -- [FIX] wrapper
                task.wait(0.45)
                prox = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
            end
            if not (prox and prox.Parent and prox.Enabled) then okOpen = true end
            if okOpen then
                NormalChestCount += 1
                collectAllDiamonds()
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
        if g.PlaceId == Config.FarmPlaceId then collectAllDiamonds() end
    end
end)
