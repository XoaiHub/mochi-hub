-- ===== VISITED + HOP CORE (NO-REPEAT-SERVER, HARD) =====
repeat task.wait() until game:IsLoaded()

-- Lịch sử server đã vào (không lặp lại)
getgenv().VisitedServers = getgenv().VisitedServers or {
    hour = -1,
    ids  = {},      -- [jobId] = last_seen_unix
    ttl  = 21600,   -- 6 giờ (tăng từ 3h -> 6h)
    min_free_slots = 2,
    _clean_counter = 0,
}
-- Ban-list tạm để không thử đi thử lại một server trong cùng phiên
getgenv().BanServers = getgenv().BanServers or {
    ids = {},       -- [jobId] = last_banned_unix
    ttl = 10800,    -- 3 giờ
}

local G       = getgenv().VisitedServers
local BAN     = getgenv().BanServers
local Http    = game:GetService("HttpService")
local TP      = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LP      = Players.LocalPlayer

local function now() return os.time() end
local function rotateHour()
    local h = os.date("!*t").hour
    if G.hour ~= h then
        G.hour = h
        local n = now()
        for id, ts in pairs(G.ids) do
            if (n - (ts or 0)) > (G.ttl or 21600) then G.ids[id] = nil end
        end
        -- dọn banlist theo TTL
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
    if id == game.JobId then return false end
    rotateHour()
    local ts = G.ids[id]
    if ts and (now() - ts) <= (G.ttl or 21600) then return false end
    return true
end

-- Nhiều mirror + phá cache để tránh trả danh sách trùng cũ
local HOSTS = {
    "https://games.roblox.com",
    "https://games.roproxy.com",
    "https://apis.roproxy.com",
    "https://games.rbxcdn.xyz"
}

local function http_get(url)
    -- thêm cache-busting
    local salt = tostring(math.random(1,1e9))
    local full = url .. (url:find("%?") and "&" or "?") .. "cbust=" .. Http:UrlEncode(salt) .. "&_t=" .. tostring(now())
    local ok1, res1 = pcall(function() return game:HttpGet(full) end)
    if ok1 and type(res1) == "string" and #res1 > 0 then return res1 end
    local req = (syn and syn.request) or (http and http.request) or request or rawget(getfenv(),"http_request")
    if req then
        local ok2, res2 = pcall(function() return req({Url = full, Method = "GET"}) end)
        if ok2 and res2 and (res2.StatusCode == 200 or res2.Success) and type(res2.Body) == "string" and #res2.Body > 0 then
            return res2.Body
        end
    end
    return nil
end

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

-- lấy ngẫu nhiên cursor start để tránh luôn lấy trang đầu (đỡ trùng)
local function randomCursorJitter(pageIdx)
    if pageIdx <= 1 then return nil end
    -- API cursor là chuỗi opaque; không tự tạo được, nên chỉ hiệu ứng xáo trộn bằng cách
    -- đổi host và đảo kết quả; phần “random pick” phía dưới xử lý chính.
    return nil
end

