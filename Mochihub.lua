--// ======= LOGIC MỚI: JOIN MAP -> SAU ĐÓ MỚI FARM (CHEST + GEMS) =======
repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer

-- ===== CẤU HÌNH =====
local FARM_PLACE_ID = 126509999114328 -- Đổi nếu map farm của bạn khác ID này
getgenv().Config = getgenv().Config or {
    Setting = {
        ["Select Region"] = false,
        ["Select Region"] = { Region = { "us", "eu", "sea", "jp" } }
    }
}
getgenv().fps    = (getgenv().fps ~= false)     -- bật tối ưu mặc định
getgenv().NoClip = (getgenv().NoClip ~= false)  -- bật noclip mặc định

-- ===== DỊCH VỤ & BIẾN =====
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local Remote = RS:FindFirstChild("RemoteEvents") and RS.RemoteEvents:FindFirstChild("RequestTakeDiamonds")

local function notify(t, x, d) pcall(function() StarterGui:SetCore("SendNotification",{Title=t,Text=x,Duration=d or 3}) end) end

-- ===== TỐI ƯU FPS NHẸ =====
local g = game
g.Lighting.GlobalShadows = false
g.Lighting.FogEnd = 1e10
g.Lighting.Brightness = 0
pcall(function() settings().Rendering.QualityLevel = "Level01" end)
local function optimize(v)
    if v:IsA("Model") then
        for _, c in ipairs(v:GetDescendants()) do
            if c:IsA("BasePart") or c:IsA("MeshPart") then
                c.Material = Enum.Material.Plastic; c.Reflectance = 0; c.CastShadow = false
                if c:IsA("MeshPart") then c.TextureID = "" end
                c.Transparency = 1
            elseif c:IsA("Decal") or c:IsA("Texture") then
                c.Transparency = 1
            elseif c:IsA("SpecialMesh") or c:IsA("SurfaceAppearance") then
                pcall(function() c:Destroy() end)
            end
        end
    elseif v:IsA("BasePart") or v:IsA("MeshPart") then
        v.Material = Enum.Material.Plastic; v.Reflectance = 0; v.CastShadow = false
        if v:IsA("MeshPart") then v.TextureID = "" end
        v.Transparency = 1
    elseif v:IsA("Decal") or v:IsA("Texture") then
        v.Transparency = 1
    elseif v:IsA("Explosion") then
        v.BlastPressure = 1; v.BlastRadius = 1
    elseif v:IsA("Fire") or v:IsA("SpotLight") or v:IsA("Smoke") or v:IsA("Sparkles") then
        v.Enabled = false
    elseif v:IsA("SpecialMesh") or v:IsA("SurfaceAppearance") then
        pcall(function() v:Destroy() end)
    end
end
for _, v in ipairs(g:GetDescendants()) do optimize(v) end
g.DescendantAdded:Connect(optimize)
for _, e in ipairs(g.Lighting:GetDescendants()) do if e:IsA("PostEffect") then e.Enabled = false end end
g.Lighting.DescendantAdded:Connect(function(e) if e:IsA("PostEffect") then e.Enabled = false end end)
repeat task.wait() until getgenv().fps

-- ===== UI ĐẾM DIAMOND =====
local function rainbowStroke(stroke)
    task.spawn(function()
        while task.wait() do
            for i=0,1,0.01 do
                pcall(function() stroke.Color = Color3.fromHSV(i,1,1) end)
                task.wait(0.03)
            end
        end
    end)
end
local overlay = Instance.new("ScreenGui"); overlay.Name = "Mochi_Farm_Overlay"; overlay.ResetOnSpawn=false; overlay.Parent = game:GetService("CoreGui")
local frame = Instance.new("Frame", overlay); frame.Size = UDim2.new(1,0,1,0); frame.BackgroundTransparency=1; frame.BorderSizePixel=0
local uiStroke = Instance.new("UIStroke", frame); uiStroke.Thickness=2; rainbowStroke(uiStroke)
local diamondLabel = Instance.new("TextLabel", frame)
diamondLabel.Size=UDim2.new(1,0,1,0); diamondLabel.BackgroundTransparency=1; diamondLabel.Text="0"
diamondLabel.TextColor3=Color3.new(1,1,1); diamondLabel.Font=Enum.Font.GothamBold; diamondLabel.TextScaled=true; diamondLabel.TextStrokeTransparency=0.6
task.spawn(function()
    while task.wait(0.25) do
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            local Interface = pg:FindFirstChild("Interface")
            local Count = Interface and Interface:FindFirstChild("DiamondCount")
            local Label = Count and Count:FindFirstChild("Count")
            if Label and Label:IsA("TextLabel") then diamondLabel.Text = Label.Text end
        end
    end
end)

