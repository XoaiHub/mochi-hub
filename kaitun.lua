local Config = {
    EnableQuest = getgenv().kaitun.Enable,
    EnableMotherBear = true,
    EnableBlackBear = true,
    MotherBearStopQuest = "Seven To Seven",
    FarmDuration = 30,
    MaxTokensPerScan = 20,
    EnableGearUpgrade = true,
    EnableAutoEgg = true,
    EnableAutoSell = true,
    TweenSpeed = tonumber(getgenv().kaitun.TweenSpeed) or 50,
    WalkSpeed = tonumber(getgenv().kaitun.WalkSpeed) or 60,
    SellTimeout = 90,
    MobDetectRange = 25,
    EnableMobAvoidance = true,
    EnableStarJelly = getgenv().kaitun.Sticker,
    FarmField = nil,
    FpsBoost = getgenv().kaitun.FpsBoost,
    CurrentAction = "Starting...",
}

repeat
    task.wait()
until game:IsLoaded()

if getgenv().kaitun.FpsBoost then
    local Terrain = workspace:FindFirstChildOfClass('Terrain')
    Terrain.WaterWaveSize = 0
    Terrain.WaterWaveSpeed = 0
    Terrain.WaterReflectance = 0
    Terrain.WaterTransparency = 0

    local Lighting = game:GetService("Lighting")
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9

    settings().Rendering.QualityLevel = 1

    for i, v in pairs(game:GetDescendants()) do
        if v:IsA("Part") or v:IsA("UnionOperation") or v:IsA("MeshPart") or v:IsA("CornerWedgePart") or v:IsA("TrussPart") then
            v.Material = "Plastic"
            v.Reflectance = 0
        elseif v:IsA("Decal") then
            v.Transparency = 1
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
            v.Lifetime = NumberRange.new(0)
        elseif v:IsA("Explosion") then
            v.BlastPressure = 1
            v.BlastRadius = 1
        end
    end

    for i, v in pairs(Lighting:GetDescendants()) do
        if v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") then
            v.Enabled = false
        end
    end

    workspace.DescendantAdded:Connect(function(child)
        task.spawn(function()
            if child:IsA('ForceField') then
                game:GetService("RunService").Heartbeat:Wait()
                child:Destroy()
            elseif child:IsA('Sparkles') then
                game:GetService("RunService").Heartbeat:Wait()
                child:Destroy()
            elseif child:IsA('Smoke') or child:IsA('Fire') then
                game:GetService("RunService").Heartbeat:Wait()
                child:Destroy()
            end
        end)
    end)
end

