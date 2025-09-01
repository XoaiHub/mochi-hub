--[[ 
  Mochi Loader (Init.lua) — universal API connectivity
  - Đặt License trước khi chạy:
      License = "KEY_CUA_BAN"
      loadstring(game:HttpGet("https://yourdomain.com/Init.lua"))()
  - Gọi /api/check; OK thì tải SCRIPT_URL và chạy.
]]

-- ========== CONFIG ==========
-- Thứ tự thử: HTTPS domain → IP (80) → IP (8000)
-- => đảm bảo chạy được trên mọi thiết bị & mạng (nhiều mạng chặn :8000 và http://)
local API_ENDPOINTS = {
    "https://yourdomain.com",   -- NÊN DÙNG (nếu đã có domain + SSL)
    "http://103.249.117.233",   -- IP qua Nginx port 80 (bạn đã cấu hình)
    "http://103.249.117.233:8000", -- fallback trực tiếp (chỉ khi cloud-firewall mở 8000)
}
local SCRIPT_URL = "https://raw.githubusercontent.com/XoaiHub/mochi-hub/refs/heads/master/Kaitun%2099Night.lua"
local DEBUG = true

-- ========== Services ==========
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local function log(...)
    if not DEBUG then return end
    pcall(function()
        local s = table.concat({...}, " ")
        if rconsoleprint then rconsoleprint(s.."\n") else warn(s) end
    end)
end

local function Kick(msg)
    log("[KICK]", tostring(msg))
    pcall(function() LocalPlayer:Kick(tostring(msg or "❌ Script dừng do lỗi.")) end)
    task.wait(0.1)
end

-- Xoá ký tự ẩn khỏi key
local function strip_invis(s)
    s = tostring(s or "")
    s = s:gsub("[%z\1-\31\127]", "")
    s = s:gsub("[\226\128\139\226\128\140\226\128\141\239\187\191]", "")
    return (s:match("^%s*(.-)%s*$") or s)
end

-- URL encode
local function urlencode(str)
    return (str:gsub("\n","\r\n"):gsub("([^%w _%-%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end):gsub(" ","%%20"))
end

-- HWID
local function identify_hwid()
    local hwid
    pcall(function()
        if syn and syn.get_hwid then hwid = syn.get_hwid() end
        if not hwid and get_hwid then hwid = get_hwid() end
    end)
    if not hwid or hwid=="" then
        pcall(function() hwid = game:GetService("RbxAnalyticsService"):GetClientId() end)
    end
    return tostring(hwid or "UNKNOWN")
end

-- HTTP GET (ưu tiên exploit request; nếu không có, chỉ cho phép HTTPS với game:HttpGet)
local function http_get(url)
    local req = (syn and syn.request) or http_request or request
    if req then
        local r = req({Url=url, Method="GET", Headers={["Accept"]="application/json"}})
        if r and r.StatusCode == 200 then return true, r.Body end
        return false, (r and ("HTTP "..tostring(r.StatusCode)..": "..tostring(r.Body))) or "HTTP error"
    else
        if not url:lower():match("^https://") then
            return false, "Executor thiếu HTTP (chỉ hỗ trợ https:// bằng game:HttpGet)"
        end
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if ok then return true, body end
        return false, tostring(body)
    end
end

-- Retry helper
local function try_get(url, times, delaySec)
    for i=1,(times or 2) do
        local ok, body = http_get(url)
        if ok then return true, body end
        log("[GET fail]", url, "=>", tostring(body), "(try", i, ")")
        task.wait(delaySec or 0.5)
    end
    return false, "Failed after retries"
end

-- ========== Main ==========
repeat task.wait() until game:IsLoaded() and LocalPlayer

-- License
local License = strip_invis(rawget(_G,"License") or License)
if type(License) ~= "string" or #License < 8 then
    return Kick("❌ Thiếu hoặc sai key (License).")
end

-- HWID
local HWID = identify_hwid()

-- Check key qua các endpoint (có retry)
local data, lastErr
for _, BASE in ipairs(API_ENDPOINTS) do
    local url = BASE .. "/api/check?license=" .. urlencode(License) .. "&hwid=" .. urlencode(HWID)
    log("[CHECK]", url)
    local ok, body = try_get(url, 3, 0.6)
    if ok then
        local okJ, parsed = pcall(function() return HttpService:JSONDecode(body) end)
        if okJ then data = parsed break end
        lastErr = "JSON decode error"
        log("[JSON error]", tostring(body))
    else
        lastErr = body
    end
end

if not data or not data.ok then
    local msg = (data and data.msg) or (lastErr or "❌ Không kết nối được API.")
    if msg == "max_tabs_exceeded" then msg = "❌ Key đã đạt số tab tối đa." end
    return Kick(msg)
end

-- Tải script chính
log("[OK] Key verified. Loading core:", SCRIPT_URL)
local ok2, script_text = try_get(SCRIPT_URL, 2, 0.5)
if not ok2 or not script_text or #script_text < 10 then
    return Kick("❌ Không tải được script chính.")
end

-- Chạy script chính
local fn, err = loadstring(script_text, "MochiCore")
if not fn then return Kick("❌ Lỗi biên dịch script: "..tostring(err)) end
local success, runErr = pcall(fn)
if not success then return Kick("❌ Lỗi khi chạy script: "..tostring(runErr)) end
