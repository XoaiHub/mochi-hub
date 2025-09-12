local g = game
g.Lighting.GlobalShadows = false
g.Lighting.FogEnd = 1e10
g.Lighting.Brightness = 0
settings().Rendering.QualityLevel = "Level01"

local function optimize(v)
    if v:IsA("Model") then
        for _, c in ipairs(v:GetDescendants()) do
            if c:IsA("BasePart") or c:IsA("MeshPart") then
                c.Transparency = 1
            elseif c:IsA("Decal") or c:IsA("Texture") then
                c.Transparency = 1
            end
        end
    elseif v:IsA("BasePart") or v:IsA("MeshPart") then
        v.Transparency = 1
    elseif v:IsA("Decal") or v:IsA("Texture") then
        v.Transparency = 1
    elseif v:IsA("Explosion") then
        v.BlastPressure = 1
        v.BlastRadius = 1
    elseif v:IsA("Fire") or v:IsA("SpotLight") or v:IsA("Smoke") or v:IsA("Sparkles") then
        v.Enabled = false
    end
end

for _, v in ipairs(g:GetDescendants()) do
    optimize(v)
end

g.DescendantAdded:Connect(optimize)

for _, e in ipairs(g.Lighting:GetDescendants()) do
    if e:IsA("PostEffect") then
        e.Enabled = false
    end
end

g.Lighting.DescendantAdded:Connect(function(e)
    if e:IsA("PostEffect") then
        e.Enabled = false
    end
end)
getgenv().fps = true
repeat wait() until getgenv().fps

local function Hop(mode)
    game.StarterGui:SetCore("SendNotification",{Title="NHM | Hoàng Minh",Text="Hopping...",Duration=3,Icon=""})
    local PlaceID=game.PlaceId
    local AllIDs,foundAnything,actualHour,isTeleporting={}, "",os.date("!*t").hour,false
    local function bQ(v)
        if v.Name=="ErrorPrompt" then
            if v.Visible and v.TitleFrame.ErrorTitle.Text=="Teleport Failed" then v.Visible=false end
            v:GetPropertyChangedSignal("Visible"):Connect(function()
                if v.Visible and v.TitleFrame.ErrorTitle.Text=="Teleport Failed" then v.Visible=false end
            end)
        end
    end
    for _,v in pairs(game.CoreGui.RobloxPromptGui.promptOverlay:GetChildren()) do bQ(v) end
    game.CoreGui.RobloxPromptGui.promptOverlay.ChildAdded:Connect(bQ)
    local function TPReturner()
        if isTeleporting then return end
        local Site=foundAnything=="" and game.HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..PlaceID.."/servers/Public?sortOrder=Asc&limit=100")) or game.HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..PlaceID.."/servers/Public?sortOrder=Asc&limit=100&cursor="..foundAnything))
        if Site.nextPageCursor and Site.nextPageCursor~="null" then foundAnything=Site.nextPageCursor end
        local serverList,num={},0
        for _,v in pairs(Site.data) do
            local Possible,ID=true,tostring(v.id)
            local ping=v.ping or 9999
            if tonumber(v.maxPlayers)>tonumber(v.playing) and ping<600 then
                for _,Existing in pairs(AllIDs) do
                    if num~=0 then
                        if ID==tostring(Existing) then Possible=false end
                    else
                        if tonumber(actualHour)~=tonumber(Existing) then
                            AllIDs={}
                            table.insert(AllIDs,actualHour)
                        end
                    end
                    num=num+1
                end
                if Possible then
                    table.insert(serverList,{id=ID,players=tonumber(v.playing),ping=ping})
                end
            end
        end
        if mode=="Low" then
            table.sort(serverList,function(a,b) return a.players<b.players end)
        elseif mode=="High" then
            table.sort(serverList,function(a,b) return a.players>b.players end)
            serverList=table.filter(serverList,function(s) return s.players>=5 end)
        end
        if #serverList>0 then
            local selectedServer=serverList[1]
            table.insert(AllIDs,selectedServer.id)
            isTeleporting=true
            pcall(function() game:GetService("TeleportService"):TeleportToPlaceInstance(PlaceID,selectedServer.id,game.Players.LocalPlayer) end)
            task.wait(0.3)
            isTeleporting=false
        end
    end
    local function Teleport()
        while task.wait(0.2) do
            pcall(function()
                TPReturner()
                if foundAnything~="" then TPReturner() end
            end)
        end
    end
    Teleport()
end