if getgenv().kaitun.UI then
    loadstring([[
            local TweenService = game:GetService("TweenService")
        local RunService = game:GetService("RunService")
        local Players = game:GetService("Players")

        local cf = function(x)
        local success, cloneref_func = pcall(function() return getfenv().cloneref end)
        if success and cloneref_func then
            return cloneref_func(x)
        end
        return x
        end

        local CoreGui = cf(game:GetService("CoreGui"))
        local LocalPlayer = Players.LocalPlayer
        local Tween = (function()
        local function getEasingStyle(style)
            if style == "Linear" then return Enum.EasingStyle.Linear end
            if style == "Quad" then return Enum.EasingStyle.Quad end
            if style == "Cubic" then return Enum.EasingStyle.Cubic end
            if style == "Quart" then return Enum.EasingStyle.Quart end
            if style == "Quint" then return Enum.EasingStyle.Quint end
            if style == "Sine" then return Enum.EasingStyle.Sine end
            if style == "Back" then return Enum.EasingStyle.Back end
            if style == "Bounce" then return Enum.EasingStyle.Bounce end
            if style == "Elastic" then return Enum.EasingStyle.Elastic end
            return Enum.EasingStyle.Quad
        end

        local function getEasingDirection(direction)
            if direction == "In" then return Enum.EasingDirection.In end
            if direction == "Out" then return Enum.EasingDirection.Out end
            if direction == "InOut" then return Enum.EasingDirection.InOut end
            return Enum.EasingDirection.Out
        end

        local function tween(instance, properties, config)
            config = config or {}

            local duration = (config.Duration) or 0.3
            local easingStyle = (config.EasingStyle) or "Quad"
            local easingDirection = (config.EasingDirection) or "Out"
            local repeatCount = (config.RepeatCount) or 0
            local reverses = (config.Reverses) or false
            local delayTime = (config.DelayTime) or 0

            local tweenInfo = TweenInfo.new(
                duration,
                getEasingStyle(easingStyle),
                getEasingDirection(easingDirection),
                repeatCount,
                reverses,
                delayTime
            )

            local tweenObject = TweenService:Create(instance, tweenInfo, properties)

            return {
                Play = function()
                    tweenObject:Play()
                    return tweenObject
                end,
                Stop = function()
                    tweenObject:Cancel()
                end,
                Pause = function()
                    tweenObject:Pause()
                end,
                Cancel = function()
                    tweenObject:Cancel()
                end,
                _tween = tweenObject,
            }
        end

        local function fadeIn(instance, duration)
            return tween(instance, { BackgroundTransparency = 0 }, { Duration = duration or 0.3 })
        end

        local function fadeOut(instance, duration)
            return tween(instance, { BackgroundTransparency = 1 }, { Duration = duration or 0.3 })
        end

        local function slideIn(instance, fromPosition, toPosition, duration)
            instance.Position = fromPosition
            return tween(instance, { Position = toPosition }, {
                Duration = duration or 0.4,
                EasingStyle = "Back",
                EasingDirection = "Out"
            })
        end

        local function scaleIn(instance, duration)
            instance.Size = UDim2.fromScale(0, 0)
            return tween(instance, { Size = UDim2.fromScale(1, 1) }, {
                Duration = duration or 0.3,
                EasingStyle = "Back",
                EasingDirection = "Out"
            })
        end

        local function spring(instance, properties, config)
            local springConfig = {
                Duration = if config and config.Duration then config.Duration else 0.6,
                EasingStyle = "Elastic",
                EasingDirection = "Out",
                RepeatCount = if config and config.RepeatCount then config.RepeatCount else 0,
                Reverses = if config and config.Reverses then config.Reverses else false,
                DelayTime = if config and config.DelayTime then config.DelayTime else 0,
            }

            return tween(instance, properties, springConfig)
        end

        local function chain(tweens)
            local currentIndex = 1

            local function playNext()
                if currentIndex <= #tweens then
                    local currentTween = tweens[currentIndex]
                    currentIndex = currentIndex + 1
                    currentTween._tween.Completed:Connect(playNext)
                    currentTween.Play()
                end
            end

            return {
                Play = playNext,
                Stop = function()
                    for _, tweenObj in ipairs(tweens) do
                        tweenObj.Stop()
                    end
                end
            }
        end

        local function chainPreview(tweens, config)
            local interval = config.Interval
            local isRunning = false
            local connections = {}

            local originalProperties = {}

            for i, tweenObj in ipairs(tweens) do
                local tweenInstance = tweenObj._tween.Instance
                local properties = {}

                for propertyName, _ in pairs(tweenObj._tween) do
                    if typeof(tweenInstance[propertyName]) ~= "nil" then
                        properties[propertyName] = tweenInstance[propertyName]
                    end
                end

                originalProperties[i] = {
                    instance = tweenInstance,
                    properties = properties
                }
            end

            local function restoreOriginalProperties()
                for _, data in ipairs(originalProperties) do
                    for propertyName, value in pairs(data.properties) do
                        data.instance[propertyName] = value
                    end
                end
            end

            local function playChain()
                local currentIndex = 1

                local function playNext()
                    if currentIndex <= #tweens and isRunning then
                        local currentTween = tweens[currentIndex]
                        currentIndex = currentIndex + 1
                        local connection = currentTween._tween.Completed:Connect(playNext)
                        table.insert(connections, connection)
                        currentTween.Play()
                    elseif isRunning then
                        task.wait(interval)
                        if isRunning then
                            restoreOriginalProperties()
                            task.wait(interval)
                            if isRunning then
                                playChain()
                            end
                        end
                    end
                end

                playNext()
            end

            return {
                Play = function()
                    isRunning = true
                    playChain()
                end,
                Stop = function()
                    isRunning = false
                    for _, tweenObj in ipairs(tweens) do
                        tweenObj.Stop()
                    end
                    for _, connection in ipairs(connections) do
                        connection:Disconnect()
                    end
                    connections = {}
                    restoreOriginalProperties()
                end
            }
        end

        return {
            tween = tween,
            fadeIn = fadeIn,
            fadeOut = fadeOut,
            slideIn = slideIn,
            scaleIn = scaleIn,
            spring = spring,
            chain = chain,
            chainPreview = chainPreview,
        }
    end)()

    local Creator = (function()
        local module = {
            Signals = {},
            HeartbeatSignals = {},
            DefaultProperties = {
                UICorner = {
                    CornerRadius = UDim.new(0, 6),
                },
                ScreenGui = {
                    ResetOnSpawn = false,
                    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
                },
                Frame = {
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderColor3 = Color3.new(0, 0, 0),
                    BorderSizePixel = 0,
                },
                ScrollingFrame = {
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderColor3 = Color3.new(0, 0, 0),
                    ScrollBarImageColor3 = Color3.new(0, 0, 0),
                },
                TextLabel = {
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderColor3 = Color3.new(0, 0, 0),
                    Font = Enum.Font.SourceSans,
                    Text = "",
                    TextColor3 = Color3.new(0, 0, 0),
                    BackgroundTransparency = 1,
                    TextSize = 14,
                },
                TextButton = {
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderColor3 = Color3.new(0, 0, 0),
                    AutoButtonColor = false,
                    Font = Enum.Font.SourceSans,
                    Text = "",
                    TextColor3 = Color3.new(0, 0, 0),
                    TextSize = 14,
                },
                TextBox = {
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderColor3 = Color3.new(0, 0, 0),
                    ClearTextOnFocus = false,
                    Font = Enum.Font.SourceSans,
                    Text = "",
                    TextColor3 = Color3.new(0, 0, 0),
                    TextSize = 14,
                },
                ImageLabel = {
                    BackgroundTransparency = 1,
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderColor3 = Color3.new(0, 0, 0),
                    BorderSizePixel = 0,
                },
                ImageButton = {
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderColor3 = Color3.new(0, 0, 0),
                    AutoButtonColor = false,
                },
                CanvasGroup = {
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderColor3 = Color3.new(0, 0, 0),
                    BorderSizePixel = 0,
                },
            },
        }

        function module.AddSignal(Signal, fn)
            if type(Signal) == "table" then
                for _, signal in Signal do
                    table.insert(module.Signals, signal:Connect(fn))
                end
            else
                table.insert(module.Signals, Signal:Connect(fn))
            end
        end

        function module.Disconnect()
            for Idx = #module.Signals, 1, -1 do
                local Connection = table.remove(module.Signals, Idx)
                Connection:Disconnect()
            end
        end

        local CustomEvents = { "OnClick", "OnHover", "OnLeave", "OnHeartbeat", "OnTextChange", "CreateLinearMotor" }
        local CustomProps = { "ThemeTag", "ImageThemeTag" }

        function module.New(Name, Properties, Children)
            Properties = Properties or {}
            Children = Children or {}

            local Object = Instance.new(Name)

            for PropName, Value in next, module.DefaultProperties[Name] or {} do
                Object[PropName] = Value
            end

            for PropName, Value in next, Properties do
                if table.find(CustomEvents, PropName) then
                    if typeof(Value) ~= "function" then
                        warn(PropName .. " must be a function")
                        continue
                    end

                    local function Callback()
                        return task.spawn(Value, Object)
                    end

                    local eventMap = {
                        OnClick = function()
                            module.AddSignal(Object.InputBegan, function(input, gameProcessedEvent)
                                if not gameProcessedEvent and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                                    Callback()
                                end
                            end)
                        end,
                        OnHover = function()
                            module.AddSignal(Object.MouseEnter, Callback)
                        end,
                        OnLeave = function()
                            module.AddSignal(Object.MouseLeave, Callback)
                        end,
                        OnHeartbeat = function()
                            table.insert(module.HeartbeatSignals, Callback)
                        end,
                        OnTextChange = function()
                            module.AddSignal(Object:GetPropertyChangedSignal("Text"), Callback)
                        end,
                    }
                    local handler = eventMap[PropName]
                    if handler then
                        handler()
                    end

                    continue
                end

                if not table.find(CustomProps, PropName) then
                    Object[PropName] = Value
                end
            end

            for _, Child in next, Children do
                if typeof(Child) == "function" then
                    Child(Object)
                elseif typeof(Child) == "Instance" then
                    Child.Parent = Object
                end
            end

            return Object
        end

        module.AddSignal(RunService.Heartbeat, function()
            for _, func in ipairs(module.HeartbeatSignals) do
                task.spawn(func)
            end
        end)

        return module
    end)()

    local New = Creator.New

    local AnimationPresets = (function()
        local function dramaticSlideIn(element, delay)
            delay = delay or 0
            local originalPosition = element.Position
            element.Position = UDim2.new(
                originalPosition.X.Scale + 0.1,
                originalPosition.X.Offset,
                originalPosition.Y.Scale + 0.15,
                originalPosition.Y.Offset
            )
            element.Rotation = -5
            Tween.tween(element, {
                Position = originalPosition,
                Rotation = 0
            }, {
                Duration = 0.8,
                EasingStyle = "Back",
                EasingDirection = "Out",
                DelayTime = delay
            }).Play()
        end

        local function staggeredFadeIn(elements, staggerDelay)
            staggerDelay = staggerDelay or 0.1
            for i, element in ipairs(elements) do
                local d = (i - 1) * staggerDelay
                Tween.tween(element, {
                    BackgroundTransparency = 0
                }, {
                    Duration = 0.4,
                    DelayTime = d
                }).Play()
            end
        end

        local function typewriterText(textLabel, fullText, speed)
            speed = speed or 0.05
            textLabel.Text = ""
            for i = 1, #fullText do
                task.wait(speed)
                textLabel.Text = string.sub(fullText, 1, i)
            end
        end

        local function glowPulse(element)
            local originalSize = element.Size
            Tween.chain({
                Tween.tween(element, {
                    Size = UDim2.new(originalSize.X.Scale * 1.05, 0, originalSize.Y.Scale * 1.05, 0)
                }, {
                    Duration = 0.3,
                    EasingStyle = "Sine",
                    EasingDirection = "Out"
                }),
                Tween.tween(element, {
                    Size = originalSize
                }, {
                    Duration = 0.3,
                    EasingStyle = "Sine",
                    EasingDirection = "In"
                })
            }).Play()
        end

        local function startFloating(element)
            Tween.tween(element, {
                Rotation = 2
            }, {
                Duration = 3,
                EasingStyle = "Sine",
                EasingDirection = "InOut",
                RepeatCount = -1,
                Reverses = true
            }).Play()
        end

        return {
            dramaticSlideIn = dramaticSlideIn,
            staggeredFadeIn = staggeredFadeIn,
            typewriterText = typewriterText,
            glowPulse = glowPulse,
            startFloating = startFloating,
        }
    end)()

    local GameUtils = (function()
        local function GetCurrentGame(Games)
            local placeId = tostring(game.PlaceId)
            for _, gameInfo in pairs(Games) do
                for _, id in pairs(gameInfo.PlaceIds) do
                    if tostring(id) == placeId or tostring(id) == "TEST" then
                        return gameInfo
                    end
                end
            end
            return nil
        end

        return {
            GetCurrentGame = GetCurrentGame,
        }
    end)()

    local StatCard = (function()
        local function FormatNumber(n)
            if n < 1000 then
                return tostring(n)
            elseif n < 1e6 then
                local k = n / 1e3
                if n % 1e3 == 0 then
                    return string.format("%dK", k)
                else
                    return string.format("%dK+", math.floor(k))
                end
            elseif n < 1e9 then
                local m = n / 1e6
                if n % 1e6 == 0 then
                    return string.format("%dM", m)
                else
                    return string.format("%dM+", math.floor(m))
                end
            elseif n < 1e12 then
                local b = n / 1e9
                if n % 1e9 == 0 then
                    return string.format("%dB", b)
                else
                    return string.format("%dB+", math.floor(b))
                end
            else
                local t = n / 1e12
                if n % 1e12 == 0 then
                    return string.format("%dT", t)
                else
                    return string.format("%dT+", math.floor(t))
                end
            end
        end

        local LockedColor = Color3.fromRGB(93, 187, 255)

        local LayoutOrder = 0

        return function(Config)
            LayoutOrder += 1

            local MainColor = LockedColor
            local Transparency = Config.Transparency or 0.5

            local ValueLabel = New("TextLabel", {
                FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
                RichText = true,
                Text = Config.Value,
                TextColor3 = MainColor,
                TextScaled = true,
                TextSize = 32,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                AnchorPoint = Vector2.new(0.5, 0.5),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Position = UDim2.fromScale(0.553, 0.458),
                Size = UDim2.new(1, 0, 0, 22),
                OnHeartbeat = Config.Callback and function(Object)
                    local Success, Result = pcall(Config.Callback)
                    if Success and Result then
                        if Config.FormatCurrency then
                            local numberValue = tonumber(Result) or 0
                            Object.Text = FormatNumber(numberValue)
                        else
                            Object.Text = tostring(Result)
                        end
                    end
                end,
            }, {
                New("UITextSizeConstraint", { MaxTextSize = 32 }),
            })

            local Title = New("TextLabel", {
                FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
                RichText = true,
                Text = Config.Title,
                TextColor3 = MainColor,
                TextScaled = true,
                TextSize = 22,
                TextTransparency = 0.4,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                Position = UDim2.fromScale(0.553, 0.458),
                Size = UDim2.fromScale(0, 0.852),
            }, {
                New("UITextSizeConstraint", { MaxTextSize = 22 }),
            })

            local Icon = New("ImageLabel", {
                Image = Config.Icon,
                ImageColor3 = Color3.fromRGB(255, 255, 255),
                ImageTransparency = 0,
                BackgroundTransparency = 1,
                LayoutOrder = 1,
                Size = UDim2.fromScale(0.111, 0.978),
                ScaleType = Enum.ScaleType.Fit,
            }, {
                New("UIAspectRatioConstraint"),
            })

            local CardFrame = New("Frame", {
                BackgroundColor3 = MainColor,
                BackgroundTransparency = Transparency,
                BorderSizePixel = 0,
                Size = UDim2.new(1, -10, 1, -10),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 10),
            }, {
                ValueLabel,

                New("UIListLayout", {
                    VerticalFlex = Enum.UIFlexAlignment.SpaceBetween,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }),

                New("UIPadding", {
                    PaddingBottom = UDim.new(0, 8),
                    PaddingLeft = UDim.new(0, 12),
                    PaddingRight = UDim.new(0, 12),
                    PaddingTop = UDim.new(0, 8),
                }),

                New("Frame", {
                    BackgroundTransparency = 1,
                    LayoutOrder = -1,
                    Size = UDim2.fromScale(1, 0.389),
                }, {
                    New("UIListLayout", {
                        HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
                        ItemLineAlignment = Enum.ItemLineAlignment.Center,
                        FillDirection = Enum.FillDirection.Horizontal,
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        VerticalAlignment = Enum.VerticalAlignment.Center,
                    }),

                    Title,
                    Icon,
                }),

                New("UICorner", {
                    CornerRadius = UDim.new(0, 12),
                }),

                New("UIStroke", {
                    Color = MainColor,
                    Transparency = 0.6,
                }),
            })

            local Frame = New("CanvasGroup", {
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2.new(0.5, -3, 0, 84),
                Parent = Config.Parent,
                LayoutOrder = LayoutOrder,
                GroupTransparency = 1,
            }, {
                CardFrame,
            })

            local animationDelay = (LayoutOrder - 1) * 0.25

            task.spawn(function()
                task.wait(animationDelay)

                Tween.tween(Frame, {
                    GroupTransparency = 0,
                }, {
                    Duration = 0.3,
                    EasingStyle = "Quad",
                    EasingDirection = "Out",
                }).Play()

                Tween.tween(CardFrame, {
                    Size = UDim2.new(1, -2, 1, -2),
                    Position = UDim2.fromScale(0.5, 0.5),
                }, {
                    Duration = 0.2,
                    EasingStyle = "Back",
                    EasingDirection = "Out",
                }).Play()
            end)

            return {
                Object = Frame,
                SetValue = function(newValue)
                    if Config.FormatCurrency then
                        local numberValue = tonumber(newValue) or 0
                        newValue = FormatNumber(numberValue)
                    end
                    ValueLabel.Text = newValue
                end,
                Pop = function()
                    local originalSize = CardFrame.Size
                    Tween.chain({
                        Tween.tween(CardFrame, {
                            Size = UDim2.new(
                                originalSize.X.Scale * 1.1,
                                originalSize.X.Offset,
                                originalSize.Y.Scale * 1.1,
                                originalSize.Y.Offset
                            ),
                        }, {
                            Duration = 0.08,
                            EasingStyle = "Back",
                            EasingDirection = "Out",
                        }),
                        Tween.tween(CardFrame, {
                            Size = originalSize,
                        }, {
                            Duration = 0.2,
                            EasingStyle = "Elastic",
                            EasingDirection = "Out",
                        }),
                    }).Play()
                end,
            }
        end
    end)()

    local MainTaskLabelModule = function()
        local MainTaskLabel = New("TextLabel", {
            FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
            Text = "Idling...",
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 1,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BorderSizePixel = 0,
            LayoutOrder = 1,
            Size = UDim2.fromScale(0, 1),
        })

        return {
            Object = MainTaskLabel,
            SetText = function(newValue)
                MainTaskLabel.Text = "Main Task: " .. newValue
            end,
        }
    end

    local ProgressBarModule = function()
        local ProgressBar = New("Frame", {
            BackgroundColor3 = Color3.fromRGB(93, 187, 255),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BorderSizePixel = 0,
            Size = UDim2.new(0, 0, 1, 0),
        }, {
            New("UICorner", {
                CornerRadius = UDim.new(1, 0),
            }),
        })

        return {
            Object = ProgressBar,
            SetProgress = function(progress)
                progress = math.clamp(progress, 0, 1)
                local targetSize = UDim2.new(progress, 0, 1, 0)
                Tween.tween(ProgressBar, { Size = targetSize }, {
                    Duration = 0.3,
                    EasingStyle = "Quad",
                    EasingDirection = "Out"
                }).Play()
            end,
        }
    end

    local StatCardsContainerModule = function()
        local StatCardsContainer = New("Frame", {
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 1,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
        }, {
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 24),
                PaddingRight = UDim.new(0, 24),
                PaddingTop = UDim.new(0, 18),
            }),

            New("UIGridLayout", {
                CellPadding = UDim2.fromOffset(6, 6),
                CellSize = UDim2.new(0.5, -3, 0, 84),
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        })

        local function AddStatCard(config)
            config.Parent = StatCardsContainer
            local card = StatCard(config)
            return card
        end

        return {
            Object = StatCardsContainer,
            AddStatCard = AddStatCard,
        }
    end

    local HeroCardModule = function()
        local TextContainer = New("Frame", {
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 1,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BorderSizePixel = 0,
            Size = UDim2.fromScale(0.6, 1),
            Position = UDim2.new(0, 0, 0, -10),
        }, {
            New("UIPadding", {
                PaddingBottom = UDim.new(0, 16),
                PaddingLeft = UDim.new(0, 20),
                PaddingRight = UDim.new(0, 16),
                PaddingTop = UDim.new(0, 16),
            }),

            New("UIListLayout", {
                Padding = UDim.new(0, 18),
                VerticalFlex = Enum.UIFlexAlignment.SpaceBetween,
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),

            New("Frame", {
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                BorderSizePixel = 0,
                LayoutOrder = -1,
                Size = UDim2.new(1, 0, 0, 30),
            }, {
                New("ImageLabel", {
                    Image = "rbxassetid://127683896328934",
                    ScaleType = Enum.ScaleType.Fit,
                    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                    BackgroundTransparency = 1,
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    Size = UDim2.fromOffset(36, 36),
                }),

                New("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                }),

                New("TextLabel", {
                    FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
                    RichText = true,
                    Text = 'HOU<b><font color="#8b5e3c">JI</font></b>',
                    TextColor3 = Color3.fromRGB(0, 0, 0),
                    TextSize = 20,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    AutomaticSize = Enum.AutomaticSize.X,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BackgroundTransparency = 1,
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    Size = UDim2.fromOffset(0, 20),
                }),
            }),

            New("Frame", {
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                BorderSizePixel = 0,
                Size = UDim2.fromScale(1, 0),
            }, {
                New("TextLabel", {
                    FontFace = Font.new(
                        "rbxasset://fonts/families/GothamSSm.json",
                        Enum.FontWeight.Medium,
                        Enum.FontStyle.Normal
                    ),
                    RichText = true,
                    Text = 'YOUR STATE-OF-THE-ART <stroke color="#000000" thickness="1"><b><font color="#8b5e3c">AGENCY.</font></b></stroke>',
                    TextColor3 = Color3.fromRGB(0, 0, 0),
                    TextSize = 32,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BackgroundTransparency = 1,
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    Size = UDim2.fromOffset(340, 0),
                }),

                New("TextLabel", {
                    FontFace = Font.new(
                        "rbxasset://fonts/families/GothamSSm.json",
                        Enum.FontWeight.Medium,
                        Enum.FontStyle.Normal
                    ),
                    Text = "Imagine walking away while your computer keeps creating, building, and winning for you.",
                    TextColor3 = Color3.fromRGB(0, 0, 0),
                    TextSize = 16,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BackgroundTransparency = 1,
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    Size = UDim2.fromOffset(340, 0),
                }),

                New("UIListLayout", {
                    Padding = UDim.new(0, 6),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }),

                New("UIPadding", {
                    PaddingLeft = UDim.new(0, 2),
                }),
            }),
        })

        local DefaultCard = New("Frame", {
            BackgroundColor3 = Color3.fromRGB(25, 23, 36),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 0,
            ClipsDescendants = true,
        }, {
            New("UICorner", {
                CornerRadius = UDim.new(0, 26),
            }),

            New("ImageLabel", {
                Image = "rbxassetid://9968344227",
                ImageTransparency = 0.85,
                ScaleType = Enum.ScaleType.Tile,
                TileSize = UDim2.fromOffset(128, 128),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                BorderSizePixel = 0,
                Size = UDim2.fromScale(1, 1),
            }, {
                New("UICorner", {
                    CornerRadius = UDim.new(0, 26),
                }),
            }),

            New("ImageLabel", {
                Image = "rbxassetid://139848892052312",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                BorderSizePixel = 0,
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(1, 1),
                ZIndex = 0,
            }, {
                New("UICorner", {
                    CornerRadius = UDim.new(0, 26),
                }),
            }),
        })

        local MinimizedCard = New("CanvasGroup", {
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 1,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BorderSizePixel = 0,
            ClipsDescendants = true,
            LayoutOrder = -1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(1.1, 1.1),
            GroupTransparency = 1,
            ZIndex = 0,
        }, {
            New("ImageLabel", {
                Image = "rbxassetid://127683896328934",
                ScaleType = Enum.ScaleType.Stretch,
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(128, 128),
            }, {
                New("UICorner", {}),
            }),

            New("UIListLayout", {
                Padding = UDim.new(0, 12),
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
                VerticalAlignment = Enum.VerticalAlignment.Center,
            }),

            New("TextLabel", {
                FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
                RichText = true,
                Text = "Bee<b><font color=\"#87CEFA\">Keeper</font></b>",
                TextColor3 = Color3.fromRGB(255, 255, 255),
                TextSize = 56,
                TextWrapped = false,
                TextXAlignment = Enum.TextXAlignment.Left,
                AutomaticSize = Enum.AutomaticSize.XY,
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                BorderSizePixel = 0,
                Position = UDim2.fromScale(0.462, 0.217),
            }),
        })

        local ContentContainer = New("CanvasGroup", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 1,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BorderSizePixel = 0,
            Position = UDim2.new(0.5, 0, 0.5, -50),
            Size = UDim2.fromScale(1, 1),
            GroupTransparency = 1,
        }, {
            DefaultCard,
            TextContainer,
        })

        local BackgroundGlow = New("ImageLabel", {
            Image = "rbxassetid://8992230677",
            ImageTransparency = 1,
            ScaleType = Enum.ScaleType.Slice,
            SliceCenter = Rect.new(99, 99, 99, 99),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 1,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BorderSizePixel = 0,
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, 120, 1, 116),
            ZIndex = -1,
        }, {
            New("UIGradient", {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(196, 154, 108)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 166, 153)),
                }),
            }),
        })

        local HeroCard = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 1,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BorderSizePixel = 0,
            Position = UDim2.fromScale(0.5, 0.3),
            Size = UDim2.new(1, 0, 0.364, 0),
            ZIndex = 2,
        }, {
            ContentContainer,
            MinimizedCard,
            BackgroundGlow,
        })

        local function playCardTransition()
            Tween.spring(BackgroundGlow, {
                ImageTransparency = 1,
            }, {
                Duration = 0.6,
                EasingStyle = "Linear",
            }).Play()

            Tween.tween(ContentContainer, {
                Size = UDim2.fromScale(0, 0),
                GroupTransparency = 1,
            }, {
                Duration = 0.6,
                EasingStyle = "Back",
                EasingDirection = "InOut",
            }).Play()

            Tween.tween(MinimizedCard, {
                Size = UDim2.fromScale(1, 1),
                GroupTransparency = 0,
            }, {
                Duration = 0.6,
                EasingStyle = "Back",
                EasingDirection = "InOut",
            }).Play()

            Tween.tween(HeroCard, {
                Size = UDim2.fromScale(1, 0.2),
            }, {
                Duration = 0.4,
                EasingStyle = "Back",
                EasingDirection = "InOut",
            }).Play()
        end

        local function playEntranceAnimation()
            Tween.tween(ContentContainer, {
                Position = UDim2.fromScale(0.5, 0.5),
                GroupTransparency = 0,
            }, {
                Duration = 0.4,
                EasingStyle = "Back",
                EasingDirection = "Out",
                DelayTime = 0.2,
            }).Play()

            Tween.tween(TextContainer, {
                Position = UDim2.fromScale(0, 0),
            }, {
                Duration = 0.2,
                EasingStyle = "Back",
                EasingDirection = "InOut",
                DelayTime = 0.2,
            }).Play()

            Tween.tween(HeroCard, {
                Rotation = 0,
            }, {
                Duration = 1,
                EasingStyle = "Elastic",
                EasingDirection = "Out",
                DelayTime = 0.1,
            }).Play()

            local glowTween = Tween.spring(BackgroundGlow, {
                ImageTransparency = 0.4,
            }, {
                Duration = 3,
                EasingStyle = "Linear",
                DelayTime = 0.4,
            })
            glowTween.Play()

            glowTween._tween.Completed:Connect(function()
                task.wait(8)
                playCardTransition()
            end)
        end

        HeroCard.Rotation = -2
        task.wait(0.1)
        playCardTransition()

        return {
            Object = HeroCard,
            PlayEntranceAnimation = playEntranceAnimation,
            Wobble = function()
                Tween.spring(HeroCard, {
                    Rotation = math.random(-1, 1),
                }, {
                    Duration = 0.4,
                }).Play()
            end,
            Pulse = function()
                local originalSize = HeroCard.Size
                Tween.chain({
                    Tween.tween(
                        HeroCard,
                        { Size = UDim2.new(originalSize.X.Scale * 1.02, 0, originalSize.Y.Scale * 1.02, 0) },
                        { Duration = 0.15 }
                    ),
                    Tween.tween(HeroCard, { Size = originalSize }, { Duration = 0.15 }),
                }).Play()
            end,
        }
    end

    local Content = function(Parent, Games)
        local MainTaskLabel = MainTaskLabelModule()
        local ProgressBar = ProgressBarModule()
        local StatCardsContainer = StatCardsContainerModule()
        local HeroCard = HeroCardModule()

        New("Frame", {
            BackgroundColor3 = Color3.fromRGB(11, 11, 15),
            BackgroundTransparency = 0.1,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            Parent = Parent,
        }, {
            New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = Color3.fromRGB(74, 144, 226),
                BackgroundTransparency = 0.8,
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                BorderSizePixel = 0,
                LayoutOrder = -1,
                Position = UDim2.new(0.5, 0, 0, 10),
                Size = UDim2.fromOffset(0, 40),
                ZIndex = 36,
            }, {
                New("UIListLayout", {
                    Padding = UDim.new(0, 8),
                    FillDirection = Enum.FillDirection.Horizontal,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                }),

                New("Frame", {
                    BackgroundColor3 = Color3.fromRGB(74, 144, 226),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    Size = UDim2.fromOffset(12, 12),
                }, {
                    New("UICorner", {
                        CornerRadius = UDim.new(1, 0),
                    }),
                }),

                MainTaskLabel.Object,

                New("UIPadding", {
                    PaddingLeft = UDim.new(0, 12),
                    PaddingRight = UDim.new(0, 12),
                }),

                New("UIStroke", {
                    Color = Color3.fromRGB(93, 187, 255),
                    Transparency = 0.6,
                }),

                New("UICorner", {
                    CornerRadius = UDim.new(0, 12),
                }),
            }),

            New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.fromRGB(11, 13, 15),
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                BorderSizePixel = 0,
                Position = UDim2.new(0.5, 0, 1, -20),
                Size = UDim2.new(0.4, 0, 0, 14),
            }, {
                New("UICorner", {
                    CornerRadius = UDim.new(1, 0),
                }),

                ProgressBar.Object,

                New("UIStroke", {
                    Color = Color3.fromRGB(93, 187, 255),
                    Transparency = 0.6,
                }),
            }),

            New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                BorderSizePixel = 0,
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(0.6, 1),
            }, {
                New("Frame", {
                    AnchorPoint = Vector2.new(0.5, 1),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BackgroundTransparency = 1,
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    LayoutOrder = 1,
                    Position = UDim2.fromScale(0.5, 1),
                    Size = UDim2.new(1, 0, 0, 240),
                }, {
                    New("ImageLabel", {
                        Image = "rbxassetid://8992230677",
                        ImageColor3 = Color3.fromRGB(0, 0, 0),
                        ImageTransparency = 0.3,
                        ScaleType = Enum.ScaleType.Slice,
                        SliceCenter = Rect.new(99, 99, 99, 99),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        BorderSizePixel = 0,
                        Position = UDim2.fromScale(0.5, 0.5),
                        Size = UDim2.new(1, 120, 1, 116),
                        ZIndex = -1,
                    }),

                    New("CanvasGroup", {
                        AnchorPoint = Vector2.new(0.5, 1),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        BorderSizePixel = 0,
                        Position = UDim2.fromScale(0.5, 1),
                        Size = UDim2.fromScale(1, 0.9),
                    }, {
                        New("Frame", {
                            BackgroundColor3 = Color3.fromRGB(11, 13, 15),
                            BorderColor3 = Color3.fromRGB(0, 0, 0),
                            BorderSizePixel = 0,
                            Size = UDim2.fromScale(1, 1),
                            ZIndex = 0,
                        }, {
                            New("UICorner", {
                                CornerRadius = UDim.new(0, 24),
                            }),

                            New("ImageLabel", {
                                Image = "rbxassetid://9968344227",
                                ImageTransparency = 0.85,
                                ScaleType = Enum.ScaleType.Tile,
                                TileSize = UDim2.fromOffset(128, 128),
                                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                                BackgroundTransparency = 1,
                                BorderColor3 = Color3.fromRGB(0, 0, 0),
                                BorderSizePixel = 0,
                                Size = UDim2.fromScale(1, 1),
                            }, {
                                New("UICorner", {
                                    CornerRadius = UDim.new(0, 26),
                                }),
                            }),
                        }),

                        StatCardsContainer.Object,
                    }),
                }),

                HeroCard.Object,
                New("UIListLayout", {
                    Padding = UDim.new(0, -24),
                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    ItemLineAlignment = Enum.ItemLineAlignment.Center,
                }),
            }),
        })

        local Game = GameUtils.GetCurrentGame(Games)
        if Game then
            if Game.Order then
                for _, Title in ipairs(Game.Order) do
                    local Config = Game.Registries[Title]
                    if Config then
                        local TypedConfig = Config
                        TypedConfig.Title = Title
                        StatCardsContainer.AddStatCard(TypedConfig)
                    end
                end
            else
                for Title, Config in pairs(Game.Registries) do
                    local TypedConfig = Config
                    TypedConfig.Title = Title
                    StatCardsContainer.AddStatCard(TypedConfig)
                end
            end
        end

        return {
            AddStatCard = StatCardsContainer.AddStatCard,
            SetMainTask = MainTaskLabel.SetText,
            SetProgress = ProgressBar.SetProgress,
            PlayHeroAnimation = HeroCard.PlayEntranceAnimation,
            HeroWobble = HeroCard.Wobble,
            HeroPulse = HeroCard.Pulse,
        }
    end

    local ScreenGUI = New("ScreenGui", {
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 3e6,
        Parent = RunService:IsStudio() and CoreGui or (LocalPlayer and LocalPlayer:WaitForChild("PlayerGui")),
    })
