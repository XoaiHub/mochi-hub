-- [[
--  Mutation ESP for Grow a Garden by Havoc
--  Discord: havoc06946 - DM me for more suggestions
--
--  CONFIGURATION:
--  Set to true to enable ESP for that mutation, false to disable
--  Set espEnabled to false to turn off all ESP
-- Example
-- ["Wet"] = false, -- u won't see any Wet ESP
-- ["Wet"] = true, -- u will see Wet ESP
--]]

local config = {
    espEnabled = true, -- Turn Off Or On | Off = false, | On = true,
    
    mutations = {
        ["Wet"] = true, -- Turn Off Or On | Off = false, | On = true,
        ["Gold"] = true, -- Turn Off Or On | Off = false, | On = true,
        ["Frozen"] = true, -- Turn Off Or On | Off = false, | On = true,
        ["Rainbow"] = true, -- Turn Off Or On | Off = false, | On = true,
        ["Choc"] = true, -- Turn Off Or On | Off = false, | On = true,
        ["Chilled"] = true, -- Turn Off Or On | Off = false, | On = true,
        ["Shocked"] = true, -- Turn Off Or On | Off = false, | On = true,
        ["Moonlit"] = true, -- Turn Off Or On | Off = false, | On = true,
        ["Bloodlit"] = true, -- Turn Off Or On | Off = false, | On = true,
        ["Celestial"] = true, -- Turn Off Or On | Off = false, | On = true,
        ["Plasma"] = true, -- Turn Off Or On | Off = false, | On = true,
        ["Disco"] = true, -- Turn Off Or On | Off = false, | On = true,
        ["Zombified"] = true -- Turn Off Or On | Off = false, | On = true,
    },
    
    showTextLabels = true, -- Set to false to only show highlights without labels
    showGlowEffects = true -- Set to false to disable glow and particle effects
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local lp = Players.LocalPlayer
local espObjects = {}
local processedFruits = {}

local mutationOptions = {
    "Wet", "Gold", "Frozen", "Rainbow", "Choc", "Chilled", 
    "Shocked", "Moonlit", "Bloodlit", "Celestial", "Plasma", 
    "Disco", "Zombified"
}

local mutationColors = {
    Wet = Color3.fromRGB(0, 120, 255),
    Gold = Color3.fromRGB(255, 215, 0),
    Frozen = Color3.fromRGB(135, 206, 250),
    Rainbow = Color3.fromRGB(255, 255, 255),
    Choc = Color3.fromRGB(139, 69, 19),
    Chilled = Color3.fromRGB(0, 255, 255),
    Shocked = Color3.fromRGB(255, 255, 0),
    Moonlit = Color3.fromRGB(160, 32, 240),
    Bloodlit = Color3.fromRGB(200, 0, 0),
    Celestial = Color3.fromRGB(200, 150, 255),
    Plasma = Color3.fromRGB(0, 255, 127),
    Disco = Color3.fromRGB(255, 0, 255),
    Zombified = Color3.fromRGB(75, 83, 32)
}

local rarityTiers = {
    {mutations = {"Wet"}, tier = 1},
    {mutations = {"Gold", "Frozen", "Choc", "Chilled", "Shocked"}, tier = 2},
    {mutations = {"Rainbow", "Moonlit", "Bloodlit", "Plasma", "Disco"}, tier = 3},
    {mutations = {"Celestial", "Zombified"}, tier = 4}
}

local function getMutationTier(mutation)
    for _, tier in ipairs(rarityTiers) do
        if table.find(tier.mutations, mutation) then
            return tier.tier
        end
    end
    return 1
end

local function cleanupESP()
    for _, obj in pairs(espObjects) do
        if obj and typeof(obj) == "table" then
            for _, item in pairs(obj) do
                if item and item.Parent then
                    item:Destroy()
                end
            end
        end
    end

    espObjects = {}
    processedFruits = {}
end

local function createGlowEffect(baseColor, parent)
    local glow = Instance.new("BillboardGui")
    glow.Name = "GlowEffect"
    glow.Size = UDim2.fromOffset(6, 6)
    glow.Adornee = parent
    glow.AlwaysOnTop = true

    local image = Instance.new("ImageLabel")
    image.Size = UDim2.fromScale(1, 1)
    image.BackgroundTransparency = 1
    image.Image = "rbxassetid://1316045217" 
    image.ImageColor3 = baseColor
    image.ImageTransparency = 0.2
    image.Parent = glow

    return glow
end

local function createESP(fruitModel)
    if not config.espEnabled or not fruitModel or not fruitModel:IsA("Model") or processedFruits[fruitModel] then return end

    local activeMutations = {}
    for _, mutation in ipairs(mutationOptions) do
        if config.mutations[mutation] and fruitModel:GetAttribute(mutation) then
            table.insert(activeMutations, mutation)
        end
    end

    if #activeMutations == 0 then return end
    processedFruits[fruitModel] = true

    local highestTier = 0
    local primaryMutation = activeMutations[1]

    for _, mutation in ipairs(activeMutations) do
        local tier = getMutationTier(mutation)
        if tier > highestTier then
            highestTier = tier
            primaryMutation = mutation
        end
    end

    local espColor = mutationColors[primaryMutation] or Color3.fromRGB(255, 255, 255)
    local espObjects_current = {}

    local highlight = Instance.new("Highlight")
    highlight.Name = "MutationESP_Highlight"
    highlight.FillTransparency = 0.7
    highlight.OutlineColor = espColor
    highlight.FillColor = espColor
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.Adornee = fruitModel
    highlight.Parent = fruitModel
    table.insert(espObjects_current, highlight)

    if config.showGlowEffects and highestTier >= 3 then
        local tweenInfo = TweenInfo.new(
            1.5,                          
            Enum.EasingStyle.Sine,        
            Enum.EasingDirection.InOut,   
            -1,                           
            true                          
        )

        local pulseUp = TweenService:Create(highlight, tweenInfo, {
            OutlineTransparency = 0.5,
            FillTransparency = 0.9
        })
        pulseUp:Play()
    end

    local primaryPart = fruitModel.PrimaryPart or fruitModel:FindFirstChildWhichIsA("BasePart")
    if primaryPart then
        if config.showTextLabels then
            local billboard = Instance.new("BillboardGui")
            billboard.Name = "MutationESP_Billboard"
            billboard.Adornee = primaryPart
            billboard.Size = UDim2.fromOffset(150, 30)
            billboard.StudsOffset = Vector3.new(0, 2, 0)
            billboard.AlwaysOnTop = true
            billboard.MaxDistance = 100

            local frame = Instance.new("Frame")
            frame.Size = UDim2.fromScale(1, 1)
            frame.BackgroundTransparency = 0.3
            frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)

            local uiCorner = Instance.new("UICorner")
            uiCorner.CornerRadius = UDim.new(0, 8)
            uiCorner.Parent = frame

            local uiStroke = Instance.new("UIStroke")
            uiStroke.Color = espColor
            uiStroke.Thickness = 2
            uiStroke.Parent = frame

            local gradient = Instance.new("UIGradient")
            gradient.Rotation = 45
            gradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 40, 40)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 15))
            })
            gradient.Parent = frame

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
            nameLabel.Position = UDim2.new(0, 0, 0, 2)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = fruitModel.Name
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLabel.TextScaled = true
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.Parent = frame

            local mutationText = table.concat(activeMutations, " • ")
            local mutationLabel = Instance.new("TextLabel")
            mutationLabel.Size = UDim2.new(1, 0, 0.6, 0)
            mutationLabel.Position = UDim2.new(0, 0, 0.4, 0)
            mutationLabel.BackgroundTransparency = 1
            mutationLabel.Text = mutationText
            mutationLabel.TextColor3 = espColor
            mutationLabel.TextScaled = true
            mutationLabel.Font = Enum.Font.GothamSemibold
            mutationLabel.Parent = frame

            frame.Parent = billboard
            billboard.Parent = fruitModel
            table.insert(espObjects_current, billboard)
        end

        if config.showGlowEffects and highestTier >= 2 then
            local glow = createGlowEffect(espColor, primaryPart)
            glow.Parent = fruitModel
            table.insert(espObjects_current, glow)

            if highestTier >= 4 then
                for i = 1, 3 do
                    local orb = Instance.new("Part")
                    orb.Name = "MutationOrb_" .. i
                    orb.Shape = Enum.PartType.Ball
                    orb.Size = Vector3.new(0.3, 0.3, 0.3)
                    orb.Material = Enum.Material.Neon
                    orb.Color = espColor
                    orb.CanCollide = false
                    orb.Anchored = true
                    orb.Transparency = 0.3
                    orb.Parent = fruitModel

                    spawn(function()
                        local offset = (i-1) * (2*math.pi/3) 
                        while orb and orb.Parent do
                            local t = tick() * 2 + offset
                            local radius = 2
                            local height = math.sin(t) * 0.5

                            local pos = primaryPart.Position + Vector3.new(
                                math.cos(t) * radius,
                                height + 1,
                                math.sin(t) * radius
                            )

                            orb.Position = pos
                            RunService.Heartbeat:Wait()
                        end
                    end)

                    table.insert(espObjects_current, orb)
                end
            end
        end
    end

    espObjects[fruitModel] = espObjects_current

    fruitModel.AncestryChanged:Connect(function(_, parent)
        if not parent then
            if espObjects[fruitModel] then
                for _, obj in pairs(espObjects[fruitModel]) do
                    if obj and obj.Parent then
                        obj:Destroy()
                    end
                end
                espObjects[fruitModel] = nil
                processedFruits[fruitModel] = nil
            end
        end
    end)
