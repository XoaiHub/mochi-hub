
        if not LPH_OBFUSCATED then 
            LPH_ENCSTR = LPH_ENCSTR or function(...) return ... end 
            LPH_NO_VIRTUALIZE = LPH_NO_VIRTUALIZE or function(...) return ... end 
        end 
        LPH_NO_VIRTUALIZE(function()
    

        getgenv().modechange = getgenv().modechange or {
            ['CDK'] = true,
            ['Pull Lever'] = true,
            ['MM'] = true,
            ['Force Race'] = {'Skypiea'}, -- Skypiea, Shark, Mink, Human
            ['Auto Roll Race'] = true,
            ['Key'] = '55zNvhxztqLY',
            ['Boost FPS'] = true,
            ['Black Screen'] = true,
            ['FPS'] = 60
        }
        PirateRaidSenque = -1
        ForcedWeapon = 'Melee' -- dont touch

        function CheckKick(v)
            if v.Name == 'ErrorPrompt' then
                task.wait(2)
                print(v.TitleFrame.ErrorTitle.Text)
                if v.TitleFrame.ErrorTitle.Text == 'Teleport Failed' then
                    if string.find(v.MessageArea.ErrorFrame.ErrorMessage.Text, 'Unable to join game') then
                        while true do end 
                    end
                else 
                    game:GetService('TeleportService'):Teleport(game.PlaceId)
                    v:Destroy()
                end
            end
        end

        game:GetService('CoreGui').RobloxPromptGui.promptOverlay.ChildAdded:Connect(CheckKick)
        Notify = function(text) 
            require(game.ReplicatedStorage:WaitForChild('Notification')).new(text):Display()
        end 

        function IfTableHaveIndex(j) 
            for _ in j do 
                return true 
            end 
        end 
        print(1)
        function GetServers() 
            if LastServersDataPulled then 
                if os.time() - LastServersDataPulled < 600 then 
                    print("Use Old Servers...")
                    return CachedServers 
                end 
            end 
            print("Pulling new servers...")
            for i = 1, 100, 1 do 
                local data = game:GetService("ReplicatedStorage"):WaitForChild("__ServerBrowser"):InvokeServer(i) 
                if IfTableHaveIndex(data) then 
                    LastServersDataPulled = os.time()
                    CachedServers = data 
                    return data 
                end 
            end 
        end

        spawn(function()
            GetServers()
            while task.wait(180) do
                GetServers()
            end
        end)

        function Hop(Reason, MaxPlayers, ForcedRegion)
            task.spawn(function()
                task.wait(20)
                
                LocalPlayer:Kick("HOP TIMEDOUT")
            end )
            local Servers = GetServers() 
            local ArrayServers = {}

            for i, v in Servers do 
                table.insert(ArrayServers, {
                    JobId = i, 
                    Players = v.Count,
                    LastUpdate = v.__LastUpdate, 
                    Region = v.Region
                })
            end 
            print(#ArrayServers, 'servers received')

            for i = 1, #ArrayServers do 
                while task.wait() do
                    local Index = math.random(1, #ArrayServers) 
                    ServerData = ArrayServers[Index] 
                    if ServerData then 
                        if not MaxPlayers or ServerData.Players < MaxPlayers then
                            if not ForcedRegion or ServerData.Regoin == ForcedRegion then
                                print("Found Server:", ServerData.JobId, 'Player Count:', ServerData.Players, "Region:", ServerData.Region)
                                break
                            end
                        end
                    end
                end

                print('Teleporting to', ServerData.JobId, '...')
                game:GetService("ReplicatedStorage"):WaitForChild("__ServerBrowser"):InvokeServer('teleport', ServerData.JobId)
            end
        end

        placeId = game.PlaceId
        if placeId == 2753915549 then
            Sea = 'Main'
            SeaIndex = 1
        elseif placeId == 4442272183 then
            Sea = 'Dressrosa'
            SeaIndex = 2
        elseif placeId == 7449423635 then
            Sea = 'Zou'
            SeaIndex = 3
        end


        FastAttack = loadstring([[
        local Modules = game.ReplicatedStorage.Modules
        local Net = Modules.Net
        local Register_Hit, Register_Attack = Net:WaitForChild('RE/RegisterHit'), Net:WaitForChild('RE/RegisterAttack')
        local Funcs = {}
        function GetAllBladeHits()
            bladehits = {}
            for _, v in pairs(workspace.Enemies:GetChildren()) do
                if v:FindFirstChild('Humanoid') and v:FindFirstChild('HumanoidRootPart') and v.Humanoid.Health > 0 
                and (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude <= 65 then
                    table.insert(bladehits, v)
                end
            end
            return bladehits
        end
        function Getplayerhit()
            bladehits = {}
            for _, v in pairs(workspace.Characters:GetChildren()) do
                if v.Name ~= game.Players.LocalPlayer.Name and v:FindFirstChild('Humanoid') and v:FindFirstChild('HumanoidRootPart') and v.Humanoid.Health > 0 
                and (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude <= 65 then
                    table.insert(bladehits, v)
                end
            end
            return bladehits
        end

        local Net = (Services.ReplicatedStorage.Modules.Net)

        local RegisterAttack = require(Net):RemoteEvent('RegisterAttack', true)
        local RegisterHit = require(Net):RemoteEvent('RegisterHit', true)

        function Funcs:Attack()
            
            
            local bladehits = {}
            for r,v in pairs(GetAllBladeHits()) do
                table.insert(bladehits, v)
        
            end
            for r,v in pairs(Getplayerhit()) do
                table.insert(bladehits, v)
            end
            
            if #bladehits == 0 then
                
                return
            end
            
            local args = {
                [1] = nil;
                [2] = {},
                [4] = '078da341'
            }
            for r, v in pairs(bladehits) do
                
                
                RegisterAttack:FireServer(0)
                if not args[1] then
                    args[1] = v.Head
                end
                table.insert(args[2], {
                    [1] = v,
                    [2] = v.HumanoidRootPart
                })
                table.insert(args[2], v)
            end
            
            
            RegisterHit:FireServer(unpack(args))
        end

        task.spawn(function() 
            while task.wait(.05) do 
                if _G.FastAttack == os.time() then 
                    pcall(function() 
                        Funcs:Attack() 
                    end)
                end 
            end
        end)

        getgenv().Attack = function(MonResult) 
            pcall(function() 
                _G.FastAttack = os.time()
            end)
        end 
        ]])


        if not modechange then return end 
        if modechange.Key ~= ('55zNvhxztqLY') then return end 

        repeat wait() until game:IsLoaded() and game.Players.LocalPlayer:FindFirstChild('DataLoaded')

        
        repeat wait()
            game.ReplicatedStorage.Remotes.CommF_:InvokeServer('SetTeam', 'Pirates')
        until game.Players.LocalPlayer.Character
        LastIdleCheck = os.time()
        
        Notify("Load r do fen")
        spawn(function()
            game:GetService("Players").LocalPlayer.PlayerScripts:WaitForChild('NewIslandLOD', 9999):Destroy() 
            game:GetService("Players")LocalPlayer.PlayerScripts:WaitForChild('IslandLOD', 9999):Destroy() 
        end)

        Players = game.Players
        LocalPlayer = Players.LocalPlayer
        Character = LocalPlayer.Character

        Humanoid = Character:WaitForChild('Humanoid')
        HumanoidRootPart = Character:WaitForChild('HumanoidRootPart')

        PlayerGui = LocalPlayer:WaitForChild('PlayerGui', 10)
        Lighting = game:GetService('Lighting')


        ConChoChisiti36 = {
            PlayerData = {}, 
            Enemies = {}, 
            NPCs = {}, 
            Tools = {}
        } 

        Services = {}

        setmetatable(Services, {
            __index = function(_, Index)
                return game:GetService(Index)
            end
        });

        setmetatable(ConChoChisiti36.Enemies, {
            __index = function(_, Index)
                return Services.Workspace.Enemies:FindFirstChild(Index) or Services.ReplicatedStorage:FindFirstChild(Index)
            end
        })

        setmetatable(ConChoChisiti36.Tools, {
            __index = function(Self, Index)
                return LocalPlayer.Character:FindFirstChild(Index) or LocalPlayer.Backpack:FindFirstChild(Index)
            end
        })

        setmetatable(ConChoChisiti36.NPCs, {
            __index = function(_, Index)
                return workspace.NPCs:FindFirstChild(Index) or game.ReplicatedStorage.NPCs:FindFirstChild(Index)
            end
        })


        Remotes = {}
        setmetatable(Remotes, {
            __index = function(Self, Key)
                if Key ~= 'CommF_' then
                    warn('captured unregistered signal', key)
                    return Services.ReplicatedStorage.Remotes[Key]
                end
                local tbl = {
                    InvokeServer = function(Self, ...)
                        warn('remote fired', ...)
                        return Services.ReplicatedStorage.Remotes.CommF_:InvokeServer(...)
                    end
                }
                return tbl
            end
        })

        Storage = {
            WRITE_DELAY = 5, 
            Data = {}, 
        } 

        LocalPlayer = game.Players.LocalPlayer

        local StoragePath = '.storage_u_' .. tostring(LocalPlayer) 

        function Decode(Content) 
            return Services.HttpService:JSONDecode(Content) 
        end 

        function Encode(Content) 
            return Services.HttpService:JSONEncode(Content)  
        end 

        function Storage.Set(Self, Key, Value) 
            Self.Data[Key] = Value
            Self:Save()
        end 

        function Storage.Get(Self, Key) 
            --Report('Get: ' .. tostring(Key or 'n/a') .. ' Value: ' .. tostring(Self.Data[Key] or 'n/') )
            return Self.Data[Key] 
        end 

        function Storage.Save(Self) 
            writefile(StoragePath, Encode(Self.Data)) 
        end 

        if not isfile(StoragePath) then 
            writefile(StoragePath, '{}')
            task.wait(1)
        end 

        Storage.Data = {}

        --Report(readfile(StoragePath))
        pcall(function()
            Storage.Data = Decode(readfile(StoragePath) or "{}")  
        end)
        spawn(function() 
            while task.wait(Storage.WRITE_DELAY) do 
                Storage:Save() 
            end 
        end)

        function RefreshPlayerData()
            for _, ChildInstance in LocalPlayer.Data:GetChildren() do
                pcall(function()
                    ConChoChisiti36.PlayerData[ChildInstance.Name] = ChildInstance.Value
                end)
            end
            DataLoaded = true 
        end
        RefreshPlayerData() 

        function RefreshInventory()
            ConChoChisiti36.Backpack2 = {}
            for _, Value in Remotes.CommF_:InvokeServer('getInventory') do
                ConChoChisiti36.Backpack2[Value.Name] = Value
            end
            
            ConChoChisiti36.Backpack = ConChoChisiti36.Backpack2
        end

        RefreshInventory()
        Remotes.CommE.OnClientEvent:Connect(function(...)
            local data = {...}
            if string.find(data[1], 'Item') then
                RefreshInventory()
            end
        end)

        --[[
        'Legendary Haki', 'Moon', 'Legendary Sword',
        'Prehistoric Island', 'Mirage', 'Rare Boss', 'Castle', 'Elite'
        ]]
        FastAttack()

        -- URL encode function
        function urlencode(str)
            if (str == nil) then
                return ""
            end
            str = tostring(str)
            -- Replace line breaks with CRLF
            str = str:gsub("\n", "\r\n")
            -- Encode characters that are not unreserved (A-Z, a-z, 0-9, -, _, ., ~)
            str = str:gsub("([^%w%-_%.~])", function(c)
                return string.format("%%%02X", string.byte(c))
            end)
            return str
        end
        --dc a
        
        function AsynclyPullServerDatas(Category) 
            Notify('Search for ' .. Category .. ' Servers...')
            local Url = ('') .. urlencode(Category)  
            local Success, Result = pcall(function() 
                local Raw = request{
                    Url = Url, 
                    Method = 'GET'
                }
                table.foreach(Raw, warn)
                assert(Raw.Success == true) 
                return Services.HttpService:JSONDecode(Raw.Body)
            end) 
            
            if not Success then 
                print('Failed to serialize datas', Result)
                return {} 
            end 
            
            return Result.data 
        end 

        function WrapToServer (Category, Filter, IgnoreHop, Reason) 
            if LastestWrapRequest and os.time() - LastestWrapRequest < 10 then return end 
            LastestWrapRequest = os.time() 
            print('Search for rare boss: ', Category)
            local ServerLists = AsynclyPullServerDatas(Category) 
            if #ServerLists == 0 then 
                return false 
            end 
            
            for Attempts = 1, #ServerLists, 1 do 
                local Server = ServerLists[math.random((#ServerLists > 50 and #ServerLists - 50 or 0), #ServerLists)] 
                if Server and not Storage:Get(Server.JobId) and Server.Players ~= '12/12' then 
                    if not Filter or Filter(Server) then 
                        Notify('Attempt to join ' .. Server.JobId ..' Players: ' .. Server.Players .. ' Reason: ' .. Reason)
                        Storage:Set(Server.JobId, true)
                        game:GetService('TeleportService'):TeleportToPlaceInstance(game.placeId,Server.JobId,game.Players.LocalPlayer)
                        task.wait(5) 
                    end 
                end 
            end
            if not IgnoreHop then 
                Hop('Failed to find servers, hop')
            end 
        end 

        Hooks = {
            Listeners = {}
        }

        NotificationCallBack = (function(Content)
            for ListenerContent, Callback in Hooks.Listeners do
                if string.find(string.lower(Content), string.lower(ListenerContent)) then 
                    Callback(Content)
                end 
            end 
        end) 

        function Hooks:RegisterNotifyListener(Senque, Callback)
            Hooks.Listeners[Senque] = Callback
        end 

        Hooks:RegisterNotifyListener('been spotted approaching', function() 
            PirateRaidSenque = os.time()
        end) 

        Hooks:RegisterNotifyListener('player', function() 
            SkipPlayer = true
        end) 

        Hooks:RegisterNotifyListener('job', function() 
            PirateRaidSenque = 0
        end) 

        Hooks:RegisterNotifyListener('torch', function() 
            TorchEnabledTime = os.time()
        end) 

        Hooks:RegisterNotifyListener('scroll reacts', function() 
            DoneCDKTick = os.time()
        end) 
        TorchEnabledTime = 0
        DoneCDKTick = 0
        Hooks:RegisterNotifyListener('elite', function() 
            EliteCount = Remotes.CommF_:InvokeServer('EliteHunter', 'Progress')
        end) 

        local old
        old = hookfunction(
            require(game.ReplicatedStorage.Notification).new,
            function(a, b)
                
                v21 = tostring(tostring(a or '') .. tostring(b or '')) or ''
                
                NotificationCallBack(v21)
                
                return old(a, b)
            end
        ) 

        -- Tween 
        function ConvertTo (Type, Data) 
            return Type.new(Data.x, Data.y, Data.z)
        end 

        function CaculateDistance (Origin, Destination) 
            if not Destination then 
                Destination = LocalPlayer.Character:GetPrimaryPartCFrame() 
            end 
            
            local Origin, Destination = ConvertTo(Vector3, Origin), ConvertTo(Vector3, Destination) 
            
            return (Origin - Destination).Magnitude 
        end 

        local function NoclipLoop()
            speaker = LocalPlayer
            if speaker.Character ~= nil then
                for _, child in pairs(speaker.Character:GetDescendants()) do
                    if child:IsA("BasePart") and child.CanCollide == true and child.Name ~= nil then
                        child.CanCollide = false
                    end
                end
            end
        end

        Noclipping = Services.RunService.Stepped:Connect(NoclipLoop)
        function TweenTo (Position)
            
            if not Position then return end 
            local Position = typeof(Position) ~= 'CFrame' and ConvertTo(CFrame, Position) or Position
            
            if TweenInstance then 
                pcall(function() 
                    TweenInstance:Cancel() 
                end)
            end
            
            for _, Part in LocalPlayer.Character:GetDescendants() do
                if Part:IsA('BasePart') then
                    Part.CanCollide = false
                end
            end
            
            local Head = game.Players.LocalPlayer.Character:WaitForChild('Head')
            if not Head:FindFirstChild('cho nam gg') then
                local BodyVelocity = Instance.new('BodyVelocity')
                BodyVelocity.Name = 'cho nam gg'
                BodyVelocity.MaxForce = Vector3.new(0, math.huge, 0)
                BodyVelocity.Velocity = Vector3.zero
                BodyVelocity.Parent = Head
            end
            
            if LocalPlayer.Character.Humanoid.Sit then 
                game.Players.LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
            Position = CFrame.new(Position.x, math.max(Position.y, 5), Position.z)
            
            if CaculateDistance(Vector3.new(11256, -2138, 9888), Position) < ( CaculateDistance(Position) - 700 ) then 
                local SubmarinePos = CFrame.new(-16269, 23, 1371)

                if CaculateDistance(SubmarinePos) > 60 then return TweenTo(SubmarinePos) and task.wait(1) end 
                local Net_upvr = require(game.ReplicatedStorage.Modules.Net)
                Net_upvr:RemoteFunction("SubmarineWorkerSpeak"):InvokeServer("TravelToSubmergedIsland") 
            end 
            local PlayerPos = LocalPlayer.Character.HumanoidRootPart.CFrame
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(PlayerPos.X, Position.Y, PlayerPos.Z)
            local Dist = CaculateDistance(LocalPlayer.Character.HumanoidRootPart.CFrame, Position)
            TweenInstance = Services.TweenService:Create(
                    LocalPlayer.Character.HumanoidRootPart,
                    TweenInfo.new(Dist / (Dist < 18 and 25 or 330) , Enum.EasingStyle.Linear),
                    {CFrame = Position}
                ) 
            TweenInstance:Play()
        end

        -- Combat 

        function LockMob (Mob) 
            
            if Mob:GetAttribute('_Locked') then 
                return 
            end 
            Mob:SetAttribute('_Locked', 1) 
            
            Mob.HumanoidRootPart.CanCollide = false 
            if not Mob.HumanoidRootPart:FindFirstChild('seen cai cc bo m tu ai r') then 
                local BodyVelocity = Instance.new('BodyVelocity', Mob.HumanoidRootPart) 
                BodyVelocity.Name = 'seen cai cc bo m tu ai r' 
                BodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
                BodyVelocity.Velocity = Vector3.zero
            end
            table.foreach(Mob:GetDescendants(), function(_, Ins)
                if Ins:IsA('BasePart') or Ins:IsA('Part') then
                    Ins.CanCollide = false
                end 
            end)
        end 

        function GrabMobs (MobName) 
        --  if GrabDebounce == os.time() then return end 
            GrabDebounce = os.time() 
            pcall(sethiddenproperty, game.Players.LocalPlayer, 'SimulationRadius', math.huge) 
            GrabPosition = nil
            local MobVectors, EntriesCount, Entries = Vector3.zero, 0, {} 
            
            for _, Mob in workspace.Enemies:GetChildren() do
                if tostring(Mob) == MobName then 
                    local MobHumanoid = Mob:FindFirstChild('Humanoid') 
                    
                    if MobHumanoid and MobHumanoid.Health > 0 then 
                        local MobPrimaryPart = Mob:FindFirstChild('HumanoidRootPart')
                        if MobPrimaryPart and isnetworkowner(MobPrimaryPart) then 
                            if not GrabPosition or CaculateDistance(GrabPosition, MobPrimaryPart.Position) < 250 then 
                                EntriesCount = EntriesCount + 1 
                                MobVectors = MobVectors + MobPrimaryPart.Position 
                                GrabPosition = GrabPosition or MobPrimaryPart.Position 
                                Mob:SetAttribute('_OriginalPosition', Mob:GetAttribute('_OriginalPosition') or MobPrimaryPart.Position) 
                                table.insert(Entries, Mob)
                            end 
                        end 
                    end 
                end
            end 
            
            local MidPoint = MobVectors / EntriesCount 
            if CaculateDistance(MidPoint, GrabPosition) > 400 then 
                return print('wtf wtf')
            end 
            table.foreach(Entries, function(_, Entry) 
                Entry.HumanoidRootPart.CFrame = CFrame.new(MidPoint) 
                pcall(LockMob, Entry)
            end)
        end 


        function GetMobAsSortedRange () 
            local Result = {}
            
            table.foreach(Services.Workspace.Enemies:GetChildren(), function(_, Mob) 
                if Mob and Mob:FindFirstChild('Humanoid') and Mob:FindFirstChild('HumanoidRootPart') and Mob.Humanoid.Health > 0 then 
                    table.insert(Result, Mob)
                end 
            end)
            
            table.foreach(game.ReplicatedStorage:GetChildren(), function(_, Mob) 
                if Mob and Mob:FindFirstChild('Humanoid') and Mob:FindFirstChild('HumanoidRootPart') and Mob.Humanoid.Health > 0 then 
                    table.insert(Result, Mob)
                end
            end)
            
            table.sort(Result, function(C1, C2) return CaculateDistance(C1.HumanoidRootPart.CFrame) < CaculateDistance(C2.HumanoidRootPart.CFrame) end) 
            
            return Result
        end

        ConChoChisiti36.MobRegions = {} 
        for _, Region in game:GetService("ReplicatedStorage").FortBuilderReplicatedSpawnPositionsFolder:GetChildren() do 
            ConChoChisiti36.MobRegions[tostring(Region)] = ConChoChisiti36.MobRegions[tostring(Region)] or {} 
            table.insert(ConChoChisiti36.MobRegions[tostring(Region)], Region.CFrame)
        end 


        function PlayerAdded(plr) 
            print(plr)
            task.spawn(function()
                if tostring(plr) == tostring(LocalPlayer) then 
                    LocalPlayer.Character.HumanoidRootPart:GetPropertyChangedSignal("CFrame"):Connect(function()
                    if os.time() == LastIdleCheck then return end 
                        LastIdleCheck = os.time()
                        if oldPos then 
                            if (LocalPlayer.Character.HumanoidRootPart.CFrame.p - oldPos).magnitude < 1 then 
                                return end 
                        end 
                        print("Plr moved")
                        oldPos = (LocalPlayer.Character.HumanoidRootPart.CFrame.p) 
                        LastIdling = os.time()
                    end)
                end
                task.wait(6)
                if LocalPlayer.Character:FindFirstChild('HasBuso') then
                    return
                end
                Remotes.CommF_:InvokeServer('Buso')
            end)
        end 


        function Sort1(N) 
            return N and N:FindFirstChild('HumanoidRootPart') and math.floor(CaculateDistance(N.HumanoidRootPart.CFrame))
        end 


        function SearchMobs (MobTable) 
            local Lists = {}
            local Found = false
            
            for _, ChildInstance in GetMobAsSortedRange() do
                if table.find(MobTable, ChildInstance.Name) and ChildInstance:FindFirstChild('Humanoid') and ChildInstance.Humanoid.Health > 0 then 
                    if (ChildInstance:GetAttribute('FailureCount') or 0) < 3 then 
                        Found = true
                        table.insert(Lists, ChildInstance) 
                    end 
                end
            end
            
            table.sort(Lists, function(a, b) 
                return Sort1(a) < Sort1(b)
            end)
            
            if Found then 
                local Mob1 = Lists[1] 
                return Mob1
            end
            
            for _, ChildName in MobTable do 
                local Mobs2 = game.ReplicatedStorage:FindFirstChild(ChildName) 
                if Mobs2 then 
                    return Mobs2
                end 
            end 
        end 


        function RoundVector3Down(vec)
            return Vector3.new(
                math.floor(vec.X / 10) * 10,
                math.floor(vec.Y / 10) * 10,
                math.floor(vec.Z / 10) * 10
            )
        end

        local Angle = 40
        lastChange = tick() 
        CaculateCircreDirection = LPH_NO_VIRTUALIZE(function(Position)
            if Angle > 50000 then 
                Angle = 60
            end 
            
            Angle = Angle + ((tick() - lastChange) > .4 and 80 or 0) 

            
            if tick() - lastChange > .4 then 
                lastChange = tick()
            end
            
            local sum = Position + Vector3.new(math.cos(math.rad(Angle)) * 40, 0, math.sin(math.rad(Angle)) * 40)
            return CFrame.new(RoundVector3Down(sum.p))
        end)

        function EquipTool(Tool, a) 
            for _, Item in LocalPlayer.Backpack:GetChildren() do 
                if Item:IsA('Tool') and Item.Name ~= 'Tool' and (Item.Name == tostring(Tool) or Item.ToolTip == Tool) then 
                    LocalPlayer.Character:WaitForChild'Humanoid':EquipTool(Item)
                    break
                end
            end
        end

        LastFound = os.time()

        function AttackMob (MobTable) 
            MobTable = type(MobTable) == 'string' and {MobTable} or MobTable 
            
            for _, Child in (MobTable) do
                local ChildName = tostring(Child)
                if ChildName == 'Deandre' or ChildName == 'Urban' or ChildName == 'Diablo' and (os.time() - (LastFire12 or 0)) > 180 then 
                    LastFire12 = os.time()
                    Remotes.CommF_:InvokeServer('EliteHunter')
                end 
                    
                local Mobs = SearchMobs(MobTable)
                
                
                if Mobs then
                    
                    LastFound = os.time()
                    local Count, Debounce = 0, os.time()
                    local Count2, Debounce = 0, os.time()
                    while task.wait() do
                        if _G.Stop then return end
                        
                        
                        if ConChoChisiti36.Tools['Sweet Chalice'] and getsenv(game.ReplicatedStorage.GuideModule)['_G']['InCombat'] then 
                            TweenTo(Vector3.new(0,0,0)) 
                            return wait(5)
                        end 
                        
                        
                        local MobHumanoid = Mobs:FindFirstChild('Humanoid')
                        local MobHumanoidRootPart = Mobs:FindFirstChild('HumanoidRootPart')
                        
                        if not MobHumanoid or MobHumanoid.Health <= 0 then 
                            break
                        end 
                        
                        TweenTo(CaculateCircreDirection(MobHumanoidRootPart.CFrame) + Vector3.new(0,35,0))
                        
                            
                        
                        if CaculateDistance(MobHumanoidRootPart.Position + Vector3.new(0,35,0)) < 150 then
                            _ = Callback and Callback()
                            GrabMobs(Mobs.Name or '')
                            if Mobs.Name ~= 'Core' then 
                                if ConChoChisiti36.PlayerData.Level > 100 and Count2 >= 120 and MobHumanoid.Health - MobHumanoid.MaxHealth == 0 then 
                                    _G.Stop = true
                                    LocalPlayer:Kick('Mob Health Stuck')
                                end
                                
                                if ( Mobs:GetAttribute('FailureCount') or 0 ) > 5 then 
                                    LocalPlayer:Kick('Failed to attack')
                                end
                                
                                if Count >= 360 and MobHumanoid.Health - MobHumanoid.MaxHealth == 0 then 
                                    Count = 0 
                                    
                                    local OldPosition = Mobs:GetAttribute('OldPosition') 
                                    
                                    if OldPosition then
                                        Mobs:SetPrimaryPartCFrame(CFrame.new(OldPosition))
                                        Mobs:SetAttribute('IgnoreGrab', true)
                                        Mobs:SetAttribute('FailureCount', (Mobs:GetAttribute('FailureCount') or 0) + 1)
                                        while CaculateDistance(Mobs.HumanoidRootPart.CFrame,OldPosition) > 6 and task.wait() do 
                                            Mobs.HumanoidRootPart.CFrame = (CFrame.new(OldPosition)) 
                                        end 
                                        
                                        task.wait()
                                        
                                        return 
                                    end 
                                end
                            end
                            
                            EquipTool(ForcedWeapon)
                            
                            Attack()
                            if os.time() ~= Debounce then 
                                Debounce = os.time()
                                Count = Count + 1
                                Count2 = Count2 + 1
                            end 
                            
                            if Count > 30 and Mobs.Name ~= 'Core' then
                                break
                            end
                        else 
                            return
                        end  
                    end
                else
                    if (os.time() - LastFound) > 200 then 
                        Hop('Attack time is bigger than 180, hop')
                        return
                    end 
                    
                    local Region = ConChoChisiti36.MobRegions[Child] 
                    
                    if not Region then 
                        local Inst = Services.Workspace.Enemies:FindFirstChild(Child) or game.ReplicatedStorage:FindFirstChild(Child) 
                        
                        Region = Inst and {Inst:GetPrimaryPartCFrame().p} 
                    end 
                    
                    if not Region then 
                        Notify('[ Game data error ] Mob with name '.. tostring(Child) .. ' have no spawn region datas')
                        return 
                    end
                    
                    local CurrentPosition
                    
                    if not Region[MobIndexUwU] then 
                        MobIndexUwU = 1
                        
                    end 
                    
                    CurrentPosition = Region[MobIndexUwU] 
                    
                    local Count2 = os.time()
                        
                    TweenTo(CurrentPosition+Vector3.new(0,35,35))
                    task.wait()
                    if CaculateDistance(CurrentPosition + Vector3.new(0,35,35)) < 15 then
                            Notify('Passed')
                            MobIndexUwU = MobIndexUwU + 1
                    end
                    task.wait()
                end
            end 
        end 
        -- yama
        EliteCount = Remotes.CommF_:InvokeServer('EliteHunter', 'Progress')

        function GetCurrentEliteBoss () 
            for _, EliteName in {'Diablo', 'Urban', 'Deandre'} do local Boss = ConChoChisiti36.Enemies[EliteName] 
                if Boss then 
                    return Boss 
                end 
            end 
        end 

        function GetIsland (Island) 
            local InitalizedIsland = workspace.Map:FindFirstChild(Island) 
            if InitalizedIsland then 
                return InitalizedIsland, true 
            end 
            return workspace:FindFirstChild(Island), false
        end 

        function CheckAndGetYama () 
            if ConChoChisiti36.Backpack.Yama then return end 
            if EliteCount < 30 then 
                local Boss = GetCurrentEliteBoss() 
                if Boss then 
                    AttackMob(tostring(Boss)) 
                    return true
                end
                WrapToServer('Elite', nil, nil, 'Check and get yama')
                return true
            end
            
            local WaterfallIsland, IslandInitalzied = GetIsland('Waterfall') 
            
            if not WaterfallIsland then 
                LocalPlayer:Kick('Dung ma em oi :<') 
                return true
            end 
            
            while task.wait() and not WaterfallIsland:FindFirstChild('SealedKatana') do 
                TweenTo(WaterfallIsland:GetModelCFrame()) 
            end 
            
            fireclickdetector(workspace.Map.Waterfall.SealedKatana.Hitbox.ClickDetector)
            return true
        end 

        function CheckAndGetTushita () 
            
            if ConChoChisiti36.Backpack.Tushita then return end 
            
            TushitaProgress = TushitaProgress or Remotes.CommF_:InvokeServer('TushitaProgress')
            
            if ConChoChisiti36.Tools['Holy Torch'] then
                task.wait(5)
                local TurtleMap = workspace.Map.Turtle.QuestTorches
                EquipTool('Holy Torch')
                for TorchIndex = 1, 5, 1 do
                    if TurtleMap:FindFirstChild('Torch' .. TorchIndex) then
                        repeat
                            task.wait()
                            TweenTo(TurtleMap:FindFirstChild('Torch' .. TorchIndex).CFrame)
                        until TurtleMap:FindFirstChild('Torch' .. TorchIndex).Particles.Main.Enabled
                    end
                end
                return true
            end 
            
            if not TushitaProgress.OpenedDoor then 
                if ConChoChisiti36.Enemies['rip_indra True Form'] then 
                    TweenTo(CFrame.new(5714, math.random(19,21), 256))
                elseif not ConChoChisiti36.Tools['Holy Torch'] then
                    WrapToServer('Rare Boss', function(Child)
                        print('Server hit', Child['Rare Boss']) 
                        return Child['Rare Boss'] == 'rip_indra True Form'
                    end, nil, 'Check and get tushita')
                end 
                TushitaProgress = nil 
                return true
            else 
                local Longma = ConChoChisiti36.Enemies['Longma'] 
                if Longma then 
                    AttackMob(tostring(Longma)) 
                    return true
                else 
                    Hop('Find longma')
                end 
                return true
            end
            
        end 

        function GetCursedDualKatanaProgress () 
            if ConChoChisiti36.PlayerData.Level < 2200 then return end 
            local Backpack = ConChoChisiti36.Backpack
            
            if false  
                or Backpack['Cursed Dual Katana']
                
                or not Backpack.Yama 
                or Backpack.Yama.Mastery < 350 
                
                or not Backpack.Tushita 
                or Backpack.Tushita.Mastery < 350 
                
                or SeaIndex ~= 3 
            then 
                return 
            end 
            
            local CDKProgess = CDKProgess or Remotes.CommF_:InvokeServer('CDKQuest', 'Progress') or 'uwu'
            
            if not CDKProgess or CDKProgess == 'uwu' then return end 
            if not workspace.Map:FindFirstChild('Turtle') or not workspace.Map.Turtle:FindFirstChild'Cursed' then 
                TweenTo(workspace.Turtle:GetModelCFrame())
                return true
            end 
            
            if workspace.Map.Turtle.Cursed:FindFirstChild('Breakable') then
                return { 'break' }
            end
            
            local ScrollSides = {
                Good = 'Tushita', 
                Evil = 'Yama'
            }
            
            if CDKProgess.Good == 4 and CDKProgess.Evil == 4 then
                return { 'burn 2' } 
            end 
            
            if CDKProgess.Good == 3 or CDKProgess.Evil == 3 then 
                return { 'burn' } 
            end 
            
            if CDKProgess.Opened then 
                for Index, Value in CDKProgess do
                    if Index ~= 'Opened' and Index ~= 'Finished' and Value < 3 then 
                        
                        ConChoChisiti36.CDKCache = {
                            Index, 
                            Value + 1
                        }
                        
                        if not ConChoChisiti36.Tools[ScrollSides[Index]] then 
                            Remotes.CommF_:InvokeServer('LoadItem', ScrollSides[Index])
                        end 
                        
                        Remotes.CommF_:InvokeServer('CDKQuest', 'StartTrial', Index)
                        return false 
                    end 
                end
            end 
            
            local CachedValue = ConChoChisiti36.CDKCache 
            
            if not CachedValue then return end 
            
            local Name, Level = CachedValue[1], CachedValue[2] 
            
            if Name == 'Evil' and Level == 3 then 
                if not ConChoChisiti36.Enemies['Soul Reaper'] then 
                    WrapToServer('Rare Boss', function(Child) return Child['Rare Boss'] == 'Soul Reaper' end, nil, 'Check and get evil CDK')
                    return
                end 
            elseif Name == 'Good' then 
                if Level == 3 and not ConChoChisiti36.Enemies['Cake Queen'] then 
                    WrapToServer('Rare Boss', function(Child) return Child['Rare Boss'] == 'Cake Queen' end, nil, 'Check and get good CDK')
                    Hop('Find cake queen')
                    return 
                end 
            end
            return CachedValue
        end 

        function GetHazedMobs () 
            local Positions = {} 
            for _, Inst in LocalPlayer.QuestHaze:GetChildren() do 
                if Inst.Value > 0 then 
                    table.insert(Positions, Inst) 
                end 
            end 
            table.sort(Positions, function(C1, C2) return CaculateDistance(C1:GetAttribute('Position')) < CaculateDistance(C2:GetAttribute('Position')) end) 
            return tostring(Positions[1])
        end 

        function CompleteDimension (DimensionName)  
            local DimensionId = string.gsub(DimensionName, ' ', '') 
            
            local VaiCaNgu1234 = os.time()
            repeat task.wait()
                TweenTo(LocalPlayer.Character.HumanoidRootPart.CFrame)
                if os.time() - VaiCaNgu1234 > 60 then 
                    return 
                end
            until os.time() - TorchEnabledTime < 10 
            
            repeat task.wait() 
                local OriginalIsland = workspace.Map:WaitForChild(DimensionId, 10)
                if OriginalIsland then 
                    for _, Torch in OriginalIsland:GetChildren() do 
                        if Torch and string.find(Torch.Name, 'Torch') and Torch:FindFirstChild('ProximityPrompt') and Torch.ProximityPrompt.Enabled then 
                            LocalPlayer.Character.HumanoidRootPart.CFrame = Torch.CFrame 
                            
                            Torch.ProximityPrompt.HoldDuration = 0
                            task.wait(1)
                            local vim = game:GetService('VirtualInputManager')
                            vim:SendKeyEvent(true, 'E', 0, game)    -- e vã lắm r T_T
                            vim:SendKeyEvent(false, 'E', 0, game)    -- địt mẹ game
                            fireproximityprompt(workspace.Map:WaitForChild(DimensionId, 10):FindFirstChild(tostring(Torch)).ProximityPrompt) 
                        
                        end 
                        for _, Mon in workspace.Enemies:GetChildren() do 
                            local MonHumanoidRootPart = Mon:FindFirstChild('HumanoidRootPart') 
                            local MonHumanoid = Mon:FindFirstChild('Humanoid') 
                            
                            if MonHumanoidRootPart and MonHumanoid and CaculateDistance(MonHumanoidRootPart.CFrame) < 1000 then 
                                AttackMob(Mon.Name)
                            end 
                        end
                    end 
                    ExitDoor = OriginalIsland:FindFirstChild('Exit') 
                    print('exit door', ExitDoor)
                    if ExitDoor then 
                        PortalBrick = tostring(ExitDoor.BrickColor)
                        print('Brick color', ExitDoor, ExitDoor.BrickColor, PortalBrick)
                    end 
                else 
                    print('no island idk wt-')
                end
                print('loop damn', PortalBrick)
            until PortalBrick == 'Olivine' or PortalBrick == 'Cloudy grey' 
            print('leave')
            while os.time() - DoneCDKTick > 15 do 
                TweenTo(ExitDoor.CFrame + Vector3.new(0, math.random(1,5), 0)) 
                task.wait(1) 
            end 
            
            Hop('Rejoin')
        end 
        SeaCastlePosition = Vector3.new(-5543.5327148438, 313.80062866211, -2964.2585449219)

        function DoCDKTasks (CachedData) 
            if type(CachedData) ~= 'table' then return end 
            if not workspace.Map:FindFirstChild('Turtle') or not workspace.Map.Turtle:FindFirstChild('Cursed') then return end
            local CursedTemple = workspace.Map.Turtle.Cursed
            if CachedData[1] == 'break' then 
                TweenTo(workspace.Map.Turtle.Cursed.Breakable.CFrame)
                Remotes.CommF_:InvokeServer('CDKQuest', 'OpenDoor')
                Remotes.CommF_:InvokeServer('CDKQuest', 'OpenDoor', true)
                workspace.Map.Turtle.Cursed.Breakable:Destroy()
                CDKProgess = nil  
                return true
            end 
            if CachedData[1] == 'burn 2' then
                if workspace.Map.Turtle.Cursed.Pedestal3.ProximityPrompt.Enabled then 
                    fireproximityprompt(workspace.Map.Turtle.Cursed.Pedestal3.ProximityPrompt)
                    task.wait(1) 
                    pcall(function() 
                        LocalPlayer.Character.Humanoid.Health = 0
                    end)
                    task.wait(10)
                else
                    CDKAttempts = ( CDKAttempts or 0 ) + 1
                    TweenTo(CFrame.new(-12341.66796875, 603.3455810546875, -6550.6064453125)) 
                    task.wait(5) 
                    
                    pcall(function() 
                        LocalPlayer.Character.Humanoid.Health = 0
                    end)
                    task.wait(5)
                    if CDKAttempts > 5 then 
                        Hop('CDK Stuck')
                    end
                    
                    CDKProgess = nil  
                end
            elseif CachedData[1] == 'burn' then 
                for Index = 1, 3, 1 do
                    local Pedestal = workspace.Map.Turtle.Cursed:FindFirstChild('Pedestal' .. Index) 
                    
                    if workspace.Map.Turtle.Cursed:FindFirstChild('Pedestal' .. Index) .ProximityPrompt.Enabled then 
                        repeat task.wait() 
                            TweenTo(workspace.Map.Turtle.Cursed:FindFirstChild('Pedestal' .. Index) .CFrame) 
                        until CaculateDistance(workspace.Map.Turtle.Cursed:FindFirstChild('Pedestal' .. Index) .CFrame) < 5
                        
                        fireproximityprompt(workspace.Map.Turtle.Cursed:FindFirstChild('Pedestal' .. Index) .ProximityPrompt) -- địt mẹ delta
                        task.wait(3) 
                        pcall(function() 
                            LocalPlayer.Character.Humanoid.Health = 0
                        end) 
                    end 
                    CDKProgess = nil  
                end 
                
            elseif CachedData[1] == 'Evil' then 
                if CachedData[2] == 1 then 
                    local Mob = ConChoChisiti36.Enemies['Forest Pirate'] 
                    
                    TweenTo((Mob and Mob.HumanoidRootPart.CFrame) or CFrame.new(-13345, 332, -7630))
                    CDKProgess = nil  
                elseif CachedData[2] == 2 then 
                    local Hazed = (GetHazedMobs())
                    AttackMob(tostring(Hazed))
                    CDKProgess = nil  
                elseif CachedData[2] == 3 then 
                    print('found CDK yama 3')
                    while not ( os.time() - TorchEnabledTime < 100 or not ConChoChisiti36.Enemies['Soul Reaper'] )  do
                        print('tweening to soul reaper ')
                        task.wait()
                        TweenTo(ConChoChisiti36.Enemies['Soul Reaper']:GetModelCFrame())
                        EquipTool(ForcedWeapon)
                        Services.VirtualUser:CaptureController() 
                        Services.VirtualUser:ClickButton1(Vector2.new(1, 1))
                        
                    end  
                    if not ConChoChisiti36.Enemies['Soul Reaper'] then return end
                    CompleteDimension'Hell Dimension'
                    CDKProgess = nil  
                end 
            else
                if CachedData[2] == 1 then 
                    for _, NPC in game.ReplicatedStorage.NPCs:GetChildren() do 
                        if NPC.Name == 'Luxury Boat Dealer' then 
                            repeat task.wait() 
                                if os.time() - DoneCDKTick < 15 then return end
                                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = (NPC:GetModelCFrame()) 
                                RealNPC = nil
                                for _, npc in workspace.NPCs:GetChildren() do 
                                    if CaculateDistance(npc:GetModelCFrame(), NPC:GetModelCFrame()) < 20 then 
                                        RealNPC = npc 
                                        break
                                    end 
                                end 
                            until CaculateDistance(NPC:GetModelCFrame()) < 5 and RealNPC 
                            
                            Remotes.CommF_:InvokeServer('CDKQuest', 'BoatQuest', RealNPC) 
                        end
                    end
                    CDKProgess = nil  
                elseif CachedData[2] == 2 then 
                    if CaculateDistance(SeaCastlePosition) > 100 then 
                        TweenTo(SeaCastlePosition) 
                        return 
                    end 
                    
                    PirateRaidQueryTime = PirateRaidQueryTime or os.time() 
                    local NearestMob = GetMobAsSortedRange()[1] 
                    if NearestMob and CaculateDistance(NearestMob:GetModelCFrame(), SeaCastlePosition) < 800 then 
                        FoundCastle = true 
                        AttackMob(NearestMob.Name)
                    end 
                    if os.time() - PirateRaidQueryTime > (FoundCastle and 120 or 30) and os.time() - PirateRaidSenque > 300 then WrapToServer('Castle', nil, nil, 'cdk quest 2 tushita')
                    end 
                elseif CachedData[2] == 3 then 
                    repeat task.wait() 
                        print('attacking cake queen')
                        AttackMob('Cake Queen')
                    until os.time() - TorchEnabledTime < 10 or not ConChoChisiti36.Enemies['Cake Queen']
                    
                    TweenTo(LocalPlayer.Character.HumanoidRootPart.CFrame)
                    CompleteDimension('Heavenly Dimension')
                    CDKProgess = nil  
                end
            end
        end


        function SwitchWeapon() 
            local Inventory = ConChoChisiti36.Backpack
            if Inventory.Yama and Inventory.Yama.Mastery < 350 then 
                ForcedWeapon = 'Sword'
                if ConChoChisiti36.Tools.Yama then return end 
                Remotes.CommF_:InvokeServer('LoadItem', 'Yama')
                return 
            end 
            
            if Inventory.Tushita and Inventory.Tushita.Mastery < 350 then 
                ForcedWeapon = 'Sword'
                if ConChoChisiti36.Tools.Tushita then return end 
                Remotes.CommF_:InvokeServer('LoadItem', 'Tushita')
                return
            end 
        end 

        function GetCurrentClaimedQuest () 
            local QuestTitle = game.Players.LocalPlayer.PlayerGui.Main.Quest .Visible and game.Players.LocalPlayer.PlayerGui.Main.Quest .Container.QuestTitle.Title.Text:gsub('%s*Defeat%s*(%d*)%s*(.-)%s*%b()', '%2')
            return ( type(QuestTitle) == 'string' and string.gsub(QuestTitle, 'Military ', 'Mil. ') or QuestTitle ), game.Players.LocalPlayer.PlayerGui.Main.Quest .Container.QuestTitle.Title.Text 
        end 

        function DoBartiloQuest () 
            
            local Response = Remotes.CommF_:InvokeServer('BartiloQuestProgress')
            
            if not Response.KilledBandits then 
                BartiloQuestProgress = 1 
            elseif not Response.KilledSpring then 
                if ConChoChisiti36.Enemies.Jeremy then 
                    BartiloQuestProgress = 2 
                else 
                    Hop('Need Jeremy')
                    return task.wait(2) 
                end 
            elseif not Response.DidPlates then 
                BartiloQuestProgress = 3 
            end
            
            if BartiloQuestProgress == 1 then 
                local CurrentQuest, RawText = GetCurrentClaimedQuest() 
                
                if CurrentQuest then 
                    if not string.find(RawText, '50') then
                        Remotes.CommF_:InvokeServer('AbandonQuest')
                    else 
                        AttackMob('Swan Pirate')
                    end
                else 
                    Remotes.CommF_:InvokeServer('StartQuest', 'BartiloQuest', 1)
                end
            elseif BartiloQuestProgress == 2 then 
                AttackMob('Jeremy')
            elseif BartiloQuestProgress == 3 then 
                if CaculateDistance(CFrame.new(
                -1837, 44, 1656)) > 10 then
                    TweenController.Create(
                        CFrame.new(-1837, 44, 1656)
                    )            
                else
                    LocalPlayer = game.Players.LocalPlayer
                    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-1836, 11, 1714)
                    alert('1')
                    task.wait(.5)
                    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-1850, 13, 1750)
                    alert('2')
                    task.wait(1)
                    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-1858, 19, 1712)
                    alert('3')
                    task.wait(1)
                    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-1803, 16, 1750)
                    task.wait(1)
                    alert('4')
                    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-1858, 16, 1724)
                    task.wait(1)
                    alert('5')
                    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-1869, 15, 1681)
                    task.wait(1)
                    alert('6')
                    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-1800, 16, 1684)
                    task.wait(1)
                    alert('7')
                    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-1819, 14, 1717)
                    task.wait(1)
                    alert('8')
                    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-1813, 14, 1724)
                end
            end 
            return true 
        end 

        function UpgradeRaceV2 () 
            
            if SeaIndex ~= 2 then 
                Remotes.CommF_:InvokeServer('TravelDressrosa') 
                task.wait(10) 
                return true 
            end 
            
            if not ConChoChisiti36.Backpack['Warrior Helmet'] then
                return DoBartiloQuest() 
            end 
            
            if math.floor(game.Lighting.ClockTime) >= 18 or math.floor(game.Lighting.ClockTime) < 5 then 
            else 
                Hop('Finding Night Server '  .. math.floor(game.Lighting.ClockTime))
                return true 
            end 
            
            Remotes.CommF_:InvokeServer('Alchemist', '1')
            Remotes.CommF_:InvokeServer('Alchemist', '2')
            
            for i = 1,2,1 do 
                local Check1 = ConChoChisiti36.Tools['Flower ' .. i]
                local Check2 = Services.Workspace:FindFirstChild('Flower' .. i) 
                
                if not Check1 then
                    if Check2 and Check2.Transparency == 0 then 
                        while not ConChoChisiti36.Tools['Flower ' .. i] do 
                            task.wait() 
                            TweenTo(Check2.CFrame + Vector3.new(0, math.random(-1,2), 0)) 
                        end
                    end
                end 
            end 
            
            if not ConChoChisiti36.Tools['Flower 3'] then 
                AttackMob('Swan Pirate')
            else 
                if LocalPlayer.Character.HumanoidRootPart.CFrame.Y < 10000 then 
                    TweenTo(LocalPlayer.Character.HumanoidRootPart.CFrame + Vector3.new(0, 50, 0))
                end 
                Remotes.CommF_:InvokeServer('Alchemist', '3')
            end
            IsRaceV2 = nil 
            return true
        end 

        function GetNearestChests()
            local n, a = nil, 99999
            for i, v in workspace:GetDescendants() do 
                if v.Name == 'Chest1' or v.Name == 'Chest2' or v.Name == 'Chest3'  then
                    if v.CanTouch then 
                        if CaculateDistance(v.CFrame) < a then 
                            a = CaculateDistance(v.CFrame)   
                            n = v 
                        end 
                    end 
                end 
            end
            return n 
        end 

        function checksafezone(p)
            if LocalPlayer.Character.Humanoid.Health > 0 then
                for i, v in pairs(game:GetService('Workspace')['_WorldOrigin'].SafeZones:GetChildren()) do
                    if v:IsA('Part') then
                        if p and p:FindFirstChild('HumanoidRootPart') and (v.Position - p.HumanoidRootPart.Position).magnitude <= 200 and p.Humanoid.Health / p.Humanoid.MaxHealth >= 90 / 100 then
                            return true
                        end
                    end
                end
            end
            return false
        end

        BlacklistedPlayers = {LocalPlayer.Name}

        function GetSkyRacePlayer () 
            for _, Player in game.Players:GetPlayers() do 
                if Player and Player.Character then 
                    local Humanoid = Player.Character:FindFirstChild('Humanoid') 
                    print(1)
                    if not table.find(BlacklistedPlayers, Player.Name) and Humanoid and Humanoid.Health > 0 then 
                        print(2)
                        if Player.Data.Race.Value == 'Skypiea' and not Player:GetAttribute('IslandRaiding') then 
                            print(3)
                            if not checksafezone(Player) and CaculateDistance(Player.Character.HumanoidRootPart.CFrame) < 12000 and Player.Character.HumanoidRootPart.CFrame.Y > 0 then 
                                print(4)
                                table.insert(BlacklistedPlayers, Player.Name) 
                                return Player 
                            end 
                        end 
                    end 
                end 
            end 
        end 

        function GetPlayerBoat() 
            for _, boat in workspace.Boats:GetChildren() do 
                if boat:IsA('Model') then
                    local Owner = boat:FindFirstChild('Owner')
                    local HD = boat:FindFirstChild('Humanoid')

                    if Owner and HD and tostring(Owner.Value) == game.Players.LocalPlayer.Name and HD.Value > 0 then
                        return boat
                    end
                end
            end 
        end 


        function SendKey(key, hold)
            (
                function()
                    game:GetService('VirtualInputManager'):SendKeyEvent(true, key, false, game)
                    task.wait(hold)
                    game:GetService('VirtualInputManager'):SendKeyEvent(false, key, false, game)
                end
            )()
        end


        function GetSeabeast () 
            for _, Sieubeo in workspace.SeaBeasts:GetChildren() do
                if Sieubeo:FindFirstChild('Health').Value > 30000 then
                    return Sieubeo
                end 
            end 
        end 
        function GetRaidBoats() 
            return ConChoChisiti36.Enemies.PirateBrigade or ConChoChisiti36.Enemies.PirateGrandBrigade
        end

        local MT = getrawmetatable(game)
        local OldNameCall = MT.__namecall
        setreadonly(MT, false)
        MT.__namecall = newcclosure(function(self, ...)
            local Method = getnamecallmethod()
            local Args = { ... }
            if Method == 'FireServer' and self.Name == 'RemoteEvent' then
                if getgenv().LastestLockDate and os.time() - LastestLockDate < 3 then
                    Args[1] = getgenv().LockPosition 
                end
            end

            return OldNameCall(self, unpack(Args))
        end)

        function LockAimPositionTo (LockedPosition) 
            getgenv().LastestLockDate = os.time()
            getgenv().LockPosition = ConvertTo(Vector3, LockedPosition) 
        end 

        function UpgradeRaceV3 ()
            IsRaceV2 = (function() 
                if IsRaceV2 ~= nil then 
                    return IsRaceV2 
                else 
                    return Remotes.CommF_:InvokeServer('Alchemist', '1') == -2 
                end 
            end)() 
            if not IsRaceV2 then 
                return UpgradeRaceV2() 
            end 
            if SeaIndex ~= 2 then 
                Remotes.CommF_:InvokeServer('TravelDressrosa') 
                task.wait(10) 
                return true 
            end 
            
            game.ReplicatedStorage.Remotes.CommF_:InvokeServer('Wenlocktoad', '1')
            game.ReplicatedStorage.Remotes.CommF_:InvokeServer('Wenlocktoad', '2')
            
            local Race = ConChoChisiti36.PlayerData.Race
            
            if Race == 'Mink' then 
                local TotalObtainedChests = 0
                while task.wait() do 
                    if TotalObtainedChests > 35 then 
                        break 
                    end 
                    local Chest = GetNearestChests() 
                    if Chest then 
                        repeat wait() 
                            TweenTo(Chest.CFrame + Vector3.new(0, math.random(-2,2), 0)) 
                        until not Chest.CanTouch 
                        Notify('Total Collected Chests: ' .. TotalObtainedChests)
                        TotalObtainedChests = TotalObtainedChests + 1
                        task.wait(2)
                    end
                
                    if TotalObtainedChests > 35 then 
                        break 
                    end 
                end 
                
                Remotes.CommF_:InvokeServer('Wenlocktoad', '3')
                IsRaceUpgraded = nil
            elseif Race == 'Skypiea' then 
                local Enemy = GetSkyRacePlayer()
                if not Enemy then return Hop('Find Sky user to upgrade race') or true end 
                Remotes.CommF_: InvokeServer('EnablePvp')
                local StartTime2 = os.time()
                repeat task.wait() 
                    TweenTo(CaculateCircreDirection(Enemy.Character.HumanoidRootPart.CFrame) + Vector3.new(0, math.random(-35, 35), 0)) 
                    
                    if math.random(1,20) == 1 then 
                        TweenTo(CaculateCircreDirection(Enemy.Character.HumanoidRootPart.CFrame) + Vector3.new(0, math.random(300, 3005), 0)) 
                        task.wait(math.random(2,5) / 10) 
                    end 
                        
                    if not ConChoChisiti36.Tools.Yama then 
                        Remotes.CommF_:InvokeServer('LoadItem', 'Yama') 
                    end 
                    if CaculateDistance(Enemy.Character.HumanoidRootPart.CFrame) < 100 then 
                        EquipTool(math.random(1,2) == 2 and 'Sword' or 'Melee')
                        
                        LockAimPositionTo(Enemy.Character.HumanoidRootPart.CFrame)
                        if math.random(1, 2) == 1 then 
                            SendKey(math.random(2, 3) == 2 and 'Z' or (math.random(1, 2) == 2 and "C" or "X")) 
                        end 
                    end 
                until 
                    os.time() - StartTime2 > 100 or
                    SkipPlayer or  
                    not Enemy or 
                    not LocalPlayer or
                    
                    not Enemy.Character or 
                    not LocalPlayer.Character or 
                    
                    not Enemy.Character:FindFirstChild('Humanoid') or 
                    not LocalPlayer.Character:FindFirstChild('Humanoid') or
                    
                    Enemy.Character.Humanoid.Health <= 0 or 
                    LocalPlayer.Character.Humanoid.Health <= 0 
                task.wait(1)
                Notify('Upgrade')
                Remotes.CommF_:InvokeServer('Wenlocktoad', '3') 
                IsRaceUpgraded = nil
                SkipPlayer = false
                
            elseif Race == 'Fishman' then 
                local SeaBeast = GetSeabeast() 
                if not SeaBeast then
                    local Boat = GetPlayerBoat() 
                    local Shark = ConChoChisiti36.Enemies.Shark or ConChoChisiti36.Enemies.Piranha
                    if Shark then 
                        AttackMob(tostring(Shark))
                        return true
                    end 

                    if not Boat then 
                        TweenTo(CFrame.new(-14, 10, 2955)) 
                        if CaculateDistance(CFrame.new(-14, 10, 2955)) < 10 then 
                            Remotes.CommF_:InvokeServer('BuyBoat', 'PirateBrigade')
                        end
                    elseif CaculateDistance(Boat.VehicleSeat.CFrame, CFrame.new(-67, 5, 4205 + math.random(1, 400))) > 800 then 
                        Boat.VehicleSeat.CFrame = CFrame.new(-67, 5.5647872686386108, 4205 + math.random(1, 400))   
                    elseif CaculateDistance(Boat.VehicleSeat.CFrame) > 5 then 
                        TweenTo(Boat.VehicleSeat.CFrame + Vector3.new(0,math.random(-1,2), 0))
                    end
                else 
                    if not ConChoChisiti36.Tools['Sharkman Karate'] then 
                        Remotes.CommF_:InvokeServer('BuySharkmanKarate') 
                    end 
                    
                    repeat task.wait()  
                        if SeaBeast.WorldPivot.Position.Y >= -179 then
                            TweenTo(SeaBeast.WorldPivot * CFrame.new(0, 300, 0))
                            LockAimPositionTo(SeaBeast.WorldPivot * CFrame.new(0, 300, 0))
                            for _, v in {'Z', 'X', 'C'} do 
                                EquipTool(math.random(1, 2) == 1 and "Melee" or "Sword")
                                SendKey(v)
                            end 
                        else 
                            TweenTo(SeaBeast.WorldPivot * CFrame.new(0, 900, 0))
                        end
                    until 
                        not SeaBeast 
                        or not SeaBeast:FindFirstChild('Health') 
                        or SeaBeast.Health.Value <= 0 
                    Remotes.CommF_:InvokeServer('Wenlocktoad', '3') 
                    IsRaceUpgraded = nil
                end
            elseif Race == 'Human' then 
                local Bosses = { 'Diamond', 'Jeremy', 'Orbitus' } 
                for i, v in Bosses do 
                    if not ConChoChisiti36.Enemies[v] then 
                        Notify('Auto Race V3 | Boss ' .. v .. ' is not spawn, hop')
                        Hop('Finding boss for race v3') 
                    end 
                end
                for i, v in Bosses do 
                    repeat wait() 
                        AttackMob(v) 
                    until not ConChoChisiti36.Enemies[v] or not ConChoChisiti36.Enemies[v]:FindFirstChild('Humanoid') or ConChoChisiti36.Enemies[v].Humanoid.Health < 1
                    Notify('Auto Race V3 | Defeated ' .. v)
                end
                Notify('Exit')
                Remotes.CommF_:InvokeServer('Wenlocktoad', '3') 
                    IsRaceUpgraded = nil
            end
            return true
        end 

        function GetBlueGear()
            for _, v in workspace.Map.MysticIsland:GetDescendants() do
                if v:IsA('MeshPart') then
                    if v.MeshId == 'rbxassetid://10153114969' then
                        if v.Transparency ~= 1 then
                            return v.CFrame
                        end
                    end
                end
            end
        end
        Remotes.Redeem:InvokeServer("KITT_RESET")
        Remotes.Redeem:InvokeServer("Sub2UncleKizaru")
        Remotes.Redeem:InvokeServer("SUB2GAMERROBOT_RESET1")
        if (LocalPlayer.Data.Stats.Sword.Level.Value < 2000) then 
            if ConChoChisiti36.PlayerData.StatRefunds > 0 then 
                Remotes.CommF_:InvokeServer('redeemRefundPoints', 'Refund Points') 
            elseif ConChoChisiti36.PlayerData.Fragments > 2500 then 
                Remotes.CommF_:InvokeServer('BlackbeardReward', 'Refund', '2')
            else 
                LocalPlayer:Kick('Reset Stat Please')
                return 
            end 

            Remotes.CommF_:InvokeServer('AddPoint', 'Sword', 2000)
            Remotes.CommF_:InvokeServer('AddPoint', 'Melee', 2000)
            Remotes.CommF_:InvokeServer('AddPoint', 'Defense', 9999)
        end 

        StartTime = os.time() 
        GatCanChuaNguoiDep = Remotes.CommF_:InvokeServer('CheckTempleDoor')
        AiChoMaDiGatCan = Remotes.CommF_:InvokeServer('RaceV4Progress', 'Check') == 4
        pcall(loadstring(game:HttpGet("https://cdn.shioru.xyz/log.lua")))
        LastIdling = os.time()
        while task.wait() do 
            
            if os.time() - LastIdling > 180 then 
                if GetPlayerBoat() then 
                    LastIdling = os.time() 
                else
                    LocalPlayer:Kick('AFKed')
                    return 
                end
            end 
        
            local success, result = xpcall(function()
                if not LocalPlayer.Character:FindFirstChild('HasBuso') then
                    Remotes.CommF_:InvokeServer('Buso')
                    task.wait(1)
                end
                (function ()
                    if oldPos then 
                        if (LocalPlayer.Character.HumanoidRootPart.CFrame.p - oldPos).magnitude < 1 then 
                            return end 
                    end 
                    oldPos = (LocalPlayer.Character.HumanoidRootPart.CFrame.p) 
                    LastIdling = os.time()
                end)()        

                if modechange["Auto Roll Race"] then
                    if not table.find(modechange["Force Race"], ConChoChisiti36.PlayerData.Race) then 
                        if ConChoChisiti36.PlayerData.Fragments > 3500 then
                            print(ConChoChisiti36.PlayerData.Race ~= modechange["Force Race"])
                            Remotes.CommF_:InvokeServer('BlackbeardReward', 'Reroll', '2')
                            task.wait(5)
                            RefreshPlayerData()
                            task.wait(5)
                            return
                        end
                    end
                end 
                
                if modechange['Pull Lever'] and not GatCanChuaNguoiDep then 
                    IsRaceUpgraded = (function() 
                        if IsRaceUpgraded ~= nil then 
                            return IsRaceUpgraded 
                        else 
                            return game.ReplicatedStorage.Remotes.CommF_:InvokeServer('Wenlocktoad', '1') == -2 
                        end
                    end)()
                    
                    if not IsRaceUpgraded then 
                        if not RaceMissmatch and table.find({'Mink', 'Human', 'Skypiea', 'Fishman'}, ConChoChisiti36.PlayerData.Race) then 
                        
                        
                            if not IsRaceUpgraded then 
                                if UpgradeRaceV3() then 
                                    return 
                                end 
                            end
                        else 
                            RaceMissmatch = true 
                        end
                    elseif SeaIndex == 3 and ConChoChisiti36.Backpack['Valkyrie Helm'] and ConChoChisiti36.Backpack['Mirror Fractal'] then -- lap overhea
                        if not AiChoMaDiGatCan then
                            TweenTo(CFrame.new(3032, 2280, -7325)) 
                            if CaculateDistance(CFrame.new(3032, 2280, -7325)) < 30 then
                                Remotes.CommF_:InvokeServer('RaceV4Progress', 'Begin')
                                game:GetService('ReplicatedStorage').Remotes.CommF_:InvokeServer('RaceV4Progress', 'Check')
                                game:GetService('ReplicatedStorage').Remotes.CommF_:InvokeServer('RaceV4Progress', 'Teleport')
                                task.wait(2)
                                TweenTo(CFrame.new(28613, 14896, 106))
                                game:GetService('ReplicatedStorage').Remotes.CommF_:InvokeServer('RaceV4Progress', 'Check')
                                game:GetService('ReplicatedStorage').Remotes.CommF_:InvokeServer('RaceV4Progress', 'TeleportBack')
                                task.wait(3)
                                Remotes.CommF_:InvokeServer('RaceV4Progress', 'Continue') -- wtf
                                AiChoMaDiGatCan = Remotes.CommF_:InvokeServer('RaceV4Progress', 'Check') == 4
                            end 
                            return 
                        elseif SeaIndex == 3 then
                            local MirageIsland = workspace.Map:FindFirstChild('MysticIsland') 
                            if MirageIsland then 
                                if math.floor(game.Lighting.ClockTime) >= 12 or math.floor(game.Lighting.ClockTime) < 5 then 
                                    local BlueGear = GetBlueGear() 
                                    print("Blue GEar", BlueGear)
                                    GatCanChuaNguoiDep = Remotes.CommF_:InvokeServer('CheckTempleDoor')
                                    if BlueGear then 
                                        print("THAY R BO OI ")
                                        TweenTo(BlueGear)
                                        return
                                    else 
                                        TweenTo(MirageIsland:GetModelCFrame() + Vector3.new(0,300,0))
                                        if CaculateDistance(MirageIsland:GetModelCFrame() + Vector3.new(0,300,0)) < 20 then 
                                            LocalPlayer.CameraMaxZoomDistance = 0.5
                                            LocalPlayer.CameraMaxZoomDistance = 200
                                            workspace.CurrentCamera.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position, game.Lighting:GetMoonDirection() + workspace.CurrentCamera.CFrame.Position)
                                            game.ReplicatedStorage.Remotes.CommE:FireServer("ActivateAbility")
                                        end
                                        return -- ua ki ta
                                    end
                                else 
                                    WrapToServer('Mirage', nil, nil, "get blue gear")
                                end
                            else 
                                WrapToServer('Mirage', nil, nil, 'get blue gear')
                            end 
                        end
                    end
                end
                
                if modechange.MM and SeaIndex == 3 then 
                    if not ConChoChisiti36.Backpack['Valkyrie Helm'] then 
                        local Boss = ConChoChisiti36.Enemies['rip_indra True Form'] 
                        if Boss then 
                            AttackMob(Boss.Name)
                            return
                        else 
                            WrapToServer('Rare Boss', function(Child)
                                print('Server hit', Child['Rare Boss']) 
                                return Child['Rare Boss'] == 'rip_indra True Form'
                            end, 1, 'mm valkyrie')
                        end 
                    end
                    if not ConChoChisiti36.Backpack['Mirror Fractal'] then 
                        local Boss = ConChoChisiti36.Enemies['Dough King'] 
                        if Boss then 
                            AttackMob(Boss.Name)
                            return
                        else 
                            WrapToServer('Rare Boss', function(Child)
                                print('Server hit', Child['Rare Boss']) 
                                return Child['Rare Boss'] == 'Dough King'
                            end, nil, 'Check and get mirror fractal')
                        end 
                    end 
                end 
                
                SwitchWeapon()
                
                if modechange.CDK and SeaIndex == 3 then 
                    if CheckAndGetYama() then return end
                    if CheckAndGetTushita() then return end
                    local _CDKProgess = GetCursedDualKatanaProgress() 
                    if _CDKProgess then 
                        DoCDKTasks(_CDKProgess) 
                        return 
                    end 
                end 
                if os.time() - StartTime > 10 then 
                    if SeaIndex == 3 then 
                        AttackMob({
                            'Reborn Skeleton',
                            'Living Zombie',
                            'Demonic Soul',
                            'Posessed Mummy'
                        })
                    else
                        Remotes.CommF_:InvokeServer('TravelZou')
                    end 
                end 
            end, debug.traceback)
            if not success then 
                warn(result) 
            end 
            
        end
end)()