local function pickServer(placeId)
    local minFree = math.max(G.min_free_slots or 2, 1)
    local candidates, cursor = {}, nil

    for page = 1, 16 do
        -- xáo thứ tự host mỗi trang để tránh lệ thuộc 1 mirror
        local shuffled = {table.unpack(HOSTS)}
        for i = #shuffled, 2, -1 do
            local j = math.random(1, i)
            shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
        end

        local gotPage = false
        for _,host in ipairs(shuffled) do
            local url = ("%s/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(host, placeId)
            if cursor then url = url .. "&cursor=" .. Http:UrlEncode(cursor) end
            local body = http_get(url)
            if body then
                local ok, data = pcall(function() return Http:JSONDecode(body) end)
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

    -- Không có ứng viên -> mở khoá visited cũ (nhưng vẫn không trùng job hiện tại)
    if #candidates == 0 then
        G._clean_counter = (G._clean_counter or 0) + 1
        if G._clean_counter % 2 == 0 then
            local oldest = {}
            for id, ts in pairs(G.ids) do table.insert(oldest, {id=id, ts=ts or 0}) end
            table.sort(oldest, function(a,b) return a.ts < b.ts end)
            local cut = math.max(1, math.floor(#oldest * 0.15))
            for i=1,math.min(cut, #oldest) do
                if oldest[i].id ~= game.JobId then G.ids[oldest[i].id] = nil end
            end
            warn("[pickServer] Cleaned", math.min(cut, #oldest), "visited entries")
        end
    end

    -- Ưu tiên: free nhiều hơn, playing ít hơn -> ít cạnh tranh
    table.sort(candidates, function(a,b)
        if a.free ~= b.free       then return a.free > b.free end
        if a.playing ~= b.playing then return a.playing < b.playing end
        return a.id < b.id
    end)

    -- Lấy ngẫu nhiên trong top 6 để giảm trùng lặp
    local n = math.min(#candidates, 6)
    if n >= 1 then
        local i = math.random(1, n)
        return candidates[i]
    end
    return nil
end

-- Teleport wrappers + chống quay lại server cũ
local STATE = { BusyTeleport=false, LastHopAt=0, HopCooldown=2.0, _bound=false }

local function bindTP()
    if STATE._bound then return end
    STATE._bound = true
    -- Nếu fail vì full -> tăng min_free_slots tạm thời
    bindConn(TP.TeleportInitFailed:Connect(function(_, result, msg)
        local r = tostring(result or "")
        if r:find("GameFull") or (msg and msg:lower():find("requested experience is full")) then
            G.min_free_slots = math.min((G.min_free_slots or 2) + 1, 3)
            task.delay(60, function() G.min_free_slots = 2 end)
        end
        task.wait(1.0); STATE.BusyTeleport=false
    end))
    -- Khi bắt đầu teleport, tắt hop guard để khỏi lặp
    bindConn(LP.OnTeleport:Connect(function(st)
        if st==Enum.TeleportState.Started then
            getgenv().AllowHop = false
        end
        if st==Enum.TeleportState.Failed or st==Enum.TeleportState.Cancelled then
            task.wait(1.0); STATE.BusyTeleport=false
        end
    end))
end

-- Fallback “random teleport” nhưng vẫn chống dính server cũ:
local function randomTeleportAvoidCurrent(maxRetry)
    maxRetry = maxRetry or 3
    if STATE.BusyTeleport then return false end
    if tick() - (STATE.LastHopAt or 0) < (STATE.HopCooldown or 2.0) then return false end
    STATE.BusyTeleport = true; bindTP(); STATE.LastHopAt = tick()

    local prev = game.JobId
    local ok = pcall(function() TP:Teleport(game.PlaceId, LP) end)
    if not ok then STATE.BusyTeleport=false return false end

    -- Sau khi tới nơi, nếu vẫn là prev -> auto-hop lại bằng pickServer
    task.delay(6, function()
        pcall(function()
            if game.JobId == prev then
                banServer(prev) -- cấm luôn job này một thời gian
                -- thử hop bằng pickServer
                local pick = pickServer(game.PlaceId)
                if pick and pick.id and pick.id ~= prev then
                    local TeleportOptions = Instance.new("TeleportOptions")
                    TeleportOptions.ServerInstanceId = pick.id
                    pcall(function() TP:TeleportAsync(game.PlaceId, { LP }, TeleportOptions) end)
                end
            end
        end)
        STATE.BusyTeleport=false
    end)
    return true
end

local function tpToJob(jobId)
    if not jobId or jobId=="" or STATE.BusyTeleport then return false end
    if jobId == game.JobId then return false end
    if tick() - (STATE.LastHopAt or 0) < (STATE.HopCooldown or 2.0) then return false end
    STATE.BusyTeleport = true; bindTP(); STATE.LastHopAt = tick()

    -- Đánh dấu để không quay lại jobId đó trong phiên này
    banServer(game.JobId)
    markVisitedGlobal(game.JobId)

    local ok = pcall(function()
        local TeleportOptions = Instance.new("TeleportOptions")
        TeleportOptions.ServerInstanceId = jobId
        TP:TeleportAsync(game.PlaceId, { LP }, TeleportOptions)
    end)
    if not ok then
        -- Nếu instance teleport lỗi -> ban job lỗi và thử random tránh trùng
        banServer(jobId)
        task.wait(1.0); STATE.BusyTeleport=false
        return randomTeleportAvoidCurrent(2)
    end
    task.delay(12, function() STATE.BusyTeleport=false end)
    return true
end

-- Stay windows / Guard giữ nguyên
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

-- ===== PUBLIC HOP API (luôn đổi job khác) =====
local function _HopInternal()
    task.wait(math.random()*(Config.HopBackoffMax-Config.HopBackoffMin) + Config.HopBackoffMin)
    -- Luôn cố pick server mới trước
    local pick = pickServer(game.PlaceId)
    if pick and pick.id and pick.id ~= game.JobId then
        if tpToJob(pick.id) then return end
    end
    -- fallback cuối cùng (tránh lặp): randomTeleportAvoidCurrent
    randomTeleportAvoidCurrent(2)
end

function Hop(reason, bypass)
    if not getgenv().AllowHop then
        warn("[Hop] block(not in farm):", tostring(reason or "")); return
    end
    local ok, why = canHopNow(bypass)
    if not ok then warn("[Hop] delay:", why); return end
    if STATE.BusyTeleport then return end
    task.spawn(_HopInternal)
end

function HopFast(reason, bypass)
    if not getgenv().AllowHop then
        warn("[HopFast] block(not in farm):", tostring(reason or "")); return
    end
    local ok, why = canHopNow(bypass)
    if not ok then warn("[HopFast] delay:", why); return end
    task.spawn(function()
        task.wait(Config.HopPostDelay or 0.18)
        pcall(function() _G._force_hop = true end)
        _HopInternal()
    end)
end

-- Đánh dấu job hiện tại sau khi tới + reset session
task.delay(2, function()
    pcall(function()
        if game.JobId and game.JobId ~= "" then
            markVisitedGlobal(game.JobId)
            banServer(game.JobId) -- cấm quay lại ngay trong phiên
        end
        _onServerEnter()
        if game.PlaceId == (Config and Config.FarmPlaceId or game.PlaceId) then
            getgenv().AllowHop = true
        end
    end)
end)


