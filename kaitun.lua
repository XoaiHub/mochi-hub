--// AUTO CHỌN "Phone" BẰNG CÁCH CLICK NÚT GUI
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local VIM = game:GetService("VirtualInputManager")
local LP = Players.LocalPlayer

local trying = false

local function getPhoneButton(timeout)
    local t0 = tick()
    local pg = LP:WaitForChild("PlayerGui", 10)
    if not pg then return nil end

    local DS = pg:WaitForChild("DeviceSelect", 10)
    if not DS then return nil end

    local Container = DS:WaitForChild("Container", 10)
    if not Container then return nil end

    local Phone = Container:WaitForChild("Phone", 10)
    if not Phone then return nil end

    return Phone, DS
end

local function isVisible(btn)
    -- kiểm tra chuỗi Visible/Enabled của các parent
    local gui = btn
    while gui and gui ~= LP do
        if gui:IsA("GuiObject") then
            if gui.Visible == false then return false end
        elseif gui:IsA("ScreenGui") then
            if gui.Enabled == false then return false end
        end
        gui = gui.Parent
    end
    return true
end

local function click(btn)
    -- 1) firesignal vào các sự kiện phổ biến
    local ok = false
    pcall(function()
        if firesignal then
            if btn.MouseButton1Click then firesignal(btn.MouseButton1Click); ok = true end
            if not ok and btn.Activated then firesignal(btn.Activated); ok = true end
            if not ok and btn.MouseButton1Down then firesignal(btn.MouseButton1Down); firesignal(btn.MouseButton1Up); ok = true end
        end
    end)
    if ok then return true, "firesignal" end

    -- 2) :Activate() (nếu hỗ trợ)
    local ok2 = pcall(function() if btn.Activated then btn:Activate() end end)
    if ok2 then return true, "Activate()" end

    -- 3) VirtualInputManager click giữa nút
    local pos, size = btn.AbsolutePosition, btn.AbsoluteSize
    if pos and size then
        local x = pos.X + size.X/2
        local y = pos.Y + size.Y/2
        pcall(function()
            VIM:SendMouseButtonEvent(x, y, 0, true, btn, 0)
            VIM:SendMouseButtonEvent(x, y, 0, false, btn, 0)
        end)
        return true, "VIM"
    end

    return false, "no-method"
end

local function autoClickPhone()
    if trying then return end
    trying = true

    local btn, screen = getPhoneButton(15)
    if not btn then
        warn("[AUTO-DEVICE] Không tìm thấy nút Phone.")
        trying = false
        return
    end

    -- thử tối đa 10 lần (UI đôi khi spawn xong nhưng chưa cho bấm)
    for i=1,10 do
        if isVisible(btn) then
            local ok, how = click(btn)
            if ok then
                warn(("[AUTO-DEVICE] Đã click nút Phone bằng %s (lần %d)."):format(how, i))
                trying = false
                return
            else
                warn(("[AUTO-DEVICE] Click thất bại (%s) lần %d."):format(how, i))
            end
        else
            warn("[AUTO-DEVICE] Nút Phone chưa visible/enabled, đợi...")
        end
        task.wait(0.4 + i*0.05)
    end

    -- Fallback: gọi trực tiếp remote nếu vẫn chưa được
    local okRemote = pcall(function()
        RS:WaitForChild("Remotes"):WaitForChild("Extras"):WaitForChild("ChangeLastDevice"):FireServer("Phone")
    end)
    warn("[AUTO-DEVICE] Fallback ChangeLastDevice('Phone') ->", okRemote)
    trying = false
end

-- chạy khi spawn và khi GUI xuất hiện trễ
LP.CharacterAdded:Connect(function() task.delay(1.0, autoClickPhone) end)
if LP.Character then task.delay(1.0, autoClickPhone) end

-- nếu GUI spawn muộn
task.spawn(function()
    local pg = LP:WaitForChild("PlayerGui", 15)
    if pg then
        pg.DescendantAdded:Connect(function(inst)
            if tostring(inst:GetFullName()):lower():find("deviceselect") then
                task.delay(0.1, autoClickPhone)
            end
        end)
    end
end)
