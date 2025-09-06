-- ================================================================
-- =============  MOCHI: MM2 FARM + AUTO-CRATE (FULL FIX) =========
-- - Auto chọn "Phone" (click GUI, fallback remote)
-- - Ở lobby đứng yên, chỉ farm khi CHÍNH BẠN vào map + round đang diễn ra
-- - Tween an toàn tránh kick
-- - Auto mở Crate khi đủ balls (realtime config, smart currency detect, arg-sniffer)
-- - DEBUG log rõ ràng
-- ================================================================
-- CÁCH DÙNG (đặt trước khi load file này):
-- getgenv().Config = { ["Mystery Box"] = true }
-- -- tuỳ chọn: getgenv().CurrencyPath = "Players.LocalPlayer.leaderstats.BeachBalls2025"
-- -- tuỳ chọn: getgenv().AutoCrateEnabled = true/false  (mặc định true)

local g            = game
local Players      = g:GetService("Players")
local RS           = g:GetService("ReplicatedStorage")
local TweenService = g:GetService("TweenService")
local UIS          = g:GetService("UserInputService")
local VIM          = g:GetService("VirtualInputManager")
local RunService   = g:GetService("RunService")
local LP           = Players.LocalPlayer

-- ======================== PHẦN A: AUTO CHỌN PHONE ========================
do
    local function chainVisible(gui)
        local cur = gui
        while cur and cur ~= LP do
            if cur:IsA("GuiObject") and cur.Visible == false then return false end
            if cur:IsA("ScreenGui") and cur.Enabled == false then return false end
            cur = cur.Parent
        end
        return true
    end
    local function getPhoneFrame()
        local pg = LP:WaitForChild("PlayerGui", 10)
        if not pg then return nil end
        local DS = pg:WaitForChild("DeviceSelect", 10)
        if not DS then return nil end
        local Container = DS:WaitForChild("Container", 10)
        if not Container then return nil end
        local Phone = Container:WaitForChild("Phone", 10)
        return Phone, DS
    end
    local function listClickableDescendants(root)
        local cands = {}
        for _, d in ipairs(root:GetDescendants()) do
            local cn = d.ClassName
            local n = d.Name:lower()
            local isBtnClass = (cn == "ImageButton" or cn == "TextButton")
            local looksLikeBtn = (n:find("btn") or n:find("button") or n:find("click") or n:find("hitbox") or n:find("select"))
            if isBtnClass or (d:IsA("GuiObject") and looksLikeBtn) then table.insert(cands, d) end
        end
        if #cands == 0 then
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("GuiObject") then table.insert(cands, d) end
            end
        end
        return cands
    end
    local function clickAtGuiObject(gui)
        if not (gui and gui.AbsolutePosition and gui.AbsoluteSize) then return false, "no-abs" end
        local pos, size = gui.AbsolutePosition, gui.AbsoluteSize
        local x = pos.X + size.X/2
        local y = pos.Y + size.Y/2
        if typeof(firesignal) == "function" then
            local ok=false
            pcall(function() if gui.MouseButton1Click then firesignal(gui.MouseButton1Click) ok=true end end)
            if ok then return true,"firesignal(MouseButton1Click)" end
            pcall(function() if gui.Activated then firesignal(gui.Activated) ok=true end end)
            if ok then return true,"firesignal(Activated)" end
            pcall(function()
                if gui.MouseButton1Down and gui.MouseButton1Up then
                    firesignal(gui.MouseButton1Down) task.wait(0.02) firesignal(gui.MouseButton1Up) ok=true
                end
            end)
            if ok then return true,"firesignal(Down/Up)" end
        end
        local ok2=pcall(function() if gui.Activated then gui:Activate() end end)
        if ok2 then return true,":Activate()" end
        pcall(function()
            VIM:SendMouseMoveEvent(x,y,gui)
            VIM:SendMouseButtonEvent(x,y,0,true,gui,0)
            VIM:SendMouseButtonEvent(x,y,0,false,gui,0)
        end)
        task.wait(0.04)
        pcall(function()
            VIM:SendMouseMoveEvent(x,y,nil)
            VIM:SendMouseButtonEvent(x,y,0,true,nil,0)
            VIM:SendMouseButtonEvent(x,y,0,false,nil,0)
        end)
        task.wait(0.04)
        if UIS.TouchEnabled then
            pcall(function()
                VIM:SendTouchEvent(x,y,0,true)
                VIM:SendTouchEvent(x,y,0,false)
            end)
            task.wait(0.03)
        end
        return false,"vim/touch"
    end
    local function fallbackRemote()
        pcall(function()
            RS:WaitForChild("Remotes"):WaitForChild("Extras"):WaitForChild("ChangeLastDevice"):FireServer("Phone")
        end)
    end
    local busyPick=false
    local function autoPickPhone()
        if busyPick then return end
        busyPick=true
        local phoneFrame=nil
        for _=1,40 do
            phoneFrame=select(1,getPhoneFrame())
            if phoneFrame and chainVisible(phoneFrame) then break end
            task.wait(0.2)
        end
        if not phoneFrame then fallbackRemote() busyPick=false return end
        local cands=listClickableDescendants(phoneFrame)
        if #cands==0 then fallbackRemote() busyPick=false return end
        for _,gui in ipairs(cands) do
            if gui:IsA("GuiObject") then
                for _=1,3 do
                    if chainVisible(gui) then
                        clickAtGuiObject(gui)
                        task.wait(0.25)
                        if not select(1,getPhoneFrame()) then busyPick=false return end
                    else
                        task.wait(0.2)
                    end
                end
            end
        end
        fallbackRemote()
        busyPick=false
    end
    LP.CharacterAdded:Connect(function() task.delay(1,autoPickPhone) end)
    if LP.Character then task.delay(1,autoPickPhone) end
    task.spawn(function()
        local pg=LP:WaitForChild("PlayerGui",15)
        if pg then
            pg.DescendantAdded:Connect(function(inst)
                local path=inst:GetFullName():lower()
                if path:find("playergui.deviceselect") then task.delay(0.1,autoPickPhone) end
            end)
        end
    end)
