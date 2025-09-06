-- ================================================================
-- =============  MOCHI: MM2 FARM + AUTO-CRATE (FULL)  ============
-- - Auto chọn "Phone"
-- - Ở lobby đứng yên, chỉ farm khi bạn thực sự vào map
-- - Tween an toàn & mượt để tránh kick / khựng
-- - Auto mở Crate khi đủ balls (anti-spam flag, smart detect)
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
        if not (gui and gui.AbsolutePosition and gui.AbsoluteSize) then return false end
        local pos, size = gui.AbsolutePosition, gui.AbsoluteSize
        local x = pos.X + size.X/2
        local y = pos.Y + size.Y/2
        pcall(function() if gui.MouseButton1Click then firesignal(gui.MouseButton1Click) end end)
        pcall(function() if gui.Activated then firesignal(gui.Activated) end end)
        pcall(function()
            VIM:SendMouseMoveEvent(x,y,gui)
            VIM:SendMouseButtonEvent(x,y,0,true,gui,0)
            VIM:SendMouseButtonEvent(x,y,0,false,gui,0)
        end)
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
end

-- ====================== PHẦN B: LOBBY WAIT + COIN FARM =====================
do
    local function getChar()
        local char = LP.Character or LP.CharacterAdded:Wait()
        local hrp  = char:WaitForChild("HumanoidRootPart")
        local hum  = char:FindFirstChildOfClass("Humanoid")
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
    end
    local function isRoundLive()
        local gd = RS:FindFirstChild("GameData")
        local iv = gd and (gd:FindFirstChild("InRound") or gd:FindFirstChild("inRound"))
        return iv and iv.Value or false
    end
    local function isPlayerInMap(mapModel)
        if not (mapModel and Char and HRP) then return false end
        return Char:IsDescendantOf(mapModel)
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
        local d=(HRP.Position-part.Position).Magnitude
        if d<5 then return end -- quá gần bỏ qua, mượt hơn
        local t=math.clamp(d/20,0.2,3.0) -- tốc độ ~20 stud/s
        local tw=TweenService:Create(HRP,TweenInfo.new(t,Enum.EasingStyle.Linear),{CFrame=part.CFrame})
        tw:Play() tw.Completed:Wait()
        task.wait(0.05)
    end
    task.spawn(function()
        task.wait(0.5)
        while true do
            local currentMap=waitUntilYouAreInMap()
            while isRoundLive() and currentMap and isPlayerInMap(currentMap) do
                if not (Char and HRP) then Char,HRP,Humanoid=getChar() end
                local target=getNearest(currentMap)
                if target then
                    tweenTo(target)
                else
                    task.wait(0.15)
                end
            end
            task.wait(0.5)
        end
    end)
end

-- ======================= PHẦN C: AUTO-CRATE (ANTI-SPAM) ===================
do
    local DEBUG = true
    local function dprint(...) if DEBUG then print("[Crate]", ...) end end

    local AC_MinBalls, AC_CheckInterval, AC_AfterOpenWait = 800, 0.8, 0.9
    local AC_BOX_DEFS = {
        ["mystery box"]     = { crateId = "Summer2025Box", crateType = "MysteryBox" },
    }
    local function norm(s) return (s or ""):lower() end

    local Remotes = RS:WaitForChild("Remotes")
    local Shop    = Remotes:WaitForChild("Shop")
    local OpenCrate = Shop:WaitForChild("OpenCrate")

    -- currency đọc từ UI (simple fallback)
    local function currencyGetter()
        local pg=LP:FindFirstChild("PlayerGui")
        if not pg then return 0 end
        local maxNum=0
        for _,ui in ipairs(pg:GetDescendants()) do
            if ui:IsA("TextLabel") or ui:IsA("TextButton") then
                local num=tonumber((tostring(ui.Text or ""):gsub("[^%d]","")))
                if num and num>maxNum then maxNum=num end
            end
        end
        return maxNum
    end

    local function tryOpen(def)
        local ok,ret = pcall(function()
            return OpenCrate:InvokeServer(def.crateId,def.crateType,"BeachBalls2025")
        end)
        dprint("OpenCrate:",def.crateId,def.crateType,"=>",ok,ret)
        return ok
    end

    getgenv().AutoCrateEnabled = (getgenv().AutoCrateEnabled ~= false)
    local function isEnabled(boxNameRaw)
        local CFG=rawget(getgenv(),"Config")
        return getgenv().AutoCrateEnabled and type(CFG)=="table" and CFG[boxNameRaw]==true
    end

    local isOpening=false
    task.spawn(function()
        while task.wait(AC_CheckInterval) do
            if isOpening then continue end
            if not getgenv().AutoCrateEnabled then continue end
            local CFG=rawget(getgenv(),"Config"); if type(CFG)~="table" then continue end

            local balls=currencyGetter()
            if DEBUG then dprint("Balls=",balls) end
            if balls<AC_MinBalls then continue end

            for rawName,on in pairs(CFG) do
                if on==true then
                    local def=AC_BOX_DEFS[norm(rawName)]
                    if def then
                        isOpening=true
                        while currencyGetter()>=AC_MinBalls and isEnabled(rawName) do
                            local ok=tryOpen(def)
                            if not ok then break end
                            task.wait(AC_AfterOpenWait)
                        end
                        isOpening=false
                    end
                end
            end
        end
    end)
end

-- ============================ END ================================


