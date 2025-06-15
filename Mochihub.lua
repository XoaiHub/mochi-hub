-- Load Rayfield library
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "Mochi Hub",
    Icon = 0,
    LoadingTitle = "Mochi Hub",
    LoadingSubtitle = "by Him",
    Theme = "Default",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = nil,
        FileName = "Big Hub"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    },
    KeySystem = false,
    KeySettings = {
        Title = "Untitled",
        Subtitle = "Key System",
        Note = "No method of obtaining the key is provided",
        FileName = "Key",
        SaveKey = true,
        GrabKeyFromSite = false,
        Key = {"Hello"}
    }
})

-- Create Tabs in the Rayfield UI
local MainTab = Window:CreateTab("⚔️ Main", nil)
local AutoBondTab = Window:CreateTab("Auto Bond", nil)
local AIMTab = Window:CreateTab("🧲 Aim Bot", nil)
local ESPTab = Window:CreateTab("💣 ESP", nil)
local SetiingTab = Window:CreateTab("⚙️ Settings", nil)

-- Game Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

-- Aimbot Variables
local fov = 136
local isAiming = false
local validNPCs = {}
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

local FOVring = Drawing.new("Circle")
FOVring.Visible = false
FOVring.Thickness = 2
FOVring.Color = Color3.fromRGB(128, 0, 128)
FOVring.Filled = false
FOVring.Radius = fov
FOVring.Position = Camera.ViewportSize / 2

-- ESP Variables
local espEnabled = false
local targetItems = {
    ["RevolverAmmo"] = CFrame.new(134.093811, 3.32812667, 29850.623),
    ["Prop_GoldBar"] = CFrame.new(141.93512, 0.845499456, 29925.3711),
    ["Prop_SivelBar"] = CFrame.new(-28.6093884, 3.48437667, 27465.0605),
    ["ShotgunShells"] = CFrame.new(150.9573516845703, 5.8973283767700195, 29840.47265625),
    ["RifleAmmo"] = CFrame.new(142.2073516845703, 5.897316932678223, 29840.47265625),
    ["Coal"] = CFrame.new(148.3759765625, 6.4521484375, 29784.201171875),
}

-- Functions for Aimbot

local function isNPC(obj)
    return obj:IsA("Model") 
        and obj:FindFirstChild("Humanoid")
        and obj.Humanoid.Health > 0
        and obj:FindFirstChild("Head")
        and obj:FindFirstChild("HumanoidRootPart")
        and not game:GetService("Players"):GetPlayerFromCharacter(obj)
end

local function updateNPCs()
    local tempTable = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isNPC(obj) then
            tempTable[obj] = true
        end
    end
    for i = #validNPCs, 1, -1 do
        if not tempTable[validNPCs[i]] then
            table.remove(validNPCs, i)
        end
    end
    for obj in pairs(tempTable) do
        if not table.find(validNPCs, obj) then
            table.insert(validNPCs, obj)
        end
    end
end

local function getTarget()
    local nearest = nil
    local minDistance = math.huge
    local viewportCenter = Camera.ViewportSize / 2
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    for _, npc in ipairs(validNPCs) do
        local screenPos, visible = Camera:WorldToViewportPoint(npc.HumanoidRootPart.Position)
        if visible and screenPos.Z > 0 then
            local ray = workspace:Raycast(
                Camera.CFrame.Position,
                (npc.HumanoidRootPart.Position - Camera.CFrame.Position).Unit * 1000,
                raycastParams
            )
            if ray and ray.Instance:IsDescendantOf(npc) then
                local distance = (Vector2.new(screenPos.X, screenPos.Y) - viewportCenter).Magnitude
                if distance < minDistance and distance < fov then
                    minDistance = distance
                    nearest = npc
                end
            end
        end
    end
    return nearest
end

local function aim(targetPosition)
    local currentCF = Camera.CFrame
    local targetDirection = (targetPosition - currentCF.Position).Unit
    local smoothFactor = 0.581
    local newLookVector = currentCF.LookVector:Lerp(targetDirection, smoothFactor)
    Camera.CFrame = CFrame.new(currentCF.Position, currentCF.Position + newLookVector)
end

-- Aimbot Update Loop
RunService.Heartbeat:Connect(function(dt)
    if isAiming then
        updateNPCs()
        local target = getTarget()
        if target then
            aim(target.HumanoidRootPart.Position)
        end
    end
end)

