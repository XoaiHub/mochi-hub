--[[ 
  Mochi Loader (Init.lua)
  - Người dùng cần đặt License trước khi chạy:
      License = "KEY_CUA_BAN"
      loadstring(game:HttpGet("https://yourdomain.com/Init.lua"))()
  - Loader sẽ gọi API /api/check → nếu OK thì tải script hack thật (script.lua) từ SCRIPT_URL và chạy.
  - Nếu key sai/hết hạn/đủ tab → Kick.
]]

-- ========== CONFIG ==========
local API_BASE   = "http://103.249.117.233:8000" -- đổi thành domain/VPS của bạn
local SCRIPT_URL = "https://raw.githubusercontent.com/XoaiHub/mochi-hub/refs/heads/master/Kaitun%2099Night.lua" -- đường dẫn script thật

-- ========== Services ==========
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local function Kick(msg)
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
    return (str:gsub("\n", "\r\n"):gsub("([^%w _%-%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end):gsub(" ", "%%20"))
end

-- Lấy HWID
local function identify_hwid()
    local hwid = nil
    pcall(function()
        if syn and syn.get_hwid then hwid = syn.get_hwid() end
        if not hwid and get_hwid then hwid = get_hwid() end
    end)
    if not hwid or hwid == "" then
        pcall(function()
            hwid = game:GetService("RbxAnalyticsService"):GetClientId()
        end)
    end
    return tostring(hwid or "UNKNOWN")
end

-- HTTP GET
local function http_get(url)
    local req = (syn and syn.request) or http_request or request
    if req then
        local r = req({Url=url, Method="GET"})
        if r and r.StatusCode == 200 then return true, r.Body end
        return false, r and r.Body or "HTTP Error"
    else
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if ok then return true, res end
        return false, res
    end
end

-- ========== Main ==========
repeat task.wait() until game:IsLoaded() and LocalPlayer

-- Lấy License
local License = rawget(_G, "License") or License
License = strip_invis(License)

if type(License) ~= "string" or #License < 8 then
    return Kick("❌ Thiếu hoặc sai key (License).")
end

-- Lấy HWID
local HWID = identify_hwid()

-- Gọi API check key
local url = API_BASE .. "/api/check?license=" .. urlencode(License) .. "&hwid=" .. urlencode(HWID)
local ok, body = http_get(url)
if not ok then return Kick("❌ Không kết nối được API.") end

local data
pcall(function() data = HttpService:JSONDecode(body) end)
if not data or not data.ok then
    local msg = (data and data.msg) or "❌ Key không hợp lệ."
    if msg == "max_tabs_exceeded" then
        msg = "❌ Key đã đạt số tab tối đa."
    end
    return Kick(msg)
end

-- Nếu hợp lệ → tải script thật
local ok2, script_text = http_get(SCRIPT_URL)
if not ok2 or not script_text or #script_text < 10 then
    return Kick("❌ Không tải được script chính.")
end

-- Chạy script thật
local fn, err = loadstring(script_text, "MochiCore")
if not fn then return Kick("❌ Lỗi biên dịch script: " .. tostring(err)) end

local success, runErr = pcall(fn)
if not success then return Kick("❌ Lỗi khi chạy script: " .. tostring(runErr)) end
