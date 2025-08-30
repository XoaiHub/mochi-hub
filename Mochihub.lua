-- LocalScript -> StarterPlayerScripts
local Players = game:GetService("Players")
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

    -- Nền đỏ full
    local bg = Instance.new("Frame")
    bg.Size = UDim2.fromScale(1,1)
    bg.BackgroundColor3 = Color3.fromRGB(220, 0, 0)
    bg.Parent = gui

    -- Nhóm chữ giữa trên
    local group = Instance.new("Frame")
    group.BackgroundTransparency = 1
    group.Size = UDim2.new(0, 600, 0, 180)
    group.AnchorPoint = Vector2.new(0.5, 0)
    group.Position = UDim2.new(0.5, 0, 0.02, 0)
    group.Parent = bg

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
        lb.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json",
                               Enum.FontWeight[weight or "Medium"], Enum.FontStyle.Normal)
        lb.TextScaled = true
        lb.Parent = group
        return lb
    end

    makeLabel("Aya Gag", 80, Color3.fromRGB(255,255,255), "Medium")
    makeLabel("ALO KUB", 46, Color3.fromRGB(255,210,210), "Medium")
    makeLabel("Made With Love", 52, Color3.fromRGB(255,190,190), "Medium")

    -- Nút OFF bên trái
    local offBtn = Instance.new("TextButton")
    offBtn.Size = UDim2.new(0, 56, 0, 36)
    offBtn.Position = UDim2.new(0, 76, 0.5, -18)
    offBtn.BackgroundColor3 = Color3.fromRGB(120,0,0)
    offBtn.Text = "OFF"
    offBtn.TextScaled = true
    offBtn.TextColor3 = Color3.fromRGB(255,255,255)
    offBtn.AutoButtonColor = true
    offBtn.Parent = bg

    Instance.new("UICorner", offBtn).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", offBtn)
    stroke.Thickness = 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.fromRGB(255,255,255)
end

-- Chờ game sẵn sàng rồi tạo UI
if not game:IsLoaded() then game.Loaded:Wait() end
task.defer(buildUI)

-- Tạo lại khi respawn
Players.LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    buildUI()
end)
