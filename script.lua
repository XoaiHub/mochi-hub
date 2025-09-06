-- AUTO CHỌN "Phone" (đa phương pháp + debug)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local LP = Players.LocalPlayer

local function chainVisible(gui)
    local cur = gui
    while cur and cur ~= LP do
        if cur:IsA("GuiObject") and cur.Visible == false then return false end
        if cur:IsA("ScreenGui") and cur.Enabled == false then return false end
        cur = cur.Parent
    end
    return true
end

local function getPhoneButton()
    local pg = LP:WaitForChild("PlayerGui", 10)
    if not pg then return nil end
    local DS = pg:FindFirstChild("DeviceSelect") or pg:FindFirstChildWhichIsA("ScreenGui", true)
    if not DS then return nil end
    local Container = DS:FindFirstChild("Container", true)
    if not Container then return nil end
    local Phone = Container:FindFirstChild("Phone", true)
    return Phone, DS
end

local function debugBtn(btn)
    local ok = btn and btn.AbsolutePosition and btn.AbsoluteSize
    warn(("[AUTO-DEVICE] btn=%s class=%s vis=%s pos=%s size=%s")
        :format(btn and btn:GetFullName() or "nil",
                btn and btn.ClassName or "nil",
                tostring(btn and chainVisible(btn)),
                ok and (btn.AbsolutePosition.X .. "," .. btn.AbsolutePosition.Y) or "nil",
                ok and (btn.AbsoluteSize.X .. "x" .. btn.AbsoluteSize.Y) or "nil"))
end

local function clickAllWays(btn)
    local tried = {}

    -- 0) chuẩn bị toạ độ
    local pos, size = btn.AbsolutePosition, btn.AbsoluteSize
    local x = pos.X + size.X/2
    local y = pos.Y + size.Y/2

    -- 1) firesignal các sự kiện GUI
    if typeof(firesignal) == "function" then
        local ok = false
        pcall(function()
            if btn.MouseButton1Click then firesignal(btn.MouseButton1Click); ok = true end
        end)
        if ok then table.insert(tried, "firesignal(MouseButton1Click)"); return true, table.concat(tried,", ") end

        pcall(function()
            if btn.Activated then firesignal(btn.Activated); ok = true end
        end)
        if ok then table.insert(tried, "firesignal(Activated)"); return true, table.concat(tried,", ") end

        pcall(function()
            if btn.MouseButton1Down and btn.MouseButton1Up then
                firesignal(btn.MouseButton1Down); task.wait(0.02); firesignal(btn.MouseButton1Up)
                ok = true
            end
        end)
        if ok then table.insert(tried, "firesignal(Down/Up)"); return true, table.concat(tried,", ") end
    end

    -- 2) :Activate()
    local ok2 = pcall(function() if btn.Activated then btn:Activate() end end)
    if ok2 then table.insert(tried, ":Activate()"); return true, table.concat(tried,", ") end

    -- 3) VIM: di chuột rồi click (target = btn)
    pcall(function()
        VIM:SendMouseMoveEvent(x, y, btn)
        VIM:SendMouseButtonEvent(x, y, 0, true, btn, 0)
        VIM:SendMouseButtonEvent(x, y, 0, false, btn, 0)
    end)
    table.insert(tried, "VIM(target=btn)")
    task.wait(0.05)
    if not btn or not btn.Parent then return true, table.concat(tried,", ") end

    -- 4) VIM: di chuột rồi click (target = nil)
    pcall(function()
        VIM:SendMouseMoveEvent(x, y, nil)
        VIM:SendMouseButtonEvent(x, y, 0, true, nil, 0)
        VIM:SendMouseButtonEvent(x, y, 0, false, nil, 0)
    end)
    table.insert(tried, "VIM(target=nil)")
    task.wait(0.05)

    -- 5) Giả lập **touch tap**
    if UIS.TouchEnabled then
        pcall(function()
            VIM:SendTouchEvent(x, y, 0, true)
            VIM:SendTouchEvent(x, y, 0, false)
        end)
        table.insert(tried, "TouchTap")
        task.wait(0.05)
    end

    return false, table.concat(tried,", ")
end

local function fallbackRemote()
    local ok = pcall(function()
        RS:WaitForChild("Remotes"):WaitForChild("Extras"):WaitForChild("ChangeLastDevice"):FireServer("Phone")
    end)
    warn("[AUTO-DEVICE] Fallback ChangeLastDevice('Phone') ->", ok)
    return ok
end

local busy = false
local function autoPickPhone()
    if busy then return end
    busy = true

    local btn = nil
    for t=1,40 do
        btn = select(1, getPhoneButton())
        if btn and chainVisible(btn) then break end
        task.wait(0.2)
    end

    if not btn then
        warn("[AUTO-DEVICE] Không tìm thấy/không visible nút Phone → thử fallback remote.")
        fallbackRemote()
        busy = false
        return
    end

    debugBtn(btn)

    -- Thử 12 lần, mỗi lần 0.25–0.4s
    for i=1,12 do
        if not chainVisible(btn) then
            warn("[AUTO-DEVICE] Nút không visible ở lần "..i.." → chờ.")
            task.wait(0.25 + i*0.02)
        else
            local ok, how = clickAllWays(btn)
            warn(("[AUTO-DEVICE] Lần %02d → click=%s via [%s]"):format(i, tostring(ok), how))
            task.wait(0.35)
            -- nếu Screen biến mất hoặc Container/Phone biến mất coi như thành công
            local stillBtn = select(1, getPhoneButton())
            if not stillBtn then
                warn("[AUTO-DEVICE] GUI DeviceSelect biến mất → coi như ĐÃ CHỌN.")
                busy = false
                return
            end
        end
    end

    -- Cuối cùng vẫn chưa → bắn remote
    fallbackRemote()
    busy = false
end

-- Hook thời điểm hợp lý
local LPc = LP.Character or LP.CharacterAdded:Wait()
LP.CharacterAdded:Connect(function() task.delay(1, autoPickPhone) end)
task.delay(1, autoPickPhone)

-- nếu GUI spawn muộn
task.spawn(function()
    local pg = LP:WaitForChild("PlayerGui", 15)
    if pg then
        pg.DescendantAdded:Connect(function(inst)
            local name = tostring(inst:GetFullName()):lower()
            if name:find("deviceselect") or name:find(".phone") then
                task.delay(0.1, autoPickPhone)
            end
        end)
    end
end)