-- ===== NOCLIP =====
local RunService = game:GetService("RunService")
RunService.Stepped:Connect(function()
    pcall(function()
        local ch = LocalPlayer.Character
        local head = ch and ch:FindFirstChild("Head")
        local hrp  = ch and ch:FindFirstChild("HumanoidRootPart")
        if not (ch and head and hrp) then return end
        if getgenv().NoClip then
            if not head:FindFirstChild("BodyClip") then
                local bv = Instance.new("BodyVelocity"); bv.Name="BodyClip"; bv.Velocity=Vector3.new(0,0,0)
                bv.MaxForce=Vector3.new(math.huge,math.huge,math.huge); bv.P=15000; bv.Parent=head
            end
            for _, v in ipairs(ch:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=false end end
        else
            local ex = head:FindFirstChild("BodyClip"); if ex then ex:Destroy() end
            for _, v in ipairs(ch:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=true end end
        end
    end)
end)

-- ===== XOR LỖI TELEPORT FAILED =====
pcall(function()
    local function hookOverlay(overlay)
        local function bQ(v)
            if v.Name=="ErrorPrompt" then
                if v.Visible and v.TitleFrame and v.TitleFrame.ErrorTitle and v.TitleFrame.ErrorTitle.Text=="Teleport Failed" then v.Visible=false end
                v:GetPropertyChangedSignal("Visible"):Connect(function()
                    if v.Visible and v.TitleFrame and v.TitleFrame.ErrorTitle and v.TitleFrame.ErrorTitle.Text=="Teleport Failed" then v.Visible=false end
                end)
            end
        end
        for _,v in pairs(overlay:GetChildren()) do bQ(v) end
        overlay.ChildAdded:Connect(bQ)
    end
    local RbxPrompt = game.CoreGui:WaitForChild("RobloxPromptGui",10)
    if RbxPrompt then hookOverlay(RbxPrompt:WaitForChild("promptOverlay",10)) end
end)

-- ===== HÀM TIỆN ÍCH DỊCH CHUYỂN =====
local function TPTo(cf) local ch=LocalPlayer.Character if ch and ch:FindFirstChild("HumanoidRootPart") then ch:SetPrimaryPartCFrame(cf) end end
local function PivotTo(cf) local ch=LocalPlayer.Character if ch and ch:FindFirstChild("HumanoidRootPart") then ch:PivotTo(cf) end end

-- ===== HOP (2 kiểu) =====
local function regionOK(v)
    if getgenv().Config and getgenv().Config.Setting and getgenv().Config.Setting["Select Region"]==true then
        local region = string.lower(v.ping or v.region or "")
        for _, selected in pairs(getgenv().Config.Setting["Select Region"]["Region"]) do
            if string.find(region, string.lower(selected)) then return true end
        end
        return false
    end
    return true
end

local function Hop(mode)
    notify("NHM | Hoàng Minh","Hopping...",3)
    local PlaceID=game.PlaceId
    local AllIDs,foundAnything,actualHour,isTeleporting={}, "",os.date("!*t").hour,false
    local function fetchPick()
        if isTeleporting then return end
        local url = foundAnything=="" and
            ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100"):format(PlaceID) or
            ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100&cursor=%s"):format(PlaceID,foundAnything)
        local ok,Site=pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
        if not ok or not Site then return end
        if Site.nextPageCursor and Site.nextPageCursor~="null" then foundAnything=Site.nextPageCursor end
        local serverList, num = {}, 0
        for _,v in pairs(Site.data or {}) do
            local Possible,ID=true,tostring(v.id)
            local ping=v.ping or 9999
            if tonumber(v.maxPlayers)>tonumber(v.playing) and ping<600 and regionOK(v) then
                for _,Existing in pairs(AllIDs) do
                    if num~=0 then if ID==tostring(Existing) then Possible=false end
                    else if tonumber(actualHour)~=tonumber(Existing) then AllIDs={}; table.insert(AllIDs,actualHour) end end
                    num+=1
                end
                if Possible then table.insert(serverList,{id=ID,players=tonumber(v.playing)}) end
            end
        end
        if mode=="Low" then table.sort(serverList,function(a,b) return a.players<b.players end)
        elseif mode=="High" then
            table.sort(serverList,function(a,b) return a.players>b.players end)
            local filtered={} for _,s in ipairs(serverList) do if s.players>=5 then table.insert(filtered,s) end end
            serverList=filtered
        end
        if #serverList>0 then
            local pick=serverList[1]; table.insert(AllIDs,pick.id)
            isTeleporting=true; pcall(function() TeleportService:TeleportToPlaceInstance(PlaceID,pick.id,LocalPlayer) end)
            task.wait(0.4); isTeleporting=false
        end
    end
    task.spawn(function() while task.wait(0.25) do pcall(function() fetchPick(); if foundAnything~="" then fetchPick() end end) end end)
end

local function Hop1()
    notify("NHM | Hoàng Minh","Hopping...",3)
    local PlaceID=game.PlaceId
    local AllIDs,foundAnything,isTeleporting = {}, "", false
    local function TPReturner()
        if isTeleporting then return end
        local url=("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100&cursor=%s"):format(PlaceID,foundAnything)
        local ok,Site=pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
        if not ok or not Site then task.wait(2) return end
        foundAnything = (Site.nextPageCursor and Site.nextPageCursor~="null") and Site.nextPageCursor or ""
        for _,v in pairs(Site.data or {}) do
            if tonumber(v.maxPlayers)>tonumber(v.playing) and regionOK(v) then
                local ID=tostring(v.id); local dup=false
                for _,ex in ipairs(AllIDs) do if ID==tostring(ex) then dup=true break end end
                if not dup then
                    table.insert(AllIDs,ID); isTeleporting=true
                    pcall(function() TeleportService:TeleportToPlaceInstance(PlaceID,ID,LocalPlayer) end)
                    task.wait(1); isTeleporting=false
                end
            end
        end
    end
    task.spawn(function() while task.wait(2) do pcall(TPReturner) end end)
end

-- ===== AUTO VÀO CỔNG Ở LOBBY (chỉ chạy khi KHÔNG ở map farm) =====
local function AutoEnterTeleporter()
    for _,obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and (obj.Name=="Teleporter1" or obj.Name=="Teleporter2" or obj.Name=="Teleporter3") then
            local g=obj:FindFirstChild("BillboardHolder")
            if g and g:FindFirstChild("BillboardGui") and g.BillboardGui:FindFirstChild("Players") then
                local t=g.BillboardGui.Players.Text
                local x,y=t:match("(%d+)/(%d+)"); x=tonumber(x); y=tonumber(y)
                if x and y and x>=2 then
                    local enter=obj:FindFirstChildWhichIsA("BasePart")
                    local hrp=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if enter and hrp and LocalPlayer.Character:FindFirstChild("Humanoid") then
                        LocalPlayer.Character.Humanoid:MoveTo(enter.Position)
                        if (hrp.Position-enter.Position).Magnitude>10 then
                            TPTo(enter.CFrame+Vector3.new(0,3,0))
                        end
                    end
                end
            end
        end
    end
end

-- ===== FOG BOX (lọc chest trong sương) =====
local FogCF,FogSize=nil,nil
pcall(function()
    if workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Boundaries") and workspace.Map.Boundaries:FindFirstChild("Fog") then
        FogCF,FogSize = workspace.Map.Boundaries.Fog:GetBoundingBox()
    end
end)
local function inFog(pos)
    if not (FogCF and FogSize) then return false end
    local mn = FogCF.Position - FogSize/2
    local mx = FogCF.Position + FogSize/2
    return (pos.X>=mn.X and pos.Y>=mn.Y and pos.Z>=mn.Z and pos.X<=mx.X and pos.Y<=mx.Y and pos.Z<=mx.Z)
end

-- ===== FIND CHEST GẦN NHẤT (chỉ gọi trong map farm) =====
local chestSeen = {}
local function FindClosestChest()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local items = workspace:FindFirstChild("Items") and workspace.Items:GetDescendants() or {}
    local best,dist=nil,nil
    for _,v in ipairs(items) do
        if v:IsA("Model") and v.Name:find("Chest") and not v.Name:find("Snow") then
            local prox = v:FindFirstChild("ProximityInteraction",true) or v:FindFirstChildWhichIsA("ProximityPrompt",true)
            if prox then
                local id=v:GetDebugId(); if not chestSeen[id] then chestSeen[id]=tick() end
                if tick()-chestSeen[id] <= 10 then
                    local p = v:GetPivot().Position
                    if not inFog(p) then
                        local d=(hrp.Position-p).Magnitude
                        if not dist or d<dist then best,dist=v,d end
                    end
                end
            else
                chestSeen[v:GetDebugId()] = nil
            end
        end
    end
    return best
end

-- ===== NHẶT TẤT CẢ DIAMOND (chỉ gọi trong map farm) =====
local function CollectAllDiamonds()
    for _,d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Model") and d.Name=="Diamond" then
            pcall(function()
                TPTo(CFrame.new(d:GetPivot().Position))
                if Remote then Remote:FireServer(d) end
            end)
        end
    end
end

-- ===================== STATE MACHINE =====================
-- State: "LOBBY" -> chỉ join map; "FARM" -> farm chest/gems
local function isFarm() return game.PlaceId == FARM_PLACE_ID end

-- LOBBY LOOP: chỉ join map; nếu lobby quá ì -> hop
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            if not isFarm() then
                AutoEnterTeleporter()
                -- inactivity hop nhẹ
                local inactive=true
                if #Players:GetPlayers() >= 5 then
                    for _,pl in ipairs(Players:GetPlayers()) do
                        if pl~=LocalPlayer and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
                            if pl.Character.HumanoidRootPart.Velocity.Magnitude > 2 then inactive=false break end
                        end
                    end
                end
                if inactive then task.wait(3); Hop1() end
            end
        end)
    end
end)