end

local function updateESP()
    local farms = {}

    if not Workspace:FindFirstChild("Farm") then return end

    for _, farm in ipairs(Workspace.Farm:GetChildren()) do
        local data = farm:FindFirstChild("Important") and farm.Important:FindFirstChild("Data")
        if data and data:FindFirstChild("Owner") and data.Owner.Value == lp.Name then
            table.insert(farms, farm)
        end
    end

    for _, farm in ipairs(farms) do
        local plantsFolder = farm.Important:FindFirstChild("Plants_Physical")
        if plantsFolder then
            for _, plantModel in ipairs(plantsFolder:GetChildren()) do
                if plantModel:IsA("Model") then
                    local fruitsFolder = plantModel:FindFirstChild("Fruits")
                    if fruitsFolder then
                        for _, fruitModel in ipairs(fruitsFolder:GetChildren()) do
                            if fruitModel:IsA("Model") then
                                createESP(fruitModel)
                            end
                        end
                    end
                end
            end
        end
    end
end

local function setupFruitMonitoring()
    local farms = Workspace:FindFirstChild("Farm")
    if not farms then return end

    for _, farm in ipairs(farms:GetChildren()) do
        local data = farm:FindFirstChild("Important") and farm.Important:FindFirstChild("Data")
        if data and data:FindFirstChild("Owner") and data.Owner.Value == lp.Name then
            local plantsFolder = farm.Important:FindFirstChild("Plants_Physical")
            if plantsFolder then
                plantsFolder.ChildAdded:Connect(function(plantModel)
                    if plantModel:IsA("Model") then
                        task.spawn(function()
                            local fruitsFolder = plantModel:FindFirstChild("Fruits") or plantModel:WaitForChild("Fruits", 10)
                            if fruitsFolder then
                                fruitsFolder.ChildAdded:Connect(function(fruitModel)
                                    if fruitModel:IsA("Model") then
                                        task.wait(0.2) 
                                        createESP(fruitModel)
                                    end
                                end)

                                for _, fruitModel in ipairs(fruitsFolder:GetChildren()) do
                                    if fruitModel:IsA("Model") then
                                        createESP(fruitModel)
                                    end
                                end
                            end
                        end)
                    end
                end)
            end
        end
    end
end

cleanupESP()
updateESP()
setupFruitMonitoring()

Workspace.ChildAdded:Connect(function(child)
    if child.Name == "Farm" then
        task.wait(1)
        setupFruitMonitoring()
        updateESP()
    end
end)

if Workspace:FindFirstChild("Farm") then
    Workspace.Farm.ChildAdded:Connect(function()
        task.wait(1)
        setupFruitMonitoring()
        updateESP()
    end)
end

task.spawn(function()
    while true do
        if config.espEnabled then
            updateESP()
        else
            cleanupESP()
        end

        for model, objList in pairs(espObjects) do
            if not model or not model.Parent then
                for _, obj in pairs(objList) do
                    if obj and obj.Parent then
                        obj:Destroy()
                    end
                end
                espObjects[model] = nil
                processedFruits[model] = nil
            end
        end

        task.wait(2)
    end
end)