-- Toggle Button for Aimbot in Rayfield UI
AIMTab:CreateToggle({
    Name = "Aimbot",
    CurrentValue = false,
    Flag = "AimbotToggle",
    Callback = function(value)
        isAiming = value
        FOVring.Visible = isAiming
        print("Aimbot: " .. (isAiming and "ON" or "OFF"))
    end
})

-- Functions for ESP

local function createDistanceESP(part, itemName)
    if part:FindFirstChild("ESPArrow") then return end

    local distanceGui = Instance.new("BillboardGui")
    distanceGui.Name = "ESPArrow"
    distanceGui.Size = UDim2.new(0, 120, 0, 60)
    distanceGui.AlwaysOnTop = true
    distanceGui.Adornee = part

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Text = itemName
    nameLabel.Parent = distanceGui

    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.Size = UDim2.new(1, 0, 0.5, 0)
    distanceLabel.Position = UDim2.new(0, 0, 0.5, 0)
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    distanceLabel.TextScaled = true
    distanceLabel.Font = Enum.Font.Gotham
    distanceLabel.Name = "DistanceLabel"
    distanceLabel.Parent = distanceGui

    distanceGui.Parent = part

    local attachment0 = Instance.new("Attachment", part)
    attachment0.Name = "ItemAttachment"

    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local rootPart = character:WaitForChild("HumanoidRootPart")

    local attachment1 = rootPart:FindFirstChild("PlayerAttachment") or Instance.new("Attachment")
    attachment1.Name = "PlayerAttachment"
    attachment1.Parent = rootPart

    local beam = Instance.new("Beam")
    beam.Name = "ESPBeam"
    beam.Attachment0 = attachment0
    beam.Attachment1 = attachment1
    beam.Width0 = 0.1
    beam.Width1 = 0.1
    beam.FaceCamera = true
    beam.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0))
    beam.Transparency = NumberSequence.new(0)
    beam.Parent = part

    -- Continuous update for ESP distance
    task.spawn(function()
        while espEnabled and part:IsDescendantOf(workspace) do
            local dist = (rootPart.Position - part.Position).Magnitude
            local display = dist > 1000 and string.format("%.2f km", dist / 1000) or string.format("%.1f m", dist)
            distanceLabel.Text = display
            task.wait(0.5)
        end

        -- Cleanup ESP
        distanceGui:Destroy()
        beam:Destroy()
        attachment0:Destroy()
        attachment1:Destroy()
    end)
end

-- Toggle Button for ESP in Rayfield UI
ESPTab:CreateToggle({
    Name = "ESP Items",
    CurrentValue = false,
    Flag = "ESPItemsToggle",
    Callback = function(value)
        espEnabled = value
        print("ESP Items: " .. (espEnabled and "ON" or "OFF"))
        if espEnabled then
            -- Create ESP for target items
            for _, v in pairs(workspace:GetDescendants()) do
                if v:IsA("BasePart") and targetItems[v.Name] then
                    local expectedPos = targetItems[v.Name].Position
                    if v.CFrame.Position:FuzzyEq(expectedPos, 1) then
                        createDistanceESP(v, v.Name)
                    end
                end
            end
        else
            -- Remove ESP
            for _, v in pairs(workspace:GetDescendants()) do
                if v:IsA("BasePart") and targetItems[v.Name] then
                    if v:FindFirstChild("ESPArrow") then v.ESPArrow:Destroy() end
                    if v:FindFirstChild("ESPBeam") then v.ESPBeam:Destroy() end
                    if v:FindFirstChild("ItemAttachment") then v.ItemAttachment:Destroy() end
                end
            end
        end
    end
})
-- Biến & service
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local isAttacking = false

-- Hàm trang bị tool
local function equipItem(name)
    local tool = LocalPlayer.Backpack:FindFirstChild(name)
    if tool then
        LocalPlayer.Character.Humanoid:EquipTool(tool)
        print(name .. " đã được trang bị!")
    else
        warn(name .. " không tồn tại trong Backpack!")
    end
end

-- Hàm bỏ tool (unequip)
local function unequipItem()
    LocalPlayer.Character.Humanoid:UnequipTools()
    print("Đã bỏ trang bị!")
end