local StartTime = tick()

    local UI = Content(ScreenGUI, {
        Game = {
            Name = "Bee Swarm",
            PlaceIds = { "TEST" },
            Order = { "Honey", "BeeInSlot", "BagPollen", "Runtime" },
            Registries = {
                Honey = {
                    Value = "0",
                    Icon = "rbxassetid://1472135114",
                    Callback = function()
                        local lp = game.Players.LocalPlayer
                        local honey = 0
                        pcall(function()
                            local cs = lp:FindFirstChild("CoreStats")
                            if cs and cs:FindFirstChild("Honey") then
                                honey = cs.Honey.Value
                            end
                        end)
                        local formatted = tostring(math.floor(honey))
                        while true do  
                            local k
                            formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
                            if (k == 0) then break end
                        end
                        return formatted
                    end,
                },
                BeeInSlot = {
                    Value = "0/50",
                    Icon = "rbxassetid://130110708533971",
                    Callback = function()
                        local count = 0
                        pcall(function()
                            local beeCount = getgenv().KaiTunBeeCount
                            if beeCount then count = beeCount end
                        end)
                        return count .. "/50"
                    end,
                },
                BagPollen = {
                    Value = "0%",
                    Icon = "rbxassetid://134471194003980",
                    Callback = function()
                        local core = game.Players.LocalPlayer:FindFirstChild("CoreStats")
                        if core and core:FindFirstChild("Pollen") and core:FindFirstChild("Capacity") then
                            local p = core.Pollen.Value
                            local c = core.Capacity.Value
                            if c > 0 then
                                return math.floor((p / c) * 100) .. "%"
                            end
                        end
                        return "0%"
                    end,
                },
                Runtime = {
                    Value = "00:00:00",
                    Icon = "rbxassetid://117958096329682",
                    Callback = function()
                        local t = tick() - StartTime
                        local h = math.floor(t / 3600)
                        local m = math.floor((t % 3600) / 60)
                        local s = math.floor(t % 60)
                        return string.format("%02d:%02d:%02d", h, m, s)
                    end,
                },
            },
        },
    })

    getgenv().KaiTunUI = UI
    UI.SetMainTask("Starting...")
    UI.SetProgress(0)
]])()
end








-------------------------------
local RS = game:GetService("ReplicatedStorage")
local SC = require(RS:WaitForChild("ClientStatCache"))
local Plr = game:GetService("Players")
local Lplr = Plr.LocalPlayer
local env = RS:WaitForChild("Events")
local Run = game:GetService("RunService")
local TS = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local plr = Lplr
local Collector = require(RS.Collectors)
local EggModule = require(RS.ItemPackages.Eggs)
repeat task.wait() until plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
repeat task.wait() until plr.PlayerGui:FindFirstChild("ScreenGui")


TokenManager = {}
AutoDig = {}
Tween = {}

local TokenFolder = {}
local TokenFolderID = {}
local ListField = {}

for _, v in pairs(game.Workspace.FlowerZones:GetChildren()) do
    table.insert(ListField, v.Name)
end
ItemManager = {}
HiveManager = {}
NPC = {}
ClickManager = {}
Gear = {}
Stats = {}
MobManager = {}
Quest = {}
Quest._reservedHoney = 0
SellManager = {}

local GetStats = function()
    local i, v = pcall(function()
        return SC:Get()
    end)
    return i and v or nil
end

function ItemManager.purchase(category, Type, amount)
    amount = amount or 1
    local i, result = pcall(function()
        return env:WaitForChild("ItemPackageEvent"):InvokeServer("Purchase", {
            ["Type"] = Type,
            ["Category"] = category,
            ["Amount"] = amount,
        })
    end)
    if not i then warn("[Blessed Softworks] Bugging!!!") end
    pcall(function()
        local freshStats = env:WaitForChild("RetrievePlayerStats"):InvokeServer()
        if freshStats then
            Stats._cachedStats = freshStats
            Stats._lastStatRefresh = tick()
        end
    end)
    return i
end

function ItemManager.buyTreat(amount)
    amount = amount or 1
    local batches = { 1000, 100, 10, 1 }
    local remaining = amount
    while remaining > 0 do
        local bought = false
        for _, batch in ipairs(batches) do
            if remaining >= batch then
                ItemManager.purchase("Eggs", "Treat", batch)
                remaining = remaining - batch
                bought = true
                task.wait(0.5)
                break
            end
        end
        if not bought then break end
    end
end

function ItemManager.buyRoyalJelly(amount)
    amount = amount or 1
    local batches = { 10000, 1000, 100, 10, 1 }
    local remaining = amount
    while remaining > 0 do
        local bought = false
        for _, batch in ipairs(batches) do
            if remaining >= batch then
                ItemManager.purchase("Eggs", "RoyalJelly", batch)
                remaining = remaining - batch
                bought = true
                task.wait(0.5)
                break
            end
        end
        if not bought then break end
    end
end

function ItemManager.buySilverEgg(amount)
    amount = amount or 1
    return ItemManager.purchase("Eggs", "Silver", amount)
end

function ItemManager.buyBasicEgg(amount)
    amount = amount or 1
    return ItemManager.purchase("Eggs", "Basic", amount)
end

function ItemManager.checkPrice(itemName)
    local stats = SC:Get()
    if not stats then return nil end
    local ok, cost = pcall(function()
        return EggModule.GetCost({ ["Type"] = itemName, ["Amount"] = 1 }, stats)
    end)
    if ok and cost then return cost end
    return nil
end

function ItemManager.canAfford(itemName)
    local cost = ItemManager.checkPrice(itemName)
    if not cost then return false end
    if cost.Category == "Honey" then
        local honey = 0
        local cs = Lplr:FindFirstChild("CoreStats")
        if cs and cs:FindFirstChild("Honey") then honey = cs.Honey.Value end
        return honey >= cost.Amount, cost.Amount
    end
    return false, cost.Amount
end

function HiveManager.GetBee()
    if not GetStats then
        warn("[KaiTun] GetStats not initialized yet")
        return {}
    end
    local stats = GetStats()
    if not stats then return {} end

    local bees = {}
    local honeycomb = stats.Honeycomb

    if type(honeycomb) == "table" then
        for xKey, yData in pairs(honeycomb) do
            if type(yData) == "table" then
                for yKey, beeData in pairs(yData) do
                    if type(beeData) == "table" and beeData.Type then
                        local xStr = tostring(xKey)
                        local yStr = tostring(yKey)
                        local xNum = tonumber(xStr:match("%d+"))
                        local yNum = tonumber(yStr:match("%d+"))
                        table.insert(bees, {
                            X = xNum or 1,
                            Y = yNum or 1,
                            Type = beeData.Type,
                            Level = beeData.Lvl or beeData.Level or 1,
                            Gifted = beeData.Gifted or false,
                            Rarity = beeData.Rarity or "Common",
                        })
                    end
                end
            end
        end
    end

    table.sort(bees, function(a, b)
        return a.Level > b.Level
    end)

    return bees
end

function HiveManager.placeBasicEgg(col, row, amount)
    amount = amount or 1
    HiveManager.PlaceEgg(col, row, "Basic", amount)
end

function HiveManager.getEmptySlot()
    local stats = SC:Get()
    if not stats or not stats.Honeycomb then return nil, nil end
    for y = 1, 5 do
        for x = 1, 5 do
            local xKey = "x" .. x
            local yKey = "y" .. y
            if not stats.Honeycomb[xKey] or not stats.Honeycomb[xKey][yKey]
                or not stats.Honeycomb[xKey][yKey].Type then
                return x, y
            end
        end
    end
    return nil, nil
end

function HiveManager.buyAndPlaceBasicEgg()
    local canBuy = ItemManager.canAfford("Basic")
    if not canBuy then return false end
    local x, y = HiveManager.getEmptySlot()
    if not x then return false end
    ItemManager.buyBasicEgg(1)
    task.wait(0.5)
    HiveManager.PlaceEgg(x, y, "Basic", 1)
    task.wait(0.5)
    return true
end

function HiveManager.GetPlayerHive()
    local honeycombs = workspace:FindFirstChild("Honeycombs")
    if not honeycombs then return nil end

    for _, hive in pairs(honeycombs:GetChildren()) do
        local owner = hive:FindFirstChild("Owner")
        if owner and (owner.Value == plr or owner.Value == plr.Name) then
            return hive
        end
    end

    return nil
end

function HiveManager.BeesCount()
    local bees = HiveManager.GetBee()
    local total = #bees

    if total == 0 then
        print(" [!] Not Found")
    else
        for i, bee in ipairs(bees) do
            local giftedText = bee.Gifted and "★ GIFTED" or "  Normal"
            print(string.format(
                "#%02d  | %-18s | Lv.%-5d | %-10s | [%d,%d]",
                i,
                bee.Type,
                bee.Level,
                giftedText,
                bee.X,
                bee.Y
            ))
        end
    end

    if total > 0 then
        print(string.format(
            " >> Highest Level: %d | Lowest Level: %d",
            bees[1].Level,
            bees[total].Level
        ))
    end
