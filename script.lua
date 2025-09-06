--======== AutoCrate + Self-Diagnostic (one-file) ========

-- === Tham số cơ bản ===
local MinBalls      = 800
local CurrencyStat  = "BeachBalls2025"   -- nếu log báo không thấy stat này, bạn đổi đúng tên stat của game
local CheckInterval = 2.0
local AfterOpenWait = 1.25

-- === Mapping tên hiển thị -> tham số OpenCrate ===
local BOX_DEFS = {
    ["Mystery Box"]     = { crateId = "Summer2025Box", crateType = "MysteryBox" },
    ["Summer 2025 Box"] = { crateId = "Summer2025Box", crateType = "MysteryBox" },
}

-- ====== Helpers ======
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local function log(...) print("[CrateDiag]", ...) end
local function warnlog(...) warn("[CrateDiag]", ...) end

local function existsPath(root, pathTbl)
    local cur = root
    for _, name in ipairs(pathTbl) do
        cur = cur and cur:FindFirstChild(name)
        if not cur then return nil end
    end
    return cur
end

local function dumpLeaderstats()
    local ls = LP:FindFirstChild("leaderstats")
    if not ls then log("leaderstats = nil") return end
    local names = {}
    for _,x in ipairs(ls:GetChildren()) do
        table.insert(names, (x.Name .. "=" .. tostring(x.Value)))
    end
    log("leaderstats:", table.concat(names, " | "))
end

local function getBall()
    local ls = LP:FindFirstChild("leaderstats")
    local s = ls and ls:FindFirstChild(CurrencyStat)
    return s and s.Value or nil
end

-- ====== Tự phát hiện RemoteEvent/RemoteFunction ======
local Remotes = existsPath(RS, {"Remotes"})
local Shop    = Remotes and Remotes:FindFirstChild("Shop") or nil
local OpenCrate = Shop and Shop:FindFirstChild("OpenCrate") or nil

if not Remotes then warnlog("Không tìm thấy ReplicatedStorage.Remotes") end
if Remotes and not Shop then warnlog("Không tìm thấy Remotes.Shop") end
if Shop and not OpenCrate then warnlog("Không tìm thấy Remotes.Shop.OpenCrate") end

if OpenCrate then
    log("OpenCrate class:", OpenCrate.ClassName)
else
    warnlog("OpenCrate = nil -> Script sẽ KHÔNG thể mở rương. Kiểm tra lại đường dẫn/tên remote.")
end

local isRemoteEvent, isRemoteFunction = false, false
if OpenCrate then
    isRemoteEvent   = OpenCrate.ClassName == "RemoteEvent"
    isRemoteFunction= OpenCrate.ClassName == "RemoteFunction"
end

local function openOne(displayName)
    local def = BOX_DEFS[displayName]
    if not def then
        warnlog("BOX_DEFS thiếu mapping cho:", displayName)
        return false
    end

    local args = { def.crateId, def.crateType, CurrencyStat }

    if isRemoteFunction then
        local ok, ret = pcall(function()
            return OpenCrate:InvokeServer(unpack(args))
        end)
        if ok then
            log("✅ InvokeServer OK:", displayName, "ret=", typeof(ret)=="table" and "table" or tostring(ret))
            return true
        else
            warnlog("❌ InvokeServer lỗi:", ret)
            return false
        end
    elseif isRemoteEvent then
        local ok, err = pcall(function()
            OpenCrate:FireServer(unpack(args))
        end)
        if ok then
            log("✅ FireServer OK:", displayName)
            return true
        else
            warnlog("❌ FireServer lỗi:", err)
            return false
        end
    else
        warnlog("OpenCrate không phải RemoteEvent/RemoteFunction ->", OpenCrate and OpenCrate.ClassName or "nil")
        return false
    end
end

local function waitAfterOpen(minBefore)
    local t0 = tick()
    repeat
        task.wait(0.25)
        local val = getBall()
        if val and val < minBefore then break end
    until (tick() - t0) > math.max(0.5, AfterOpenWait)
end

-- ====== In thông tin chẩn đoán ban đầu ======
dumpLeaderstats()
local b0 = getBall()
if b0 == nil then
    warnlog(("Không thấy stat '%s' trong leaderstats. Hãy kiểm tra log leaderstats ở trên và đổi CurrencyStat cho đúng."):format(CurrencyStat))
else
    log(("Ball ban đầu: %d | MinBalls=%d"):format(b0, MinBalls))
end
if OpenCrate then
    log("Đã thấy OpenCrate:", OpenCrate:GetFullName())
end

-- ====== Vòng lặp chính ======
task.spawn(function()
    while task.wait(math.max(0.5, CheckInterval)) do
        -- Đọc config ngoại
        local CFG = rawget(getgenv(), "Config")
        if type(CFG) ~= "table" then
            warnlog("getgenv().Config chưa tồn tại hoặc không phải table. Ví dụ: getgenv().Config = { [\"Mystery Box\"]=true }")
            continue
        end

        -- Kiểm tra stat
        local balls = getBall()
        if balls == nil then
            -- log cho mỗi vòng sẽ spam -> chỉ cảnh báo nhẹ
            -- Bạn nên đổi CurrencyStat = đúng tên stat thật sự
            continue
        end

        if balls >= MinBalls and OpenCrate then
            -- Duyệt từng box bật true
            local triedAny = false
            for name, on in pairs(CFG) do
                if on and BOX_DEFS[name] then
                    triedAny = true
                    while (getBall() or 0) >= MinBalls do
                        if not openOne(name) then break end
                        waitAfterOpen(MinBalls)
                    end
                end
            end
            if not triedAny then
                warnlog("Config có nhưng không có key hợp lệ khớp BOX_DEFS. Ví dụ hợp lệ: [\"Mystery Box\"]=true")
            end
        end
    end
end)