function Hop1()
    game.StarterGui:SetCore("SendNotification", {
        Title = "NHM | Hoàng Minh",
        Text = "Hopping...",
        Duration = 3,
        Icon = "rbxassetid://82998069635449"
    })

    local PlaceID = game.PlaceId
    local AllIDs = {}
    local foundAnything = ""
    local isTeleporting = false

    local function handleErrorPrompt(v)
        if v.Name == "ErrorPrompt" then
            if v.Visible and v.TitleFrame.ErrorTitle.Text == "Teleport Failed" then
                v.Visible = false
            end
            v:GetPropertyChangedSignal("Visible"):Connect(function()
                if v.Visible and v.TitleFrame.ErrorTitle.Text == "Teleport Failed" then
                    v.Visible = false
                end
            end)
        end
    end

    for _, v in pairs(game.CoreGui.RobloxPromptGui.promptOverlay:GetChildren()) do
        handleErrorPrompt(v)
    end
    game.CoreGui.RobloxPromptGui.promptOverlay.ChildAdded:Connect(handleErrorPrompt)

    local function TPReturner()
        if isTeleporting then return end

        local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100&cursor=%s"):format(PlaceID, foundAnything)
        local success, Site = pcall(function()
            return game.HttpService:JSONDecode(game:HttpGet(url))
        end)

        if not success then
            task.wait(2)
        end

        if Site.nextPageCursor and Site.nextPageCursor ~= "null" then
            foundAnything = Site.nextPageCursor
        else
            foundAnything = ""
        end

        for _, v in pairs(Site.data) do
            local ID = tostring(v.id)
            local Possible = true

            if tonumber(v.maxPlayers) > tonumber(v.playing) then
                for _, Existing in pairs(AllIDs) do
                    if ID == tostring(Existing) then
                        Possible = false
                    end
                end

                if Possible then
                    if Config["Setting"]["Select Region"] == true then
                        local region = string.lower(v.ping or v.region or "")
                        local valid = false
                        for _, selected in pairs(Config["Setting"]["Select Region"]["Region"]) do
                            if string.find(region, string.lower(selected)) then
                                valid = true
                                break
                            end
                        end
                        if not valid then
                            continue
                        end
                    end
                    table.insert(AllIDs, ID)
                    isTeleporting = true
                    pcall(function()
                        game:GetService("TeleportService"):TeleportToPlaceInstance(PlaceID, ID, game:GetService("Players").LocalPlayer)
                    end)
                    task.wait(1)
                    isTeleporting = false
                end
            end
        end
    end

    local function Teleport()
        while task.wait(2) do
            pcall(TPReturner)
        end
    end

    Teleport()
end

getgenv().NoClip = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

RunService.Stepped:Connect(function()
    pcall(function()
        local char = LocalPlayer.Character
        local head = char and char:FindFirstChild("Head")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if not (char and head and hrp) then return end

        if getgenv().NoClip then
            if not head:FindFirstChild("BodyClip") then
                local bv = Instance.new("BodyVelocity")
                bv.Name = "BodyClip"
                bv.Velocity = Vector3.new(0, 0, 0)
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.P = 15000
                bv.Parent = head
            end

            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.CanCollide = false
                end
            end
        else
            local existingClip = head:FindFirstChild("BodyClip")
            if existingClip then
                existingClip:Destroy()
            end

            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.CanCollide = true
                end
            end
        end
    end)
end)

local function rainbowStroke(stroke)
    task.spawn(function()
        while task.wait() do
            for i = 0, 1, 0.01 do
                stroke.Color = Color3.fromHSV(i, 1, 1)
                task.wait(0.03)
            end
        end
    end)
end

local a = Instance.new("ScreenGui", game:GetService("CoreGui"))
a.Name = "gg"

local b = Instance.new("Frame", a)
b.Size = UDim2.new(1, 0, 1, 0)
b.Position = UDim2.new(0, 0, 0, 0)
b.BackgroundTransparency = 1
b.BorderSizePixel = 0

local d = Instance.new("UIStroke", b)
d.Thickness = 2
rainbowStroke(d)

local e = Instance.new("TextLabel", b)
e.Size = UDim2.new(1, 0, 1, 0)
e.BackgroundTransparency = 1
e.Text = "0"
e.TextColor3 = Color3.fromRGB(255, 255, 255)
e.Font = Enum.Font.GothamBold
e.TextScaled = true
e.TextStrokeTransparency = 0.6

task.spawn(function()
    while task.wait(0.2) do
        local diamondGui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
        if diamondGui then
            local countLabel = diamondGui:FindFirstChild("Interface") 
                and diamondGui.Interface:FindFirstChild("DiamondCount") 
                and diamondGui.Interface.DiamondCount:FindFirstChild("Count")
            if countLabel and countLabel:IsA("TextLabel") then
                e.Text = countLabel.Text
            end
        end
    end
end)


local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local lp=Players.LocalPlayer

local function L_V1(pos)
    if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
        lp.Character:SetPrimaryPartCFrame(pos)
    end
end

local function L_V2()
    for _,obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and(obj.Name=="Teleporter1"or obj.Name=="Teleporter2"or obj.Name=="Teleporter3") then
            local g=obj:FindFirstChild("BillboardHolder")
            if g and g:FindFirstChild("BillboardGui") and g.BillboardGui:FindFirstChild("Players") then
                local t=g.BillboardGui.Players.Text
                local x,y=t:match("(%d+)/(%d+)")
                x,y=tonumber(x),tonumber(y)
                if x and y and x>=2 then
                    local enter=obj:FindFirstChildWhichIsA("BasePart")
                    if enter and lp.Character and lp.Character:FindFirstChild("Humanoid") then
                        local hrp=lp.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local dir=(enter.Position-hrp.Position).Unit
                            lp.Character.Humanoid:MoveTo(enter.Position)
                            if(hrp.Position-enter.Position).Magnitude>10 then
                                L_V1(enter.CFrame+Vector3.new(0,3,0))
                            end
                        end
                    end
                end
            end
        end
    end
