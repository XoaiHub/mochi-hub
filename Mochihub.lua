-- LocalScript -> StarterPlayerScripts
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local lp = Players.LocalPlayer

local function buildUI()
    local pg = lp:WaitForChild("PlayerGui")

    -- xoá bản cũ nếu có
    local old = pg:FindFirstChild("AyaLikeUI")
    if old then old:Destroy() end

    -- ScreenGui
    local gui = Instance.new("ScreenGui")
    gui.Name = "AyaLikeUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 1000
    gui.Parent = pg

    -- ==== Khối nội dung cần ẩn/hiện ====
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.fromScale(1,1)
    content.BackgroundColor3 = Color3.fromRGB(255,255,255) -- nền trắng
    content.Parent = gui

    -- Nhóm chữ giữa trên
    local group = Instance.new("Frame")
    group.BackgroundTransparency = 1
    group.Size = UDim2.new(0, 600, 0, 180)
    group.AnchorPoint = Vector2.new(0.5, 0)
    group.Position = UDim2.new(0.5, 0, 0.02, 0)
    group.Parent = content

    local layout = Instance.new("UIListLayout", group)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.Padding = UDim.new(0, 8)

    local function makeLabel(text, height, color, weight)
        local lb = Instance.new("TextLabel")
        lb.BackgroundTransparency = 1
        lb.Size = UDim2.new(1, 0, 0, height)
        lb.Text = text
        lb.TextColor3 = color
        lb.FontFace = Font.new(
            "rbxasset://fonts/families/GothamSSm.json",
            Enum.FontWeight[weight or "Medium"],
            Enum.FontStyle.Normal
        )
        lb.TextScaled = true
        lb.Parent = group
        return lb
    end

    makeLabel("Aya Gag", 80, Color3.fromRGB(0,0,0), "Medium")
    makeLabel("ALO KUB", 46, Color3.fromRGB(50,50,50), "Medium")
    makeLabel("Made With Love", 52, Color3.fromRGB(100,100,100), "Medium")

    -- ===== Nút Toggle luôn hiển thị =====
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleBtn"
    toggleBtn.Size = UDim2.new(0, 64, 0, 40)
    toggleBtn.Position = UDim2.new(0, 24, 0.5, -20)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(120,0,0)
    toggleBtn.Text = "OFF"
    toggleBtn.TextScaled = true
    toggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
    toggleBtn.AutoButtonColor = true
    toggleBtn.Parent = gui

    local corner = Instance.new("UICorner", toggleBtn)
    corner.CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke", toggleBtn)
    stroke.Thickness = 1.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.fromRGB(255,255,255)

    -- ==== logic bật/tắt UI ====
    local isOn = true
    local debounce = false

    local function applyState()
        content.Visible = isOn
        if isOn then
            toggleBtn.Text = "OFF"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(120,0,0)
        else
            toggleBtn.Text = "ON"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(0,120,0)
        end
    end
    applyState()

    toggleBtn.MouseButton1Click:Connect(function()
        if debounce then return end
        debounce = true
        isOn = not isOn
        applyState()
        task.delay(0.15, function() debounce = false end)
    end)

    -- Phím tắt RightShift để toggle
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            if debounce then return end
            debounce = true
            isOn = not isOn
            applyState()
            task.delay(0.15, function() debounce = false end)
        end
    end)
end

-- Chờ game sẵn sàng rồi tạo UI
if not game:IsLoaded() then game.Loaded:Wait() end
task.defer(buildUI)

-- Tạo lại khi respawn
Players.LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    buildUI()
end)