end

function HiveManager.PlaceEgg(col, row, eggType, amount)
    amount = amount or 1
    local ok, v1, v2, v3, v4, v5 = pcall(function()
        return env:WaitForChild("ConstructHiveCellFromEgg"):InvokeServer(col, row, eggType, amount, false)
    end)
    if ok then
        pcall(function()
            if v1 ~= nil then SC:Set({ "Eggs", eggType }, v1) end
            if v3 then SC:Set({ "Honeycomb" }, v3) end
            if v4 then SC:Set({ "DiscoveredBees" }, v4) end
            if v5 then SC:Set({ "Totals", "EggUses" }, v5) end
        end)
        print("[Egg] Placing " .. eggType .. " egg at [" .. col .. "," .. row .. "]")
    end
end

function HiveManager.Feed(x, y, itemType, amount)
    amount = amount or 1

    local ok, v1, v2, v3, v4, v5 = pcall(function()
        return env:WaitForChild("ConstructHiveCellFromEgg"):InvokeServer(x, y, itemType, amount, false)
    end)

    if not ok then
        warn("[Blessed Softworks] Bugging!!!")
        return false
    end

    if v2 then
        pcall(function()
            SC:Set({ "Eggs", itemType }, v1)
            if v4 then SC:Set({ "DiscoveredBees" }, v4) end
            if v3 then SC:Set({ "Honeycomb" }, v3) end
            if v5 then SC:Set({ "Totals", "EggUses" }, v5) end
        end)
        return true
    else
        warn("[Blessed Softworks] Bugging!!!")
        return false
    end
end

function HiveManager.getMaxBeeLevel()
    local bees = HiveManager.GetBee()
    if #bees == 0 then return 1 end
    return bees[1].Level
end

function HiveManager.feedGingerbreadBears()
    local have = Stats.getItemCount("GingerbreadBear")
    if have <= 0 then return false end

    local bees = HiveManager.GetBee()
    if #bees == 0 then return false end

    table.sort(bees, function(a, b)
        return a.Level < b.Level
    end)

    local fed = 0
    for _, bee in ipairs(bees) do
        if have <= 0 then break end
        print("[Feed] Feeding GingerbreadBear to " .. bee.Type .. " Lv." .. bee.Level .. " at [" .. bee.X .. "," .. bee.Y .. "]")
        HiveManager.Feed(bee.X, bee.Y, "GingerbreadBear", 1)
        have = have - 1
        fed = fed + 1
        task.wait(0.5)
    end

    print("[Feed] Fed GingerbreadBear to " .. fed .. " bees")
    return fed > 0
end

function HiveManager.claimHive()
    if HiveManager.GetPlayerHive() then return end
    repeat
        task.wait(1)
        local honeycombs = workspace:FindFirstChild("Honeycombs")
        if honeycombs then
            local pos, id
            for _, v in pairs(honeycombs:GetChildren()) do
                if v:FindFirstChild("Owner") and v.Owner.Value == nil then
                    if v:FindFirstChild("SpawnPos") then pos = v.SpawnPos.Value end
                    if v:FindFirstChild("HiveID") then id = v.HiveID.Value end
                    break
                end
            end
            if pos and id then
                Tween.tweenTo(CFrame.new(pos.Position))
                task.wait(1)
                pcall(function()
                    RS.Events.ClaimHive:FireServer(id)
                end)
                task.wait(1)
            end
        end
    until HiveManager.GetPlayerHive()
end

function NPC.alert(npcName)
    local npcs = workspace:FindFirstChild("NPCs")
    if not npcs then return false end
    local npc = npcs:FindFirstChild(npcName)
    if not npc then return false end
    local i, v = pcall(function()
        return npc.Platform.AlertPos.AlertGui.ImageLabel.ImageTransparency == 0
    end)
    return i and v
end

function NPC.talkTo(npcName)
    local npcFolder = workspace:FindFirstChild("NPCs")
    local npc = npcFolder and npcFolder:FindFirstChild(npcName)
    if not npc then
        warn("Bugging!!!" .. npcName)
        return false
    end

    local ok = pcall(function()
        local npcModule = require(game.ReplicatedStorage.Activatables.NPCs)
        npcModule.ButtonEffect(plr, npc)
    end)
    if not ok then return false end

    local dialogTimeout = tick()
    repeat
        task.wait(0.1)
    until (function()
            local guiOk, visible = pcall(function()
                return plr.PlayerGui.ScreenGui.NPC.Visible
            end)
            return (guiOk and not visible) or (tick() - dialogTimeout > 15)
        end)()

    task.wait(1)
    return true
end

function NPC.goAndAccept(npcName)
    if Tween then
        Tween.moveToNPC(npcName)
    end
    task.wait(1)
    NPC.talkTo(npcName)
    task.wait(1)
end

function NPC.goAndTurnIn(npcName, questName)
    if Tween then
        Tween.moveToNPC(npcName)
    end
    task.wait(1)
    NPC.talkTo(npcName)
    task.wait(1)

    if NPC.alert(npcName) then
        task.wait(1)
        NPC.talkTo(npcName)
        task.wait(1)
    end
end

local function createTweenFloat()
    if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
        if not plr.Character.HumanoidRootPart:FindFirstChild("KaiTunFloat") then
            local bv = Instance.new("BodyVelocity")
            bv.Parent = plr.Character.HumanoidRootPart
            bv.Name = "KaiTunFloat"
            bv.MaxForce = Vector3.new(0, 100000, 0)
            bv.Velocity = Vector3.new(0, 0, 0)
        end
    end
end

local KaiTunNoClip = false

