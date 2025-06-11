local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Fluent " .. Fluent.Version,
    SubTitle = "by dawid",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true, -- The blur may be detectable, setting this to false disables blur entirely
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl -- Used when theres no MinimizeKeybind
})

--Fluent provides Lucide Icons https://lucide.dev/icons/ for the tabs, icons are optional
local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "" }),
}

local Options = Fluent.Options

do

   -- Tham chiếu thư viện và player
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CollectController = require(ReplicatedStorage.Modules.CollectController)
local LocalPlayer = Players.LocalPlayer

-- Biến kiểm soát thu hoạch
local pickup_enabled = false
local farm_model

-- Tạo Toggle UI (giả sử bạn dùng Fluent UI hoặc tương tự)
local Toggle = Tabs.Main:AddToggle("MyToggle", {Title = "Collect", Default = false})

-- Hàm tìm farm của player
local function findPlayerFarm()
    for _, descendant in next, Workspace:FindFirstChild("Farm"):GetDescendants() do
        if descendant.Name == "Owner" and descendant.Value == LocalPlayer.Name then
            return descendant.Parent and descendant.Parent.Parent
        end
    end
end

-- Hàm thu hoạch
local function startCollecting()
    CollectController._lastCollected = 0
    CollectController._holding = true
    CollectController:_updateButtonState()

    farm_model = findPlayerFarm()

    if not farm_model then return end

    -- Teleport nhân vật đến farm
    local farmRoot = farm_model:FindFirstChild("Farmhouse") or farm_model:FindFirstChildWhichIsA("BasePart")
    if farmRoot and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.CFrame = farmRoot.CFrame + Vector3.new(0, 5, 0)
    end

    task.spawn(function()
        while pickup_enabled and farm_model do
            local plants_folder = farm_model:FindFirstChild("Plants_Physical")
            if plants_folder then
                for _, plant_model in next, plants_folder:GetChildren() do
                    if plant_model:IsA("Model") then
                        CollectController._lastCollected = 0
                        CollectController:_updateButtonState()
                        CollectController:Collect(plant_model)

                        for _, object in next, plant_model:GetDescendants() do
                            CollectController._lastCollected = 0
                            CollectController:_updateButtonState()
                            CollectController:Collect(object)
                            task.wait(0.01)
                        end
                    end
                end
            end
            task.wait(0.1)
        end
    end)
end

-- Bắt sự kiện khi toggle thay đổi
Toggle:OnChanged(function()
    pickup_enabled = Options.MyToggle.Value
    print("Toggle changed:", pickup_enabled)

    if pickup_enabled then
        startCollecting()
    end
end)

-- Đảm bảo tắt thu hoạch khi khởi đầu
Options.MyToggle:SetValue(false)


    local Keybind = Tabs.Main:AddKeybind("Keybind", {
        Title = "KeyBind",
        Mode = "Toggle", -- Always, Toggle, Hold
        Default = "LeftControl", -- String as the name of the keybind (MB1, MB2 for mouse buttons)

        -- Occurs when the keybind is clicked, Value is `true`/`false`
        Callback = function(Value)
            print("Keybind clicked!", Value)
        end,

        -- Occurs when the keybind itself is changed, `New` is a KeyCode Enum OR a UserInputType Enum
        ChangedCallback = function(New)
            print("Keybind changed!", New)
        end
    })

    -- OnClick is only fired when you press the keybind and the mode is Toggle
    -- Otherwise, you will have to use Keybind:GetState()
    Keybind:OnClick(function()
        print("Keybind clicked:", Keybind:GetState())
    end)

    Keybind:OnChanged(function()
        print("Keybind changed:", Keybind.Value)
    end)

    task.spawn(function()
        while true do
            wait(1)

            -- example for checking if a keybind is being pressed
            local state = Keybind:GetState()
            if state then
                print("Keybind is being held down")
            end

            if Fluent.Unloaded then break end
        end
    end)

    Keybind:SetValue("MB2", "Toggle") -- Sets keybind to MB2, mode to Hold


    local Input = Tabs.Main:AddInput("Input", {
        Title = "Input",
        Default = "Default",
        Placeholder = "Placeholder",
        Numeric = false, -- Only allows numbers
        Finished = false, -- Only calls callback when you press enter
        Callback = function(Value)
            print("Input changed:", Value)
        end
    })

    Input:OnChanged(function()
        print("Input updated:", Input.Value)
    end)
end


-- Addons:
-- SaveManager (Allows you to have a configuration system)
-- InterfaceManager (Allows you to have a interface managment system)

-- Hand the library over to our managers
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

-- Ignore keys that are used by ThemeManager.
-- (we dont want configs to save themes, do we?)
SaveManager:IgnoreThemeSettings()

-- You can add indexes of elements the save manager should ignore
SaveManager:SetIgnoreIndexes({})

-- use case for doing it this way:
-- a script hub could have themes in a global folder
-- and game configs in a separate folder per game
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/specific-game")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)


Window:SelectTab(1)

Fluent:Notify({
    Title = "Fluent",
    Content = "The script has been loaded.",
    Duration = 8
})

-- You can use the SaveManager:LoadAutoloadConfig() to load a config
-- which has been marked to be one that auto loads!
SaveManager:LoadAutoloadConfig()
