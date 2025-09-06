-- AUTO CHỌN "Phone" BẰNG CÁCH CLICK NÚT CON BÊN TRONG FRAME `Phone`
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
        if isBtnClass or (d:IsA("GuiObject") and looksLikeBtn) then
            table.insert(cands, d)
        end
    end
    -- nếu không tìm thấy gì, thử lấy tất cả GuiObject con trực tiếp
    if #cands == 0 then
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("GuiObject") then
                table.insert(cands, d)
            end
        end
    end
    return cands
end

local function clickAtGuiObject(gui)
    if not (gui and gui.AbsolutePosition and gui.AbsoluteSize) then return false, "no-abs" end
    local pos, size = gui.AbsolutePosition, gui.AbsoluteSize
    local x = pos.X + size.X/2
    local y = pos.Y + size.Y/2

    -- 1) firesignal
    if typeof(firesignal) == "function" then
        local ok = false
        pcall(function() if gui.MouseButton1Click then firesignal(gui.MouseButton1Click); ok = true end end)
        if ok then return true, "firesignal(MouseButton1Click)" end
        pcall(function() if gui.Activated then firesignal(gui.Activated); ok = true end end)
        if ok then return true, "firesignal(Activated)" end
        pcall(function()
            if gui.MouseButton1Down and gui.MouseButton1Up then
                firesignal(gui.MouseButton1Down); task.wait(0.02); firesignal(gui.MouseButton1Up); ok = true
            end
        end)
        if ok then return true, "firesignal(Down/Up)" end
    end

    -- 2) :Activate()
    local ok2 = pcall(function() if gui.Activated then gui:Activate() end end)
    if ok2 then return true, ":Activate()" end

    -- 3) VIM target = gui
    pcall(function()
        VIM:SendMouseMoveEvent(x, y, gui)
        VIM:SendMouseButtonEvent(x, y, 0, true, gui, 0)
        VIM:SendMouseButtonEvent(x, y, 0, false, gui, 0)
    end)
    task.wait(0.04)

    -- 4) VIM target = nil
    pcall(function()
        VIM:SendMouseMoveEvent(x, y, nil)
        VIM:SendMouseButtonEvent(x, y, 0, true, nil, 0)
        VIM:SendMouseButtonEvent(x, y, 0, false, nil, 0)
    end)
    task.wait(0.04)

    -- 5) Touch tap
    if UIS.TouchEnabled then
        pcall(function()
            VIM:SendTouchEvent(x, y, 0, true)
            VIM:SendTouchEvent(x, y, 0, false)
        end)
        task.wait(0.03)
    end

    return false, "vim/touch"
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

    local phoneFrame = nil
    for _=1,40 do
        phoneFrame = select(1, getPhoneFrame())
        if phoneFrame and chainVisible(phoneFrame) then break end
        task.wait(0.2)
    end
    if not phoneFrame then
        warn("[AUTO-DEVICE] Không thấy Phone frame → fallback remote.")
        fallbackRemote(); busy = false; return
    end

    warn(("[AUTO-DEVICE] PhoneFrame=%s class=%s vis=%s")
        :format(phoneFrame:GetFullName(), phoneFrame.ClassName, tostring(chainVisible(phoneFrame))))

    -- Tìm nút con
    local cands = listClickableDescendants(phoneFrame)
    if #cands == 0 then
        warn("[AUTO-DEVICE] Không tìm thấy nút con trong Phone → fallback remote.")
        fallbackRemote(); busy = false; return
    end

    -- Thử lần lượt từng candidate, mỗi cái 3 lần
    for idx, gui in ipairs(cands) do
        if not gui:IsA("GuiObject") then continue end
        warn(("[AUTO-DEVICE] Thử candidate #%d: %s (%s)")
            :format(idx, gui:GetFullName(), gui.ClassName))
        for i=1,3 do
            if chainVisible(gui) then
                local ok, how = clickAtGuiObject(gui)
                warn(("[AUTO-DEVICE]  -> lần %d: click=%s via %s")
                    :format(i, tostring(ok), how))
                task.wait(0.25)
                -- nếu DeviceSelect biến mất sau click → coi như xong
                local pf = select(1, getPhoneFrame())
                if not pf then
                    warn("[AUTO-DEVICE] DeviceSelect biến mất → ĐÃ CHỌN.")
                    busy = false
                    return
                end
            else
                warn("[AUTO-DEVICE]  -> candidate chưa visible, chờ…")
                task.wait(0.2)
            end
        end
    end

    -- Cuối cùng vẫn không được
    fallbackRemote()
    busy = false
end

-- chạy khi spawn & khi GUI xuất hiện
LP.CharacterAdded:Connect(function() task.delay(1.0, autoPickPhone) end)
if LP.Character then task.delay(1.0, autoPickPhone) end

task.spawn(function()
    local pg = LP:WaitForChild("PlayerGui", 15)
    if pg then
        pg.DescendantAdded:Connect(function(inst)
            local path = inst:GetFullName():lower()
            if path:find("playergui.deviceselect") then
                task.delay(0.1, autoPickPhone)
            end
        end)
    end
end)


