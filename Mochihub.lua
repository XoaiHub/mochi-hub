-- ================================================================
-- =============  MOCHI: BALL FARM + AUTO-CRATE (FULL) ============
-- - Auto chọn "Phone"
-- - Ở lobby đứng yên, chỉ farm khi bạn vào map
-- - Tween mượt để tránh kick/khựng
-- - Auto mở Crate khi đủ ball (anti-spam flag, smart detect)
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
            if cur:IsA("GuiObject") and not cur.Visible then return false end
            if cur:IsA("ScreenGui") and not cur.Enabled then return false end
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
    local function clickAtGuiObject(gui)
        if not (gui and gui.AbsolutePosition and gui.AbsoluteSize) then return end
        local pos, size = gui.AbsolutePosition, gui.AbsoluteSize
        local x, y = pos.X+size.X/2, pos.Y+size.Y/2
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
        clickAtGuiObject(phoneFrame) -- thử click
        if select(1,getPhoneFrame()) then fallbackRemote() end
        busyPick=false
    end
    LP.CharacterAdded:Connect(function() task.delay(1,autoPickPhone) end)
    if LP.Character then task.delay(1,autoPickPhone) end
end

-- ====================== PHẦN B: LOBBY WAIT + BALL FARM ===================
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
            if obj:GetAttribute("MapID") then return obj end
        end
    end
    local function isPlayerInMap(mapModel)
        if not (mapModel and Char and HRP) then return false end
        return Char:IsDescendantOf(mapModel)
    end
    local function waitUntilYouAreInMap()
        while true do
            local m=findActiveMap()
            if m and isPlayerInMap(m) then return m end
            task.wait(0.25)
        end
    end
    -- lấy ball gần nhất
    local function getNearestBall(mapModel)
        local cc = mapModel:FindFirstChild("BallContainer") or mapModel:FindFirstChild("Balls") or mapModel:FindFirstChild("BeachBalls")
        if not cc then return nil end
        local closest,dist=nil,math.huge
        for _,ball in ipairs(cc:GetChildren()) do
            if ball:IsA("BasePart") then
                local d=(HRP.Position-ball.Position).Magnitude
                if d<dist then closest,dist=ball,d end
            end
        end
        return closest
    end
    -- tween mượt
    local function tweenTo(part)
        if not (HRP and part and part.CFrame) then return end
        local d=(HRP.Position-part.Position).Magnitude
        if d<5 then return end
        local t=math.clamp(d/20,0.2,3.0) -- tốc độ 20 stud/s
        local tw=TweenService:Create(HRP,TweenInfo.new(t,Enum.EasingStyle.Linear),{CFrame=part.CFrame})
        tw:Play() tw.Completed:Wait()
        task.wait(0.05)
    end
    -- vòng farm
    task.spawn(function()
        task.wait(0.5)
        while true do
            local currentMap=waitUntilYouAreInMap()
            while currentMap and currentMap.Parent and isPlayerInMap(currentMap) do
                if not (Char and HRP) then Char,HRP,Humanoid=getChar() end
                local target=getNearestBall(currentMap)
                if target then
                    tweenTo(target)
                else
                    task.wait(0.2)
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
    local AC_MinBalls, AC_CheckInterval, AC_AfterOpenWait = 800, 1, 1
    local AC_BOX_DEFS = {
        ["mystery box"] = { crateId = "Summer2025Box", crateType = "MysteryBox" },
    }
    local function norm(s) return (s or ""):lower() end
    local Remotes=RS:WaitForChild("Remotes")
    local Shop=Remotes:WaitForChild("Shop")
    local OpenCrate=Shop:WaitForChild("OpenCrate")
    -- currency lấy từ UI (smart scan max số)
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
        local ok,ret=pcall(function()
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
            dprint("Balls=",balls)
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