end

-- ====================== PHẦN B: LOBBY WAIT + COIN FARM =====================
do
    local function getChar()
        local char = LP.Character or LP.CharacterAdded:Wait()
        local hrp  = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
        local hum  = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid")
        return char, hrp, hum
    end
    local Char, HRP, Humanoid = getChar()
    LP.CharacterAdded:Connect(function() Char,HRP,Humanoid=getChar() end)

    local function findActiveMap()
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:GetAttribute("MapID") and obj:FindFirstChild("CoinContainer") then
                return obj
            end
        end
        return nil
    end
    local function isRoundLive()
        local ok, inRound = pcall(function()
            local gd = RS:FindFirstChild("GameData")
            local iv = gd and (gd:FindFirstChild("InRound") or gd:FindFirstChild("inRound"))
            return iv and iv.Value
        end)
        if ok and inRound ~= nil then return inRound end
        local m = findActiveMap()
        if not m then return false end
        local cc = m:FindFirstChild("CoinContainer")
        if not cc then return false end
        if #cc:GetChildren() > 0 then return true end
        local t0=os.clock()
        while os.clock()-t0<2 do
            if #cc:GetChildren()>0 then return true end
            task.wait(0.1)
        end
        return false
    end
    local function isPlayerInMap(mapModel)
        if not (mapModel and Char and HRP) then return false end
        if Char:IsDescendantOf(mapModel) then return true end
        local ok, cf, size = pcall(function() return mapModel:GetModelCFrame(), mapModel:GetExtentsSize() end)
        if ok and cf and size then
            local half=size*0.5
            local rel=cf:PointToObjectSpace(HRP.Position)
            return math.abs(rel.X)<=half.X+6 and math.abs(rel.Y)<=half.Y+6 and math.abs(rel.Z)<=half.Z+6
        end
        if mapModel.PrimaryPart then
            return (HRP.Position - mapModel.PrimaryPart.Position).Magnitude <= 150
        end
        return false
    end
    local function waitUntilYouAreInMap()
        while true do
            local m=findActiveMap()
            if m and isRoundLive() and isPlayerInMap(m) then return m end
            task.wait(0.25)
        end
    end
    local function getNearest(mapModel)
        local cc = mapModel and mapModel:FindFirstChild("CoinContainer")
        if not cc then return nil end
        local closest,dist=nil,math.huge
        for _,coin in ipairs(cc:GetChildren()) do
            if coin and coin:IsA("BasePart") then
                local v=coin:FindFirstChild("CoinVisual")
                if v and not v:GetAttribute("Collected") then
                    local d=(HRP.Position-coin.Position).Magnitude
                    if d<dist then closest,dist=coin,d end
                end
            end
        end
        return closest
    end
    local function tweenTo(part)
        if not (HRP and part and part.CFrame) then return end
        if Humanoid then Humanoid:ChangeState(Enum.HumanoidStateType.Physics) end
        local d=(HRP.Position-part.Position).Magnitude
        local t=math.clamp(d/25,0.10,2.0)
        local tw=TweenService:Create(HRP,TweenInfo.new(t,Enum.EasingStyle.Linear),{CFrame=part.CFrame})
        tw:Play() tw.Completed:Wait()
    end
    task.spawn(function()
        task.wait(0.5)
        while true do
            local currentMap=waitUntilYouAreInMap()
            while isRoundLive() and currentMap and currentMap.Parent and isPlayerInMap(currentMap) do
                if not (Char and HRP and Humanoid) then Char,HRP,Humanoid=getChar() end
                local target=getNearest(currentMap)
                if target then
                    tweenTo(target)
                    local v=target:FindFirstChild("CoinVisual")
                    local t0=os.clock()
                    while isRoundLive() and isPlayerInMap(currentMap) and v and v.Parent and not v:GetAttribute("Collected") do
                        local n=getNearest(currentMap)
                        if n and n~=target then break end
                        if os.clock()-t0>2.5 then break end
                        task.wait(0.05)
                    end
                else
                    task.wait(0.15)
                end
            end
            task.wait(0.5)
        end
    end)
