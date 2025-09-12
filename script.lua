-- ================================================================
-- Mochi Farm (Luarmor-ready & Emulator-stable, no UI)
-- + Fast Hop After Collect (CHỈ sau khi đã NHẶT gems)
-- + Anti-DEAD + Skip Server Full + No-Rejoin-Same-Server
-- + Guard: chỉ hop khi đã vào map farm (không hop ở lobby)
-- + Hop V2.4 Hotfix: cấm lặp server, phá cache API, xáo host, bỏ rejoin cũ
-- + Emulator polish: tối ưu đồ hoạ/mesh; anti-void sau TP
-- + Re-exec safe: không double loop
-- ================================================================

-- ===== CONFIG =====
local Config = {
    RegionFilterEnabled     = false,
    RegionList              = { "singapore", "tokyo", "us-east" },

    RetryHttpDelay          = 2,

    StrongholdChestName     = "Stronghold Diamond Chest",
    StrongholdPromptTime    = 6,
    StrongholdDiamondWait   = 10,

    FarmPlaceId             = 126509999114328, -- MAP FARM
    LobbyCheckInterval      = 2.0,
    FarmTick                = 1.0,
    DiamondTick             = 0.30,   -- hút nhanh hơn

    HopBackoffMin           = 1.1,
    HopBackoffMax           = 2.4,
    HopPostDelay            = 0.18,

    DeadHopTimeout          = 6.0,
    DeadUiKeywords          = { "dead", "you died", "respawn", "revive" },

    MinStayAfterJoin        = 8.0,
    MinStayAfterFirstGem    = 5.0,
    RequirePickupBeforeHop  = true,

    NoGemsGrace             = 10.0,
    NoChestScanWindow       = 15.0,

    FarmHoldAfterSpawn      = 2.3,
    FarmDrainHold           = 1.8,
    HopOnlyIfCollected      = true,

    HopAfterStronghold      = true,
    HopAfterNormalChest     = true,
}

-- ===== SERVICES =====
local g               = game
local Players         = g:GetService("Players")
local LocalPlayer     = Players.LocalPlayer
local RS              = g:GetService("ReplicatedStorage")
local RunService      = g:GetService("RunService")
local HttpService     = g:GetService("HttpService")
local TeleportService = g:GetService("TeleportService")

-- ===== RE-EXEC SAFE BOOT =====
local ENV = getgenv()
ENV.MOCHI = ENV.MOCHI or {}
pcall(function() if ENV.MOCHI.kill then ENV.MOCHI.kill() end end)
ENV.MOCHI._cons, ENV.MOCHI._loops = {}, {}
ENV.MOCHI._ver = "hop-v2.4-hotfix"

local function dprint(...) print("[Mochi]", ...) end
local function wprint(...) warn("[Mochi]", ...) end

local function bindConn(c) if c then table.insert(ENV.MOCHI._cons, c) end end
local function bindLoop(id, fn, interval)
    interval = interval or 0.05
    local alive = true
    ENV.MOCHI._loops[id] = function() alive = false end
    task.spawn(function()
        while alive do
            local ok, err = pcall(fn)
            if not ok then warn("[Loop "..id.."]", err) end
            task.wait(interval)
        end
    end)
end
ENV.MOCHI.kill = function()
    for _,c in ipairs(ENV.MOCHI._cons) do pcall(function() c:Disconnect() end) end
    for _,stop in pairs(ENV.MOCHI._loops) do pcall(stop) end
    ENV.MOCHI._cons, ENV.MOCHI._loops = {}, {}
end

-- ===== UTILS =====
local function HRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function WaitForChar(timeout)
    timeout = timeout or 20
    local t = 0
    while t < timeout do
        local c = LocalPlayer.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        local hrp = HRP()
        if c and hum and hrp and hum.Health > 0 then return c end
        t = t + 0.25
        task.wait(0.25)
    end
    return LocalPlayer.Character
end

local function rand(a,b) return a + (b-a)*math.random() end

