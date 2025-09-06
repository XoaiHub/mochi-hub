--================ AutoCrate + AutoDetect Currency =================
local MinBalls, CheckInterval, AfterOpenWait = 800, 1.5, 1.25

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local BOX_DEFS = {
    ["Mystery Box"]     = { crateId = "Summer2025Box", crateType = "MysteryBox" },
    ["Summer 2025 Box"] = { crateId = "Summer2025Box", crateType = "MysteryBox" },
}

local Remotes   = RS:WaitForChild("Remotes")
local Shop      = Remotes:WaitForChild("Shop")
local OpenCrate = Shop:WaitForChild("OpenCrate")
local UseInvoke = (OpenCrate.ClassName == "RemoteFunction")

local function log(...) print("[CrateAuto]", ...) end
local function warnlog(...) warn("[CrateAuto]", ...) end

-- ---- Path helpers ----
local function resolve_path(root, dotpath)
    local cur = root
    for part in string.gmatch(dotpath, "[^%.]+") do
        if part == "%UserId%" then part = tostring(LP.UserId) end
        if part == "%Name%"   then part = LP.Name end
        cur = cur and cur:FindFirstChild(part)
        if not cur then return nil end
    end
    return cur
end

local function find_number_value(root, nameHints)
    for _, inst in ipairs(root:GetDescendants()) do
        if inst:IsA("IntValue") or inst:IsA("NumberValue") then
            local n = inst.Name:lower()
            for _,kw in ipairs(nameHints) do
                if n:find(kw) then return inst, "Value" end
            end
        end
        -- attributes?
        for _,kw in ipairs(nameHints) do
            local att = inst:GetAttribute(kw)
            if type(att) == "number" then
                return inst, ("Attribute:%s"):format(kw)
            end
        end
    end
end

local function find_textlabel_ball()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, ui in ipairs(pg:GetDescendants()) do
        if ui:IsA("TextLabel") or ui:IsA("TextButton") then
            local txt = (ui.Text or ""):lower()
            -- bắt các trường hợp có chữ ball/beach/ký hiệu 800
            if txt:find("ball") or txt:find("beach") or txt:find("800") then
                return ui
            end
        end
    end
end

-- ---- Currency detector ----
local currencyGetter, currencySourceDesc

local function install_currency_getter()
    -- 1) Ưu tiên: đường dẫn do user set
    local path = rawget(getgenv(), "CurrencyPath")
    if type(path) == "string" and #path > 0 then
        local root = game
        local first = path:match("^[^%.]+")
        -- tự động hiểu "ReplicatedStorage" / "Players" / "LocalPlayer" / "PlayerGui"
        if first == "ReplicatedStorage" then root = game:GetService("ReplicatedStorage") end
        if first == "Players" then root = game:GetService("Players") end
        if first == "LocalPlayer" or first == "Player" then root = LP; path = path:gsub("^[^%.]+%.","") end
        local inst = resolve_path(root, path)
        if inst then
            if inst:IsA("IntValue") or inst:IsA("NumberValue") then
                currencyGetter = function() return inst.Value end
                currencySourceDesc = inst:GetFullName()
                log("Found currency source at (Value):", currencySourceDesc)
                return true
            else
                warnlog("CurrencyPath trỏ tới không phải IntValue/NumberValue:", inst.ClassName)
            end
        else
            warnlog("CurrencyPath không resolve được:", path)
        end
    end

    -- 2) Quét LocalPlayer & ReplicatedStorage
    local hints = {"ball","balls","beach","beachball","beachballs","beachballs2025"}
    local holder, how = find_number_value(LP, hints)
    if not holder then
        holder, how = find_number_value(RS, hints)
    end
    if holder then
        if how == "Value" then
            currencyGetter = function() return holder.Value end
            currencySourceDesc = holder:GetFullName()
            log("Found currency source at (Value):", currencySourceDesc)
            return true
        else
            local attName = how:match("Attribute:(.+)")
            currencyGetter = function() return tonumber(holder:GetAttribute(attName)) end
            currencySourceDesc = holder:GetFullName() .. "@" .. how
            log("Found currency source at (Attribute):", currencySourceDesc)
            return true
        end
    end

    -- 3) Fallback: đọc từ UI (TextLabel)
    local tl = find_textlabel_ball()
    if tl then
        currencyGetter = function()
            local t = tl.Text or ""
            local num = tonumber((t:gsub("[^%d]", "")))
            return num or 0
        end
        currencySourceDesc = tl:GetFullName() .. " (Text parse)"
        log("Found currency source at (UI Text):", currencySourceDesc)
        return true
    end

    return false
end

assert(install_currency_getter(), "Không tìm thấy nơi lưu ball. Hãy set getgenv().CurrencyPath trỏ đúng IntValue/NumberValue.")

-- ---- OpenCrate wrapper ----
local function openOne(displayName)
    local def = BOX_DEFS[displayName]; if not def then return false end
    local args = { def.crateId, def.crateType, "BeachBalls2025" } -- server chỉ cần tên loại tiền, không phụ thuộc nơi bạn đọc
    local ok, ret = pcall(function()
        if UseInvoke then
            return OpenCrate:InvokeServer(unpack(args))
        else
            OpenCrate:FireServer(unpack(args))
            return true
        end
    end)
    if ok then
        log("🎁 Opened:", displayName)
        return true
    else
        warnlog("OpenCrate error:", ret)
        return false
    end
end

-- ---- Main loop ----
task.spawn(function()
    log("Currency source:", currencySourceDesc)
    while task.wait(CheckInterval) do
        local CFG = rawget(getgenv(), "Config")
        if type(CFG) ~= "table" then continue end

        local balls = tonumber(currencyGetter() or 0) or 0
        if balls >= MinBalls then
            for name, on in pairs(CFG) do
                if on and BOX_DEFS[name] then
                    while (tonumber(currencyGetter() or 0) or 0) >= MinBalls do
                        if not openOne(name) then break end
                        local t0=tick()
                        repeat task.wait(0.25) until (tonumber(currencyGetter() or 0) or 0) < MinBalls or tick()-t0 > AfterOpenWait
                    end
                end
            end
        end
    end
end)


