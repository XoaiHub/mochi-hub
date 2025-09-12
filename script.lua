-- ================================================================
-- Mochi Farm (Luarmor-ready & Emulator-stable, no UI)
-- + Fast Hop After Collect
-- + Anti-DEAD + Skip Server Full + No-Rejoin-Same-Server
-- + Guard: chỉ hop khi đã vào map farm (không hop ở lobby)
-- + Hop V2: tránh trùng server, tránh full, no-gems autohop
-- (Hardened for all executors incl. Wave)
-- ================================================================

-- ===== CONFIG =====
local Config = {
    RegionFilterEnabled     = false,                          -- chưa bật lọc region; có thể nối vào pickServer nếu cần
    RegionList              = { "singapore", "tokyo", "us-east" },
    RetryHttpDelay          = 2,

    StrongholdChestName     = "Stronghold Diamond Chest",
    StrongholdPromptTime    = 6,
    StrongholdDiamondWait   = 10,

    FarmPlaceId             = 126509999114328,                -- MAP FARM
    LobbyCheckInterval      = 2.0,
    FarmTick                = 1.0,
    DiamondTick             = 0.35,

    HopBackoffMin           = 1.5,
    HopBackoffMax           = 3.0,

    -- Fast hop ngay sau khi nhặt xong
    HopAfterStronghold      = true,
    HopAfterNormalChest     = true,
    HopPostDelay            = 0.20,

    -- Anti-DEAD
    DeadHopTimeout          = 6.0,
    DeadUiKeywords          = { "dead", "you died", "respawn", "revive" },

    -- Tham số cũ giữ nguyên để tương thích cấu trúc (không dùng ở hop mới)
    MaxConsecutiveHopFail   = 5,
    ConsecutiveHopCooloff   = 6.0,
    MaxPagesPrimary         = 8,
    MaxPagesFallback        = 12,
    TeleportFailBackoffMax  = 8,

    MinFreeSlotsDefault     = 1,     -- (không dùng ở hop mới)
    MinFreeSlotsCeil        = 3,     -- (không dùng ở hop mới)
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

-- HTTP getter tương thích (ưu tiên game:HttpGet, fallback request)
local function http_get(url)
    local ok1, res1 = pcall(function() return g:HttpGet(url) end)
    if ok1 and type(res1) == "string" and #res1 > 0 then return res1 end
    local req = (syn and syn.request) or (http and http.request) or request or rawget(getfenv(),"http_request")
    if req then
        local ok2, res2 = pcall(function() return req({Url = url, Method = "GET"}) end)
        if ok2 and res2 then
            if res2.StatusCode == 200 and type(res2.Body) == "string" and #res2.Body > 0 then
                return res2.Body
            end
            if res2.Success and type(res2.Body) == "string" and #res2.Body > 0 then
                return res2.Body
            end
        end
    end
    return nil
end

-- queue_on_teleport tương thích
local function queue_on_teleport_compat(code)
    local f = (syn and syn.queue_on_teleport)
          or  queue_on_teleport
          or  (fluxus and fluxus.queue_on_teleport)
          or  (KRNL_LOADED and queue_on_teleport)
    if f then pcall(f, code) end
end
-- ví dụ: queue_on_teleport_compat([[loadstring(game:HttpGet("https://yourdomain/Init.lua"))()]])

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

-- ===== STATE (farm) =====
local PlaceID = g.PlaceId
local strongholdTried, chestTried = {}, {}
local StrongholdCount, NormalChestCount = 0, 0

-- ===== FARM GUARD: chỉ hop khi đã vào đúng map farm =====
getgenv().AllowHop = false
local function inFarm() return g.PlaceId == (Config and Config.FarmPlaceId or g.PlaceId) end
task.spawn(function()
    while task.wait(0.5) do
        getgenv().AllowHop = inFarm()
    end
end)

-- ===== VISITED persistence + HOP CORE (V2) =====
do
    repeat task.wait() until g:IsLoaded()

    -- Ghi nhớ JobId 3 giờ, lưu xuyên teleport
    getgenv().VisitedServers = getgenv().VisitedServers or {
        hour = -1,
        ids  = {},      -- [jobId] = last_seen_unix
        ttl  = 10800,   -- 3 giờ
        min_free_slots = 2, -- yêu cầu slot trống mặc định
    }
    local G = getgenv().VisitedServers

    local function now() return os.time() end
    local function rotateHour()
        local h = os.date("!*t").hour
        if G.hour ~= h then
            G.hour = h
            local n = now()
            for id, ts in pairs(G.ids) do
                if (n - (ts or 0)) > (G.ttl or 10800) then
                    G.ids[id] = nil
                end
            end
        end
    end
    local function markVisitedGlobal(id)
        if not id or id == "" then return end
        rotateHour(); G.ids[id] = now()
    end
    local function notVisited(id)
        if not id or id == "" then return false end
        if id == g.JobId then return false end
        rotateHour()
        local ts = G.ids[id]
        if ts and (now() - ts) <= (G.ttl or 10800) then return false end
        return true
    end

    local HOSTS = { "https://games.roblox.com", "https://games.roproxy.com", "https://apis.roproxy.com" }
    local function vacancy(sv)
        local maxp   = tonumber(sv.maxPlayers or sv.maxPlayerCount or 0) or 0
        local play   = tonumber(sv.playing    or sv.playerCount    or 0) or 0
        return math.max(0, maxp - play), play, maxp
    end

    -- (tuỳ chọn) lọc theo region list nếu bật Config.RegionFilterEnabled
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
        local bestList, cursor = {}, nil

        for _page=1,10 do
            for _,host in ipairs(HOSTS) do
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
                               and free >= minFree
                               and playing >= 0 and playing <= math.max(0,(maxp-2)) -- buffer 2 slot
                               and regionMatch(sv) then
                                table.insert(bestList, { id=id, free=free, playing=playing, maxp=maxp })
                            end
                        end
                        cursor = json.nextPageCursor
                        break
                    end
                end
                task.wait(0.12)
            end
            if not cursor then break end
            task.wait(0.12)
        end

        table.sort(bestList, function(a,b)
            if a.free ~= b.free then return a.free > b.free end
            if a.playing ~= b.playing then return a.playing < b.playing end
            return a.id < b.id
        end)
        local n = math.min(#bestList, 5)
        if n >= 2 then
            local i = math.random(1, n)
            bestList[1], bestList[i] = bestList[i], bestList[1]
        end
        return bestList[1]
    end

    -- Teleport wrappers
    local STATE = { BusyTeleport=false }
    local function bindTP()
        if STATE._bound then return end
        STATE._bound = true
        TeleportService.TeleportInitFailed:Connect(function(_, result, msg)
            local r = tostring(result)
            if r:find("GameFull") or (msg and msg:lower():find("requested experience is full")) then
                G.min_free_slots = math.min((G.min_free_slots or 2) + 1, 3)
                task.delay(60, function() G.min_free_slots = 2 end)
            end
            task.wait(1.5); STATE.BusyTeleport=false
        end)
        LocalPlayer.OnTeleport:Connect(function(st)
            if st==Enum.TeleportState.Started then
                getgenv().AllowHop = false -- reset guard, vào farm sẽ bật lại
            end
            if st==Enum.TeleportState.Failed or st==Enum.TeleportState.Cancelled then
                task.wait(1.5); STATE.BusyTeleport=false
            end
        end)
    end

    local function tpToJob(jobId)
        if not jobId or jobId=="" or STATE.BusyTeleport then return false end
        STATE.BusyTeleport = true; bindTP(); markVisitedGlobal(jobId)
        local ok = pcall(function()
            local TeleportOptions = Instance.new("TeleportOptions")
            TeleportOptions.ServerInstanceId = jobId
            TeleportService:TeleportAsync(g.PlaceId, { LocalPlayer }, TeleportOptions)
        end)
        if not ok then
            local ok2 = pcall(function()
                TeleportService:TeleportToPlaceInstance(g.PlaceId, jobId, LocalPlayer)
            end)
            if not ok2 then
                task.wait(1.5); STATE.BusyTeleport=false; return false
            end
        end
        task.delay(15, function() STATE.BusyTeleport=false end)
        return true
    end

    local function softRejoin()
        if STATE.BusyTeleport then return false end
        STATE.BusyTeleport = true; bindTP()
        local ok = pcall(function() TeleportService:Teleport(g.PlaceId, LocalPlayer) end)
        if not ok then task.wait(1.5); STATE.BusyTeleport=false; return false end
        task.delay(15, function() STATE.BusyTeleport=false end)
        return true
    end

    -- ===== Hop/HopFast với GUARD: chỉ hop khi đã vào map farm =====
    local function _HopInternal()
        task.wait(rand(Config.HopBackoffMin, Config.HopBackoffMax))
        local pick = pickServer(g.PlaceId)
        if not (pick and tpToJob(pick.id)) then
            softRejoin()
        end
    end

    function Hop(reason)
        if not getgenv().AllowHop then
            warn("[Hop] blocked (not in farm), reason=", tostring(reason or ""))
            return
        end
        if STATE.BusyTeleport then return end
        task.spawn(_HopInternal)
    end

    function HopFast(reason)
        if not getgenv().AllowHop then
            warn("[HopFast] blocked (not in farm), reason=", tostring(reason or ""))
            return
        end
        if getgenv and getgenv().PauseHop then
            local t0 = os.clock()
            while getgenv().PauseHop and os.clock()-t0 < 10 do task.wait(0.25) end
        end
        task.spawn(function()
            task.wait(Config.HopPostDelay or 0.2)
            warn("[HopFast]", tostring(reason or ""))
            pcall(function() _G._force_hop = true end)
            _HopInternal()
        end)
    end

    -- Mark JobId hiện tại sau khi tới (bảo hiểm)
    task.delay(2, function()
        pcall(function()
            if g.JobId and g.JobId ~= "" then markVisitedGlobal(g.JobId) end
        end)
    end)

    -- Sau khi vào server mới: nếu không thấy diamonds -> hop tiếp
    local function hasDiamonds()
        local items = workspace:FindFirstChild("Items")
        return items and items:FindFirstChild("Diamond") ~= nil
    end
    task.spawn(function()
        while true do
            if inFarm() then
                local t0 = tick()
                while tick()-t0 < 6 do
                    if hasDiamonds() then break end
                    task.wait(0.4)
                end
                if not hasDiamonds() then
                    if typeof(HopFast) == "function" then
                        HopFast("no-diamonds-after-join")
                    else
                        Hop("no-diamonds-after-join")
                    end
                end
            end
            task.wait(8)
        end
    end)
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
        task.wait(0.2)
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
                firePromptSafe(prox)
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

-- Compatibility mark-visited (không cần thiết nhưng để an toàn)
queue_on_teleport_compat([[
    task.wait(1)
    pcall(function()
        -- Hop V2 đã tự mark visited qua getgenv().VisitedServers
    end)
]])