end

-- ======================= PHẦN C: AUTO-CRATE (FIX+) ========================
do
    local DEBUG = true
    local function dprint(...) if DEBUG then print("[Crate]", ...) end end
    local function dwarn(...)  if DEBUG then warn("[Crate]", ...)  end end

    -- Ngưỡng & nhịp kiểm tra
    local AC_MinBalls, AC_CheckInterval, AC_AfterOpenWait = 800, 0.8, 0.9

    -- Map tên hiển thị → tham số server (bạn có thể bổ sung)
    local AC_BOX_DEFS = {
        ["mystery box"]     = { crateId = "Summer2025Box", crateType = "MysteryBox" },
        ["summer 2025 box"] = { crateId = "Summer2025Box", crateType = "MysteryBox" },
    }
    local function norm(s)
        if type(s)~="string" then return "" end
        s=s:gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$","")
        return s:lower()
    end

    -- Remotes & arg sniffer
    local Remotes   = RS:WaitForChild("Remotes")
    local Shop      = Remotes:WaitForChild("Shop")
    local OpenCrate = Shop:WaitForChild("OpenCrate")
    dprint("OpenCrate:", OpenCrate.ClassName)

    local SNIFF_ARGS = nil
    -- Nếu executor hỗ trợ hookfunction, ta bọc để bắt arg khi bạn click OPEN thủ công
    pcall(function()
        local mt = getrawmetatable(OpenCrate)
        if hookfunction and OpenCrate.InvokeServer then
            local old = OpenCrate.InvokeServer
            OpenCrate.InvokeServer = hookfunction(old, function(self, crateId, crateType, currencyKey, ...)
                SNIFF_ARGS = {crateId, crateType, currencyKey}
                dprint("Sniff Invoke args:", crateId, crateType, currencyKey)
                return old(self, crateId, crateType, currencyKey, ...)
            end)
        end
        if hookfunction and OpenCrate.FireServer then
            local oldf = OpenCrate.FireServer
            OpenCrate.FireServer = hookfunction(oldf, function(self, crateId, crateType, currencyKey, ...)
                SNIFF_ARGS = {crateId, crateType, currencyKey}
                dprint("Sniff Fire args:", crateId, crateType, currencyKey)
                return oldf(self, crateId, crateType, currencyKey, ...)
            end)
        end
    end)

    -- ====== Currency detector (ưu tiên path → Value holder → UI Smart Scan) ======
    local currencyGetter, currencySourceDesc, currencySignalConn
    local cachedBalls = 0
    local function setCached(v) cachedBalls = tonumber(v or 0) or 0 end

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

    local function install_currency_getter()
        -- 1) Path chỉ định
        local path = rawget(getgenv(), "CurrencyPath")
        if type(path) == "string" and #path > 0 then
            local root = g
            local first = path:match("^[^%.]+")
            if first == "ReplicatedStorage" then root = RS end
            if first == "Players" then root = Players end
            if first == "LocalPlayer" or first == "Player" then root = LP; path = path:gsub("^[^%.]+%.","") end
            local inst = resolve_path(root, path)
            if inst and (inst:IsA("IntValue") or inst:IsA("NumberValue")) then
                currencyGetter     = function() return inst.Value end
                currencySourceDesc = inst:GetFullName()
                setCached(inst.Value)
                if currencySignalConn then currencySignalConn:Disconnect() end
                currencySignalConn = inst:GetPropertyChangedSignal("Value"):Connect(function()
                    setCached(inst.Value)
                end)
                dprint("Currency via Value:", currencySourceDesc, "->", inst.Value)
                return true
            elseif inst then
                dwarn("CurrencyPath không phải Int/NumberValue:", inst.ClassName)
            else
                dwarn("Không resolve được CurrencyPath:", path)
            end
        end

        -- 2) Holder trong LP → RS
        local hints = {"beachballs2025","beachballs","beachball","balls","ball","beach"}
        local holder, how = find_number_value(LP, hints)
        if not holder then holder, how = find_number_value(RS, hints) end
        if holder then
            if how == "Value" then
                currencyGetter     = function() return holder.Value end
                currencySourceDesc = holder:GetFullName()
                setCached(holder.Value)
                if currencySignalConn then currencySignalConn:Disconnect() end
                currencySignalConn = holder:GetPropertyChangedSignal("Value"):Connect(function()
                    setCached(holder.Value)
                end)
                dprint("Currency via Value:", currencySourceDesc, "->", holder.Value)
                return true
            else
                local att = how:match("Attribute:(.+)")
                currencyGetter     = function() return tonumber(holder:GetAttribute(att)) end
                currencySourceDesc = holder:GetFullName() .. "@" .. how
                setCached(holder:GetAttribute(att))
                dprint("Currency via Attribute:", currencySourceDesc, "->", holder:GetAttribute(att))
                return true
            end
        end

        -- 3) UI Smart Scan (lấy số LỚN NHẤT trên UI)
        local pg = LP:FindFirstChild("PlayerGui")
        if not pg then return false end
        currencyGetter = (function()
            -- quét nhanh mỗi lần gọi
            return function()
                local maxNum = 0
                for _, ui in ipairs(pg:GetDescendants()) do
                    if ui:IsA("TextLabel") or ui:IsA("TextButton") or ui:IsA("ImageLabel") then
                        local txt = ""
                        pcall(function() txt = tostring(ui.Text or ui.ContentText or "") end)
                        if txt ~= "" then
                            local num = tonumber((txt:gsub("[^%d]", "")))
                            if num and num > maxNum then maxNum = num end
                        end
                    end
                end
                return maxNum
            end
        end)()
        currencySourceDesc = "PlayerGui (UI Smart Scan: max-digit)"
        dprint("Currency via UI:", currencySourceDesc)
        return true
    end

    assert(install_currency_getter(), "Không tìm thấy nơi đọc ball. Set getgenv().CurrencyPath nếu cần.")

    -- ====== Open wrapper ======
    local CURRENCY_KEYS_TRY = { "BeachBalls2025", "BeachBalls", "Balls", nil }
    local function tryOpen(def)
        -- Nếu đã sniff được arg thật từ click tay → ưu tiên dùng
        if SNIFF_ARGS and SNIFF_ARGS[1] and SNIFF_ARGS[2] then
            local a1,a2,a3 = SNIFF_ARGS[1], SNIFF_ARGS[2], SNIFF_ARGS[3]
            local ok,ret = pcall(function()
                if OpenCrate.ClassName == "RemoteFunction" then
                    return OpenCrate:InvokeServer(a1,a2,a3)
                else
                    OpenCrate:FireServer(a1,a2,a3); return true
                end
            end)
            dprint("OpenCrate SNIFF use:", a1,a2,a3,"=>",ok,ret)
            if ok then return true end
        end

        -- Thử với def + các currencyKey gợi ý
        for _, ck in ipairs(CURRENCY_KEYS_TRY) do
            local ok, ret = pcall(function()
                if OpenCrate.ClassName == "RemoteFunction" then
                    return OpenCrate:InvokeServer(def.crateId, def.crateType, ck)
                else
                    OpenCrate:FireServer(def.crateId, def.crateType, ck); return true
                end
            end)
            dprint("OpenCrate try:", def.crateId, def.crateType, ck, "=>", ok, ret)
            if ok then return true end
            task.wait(0.05)
        end

        -- Thử bỏ currency
        local ok2, ret2 = pcall(function()
            if OpenCrate.ClassName == "RemoteFunction" then
                return OpenCrate:InvokeServer(def.crateId, def.crateType)
            else
                OpenCrate:FireServer(def.crateId, def.crateType); return true
            end
        end)
        dprint("OpenCrate try (no currency):", def.crateId, def.crateType, "=>", ok2, ret2)
        return ok2
    end

    -- Gate + isEnabled
    getgenv().AutoCrateEnabled = (getgenv().AutoCrateEnabled ~= false)
    local function isEnabled(boxNameRaw)
        local CFG = rawget(getgenv(), "Config")
        if not (getgenv().AutoCrateEnabled and type(CFG)=="table") then return false end
        return CFG[boxNameRaw] == true
    end

    -- Main loop
    task.spawn(function()
        dprint("Currency source:", currencySourceDesc)
        while task.wait(AC_CheckInterval) do
            if not getgenv().AutoCrateEnabled then continue end
            local CFG = rawget(getgenv(), "Config"); if type(CFG) ~= "table" then continue end

            local balls = tonumber((currencyGetter and currencyGetter()) or cachedBalls or 0) or 0
            dprint(("Balls=%d  Min=%d"):format(balls, AC_MinBalls))
            if balls < AC_MinBalls then continue end

            -- Duyệt các box bật trong Config
            for rawName, on in pairs(CFG) do
                if on == true then
                    local def = AC_BOX_DEFS[norm(rawName)]
                    if not def then
                        local keys = {}
                        for k,_ in pairs(AC_BOX_DEFS) do table.insert(keys, k) end
                        table.sort(keys)
                        dwarn("Box không khớp:", rawName, "→ keys hợp lệ:", table.concat(keys,", "))
                    else
                        while (tonumber((currencyGetter and currencyGetter()) or cachedBalls or 0) or 0) >= AC_MinBalls
                              and isEnabled(rawName) do
                            local ok = tryOpen(def)
                            if not ok then
                                dwarn("OpenCrate fail → break:", rawName)
                                break
                            end
                            -- chờ server trừ balls/animation
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

-- ============================ END ================================