local function http_get(url)
    -- cache-busting
    local salt = tostring(math.random(1,1e9))
    local full = url .. (url:find("%?") and "&" or "?") .. "cbust=" .. HttpService:UrlEncode(salt) .. "&_t=" .. tostring(os.time())
    local ok1, res1 = pcall(function() return g:HttpGet(full) end)
    if ok1 and type(res1) == "string" and #res1 > 0 then return res1 end
    local req = (syn and syn.request) or (http and http.request) or request or rawget(getfenv(), "http_request")
    if req then
        local ok2, res2 = pcall(function() return req({Url = full, Method = "GET"}) end)
        if ok2 and res2 and (res2.StatusCode == 200 or res2.Success) and type(res2.Body) == "string" and #res2.Body > 0 then
            return res2.Body
        end
    end
    return nil
end

local function queue_on_teleport_compat(code)
    local f = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport) or (KRNL_LOADED and queue_on_teleport)
    if f then pcall(f, code) end
end

-- ===== FPS BOOST =====
do
    g.Lighting.GlobalShadows = false
    g.Lighting.Brightness = 0
    g.Lighting.FogEnd = 1e10
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        settings().Network.IncomingReplicationLag = 0
    end)
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
    bindConn(g.DescendantAdded:Connect(optimize))
end

-- ===== STATE =====
local strongholdTried, chestTried = {}, {}
local StrongholdCount, NormalChestCount = 0, 0
local Server = { joinedAt=tick(), firstGemAt=nil, collectedCount=0, lastTeleportAt=0 }
local function _onServerEnter()
    Server.joinedAt = tick()
    Server.firstGemAt = nil
    Server.collectedCount = 0
end

-- ===== FARM GUARD =====
getgenv().AllowHop = false
local function inFarm() return g.PlaceId == (Config and Config.FarmPlaceId or g.PlaceId) end
bindLoop("allow-hop-watch", function() getgenv().AllowHop = inFarm() end, 0.5)

-- ===== VISITED + BANLIST (NO REPEAT) =====
repeat task.wait() until g:IsLoaded()

getgenv().VisitedServers = getgenv().VisitedServers or {
    hour = -1,
    ids  = {},      -- [jobId] = last_seen_unix
    ttl  = 21600,   -- 6 giờ
    min_free_slots = 2,
    _clean_counter = 0,
}
getgenv().BanServers = getgenv().BanServers or {
    ids = {},       -- [jobId] = last_banned_unix
    ttl = 10800,    -- 3 giờ
}
local G   = getgenv().VisitedServers
local BAN = getgenv().BanServers

local function now() return os.time() end
local function rotateHour()
    local h = os.date("!*t").hour
    if G.hour ~= h then
        G.hour = h
        local n = now()
        for id, ts in pairs(G.ids) do
            if (n - (ts or 0)) > (G.ttl or 21600) then G.ids[id] = nil end
        end
        for id, ts in pairs(BAN.ids) do
            if (n - (ts or 0)) > (BAN.ttl or 10800) then BAN.ids[id] = nil end
        end
    end
end
local function markVisitedGlobal(id)
    if not id or id == "" then return end
    rotateHour(); G.ids[id] = now()
end
local function banServer(id)
    if not id or id == "" then return end
    BAN.ids[id] = now()
end
local function isBanned(id)
    if not id or id == "" then return true end
    rotateHour()
    local ts = BAN.ids[id]
    if ts and (now() - ts) <= (BAN.ttl or 10800) then return true end
    return false
end
local function notVisited(id)
    if not id or id == "" then return false end
    if id == g.JobId then return false end
    rotateHour()
    local ts = G.ids[id]
    if ts and (now() - ts) <= (G.ttl or 21600) then return false end
    return true
end

-- Mirrors
local HOSTS = {
    "https://games.roblox.com",
    "https://games.roproxy.com",
    "https://apis.roproxy.com",
    "https://games.rbxcdn.xyz"
}

local function vacancy(sv)
    local maxp   = tonumber(sv.maxPlayers or sv.maxPlayerCount or 0) or 0
    local play   = tonumber(sv.playing    or sv.playerCount    or 0) or 0
    return math.max(0, maxp - play), play, maxp
end

local function regionMatch(entry)
    if not Config.RegionFilterEnabled then return true end
    local raw = tostring(entry.region or entry.ping or ""):lower()
    for _, key in ipairs(Config.RegionList or {}) do
        if raw:find(tostring(key):lower(), 1, true) then return true end
    end
    return false
end

