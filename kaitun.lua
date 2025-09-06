-- ================================================================
-- ===============     PHẦN C: AUTO-CRATE OPENING (FIX) ===========
-- ================================================================
do
    -- Tham số
    local AC_MinBalls, AC_CheckInterval, AC_AfterOpenWait = 800, 1.0, 1.0
    local DEBUG = true  -- bật log chẩn đoán

    -- Map hiển thị -> tham số server
    local AC_BOX_DEFS = {
        ["mystery box"]     = { crateId = "Summer2025Box", crateType = "MysteryBox" },
        ["summer 2025 box"] = { crateId = "Summer2025Box", crateType = "MysteryBox" },
    }

    -- Helpers chung
    local function norm(s)
        if type(s) ~= "string" then return "" end
        s = s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        return s:lower()
    end
    local function dprint(...)
        if DEBUG then print("[Crate]", ...) end
    end
    local function dwarn(...)
        if DEBUG then warn("[Crate]", ...) end
    end

    -- Remotes
    local Remotes   = RS:WaitForChild("Remotes")
    local Shop      = Remotes:WaitForChild("Shop")
    local OpenCrate = Shop:WaitForChild("OpenCrate")
    local UseInvoke = (OpenCrate.ClassName == "RemoteFunction")
    dprint("OpenCrate:", OpenCrate.ClassName)

    -- ====== currency detector (giữ như cũ nhưng thêm Changed-watcher) ======
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
                for _, kw in ipairs(nameHints) do
                    if n:find(kw) then return inst, "Value" end
                end
            end
            for _, kw in ipairs(nameHints) do
                local att = inst:GetAttribute(kw)
                if type(att) == "number" then
                    return inst, ("Attribute:" .. kw)
                end
            end
        end
    end
    local function find_textlabel_ball()
        local pg = LP:FindFirstChild("PlayerGui")
        if not pg then return nil end
        for _, ui in ipairs(pg:GetDescendants()) do
            if ui:IsA("TextLabel") or ui:IsA("TextButton") then
                local t = (ui.Text or ""):lower()
                if t:find("ball") or t:find("beach") then
                    return ui
                end
            end
        end
    end

    local currencyGetter, currencySourceDesc, currencySignalConn
    local cachedBalls = 0
    local function setCached(v) cachedBalls = tonumber(v or 0) or 0 end

    local function install_currency_getter()
        -- 1) Ưu tiên path chỉ định
        local path = rawget(getgenv(), "CurrencyPath")
        if type(path) == "string" and #path > 0 then
            local root = game
            local first = path:match("^[^%.]+")
            if first == "ReplicatedStorage" then root = RS end
            if first == "Players" then root = Players end
            if first == "LocalPlayer" or first == "Player" then root = LP; path = path:gsub("^[^%.]+%.","") end
            local inst = resolve_path(root, path)
            if inst then
                if inst:IsA("IntValue") or inst:IsA("NumberValue") then
                    currencyGetter = function() return inst.Value end
                    currencySourceDesc = inst:GetFullName()
                    setCached(inst.Value)
                    if currencySignalConn then currencySignalConn:Disconnect() end
                    currencySignalConn = inst:GetPropertyChangedSignal("Value"):Connect(function()
                        setCached(inst.Value)
                    end)
                    dprint("Currency via Value:", currencySourceDesc)
                    return true
                else
                    dwarn("CurrencyPath không phải Int/NumberValue:", inst.ClassName)
                end
            else
                dwarn("Không resolve được CurrencyPath:", path)
            end
        end

        -- 2) Quét LP -> RS
        local hints = {"beachballs2025","beachballs","beachball","balls","ball","beach"}
        local holder, how = find_number_value(LP, hints)
        if not holder then holder, how = find_number_value(RS, hints) end
        if holder then
            if how == "Value" then
                currencyGetter = function() return holder.Value end
                currencySourceDesc = holder:GetFullName()
                setCached(holder.Value)
                if currencySignalConn then currencySignalConn:Disconnect() end
                currencySignalConn = holder:GetPropertyChangedSignal("Value"):Connect(function()
                    setCached(holder.Value)
                end)
                dprint("Currency via Value:", currencySourceDesc)
                return true
            else
                local att = how:match("Attribute:(.+)")
                currencyGetter = function() return tonumber(holder:GetAttribute(att)) end
                currencySourceDesc = holder:GetFullName() .. "@" .. how
                setCached(holder:GetAttribute(att))
                dprint("Currency via Attribute:", currencySourceDesc)
                return true
            end
        end

        -- 3) Fallback UI parse
        local tl = find_textlabel_ball()
        if tl then
            currencyGetter = function()
                local t = tl.Text or ""
                local num = tonumber((t:gsub("[^%d]", "")))
                return num or 0
            end
            currencySourceDesc = tl:GetFullName() .. " (UI parse)"
            setCached(currencyGetter())
            dprint("Currency via UI:", currencySourceDesc)
            return true
        end
        return false
    end

    assert(install_currency_getter(), "Không tìm thấy nơi đọc ball. Set getgenv().CurrencyPath nếu cần.")

    -- ====== Open wrapper: thử nhiều cách arg để tránh lệch tên currency ======
    local CURRENCY_KEYS_TRY = { "BeachBalls2025", "BeachBalls", "Balls", nil }

    local function tryOpen(def)
        -- Thử các chữ ký:
        -- 1) (crateId, crateType, currencyKey)
        -- 2) (crateId, crateType)  -- nếu server tự suy ra currency
        local ok, ret

        -- thử có currency trước
        for _, ck in ipairs(CURRENCY_KEYS_TRY) do
            ok, ret = pcall(function()
                if UseInvoke then
                    return OpenCrate:InvokeServer(def.crateId, def.crateType, ck)
                else
                    OpenCrate:FireServer(def.crateId, def.crateType, ck)
                    return true
                end
            end)
            dprint("OpenCrate try:", def.crateId, def.crateType, ck, "=>", ok, ret)
            if ok then return true end
            task.wait(0.05)
        end

        -- thử bỏ currency hẳn
        ok, ret = pcall(function()
            if UseInvoke then
                return OpenCrate:InvokeServer(def.crateId, def.crateType)
            else
                OpenCrate:FireServer(def.crateId, def.crateType)
                return true
            end
        end)
        dprint("OpenCrate try (no currency):", def.crateId, def.crateType, "=>", ok, ret)

        return ok
    end

    -- realtime config gate
    getgenv().AutoCrateEnabled = (getgenv().AutoCrateEnabled ~= false)
    local function isEnabled(boxNameRaw)
        local CFG = rawget(getgenv(), "Config")
        if not (getgenv().AutoCrateEnabled and type(CFG) == "table") then return false end
        return CFG[boxNameRaw] == true
    end

    -- main loop
    task.spawn(function()
        dprint("Currency source:", currencySourceDesc)
        while task.wait(AC_CheckInterval) do
            if not getgenv().AutoCrateEnabled then continue end
            local CFG = rawget(getgenv(), "Config"); if type(CFG) ~= "table" then continue end

            local balls = tonumber((currencyGetter and currencyGetter()) or cachedBalls or 0) or 0
            if DEBUG then dprint(("Balls=%d  Min=%d"):format(balls, AC_MinBalls)) end
            if balls < AC_MinBalls then continue end

            -- duyệt các box đang bật trong Config
            for rawName, on in pairs(CFG) do
                if on == true then
                    local key = norm(rawName)
                    local def = AC_BOX_DEFS[key]
                    if not def then
                        dwarn("Config bật box nhưng không khớp BOX_DEFS:", rawName, "→ (đang có keys:", table.concat((function()
                            local t = {}
                            for k,_ in pairs(AC_BOX_DEFS) do table.insert(t, k) end
                            table.sort(t); return t
                        end)(), ", "), ")")
                    else
                        -- mở liên tục tới khi dưới ngưỡng hoặc bị tắt
                        while (tonumber((currencyGetter and currencyGetter()) or cachedBalls or 0) or 0) >= AC_MinBalls
                              and isEnabled(rawName) do
                            local ok = tryOpen(def)
                            if not ok then
                                dwarn("OpenCrate fail → break vòng box:", rawName)
                                break
                            end
                            -- đợi server trừ balls / animation
                            local t0 = tick()
                            repeat
                                task.wait(0.2)
                                if not isEnabled(rawName) then break end
                                balls = tonumber((currencyGetter and currencyGetter()) or cachedBalls or 0) or 0
                            until balls < AC_MinBalls or (tick()-t0) > AC_AfterOpenWait
                        end
                    end
                end
            end
        end
    end)
end