-- Toggle bật/tắt tự đánh
local Toggle = MainTab:CreateToggle({
    Name = "Melle",
    CurrentValue = false,
    Flag = "Toggle1",
    Callback = function(Value)
        isAttacking = Value
        if Value then
            equipItem("Shovel")
        else
            unequipItem()
        end
        print("Melle toggle:", Value and "Bật" or "Tắt")
    end,
})

-- Tham số cho SwingEvent
local args = {
    [1] = Vector3.new(0.52230304479599, 0.13523706793785095, 0.8419681787490845)
}

-- Vòng lặp tự đánh khi bật toggle
task.spawn(function()
    while true do
        if isAttacking then
            -- Kiểm tra có đang cầm Shovel không, nếu không thì trang bị lại
            if not LocalPlayer.Character:FindFirstChild("Shovel") then
                equipItem("Shovel")
            end

            -- Gửi sự kiện đánh
            LocalPlayer.Character.Shovel.SwingEvent:FireServer(unpack(args))
        end
        wait(1) -- chỉnh tốc độ đánh tại đây
    end
end)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local espEnabled = false
local Toggle = AutoBondTab:CreateToggle({
    Name = "Auto Bond",
    CurrentValue = false,
    Flag = "Toggle1",
    Callback = function(enabled)
        if enabled then
            -- Auto Bond Code Start
            task.spawn(function()
                if not game:IsLoaded() then
                    game.Loaded:Wait()
                end
                repeat task.wait() until game.Players.LocalPlayer.Character and game.Players.LocalPlayer.PlayerGui:FindFirstChild("LoadingScreenPrefab") == nil
                game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("EndDecision"):FireServer(false)

                if game.CoreGui:FindFirstChild("BondCheck") == nil then
                    local gui = Instance.new("ScreenGui", game.CoreGui)
                    gui.Name = "BondCheck"

                    local Frame = Instance.new("Frame")
                    Frame.Name = "Bond"
                    Frame.Size = UDim2.new(0.13, 0, 0.1, 0)
                    Frame.Position = UDim2.new(0.03, 0, 0.05, 0)
                    Frame.BackgroundColor3 = Color3.new(1, 1, 1)
                    Frame.BorderColor3 = Color3.new(0, 0, 0)
                    Frame.BorderSizePixel = 1
                    Frame.Active = true
                    Frame.BackgroundTransparency = 0.3
                    Frame.Draggable = true
                    Frame.Parent = gui

                    local UICorner = Instance.new("UICorner")
                    UICorner.CornerRadius = UDim.new(1, 0)
                    UICorner.Parent = Frame

                    local UIStroke = Instance.new("UIStroke")
                    UIStroke.Color = Color3.new(0, 0, 0)
                    UIStroke.Thickness = 2.3
                    UIStroke.Parent = Frame

                    local TextLabel = Instance.new("TextLabel")
                    TextLabel.Size = UDim2.new(1, 0, 1, 0)
                    TextLabel.Position = UDim2.new(0, 0, 0, 0)
                    TextLabel.BackgroundTransparency = 1
                    TextLabel.Text = "Really"
                    TextLabel.TextSize = 20
                    TextLabel.FontFace = Font.new("rbxassetid://12187372175", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
                    TextLabel.TextColor3 = Color3.new(0, 0, 0)
                    TextLabel.Parent = Frame
                end

                _G.Bond = 0
                workspace.RuntimeItems.ChildAdded:Connect(function(v)
                    if v.Name:find("Bond") and v:FindFirstChild("Part") then
                        v.Destroying:Connect(function()
                            _G.Bond += 1
                        end)
                    end
                end)

                spawn(function()
                    repeat task.wait()
                        local textLabel = game.CoreGui:FindFirstChild("BondCheck") and game.CoreGui.BondCheck:FindFirstChild("Bond") and game.CoreGui.BondCheck.Bond:FindFirstChild("TextLabel")
                        if textLabel then
                            textLabel.Text = "Bond (+" .. _G.Bond .. ")"
                        end
                    until game.CoreGui:FindFirstChild("BondCheck") == nil
                end)

                local lp = game.Players.LocalPlayer
                local char = lp.Character or lp.CharacterAdded:Wait()

                if char:FindFirstChild("Humanoid") then
                    workspace.CurrentCamera.CameraSubject = char:FindFirstChild("Humanoid")
                end
                lp.CameraMode = "Classic"
                lp.CameraMaxZoomDistance = math.huge
                lp.CameraMinZoomDistance = 30

                local hrp = char:WaitForChild("HumanoidRootPart")
                hrp.Anchored = true

                repeat
                    task.wait()
                    hrp.Anchored = true
                    wait(0.5)
                    hrp.CFrame = CFrame.new(80, 3, -9000)
                until workspace.RuntimeItems:FindFirstChild("MaximGun")

                wait(0.3)
                for _, v in pairs(workspace.RuntimeItems:GetChildren()) do
                    if v.Name == "MaximGun" and v:FindFirstChild("VehicleSeat") then
                        v.VehicleSeat.Disabled = false
                        v.VehicleSeat:SetAttribute("Disabled", false)
                        v.VehicleSeat:Sit(char:FindFirstChild("Humanoid"))
                    end
                end

                wait(0.5)
                for _, v in pairs(workspace.RuntimeItems:GetChildren()) do
                    if v.Name == "MaximGun" and v:FindFirstChild("VehicleSeat") and (hrp.Position - v.VehicleSeat.Position).Magnitude < 400 then
                        hrp.CFrame = v.VehicleSeat.CFrame
                    end
                end

                wait(1)
                hrp.Anchored = false

                repeat wait() until char:FindFirstChild("Humanoid").Sit == true

                wait(0.5)
                char.Humanoid.Sit = false
                wait(0.5)

                repeat
                    task.wait()
                    for _, v in pairs(workspace.RuntimeItems:GetChildren()) do
                        if v.Name == "MaximGun" and v:FindFirstChild("VehicleSeat") and (hrp.Position - v.VehicleSeat.Position).Magnitude < 400 then
                            hrp.CFrame = v.VehicleSeat.CFrame
                        end
                    end
                until char.Humanoid.Sit == true

                wait(0.9)
                for _, model in pairs(workspace:GetChildren()) do
                    if model:IsA("Model") and model:FindFirstChild("RequiredComponents") then
                        local rc = model.RequiredComponents
                        if rc:FindFirstChild("Controls") and rc.Controls:FindFirstChild("ConductorSeat") and rc.Controls.ConductorSeat:FindFirstChild("VehicleSeat") then
                            local seatCF = rc.Controls.ConductorSeat.VehicleSeat.CFrame
                            local tween = game:GetService("TweenService"):Create(hrp, TweenInfo.new(25, Enum.EasingStyle.Quad), {CFrame = seatCF * CFrame.new(0, 20, 0)})
                            tween:Play()

                            if not hrp:FindFirstChild("VelocityHandler") then
                                local bv = Instance.new("BodyVelocity")
                                bv.Name = "VelocityHandler"
                                bv.Parent = hrp
                                bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                                bv.Velocity = Vector3.new(0, 0, 0)
                            end
                            tween.Completed:Wait()
                        end
                    end
                end

                wait(1)
                while true do
                    if char:FindFirstChild("Humanoid").Sit then
                        local endTween = game:GetService("TweenService"):Create(hrp, TweenInfo.new(17, Enum.EasingStyle.Quad), {CFrame = CFrame.new(0.5, -78, -49429)})
                        endTween:Play()

                        if not hrp:FindFirstChild("VelocityHandler") then
                            local bv = Instance.new("BodyVelocity")
                            bv.Name = "VelocityHandler"
                            bv.Parent = hrp
                            bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                            bv.Velocity = Vector3.new(0, 0, 0)
                        end

                        repeat task.wait() until workspace.RuntimeItems:FindFirstChild("Bond")
                        endTween:Cancel()

                        for _, bond in pairs(workspace.RuntimeItems:GetChildren()) do
                            if bond.Name:find("Bond") and bond:FindFirstChild("Part") then
                                repeat task.wait()
                                    if bond:FindFirstChild("Part") then
                                        hrp.CFrame = bond.Part.CFrame
                                        game:GetService("ReplicatedStorage").Shared.Network.RemotePromise.Remotes.C_ActivateObject:FireServer(bond)
                                    end
                                until bond:FindFirstChild("Part") == nil
                            end
                        end
                    end
                    task.wait()
                end
            end)
            -- Auto Bond Code End
        end
    end,
})