-- FARM LOOP: chỉ farm khi ĐÃ ở map farm
task.spawn(function()
    while task.wait(0.15) do
        pcall(function()
            if isFarm() then
                -- Nếu không có chest và cũng chưa thấy diamond -> hop
                local validChest = 0
                local items = workspace:FindFirstChild("Items") and workspace.Items:GetChildren() or {}
                for _,v in ipairs(items) do
                    if v.Name:find("Chest") and not v.Name:find("Snow") then
                        local prox = v:FindFirstChild("ProximityInteraction",true) or v:FindFirstChildWhichIsA("ProximityPrompt",true)
                        if prox and not inFog(v:GetPivot().Position) then validChest += 1 end
                    end
                end
                if validChest<=0 and not workspace:FindFirstChild("Diamond", true) then
                    warn("[FARM] No chest/diamond -> Hop")
                    Hop("Low")
                    task.wait(2)
                else
                    -- Ưu tiên chest trước
                    local chest = FindClosestChest()
                    if chest then
                        local t0=os.time()
                        local prox = chest:FindFirstChild("ProximityInteraction",true) or chest:FindFirstChildWhichIsA("ProximityPrompt",true)
                        while prox and prox.Parent and (os.time()-t0)<10 do
                            TPTo(CFrame.new(chest:GetPivot().Position))
                            pcall(fireproximityprompt, prox)
                            task.wait(0.4)
                            prox = chest:FindFirstChild("ProximityInteraction",true) or chest:FindFirstChildWhichIsA("ProximityPrompt",true)
                        end
                    end
                    -- Sau đó quét nhặt diamond (nếu có)
                    CollectAllDiamonds()
                end
            end
        end)
    end
end)

-- (Tùy chọn) Nếu bạn thật sự cần hop theo “trùng DisplayName” thì bật khối bên dưới.
--[[
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            if not isFarm() then
                local chars = workspace:FindFirstChild("Characters")
                if chars then
                    for _, char in pairs(chars:GetChildren()) do
                        local hum = char:FindFirstChild("Humanoid")
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        if hum and hrp and hum.DisplayName == LocalPlayer.DisplayName then
                            Hop("Low")
                        end
                    end
                end
            end
        end)
    end
end)
]]
-- ================== HẾT ==================
