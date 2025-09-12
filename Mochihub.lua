-- ================== HOP SERVER API (FIXED & COMPAT) ==================
-- Bền với đổi host, tránh full, tránh trùng, không phụ thuộc field lạ.
-- Tương thích executor (game:HttpGet ưu tiên, fallback http_request/syn.request).
-- Giữ BusyTeleport/Visited; có shim Hop()/Hop1() để code cũ chạy nguyên xi.

local HttpService     = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players         = game:GetService("Players")
local LP              = Players.LocalPlayer

-- --------- STATE (reuse nếu đã tồn tại) ---------
getgenv()._HOP_STATE = getgenv()._HOP_STATE or { BusyTeleport=false, Visited={}, TTL=6*3600 }
local STATE = getgenv()._HOP_STATE

local function now() return os.time() end
local function markVisited(jobId) if jobId and jobId ~= "" then STATE.Visited[jobId] = now() end end
local function notVisited(jobId)
    if not jobId or jobId == "" then return false end
    if jobId == game.JobId then return false end
    local t = STATE.Visited[jobId]
    if t and (now() - t) <= (STATE.TTL or 21600) then return false end
    return true
end

-- --------- HTTP helpers (robust) ---------
local http_request = rawget(getfenv(), "http_request")
               or rawget(getfenv(), "request")
               or (rawget(getfenv(), "syn") and syn.request)
               or (http and http.request)

local function SafeHttpGet(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body)=="string" and #body>0 then return body end
    if http_request then
        local ok2, res = pcall(function() return http_request({Url=url, Method="GET"}) end)
        if ok2 and res and (res.StatusCode==200 or res.StatusCode==201) and res.Body and #res.Body>0 then
            return res.Body
        end
    end
    return nil
end

local function jdec(s) local ok,d=pcall(function() return HttpService:JSONDecode(s) end) return ok and d or nil end

-- Nhiều host để chống đổi proxy / rate-limit
local HOSTS = {
    "https://games.roblox.com",
    "https://games.roproxy.com",
    "https://apis.roproxy.com",
    "https://games.rprxy.xyz",
    "https://games.roproxy.xyz",
}

-- Roblox list thường chỉ chắc: id / playing / maxPlayers
local function vacancy(sv)
    local maxp = tonumber(sv.maxPlayers or sv.maxPlayerCount or sv.maximumPlayerCount or 0) or 0
    local playing = tonumber(sv.playing or sv.playerCount or sv.currentPlayers or 0) or 0
    local open = math.max(0, maxp - playing)
    return open, playing, maxp
end

local function getPage(host, placeId, cursor, order)
    local url = ("%s/v1/games/%d/servers/Public?limit=100&excludeFullGames=true&sortOrder=%s")
                :format(host, placeId, order or "Asc")
    if cursor and cursor ~= "" then url = url .. "&cursor=" .. HttpService:UrlEncode(cursor) end
    local body = SafeHttpGet(url)
    if not body then return nil end
    local data = jdec(body)
    if not (data and type(data.data)=="table") then return nil end
    return data
end

-- mode: "Low" (ít người) | "High" (né server chết – ưu tiên vừa/đông nhưng còn slot)
local function pickBestServer(placeId, mode)
    local best, bestScore = nil, math.huge
    local cursor, order = nil, ((mode=="High") and "Desc" or "Asc")
    for _=1,10 do
        local page
        for _,host in ipairs(HOSTS) do
            page = getPage(host, placeId, cursor, order)
            if page then break end
            task.wait(0.05)
        end
        if not page then break end
        for _,sv in ipairs(page.data) do
            local jobId = sv.id or sv.Id or sv.jobId
            local open, playing, maxp = vacancy(sv)
            if jobId and open >= 1 and notVisited(jobId) then
                local score
                if mode == "High" then
                    -- hướng tới khoảng 60% sức chứa (né server “chết” mà vẫn còn slot)
                    score = math.abs((maxp * 0.6) - playing)
                else
                    -- càng ít người càng tốt
                    score = playing
                end
                if score < bestScore then
                    best, bestScore = sv, score
                end
            end
        end
        cursor = (page.nextPageCursor ~= "null") and page.nextPageCursor or nil
        if not cursor then break end
        task.wait(0.05)
    end
    return best
end

-- --------- Teleport wrappers & guards ---------
local bound = false
local function bindGuards()
    if bound then return end
    bound = true
    TeleportService.TeleportInitFailed:Connect(function()
        task.wait(2); STATE.BusyTeleport = false
    end)
    if LP and LP.OnTeleport then
        LP.OnTeleport:Connect(function(st)
            if st == Enum.TeleportState.Failed or st == Enum.TeleportState.Cancelled then
                task.wait(2); STATE.BusyTeleport = false
            end
        end)
    end
    pcall(function()
        local gui = game:GetService("CoreGui")
        local overlay = gui:FindFirstChild("RobloxPromptGui") and gui.RobloxPromptGui:FindFirstChild("promptOverlay")
        if overlay then
            local function hush(v)
                if v.Name=="ErrorPrompt" and v:FindFirstChild("TitleFrame") and v.TitleFrame:FindFirstChild("ErrorTitle") then
                    if v.Visible and v.TitleFrame.ErrorTitle.Text=="Teleport Failed" then v.Visible=false end
                    v:GetPropertyChangedSignal("Visible"):Connect(function()
                        if v.Visible and v.TitleFrame.ErrorTitle.Text=="Teleport Failed" then v.Visible=false end
                    end)
                end
            end
            for _,ch in ipairs(overlay:GetChildren()) do hush(ch) end
            overlay.ChildAdded:Connect(hush)
        end
    end)
end

local function teleportToJob(jobId)
    if not jobId or STATE.BusyTeleport then return false end
    STATE.BusyTeleport = true; bindGuards(); markVisited(jobId)
    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LP)
    end)
    if not ok then task.wait(2); STATE.BusyTeleport=false; return false end
    task.delay(15, function() STATE.BusyTeleport=false end)
    return true
end

local function softRejoin()
    if STATE.BusyTeleport then return false end
    STATE.BusyTeleport = true; bindGuards()
    local ok = pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
    if not ok then task.wait(2); STATE.BusyTeleport=false; return false end
    task.delay(15, function() STATE.BusyTeleport=false end)
    return true
end

-- --------- Public API ---------
getgenv().HopAPI = function(mode)
    mode = mode or "Low"
    for _=1,6 do
        local sv = pickBestServer(game.PlaceId, mode)
        if sv and teleportToJob(sv.id or sv.Id or sv.jobId) then return true end
        softRejoin()
        task.wait(1.5 + math.random())
    end
    return false
end

-- --------- Shim tương thích cho code cũ ---------
getgenv().Hop  = function(mode) return getgenv().HopAPI(mode or "Low") end
getgenv().Hop1 = function()      return getgenv().HopAPI("Low") end
-- ================== END HOP SERVER API ==================