local function pickServer(placeId)
    local minFree = math.max(G.min_free_slots or 2, 1)
    local candidates, cursor = {}, nil

    for page = 1, 16 do
        -- shuffle hosts
        local shuffled = {table.unpack(HOSTS)}
        for i = #shuffled, 2, -1 do
            local j = math.random(1, i)
            shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
        end

        local gotPage = false
        for _,host in ipairs(shuffled) do
            local url = ("%s/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(host, placeId)
            if cursor then url = url .. "&cursor=" .. HttpService:UrlEncode(cursor) end
            local body = http_get(url)
            if body then
                local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
                local json = ok and data or nil
                if json and type(json.data) == "table" then
                    for _,sv in ipairs(json.data) do
                        local id = sv.id or sv.Id or sv.jobId
                        local free, playing, maxp = vacancy(sv)
                        if id
                           and notVisited(id)
                           and (not isBanned(id))
                           and free >= minFree
                           and playing >= 0 and playing <= math.max(0,(maxp-2))
                           and regionMatch(sv) then
                            table.insert(candidates, { id=id, free=free, playing=playing, maxp=maxp })
                        end
                    end
                    cursor, gotPage = json.nextPageCursor, true
                    break
                end
            end
            task.wait(0.08)
        end
        if not cursor or not gotPage then break end
        task.wait(0.06)
    end

    if #candidates == 0 then
        G._clean_counter = (G._clean_counter or 0) + 1
        if G._clean_counter % 2 == 0 then
            local oldest = {}
            for id, ts in pairs(G.ids) do table.insert(oldest, {id=id, ts=ts or 0}) end
            table.sort(oldest, function(a,b) return a.ts < b.ts end)
            local cut = math.max(1, math.floor(#oldest * 0.15))
            for i=1,math.min(cut, #oldest) do
                if oldest[i].id ~= g.JobId then G.ids[oldest[i].id] = nil end
            end
            wprint("pickServer cleaned", math.min(cut, #oldest), "visited entries")
        end
    end

    table.sort(candidates, function(a,b)
        if a.free ~= b.free       then return a.free > b.free end
        if a.playing ~= b.playing then return a.playing < b.playing end
        return a.id < b.id
    end)

    local n = math.min(#candidates, 6)
    if n >= 1 then
        local i = math.random(1, n)
        return candidates[i]
    end
    return nil
end

-- ===== PROXIMITY PROMPT HELPER =====
local function pressPromptWithTimeout(prox, holdSeconds)
    if not prox or not prox.Parent then return false end
    local t0, ok = tick(), false
    holdSeconds = holdSeconds or 3
    while prox and prox.Parent and prox.Enabled and (tick()-t0) <= holdSeconds do
        if typeof(fireproximityprompt) == "function" then
            pcall(function() fireproximityprompt(prox, 1) end)
        else
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and prox.HoldDuration == 0 then
                local p = prox.Parent and (prox.Parent.Position or prox.Parent.CFrame.Position)
                if p then hum:MoveTo(p) end
            end
        end
        task.wait(0.25)
        if not prox.Enabled then ok = true; break end
    end
    return ok or (prox and not prox.Enabled)
end

-- ===== Teleport + Debounce =====
local STATE = { BusyTeleport=false, LastHopAt=0, HopCooldown=2.0, _bound=false }

local function antiVoidPad()
    local r = HRP()
    if not r then return end
    if r.Position.Y < -20 then
        r.CFrame = CFrame.new(r.Position.X, 30, r.Position.Z)
    end
end

local function bindTP()
    if STATE._bound then return end
    STATE._bound = true
    bindConn(TeleportService.TeleportInitFailed:Connect(function(_, result, msg)
        local r = tostring(result or "")
        if r:find("GameFull") or (msg and msg:lower():find("requested experience is full")) then
            G.min_free_slots = math.min((G.min_free_slots or 2) + 1, 3)
            task.delay(60, function() G.min_free_slots = 2 end)
        end
        task.wait(1.0); STATE.BusyTeleport=false
    end))
    bindConn(LocalPlayer.OnTeleport:Connect(function(st)
        if st==Enum.TeleportState.Started then
            getgenv().AllowHop = false
        end
        if st==Enum.TeleportState.Failed or st==Enum.TeleportState.Cancelled then
            task.wait(1.0); STATE.BusyTeleport=false
        end
    end))
end

local function randomTeleportAvoidCurrent(maxRetry)
    maxRetry = maxRetry or 3
    if STATE.BusyTeleport then return false end
    if tick() - (STATE.LastHopAt or 0) < (STATE.HopCooldown or 2.0) then return false end
    STATE.BusyTeleport = true; bindTP(); STATE.LastHopAt = tick()

    local prev = g.JobId
    local ok = pcall(function() TeleportService:Teleport(g.PlaceId, LocalPlayer) end)
    if not ok then STATE.BusyTeleport=false return false end

    task.delay(6, function()
        pcall(function()
            if g.JobId == prev then
                banServer(prev)
                local pick = pickServer(g.PlaceId)
                if pick and pick.id and pick.id ~= prev then
                    local TeleportOptions = Instance.new("TeleportOptions")
                    TeleportOptions.ServerInstanceId = pick.id
                    pcall(function() TeleportService:TeleportAsync(g.PlaceId, { LocalPlayer }, TeleportOptions) end)
                end
            end
        end)
        STATE.BusyTeleport=false
    end)
    return true
end

local function tpToJob(jobId)
    if not jobId or jobId=="" or STATE.BusyTeleport then return false end
    if jobId == g.JobId then return false end
    if tick() - (STATE.LastHopAt or 0) < (STATE.HopCooldown or 2.0) then return false end
    STATE.BusyTeleport = true; bindTP(); STATE.LastHopAt = tick()

    banServer(g.JobId)
    markVisitedGlobal(g.JobId)

    local ok = pcall(function()
        local TeleportOptions = Instance.new("TeleportOptions")
        TeleportOptions.ServerInstanceId = jobId
        TeleportService:TeleportAsync(g.PlaceId, { LocalPlayer }, TeleportOptions)
    end)
    if not ok then
        banServer(jobId)
        task.wait(1.0); STATE.BusyTeleport=false
        return randomTeleportAvoidCurrent(2)
    end
    task.delay(12, function() STATE.BusyTeleport=false end)
    return true
end

-- Stay windows / Guard
local function canHopNow(bypass)
    if not getgenv().AllowHop then return false, "not-in-farm" end
    if bypass == true then return true, "bypass" end
    local aliveFor = tick() - (Server.joinedAt or 0)
    if aliveFor < (Config.MinStayAfterJoin or 0) then
        return false, "min-stay-after-join"
    end
    if Config.RequirePickupBeforeHop then
        if (Server.collectedCount or 0) <= 0 then
            return false, "no-pickup-yet"
        end
        if Server.firstGemAt and (tick() - Server.firstGemAt) < (Config.MinStayAfterFirstGem or 0) then
            return false, "min-stay-after-first-gem"
        end
    end
    return true, "ok"
end

-- ===== PUBLIC HOP API =====
local function _HopInternal()
    task.wait(rand(Config.HopBackoffMin, Config.HopBackoffMax))
    local pick = pickServer(g.PlaceId)
    if pick and pick.id and pick.id ~= g.JobId then
        if tpToJob(pick.id) then return end
    end
    randomTeleportAvoidCurrent(2)
end

function Hop(reason, bypass)
    if not getgenv().AllowHop then
        wprint("Hop blocked (not in farm):", tostring(reason or "")); return
    end
    local ok, why = canHopNow(bypass)
    if not ok then wprint("Hop delay:", why); return end
    if STATE.BusyTeleport then return end
    dprint("Hop reason:", tostring(reason or ""))
    task.spawn(_HopInternal)
end

function HopFast(reason, bypass)
    if not getgenv().AllowHop then
        wprint("HopFast blocked (not in farm):", tostring(reason or "")); return
    end
    local ok, why = canHopNow(bypass)
    if not ok then wprint("HopFast delay:", why); return end
    task.spawn(function()
        task.wait(Config.HopPostDelay or 0.18)
        pcall(function() _G._force_hop = true end)
        dprint("HopFast reason:", tostring(reason or ""))
        _HopInternal()
    end)
end

-- Mark job hiện tại + reset session
task.delay(2, function()
    pcall(function()
        if g.JobId and g.JobId ~= "" then
            markVisitedGlobal(g.JobId)
            banServer(g.JobId)
        end
        _onServerEnter()
        if inFarm() then getgenv().AllowHop = true end
    end)
end)

-- ===== WORLD HELPERS & FARM CORE =====
local function tpCFrame(cf) local r = HRP(); if r then r.CFrame = cf end end
local function worldPos(obj)
    if not obj then return (HRP() and HRP().Position) or Vector3.new() end
    local ok, pos = pcall(function()
        if obj:IsA("BasePart") then return obj.Position end
        if obj.GetPivot then return obj:GetPivot().Position end
        if obj.PrimaryPart then return obj.PrimaryPart.Position end
        return obj.Position
    end)
    return ok and pos or ((HRP() and HRP().Position) or Vector3.new())
end

-- Diamonds
local function diamondsLeft()
    local items = workspace:FindFirstChild("Items")
    if not items then return false end
    for _, v in ipairs(items:GetChildren()) do
        if v.Name == "Diamond" then return true end
    end
    return false
end

local function waitDiamonds(timeout)
    local t0 = tick()
    while (tick()-t0) < (timeout or 2.0) do
        local items = workspace:FindFirstChild("Items")
        if items and items:FindFirstChild("Diamond") then return true end
        task.wait(0.18)
    end
    return false
end

local function collectAllDiamonds()
    local n = 0
    local items = workspace:FindFirstChild("Items")
    if not items then return 0 end
    local r = HRP(); local rpos = r and r.Position
    for _, v in ipairs(items:GetChildren()) do
        if v.Name == "Diamond" then
            local ok = pcall(function()
                local ev = RS:FindFirstChild("RemoteEvents")
                local re = ev and ev:FindFirstChild("RequestTakeDiamonds")
                if re and re.FireServer then
                    if rpos then
                        local dp = worldPos(v)
                        if (rpos - dp).Magnitude > 120 then
                            tpCFrame(CFrame.new(dp + Vector3.new(0,3,0)))
                            task.wait(0.04)
                        end
                    end
                    re:FireServer(v)
                end
            end)
            if ok then n = n + 1 end
        end
    end
    if n > 0 then
        Server.collectedCount = (Server.collectedCount or 0) + n
        if not Server.firstGemAt then Server.firstGemAt = tick() end
    end
    return n
end

local function harvestDrain(drainHold)
    drainHold = drainHold or (Config.FarmDrainHold or 1.8)
    local noneSince, total = nil, 0
    while true do
        local got = collectAllDiamonds()
        total = total + got
        if got == 0 then
            local items = workspace:FindFirstChild("Items")
            if items then
                local r = HRP()
                local near, nd, rpos = nil, 1e9, (r and r.Position) or Vector3.new()
                for _, v in ipairs(items:GetChildren()) do
                    if v.Name == "Diamond" then
                        local p = worldPos(v); local d = (p - rpos).Magnitude
                        if d < nd then near, nd = v, d end
                    end
                end
                if near and nd > 70 and r then
                    tpCFrame(CFrame.new(worldPos(near) + Vector3.new(0,3,0)))
                    task.wait(0.12)
                    got = collectAllDiamonds(); total = total + got
                end
            end
        end
        local has = diamondsLeft()
        if not has then
            if not noneSince then noneSince = tick() end
            if tick() - noneSince >= drainHold then break end
        else
            noneSince = nil
        end
        task.wait(0.18)
    end
    return total
end

-- FINDERS
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

local function hasOpenableChest()
    local items = workspace:FindFirstChild("Items"); if not items then return false end
    for _, v in ipairs(items:GetChildren()) do
        if v:IsA("Model") and v.Name:find("Chest") and not v.Name:find("Snow") then
            local prox = v:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prox and prox.Enabled then return true end
        end
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

bindLoop("lobby-join", function()
    if g.PlaceId ~= Config.FarmPlaceId then pcall(autoJoinOrCreate) end
end, Config.LobbyCheckInterval or 2.0)

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
    bindConn(hum.Died:Connect(function()
        IsDead = true
        DeadSince = tick()
    end))
end

if LocalPlayer.Character then bindDeathWatcher(LocalPlayer.Character) end
bindConn(LocalPlayer.CharacterAdded:Connect(function(c)
    IsDead, DeadSince = false, 0
    task.wait(0.5)
    bindDeathWatcher(c)
end))

bindLoop("anti-dead", function()
    if g.PlaceId ~= Config.FarmPlaceId then return end
    if not IsDead and not hasDeadUi() then return end
    if DeadSince == 0 then DeadSince = tick() end
    if tick() - DeadSince >= Config.DeadHopTimeout then
        HopFast("anti-dead", true)
    end
end, 0.5)

-- ===== MAIN FARM =====
bindLoop("farm", function()
    if g.PlaceId ~= Config.FarmPlaceId then task.wait(Config.FarmTick) return end
    WaitForChar()
    antiVoidPad()

    -- Stronghold
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
                    if waitDiamonds(Config.FarmHoldAfterSpawn or 2.3) then
                        local before = Server.collectedCount or 0
                        local got    = harvestDrain(Config.FarmDrainHold)
                        local delta  = (Server.collectedCount or 0) - before
                        if got > 0 or delta > 0 then
                            StrongholdCount = StrongholdCount + 1
                            if Config.HopAfterStronghold and (not Config.HopOnlyIfCollected or delta > 0) then
                                HopFast("after-stronghold-collect")
                            end
                        else
                            strongholdTried[sid] = true
                        end
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
        if (tick() - (Server.joinedAt or 0)) >= (Config.NoChestScanWindow or 15) then
            Hop("no-chest-after-scan")
        end
    else
        local id   = chest:GetDebugId()
        local prox = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
        local t0   = os.clock()
        local okOpen = false
        while prox and prox.Parent and prox.Enabled and (os.clock() - t0) < 10 do
            tpCFrame(CFrame.new(chest:GetPivot().Position))
            if typeof(fireproximityprompt) == "function" then
                pcall(function() fireproximityprompt(prox, 1) end)
            else
                local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum and prox and prox.HoldDuration == 0 then hum:MoveTo(chest:GetPivot().Position) end
            end
            task.wait(0.4)
            prox = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
        end
        if not (prox and prox.Parent and prox.Enabled) then okOpen = true end

        if okOpen then
            if waitDiamonds(Config.FarmHoldAfterSpawn or 2.3) then
                local before = Server.collectedCount or 0
                local got    = harvestDrain(Config.FarmDrainHold)
                local delta  = (Server.collectedCount or 0) - before
                if got > 0 or delta > 0 then
                    NormalChestCount = NormalChestCount + 1
                    if Config.HopAfterNormalChest and (not Config.HopOnlyIfCollected or delta > 0) then
                        HopFast("after-normalchest-collect")
                    end
                else
                    chestTried[id] = true
                end
            else
                chestTried[id] = true
            end
        else
            chestTried[id] = true
        end
    end

    task.wait(Config.FarmTick)
end)

-- Diamonds song song
bindLoop("diamonds", function()
    if g.PlaceId == Config.FarmPlaceId then collectAllDiamonds() end
end, Config.DiamondTick)

-- No-gems watcher
bindLoop("no-gems-watch", function()
    if inFarm() then
        if (Server.collectedCount or 0) == 0 then
            local aliveFor = tick() - (Server.joinedAt or 0)
            if aliveFor >= (Config.NoGemsGrace or 10) then
                if not hasOpenableChest() then
                    local t0, seen = tick(), false
                    while tick()-t0 < 4 do
                        if diamondsLeft() then seen = true; break end
                        task.wait(0.35)
                    end
                    if not seen then Hop("no-diamonds-after-grace") end
                end
            end
        end
    end
end, 2.2)

-- Noclip
getgenv().NoClip = true
bindConn(RunService.Stepped:Connect(function()
    local c = LocalPlayer.Character
    if not c then return end
    local on = getgenv().NoClip
    for _, v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then v.CanCollide = not on end
    end
end))

-- Mark visited in queued teleport
queue_on_teleport_compat([[
    task.wait(1)
    pcall(function()
        if game.JobId and game.JobId ~= "" then
            getgenv().VisitedServers = getgenv().VisitedServers or {hour=-1, ids={}, ttl=21600, min_free_slots=2}
            local G = getgenv().VisitedServers
            local now = os.time()
            G.ids[game.JobId] = now
        end
    end)
]])