end

local FogCF,FogSize=workspace.Map:FindFirstChild("Boundaries") and workspace.Map.Boundaries:FindFirstChild("Fog") and workspace.Map.Boundaries.Fog:GetBoundingBox()

local chestSeen = {}

local function L_V3()
    local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, nil end
    local closest, dist
    for _, v in pairs(workspace.Items:GetDescendants()) do
        if v:IsA("Model") and v.Name:find("Chest") and not v.Name:find("Snow") then
            local prox = v:FindFirstChild("ProximityInteraction", true) or v:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prox then
                local id = v:GetDebugId() 
                if not chestSeen[id] then
                    chestSeen[id] = tick()
                end
                if tick() - chestSeen[id] <= 10 then
                    local p = v:GetPivot().Position
                    if not FogCF or not FogSize or not (p >= FogCF.Position - FogSize/2 and p <= FogCF.Position + FogSize/2) then
                        local d = (hrp.Position - p).Magnitude
                        if not dist or d < dist then
                            closest, dist = v, d
                        end
                    end
                end
            else
                chestSeen[v:GetDebugId()] = nil
            end
        end
    end
    return closest, dist
end


local function L_V4()
    for _,d in pairs(workspace:GetDescendants()) do
        if d:IsA("Model") and d.Name=="Diamond" and game.PlaceId==126509999114328 then
            L_V1(CFrame.new(d:GetPivot().Position))
            RS.RemoteEvents.RequestTakeDiamonds:FireServer(d)
            warn("collect kc")
        end
    end
end

spawn(function()
    while task.wait(0.5) do
        if game.PlaceId~=126509999114328 then pcall(L_V2) end
    end
end)

spawn(function()
    while task.wait(0.1) do
        if game.PlaceId==126509999114328 then
            warn("[ChestFarm] Entered farm place")
            local t=os.time()
            while os.time()-t<15 do
                local c=0
                for _,v in pairs(workspace.Items:GetChildren()) do
                    if v.Name:find("Chest") and not v.Name:find("Snow") then
                        local p=v:GetPivot().Position
                        if not FogCF or not FogSize or not(p>=FogCF.Position-FogSize/2 and p<=FogCF.Position+FogSize/2) then
                            c=c+1
                        end
                    end
                end
                warn("[ChestFarm] Checking chests in fog cycle, found:", c)
                if c>=0 then break end
                task.wait(5)
            end

            local c=0
            for _,v in pairs(workspace.Items:GetChildren()) do
                if v.Name:find("Chest") and v:FindFirstChildWhichIsA("ProximityPrompt",true) and not v.Name:find("Snow") then
                    local p=v:GetPivot().Position
                    if not FogCF or not FogSize or not(p>=FogCF.Position-FogSize/2 and p<=FogCF.Position+FogSize/2) then
                        c=c+1
                    end
                end
            end
            warn("[ChestFarm] Final chest count before farming:", c)

            if c<0 and not workspace:FindFirstChild("Diamond", true) and game.PlaceId==126509999114328 then
                warn("[ChestFarm] Not enough chests, hopping...")
                Hop("Low")
                return
            end

            while true do
                local chest=L_V3()
                if not chest and game.PlaceId==126509999114328 then
                    warn("[ChestFarm] No chest found, hopping...")
                    Hop("Low")
                    break
                end
                warn("[ChestFarm] Farming chest:", chest and chest.Name or "nil")
                local prox=chest:FindFirstChildWhichIsA("ProximityPrompt",true)
                local start=os.time()
                while prox and prox.Parent and os.time()-start<10 do 
                    L_V1(CFrame.new(chest:GetPivot().Position))
                    fireproximityprompt(prox)
                    warn("[ChestFarm] Prompt fired on:", chest.Name)
                    task.wait(0.5)
                    prox=chest:FindFirstChildWhichIsA("ProximityPrompt",true)
                end
                if os.time()-start>=10 then
                    warn("[ChestFarm] Chest timeout (10s), skipping:", chest.Name)
                end
                task.wait(0.5)
            end
        else
            local inactive=true
            if #Players:GetPlayers()<5 and game.PlaceId~=126509999114328 then
                inactive=true
            else
                for _,pl in pairs(Players:GetPlayers()) do
                    if pl~=lp and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
                        if pl.Character.HumanoidRootPart.Velocity.Magnitude>2 then inactive=false break end
                    end
                end
            end
            warn("[ChestFarm] Inactivity check:", inactive)
            if inactive and game.PlaceId~=126509999114328 then
                warn("[ChestFarm] Inactive server, hopping...")
                task.wait(5)
                Hop1()
            end
        end
    end
end)



while task.wait(0.1) do
    if game.PlaceId==126509999114328 then
    L_V4()
    end
end