Run.Stepped:Connect(function()
    if plr.Character then
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = Config.WalkSpeed
        end
    end
    if KaiTunNoClip and plr.Character then
        createTweenFloat()
        for _, v in pairs(plr.Character:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = false
            end
        end
    else
        if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local f = plr.Character.HumanoidRootPart:FindFirstChild("KaiTunFloat")
            if f then f:Destroy() end
        end
    end
    pcall(function()
        local npcGui = plr.PlayerGui:FindFirstChild("ScreenGui")
        if npcGui then
            local npcFrame = npcGui:FindFirstChild("NPC")
            if npcFrame and npcFrame.Visible == true then
                local cam = plr.PlayerGui:FindFirstChild("Camera")
                if cam then
                    local controllers = cam:FindFirstChild("Controllers")
                    if controllers then
                        local npcController = controllers:FindFirstChild("NPC")
                        if npcController then
                            local incr = npcController:FindFirstChild("IncrementDialogue")
                            if incr then
                                incr:Invoke()
                            end
                        end
                    end
                end
            end
        end
    end)
end)

function Tween.tweenTo(targetCFrame)
    if not (plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")) then return end
    KaiTunNoClip = true
    local root = plr.Character.HumanoidRootPart
    local distance = (targetCFrame.Position - root.Position).Magnitude

    if distance <= 50 then
        root.CFrame = targetCFrame
    else
        local speed = Config.TweenSpeed or 100
        local tween = TS:Create(
            root,
            TweenInfo.new(distance / speed, Enum.EasingStyle.Linear),
            { CFrame = targetCFrame }
        )
        tween:Play()
        tween.Completed:Wait()
    end
    KaiTunNoClip = false
end

Tween.FieldHeightOffsets = {
    ["Pine Tree Forest"]   = 70,
    ["Rose Field"]         = 50,
    ["Pumpkin Patch"]      = 50,
    ["Cactus Field"]       = 40,
    ["Pepper Patch"]       = 80,
    ["Coconut Field"]      = 80,
    ["Mountain Top Field"] = 80,
    ["Stump Field"]        = 40,
    ["Spider Field"]       = 30,
}

function Tween.moveToField(fieldName)
    local zones = workspace:FindFirstChild("FlowerZones")
    if not zones then return false end
    local field = zones:FindFirstChild(fieldName)
    if not field then return false end
    local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local heightOffset = Tween.FieldHeightOffsets[fieldName] or 0
    if heightOffset > 0 then
        KaiTunNoClip = true
        local highCFrame = CFrame.new(field.Position.X, field.Position.Y + heightOffset, field.Position.Z)
        local dist1 = (highCFrame.Position - root.Position).Magnitude
        if dist1 <= 50 then
            root.CFrame = highCFrame
        else
            local speed = Config.TweenSpeed or 100
            local t1 = TS:Create(root, TweenInfo.new(dist1 / speed, Enum.EasingStyle.Linear), { CFrame = highCFrame })
            t1:Play()
            t1.Completed:Wait()
        end
        local targetCFrame = field.CFrame + Vector3.new(0, 5, 0)
        local dist2 = (targetCFrame.Position - root.Position).Magnitude
        if dist2 <= 50 then
            root.CFrame = targetCFrame
        else
            local speed = Config.TweenSpeed or 100
            local t2 = TS:Create(root, TweenInfo.new(dist2 / speed, Enum.EasingStyle.Linear), { CFrame = targetCFrame })
            t2:Play()
            t2.Completed:Wait()
        end
        KaiTunNoClip = false
    else
        Tween.tweenTo(field.CFrame + Vector3.new(0, 3, 0))
    end
    return true
end

function Tween.moveToNPC(npcName)
    local npcs = workspace:FindFirstChild("NPCs")
    if not npcs then return false end
    local npc = npcs:FindFirstChild(npcName)
    if not npc then return false end

    if npc:FindFirstChild("Platform") then
        local pos = npc.Platform.Position
        Tween.tweenTo(CFrame.new(pos.X, pos.Y + 5, pos.Z))
        return true
    else
        local hrp = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Head")
        if hrp then
            Tween.tweenTo(hrp.CFrame * CFrame.new(0, 0, -5))
            return true
        end
    end
    return false
end

ClickManager._lastDigTime = 0
AutoDig._lastDigTime = 0

AutoDig._scoopAnim = Instance.new("Animation")
AutoDig._scoopAnim.AnimationId = "http://www.roblox.com/asset/?id=522635514"

function AutoDig.getEquippedTool()
    local stats = GetStats()
    return stats and (stats.EquippedCollector or "None") or "None"
end

function AutoDig.getCooldown()
    local stats = SC:Get()
    if not stats then return nil end

    local toolName = stats.EquippedCollector
    if not toolName or toolName == "None" then return nil end

    local cd = Collector.GetStat(toolName, "Cooldown")
    if not cd then return nil end

    local speedMult = (stats.Transient and stats.Transient.CollectorSpeed) or 1
    if speedMult ~= 1 then
        cd = cd / speedMult
    end
    return cd
end

function AutoDig.isBackpackFull()
    local coreStats = Lplr:WaitForChild("CoreStats", 1)
    if not coreStats then return false end
    local pollen = coreStats:FindFirstChild("Pollen")
    local capacity = coreStats:FindFirstChild("Capacity")
    if pollen and capacity then
        return not (capacity.Value > pollen.Value)
    end
    return false
end

function AutoDig.getPollen()
    local coreStats = Lplr:FindFirstChild("CoreStats")
    if coreStats and coreStats:FindFirstChild("Pollen") then
        return coreStats.Pollen.Value
    end
    return 0
end

function AutoDig.dig()
    if AutoDig.getEquippedTool() == "None" then return end
    local cd = AutoDig.getCooldown() or 0
    local now = time()
    if now - AutoDig._lastDigTime < cd then return end
    AutoDig._lastDigTime = now

    pcall(function()
        local humanoid = Lplr.Character and Lplr.Character:FindFirstChild("Humanoid")
        if humanoid then
            local track = humanoid:LoadAnimation(AutoDig._scoopAnim)
            track:Play()
        end
    end)

    require(RS.Events).ClientCall("ToolCollect")
end

function AutoDig.digFor(seconds)
    local startTime = tick()
    while tick() - startTime < seconds do
        if AutoDig.isBackpackFull() then return "backpack_full" end
        AutoDig.dig()
        task.wait(0.05)
    end
    return "timeout"
end

function AutoDig.digUntilFull(maxSeconds)
    maxSeconds = maxSeconds or 300
    local startTime = tick()
    while tick() - startTime < maxSeconds do
        if AutoDig.isBackpackFull() then return true end
        AutoDig.dig()
        task.wait(0.05)
    end
    return AutoDig.isBackpackFull()
end

local function getHoney()
    local ok, val = pcall(function()
        return Lplr:FindFirstChild("CoreStats") and Lplr.CoreStats:FindFirstChild("Honey") and Lplr.CoreStats.Honey
            .Value
    end)
    if ok and val then return val end
    local stats = GetStats()
    if stats and stats.Honey then return stats.Honey end
    return 0
end
Gear.ToolOrder = {
    { name = "Scooper",        cost = 0 },
    { name = "Rake",           cost = 800 },
    { name = "Clippers",       cost = 2200 },
    { name = "Magnet",         cost = 5500 },
    { name = "Vacuum",         cost = 14000 },
    { name = "Super-Scooper",  cost = 40000 },
    { name = "Pulsar",         cost = 125000 },
    { name = "Electro-Magnet", cost = 300000 },
    { name = "Scissors",       cost = 850000 },
    { name = "Honey Dipper",   cost = 1500000 },
    { name = "Scythe",         cost = 3500000 },
    { name = "Bubble Wand",    cost = 3500000 },
}

Gear.BackpackOrder = {
    { name = "Pouch",                 cost = 0,         capacity = 200 },
    { name = "Jar",                   cost = 650,       capacity = 750 },
    { name = "Backpack",              cost = 5500,      capacity = 3500 },
    { name = "Canister",              cost = 22000,     capacity = 10000 },
    { name = "Mega-Jug",              cost = 50000,     capacity = 24000 },
    { name = "Compressor",            cost = 160000,    capacity = 50000 },
    { name = "Elite Barrel",          cost = 650000,    capacity = 100000 },
    { name = "Port-O-Hive",           cost = 1250000,   capacity = 150000 },
    { name = "Porcelain Port-O-Hive", cost = 250000000, capacity = 500000 },
}

Gear._ownedTools = { "Scooper" }
Gear._ownedBags = { "Pouch" }
Gear._equippedTool = nil
Gear._equippedBag = nil

-- Read CoreStats.Capacity to detect which backpack is currently equipped
-- This is always up-to-date (unlike StatCache which can be stale)
function Gear.getBackpackFromCapacity()
    local ok, capValue = pcall(function()
        return game:GetService("Players").LocalPlayer.CoreStats.Capacity.Value
    end)
    if not ok or not capValue then return nil end

    -- Walk backwards so we match the highest-capacity bag first
    for i = #Gear.BackpackOrder, 1, -1 do
        if capValue >= Gear.BackpackOrder[i].capacity then
            return Gear.BackpackOrder[i].name, i
        end
    end
    return "Pouch", 1
end

function Gear.getCurrentGear()
    local stats
    if Stats and Stats.forceRefresh then
        stats = Stats.forceRefresh()
    end
    if not stats then
        stats = GetStats()
    end

    -- Use stats for equipped tool, fallback to local tracking
    local tool = (stats and stats.EquippedCollector) or Gear._equippedTool or "Scooper"

    -- For bag: prefer CoreStats.Capacity (always up-to-date) over stale StatCache
    local bag = Gear.getBackpackFromCapacity()
    if not bag then
        bag = (stats and stats.EquippedBackpack) or Gear._equippedBag or "Pouch"
    end

    -- Merge server list + local tracking for owned items
    local function mergeOwned(orderList, equippedName, serverList, localList)
        local ownedSet = {}

        -- From equipped
        ownedSet[equippedName] = true

        -- From server stats
        if type(serverList) == "table" then
            for _, name in pairs(serverList) do
                ownedSet[name] = true
            end
        end

        -- From local tracking
        if type(localList) == "table" then
            for _, name in pairs(localList) do
                ownedSet[name] = true
            end
        end

        -- Build ordered owned list
        local highest = 1
        for i, item in ipairs(orderList) do
            if ownedSet[item.name] then
                highest = i
            end
        end
        local owned = {}
        for i = 1, highest do
            table.insert(owned, orderList[i].name)
        end
        return owned
    end

    local ownedTools = mergeOwned(Gear.ToolOrder, tool, stats and stats.Collectors, Gear._ownedTools)
    local ownedBags = mergeOwned(Gear.BackpackOrder, bag, stats and stats.Backpacks, Gear._ownedBags)

    print("[Gear] Equipped: Tool=" .. tool .. " | Bag=" .. bag)
    print("[Gear] Owned Tools: " .. table.concat(ownedTools, ", ") .. " | Owned Bags: " .. table.concat(ownedBags, ", "))

    return tool, bag, ownedTools, ownedBags
end

function Gear.findHighestOwnedIndex(orderList, ownedList)
    local ownedSet = {}
    for _, name in ipairs(ownedList) do
        ownedSet[name] = true
    end

    local highest = 1
    for i, item in ipairs(orderList) do
        if ownedSet[item.name] then
            highest = i
        end
    end
    return highest
end

local function equipIfNeeded(category, itemName, currentEquipped)
    if currentEquipped == itemName then return end
    pcall(function()
        env:WaitForChild("ItemPackageEvent"):InvokeServer("Equip", {
            Type = itemName,
            Category = category,
            Mute = false
        })
    end)
    task.wait(1)
end

function Gear.tryUpgradeTool()
    local currentTool, _, ownedTools = Gear.getCurrentGear()
    local highestIdx = Gear.findHighestOwnedIndex(Gear.ToolOrder, ownedTools)
    local highestName = Gear.ToolOrder[highestIdx].name

    equipIfNeeded("Collector", highestName, currentTool)

    local nextIdx = highestIdx + 1
    if nextIdx > #Gear.ToolOrder then return false end

    local nextTool = Gear.ToolOrder[nextIdx]
    local honeyBefore = getHoney()
    local reserved = Quest._reservedHoney or 0
    local available = honeyBefore - reserved

    if available >= nextTool.cost then
        print("[Gear] Buying tool: " .. nextTool.name .. " | Cost: " .. nextTool.cost .. " | Honey: " .. honeyBefore)

        local IPE = game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("ItemPackageEvent")

        pcall(function()
            IPE:InvokeServer("Purchase", {
                ["Category"] = "Collector",
                ["Type"] = nextTool.name,
            })
        end)
        task.wait(2)

        local honeyAfter = getHoney()
        if honeyAfter < honeyBefore then
            print("[Gear] Tool purchased! Honey: " .. honeyBefore .. " -> " .. honeyAfter)
            table.insert(Gear._ownedTools, nextTool.name)
            Gear._equippedTool = nextTool.name
            print("[Gear] Tool upgraded to: " .. nextTool.name)
            return true
        else
            print("[Gear] Already own tool (honey unchanged): " .. nextTool.name .. " -> skipping")
            table.insert(Gear._ownedTools, nextTool.name)
            return true
        end
    end

    return false
end

function Gear.tryUpgradeBackpack()
    local capacityBag, capacityIdx = Gear.getBackpackFromCapacity()
    if not capacityBag then
        local _, currentBag, _, ownedBags = Gear.getCurrentGear()
        capacityIdx = Gear.findHighestOwnedIndex(Gear.BackpackOrder, ownedBags)
        capacityBag = Gear.BackpackOrder[capacityIdx].name
    end

    local highestIdx = capacityIdx
    local highestName = capacityBag
    print("[Gear] Current bag (from Capacity): " .. highestName .. " (index " .. highestIdx .. ")")

    Gear._ownedBags = {}
    for i = 1, highestIdx do
        table.insert(Gear._ownedBags, Gear.BackpackOrder[i].name)
    end
    Gear._equippedBag = highestName

    local _, currentBag = Gear.getCurrentGear()
    equipIfNeeded("Accessory", highestName, currentBag)

    local nextIdx = highestIdx + 1
    if nextIdx > #Gear.BackpackOrder then return false end

    local nextBag = Gear.BackpackOrder[nextIdx]
    local honeyBefore = getHoney()
    local reserved = Quest._reservedHoney or 0
    local available = honeyBefore - reserved

    if available >= nextBag.cost then
        print("[Gear] Buying bag: " .. nextBag.name .. " | Cost: " .. nextBag.cost .. " | Honey: " .. honeyBefore)

        local IPE = game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("ItemPackageEvent")
        local capBefore = pcall(function() return plr.CoreStats.Capacity.Value end)

        pcall(function()
            IPE:InvokeServer("Purchase", {
                ["Category"] = "Accessory",
                ["Type"] = nextBag.name,
            })
        end)
        task.wait(2)
        local newBag, newIdx = Gear.getBackpackFromCapacity()
        if newIdx and newIdx >= nextIdx then
            print("[Gear] Bag purchased! Capacity confirms: " .. (newBag or "?"))
            Gear._ownedBags = {}
            for i = 1, newIdx do
                table.insert(Gear._ownedBags, Gear.BackpackOrder[i].name)
            end
            Gear._equippedBag = newBag
            print("[Gear] Bag upgraded to: " .. newBag)
            return true
        else
            local honeyAfter = getHoney()
            if honeyAfter < honeyBefore then
                print("[Gear] Bag likely purchased (honey decreased), marking owned: " .. nextBag.name)
                table.insert(Gear._ownedBags, nextBag.name)
                Gear._equippedBag = nextBag.name
                return true
            else
                print("[Gear] Purchase failed or already owned (capacity & honey unchanged): " .. nextBag.name)
                return false
            end
        end
    end

    return false
end

function Gear.upgradeAll()
    local currentTool, currentBag, ownedTools, ownedBags = Gear.getCurrentGear()
    local honey = getHoney()
    local reserved = Quest._reservedHoney or 0
    local available = honey - reserved

    print("[Gear] Honey: " ..
        tostring(honey) .. " | Reserved: " .. tostring(reserved) .. " | Available: " .. tostring(available))
    print("[Gear] Current Tool: " .. tostring(currentTool) .. " | Current Bag: " .. tostring(currentBag))

    local bagIdx = Gear.findHighestOwnedIndex(Gear.BackpackOrder, ownedBags)
    equipIfNeeded("Accessory", Gear.BackpackOrder[bagIdx].name, currentBag)

    local toolIdx = Gear.findHighestOwnedIndex(Gear.ToolOrder, ownedTools)
    equipIfNeeded("Collector", Gear.ToolOrder[toolIdx].name, currentTool)

    local nextBagIdx = bagIdx + 1
    if nextBagIdx <= #Gear.BackpackOrder then
        print("[Gear] Next Bag: " ..
            Gear.BackpackOrder[nextBagIdx].name .. " | Cost: " .. Gear.BackpackOrder[nextBagIdx].cost)
    end
    local nextToolIdx = toolIdx + 1
    if nextToolIdx <= #Gear.ToolOrder then
        print("[Gear] Next Tool: " .. Gear.ToolOrder[nextToolIdx].name .. " | Cost: " .. Gear.ToolOrder[nextToolIdx]
            .cost)
    end

    local upgraded = false

    while Gear.tryUpgradeBackpack() do
        upgraded = true
        print("[Gear] Upgraded backpack!")
        task.wait(0.3)
    end

    while Gear.tryUpgradeTool() do
        upgraded = true
        print("[Gear] Upgraded tool!")
        task.wait(0.3)
    end

    return upgraded
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plr = Players.LocalPlayer
local Events = ReplicatedStorage:WaitForChild("Events")
local QuestsModule = require(ReplicatedStorage.Quests)
local NPCsModule = require(ReplicatedStorage.NPCs)

Quest = Quest or {}

local function getStats()
    return GetStats()
end

local function forceRefreshStats()
end

local function getItemCount(itemName)
    local ok, stats = pcall(function() return SC:Get() end)
    if not ok or not stats then return 0 end
    return (stats.Eggs and stats.Eggs[itemName]) or (stats.Items and stats.Items[itemName]) or 0
end

local function getHoney()
    local ok, val = pcall(function()
        return plr:FindFirstChild("CoreStats") and plr.CoreStats:FindFirstChild("Honey") and plr.CoreStats.Honey.Value
    end)
    if ok and val then return val end
    local stats = getStats()
    if stats and stats.Honey then return stats.Honey end
    return 0
end

local function moveToField(fieldName)
    if Tween then
        Tween.moveToField(fieldName)
    end
end

local function moveToNPC(npcName)
    if Tween then
        Tween.moveToNPC(npcName)
    end
end

local function hasNPCAlert(npcName)
    if NPC then
        return NPC.alert(npcName)
    end
    return false
end

local function talkToNPC(npcName)
    if NPC then
        return NPC.talkTo(npcName)
    end
    return false
end

local function feedBee(x, y, itemType, amount)
    if HiveManager and HiveManager.Feed then
        return HiveManager.Feed(x, y, itemType, amount)
    end
    return false
end

local function buyTreat(amount)
    if ItemManager and ItemManager.buyTreat then
        ItemManager.buyTreat(amount)
    end
end

local function countBeesAtLevel(minLevel)
    if not HiveManager or not HiveManager.GetBee then return 0 end
    local bees = HiveManager.GetBee()
    local count = 0
    for _, bee in ipairs(bees) do
        if bee.Level >= minLevel then
            count = count + 1
        end
    end
    return count
end

local function getTopBees(count)
    if not HiveManager or not HiveManager.GetBee then return {} end
    local bees = HiveManager.GetBee()
    table.sort(bees, function(a, b)
        return a.Level > b.Level
    end)
    local result = {}
    for i = 1, math.min(count or 7, #bees) do
        table.insert(result, bees[i])
    end
    return result
end

local function getBeeCount()
    local bees = HiveManager.GetBee()
    return #bees
end

Quest.FieldTiers = {
    { min = 0,  Red = "Mushroom Field",   Blue = "Bamboo Field",     White = "Bamboo Field" },
    { min = 5,  Red = "Strawberry Field", Blue = "Bamboo Field",     White = "Bamboo Field" },
    { min = 10, Red = "Strawberry Field", Blue = "Bamboo Field",     White = "Pineapple Patch" },
    { min = 15, Red = "Rose Field",       Blue = "Pine Tree Forest", White = "Pumpkin Patch" },
    { min = 25, Red = "Rose Field",       Blue = "Pine Tree Forest", White = "Pumpkin Patch" },
    { min = 35, Red = "Pepper Patch",     Blue = "Pine Tree Forest", White = "Coconut Field" },
}

Quest.FieldColors = {
    ["Sunflower Field"]    = "White",
    ["Dandelion Field"]    = "White",
    ["Spider Field"]       = "White",
    ["Pineapple Patch"]    = "White",
    ["Pumpkin Patch"]      = "White",
    ["Coconut Field"]      = "White",
    ["Blue Flower Field"]  = "Blue",
    ["Bamboo Field"]       = "Blue",
    ["Pine Tree Forest"]   = "Blue",
    ["Stump Field"]        = "Blue",
    ["Mushroom Field"]     = "Red",
    ["Clover Field"]       = "Red",
    ["Strawberry Field"]   = "Red",
    ["Cactus Field"]       = "Red",
    ["Rose Field"]         = "Red",
    ["Pepper Patch"]       = "Red",
    ["Mountain Top Field"] = "Red",
    ["Ant Field"]          = "Red",
}

Quest.MotherBearStopQuest = Config.MotherBearStopQuest or "Seven To Seven"

function Quest.getSmartField(color)
    local bee = getBeeCount()
    local chosen = Quest.FieldTiers[1]
    for _, tier in ipairs(Quest.FieldTiers) do
        if bee >= tier.min then chosen = tier end
    end
    if color == "Red" then return chosen.Red end
    if color == "White" then return chosen.White end
    return chosen.Blue
end

function Quest.getFieldForQuest(questName)
    local def = nil
    pcall(function() def = QuestsModule:Get(questName) end)
    if not def or not def.Tasks then return Quest.getSmartField("Blue") end

    for _, t in ipairs(def.Tasks) do
        if t.Zone then return t.Zone end
    end
    for _, t in ipairs(def.Tasks) do
        if t.Color then return Quest.getSmartField(t.Color) end
    end
    return Quest.getSmartField("Blue")
end

function Quest.hasItemTask(questName, itemType)
    local progress = Quest.getQuestProgress(questName)
    if not progress then return false, 0 end
    for _, t in ipairs(progress.tasks) do
        if not t.complete then
            local typ = string.lower(t.taskType)
            local desc = string.lower(t.description)
            if string.find(typ, string.lower(itemType)) or string.find(desc, string.lower(itemType)) then
                return true, t.remaining
            end
        end
    end
    return false, 0
end

function Quest.getActiveQuests()
    local stats = getStats()
    if not stats or not stats.Quests then return {} end
    return stats.Quests.Active or {}
end

function Quest.getQuestProgress(questName)
    local stats = getStats()
    if not stats then return nil end

    local ok, progressData = pcall(function()
        return QuestsModule:Progress(questName, stats)
    end)
    if not ok then return nil end

    local questDef = nil
    pcall(function()
        questDef = QuestsModule:Get(questName)
    end)

    local result = { name = questName, tasks = {}, allComplete = true }

    if questDef and questDef.Tasks and progressData then
        for i, taskDef in ipairs(questDef.Tasks) do
            local prog = progressData[i]
            if prog and type(prog) == "table" then
                local percent = math.floor((prog[1] or 0) * 100)
                local current = math.floor(prog[2] or 0)
                local amount = taskDef.Amount or taskDef.Goal or 0
                local remaining = math.max(0, amount - current)
                table.insert(result.tasks, {
                    description = taskDef.Description or taskDef.Type or "Task",
                    taskType    = taskDef.Type or "",
                    taskAmount  = amount,
                    remaining   = remaining,
                    percent     = percent,
                    current     = current,
                    complete    = percent >= 100,
                })
                if percent < 100 then
                    result.allComplete = false
                end
            end
        end
    end

    return result
end

function Quest.isQuestComplete(questName)
    local prog = Quest.getQuestProgress(questName)
    return prog and prog.allComplete
end

function Quest.handleTreatTask(questName)
    local progress = Quest.getQuestProgress(questName)
    if not progress then return false, false end

    for _, t in ipairs(progress.tasks) do
        if not t.complete then
            local desc        = string.lower(t.description)
            local typ         = string.lower(t.taskType)
            local isTreatFeed = string.find(desc, "treat") or string.find(typ, "treat")
            if isTreatFeed and t.remaining > 0 then
                local have = Stats.getItemCount("Treat")
                if have < t.remaining then
                    local needed = t.remaining - have
                    local treatCost = ItemManager.checkPrice("Treat")
                    if treatCost and treatCost.Category == "Honey" then
                        local totalCost = treatCost.Amount * needed
                        local honey = Stats.getHoney()
                        if honey < totalCost then
                            print("[Feed] Not enough honey for treats: need " .. totalCost .. " | have " .. honey)
                            return false, true
                        end
                    end
                    print("[Feed] Buying " .. needed .. " Treat")
                    ItemManager.buyTreat(needed)
                    task.wait(2)
                    have = Stats.getItemCount("Treat")
                    print("[Feed] After buying: have " .. have .. " Treat")
                end

                if have >= t.remaining then
                    local bees = HiveManager.GetBee()
                    if #bees == 0 then return false, false end
                    local bee = bees[math.random(1, #bees)]
                    HiveManager.Feed(bee.X, bee.Y, "Treat", t.remaining)
                    task.wait(1)
                    return true, false
                end
                return false, true
            end
        end
    end
    return false, false
end

function Quest.handleRoyalJellyTask(questName)
    local progress = Quest.getQuestProgress(questName)
    if not progress then return false, false end

    local beeCount = getBeeCount()
    if beeCount <= 15 then
        print("[Feed] Skipping RJ buy - only " .. beeCount .. " bees (need >15)")
        return false, false
    end

    for _, t in ipairs(progress.tasks) do
        if not t.complete then
            local desc = string.lower(t.description)
            local typ = string.lower(t.taskType)
            local isRJ = string.find(desc, "royal jelly") or string.find(typ, "royal jelly")
            if isRJ and t.remaining > 0 then
                local have = Stats.getItemCount("RoyalJelly")
                if have < t.remaining then
                    local needed = t.remaining - have
                    local rjCost = ItemManager.checkPrice("RoyalJelly")
                    if rjCost and rjCost.Category == "Honey" then
                        local totalCost = rjCost.Amount * needed
                        local honey = Stats.getHoney()
                        if honey < totalCost then
                            print("[Feed] Not enough honey for RJ: need " .. totalCost .. " | have " .. honey)
                            return false, true
                        end
                    end
                    print("[Feed] Buying " .. needed .. " Royal Jelly")
                    ItemManager.buyRoyalJelly(needed)
                    task.wait(2)
                    have = Stats.getItemCount("RoyalJelly")
                    print("[Feed] After buying: have " .. have .. " Royal Jelly")
                end

                if have >= t.remaining then
                    local bees = HiveManager.GetBee()
                    if #bees == 0 then return false, false end
                    local bee = bees[math.random(1, #bees)]
                    HiveManager.Feed(bee.X, bee.Y, "RoyalJelly", t.remaining)
                    task.wait(1)
                    return true, false
                end
                return false, true
            end
        end
    end
    return false, false
end

function Quest.handleFeedItemTask(questName)
    local progress = Quest.getQuestProgress(questName)
    if not progress then return false end

    local items = {
        { name = "Strawberry",     remote = "Strawberry",    match = "strawberr" },
        { name = "Blueberry",      remote = "Blueberry",     match = "blueberr" },
        { name = "Pineapple",      remote = "Pineapple",     match = "pineapple" },
        { name = "Sunflower Seed", remote = "SunflowerSeed", match = "sunflower seed" },
        { name = "Moon Charm",     remote = "MoonCharm",     match = "moon charm" },
        { name = "Bitterberry",    remote = "Bitterberry",   match = "bitterberr" },
        { name = "Neonberry",      remote = "Neonberry",     match = "neonberr" },
    }

    for _, t in ipairs(progress.tasks) do
        if not t.complete and t.remaining > 0 then
            local desc = string.lower(t.description)
            local typ = string.lower(t.taskType)
            print("[Feed] Checking task: type=" .. typ .. " | desc=" .. desc .. " | remaining=" .. t.remaining)

            local matchedItem = nil
            for _, item in ipairs(items) do
                if string.find(desc, item.match) or string.find(typ, item.match) then
                    matchedItem = item
                    local have = Stats.getItemCount(item.remote)
                    print("[Feed] Quest needs " ..
                        item.name .. " | Have: " .. have .. " (key=" .. item.remote .. ") | Need: " .. t.remaining)
                    if have > 0 then
                        local amount = math.min(have, t.remaining)
                        local bees = HiveManager.GetBee()
                        if #bees > 0 then
                            local bee = bees[math.random(1, #bees)]
                            print("[Feed] Feeding " ..
                                amount .. " " .. item.name .. " at [" .. bee.X .. "," .. bee.Y .. "]")
                            HiveManager.Feed(bee.X, bee.Y, item.remote, amount)
                            task.wait(1)
                            return true
                        end
                    else
                        print("[Feed] Need " .. item.name .. " but have 0, skipping")
                    end
                    break
                end
            end

            -- Generic feed: only if no specific item was mentioned in the description
            if not matchedItem then
                local isFeedTask = string.find(typ, "feed") or string.find(desc, "feed")
                local isTreat = string.find(desc, "treat") or string.find(typ, "treat")
                local isRJ = string.find(desc, "royal jelly") or string.find(typ, "royal jelly")
                if isFeedTask and not isTreat and not isRJ then
                    for _, item in ipairs(items) do
                        local have = Stats.getItemCount(item.remote)
                        if have > 0 then
                            local amount = math.min(have, t.remaining)
                            local bees = HiveManager.GetBee()
                            if #bees > 0 then
                                local bee = bees[math.random(1, #bees)]
                                print("[Feed] Generic feed: using " ..
                                    amount .. " " .. item.name .. " at [" .. bee.X .. "," .. bee.Y .. "]")
                                HiveManager.Feed(bee.X, bee.Y, item.remote, amount)
                                task.wait(1)
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

function Quest.getFeedCostForQuest(questName)
    if not questName then return 0 end
    local progress = Quest.getQuestProgress(questName)
    if not progress then return 0 end

    local totalCost = 0
    for _, t in ipairs(progress.tasks) do
        if not t.complete then
            local desc = string.lower(t.description)
            local typ = string.lower(t.taskType)

            local isTreat = string.find(desc, "treat") or string.find(typ, "treat")
            if isTreat and t.remaining > 0 then
                local have = Stats.getItemCount("Treat")
                local need = math.max(0, t.remaining - have)
                if need > 0 then
                    local treatCost = ItemManager.checkPrice("Treat")
                    if treatCost and treatCost.Category == "Honey" then
                        totalCost = totalCost + (treatCost.Amount * need)
                    end
                end
            end

            local isRJ = string.find(desc, "royal jelly") or string.find(typ, "royal jelly")
            if isRJ and t.remaining > 0 then
                local have = Stats.getItemCount("RoyalJelly")
                local need = math.max(0, t.remaining - have)
                if need > 0 then
                    local rjCost = ItemManager.checkPrice("RoyalJelly")
                    if rjCost and rjCost.Category == "Honey" then
                        totalCost = totalCost + (rjCost.Amount * need)
                    end
                end
            end
        end
    end
    return totalCost
end

function Quest.getCurrentQuestOf(npcName)
    local ok, questName = pcall(function()
        local eventIdx, phase = NPCsModule.ResolveEventPhase(npcName)
        if not eventIdx then return nil end
        if phase ~= "Ongoing" and phase ~= "Finish" then return nil end

        local npcData = NPCsModule.Get(npcName)
        if not npcData or not npcData.Events then return nil end

        local event = npcData.Events[eventIdx]
        if not event then return nil end

        if event.Quest then
            return type(event.Quest) == "table" and event.Quest.Name or event.Quest
        end
        return nil
    end)
    return ok and questName or nil
end

function Quest.getNPCPhase(npcName)
    local ok, phase = pcall(function()
        local _, p = NPCsModule.ResolveEventPhase(npcName)
        return p
    end)
    return ok and phase or nil
end

function Quest.hasQuestToAccept(npcName)
    local phase = Quest.getNPCPhase(npcName)
    return phase == "Start"
end

function Quest.getNextQuestName(npcName)
    local ok, questName = pcall(function()
        local eventIdx, phase = NPCsModule.ResolveEventPhase(npcName)
        if not eventIdx then return nil end
        if phase ~= "Start" then return nil end
        local npcData = NPCsModule.Get(npcName)
        if not npcData or not npcData.Events then return nil end
        local event = npcData.Events[eventIdx]
        if not event then return nil end
        if event.Quest then
            return type(event.Quest) == "table" and event.Quest.Name or event.Quest
        end
        return nil
    end)
    return ok and questName or nil
end

function Quest.executeFarmAction(action)
    local fieldName = action.field or Quest.getSmartField("Blue")
    Quest.doFarmLoop(fieldName, Config.FarmDuration or 30)
end

function Quest.feedItemsAtHive(questName)
    if not questName then return end
    local progress = Quest.getQuestProgress(questName)
    if not progress then return end

    local bees = HiveManager.GetBee()
    if #bees == 0 then return end

    for _, t in ipairs(progress.tasks) do
        if not t.complete and t.remaining > 0 then
            local desc = string.lower(t.description)
            local typ = string.lower(t.taskType)

            local isTreat = string.find(desc, "treat") or string.find(typ, "treat")
            if isTreat then
                local have = Stats.getItemCount("Treat")
                if have > 0 then
                    local amount = math.min(have, t.remaining)
                    local bee = bees[math.random(1, #bees)]
                    print("[Feed] Feeding " .. amount .. " Treat")
                    HiveManager.Feed(bee.X, bee.Y, "Treat", amount)
                    task.wait(1)
                end
            end

            local isRJ = string.find(desc, "royal jelly") or string.find(typ, "royal jelly")
            if isRJ then
                local have = Stats.getItemCount("RoyalJelly")
                if have > 0 then
                    local amount = math.min(have, t.remaining)
                    local bee = bees[math.random(1, #bees)]
                    print("[Feed] Feeding " .. amount .. " RoyalJelly")
                    HiveManager.Feed(bee.X, bee.Y, "RoyalJelly", amount)
                    task.wait(1)
                end
            end

            local items = {
                { name = "Strawberry",     remote = "Strawberry" },
                { name = "Blueberry",      remote = "Blueberry" },
                { name = "Pineapple",      remote = "Pineapple" },
                { name = "Sunflower Seed", remote = "SunflowerSeed" },
                { name = "Moon Charm",     remote = "MoonCharm" },
                { name = "Bitterberry",    remote = "Bitterberry" },
                { name = "Neonberry",      remote = "Neonberry" },
            }
            for _, item in ipairs(items) do
                if string.find(desc, string.lower(item.name)) or string.find(typ, string.lower(item.name)) then
                    local have = Stats.getItemCount(item.remote)
                    if have > 0 then
                        local amount = math.min(have, t.remaining)
                        local bee = bees[math.random(1, #bees)]
                        print("[Feed] Feeding " .. amount .. " " .. item.name)
                        HiveManager.Feed(bee.X, bee.Y, item.remote, amount, false)
                        task.wait(1)
                    end
                end
            end
        end
    end
end

function Quest.completeQuest(npcName, questName)
    Config.CurrentAction = "Turning in quest to " .. npcName .. "..."
    if NPC then
        NPC.goAndTurnIn(npcName, questName)
    end
    task.wait(2)
end

function Quest.processQuest(npcName, questName)
    local progress = Quest.getQuestProgress(questName)
    if not progress then return end

    if progress.allComplete then
        Quest.completeQuest(npcName, questName)
        task.wait(2)
        if NPC then
            NPC.goAndAccept(npcName)
        end
        return
    end

    local treated, needHoneyTreat = Quest.handleTreatTask(questName)
    if treated then print("[Quest] Fed treats for: " .. questName) end

    local fedRJ, needHoneyRJ = Quest.handleRoyalJellyTask(questName)
    if fedRJ then print("[Quest] Fed royal jelly for: " .. questName) end

    local fedItem = Quest.handleFeedItemTask(questName)
    if fedItem then print("[Quest] Fed item for: " .. questName) end

    local questField = Quest.getFieldForQuest(questName)
    Quest.executeFarmAction({ field = questField })
end

function Quest.isMotherBearDone()
    local ok, result = pcall(function()
        local eventIdx, phase = NPCsModule.ResolveEventPhase("Mother Bear")
        if not eventIdx then return true end

        local npcData = NPCsModule.Get("Mother Bear")
        if not npcData or not npcData.Events then return false end

        local stopIdx = nil
        for i, event in ipairs(npcData.Events) do
            if event.Quest then
                local qName = type(event.Quest) == "table" and event.Quest.Name or event.Quest
                if qName == Quest.MotherBearStopQuest then
                    stopIdx = i
                    break
                end
            end
        end

        if not stopIdx then return false end

        if eventIdx > stopIdx then return true end

        return false
    end)

    if ok then return result end

    local motherQuest = Quest.getCurrentQuestOf("Mother Bear")
    if not motherQuest and not NPC.alert("Mother Bear") then
        return true
    end
    return false
end

function Quest.determinePhase()
    local motherQuest = Quest.getCurrentQuestOf("Mother Bear")
    local blackBearQuest = Quest.getCurrentQuestOf("Black Bear")

    if Config.EnableMotherBear and motherQuest and not Quest.isMotherBearDone() then
        return "active", motherQuest, "Mother Bear"
    end

    if Config.EnableBlackBear and blackBearQuest then
        return "active", blackBearQuest, "Black Bear"
    end

    if Config.EnableMotherBear and not motherQuest and not Quest.isMotherBearDone() then
        if Quest.hasQuestToAccept("Mother Bear") or NPC.alert("Mother Bear") then
            return "accept_mother", nil, "Mother Bear"
        end
    end

    if Config.EnableBlackBear and not blackBearQuest then
        if Quest.hasQuestToAccept("Black Bear") or NPC.alert("Black Bear") then
            return "accept_black", nil, "Black Bear"
        end
    end

    return "idle", nil, nil
end

function Quest.doFarmLoop(fieldName, duration)
    duration = duration or 30
    while SellManager and SellManager.isSelling do task.wait(0.5) end
    Config.FarmField = fieldName
    Config.CurrentAction = "Tweening to " .. fieldName .. "..."
    moveToField(fieldName)
    task.wait(1)

    Config.CurrentAction = "Farming at " .. fieldName .. "..."
    local loopStart = tick()
    while tick() - loopStart < duration do
        if SellManager and SellManager.isSelling then
            task.wait(1)
        else
            task.wait(0.5)
        end
    end
end

function Quest.run()
    local statsReady = false
    for attempt = 1, 30 do
        local stats = getStats()
        if stats and stats.Quests then
            statsReady = true
            break
        end
        warn("[Quest] Waiting for stats to load... attempt " .. attempt)
        task.wait(2)
    end

    if not statsReady then
        warn("[Quest] Stats never loaded, starting anyway...")
    end

    print("=== [Quest] Startup - Detecting quests ===")
    local mbQuest = Quest.getCurrentQuestOf("Mother Bear")
    local bbQuest = Quest.getCurrentQuestOf("Black Bear")
    print("[Quest] Mother Bear: " ..
        tostring(mbQuest or "(none)") .. " | Phase: " .. tostring(Quest.getNPCPhase("Mother Bear")))
    print("[Quest] Black Bear: " ..
        tostring(bbQuest or "(none)") .. " | Phase: " .. tostring(Quest.getNPCPhase("Black Bear")))
    print("[Quest] Mother Bear done: " .. tostring(Quest.isMotherBearDone()))
    local active = Quest.getActiveQuests()
    for idx, q in pairs(active) do
        local name = type(q) == "table" and q.Name or tostring(q)
        print("[Quest] Raw Active[" .. tostring(idx) .. "] = " .. tostring(name))
    end
    print("=== [Quest] Starting main loop ===")

    while Config.EnableQuest do
        local phase, questName, npcName = Quest.determinePhase()
        print("[Quest] Phase: " ..
            tostring(phase) .. " | Quest: " .. tostring(questName) .. " | NPC: " .. tostring(npcName))

        Quest._reservedHoney = 0
        local feedCost = 0
        if phase == "active" and questName then
            feedCost = Quest.getFeedCostForQuest(questName)
            local honey = Stats.getHoney()
            if honey >= feedCost and feedCost > 0 then
                Quest._reservedHoney = feedCost
                print("[Quest] Reserving " .. feedCost .. " honey for feed items")
            elseif feedCost > 0 then
                print("[Quest] Can't afford feed cost (" .. feedCost .. "), allowing lower priorities to spend honey")
            end
        end

        if phase == "accept_mother" then
            Config.CurrentAction = "Walking to Mother Bear..."
            local nextQuest = Quest.getNextQuestName("Mother Bear")
            NPC.goAndAccept("Mother Bear")
            task.wait(1)
            if nextQuest then
                pcall(function()
                    game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("GiveQuest"):FireServer(nextQuest)
                end)
                print("[Quest] Fired GiveQuest for Mother Bear: " .. nextQuest)
                task.wait(1)
            end
            local check = Quest.getCurrentQuestOf("Mother Bear")
            if check then
                print("[Quest] Accepted Mother Bear quest: " .. check)
            else
                warn("[Quest] Failed to accept Mother Bear quest, will retry...")
            end
        elseif phase == "accept_black" then
            Config.CurrentAction = "Walking to Black Bear..."
            local nextQuest = Quest.getNextQuestName("Black Bear")
            NPC.goAndAccept("Black Bear")
            task.wait(1)
            if nextQuest then
                pcall(function()
                    game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("GiveQuest"):FireServer(nextQuest)
                end)
                print("[Quest] Fired GiveQuest for Black Bear: " .. nextQuest)
                task.wait(1)
            end
            local check = Quest.getCurrentQuestOf("Black Bear")
            if check then
                print("[Quest] Accepted Black Bear quest: " .. check)
            else
                warn("[Quest] Failed to accept Black Bear quest, will retry...")
            end
        elseif phase == "active" and questName then
            Config.CurrentAction = "Processing quest: " .. questName .. "..."
            Quest.processQuest(npcName, questName)
        else
            Quest._reservedHoney = 0
            local farmField = Config.FarmField or Quest.getSmartField("Blue")
            Config.CurrentAction = "Auto Farming at " .. farmField .. "..."
            Quest.doFarmLoop(farmField, Config.FarmDuration or 30)
        end

        if Config.EnableAutoEgg then
            pcall(function()
                local cost = ItemManager.checkPrice("Basic")
                local honey = Stats.getHoney()
                local available = honey - (Quest._reservedHoney or 0)
                if cost and cost.Category == "Honey" and available >= cost.Amount then
                    Config.CurrentAction = "Buying & placing egg..."
                    HiveManager.buyAndPlaceBasicEgg()
                else
                    if Quest._reservedHoney > 0 then
                        print("[Egg] Skipped - honey reserved for feed items")
                    end
                end
            end)
        end

        if Config.EnableGearUpgrade then
            pcall(function() Gear.upgradeAll() end)
        end

        pcall(function()
            HiveManager.feedGingerbreadBears()
        end)

        task.wait(3)
    end
end

SellManager = SellManager or {}
SellManager.isSelling = false
SellManager.enabled = Config.EnableAutoSell ~= false

local function getPollen()
    local core = plr:FindFirstChild("CoreStats")
    if core and core:FindFirstChild("Pollen") then
        return core.Pollen.Value
    end
    return 0
end

function SellManager.tpToHive()
    if not (plr:FindFirstChild("SpawnPos") and plr.SpawnPos.Value) then
        return false
    end

    local sp = plr.SpawnPos.Value.Position
    local hiveCF =
        CFrame.new(sp.X, sp.Y, sp.Z, -0.996, 0, 0.02, 0, 1, 0, -0.02, 0, -0.9)
        + Vector3.new(0, 0, 8)

    if Tween and Tween.tweenTo then
        Tween.tweenTo(hiveCF)
        return true
    end

    return false
end

function SellManager.sell()
    if SellManager.isSelling then return false end
    if getPollen() <= 0 then return false end
    if not (plr:FindFirstChild("SpawnPos") and plr.SpawnPos.Value) then
        return false
    end

    SellManager.isSelling = true
    TokenManager._walkTarget = nil
    Config.CurrentAction = "Converting Pollen at Hive..."
    print("[Sell] Starting convert...")

    local hivePos = plr.SpawnPos.Value.Position
    local timeout = Config.SellTimeout or 90
    local startTime = tick()

    SellManager.tpToHive()
    task.wait(1)

    local atHive = false
    pcall(function()
        atHive = plr:DistanceFromCharacter(hivePos) < 5
    end)
    if not atHive then
        SellManager.tpToHive()
        task.wait(2)
    end

    pcall(function()
        Events:WaitForChild("PlayerHiveCommand"):FireServer("ToggleHoneyMaking")
    end)
    task.wait(1)

    local lastToggleTime = tick()
    local lastTweenTime = tick()

    while getPollen() > 0 and (tick() - startTime < timeout) do
        task.wait(0.5)

        local needsTween = false
        pcall(function()
            if plr:DistanceFromCharacter(hivePos) >= 5 then
                needsTween = true
            end
        end)

        if needsTween and (tick() - lastTweenTime > 3) then
            lastTweenTime = tick()
            SellManager.tpToHive()
            task.wait(1)
        end

        local needsToggle = false
        pcall(function()
            local btn = plr.PlayerGui.ScreenGui.ActivateButton
            if btn and btn:FindFirstChild("TextBox") then
                if string.match(btn.TextBox.Text, "Make") then
                    needsToggle = true
                end
            end
        end)

        if needsToggle and (tick() - lastToggleTime > 3) then
            lastToggleTime = tick()
            pcall(function()
                Events:WaitForChild("PlayerHiveCommand"):FireServer("ToggleHoneyMaking")
            end)
            task.wait(1)
        end
    end

    task.wait(3)
    print("[Sell] Convert done. Pollen: " .. getPollen())

    pcall(function()
        local phase, questName = Quest.determinePhase()
        if questName then
            print("[Sell] At hive - checking feed items for: " .. questName)
            Quest.feedItemsAtHive(questName)
        end
    end)

    if Config.EnableGearUpgrade and Gear and Gear.upgradeAll then
        pcall(function()
            Gear.upgradeAll()
        end)
    end

    SellManager.isSelling = false
    Config.FarmField = nil
    return true
end

-- local hive = HiveManager.GetPlayerHive()
-- if hive then
--     local hiveID = hive:FindFirstChild("HiveID") and hive.HiveID.Value
--     local spawnPos = hive:FindFirstChild("SpawnPos") and hive.SpawnPos.Value

--     print("Hive ID:", hiveID or "N/A")
--     print("SpawnPos:", spawnPos or "N/A")
-- end


Stats._cachedStats = nil
Stats._lastStatRefresh = 0

local StatCache = require(ReplicatedStorage:WaitForChild("ClientStatCache"))

function Stats.refresh()
    local ok, stats = pcall(function()
        return Events:WaitForChild("RetrievePlayerStats"):InvokeServer()
    end)

    if ok and stats then
        Stats._cachedStats = stats
        Stats._lastStatRefresh = tick()
        return stats
    end

    return Stats._cachedStats
end

function Stats.get()
    if Stats._cachedStats and (tick() - Stats._lastStatRefresh) < 3 then
        return Stats._cachedStats
    end

    local fresh = Stats.refresh()
    if fresh then return fresh end

    local ok, fallback = pcall(function()
        return StatCache:Get()
    end)

    if ok and fallback then
        return fallback
    end

    return nil
end

function Stats.forceRefresh()
    return Stats.refresh()
end

function Stats.getItemCount(itemName)
    local ok, stats = pcall(function() return SC:Get() end)
    if not ok or not stats then return 0 end
    return (stats.Eggs and stats.Eggs[itemName]) or (stats.Items and stats.Items[itemName]) or 0
end

function Stats.getHoney()
    local ok, val = pcall(function()
        return plr:FindFirstChild("CoreStats")
            and plr.CoreStats:FindFirstChild("Honey")
            and plr.CoreStats.Honey.Value
    end)

    if ok and val then
        return val
    end

    local stats = Stats.get()
    if stats and stats.Totals and stats.Totals.Honey then
        return stats.Totals.Honey
    end

    if stats and stats.Honey then
        return stats.Honey
    end

    return 0
end

function Stats.getTickets()
    return Stats.getItemCount("Ticket")
end

function Stats.getPlayerHive()
    local honeycombs = workspace:FindFirstChild("Honeycombs")
    if not honeycombs then return nil end

    for _, hive in pairs(honeycombs:GetChildren()) do
        local owner = hive:FindFirstChild("Owner")
        if owner and (owner.Value == plr or owner.Value == plr.Name) then
            return hive
        end
    end

    return nil
end

GetStats = function()
    return Stats.get()
end

task.spawn(function()
    while true do
        pcall(function()
            Stats.refresh()
        end)
        task.wait(2)
    end
end)

local EggTypes = { "Basic", "Silver", "Gold", "Diamond", "Mythic", "Star" }

task.spawn(function()
    task.wait(5)
    while true do
        pcall(function()
            local stats = SC:Get()
            if not stats or not stats.Eggs then return end
            for _, eggName in ipairs(EggTypes) do
                local count = stats.Eggs[eggName] or 0
                if count > 0 then
                    local x, y = HiveManager.getEmptySlot()
                    if not x then return end
                    print("[Egg] Placing " .. eggName .. " egg at [" .. x .. "," .. y .. "]")
                    HiveManager.PlaceEgg(x, y, eggName, 1)
                    task.wait(1)
                end
            end
        end)
        task.wait(5)
    end
end)

local RARITY_ORDER = {
    ["Common"] = 1,
    ["Rare"] = 2,
    ["Epic"] = 3,
    ["Legendary"] = 4,
    ["Mythic"] = 5,
    ["Event"] = 6,
}

function HiveManager.useStarJelly()
    -- Check both possible stat keys
    local starJellyCount = Stats.getItemCount("StarJelly")
    if starJellyCount <= 0 then
        starJellyCount = Stats.getItemCount("Star Jelly")
    end
    if starJellyCount <= 0 then
        -- Also check raw stats directly
        local stats = GetStats()
        if stats then
            if stats.Eggs then
                starJellyCount = stats.Eggs["StarJelly"] or stats.Eggs["Star Jelly"] or 0
            end
            if starJellyCount <= 0 and stats.Items then
                starJellyCount = stats.Items["StarJelly"] or stats.Items["Star Jelly"] or 0
            end
        end
    end
    if starJellyCount <= 0 then return end

    local bees = HiveManager.GetBee()
    if #bees == 0 then return end

    local lowestVal = math.huge
    for _, bee in ipairs(bees) do
        local val = RARITY_ORDER[bee.Rarity] or 1
        if val < lowestVal then
            lowestVal = val
        end
    end

    local candidates = {}
    for _, bee in ipairs(bees) do
        local val = RARITY_ORDER[bee.Rarity] or 1
        if val == lowestVal then
            table.insert(candidates, bee)
        end
    end

    if #candidates == 0 then return end

    local target = candidates[math.random(1, #candidates)]
    print("[StarJelly] Using on " ..
        target.Type .. " (" .. target.Rarity .. ") at [" .. target.X .. "," .. target.Y .. "] | Have: " .. starJellyCount)

    local IPE = game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("ConstructHiveCellFromEgg")
    pcall(function()
        IPE:InvokeServer(target.X, target.Y, "StarJelly", 1, false)
    end)
    task.wait(1)
end

task.spawn(function()
    task.wait(10)
    while true do
        if Config.EnableStarJelly then
            pcall(function()
                HiveManager.useStarJelly()
            end)
        end
        task.wait(10)
    end
end)

function MobManager.isMobNearby()
    local character = plr.Character
    if not character then return false end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local monsters = workspace:FindFirstChild("Monsters")
    if not monsters then return false end

    for _, mob in ipairs(monsters:GetChildren()) do
        if mob:FindFirstChild("Head")
            and not string.match(mob.Name, "Vici")
            and not string.match(mob.Name, "Windy")
            and not string.match(mob.Name, "Mondo") then
            local targeting = false

            if mob:FindFirstChild("Target")
                and tostring(mob.Target.Value) == plr.Name then
                targeting = true
            end

            if mob:FindFirstChild("KaiTunMobTag") then
                targeting = true
            end

            if targeting then
                local dist = (hrp.Position - mob.Head.Position).Magnitude
                if dist < (Config.MobDetectRange or 50) then
                    if not mob:FindFirstChild("KaiTunMobTag") then
                        local tag = Instance.new("BoolValue")
                        tag.Name = "KaiTunMobTag"
                        tag.Parent = mob
                    end
                    return true
                end
            end
        end
    end

    return false
end

function MobManager.avoidMobs()
    local character = plr.Character
    if not character then return end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end

    if not MobManager.isMobNearby() then return end

    local oldJumpPower = humanoid.JumpPower
    humanoid:MoveTo(humanoid.RootPart.Position)

    local timeout = tick()
    repeat
        task.wait(0.05)
        if plr.Character and plr.Character:FindFirstChild("Humanoid") then
            plr.Character.Humanoid.JumpPower = 80
            plr.Character.Humanoid.Jump = true
        end
    until not MobManager.isMobNearby() or (tick() - timeout > 10)

    if plr.Character and plr.Character:FindFirstChild("Humanoid") and oldJumpPower then
        plr.Character.Humanoid.JumpPower = oldJumpPower
    end
    task.wait(0.1)
end

task.spawn(function()
    while true do
        if Config.EnableMobAvoidance then
            pcall(function()
                if MobManager.isMobNearby() then
                    local hum = plr.Character and plr.Character:FindFirstChild("Humanoid")
                    if hum then
                        hum.Jump = true
                    end
                end
            end)
        end
        task.wait(0.1)
    end
end)


TokenManager.TokenIds = {
    ["Ticket"] = "1674871631",
    ["Glue"] = "2504978518",
    ["Pineapple"] = "1952796032",
    ["Strawberry"] = "1952740625",
    ["Blueberry"] = "2028453802",
    ["SunflowerSeed"] = "1952682401",
    ["Treat"] = "2028574353",
    ["Gumdrop"] = "1838129169",
    ["Red Extract"] = "2495935291",
    ["Blue Extract"] = "2495936060",
    ["Oil"] = "2545746569",
    ["Glitter"] = "2542899798",
    ["Enzymes"] = "2584584968",
    ["TropicalDrink"] = "3835877932",
    ["Diamond Egg"] = "1471850677",
    ["Gold Egg"] = "1471849394",
    ["Mythic Egg"] = "4520739302",
    ["Star Treat"] = "2028603146",
    ["Royal Jelly"] = "1471882621",
    ["Star Jelly"] = "2319943273",
    ["Moon Charm"] = "2306224708",
    ["Super Smoothie"] = "5144657109",
    ["Bitterberry"] = "4483236276",
    ["Festive Bean"] = "4483230719",
    ["Ginger Bread"] = "6077173317",
    ["Honey Token"] = "1472135114",
    ["Purple Potion"] = "4935580111",
    ["Snowflake"] = "6087969886",
    ["Magic Bean"] = "2529092020",
    ["Neonberry"] = "4483267595",
    ["Swirled Wax"] = "8277783113",
    ["Soft Wax"] = "8277778300",
    ["Hard Wax"] = "8277780065",
    ["Caustic Wax"] = "827778166"
}

TokenManager.PrioritizeIds = {
    ["Token Link"] = "1629547638",
    ["Inspire"] = "2000457501",
    ["Bear Morph"] = "177997841",
    ["Pollen Bomb"] = "1442725244",
    ["Fuzz Bomb"] = "4889322534",
    ["Pollen Haze"] = "4889470194",
    ["Triangulate"] = "4519523935",
    ["Inferno"] = "4519549299",
    ["Summon Frog"] = "4528414666",
    ["Tornado"] = "3582519526",
    ["Cross Hair"] = "8173559749",
    ["Red Boost"] = "1442859163",
    ["Inflate Balloon"] = "8083437090"
}

TokenManager.EventTokenIds = {
    ["RedBoost"] = "rbxassetid://1442859163",
    ["BlueBoost"] = "rbxassetid://1442863423",
    ["BlueSync"] = "rbxassetid://1874692303",
    ["RedSync"] = "rbxassetid://1874704640",
    ["Bomb"] = "rbxassetid://1442725244",
    ["Bomb+"] = "rbxassetid://1442764904",
    ["BabyLove"] = "rbxassetid://1472256444",
    ["Inspire"] = "rbxassetid://2000457501",
    ["Haste"] = "65867881"
}

TokenManager.EventTokenIdRef = {}
for k, v in pairs(TokenManager.EventTokenIds) do TokenManager.EventTokenIdRef[v] = k end

TokenManager.NeedState = {
    RedBoost = { Stack = 10, Cooldown = 15 },
    BlueBoost = { Stack = 10, Cooldown = 15 },
    Bomb = { Stack = 10, Cooldown = 5 },
    BabyLove = { Stack = 1, Cooldown = 30 },
    Haste = { Stack = 10, Cooldown = 15 }
}

function TokenManager.isToken(obj)
    return obj
        and obj:IsA("Part")
        and obj.Name == "C"
        and obj.Parent
        and obj.Orientation.Z == 0
        and obj:FindFirstChild("FrontDecal")
end

function TokenManager.isPriorityToken(obj)
    if not obj:FindFirstChild("FrontDecal") then return false end
    local texture = obj.FrontDecal.Texture

    for _, id in pairs(TokenManager.PrioritizeIds) do
        if string.find(texture, id) then return true end
    end

    for _, id in pairs(TokenManager.TokenIds) do
        if string.find(texture, id) then return true end
    end

    return false
end

function TokenManager.getFieldByName(name)
    return game.Workspace.FlowerZones:FindFirstChild(name)
end

function TokenManager.getFieldId(name)
    local field = TokenManager.getFieldByName(name)
    return field and field:FindFirstChild("ID") and field.ID.Value
end

function TokenManager.getFieldByFP(fpName)
    for _, v in pairs(ListField) do
        if "FP" .. tostring(TokenManager.getFieldId(v)) == fpName then
            return v
        end
    end
end

function TokenManager.getFieldByPosition(pos)
    local rayparams = RaycastParams.new()
    rayparams.FilterDescendantsInstances = { game.Workspace.Flowers }
    rayparams.FilterType = Enum.RaycastFilterType.Include

    local ray = workspace:Raycast(pos + Vector3.new(0, 5, 0), Vector3.new(0, -50, 0), rayparams)
    if ray and ray.Instance then
        local curr = string.split(ray.Instance.Name, "-")[1]
        return TokenManager.getFieldByFP(curr)
    end
end

function TokenManager.getNearestField(position)
    local zones = workspace:FindFirstChild("FlowerZones")
    if not zones then return "Bamboo Field" end

    local bestField = "Bamboo Field"
    local bestDist = math.huge

    for _, field in pairs(zones:GetChildren()) do
        if field.Name ~= "PuffField" then
            local dist = (position - field.Position).Magnitude
            if dist < bestDist then
                bestDist = dist
                bestField = field.Name
            end
        end
    end

    return bestField
end

function TokenManager.isTokenInField(token, fieldName)
    local zones = workspace:FindFirstChild("FlowerZones")
    if not zones then return false end

    local field = zones:FindFirstChild(fieldName)
    if not field then return false end

    local range = field:FindFirstChild("Range") and field.Range.Value or 60
    return (token.Position - field.Position).Magnitude < range
end

function TokenManager.checkBuff(iconId)
    for _, gui in pairs(plr.PlayerGui.ScreenGui:GetChildren()) do
        if gui.Name == "TileGrid" then
            for _, v in pairs(gui:GetChildren()) do
                if v:FindFirstChild("BG") and v.BG:FindFirstChild("Icon") then
                    if string.find(v.BG.Icon.Image, iconId) then
                        local stack = tonumber(string.gsub(v.BG.Text.Text, "x", "")) or 1
                        return { CurrentStack = stack, Percent = v.BG.Bar.Size.Y.Scale }
                    end
                end
            end
        end
    end
    return nil
end

function TokenManager.smartMove(targetPos)
    local char = plr.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    char.Humanoid:MoveTo(targetPos)
end

function TokenManager.moveToToken(Token, TokenList)
    local char = plr.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    char.Humanoid:MoveTo(Token.Position)
end

function TokenManager.tokenMinimax(ListAllToken, CurrentState, Depth)
    if Depth == 0 or not next(ListAllToken) then
        return CurrentState.Point, nil
    end

    local BestTokenEval = -math.huge
    local BestToken = nil
    local count = 0
    for _, v in pairs(ListAllToken) do
        count = count + 1
        if count > 10 then break end

        if not CurrentState.CollectedToken[v.ID] then
            local dist = (CurrentState.Position - v.Position).Magnitude
            local timeToReach = dist / CurrentState.Speed
            local remainingTokenTime = v.Dur - (tick() - v.ClientStartTime)

            if remainingTokenTime > timeToReach then
                CurrentState.CollectedToken[v.ID] = true
                local moveScore = -dist * 0.1
                local typeScore = 0
                if v.Type == "Bomb" or v.Type == "Bomb+" then typeScore = 10 end
                if TokenManager.NeedState[v.Type] then typeScore = 20 end

                local OldPos = CurrentState.Position
                CurrentState.Position = v.Position
                CurrentState.Point = CurrentState.Point + typeScore + moveScore

                local eval = TokenManager.tokenMinimax(ListAllToken, CurrentState, Depth - 1)

                if eval > BestTokenEval then
                    BestTokenEval = eval
                    BestToken = v
                end
                CurrentState.Position = OldPos
                CurrentState.Point = CurrentState.Point - (typeScore + moveScore)
                CurrentState.CollectedToken[v.ID] = nil
            end
        end
    end

    return BestTokenEval, BestToken
end

function TokenManager.getFlowerTile(pos)
    local flowers = workspace:FindFirstChild("Flowers")
    if not flowers then return nil end
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = { flowers }
    rayParams.FilterType = Enum.RaycastFilterType.Include
    local result = workspace:Raycast(pos + Vector3.new(0, 5, 0), Vector3.new(0, -30, 0), rayParams)
    if result and result.Instance then
        return result.Instance
    end
    return nil
end

function TokenManager.getRandomFieldPosition(fieldName)
    local character = plr.Character
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local tile = TokenManager.getFlowerTile(hrp.Position)
    if tile then
        local parts = tile.Name:split("-")
        if #parts >= 3 then
            local field = parts[1]
            local x = tonumber(parts[2])
            local y = tonumber(parts[3])
            if x and y then
                local flowers = workspace:FindFirstChild("Flowers")
                if flowers then
                    local n = 4
                    for _ = 1, 10 do
                        local nx = math.random(x - n, x + n)
                        local ny = math.random(y - n, y + n)
                        local newTile = flowers:FindFirstChild(field .. "-" .. nx .. "-" .. ny)
                        if newTile then
                            return newTile.Position + Vector3.new(0, 2, 0)
                        end
                    end
                end
            end
        end
    end

    local zones = workspace:FindFirstChild("FlowerZones")
    if not zones then return nil end
    local zone = zones:FindFirstChild(fieldName)
    if not zone then return nil end
    local pos = zone.Position
    local size = zone.Size
    local rx = pos.X + math.random() * size.X - size.X / 2
    local rz = pos.Z + math.random() * size.Z - size.Z / 2
    return Vector3.new(rx, pos.Y + 3, rz)
end

game:GetService("ReplicatedStorage").Events.CollectibleEvent.OnClientEvent:Connect(function(action, data)
    if action == "Spawn" then
        if data.Permanent then return end
        local field = TokenManager.getFieldByPosition(data.Pos)
        if not field then return end

        local tokenType = TokenManager.EventTokenIdRef[data.Icon] or "Other"
        local tokenInfo = {
            Type = tokenType,
            ID = data.ID,
            Position = data.Pos,
            Dur = data.Dur,
            ClientStartTime = tick(),
            Field = field
        }

        if not TokenFolder[field] then TokenFolder[field] = {} end
        TokenFolder[field][data.ID] = tokenInfo
        TokenFolderID[data.ID] = tokenInfo
    elseif action == "Destroy" or action == "Collect" then
        local info = TokenFolderID[data.ID or data]
        if info and TokenFolder[info.Field] then
            TokenFolder[info.Field][data.ID or data] = nil
        end
    end
end)

function TokenManager.collectHiveTokens()
    local hive = HiveManager.GetPlayerHive()
    if not hive then return 0 end
    local spawnPos = hive:FindFirstChild("SpawnPos") and hive.SpawnPos.Value
    if not spawnPos then return 0 end
    local hivePos = spawnPos.Position

    local collectibles = workspace:FindFirstChild("Collectibles")
    if not collectibles then return 0 end

    local tokens = {}
    for _, obj in pairs(collectibles:GetChildren()) do
        if TokenManager.isToken(obj) and (obj.Position - hivePos).Magnitude <= 40 then
            table.insert(tokens, {
                obj      = obj,
                dist     = (obj.Position - hivePos).Magnitude,
                priority = TokenManager.isPriorityToken(obj),
            })
        end
    end

    table.sort(tokens, function(a, b)
        if a.priority ~= b.priority then return a.priority end
        return a.dist < b.dist
    end)

    local collected = 0
    for _, data in ipairs(tokens) do
        local obj = data.obj
        if obj.Parent and TokenManager.isToken(obj) then
            Tween.tweenTo(CFrame.new(obj.Position))
            collected += 1
            task.wait(0.1)
        end
    end
    return collected
end

local function getMaxBeeLevel()
    if HiveManager and HiveManager.getMaxBeeLevel then
        return HiveManager.getMaxBeeLevel()
    end
    return 0
end

local function getMonsterLevel(monster)
    if monster:FindFirstChild("Level") then
        return monster.Level.Value
    end

    local humanoid = monster:FindFirstChild("Humanoid")
    if humanoid then
        local hp = humanoid.MaxHealth

        if hp <= 20 then
            return 1
        elseif hp <= 50 then
            return 2
        elseif hp <= 100 then
            return 3
        elseif hp <= 200 then
            return 4
        elseif hp <= 500 then
            return 5
        elseif hp <= 1000 then
            return 6
        elseif hp <= 2000 then
            return 7
        elseif hp <= 5000 then
            return 8
        else
            return 9
        end
    end

    return 1
end

function MobManager.canFight(monsterLevel)
    return getMaxBeeLevel() >= monsterLevel
end

function MobManager.shouldEngage(monster)
    if not monster then return false end
    if not monster:FindFirstChild("Humanoid") then return false end
    if monster.Humanoid.Health <= 0 then return false end

    local level = getMonsterLevel(monster)
    return MobManager.canFight(level)
end

function MobManager.scanNearby(range)
    range = range or Config.MobDetectRange

    local character = plr.Character
    if not character then return nil end

    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local monsters = workspace:FindFirstChild("Monsters")
    if not monsters then return nil end

    for _, monster in pairs(monsters:GetChildren()) do
        if monster:FindFirstChild("Humanoid")
            and monster.Humanoid.Health > 0 then
            local dist = (monster:GetPivot().Position - root.Position).Magnitude
            if dist <= range then
                if MobManager.shouldEngage(monster) then
                    return monster
                end
            end
        end
    end
    return nil
end

task.spawn(function()
    Config.CurrentAction = "Claiming hive..."
    HiveManager.claimHive()
    Config.CurrentAction = "Starting quest loop..."
    Quest.run()
end)

task.spawn(function()
    while true do
        if Config.EnableAutoSell and AutoDig.isBackpackFull() then
            SellManager.sell()
        end
        TokenManager.collectHiveTokens()
        task.wait(5)
    end
end)

TokenManager._walkTarget = nil
TokenManager._walkTargetTime = 0

task.spawn(function()
    while task.wait(0.1) do
        if not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") then continue end
        if SellManager and SellManager.isSelling then continue end
        local currentField = Config.FarmField
        if not currentField then continue end
        if AutoDig and AutoDig.isBackpackFull() then continue end

        local root = plr.Character.HumanoidRootPart
        local humanoid = plr.Character:FindFirstChildOfClass("Humanoid")
        if not humanoid then continue end

        local zones = workspace:FindFirstChild("FlowerZones")
        local zone = zones and zones:FindFirstChild(currentField)
        if zone then
            local dist = (root.Position - zone.Position).Magnitude
            local fieldRadius = math.max(zone.Size.X, zone.Size.Z) / 2 + 20
            if dist > fieldRadius then continue end
        end

        AutoDig.dig()

        if Config.EnableMobAvoidance and MobManager.isMobNearby() then
            humanoid.Jump = true
        end

        local needNewTarget = false
        if not TokenManager._walkTarget then
            needNewTarget = true
        elseif (root.Position - TokenManager._walkTarget).Magnitude < 4 then
            needNewTarget = true
        elseif tick() - TokenManager._walkTargetTime > 3 then
            needNewTarget = true
        end

        if needNewTarget then
            local tokensInField = TokenFolder[currentField]
            if tokensInField and next(tokensInField) then
                local _, best = TokenManager.tokenMinimax(tokensInField, {
                    CollectedToken = {},
                    Speed = humanoid.WalkSpeed,
                    Position = root.Position,
                    Point = 0
                }, 3)
                if best then
                    Config.CurrentAction = "Collecting " .. (best.Type or "token") .. " in " .. currentField .. "..."
                    TokenManager._walkTarget = best.Position
                    TokenManager._walkTargetTime = tick()
                end
            end

            if not TokenManager._walkTarget or (root.Position - TokenManager._walkTarget).Magnitude < 4 then
                local rndPos = TokenManager.getRandomFieldPosition(currentField)
                if rndPos then
                    Config.CurrentAction = "Farming at " .. currentField .. "..."
                    TokenManager._walkTarget = rndPos
                    TokenManager._walkTargetTime = tick()
                end
            end
        end

        if TokenManager._walkTarget then
            humanoid:MoveTo(TokenManager._walkTarget)
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            local KUI = getgenv().KaiTunUI
            if not KUI then return end

            pcall(function()
                local bees = HiveManager.GetBee()
                getgenv().KaiTunBeeCount = #bees
            end)

            local mbQuest = Quest and Quest.getCurrentQuestOf and Quest.getCurrentQuestOf("Mother Bear")
            if mbQuest then
                local progress = Quest.getQuestProgress(mbQuest)
                if progress and #progress.tasks > 0 then
                    local totalPercent = 0
                    for _, t in ipairs(progress.tasks) do
                        totalPercent = totalPercent + t.percent
                    end
                    KUI.SetProgress(totalPercent / (#progress.tasks * 100))
                end
            else
                KUI.SetProgress(0)
            end

            KUI.SetMainTask(Config.CurrentAction or "Idling...")
        end)
    end
end)
