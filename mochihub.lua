local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Mochi Hub " .. Fluent.Version,
    SubTitle = "By Him",
    TabWidth = 160,
    Size = UDim2.fromOffset(520, 400),
    Acrylic = true, -- The blur may be detectable, setting this to false disables blur entirely
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl -- Used when theres no MinimizeKeybind
})

--Fluent provides Lucide Icons https://lucide.dev/icons/ for the tabs, icons are optional
local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "" }),
    Gun = Window:AddTab({ Title = "Gun", Icon = "" }),
    Item = Window:AddTab({ Title = "Item", Icon = "" }),
    ESP = Window:AddTab({ Title = "ESP", Icon = "" }),
}

local Options = Fluent.Options

do
    Fluent:Notify({
        Title = "Notification",
        Content = "This is a notification",
        SubContent = "SubContent", -- Optional
        Duration = 5 -- Set to nil to make the notification not disappear
    })




    local Toggle = Tabs.Main:AddToggle("MyToggle", {Title = "Attack", Default = false })

    Toggle:OnChanged(function()
        print("Toggle changed:", Options.MyToggle.Value)
    end)

    Options.MyToggle:SetValue(false)





    -- Thêm toggle vào UI (có thể là từ một framework UI như `Tabs`)
local Toggle = Tabs.Item:AddToggle("MyToggle", {Title = "Sack", Default = false})

-- Lấy tham chiếu tới LocalPlayer
local player = game:GetService("Players")
local LocalPlayer = player.LocalPlayer

-- Hàm trang bị item "Sack"
local equipitem = function(v)
    -- Kiểm tra xem item có tồn tại trong Backpack không
    local tool = LocalPlayer.Backpack:FindFirstChild(v)
    if tool then
        -- Nếu tồn tại, trang bị item cho nhân vật
        LocalPlayer.Character.Humanoid:EquipTool(tool)
        print(v .. " đã được trang bị!")
    else
        warn(v .. " không tồn tại trong Backpack!")
    end
end

-- Hàm để tháo bỏ item (Sack)
local unequipitem = function(v)
    -- Kiểm tra nếu item đang được trang bị
    local tool = LocalPlayer.Character:FindFirstChild(v)
    if tool then
        -- Nếu có, tháo item khỏi nhân vật
        tool.Parent = LocalPlayer.Backpack  -- Đưa item lại vào Backpack
        print(v .. " đã được tháo!")
    else
        print(v .. " không được trang bị!")
    end
end

-- Biến lưu trạng thái của Toggle
local isEquipping = false

-- Lắng nghe sự thay đổi trạng thái của toggle
Toggle:OnChanged(function()
    if Toggle.Value then
        -- Nếu toggle bật, trang bị item
        print("Toggle bật: Trang bị Sack")
        isEquipping = true
        -- Liên tục trang bị item nếu toggle bật
        task.spawn(function()
            while isEquipping do
                equipitem("Sack")
                task.wait(1)  -- Đợi 1 giây trước khi kiểm tra lại
            end
        end)
    else
        -- Nếu toggle tắt, ngừng trang bị item và tháo item ra
        print("Toggle tắt: Ngừng trang bị Sack")
        isEquipping = false
        unequipitem("Sack")  -- Tháo item khi toggle tắt
    end
end)



    local Toggle = Tabs.ESP:AddToggle("MyToggle", {Title = "Item", Default = false })

    Toggle:OnChanged(function()
        print("Toggle changed:", Options.MyToggle.Value)
    end)

    Options.MyToggle:SetValue(false)




    -- Function to equip item (like "Revolver")
local player = game:GetService("Players")
local LocalPlayer = player.LocalPlayer  -- Ensure accessing the correct player

-- Variable to track if the item is already equipped
local hasEquipped = false

-- Function to equip a weapon (tool) to the character
equipitem = function(v)
    -- Check if the tool exists in the Backpack
    local tool = LocalPlayer.Backpack:FindFirstChild(v)
    if tool then
        -- If the tool exists, equip it to the character
        LocalPlayer.Character.Humanoid:EquipTool(tool)
        print(v .. " đã được trang bị!")
        hasEquipped = true  -- Mark that the item has been equipped
    else
        warn(v .. " không tồn tại trong Backpack!")
    end
end

-- Function to unequip a weapon (tool) from the character
unequipitem = function(v)
    -- Check if the item is equipped
    local tool = LocalPlayer.Character:FindFirstChild(v)
    if tool then
        -- If the tool exists, unequip it
        tool.Parent = LocalPlayer.Backpack  -- Put the tool back in the backpack
        print(v .. " đã bị tháo!")
        hasEquipped = false  -- Mark that the item has been unequipped
    else
        warn(v .. " không được trang bị!")
    end
end

-- Create a Toggle to choose whether to equip or unequip the item
local Toggle = Tabs.Gun:AddToggle("MyToggle", {Title = "Revolver", Default = false })

-- Lắng nghe sự thay đổi của toggle
Toggle:OnChanged(function()
    if Toggle.Value then
        -- If toggle is on, equip the item
        print("Toggle bật: Cầm súng")
        if not hasEquipped then
            equipitem("Revolver")  -- Equip "Revolver"
        end
    else
        -- If toggle is off, unequip the item
        print("Toggle tắt: Tháo súng")
        if hasEquipped then
            unequipitem("Revolver")  -- Unequip "Revolver"
        end
    end
end)

-- Optionally, you can set the default value for the toggle (Ensure this line works with your UI framework)
if Options.MyToggle then
    Options.MyToggle:SetValue(false)  -- Set the default value to false (toggle off)
else
    warn("Options.MyToggle không tồn tại!")
end


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
