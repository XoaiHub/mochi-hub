-- ====================== HOP SERVER (V2) =========================
-- Mục tiêu:
-- - Tránh trùng server: nhớ JobId 3 giờ, lưu xuyên teleport (getgenv)
-- - Tránh server full: yêu cầu tối thiểu 2 slot trống (tự tăng khi fail GameFull)
-- - Vào server không có gems trong vài giây -> hop tiếp
-- - Giữ nguyên API Hop() / HopFast() đang được các nơi khác gọi

do
    repeat task.wait() until game:IsLoaded()

    local g               = game
    local Players         = g:GetService("Players")
    local LP              = Players.LocalPlayer
    local HttpService     = g:GetService("HttpService")
    local TeleportService = g:GetService("TeleportService")

    -- ===== Visited persistence (xuyên teleport & theo giờ UTC) =====
    getgenv().VisitedServers = getgenv().VisitedServers or {
        hour = -1,
        ids  = {},      -- [jobId] = last_seen_unix
        ttl  = 10800,   -- 3 giờ
        min_free_slots = 2,  -- yêu cầu slot trống mặc định
    }
    local G = getgenv().VisitedServers

    local function rotateHour()
        local h = os.date("!*t").hour
        if G.hour ~= h then
            G.hour = h
            -- giữ lại các id còn trong TTL, xoá những id quá TTL
            local now = os.time()
            for id, ts in pairs(G.ids) do
                if (now - (ts or 0)) > (G.ttl or 10800) then
                    G.ids[id] = nil
                end
            end
        end
    end

    local STATE = { BusyTeleport=false } -- state nội bộ cho 1 session
    local function now() return os.time() end

    local function markVisitedGlobal(id)
        if not id or id == "" then return end
        rotateHour()
        G.ids[id] = now()
    end
    local function notVisited(id)
        if not id or id == "" then return false end
        if id == g.JobId then return false end
        rotateHour()
        local ts = G.ids[id]
        if ts and (now() - ts) <= (G.ttl or 10800) then return false end
        return true
    end

    -- ===== HTTP helper =====
    local function http_get(url)
        local ok1, res1 = pcall(function() return g:HttpGet(url) end)
        if ok1 and type(res1) == "string" and #res1 > 0 then return res1 end
        local req = (syn and syn.request) or (http and http.request) or request or rawget(getfenv(),"http_request")
        if req then
            local ok2, res2 = pcall(function() return req({Url=url, Method="GET"}) end)
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
    local function jdec(s)
        local ok,d = pcall(function() return HttpService:JSONDecode(s) end)
        return ok and d or nil
    end

    -- ===== Chọn server thông minh =====
    local HOSTS = { "https://games.roblox.com", "https://games.roproxy.com", "https://apis.roproxy.com" }

    local function vacancy(sv)
        local maxp   = tonumber(sv.maxPlayers or sv.maxPlayerCount or 0) or 0
        local play   = tonumber(sv.playing    or sv.playerCount    or 0) or 0
        return math.max(0, maxp - play), play, maxp
    end

    local function pickServer(placeId)
        -- Chiến lược:
        -- - Yêu cầu ít nhất G.min_free_slots slot trống
        -- - Tránh JobId đã vào (getgenv persist 3h)
        -- - Ưu tiên server free nhiều, đồng thời "playing" thấp (nhưng >0 để hạn chế lobby trống)
        -- - Ngẫu nhiên hoá trong top candidates để tránh stampede
        local minFree = math.max(G.min_free_slots or 2, 1)
        local bestList, cursor = {}, nil

        for _page=1,10 do
            for _,host in ipairs(HOSTS) do
                local url = ("%s/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(host, placeId)
                if cursor then url = url .. "&cursor=" .. HttpService:UrlEncode(cursor) end
                local body = http_get(url)
                if body then
                    local data = jdec(body)
                    if data and type(data.data) == "table" then
                        for _,sv in ipairs(data.data) do
                            local id = sv.id or sv.Id or sv.jobId
                            local free, playing, maxp = vacancy(sv)
                            -- Buffer: playing <= maxp-2 để giảm race-to-full; tránh playing==0 nếu muốn
                            if id and notVisited(id) and free >= minFree and playing >= 0 and playing <= math.max(0,(maxp-2)) then
                                table.insert(bestList, {
                                    id=id, free=free, playing=playing, maxp=maxp
                                })
                            end
                        end
                        cursor = data.nextPageCursor
                        break
                    end
                end
                task.wait(0.12)
            end
            if not cursor then break end
            task.wait(0.12)
        end

        table.sort(bestList, function(a,b)
            if a.free   ~= b.free   then return a.free   > b.free   end
            if a.playing~= b.playing then return a.playing < b.playing end
            return a.id < b.id
        end)

        -- Trộn ngẫu nhiên nhẹ top 5 để phân tán
        local n = math.min(#bestList, 5)
        if n >= 2 then
            local i = math.random(1, n)
            bestList[1], bestList[i] = bestList[i], bestList[1]
        end

        return bestList[1]  -- có thể nil
    end

    -- ===== Teleport wrappers =====
    local bound = false
    local function bind()
        if bound then return end
        bound = true
        TeleportService.TeleportInitFailed:Connect(function(_, result, msg)
            local r = tostring(result)
            -- GameFull -> tạm tăng yêu cầu slot trống trong 60s
            if r:find("GameFull") or (msg and msg:lower():find("requested experience is full")) then
                G.min_free_slots = math.min((G.min_free_slots or 2) + 1, 3)
                task.delay(60, function() G.min_free_slots = 2 end)
            end
            task.wait(1.5); STATE.BusyTeleport = false
        end)
        LP.OnTeleport:Connect(function(st)
            if st==Enum.TeleportState.Failed or st==Enum.TeleportState.Cancelled then
                task.wait(1.5); STATE.BusyTeleport=false
            end
        end)
    end

    local function tpToJob(jobId)
        if not jobId or jobId=="" or STATE.BusyTeleport then return false end
        STATE.BusyTeleport = true; bind(); markVisitedGlobal(jobId)

        local ok = pcall(function()
            local TeleportOptions = Instance.new("TeleportOptions")
            TeleportOptions.ServerInstanceId = jobId
            TeleportService:TeleportAsync(g.PlaceId, { LP }, TeleportOptions)
        end)
        if not ok then
            local ok2 = pcall(function()
                TeleportService:TeleportToPlaceInstance(g.PlaceId, jobId, LP)
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
        STATE.BusyTeleport = true; bind()
        local ok = pcall(function() TeleportService:Teleport(g.PlaceId, LP) end)
        if not ok then task.wait(1.5); STATE.BusyTeleport=false; return false end
        task.delay(15, function() STATE.BusyTeleport=false end)
        return true
    end

    -- ===== Public Hop() (được gọi từ Anti-Dead / after-collect / no-chest) =====
    function Hop()
        if STATE.BusyTeleport then return end
        task.spawn(function()
            task.wait(math.random()+0.2) -- backoff nhẹ
            local pick = pickServer(g.PlaceId)
            if not (pick and tpToJob(pick.id)) then
                softRejoin()
            end
        end)
    end

    -- Đánh dấu JobId hiện tại sau khi tới (bảo hiểm)
    task.delay(2, function()
        pcall(function()
            if g.JobId and g.JobId ~= "" then markVisitedGlobal(g.JobId) end
        end)
    end)

    -- ===== Sau khi vào server mới: nếu không thấy diamonds -> hop tiếp =====
    -- Hành vi: chờ tối đa ~6s để thấy vật phẩm "Diamond"; nếu không -> HopFast("no-diamonds")
    local function hasDiamonds()
        local items = workspace:FindFirstChild("Items")
        if not items then return false end
        return items:FindFirstChild("Diamond") ~= nil
    end
    task.spawn(function()
        while true do
            -- chỉ kiểm tra ở map farm
            if g.PlaceId == (Config and Config.FarmPlaceId or g.PlaceId) then
                local t0 = tick()
                -- chờ vài giây cho map spawn
                while tick()-t0 < 6 do
                    if hasDiamonds() then break end
                    task.wait(0.4)
                end
                if not hasDiamonds() then
                    -- không có gems -> hop tiếp
                    if typeof(HopFast) == "function" then
                        HopFast("no-diamonds-after-join")
                    else
                        Hop()
                    end
                end
            end
            task.wait(8)
        end
    end)
end
-- ==================== HẾT HOP SERVER (V2) =======================


