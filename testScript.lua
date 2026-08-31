local getgenv = getgenv or function() return shared end
local OstiumEnv = getgenv()
if OstiumEnv.OstiumLoaded then
    return warn("Ostium is already loaded.")
end
OstiumEnv.OstiumLoaded = true

local OSTIUM_VERSION = "v4"
local OSTIUM_ICON = 117198211193045
local OSTIUM_DISCORD = "https://discord.gg/9UuswyPTDE"
local OSTIUM_WEBSITE = "https://discord.gg/9UuswyPTDE"
local StartClock = os.clock()

local OBSIDIAN_REPO = "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/"
local VELOESP_URL = "https://raw.githubusercontent.com/DasVelocity/VeloESP/refs/heads/main/VeloESP.lua"

local ObsidianLibrary = loadstring(game:HttpGet(OBSIDIAN_REPO .. "Library.lua"))()
local ObsidianThemeManager = loadstring(game:HttpGet(OBSIDIAN_REPO .. "addons/ThemeManager.lua"))()
local ObsidianSaveManager = loadstring(game:HttpGet(OBSIDIAN_REPO .. "addons/SaveManager.lua"))()

ObsidianLibrary.NotifyOnError = true
ObsidianLibrary.ShowToggleFrameInKeybinds = true

local toclipboard = toclipboard or setclipboard or function() end
local _cloneref = cloneref or clonereference or function(Object) return Object end
local _gethui = gethui or function() return game:GetService("CoreGui") end
local _newcclosure = newcclosure or function(Function) return Function end

local Loading
local function SetLoadingStep(Step, Message, Description)
    if not Loading then return end
    pcall(function()
        Loading:SetCurrentStep(Step)
        if Message then Loading:SetMessage(Message) end
        if Description then Loading:SetDescription(Description) end
    end)
end

do
    local Ok, Result = pcall(function()
        return ObsidianLibrary:CreateLoading({
            Title = "Ostium",
            Icon = OSTIUM_ICON,
            LoadingIcon = "loader-circle",
            LoadingIconTweenTime = 1.1,
            LoadingIconColor = Color3.fromRGB(0, 204, 255),
            CurrentStep = 0,
            TotalSteps = 5,
            ShowSidebar = true,
            AutoResizeHeight = true,
            AlwaysOnTop = true,
        })
    end)
    if Ok then
        Loading = Result
        pcall(function()
            Loading:SetMessage("Starting Ostium")
            Loading:SetDescription("Fetching the interface and ESP library...")
            Loading:ShowSidebarPage(true)
            Loading.Sidebar:AddLabel("Player: " .. game:GetService("Players").LocalPlayer.Name)
            Loading.Sidebar:AddLabel("Version: " .. OSTIUM_VERSION)
        end)
    end
end

SetLoadingStep(1, "Loading ESP library", "Downloading the VeloESP renderer...")

local VeloESP = loadstring(game:HttpGet(VELOESP_URL .. "?cachebust=" .. tostring(os.time())))()

local function BuildESPAdapter()
    local Adapter = {}
    Adapter.ColorTable = setmetatable({}, { __mode = "k" })

    local Handles = setmetatable({}, { __mode = "k" })
    local Defaults = {
        FillTransparency = 0.75,
        OutlineTransparency = 0,
        TextTransparency = 0,
        TextOutlineTransparency = 0,
        MaxDistance = 240,
        TextSize = 20,
        FadeTime = 0.25,
        FadeSpeed = 4,
        TracerThickness = 0.75,
        TracerFrom = "Bottom",
        ArrowRadius = 250,
        ArrowMargin = 28,
    }

    VeloESP.Configure({
        Rainbow = false,
        Distance = true,
        Tracers = false,
        Arrows = false,
        EdgeBeacons = false,
        Font = Enum.Font.Highway,
        UpdateRate = 0,
        NearUpdateRate = 0,
        FarUpdateRate = 0.12,
        FarDistance = 450,
        MaxPerFrame = 90,
        FrameBudget = 1 / 360,
        BudgetCheckInterval = 8,
    })

    local function ForEachHandle(Callback)
        for _, Handle in Handles do
            if Handle and not Handle.Deleted then
                pcall(Callback, Handle)
            end
        end
    end

    function Adapter:GenerateRandomString(Length)
        Length = Length or 16
        local Chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        local Result = table.create(Length)
        for Index = 1, Length do
            local At = math.random(1, #Chars)
            Result[Index] = Chars:sub(At, At)
        end
        return table.concat(Result)
    end

    function Adapter:AddESP(Info)
        if typeof(Info) ~= "table" then return end
        local Object = Info.Object
        if typeof(Object) ~= "Instance" or not Object.Parent then return end

        local Color = Info.Color or Color3.new(1, 1, 1)
        self.ColorTable[Object] = Color

        local Existing = Handles[Object]
        if Existing and not Existing.Deleted then
            Existing:Set({
                Name = tostring(Info.Text or Existing.CurrentSettings.Name),
                Color = Color,
                FillColor = Color,
                OutlineColor = Color,
                SurfaceColor = Color,
                TextTransparency = Defaults.TextTransparency,
                TextStrokeTransparency = Defaults.TextOutlineTransparency,
            })
            Existing:SetEveryColor(Color, true)
            return Existing
        end

        local Ok, Handle = pcall(function()
            return VeloESP:Add({
                Name = tostring(Info.Text or Object.Name),
                Model = Object,
                ESPType = "Highlight",
                Color = Color,
                FillColor = Color,
                OutlineColor = Color,
                SurfaceColor = Color,
                FillTransparency = Defaults.FillTransparency,
                OutlineTransparency = Defaults.OutlineTransparency,
                TextTransparency = Defaults.TextTransparency,
                TextStrokeTransparency = Defaults.TextOutlineTransparency,
                TextSize = Defaults.TextSize,
                MaxDistance = Defaults.MaxDistance,
                Fade = { Enabled = Defaults.FadeTime > 0, Speed = Defaults.FadeSpeed, OutSpeed = Defaults.FadeSpeed },
                Tracer = { Enabled = true, Color = Color, Thickness = Defaults.TracerThickness, Transparency = Defaults.TextTransparency, From = Defaults.TracerFrom },
                EdgeBeacon = { Enabled = true, Color = Color, Margin = Defaults.ArrowMargin, Length = 42, DotSize = 10, Pulse = false, Label = true, Distance = true },
                OnDestroyFunc = function()
                    Handles[Object] = nil
                    Adapter.ColorTable[Object] = nil
                end,
            })
        end)

        if not Ok or not Handle then return end
        Handles[Object] = Handle

        Object.Destroying:Once(function()
            Adapter:RemoveESP(Object)
        end)

        return Handle
    end

    function Adapter:RemoveESP(Object)
        local Handle = Handles[Object]
        Handles[Object] = nil
        self.ColorTable[Object] = nil
        if Handle and not Handle.Deleted then
            pcall(function() Handle:Destroy() end)
        end
    end

    function Adapter:UpdateObjectColor(Object, Color)
        self.ColorTable[Object] = Color
        local Handle = Handles[Object]
        if Handle and not Handle.Deleted then
            Handle:SetEveryColor(Color, true)
        end
    end

    function Adapter:UpdateObjectText(Object, Text)
        local Handle = Handles[Object]
        if Handle and not Handle.Deleted then
            Handle:Set({ Name = tostring(Text) })
        end
    end

    function Adapter:SetRainbow(Value) VeloESP.GlobalConfig.Rainbow = Value == true end
    function Adapter:SetShowDistance(Value) VeloESP.GlobalConfig.Distance = Value == true end

    function Adapter:SetFillTransparency(Value)
        Defaults.FillTransparency = math.clamp(tonumber(Value) or 0.75, 0, 1)
        ForEachHandle(function(Handle) Handle:Set({ FillTransparency = Defaults.FillTransparency }) end)
    end
    function Adapter:SetOutlineTransparency(Value)
        Defaults.OutlineTransparency = math.clamp(tonumber(Value) or 0, 0, 1)
        ForEachHandle(function(Handle) Handle:Set({ OutlineTransparency = Defaults.OutlineTransparency }) end)
    end
    function Adapter:SetTextTransparency(Value)
        Defaults.TextTransparency = math.clamp(tonumber(Value) or 0, 0, 1)
        ForEachHandle(function(Handle)
            Handle:Set({
                TextTransparency = Defaults.TextTransparency,
                Tracer = { Transparency = Defaults.TextTransparency },
            })
        end)
    end
    function Adapter:SetTextOutlineTransparency(Value)
        Defaults.TextOutlineTransparency = math.clamp(tonumber(Value) or 0, 0, 1)
        ForEachHandle(function(Handle) Handle:Set({ TextStrokeTransparency = Defaults.TextOutlineTransparency }) end)
    end

    function Adapter:SetRenderLimit(Value)
        Defaults.MaxDistance = math.max(1, tonumber(Value) or 240)
        ForEachHandle(function(Handle) Handle:Set({ MaxDistance = Defaults.MaxDistance }) end)
    end
    function Adapter:SetFadeTime(Value)
        Defaults.FadeTime = math.clamp(tonumber(Value) or 0, 0, 1)
        Defaults.FadeSpeed = Defaults.FadeTime > 0 and math.max(1, 1 / Defaults.FadeTime) or 0
        ForEachHandle(function(Handle)
            Handle:Set({ Fade = { Enabled = Defaults.FadeTime > 0, Speed = Defaults.FadeSpeed, OutSpeed = Defaults.FadeSpeed } })
        end)
    end

    function Adapter:SetTextSize(Value)
        Defaults.TextSize = math.max(1, tonumber(Value) or 20)
        ForEachHandle(function(Handle) Handle:Set({ TextSize = Defaults.TextSize }) end)
    end
    function Adapter:SetFont(Value)
        if typeof(Value) == "EnumItem" then
            VeloESP.GlobalConfig.Font = Value
            ForEachHandle(function(Handle) Handle:Set({ Font = Value }) end)
        end
    end

    function Adapter:SetTracers(Value) VeloESP.GlobalConfig.Tracers = Value == true end
    function Adapter:SetTracerSize(Value)
        Defaults.TracerThickness = math.max(0.1, tonumber(Value) or 0.75)
        ForEachHandle(function(Handle)
            Handle:Set({ Tracer = { Thickness = Defaults.TracerThickness } })
        end)
    end
    function Adapter:SetTracerOrigin(Value)
        Defaults.TracerFrom = tostring(Value or "Bottom")
        ForEachHandle(function(Handle)
            Handle:Set({ Tracer = { From = Defaults.TracerFrom } })
        end)
    end

    function Adapter:SetArrows(Value)
        local Enabled = Value == true
        VeloESP.GlobalConfig.Arrows = Enabled
        VeloESP.GlobalConfig.EdgeBeacons = Enabled
    end
    function Adapter:SetArrowRadius(Value)
        Defaults.ArrowRadius = math.max(25, tonumber(Value) or 250)
        Defaults.ArrowMargin = math.max(12, math.floor(Defaults.ArrowRadius / 9))
        ForEachHandle(function(Handle)
            Handle:Set({ EdgeBeacon = { Margin = Defaults.ArrowMargin } })
        end)
    end
    function Adapter:SetDistanceSizeRatio() end

    function Adapter:ObserveGenerated(RootObject, Options)
        return VeloESP.ObserveGenerated(RootObject, Options)
    end

    function Adapter:Observe(RootObject, Options)
        return VeloESP.ObserveGenerated(RootObject, Options)
    end

    function Adapter:WatchGenerated(RootObject, Options)
        return VeloESP.ObserveGenerated(RootObject, Options)
    end

    function Adapter:Unload()
        pcall(function() VeloESP.Destroy() end)
    end

    return Adapter
end

local Ostium = {
    SavePath = "Ostium/Doors",
    Environment = {
        cloneref = _cloneref,
        gethui = _gethui,
        getconnections = getconnections,
        firesignal = firesignal,
        replicatesignal = replicatesignal,
        fireproximityprompt = fireproximityprompt,
        firetouchinterest = firetouchinterest,
        hookmetamethod = hookmetamethod,
        getnamecallmethod = getnamecallmethod,
        newcclosure = _newcclosure,
        isnetworkowner = isnetworkowner,
        require = require,
    },
    ESPLibrary = BuildESPAdapter(),
    Internal = {
        Library = ObsidianLibrary,
        SaveManager = ObsidianSaveManager,
        ThemeManager = ObsidianThemeManager,
    },
}

getgenv().__o = Ostium







Ostium.Key = {
    Value  = "iLoveOstium",
    Folder = "Ostium",
    Path   = "Ostium/ostium_key.json",
}

function Ostium.Key:Read()
    if isfile and readfile and isfile(self.Path) then
        local Ok, Data = pcall(function()
            return game:GetService("HttpService"):JSONDecode(readfile(self.Path))
        end)
        if Ok and typeof(Data) == "table" then return Data.key end
    end
    return nil
end

function Ostium.Key:Save()
    if not writefile then return end
    pcall(function()
        if isfolder and makefolder and not isfolder(self.Folder) then makefolder(self.Folder) end
        writefile(self.Path, game:GetService("HttpService"):JSONEncode({ key = self.Value, at = os.time() }))
    end)
end

function Ostium.Key:IsUnlocked()
    return self:Read() == self.Value
end







function Ostium.Key:GateTab(Window)
    if self:IsUnlocked() then return nil end

    
    
    
    if Loading then
        pcall(function() Loading:Continue() end)
        Loading = nil
    end

    local Key = self
    local Verified = false
    local EnteredKey = ""
    local function NormalizeKey(Value)
        Value = tostring(Value or "")
        return (Value:gsub("^%s+", ""):gsub("%s+$", ""))
    end
    local function IsValidKey(Value)
        return NormalizeKey(Value) == NormalizeKey(Key.Value)
    end

    local KeyTab = Window:AddTab("Key", "lock")
    local Group = Ostium.Internal.WrapUIContainer(KeyTab:AddLeftGroupbox("Verification"))
    Group:AddLabel({
        Text = "Ostium is locked. Enter your key to unlock the menu. The key is pinned in our Discord server.",
        DoesWrap = true,
    })
    Group:AddDivider()

    local KeyInput = Group:AddInput("OstiumKeyInput", {
        Text = "Key",
        Default = "",
        Placeholder = "Paste your key here...",
        Finished = false,
        ClearTextOnFocus = false,
        Callback = function(Value)
            EnteredKey = tostring(Value or "")
            if IsValidKey(Value) then
                Key:Save()
                Verified = true
            end
        end,
    })

    Group:AddButton({
        Text = "Copy Discord",
        Func = function()
            toclipboard(OSTIUM_DISCORD)
            ObsidianLibrary:Notify("Discord link copied to your clipboard.")
        end,
    })
    Group:AddButton({
        Text = "Check Key",
        Func = function()
            local CurrentValue = EnteredKey
            if not IsValidKey(CurrentValue) and KeyInput.GetValue then
                local Ok, Value = pcall(function()
                    return KeyInput:GetValue()
                end)
                if Ok then
                    CurrentValue = Value
                end
            end
            if not IsValidKey(CurrentValue) then
                CurrentValue = KeyInput.Value
            end

            if IsValidKey(CurrentValue) then
                Key:Save()
                ObsidianLibrary:Notify("Key accepted. Unlocking Ostium...")
                Verified = true
            else
                ObsidianLibrary:Notify("Invalid key. Check the Discord for the correct key.")
                KeyInput:SetValue("")
            end
        end,
    })

    repeat task.wait() until Verified
    return KeyTab
end



function Ostium.Key:FinishGate(KeyTab, FirstTab)
    if not KeyTab then return end
    pcall(function() KeyTab:Destroy() end)
    if FirstTab then pcall(function() FirstTab:Show() end) end
end

local function ReadExecutionCount()
    local Path = "Ostium/ostium_executions.json"
    local Count = 0
    if isfile and readfile and isfile(Path) then
        local Ok, Data = pcall(function()
            return game:GetService("HttpService"):JSONDecode(readfile(Path))
        end)
        if Ok and Data and Data.count then Count = Data.count end
    end
    Count += 1
    if writefile then
        pcall(function()
            if isfolder and makefolder and not isfolder("Ostium") then makefolder("Ostium") end
            writefile(Path, game:GetService("HttpService"):JSONEncode({ count = Count }))
        end)
    end
    return Count
end

function Ostium.Internal.RenderStartPane(Window)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    local HomeTab = Window:AddTab("Home", "house")
    local Welcome = Ostium.Internal.WrapUIContainer(HomeTab:AddLeftGroupbox("Welcome"))

    local Avatar = Welcome:AddImage("AvatarThumbnail", { Image = "rbxassetid://0" })
    task.spawn(function()
        local Ok, Thumbnail = pcall(function()
            return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size180x180)
        end)
        if Ok and Thumbnail then Avatar:SetImage(Thumbnail) end
    end)

    local Hour = os.date("*t").hour
    local Greeting = (Hour < 12 and Hour >= 5 and "Good morning")
        or (Hour < 17 and "Good afternoon")
        or (Hour < 21 and "Good evening")
        or "Good night"
    Welcome:AddLabel(Greeting .. ", " .. LocalPlayer.Name)
    Welcome:AddDivider()
    Welcome:AddButton({
        Text = "Join Discord",
        Func = function()
            toclipboard(OSTIUM_DISCORD)
            ObsidianLibrary:Notify("Discord link copied to your clipboard.")
        end,
    })
    Welcome:AddButton({
        Text = "Website",
        Func = function()
            toclipboard(OSTIUM_WEBSITE)
            ObsidianLibrary:Notify("Website link copied to your clipboard.")
        end,
    })

    HomeTab:UpdateWarningBox({
        Title = "Ostium " .. OSTIUM_VERSION,
        Text = table.concat({
            '<font color="rgb(255, 85, 85)">Release ' .. OSTIUM_VERSION .. '</font>',
            "",
            '<font color="rgb(255, 255, 255)">Latest changes</font>',
            '- <font color="rgb(0, 255, 0)">Rebuilt every system from the ground up</font>',
            '- <font color="rgb(0, 255, 0)">Brand new ESP powered by the VeloESP renderer</font>',
            '- <font color="rgb(0, 255, 0)">Floor-incompatible features now disable themselves</font>',
            '- <font color="rgb(0, 255, 0)">Reorganized the whole interface for speed</font>',
        }, "\n"),
        IsNormal = true,
        Visible = true,
        LockSize = true,
    })

    local Status = Ostium.Internal.WrapUIContainer(HomeTab:AddRightGroupbox("Executors"))
    Status:AddLabel('<font color="rgb(255,85,85)">Total Executions: ' .. ReadExecutionCount() .. '</font>')
    Status:AddDivider()
    for _, Name in { "Volt", "Wave", "Potassium", "Synapse Z", "Real", "Madium", "Vortex", "Solara", "Xeno" } do
        Status:AddLabel('<font color="rgb(255,85,85)">🟢 ' .. Name .. '</font>')
    end

    return HomeTab
end

function Ostium.Internal.RenderConfigPane(Window)
    local Options = ObsidianLibrary.Options
    local CurrentFloor = tostring(game:GetService("ReplicatedStorage"):WaitForChild("GameData"):WaitForChild("Floor").Value)

    local SettingsTab = Window:AddTab("Config", "settings")
    local Menu = Ostium.Internal.WrapUIContainer(SettingsTab:AddLeftGroupbox("Interface"))

    Menu:AddToggle("ShowCustomCursor", {
        Text = "Custom Cursor",
        Default = ObsidianLibrary.ShowCustomCursor,
        Callback = function(Value) ObsidianLibrary.ShowCustomCursor = Value end,
    })
    Menu:AddDropdown("NotificationSide", {
        Text = "Notification Side",
        Values = { "Left", "Right" },
        Default = "Right",
        Callback = function(Value) ObsidianLibrary:SetNotifySide(Value) end,
    })
    Menu:AddDropdown("DPIScale", {
        Text = "DPI Scale",
        Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
        Default = "100%",
        Callback = function(Value)
            local Scale = tonumber((Value or "100%"):gsub("%%", ""))
            if Scale and ObsidianLibrary.SetDPIScale then ObsidianLibrary:SetDPIScale(Scale) end
        end,
    })
    Menu:AddDivider()
    Menu:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
        Default = "RightShift",
        NoUI = true,
        Text = "Menu keybind",
    })
    Menu:AddButton({
        Text = "Unload",
        DoubleClick = false,
        Func = function() ObsidianLibrary:Unload() end,
    })

    ObsidianLibrary.ToggleKeybind = Options.MenuKeybind

    ObsidianThemeManager:SetLibrary(ObsidianLibrary)
    ObsidianSaveManager:SetLibrary(ObsidianLibrary)
    ObsidianSaveManager:IgnoreThemeSettings()
    ObsidianSaveManager:SetIgnoreIndexes({ "MenuKeybind" })
    ObsidianThemeManager:SetFolder("Ostium")
    ObsidianSaveManager:SetFolder(Ostium.SavePath)
    if ObsidianSaveManager.SetSubFolder then
        ObsidianSaveManager:SetSubFolder(CurrentFloor)
    end
    ObsidianSaveManager:BuildConfigSection(SettingsTab)
    ObsidianThemeManager:ApplyToTab(SettingsTab)

    pcall(function() ObsidianSaveManager:LoadAutoloadConfig() end)

    local CreditsTab = Window:AddTab("Credits", "heart")
    local Team = Ostium.Internal.WrapUIContainer(CreditsTab:AddLeftGroupbox("The Team"))
    Team:AddLabel('<font color="rgb(255,85,85)"><b>Ostium</b></font>')
    Team:AddLabel('<font color="rgb(150,150,150)">#1 DOORS Mod Menu</font>')
    Team:AddDivider()
    Team:AddLabel('<font color="rgb(255,85,85)"><b>Owner &amp; Developer</b></font>')
    Team:AddLabel('Velocity', true)
    Team:AddDivider()
    Team:AddLabel('<font color="rgb(255,85,85)"><b>Special Thanks</b></font>')
    Team:AddLabel('koekis2  •  lekkie2', true)

    local About = Ostium.Internal.WrapUIContainer(CreditsTab:AddRightGroupbox("About"))
    About:AddLabel('<font color="rgb(120,120,120)">Version</font>   <b>' .. OSTIUM_VERSION .. '</b>')
    About:AddLabel('<font color="rgb(120,120,120)">ESP</font>   <b>VeloESP by Velocity</b>')
    About:AddLabel('<font color="rgb(120,120,120)">UI</font>   <b>Obsidian</b>')
    About:AddDivider()
    About:AddButton({
        Text = "Copy Discord Invite",
        Tooltip = "Join the community for updates and support.",
        Func = function()
            toclipboard(OSTIUM_DISCORD)
            ObsidianLibrary:Notify("Discord link copied to your clipboard.")
        end,
    })
    About:AddButton({
        Text = "Copy Website",
        Func = function()
            toclipboard(OSTIUM_WEBSITE)
            ObsidianLibrary:Notify("Website link copied to your clipboard.")
        end,
    })

    local AddonsTab = Window:AddTab("Addons", "plug")
    AddonsTab:UpdateWarningBox({
        Title = "Warning",
        Text = "Only load addons you trust. Downloaded scripts run with full access.",
        Visible = true,
        LockSize = true,
    })
    local AddonsGroup = Ostium.Internal.WrapUIContainer(AddonsTab:AddLeftGroupbox("Extensions"))
    Ostium.AddonsGroup = AddonsGroup

    if isfolder and makefolder and listfiles and readfile then
        if not isfolder("Ostium") then makefolder("Ostium") end
        if not isfolder("Ostium/Addons") then makefolder("Ostium/Addons") end
        local Any = false
        for _, File in listfiles("Ostium/Addons") do
            if File:sub(-4) == ".lua" or File:sub(-4) == ".txt" then
                Any = true
                pcall(function() loadstring(readfile(File))() end)
            end
        end
        if not Any then
            AddonsGroup:AddLabel({ Text = "Drop .lua or .txt files into the Ostium/Addons folder to load them here.", DoesWrap = true })
        end
    else
        AddonsGroup:AddLabel({ Text = "Local addons are unavailable because this executor has no filesystem access.", DoesWrap = true })
    end
end

local LoadStart = tick()
Ostium.SavePath = "Ostium/Doors"

local Library = Ostium.Internal.Library
local SaveManager = Ostium.Internal.SaveManager
local ThemeManager = Ostium.Internal.ThemeManager

local Toggles = Library.Toggles
local Options = Library.Options

local function CloneReference(Object)
	if Ostium and Ostium.Environment.cloneref then
		return Ostium.Environment.cloneref(Object)
	end
	return Object
end

local Services = setmetatable({}, {
	__index = function(Self, Name)
		return CloneReference(game:GetService(Name))
	end
})

local Globals = {}
local Connections = {}
local ESPConnections = {}
local Groupboxes = {}
local FakePrompts = {}
local Functions = {}
local PartProperties = {}

local FeatureConfig = {
	LadderSpeed = {
		Min = 0,
		Max = 100,
		Default = 35,
	},
	JumpBoost = {
		Min = 5,
		Max = 100,
		Default = 25,
	},
	Firedamp = {
		CameraEffects = {
			LiveFiredamp = true,
			LiveSantity = true,
		},
		OriginalModuleName = "Firedamp",
		DisabledModuleName = "_Firedamp",
	},
	Haste = {
		CameraEffectName = "LiveSanity",
		EntityName = "EntityModel",
	},
	Fog = {
		DestroyNames = {
			CaveAtmosphere = true,
			Caves = true,
		},
	},
	LibraryBruteforce = {
		MinGuessesPerSecond = 1,
		MaxGuessesPerSecond = 60,
		DefaultGuessesPerSecond = 10,
	},
	GlitchCube = {
		Attempts = 3,
		ManipulationDuration = 3,
		AttemptDelay = 1,
		DoorOffset = 2,
		OutsideMapOffset = Vector3.new(0, -250, 0),
	},
	MinecartPush = {
		ScanInterval = 1,
	},
	AntiJeff = {
		ScanInterval = 0.25,
	},
	DiscordCaption = {
		DelayMin = 60,
		DelayMax = 180,
		Duration = 7,
		Text = "join our discord, link is in the menu",
		Url = "https://raw.githubusercontent.com/RegularVynixu/DOORS-Captions/main/init.luau",
	},
}

Globals.LadderSpeedOverride = {
	Active = false,
	PreviousToggle = false,
	PreviousSpeed = 0,
}
Globals.GlitchCube = {
	Running = false,
	CancelRequested = false,
	PreviousVelocityManipulation = false,
}
Globals.RemovedLightingEffects = {}
Globals.RestoringLightingEffects = false

local Objects = {
	Prompts = {},
	Objectives = {},
	Doors = {},
	HidingSpots = {},
	Entities = {},
	SeekObstructions = {},
	Items = {},
	Chests = {},
	Currency = {},
	Ladders = {},
	VineDoors = {},
	MissingObjects = {},
	Obstructions = {},
	EventTriggers = {},
	Jeffs = {},
	JumpscareModules = {},
	SeekHighlights = {},
	EyestalkHighlights = {},
	SeekNodes = {},
	SeekDuckBoards = {},
	SeekBridges = {},
	PathLights = {}
}

Globals.IncompatibleMessage = "Your executor doesn't support this feature."

local ExecutorSupport = {
	Functions = {},
	Status = {},
	Tests = {},
	Features = {
		DisableIdleKick = { "getconnections" },
		AutoHeartbeatMinigame = { "hookmetamethod", "newcclosure", "getnamecallmethod" },
		BypassEyes = { "hookmetamethod", "newcclosure", "getnamecallmethod" },
		BypassLookman = { "hookmetamethod", "newcclosure", "getnamecallmethod" },
		PositionSpoof = { "hookmetamethod", "newcclosure", "getnamecallmethod" },
		CrouchSpoof = { "hookmetamethod", "newcclosure", "getnamecallmethod" },
		InfiniteItemsToggle = { "fireproximityprompt" },
		InfiniteItemsList = { "fireproximityprompt" },
		["Spawn Dread"] = { "require" },
		["Spawn A-90"] = { "firesignal" },
		["Spawn Screech"] = { "firesignal" },
		["Spawn Glitch"] = { "firesignal" },
		RemoveCameraShake = { "require" },
		RemoveCameraBobbing = { "require" },
		ViewmodelOffsetToggle = { "require" },
		ViewmodelOffsetX = { "require" },
		ViewmodelOffsetY = { "require" },
		ViewmodelOffsetZ = { "require" },
		DisableVoiceActing = { "debug.getupvalues", "debug.setupvalue" },
		AutoSteerMinecart = { "require" },
		AutoSteerMinecartTurnDistance = { "require" },
		AutoSteerMinecartDuckDistance = { "require" },
		AutoMinecartPush = { "fireproximityprompt" },
		RoomsAutoWalkSpoofFootsteps = { "hookmetamethod", "newcclosure", "getnamecallmethod" },
		RemoveSeekTrigger = { "firetouchinterest" },
		RemoveFigure = { "isnetworkowner" },
		["Complete Maze"] = { "fireproximityprompt" },
		KnobFarm = { "replicatesignal" },
		LobbyKnobFarm = { "queue_on_teleport", "writefile", "readfile", "fireproximityprompt", "replicatesignal" },
		KF_MinContainers = { "queue_on_teleport", "writefile", "readfile", "fireproximityprompt", "replicatesignal" },
		KF_MinCoins = { "queue_on_teleport", "writefile", "readfile", "fireproximityprompt", "replicatesignal" },
		KF_UseLockpick = { "queue_on_teleport", "writefile", "readfile", "fireproximityprompt", "replicatesignal" },
		KF_UseKnobBoost = { "queue_on_teleport", "writefile", "readfile", "fireproximityprompt", "replicatesignal" },
		["Death Farm"] = { "queue_on_teleport", "writefile", "readfile", "fireproximityprompt", "replicatesignal" },
		["Get Crucifix"] = { "loadstring" },
		["Get Keyboard Script"] = { "loadstring" },
		["Join Discord"] = { "setclipboard" },
		Website = { "setclipboard" },
		["Copy Discord"] = { "setclipboard" },
		["Copy Discord Invite"] = { "setclipboard" },
		["Copy Website"] = { "setclipboard" },
	},
}

local function ResolveExecutorFunction(Names, Fallback)
	for _, Name in Names do
		local Value = rawget(OstiumEnv, Name)
		if type(Value) == "function" then
			return Value
		end
	end
	return type(Fallback) == "function" and Fallback or nil
end

local SynEnvironment = rawget(OstiumEnv, "syn")
local FluxusEnvironment = rawget(OstiumEnv, "fluxus")

ExecutorSupport.Functions = {
	cloneref = ResolveExecutorFunction({ "cloneref", "clonereference" }, cloneref or clonereference),
	gethui = ResolveExecutorFunction({ "gethui" }, gethui),
	getconnections = ResolveExecutorFunction({ "getconnections" }, getconnections),
	firesignal = ResolveExecutorFunction({ "firesignal" }, firesignal),
	replicatesignal = ResolveExecutorFunction({ "replicatesignal" }, replicatesignal),
	fireproximityprompt = ResolveExecutorFunction({ "fireproximityprompt" }, fireproximityprompt),
	firetouchinterest = ResolveExecutorFunction({ "firetouchinterest" }, firetouchinterest),
	hookmetamethod = ResolveExecutorFunction({ "hookmetamethod" }, hookmetamethod),
	getnamecallmethod = ResolveExecutorFunction({ "getnamecallmethod" }, getnamecallmethod),
	newcclosure = ResolveExecutorFunction({ "newcclosure" }, newcclosure),
	isnetworkowner = ResolveExecutorFunction({ "isnetworkowner" }, isnetworkowner),
	queue_on_teleport = ResolveExecutorFunction(
		{ "queue_on_teleport", "queueonteleport" },
		queue_on_teleport
			or queueonteleport
			or (type(SynEnvironment) == "table" and SynEnvironment.queue_on_teleport)
			or (type(FluxusEnvironment) == "table" and FluxusEnvironment.queue_on_teleport)
	),
	writefile = ResolveExecutorFunction({ "writefile" }, writefile),
	readfile = ResolveExecutorFunction({ "readfile" }, readfile),
	isfile = ResolveExecutorFunction({ "isfile" }, isfile),
	makefolder = ResolveExecutorFunction({ "makefolder" }, makefolder),
	isfolder = ResolveExecutorFunction({ "isfolder" }, isfolder),
	listfiles = ResolveExecutorFunction({ "listfiles" }, listfiles),
	setclipboard = ResolveExecutorFunction({ "setclipboard", "toclipboard" }),
	loadstring = type(loadstring) == "function" and loadstring or nil,
	require = type(require) == "function" and require or nil,
	["debug.getupvalues"] = ResolveExecutorFunction(
		{ "getupvalues" },
		type(debug) == "table" and debug.getupvalues or nil
	),
	["debug.setupvalue"] = ResolveExecutorFunction(
		{ "setupvalue" },
		type(debug) == "table" and debug.setupvalue or nil
	),
}

ExecutorSupport.Tests.cloneref = function(Function)
	local Ok, Result = pcall(Function, game)
	return Ok and typeof(Result) == "Instance"
end

ExecutorSupport.Tests.gethui = function(Function)
	local Ok, Result = pcall(Function)
	return Ok and typeof(Result) == "Instance"
end

ExecutorSupport.Tests.getconnections = function(Function)
	local Event = Instance.new("BindableEvent")
	local function DummyCallback()
	end
	local Connection = Event.Event:Connect(DummyCallback)
	local Ok, Result = pcall(Function, Event.Event)
	Connection:Disconnect()
	Event:Destroy()

	if not Ok then
		return false
	end
	return typeof(Result) == "table"
end

ExecutorSupport.Tests.firesignal = function(Function)
	local Event = Instance.new("BindableEvent")
	local Connection = Event.Event:Connect(function() end)
	local Ok = pcall(Function, Event.Event, 713)
	Connection:Disconnect()
	Event:Destroy()
	return Ok
end

ExecutorSupport.Tests.newcclosure = function(Function)
	local Ok, Closure = pcall(Function, function(Value)
		return Value
	end)
	if not Ok or type(Closure) ~= "function" then
		return false
	end
	local Called, Result = pcall(Closure, 713)
	return Called and Result == 713
end

ExecutorSupport.Tests.loadstring = function(Function)
	local Ok, Chunk = pcall(Function, "return 713")
	if not Ok or type(Chunk) ~= "function" then
		return false
	end
	local Called, Result = pcall(Chunk)
	return Called and Result == 713
end

ExecutorSupport.Run = function()
	for Name, Function in ExecutorSupport.Functions do
		local Supported = type(Function) == "function"
		local Test = ExecutorSupport.Tests[Name]
		if Supported and Test then
			local Ok, Result = pcall(Test, Function)
			Supported = Ok and Result == true
		end
		ExecutorSupport.Status[Name] = Supported
	end
end

ExecutorSupport.Run()
Ostium.Executor = ExecutorSupport

Functions.GetMissingCapabilities = function(Array)
	local Missing = {}
	for _, Name in Array or {} do
		if ExecutorSupport.Status[Name] ~= true then
			table.insert(Missing, Name)
		end
	end
	return Missing
end

Functions.CheckCompatibility = function(Array)
	return #Functions.GetMissingCapabilities(Array) == 0
end

Functions.CheckCompatability = Functions.CheckCompatibility

Functions.ApplyCompatibility = function(Identifier, Settings)
	if type(Settings) ~= "table" then
		return Settings
	end

	local Feature = Settings.Capability or Identifier
	local Requirements = ExecutorSupport.Features[Feature]
	if not Requirements and Settings.Capability == nil then
		return Settings
	end

	local Result = {}
	for Key, Value in Settings do
		if Key ~= "Capability" then
			Result[Key] = Value
		end
	end

	local Missing = Functions.GetMissingCapabilities(Requirements)
	if #Missing > 0 then
		Result.Disabled = true
		Result.DisabledTooltip = "Missing executor support: " .. table.concat(Missing, ", ")
	end

	return Result
end

local WrappedUIContainers = setmetatable({}, { __mode = "k" })
local CompatibleControlMethods = {
	AddButton = true,
	AddDropdown = true,
	AddInput = true,
	AddSlider = true,
	AddToggle = true,
}

Functions.WrapUIContainer = function(Container)
	if type(Container) ~= "table" then
		return Container
	end
	if WrappedUIContainers[Container] then
		return WrappedUIContainers[Container]
	end

	local Proxy = {}
	setmetatable(Proxy, {
		__index = function(_, Key)
			local Value = Container[Key]
			if type(Value) ~= "function" then
				return Value
			end
			return function(_, ...)
				local Arguments = table.pack(...)
				if CompatibleControlMethods[Key] then
					local SettingsIndex = Key == "AddButton" and 1 or 2
					local Settings = Arguments[SettingsIndex]
					if type(Settings) == "table" then
						local Identifier = Key == "AddButton" and Settings.Text or Arguments[1]
						Arguments[SettingsIndex] = Functions.ApplyCompatibility(Identifier, Settings)
					end
				end
				return Value(Container, table.unpack(Arguments, 1, Arguments.n))
			end
		end,
		__newindex = function(_, Key, Value)
			Container[Key] = Value
		end,
	})

	WrappedUIContainers[Container] = Proxy
	return Proxy
end

Ostium.Internal.WrapUIContainer = Functions.WrapUIContainer

setmetatable(Groupboxes, {
	__newindex = function(Self, Key, Value)
		rawset(Self, Key, Functions.WrapUIContainer(Value))
	end,
})

local Entities = {
	["RushMoving"] = {
		Alias = "Rush",
		NotifyMessage = { Title = "Entity 'Rush' has spawned.", Body = "Find a hiding spot." }
	},
	["AmbushMoving"] = {
		Alias = "Ambush",
		NotifyMessage = { Title = "Entity 'Ambush' has spawned.", Body = "Find a hiding spot." }
	},
	["Eyes"] = {
		Alias = "Eyes",
		NotifyMessage = { Title = "Entity 'Eyes' has spawned.", Body = "Avoid looking at it." }
	},
	["Lookman"] = {
		Alias = "Eyes",
		NotifyMessage = { Title = "Entity 'Eyes' has spawned.", Body = "Avoid looking at it." }
	},
	["BackdoorRush"] = {
		Alias = "Blitz",
		NotifyMessage = { Title = "Entity 'Blitz' has spawned.", Body = "Find a hiding spot." }
	},
	["BackdoorLookman"] = {
		Alias = "Lookman",
		NotifyMessage = { Title = "Entity 'Lookman' has spawned.", Body = "Avoid looking at its eyes." }
	},
	["Groundskeeper"] = {
		Alias = "Groundskeeper",
		NotifyMessage = { Title = "Entity 'Groundskeeper' has spawned.", Body = "Avoid stepping on the grass." }
	},
	["A60"] = {
		Alias = "A-60",
		NotifyMessage = { Title = "Entity 'A-60' has spawned.", Body = "Find a hiding spot." }
	},
	["A120"] = {
		Alias = "A-120",
		NotifyMessage = { Title = "Entity 'A-120' has spawned.", Body = "Find a hiding spot." }
	},
	["GloombatSwarm"] = {
		Alias = "Gloombat Swarm",
		NotifyMessage = { Title = "Entity 'Gloombat Swarm' has spawned.", Body = "Keep all light sources turned off." }
	},
	["GlitchRush"] = {
		Alias = "RNIUSHCG==",
		NotifyMessage = { Title = "Entity 'RNIUSHCG==' has spawned.", Body = "Find a hiding spot." }
	},
	["GlitchAmbush"] = {
		Alias = "AR0xMBUSH",
		NotifyMessage = { Title = "Entity 'AR0xMBUSH' has spawned.", Body = "Find a hiding spot." }
	},
	["MonumentEntity"] = {
		Alias = "Monument",
		NotifyMessage = { Title = "Entity 'Monument' has spawned.", Body = "It can't move while you are looking at it." }
	},
	["JeffTheKiller"] = {
		Alias = "Jeff the Killer",
		NotifyMessage = { Title = "Entity 'Jeff the Killer' has spawned.", Body = "Avoid touching him." }
	},
	["CustomEntity"] = {
		Alias = "Custom Entity",
		NotifyMessage = { Title = "Entity 'Custom Entity' has spawned.", Body = "Find a hiding spot." }
	},
	["FrozenAmbush"] = {
		Alias = "Frozen Ambush",
		NotifyMessage = { Title = "Entity 'Frozen Ambush' has spawned.", Body = "Find a hiding spot." }
	},
	["SallyMoving"] = {
		Alias = "Sally",
		NotifyMessage = { Title = "Entity 'Sally' has spawned.", Body = "Drop an item for her." }
	},
	["BashMoving"] = {
		Alias = "Bash",
		NotifyMessage = { Title = "Entity 'Bash' has spawned.", Body = "Find a hiding spot." }
	}
}

local EntityListOrder = {
	"RushMoving",
	"AmbushMoving",
	"Eyes",
	"Lookman",
	"BackdoorRush",
	"BackdoorLookman",
	"Groundskeeper",
	"A60",
	"A120",
	"GloombatSwarm",
	"GlitchRush",
	"GlitchAmbush",
	"MonumentEntity",
	"JeffTheKiller",
	"CustomEntity",
	"FrozenAmbush",
	"SallyMoving",
	"BashMoving",
}

local EntityListOptionValues = { "Halt" }
for _, EntityName in EntityListOrder do
	local EntityData = Entities[EntityName]
	local Alias = EntityData and EntityData.Alias
	if Alias and not table.find(EntityListOptionValues, Alias) then
		table.insert(EntityListOptionValues, Alias)
	end
end

local EntityESPOptionValues = {
	"Rush","Ambush","Eyes","Blitz","Lookman","A-60","A-120","Gloombat Swarm","RNIUSHCG==","AR0xMBUSH",
	"Monument","Jeff the Killer","Custom Entity","Frozen Ambush","Sally","Bash","Groundskeeper",
	"Dupe","Figure","Snare","Giggle","Gloombat Eggs","Grumble","Mandrake Hole","Bramble",
	"Teller","Creak","Noise","Cobbler","Drone","Portrait","Fih","Water Pool"
}

local EntityIcons = {
	["RushMoving"]      = "rbxassetid://10716032262",
	["AmbushMoving"]    = "rbxassetid://10110576663",
	["A60"]             = "rbxassetid://12571092295",
	["A120"]            = "rbxassetid://12711591665",
	["BackdoorRush"]    = "rbxassetid://16602023490",
	["Eyes"]            = "rbxassetid://10183704772",
	["Lookman"]         = "rbxassetid://10183704772",
	["BackdoorLookman"] = "rbxassetid://16764872677",
	["GloombatSwarm"]   = "rbxassetid://79221203116470",
	["Halt"]            = "rbxassetid://11331795398",
	["JeffTheKiller"]   = "rbxassetid://94479432156278",
	["GlitchRush"]      = "rbxassetid://73859273102919",
	["GlitchAmbush"]    = "rbxassetid://88369678433359",
	["SallyMoving"]     = "rbxassetid://10840888070",
	["MonumentEntity"]  = "rbxassetid://88933556873017",
	["Groundskeeper"]   = "rbxassetid://114991380115557"
}

local ItemNames = {
	["Lighter"]           = "Lighter",
	["Flashlight"]        = "Flashlight",
	["Lockpick"]          = "Lockpicks",
	["Vitamins"]          = "Vitamins",
	["Bandage"]           = "Bandage",
	["StarVial"]          = "Starlight Vial",
	["StarBottle"]        = "Starlight Bottle",
	["StarJug"]           = "Starlight Barrel",
	["Shakelight"]        = "Gummy Flashlight",
	["Straplight"]        = "Straplight",
	["Bulklight"]         = "Spotlight",
	["Battery"]           = "Battery",
	["Candle"]            = "Candle",
	["Crucifix"]          = "Crucifix",
	["CrucifixWall"]      = "Crucifix",
	["Glowsticks"]        = "Glowstick",
	["SkeletonKey"]       = "Skeleton Key",
	["Candy"]             = "Candy",
	["ShieldMini"]        = "Mini Shield Potion",
	["ShieldBig"]         = "Big Shield Potion",
	["BandagePack"]       = "Bandage Pack",
	["BatteryPack"]       = "Battery Pack",
	["RiftCandle"]        = "Moonlight Candle",
	["LaserPointer"]      = "Laser Pointer",
	["HolyGrenade"]       = "Holy Hand Grenade",
	["Shears"]            = "Shears",
	["Smoothie"]          = "Smoothie",
	["Cheese"]            = "Cheese",
	["Bread"]             = "Bread",
	["AlarmClock"]        = "Alarm Clock",
	["RiftSmoothie"]      = "Moonlight Smoothie",
	["GweenSoda"]         = "Gween Soda",
	["GlitchCube"]        = "Glitch Fragment",
	["Scanner"]           = "Tablet",
	["Bomb"]              = "Bomb",
	["Knockbomb"]         = "Knockbomb",
	["Nanner"]            = "Nanner",
	["BigBomb"]           = "Big Bomb",
	["SnakeBox"]          = "Hiding Box",
	["GoldGun"]           = "Golden Gun",
	["StopSign"]          = "Stop Sign",
	["TipJar"]            = "Tip Jar",
	["Lantern"]           = "Lantern",
	["IronKey"]           = "Iron Key",
	["LotusPetal"]        = "Lotus Petal",
	["Compass"]           = "Compass",
	["LotusPetalPickup"]  = "Lotus Petal",
	["LanternLitItem"]    = "Lantern",
	["KeyIron"]           = "Iron Key",
	["IronKeyForCrypt"]   = "Iron Key",
	["LotusHolder"]       = "Lotus Petal",
	["Multitool"]         = "Multitool",
	["RiftJar"]           = "Rift Jar",
	["AloeVera"]          = "Aloe Vera",
	["Donut"]             = "Donut",
	["Lotus"]             = "Lotus",
	["BoxingGloves"]      = "Boxing Gloves",
	["PaperPlane"]        = "Paper Plane",
	["Pizza"]             = "Pizza",
	["PocketMirror"]      = "Pocket Mirror",
	["WaterCup"]          = "Water Cup",
	["FihFlakes"]         = "Fih Flakes",
	["PaperPlanePickup"]  = "Paper Plane"
}

local SpecialItemESPLabels = {
	BrokenMonitor = "Stairwell Debris",
	DinkyLamp = "Stairwell Debris",
	GweenSodaPack = "Stairwell Debris",
	TV_Stand = "TV Stand",
}

local CutsceneNames = {
    "Figure",
    "FigureEnd",
    "FigureHotelEnd",
    "FigureHotelFire",
    "SeekIntroFools",
    "SeekIntroHotel",
    "SeekIntroMines",
    "SeekIntroMines2",
    "SerewSeekDrain",
    "SewerSeekLower",
    "GrumbleNestEnd",
    "EyestalkIntro",
}

local Character
local Humanoid
local RootPart

local Collision
local CollisionClone
local CollisionPart
local CollisionPartClone

local Camera
local LocalPlayer = Services.Players.LocalPlayer

local RemotesFolder   = Services.ReplicatedStorage:FindFirstChild("RemotesFolder")
local LiveModifiers   = Services.ReplicatedStorage:FindFirstChild("LiveModifiers")
local FloorReplicated = Services.ReplicatedStorage:FindFirstChild("FloorReplicated")
local CurrentRooms    = Services.Workspace:FindFirstChild("CurrentRooms")
local Drops           = Services.Workspace:FindFirstChild("Drops")
local GameData        = Services.ReplicatedStorage:WaitForChild("GameData")
local Floor           = GameData:WaitForChild("Floor").Value
local LatestRoom      = GameData:WaitForChild("LatestRoom")
local FinishedLoadingRoom = GameData:FindFirstChild("FinishedLoadingRoom")
if FinishedLoadingRoom then
	FinishedLoadingRoom:Destroy()
end

local function GetHiddenContainer()
	if Functions.CheckCompatability({"gethui"}) then
		return Ostium.Environment.gethui()
	end
	return Services.CoreGui
end

Functions.Notify = function(Settings)
	Library:Notify({
		Title = Settings.Title,
		Description = Settings.Body or "",
		Time = Settings.Time or 5,
		Icon = Settings.Icon,
		BigIcon = Settings.Image,
	})
end

Functions.Caption = function(Text, PlaySound)
	if typeof(PlaySound) ~= "boolean" then
		PlaySound = true
	end
	local CaptionValue = Instance.new("NumberValue")
	local Caption = Globals.MainUI:WaitForChild("MainFrame"):WaitForChild("Caption"):Clone()
	local CaptionSound = Globals.MainUI:WaitForChild("Initiator"):WaitForChild("Main_Game"):WaitForChild("Reminder"):WaitForChild("Caption")
	local CaptionSoundClone = CaptionSound:Clone()
	CaptionSoundClone.Parent = CaptionSound.Parent
	CaptionSoundClone.Volume = 0.1

	Caption.Destroying:Connect(function()
		CaptionValue:Destroy()
	end)

	for _, Child in Globals.MainUI:GetChildren() do
		if Child.Name == "LiveCaption" then
			Child:Destroy()
		end
	end

	Caption.Parent = Globals.MainUI
	Caption.Visible = true
	Caption.Name = "LiveCaption"
	Caption.Text = Text

	if PlaySound then
		CaptionSoundClone:Play()
	end

	Services.Debris:AddItem(CaptionSoundClone, 5)

	local HolderTween = Services.TweenService:Create(CaptionValue, TweenInfo.new(3), { Value = 100 })
	HolderTween:Play()
	HolderTween.Completed:Connect(function()
		CaptionValue:Destroy()
		Services.TweenService:Create(Caption, TweenInfo.new(4, Enum.EasingStyle.Linear), { TextTransparency = 1 }):Play()
		Services.TweenService:Create(Caption, TweenInfo.new(4, Enum.EasingStyle.Linear), { TextStrokeTransparency = 1 }):Play()
	end)
end

Functions.GetHasteTime = function()
	local TimeRemaining = FloorReplicated.DigitalTimer.Value
	local Minutes = math.floor(TimeRemaining / 60)
	local Seconds = TimeRemaining - (Minutes * 60)
	local MinutesText = Minutes < 10 and ("0" .. tostring(Minutes)) or tostring(Minutes)
	local SecondsText = Seconds < 10 and ("0" .. tostring(Seconds)) or tostring(Seconds)
	return MinutesText .. ":" .. SecondsText
end

Functions.BuildKnobFarmSource = function(Opts)
	Opts = Opts or {}
	local MinContainers = tonumber(Opts.MinContainers) or 0
	local MinCoins = tonumber(Opts.MinCoins) or 0
	local UseLockpick = (Opts.UseLockpick == true) and "true" or "false"
	local UseKnobBoost = (Opts.UseKnobBoost == true) and "true" or "false"

	local ModsList = {
		"LightsNeverFlicker", "ItemSpawnNone", "NoGuidingLight", "NoKeySound", "Slippery",
		"Fog", "Firedamp", "LeastHidingSpots", "Jammin", "PlayerHealthLess", "PlayerSlowHealth",
		"EntitiesMore", "RushMore", "RushFaster", "RushQuiet", "DupeMost", "ScreechFast",
		"TimothyMore", "EyesTwice", "FigureFaster", "AmbushMore", "AmbushFaster", "HideTime",
		"Dread", "GiggleMore", "Gloombat", "RoomsA90", "BackdoorRush", "BackdoorLookman", "BackdoorVacuum",
	}
	local Quoted = {}
	for _, Name in ipairs(ModsList) do Quoted[#Quoted + 1] = string.format("%q", Name) end

	local Header = string.format(
		"local MIN_CONTAINERS = %d\nlocal MIN_COINS = %d\nlocal USE_LOCKPICK = %s\nlocal USE_KNOBBOOST = %s\nlocal MODS = {%s}\n",
		MinContainers, MinCoins, UseLockpick, UseKnobBoost, table.concat(Quoted, ", ")
	)

	local Body = [==[
local FARM_FILE = "ostium_knobfarm.lua"
local STOP_FILE = "ostium_knobfarm_stop.txt"

if isfile and isfile(STOP_FILE) then return end

if _G.OSTIUM_KNOBFARM_ACTIVE then return end
_G.OSTIUM_KNOBFARM_ACTIVE = true

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local plr = Players.LocalPlayer

local fpp = fireproximityprompt
local rsig = replicatesignal

local requeued = false
plr.OnTeleport:Connect(function(state)
	if requeued then return end
	if state == Enum.TeleportState.Started or state == Enum.TeleportState.InProgress then
		if isfile and isfile(STOP_FILE) then return end
		if queue_on_teleport and readfile and isfile and isfile(FARM_FILE) then
			pcall(function() queue_on_teleport(readfile(FARM_FILE)) end)
			requeued = true
		end
	end
end)

local function getChar()
	return plr.Character or plr.CharacterAdded:Wait()
end

local function inLobby()
	return workspace:FindFirstChild("Lobby") ~= nil
end

local function inRun()
	local gd = RS:FindFirstChild("GameData")
	return gd and gd:FindFirstChild("InGame") and gd.InGame.Value == true
end

local function remotes()
	return RS:FindFirstChild("RemotesFolder")
end

local function createMinesRun()
	local rf = remotes()
	if not rf or not rf:FindFirstChild("CreateElevator") then return end
	pcall(function()
		rf.CreateElevator:FireServer({ Destination = "Mines", FriendsOnly = true, MaxPlayers = 1, Mods = MODS, Settings = {} })
	end)
	local char, waited = plr.Character, 0
	while (not char or char:GetAttribute("InGameElevator") == nil) and waited < 12 do
		task.wait(0.2); waited = waited + 0.2; char = plr.Character
	end
	task.wait(0.5)
	if rf:FindFirstChild("ElevatorStart") then
		pcall(function() rf.ElevatorStart:FireServer(true) end)
	end
end

local function resolveShopItem(keyword)
	local shop = RS:FindFirstChild("ItemShop")
	if not shop then return nil end
	keyword = keyword:lower()
	for _, item in shop:GetChildren() do
		local title = tostring(item:GetAttribute("Title") or "")
		if item.Name:lower():find(keyword) or title:lower():find(keyword) then return item.Name end
	end
	return nil
end

local function doPreRunShop()
	local rf = remotes()
	if not rf or not rf:FindFirstChild("PreRunShop") then return end
	local items = {}
	if USE_LOCKPICK then
		local n = resolveShopItem("lockpick")
		if n then table.insert(items, n) end
	end
	pcall(function() rf.PreRunShop:FireServer(items, USE_KNOBBOOST and true or false) end)
end

local function skipElevator()
	local rooms = workspace:FindFirstChild("CurrentRooms")
	local room0 = rooms and rooms:FindFirstChild("0")
	local elevator = room0 and room0:FindFirstChild("StarterElevator")
	if not elevator or not fpp then return end
	for _, d in elevator:GetDescendants() do
		if d:IsA("ProximityPrompt") and (d.Name == "SkipPrompt" or (d.Parent and tostring(d.Parent.Name):find("Skip"))) then
			pcall(fpp, d)
		end
	end
end

local ContainerNames = {
	ChestBox = true, ChestBoxLocked = true, Toolbox = true, Toolbox_Locked = true,
	Chest_Vine = true, Toolshed_Small = true, Locker_Small_Locked = true, MouseHole = true,
	Drawer = true, Drawers = true, DrawerSingle = true,
}

local pathFolder = Instance.new("Folder")
pathFolder.Name = "OstiumKnobPath"
pathFolder.Parent = workspace

local function clearNodes() for _, n in pathFolder:GetChildren() do n:Destroy() end end

local function primaryPart(o)
	if o:IsA("BasePart") then return o end
	return o.PrimaryPart or o:FindFirstChildWhichIsA("BasePart", true)
end

local function firePromptsIn(o)
	if not o or not fpp then return end
	for _, d in o:GetDescendants() do
		if d:IsA("ProximityPrompt") then pcall(fpp, d) end
	end
end

local function pathTo(pos)
	local char = getChar()
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return end
	local path = PathfindingService:CreatePath({ AgentCanJump = true, AgentRadius = 2, AgentHeight = 5, WaypointSpacing = 4 })
	local ok = pcall(function() path:ComputeAsync(root.Position, pos) end)
	clearNodes()
	local wps = (ok and path.Status == Enum.PathStatus.Success) and path:GetWaypoints() or nil
	if not wps or #wps == 0 then
		hum:MoveTo(pos)
		hum.MoveToFinished:Wait()
		return
	end
	for _, wp in wps do
		local b = Instance.new("Part")
		b.Size = Vector3.one; b.Shape = Enum.PartType.Ball; b.Position = wp.Position
		b.Anchored = true; b.CanCollide = false; b.Material = Enum.Material.ForceField
		b.Color = Color3.fromRGB(255, 85, 85); b.Transparency = 0.4; b.Parent = pathFolder
	end
	for _, wp in wps do
		if wp.Action == Enum.PathWaypointAction.Jump then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
		hum:MoveTo(wp.Position)
		local reached, t = false, tick()
		local c = hum.MoveToFinished:Connect(function() reached = true end)
		repeat task.wait() until reached or (tick() - t) > 3
		c:Disconnect()
	end
	clearNodes()
end

local function getGold()
	local g = plr:FindFirstChild("Gold")
	return g and g.Value or 0
end

local function firstRoom()
	local rooms = workspace:FindFirstChild("CurrentRooms")
	return rooms and (rooms:FindFirstChild("1") or rooms:FindFirstChild("0"))
end

local function scanContainers(room)
	local found = {}
	if not room then return found end
	for _, o in room:GetDescendants() do
		if ContainerNames[o.Name] and (o:IsA("Model") or o:IsA("BasePart")) then table.insert(found, o) end
	end
	return found
end

local function playAgain()
	local rf = remotes()
	if rf and rf:FindFirstChild("PlayAgain") then pcall(function() rf.PlayAgain:FireServer() end) end
end

local function activateKnobFarm()
	local VirtualUser = game:GetService("VirtualUser")
	pcall(function()
		plr.Idled:Connect(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end)
	while task.wait(0.25) do
		if isfile and isfile(STOP_FILE) then break end
		if rsig then pcall(function() rsig(plr.Kill) end) end
		local rf = remotes()
		if rf and rf:FindFirstChild("Statistics") then pcall(function() rf.Statistics:FireServer() end) end
	end
end

if inLobby() then
	createMinesRun()
	return
end

local waited = 0
while not inRun() and waited < 30 do task.wait(0.5); waited = waited + 0.5 end
getChar()

doPreRunShop()
task.wait(0.5)
skipElevator()

local room
waited = 0
repeat
	room = firstRoom()
	task.wait(0.25); waited = waited + 0.25
until (room and room.Name == "1") or waited > 40
room = firstRoom()

local containers = scanContainers(room)
if #containers < MIN_CONTAINERS then
	playAgain()
	return
end

local startGold = getGold()
for _, c in ipairs(containers) do
	if isfile and isfile(STOP_FILE) then return end
	local part = primaryPart(c)
	if part then
		pathTo(part.Position)
		firePromptsIn(c)
		task.wait(0.35)
		for _, o in c:GetDescendants() do
			if o.Name == "GoldPile" then firePromptsIn(o) end
		end
		for _, o in room:GetDescendants() do
			if o.Name == "GoldPile" then
				local pp = primaryPart(o)
				if pp and (pp.Position - part.Position).Magnitude < 25 then firePromptsIn(o) end
			end
		end
		task.wait(0.15)
	end
end

local collected = getGold() - startGold
if collected >= MIN_COINS then
	activateKnobFarm()
else
	playAgain()
end
]==]

	return Header .. Body
end

local InLobby = (Services.Workspace:FindFirstChild("Lobby") ~= nil)
	and (not GameData:FindFirstChild("InGame") or GameData.InGame.Value == false)

if InLobby then
	local Window = Library:CreateWindow({
		Title = "Ostium",
		Footer = OSTIUM_VERSION .. " | Ostium | Lobby",
		Icon = OSTIUM_ICON,
		NotifySide = "Right",
		ShowCustomCursor = false,
		AutoShow = true,
		Center = true,
		Resizable = true,
		ShowMobileButtons = true,
		UnlockMouseWhileOpen = true,
		GlobalSearch = true,
		TabPadding = 3,
		MenuFadeTime = 0,
		CornerRadius = 7,
	})

	Library.Scheme.AccentColor = Color3.fromRGB(255, 85, 85)
	Library:UpdateColorsUsingRegistry()

	
	local KeyTab = Ostium.Key:GateTab(Window)

	
	local HomeTab = Ostium.Internal.RenderStartPane(Window)

	local LobbyTab = Window:AddTab("Lobby", "pickaxe")

	
	
	
	
	
	
	
	
	
	
	
	
	
	local LobbyBindings = {}

	
	
	
	
	LobbyBindings.MinesModifiers = {
		"LightsNeverFlicker",  
		"ItemSpawnNone",       
		"NoGuidingLight",      
		"NoKeySound",          
		"Slippery",            
		"Fog",                 
		"Firedamp",            
		"LeastHidingSpots",    
		"Jammin",              
		"PlayerHealthLess",    
		"PlayerSlowHealth",    
		"EntitiesMore",        
		"RushMore",            
		"RushFaster",          
		"RushQuiet",           
		"DupeMost",            
		"ScreechFast",         
		"TimothyMore",         
		"EyesTwice",           
		"FigureFaster",        
		"AmbushMore",          
		"AmbushFaster",        
		"HideTime",            
		"Dread",               
		"GiggleMore",          
		"Gloombat",            
		"RoomsA90",            
		"BackdoorRush",        
		"BackdoorLookman",     
		"BackdoorVacuum",      
	}

	LobbyBindings.Elevator = {
		FloorMap = {},
		NameByDisplay = {},
		Values = {},
		DefaultFloor = nil,
	}

	LobbyBindings.Elevator.GetDisplayName = function(FloorName, FloorData)
		local Title = tostring((type(FloorData) == "table" and FloorData.Title) or FloorName)
		if Title == FloorName then
			return FloorName
		end
		return string.format("%s [%s]", Title, FloorName)
	end

	LobbyBindings.Elevator.IsLobbyAccessible = function(FloorData)
		if type(FloorData) ~= "table" then
			return false
		end
		if FloorData.AccessibleThroughLobby == false or FloorData.AccessibleTroughLobby == false then
			return false
		end
		local Requires = FloorData.Requires
		if type(Requires) == "table" and Requires.NoLobbyEntry == true then
			return false
		end
		return true
	end

	LobbyBindings.Elevator.CanUseAdmin = function(FloorData)
		return type(FloorData) == "table" and FloorData.CanUseAdmin ~= false
	end

	LobbyBindings.Elevator.GetFloorData = function(FloorName)
		return FloorName and LobbyBindings.Elevator.FloorMap[FloorName] or nil
	end

	LobbyBindings.Elevator.GetSelectedFloorName = function()
		local Display = Options.LobbyElevatorFloor and Options.LobbyElevatorFloor.Value
		return LobbyBindings.Elevator.NameByDisplay[Display] or Display or LobbyBindings.Elevator.DefaultFloor
	end

	LobbyBindings.Elevator.BuildMods = function(FloorName, UseAdmin, ExtraMods)
		local Mods = {}
		for _, ModName in ipairs(ExtraMods or {}) do
			if not table.find(Mods, ModName) then
				table.insert(Mods, ModName)
			end
		end

		local FloorData = LobbyBindings.Elevator.GetFloorData(FloorName)
		if UseAdmin and LobbyBindings.Elevator.CanUseAdmin(FloorData) and not table.find(Mods, "AdminPanel") then
			table.insert(Mods, "AdminPanel")
		end

		return Mods
	end

	LobbyBindings.Elevator.LoadFloors = function()
		table.clear(LobbyBindings.Elevator.FloorMap)
		table.clear(LobbyBindings.Elevator.NameByDisplay)
		table.clear(LobbyBindings.Elevator.Values)
		LobbyBindings.Elevator.DefaultFloor = nil

		local ModuleContainer = Services.ReplicatedStorage:FindFirstChild("ModulesShared")
		local FloorModule = ModuleContainer and ModuleContainer:FindFirstChild("AccessibleFloors")
		if not FloorModule then
			return false, "Could not find ModulesShared.AccessibleFloors."
		end

		local Ok, Result = pcall(require, FloorModule)
		if not Ok or type(Result) ~= "table" then
			return false, "Could not read AccessibleFloors."
		end

		local Entries = {}
		for FloorName, FloorData in pairs(Result) do
			if LobbyBindings.Elevator.IsLobbyAccessible(FloorData) then
				table.insert(Entries, {
					Name = FloorName,
					Data = FloorData,
					Sort = tonumber(FloorData.Sort) or 0,
					Title = tostring(FloorData.Title or FloorName),
				})
			end
		end

		table.sort(Entries, function(Left, Right)
			if Left.Sort ~= Right.Sort then
				return Left.Sort < Right.Sort
			end
			if Left.Title ~= Right.Title then
				return Left.Title < Right.Title
			end
			return Left.Name < Right.Name
		end)

		for _, Entry in ipairs(Entries) do
			local Display = LobbyBindings.Elevator.GetDisplayName(Entry.Name, Entry.Data)
			LobbyBindings.Elevator.FloorMap[Entry.Name] = Entry.Data
			LobbyBindings.Elevator.NameByDisplay[Display] = Entry.Name
			table.insert(LobbyBindings.Elevator.Values, Display)
		end

		LobbyBindings.Elevator.DefaultFloor =
			(LobbyBindings.Elevator.FloorMap.Hotel and "Hotel")
			or (LobbyBindings.Elevator.FloorMap.Mines and "Mines")
			or next(LobbyBindings.Elevator.FloorMap)

		return true
	end

	LobbyBindings.Elevator.Create = function(Config)
		local CreateElevator = RemotesFolder and RemotesFolder:FindFirstChild("CreateElevator")
		if not CreateElevator then
			Functions.Notify({
				Title = Config.NotifyTitle or "Elevator Creator",
				Body = "CreateElevator remote was not found.",
			})
			return false
		end

		local FloorName = Config.Floor or LobbyBindings.Elevator.GetSelectedFloorName()
		local FloorData = LobbyBindings.Elevator.GetFloorData(FloorName)
		if not FloorName or not FloorData then
			Functions.Notify({
				Title = Config.NotifyTitle or "Elevator Creator",
				Body = "Selected floor is unavailable.",
			})
			return false
		end

		local Payload = {
			Destination = FloorName,
			FriendsOnly = Config.FriendsOnly == true,
			MaxPlayers = math.clamp(math.floor(tonumber(Config.MaxPlayers) or 1), 1, 12),
			Mods = LobbyBindings.Elevator.BuildMods(FloorName, Config.UseAdmin, Config.Mods),
			Settings = Config.Settings or {},
		}

		local Created = pcall(function()
			CreateElevator:FireServer(Payload)
		end)
		if not Created then
			Functions.Notify({
				Title = Config.NotifyTitle or "Elevator Creator",
				Body = "Failed to fire CreateElevator.",
			})
			return false
		end

		local Char = LocalPlayer.Character
		local Waited = 0
		while (not Char or Char:GetAttribute("InGameElevator") == nil) and Waited < 12 do
			task.wait(0.2)
			Waited += 0.2
			Char = LocalPlayer.Character
		end
		if not Char or Char:GetAttribute("InGameElevator") == nil then
			Functions.Notify({
				Title = Config.NotifyTitle or "Elevator Creator",
				Body = Config.FailureBody or ("Could not create a " .. FloorName .. " elevator."),
			})
			return false
		end

		if Config.AutoStart then
			task.wait(0.5)
			pcall(function() RemotesFolder.ElevatorStart:FireServer(true) end)
		end

		return true
	end

	function LobbyBindings.StartMinesRun()
		return LobbyBindings.Elevator.Create({
			Floor = "Mines",
			FriendsOnly = true,
			MaxPlayers = 1,
			Mods = LobbyBindings.MinesModifiers,
			UseAdmin = false,
			AutoStart = true,
			NotifyTitle = "Knob Farm",
			FailureBody = "Could not create a Mines elevator.",
		})
	end

	
	
	local function ResolveShopItem(Keyword)
		local Shop = Services.ReplicatedStorage:FindFirstChild("ItemShop")
		if not Shop then return nil end
		Keyword = Keyword:lower()
		for _, Item in Shop:GetChildren() do
			local Title = tostring(Item:GetAttribute("Title") or "")
			if Item.Name:lower():find(Keyword) or Title:lower():find(Keyword) then
				return Item.Name
			end
		end
		return nil
	end

	
	function LobbyBindings.DoPreRunShop(UseLockpick, UseKnobBoost)
		local Items = {}
		if UseLockpick then
			local Name = ResolveShopItem("lockpick")
			if Name then table.insert(Items, Name) end
		end
		if #Items == 0 and not UseKnobBoost then return end
		pcall(function()
			RemotesFolder.PreRunShop:FireServer(Items, UseKnobBoost and true or false)
		end)
	end

	local ElevatorReady, ElevatorError = LobbyBindings.Elevator.LoadFloors()

	local ElevatorCreator = Functions.WrapUIContainer(LobbyTab:AddLeftGroupbox("Elevator Creator"))
	if ElevatorReady and #LobbyBindings.Elevator.Values > 0 then
		local DefaultFloorName = LobbyBindings.Elevator.DefaultFloor
		local DefaultDisplay = DefaultFloorName and LobbyBindings.Elevator.GetDisplayName(DefaultFloorName, LobbyBindings.Elevator.GetFloorData(DefaultFloorName))
			or LobbyBindings.Elevator.Values[1]

		local CreateElevatorButton

		ElevatorCreator:AddDropdown("LobbyElevatorFloor", {
			Text = "Floor",
			Values = LobbyBindings.Elevator.Values,
			Default = DefaultDisplay,
		})
		ElevatorCreator:AddToggle("LobbyElevatorFriendsOnly", {
			Text = "Friends Only",
			Default = true,
		})
		ElevatorCreator:AddToggle("LobbyElevatorUseAdmin", {
			Text = "Admin Panel",
			Default = false,
		})
		ElevatorCreator:AddSlider("LobbyElevatorMaxPlayers", {
			Text = "Max Players",
			Min = 1,
			Max = 12,
			Default = 1,
			Rounding = 0,
			Compact = true,
		})

		CreateElevatorButton = ElevatorCreator:AddButton({
			Text = "Create Elevator",
			DoubleClick = false,
			Func = function()
				local FloorName = LobbyBindings.Elevator.GetSelectedFloorName()
				local FloorData = LobbyBindings.Elevator.GetFloorData(FloorName)
				if not FloorName or not FloorData then
					Functions.Notify({ Title = "Elevator Creator", Body = "Selected floor is unavailable." })
					return
				end

				local RequestedAdmin = Toggles.LobbyElevatorUseAdmin.Value == true
				local CanUseAdmin = LobbyBindings.Elevator.CanUseAdmin(FloorData)
				if RequestedAdmin and not CanUseAdmin then
					Functions.Notify({
						Title = "Elevator Creator",
						Body = "This floor does not allow Admin Panel. Creating it without admin instead.",
					})
				end

				local Created = LobbyBindings.Elevator.Create({
					Floor = FloorName,
					FriendsOnly = Toggles.LobbyElevatorFriendsOnly.Value == true,
					MaxPlayers = Options.LobbyElevatorMaxPlayers.Value,
					UseAdmin = RequestedAdmin and CanUseAdmin,
					NotifyTitle = "Elevator Creator",
				})

				if Created then
					Functions.Notify({
						Title = "Elevator Creator",
						Body = "Created a " .. FloorName .. " elevator.",
					})
				end
			end,
		})

		LobbyBindings.Elevator.RefreshControls = function()
			local FloorName = LobbyBindings.Elevator.GetSelectedFloorName()
			local FloorData = LobbyBindings.Elevator.GetFloorData(FloorName)
			local CanUseAdmin = LobbyBindings.Elevator.CanUseAdmin(FloorData)

			Toggles.LobbyElevatorUseAdmin:SetDisabled(not CanUseAdmin)
			if not CanUseAdmin and Toggles.LobbyElevatorUseAdmin.Value then
				Functions.SetControlValue(Toggles.LobbyElevatorUseAdmin, false)
			end

			if CreateElevatorButton then
				CreateElevatorButton:SetDisabled(FloorData == nil)
			end
		end

		Options.LobbyElevatorFloor:OnChanged(function()
			LobbyBindings.Elevator.RefreshControls()
		end)
		LobbyBindings.Elevator.RefreshControls()
	else
		ElevatorCreator:AddLabel({
			Text = ElevatorError or "No lobby-accessible floors were found.",
			DoesWrap = true,
		})
	end

	local Achievements = Functions.WrapUIContainer(LobbyTab:AddLeftGroupbox("Achievements"))
	Achievements:AddSlider("AchCycleSpeed", {
		Text = "Cycle Speed", Tooltip = "Seconds between each achievement while cycling.",
		Min = 0.1, Max = 5, Default = 1, Rounding = 1, Suffix = "s", Compact = true,
	})
	Achievements:AddToggle("AchCycle", {
		Text = "Cycle Achievements", Default = false,
		Tooltip = "Cycles through your unlocked achievements above your head.",
	})

	Globals.AchievementCycle = { Running = false }
	Toggles.AchCycle:OnChanged(function(Value)
		if Value and not Globals.AchievementCycle.Running then
			Globals.AchievementCycle.Running = true
			task.spawn(function()
				local FlexAchievement = RemotesFolder:FindFirstChild("FlexAchievement")
				local Index = 0
				while Toggles.AchCycle.Value and not Library.Unloaded do
					
					
					
					local Unlocked
					pcall(function()
						local Rep = require(Services.ReplicatedStorage:WaitForChild("ReplicaDataModule"))
						Unlocked = Rep.data and Rep.data.Achievements
					end)
					if FlexAchievement and typeof(Unlocked) == "table" and #Unlocked > 0 then
						Index = (Index % #Unlocked) + 1
						pcall(function() FlexAchievement:FireServer(Unlocked[Index]) end)
					end
					task.wait(math.max(0.1, Options.AchCycleSpeed.Value))
				end
				Globals.AchievementCycle.Running = false
			end)
		end
	end)

	
	
	
	local KnobFarm = Functions.WrapUIContainer(LobbyTab:AddRightGroupbox("Knob Farm"))
	KnobFarm:AddSlider("KF_MinContainers", {
		Text = "Minimum Containers",
		Tooltip = "If the first Mines room has fewer openable containers than this, reroll the run.",
		Min = 0, Max = 30, Default = 6, Rounding = 0, Compact = true,
	})
	KnobFarm:AddSlider("KF_MinCoins", {
		Text = "Minimum Coins",
		Tooltip = "After looting, only start the knob farm if you collected at least this much gold.",
		Min = 0, Max = 500, Default = 50, Rounding = 0, Compact = true,
	})
	KnobFarm:AddToggle("KF_UseLockpick", {
		Text = "Use Lockpick", Default = false,
		Tooltip = "Buy a lockpick in the pre-run shop to open locked containers.",
	})
	KnobFarm:AddToggle("KF_UseKnobBoost", {
		Text = "Use Knob Boost", Default = false,
		Tooltip = "Buy the knob boost in the pre-run shop.",
	})

	local LobbyKnobFarm = {
		File = "ostium_knobfarm.lua",
		State = {
			Running = false,
			TeleportConnection = nil,
		},
		Functions = {},
	}

	local LobbyFarm = LobbyKnobFarm.Functions

	LobbyFarm.ResolveQueue = function()
		local Environment = getgenv and getgenv() or _G
		local Syn = rawget(Environment, "syn")
		local Fluxus = rawget(Environment, "fluxus")
		return queue_on_teleport
			or queueonteleport
			or rawget(Environment, "queue_on_teleport")
			or rawget(Environment, "queueonteleport")
			or (Syn and Syn.queue_on_teleport)
			or (Fluxus and Fluxus.queue_on_teleport)
	end

	LobbyFarm.BuildSource = Functions.BuildKnobFarmSource

	LobbyKnobFarm.StopFile = "ostium_knobfarm_stop.txt"

	LobbyFarm.Stop = function()
		LobbyKnobFarm.State.Running = false
		if LobbyKnobFarm.State.TeleportConnection then
			LobbyKnobFarm.State.TeleportConnection:Disconnect()
			LobbyKnobFarm.State.TeleportConnection = nil
		end
		if type(writefile) == "function" then
			pcall(writefile, LobbyKnobFarm.StopFile, "1")
		end
	end

	Globals.LobbyKnobFarm = LobbyKnobFarm.State

	KnobFarm:AddButton({
		Text = "Knob Farm",
		Capability = "LobbyKnobFarm",
		DoubleClick = true,
		Tooltip = "Enter a Mines run, loot the first room, and start the knob farm.",
		Func = function()
			if LobbyKnobFarm.State.Running then
				LobbyFarm.Stop()
				Functions.Notify({ Title = "Knob Farm", Body = "Stopped." })
				return
			end

			local Queue = LobbyFarm.ResolveQueue()
			if type(Queue) ~= "function" or type(writefile) ~= "function" or type(readfile) ~= "function" then
				Functions.Notify({
					Title = "Knob Farm",
					Body = "Your executor needs queue_on_teleport, writefile, and readfile.",
				})
				return
			end

			if type(delfile) == "function" then
				if type(isfile) == "function" and isfile(LobbyKnobFarm.StopFile) then
					pcall(delfile, LobbyKnobFarm.StopFile)
				end
			end

			local Source = LobbyFarm.BuildSource({
				MinContainers = Options.KF_MinContainers.Value,
				MinCoins = Options.KF_MinCoins.Value,
				UseLockpick = Toggles.KF_UseLockpick.Value == true,
				UseKnobBoost = Toggles.KF_UseKnobBoost.Value == true,
			})

			local WroteFile, WriteError = pcall(writefile, LobbyKnobFarm.File, Source)
			if not WroteFile then
				Functions.Notify({
					Title = "Knob Farm",
					Body = "Could not save continuation: " .. tostring(WriteError),
				})
				return
			end

			LobbyKnobFarm.State.Running = true
			local Queued = false

			LobbyKnobFarm.State.TeleportConnection = LocalPlayer.OnTeleport:Connect(function(TeleportState)
				if TeleportState == Enum.TeleportState.Failed
					or Queued
					or not LobbyKnobFarm.State.Running then
					return
				end

				if pcall(Queue, Source) then
					Queued = true
					if LobbyKnobFarm.State.TeleportConnection then
						LobbyKnobFarm.State.TeleportConnection:Disconnect()
						LobbyKnobFarm.State.TeleportConnection = nil
					end
				else
					Functions.Notify({
						Title = "Knob Farm",
						Body = "Failed to queue the in-run continuation.",
					})
				end
			end)

			Functions.Notify({
				Title = "Knob Farm",
				Body = "Creating a Mines run with modifiers...",
			})

			if not LobbyBindings.StartMinesRun() then
				LobbyFarm.Stop()
			end
		end,
	})

	
	Ostium.Internal.RenderConfigPane(Window)

	
	Ostium.Key:FinishGate(KeyTab, HomeTab)

	Functions.Notify({ Title = "Ostium loaded (Lobby Mode).", Body = "Head into a run for the full menu." })
	if Loading then
		pcall(function() Loading:Continue() end)
		Loading = nil
	end
	return
end

if not LocalPlayer.Character or not CurrentRooms:FindFirstChildOfClass("Model") then
	Functions.Notify({ Title = "Waiting for the game to load..." })
	while not LocalPlayer.Character or not CurrentRooms:FindFirstChildOfClass("Model") do
		task.wait()
	end
	task.wait(4)
end

if not RemotesFolder then
	if Services.ReplicatedStorage:FindFirstChild("EntityInfo") then
		RemotesFolder = Services.ReplicatedStorage:FindFirstChild("EntityInfo")
	elseif Services.ReplicatedStorage:FindFirstChild("Bricks") then
		RemotesFolder = Services.ReplicatedStorage:FindFirstChild("Bricks")
	end
end

if Floor == "Hotel" and RemotesFolder.Name == "Bricks" then
	Floor = "OldHotel"
end

if not LiveModifiers then
	LiveModifiers = Instance.new("Folder")
end

if not FloorReplicated then
	FloorReplicated = Instance.new("Folder")
end

local FakeEvents = {
	Screech = Instance.new("RemoteEvent"),
	Shade   = Instance.new("RemoteEvent"),
	A90     = Instance.new("RemoteEvent"),
	Surge   = Instance.new("RemoteEvent"),
}

FakeEvents.Screech.Name  = "Screech"
FakeEvents.Shade.Name    = "ShadeResult"
FakeEvents.A90.Name      = "A90"
FakeEvents.Surge.Name    = "SurgeRemote"

FakeEvents.Screech_Real = RemotesFolder:WaitForChild("Screech")
FakeEvents.Shade_Real   = RemotesFolder:WaitForChild("ShadeResult")
FakeEvents.A90_Real     = RemotesFolder:FindFirstChild("A90")
FakeEvents.Surge_Real   = RemotesFolder:FindFirstChild("SurgeRemote")

if RemotesFolder:FindFirstChild("FootstepRemoteThatWeNeed") then
    local RealRemote = RemotesFolder:FindFirstChild("FootstepRemoteThatWeNeed")
    RealRemote:Destroy()

    local FakeRemote = Instance.new("RemoteEvent", RemotesFolder)
    FakeRemote.Name = "FootstepRemoteThatWeNeed"
end

Globals.FogInstances = {}
Globals.OldFog = Services.Lighting.FogEnd

for _, Object in Services.Lighting:GetChildren() do
	if Object:IsA("Atmosphere") then
		Object:SetAttribute("Density_Old", Object.Density)

		local AtmoConnection = Object:GetPropertyChangedSignal("Density"):Connect(function()
			if Object.Density ~= 0 then
				Object:SetAttribute("Density_Old", Object.Density)
			end
			if Toggles.RemoveCameraFog.Value then
				Object.Density = 0
			end
		end)

		Object.Destroying:Once(function()
			AtmoConnection:Disconnect()
			local Position = table.find(Globals.FogInstances, Object)
			if Position then table.remove(Globals.FogInstances, Position) end
		end)

		table.insert(Connections, AtmoConnection)
		table.insert(Globals.FogInstances, Object)
	end
end

Globals.SeekNodesFolder = Instance.new("Folder", Services.Workspace)
Globals.SeekNodesFolder.Name = Ostium.ESPLibrary:GenerateRandomString()

Globals.RoomsNodesFolder = Instance.new("Folder", Services.Workspace)
Globals.RoomsNodesFolder.Name = Ostium.ESPLibrary:GenerateRandomString()

Globals.ArchivesESPFolder = Instance.new("Folder", Services.Workspace)
Globals.ArchivesESPFolder.Name = Ostium.ESPLibrary:GenerateRandomString()

Functions.SendChat = function(Message)
	local Folder = Services.ReplicatedStorage:FindFirstChild("DefaultChatSystemEvents") or Instance.new("Folder")
	local Event = Folder:FindFirstChild("SayMessageRequest") or Instance.new("RemoteEvent")
	Event:FireServer(Message, "All")
	local Channel = (Services.TextChatService:FindFirstChild("TextChannels") and Services.TextChatService.TextChannels:FindFirstChild("RBXGeneral")) or Instance.new("TextChannel")
	Channel:SendAsync(Message)
end

Functions.IsCrouching = function()
	if Floor == "Fools" or Floor == "OldHotel" then
		return Character:GetAttribute("Crouching")
	end
	return CollisionPart.CollisionGroup == "PlayerCrouching"
end

Functions.GetInjuriesSpeed = function()
	return 0.075 * (Humanoid.MaxHealth - Humanoid.Health)
end

Functions.GetCurrentSpeed = function()
	local Speed = 15
	Speed += Character:GetAttribute("SpeedBoost") or 0
	Speed += Character:GetAttribute("SpeedBoostBehind") or 0
	Speed += Character:GetAttribute("SpeedBoostExtra") or 0
	Speed += (Floor == "Party" and 10 or 0)
	Speed += (LiveModifiers:FindFirstChild("PlayerFast") and 3 or 0)
	Speed += (LiveModifiers:FindFirstChild("PlayerFaster") and 6 or 0)
	Speed += (LiveModifiers:FindFirstChild("PlayerFastest") and 20 or 0)
	Speed -= (LiveModifiers:FindFirstChild("PlayerSlow") and 3 or 0)
	Speed -= (LiveModifiers:FindFirstChild("PlayerSlowHealth") and Functions.GetInjuriesSpeed() or 0)
	if Functions.IsCrouching() then
		if LiveModifiers:FindFirstChild("PlayerCrouchSlow") then
			Speed -= 8
		elseif LiveModifiers:FindFirstChild("PlayerSlow") then
			Speed -= 8
		else
			Speed -= 5
		end
	end
	return Speed
end

Functions.GetMousePosition = function()
	if Library.IsMobile then
		return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
	end
	local MouseLocation = Services.UserInputService:GetMouseLocation()
	return Vector2.new(MouseLocation.X, MouseLocation.Y)
end

Functions.FormatOxygen = function(Oxygen)
	return "Oxygen: " .. (math.floor(Oxygen * 10) / 10) .. "%"
end

Functions.IsHidePersistent = function()
	return Floor == "Mines"
		or Floor == "Ripple"
		or Floor == "Party"
		or LiveModifiers:FindFirstChild("HideLevel2") ~= nil
end

Functions.GetPlayerFromMouse = function(TargetPart, MaxDistance)
	local Closest
	local ClosestDistance = math.huge

	for _, Player in Services.Players:GetPlayers() do
		local Char = Player.Character
		if Char then
			local Target = Char:FindFirstChild(TargetPart)
			if Target then
				local Result = Camera:WorldToViewportPoint(Target.Position)
				local ScreenPos = Vector2.new(Result.X, Result.Y)
				local Distance = (Functions.GetMousePosition() - ScreenPos).Magnitude
				if Player.Name ~= LocalPlayer.Name and Distance < ClosestDistance and Distance < MaxDistance then
					Closest = Target
					ClosestDistance = Distance
				end
			end
		end
	end
	return Closest
end

local EntityDistances = {
	["RushMoving"]    = 85,
	["AmbushMoving"]  = 150,
	["A60"]           = 125,
	["A120"]          = 85,
	["GlitchRush"]    = 90,
	["GlitchAmbush"]  = 175,
	["BackdoorRush"]  = 85,
	["CustomEntity"]  = 85,
}

local AutoGodmodeEntityNames = {
	["RushMoving"] = "Rush",
	["AmbushMoving"] = "Ambush",
	["Scribbles"] = "Scribbles",
	["BashMoving"] = "Bash",
	["FrozenAmbush"] = "Frozen Ambush",
	["GlitchRush"] = "RNIUSHCG==",
	["GlitchAmbush"] = "AR0xMBUSH",
	["A60"] = "A-60",
	["A120"] = "A-120",
	["BackdoorRush"] = "Blitz",
}

local AutoGodmodeState = {
	Forced = false,
	Elapsed = 0,
}

local AlmaRemoteBlocklist = {
	Noticed = true,
	AlmaSpotted = true,
	AlmaMinigameFail = true,
}

local AlmaModelNames = {
	Alma = true,
	CutsceneAlma = true,
}

local AlmaTriggerNames = {
	NoticeTrigger = true,
}

local ArchivesChairNames = {
	ArchivesOfficeChair = true,
}

local ArchivesChairPromptModes = {
	SeatPrompt = "SeatedInSeat",
	CartPrompt = "PushingCart",
	InteractPrompt = "SeatedInSeat",
}

Functions.GetNearestEntity = function(CheckDisabled, List, UseRaycasting)
	local Nearest = { Distance = math.huge, Object = nil }

	for _, Entity in Services.Workspace:GetChildren() do
		if Entity and EntityDistances[Entity.Name] and Entity.PrimaryPart then
			local EntityData = Entities[Entity.Name]
			if not (List and List[EntityData.Alias]) then
				local Distance = LocalPlayer:DistanceFromCharacter(Entity.PrimaryPart.Position)
				if Distance < EntityDistances[Entity.Name] and Distance < Nearest.Distance then
					if not CheckDisabled or Entity:GetAttribute("Inactive") ~= true then
						Nearest.Distance = Distance
						Nearest.Object = Entity
					end
				end
			end
		end
	end
	return Nearest.Object
end

Functions.GetAutoGodmodeEntity = function()
	for _, Object in Services.Workspace:GetChildren() do
		if AutoGodmodeEntityNames[Object.Name] and Object:GetAttribute("Inactive") ~= true then
			return Object
		end
	end
end

Functions.GetNearestFigure = function()
	local Nearest = { Distance = math.huge, Object = nil }
	local FigureNames = { FigureRig = true, FigureRagdoll = true, Figure = true }

	for _, Object in Objects.Entities do
		if Object:IsA("Model") and Object.PrimaryPart and FigureNames[Object.Name] then
			local Distance = LocalPlayer:DistanceFromCharacter(Object.PrimaryPart.Position)
			if Distance < Nearest.Distance and Distance < 25 then
				Nearest.Distance = Distance
				Nearest.Object = Object
			end
		end
	end
	return Nearest.Object
end

Functions.GetNearestHidingSpot = function()
	local Nearest = { Distance = math.huge, Object = nil }
	local LastHideSpot = Character:FindFirstChild("LastHideSpot")

	for _, Object in Objects.HidingSpots do
		local Prompt = Object:FindFirstChild("HidePrompt") or Object:FindFirstChild("InteractPrompt", true)
		local Root = Object.PrimaryPart or (Prompt and Prompt.Parent:IsA("BasePart") and Prompt.Parent) or Object:FindFirstChildWhichIsA("BasePart")
		if Prompt and Root then
			local Distance = LocalPlayer:DistanceFromCharacter(Root.Position)
			if Distance < Prompt.MaxActivationDistance and Distance < Nearest.Distance then
				local Persistent = Functions.IsHidePersistent()
				if not Persistent or (LastHideSpot and LastHideSpot.Value ~= Object) or not LastHideSpot then
					Nearest.Distance = Distance
					Nearest.Object = Object
				end
			end
		end
	end
	return Nearest.Object
end

Functions.GetNearestTurnNode = function()
	local Nearest = { Distance = math.huge, Object = nil }

	for _, Node in Objects.SeekNodes do
		local Distance = LocalPlayer:DistanceFromCharacter(Node.Position)
		if Distance < Options.AutoSteerMinecartTurnDistance.Value and Distance < Nearest.Distance then
			Nearest.Distance = Distance
			Nearest.Object = Node
		end
	end
	return Nearest.Object
end

Functions.GetNearestDuckBoard = function()
	local Nearest = { Distance = math.huge, Object = nil }

	for _, Board in Objects.SeekDuckBoards do
		if Board.PrimaryPart then
			local Distance = LocalPlayer:DistanceFromCharacter(Board.PrimaryPart.Position)
			if Distance < Options.AutoSteerMinecartDuckDistance.Value and Distance < Nearest.Distance then
				Nearest.Distance = Distance
				Nearest.Object = Board
			end
		end
	end
	return Nearest.Object
end

Functions.GetCurrentAnchor = function()
	local AnchorCode = Globals.MainUI.AnchorHintFrame.AnchorCode.Text
	for _, Anchor in Objects.Objectives do
		if Anchor.Name == "MinesAnchor" and Anchor:FindFirstChild("Sign") then
			if Anchor.Sign.TextLabel.Text == AnchorCode then
				return Anchor
			end
		end
	end
end

Functions.GetMinecart = function()
	return Camera:FindFirstChild("MinecartRig") ~= nil
end

Functions.HasItem = function(Name, OnlyCharacter)
	if not OnlyCharacter and LocalPlayer.Backpack:FindFirstChild(Name) then
		return LocalPlayer.Backpack:FindFirstChild(Name)
	elseif Character:FindFirstChild(Name) then
		return Character:FindFirstChild(Name)
	end
end

Functions.GetFlyVelocity = function()
	if Humanoid.MoveDirection == Vector3.zero then
		return Humanoid.MoveDirection
	end
	local LookFlat = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
	local FlatFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + LookFlat)
	local Velocity = (Camera.CFrame * CFrame.new(FlatFrame:VectorToObjectSpace(Humanoid.MoveDirection))).Position - Camera.CFrame.Position
	if Velocity == Vector3.zero then
		return Velocity
	end
	return Velocity.Unit
end

Functions.DisconnectConnection = function(Key)
	local Connection = Connections[Key]
	if Connection then
		pcall(function() Connection:Disconnect() end)
		Connections[Key] = nil
	end
end

Functions.SetControlValue = function(Control, Value)
	if not Control then return end
	if Control.SetValue then
		Control:SetValue(Value)
	else
		Control.Value = Value
	end
end

Functions.SetLadderSpeedOverride = function(Climbing)
	local State = Globals.LadderSpeedOverride
	if Climbing and not State.Active then
		State.Active = true
		State.PreviousToggle = Toggles.SpeedBoostToggle.Value
		State.PreviousSpeed = Options.SpeedBoostSlider.Value
		Functions.SetControlValue(Toggles.SpeedBoostToggle, true)
		Functions.SetControlValue(Options.SpeedBoostSlider, Options.LadderClimbSpeed.Value)
	elseif not Climbing and State.Active then
		State.Active = false
		Functions.SetControlValue(Options.SpeedBoostSlider, State.PreviousSpeed)
		Functions.SetControlValue(Toggles.SpeedBoostToggle, State.PreviousToggle)
	end
end

Functions.GetFiredampModule = function()
	local ModulesClient = Services.ReplicatedStorage:FindFirstChild("ModulesClient")
	local UpdatedModules = ModulesClient and ModulesClient:FindFirstChild("ClientUpdatedModules")
	if not UpdatedModules then return nil, nil end
	return UpdatedModules:FindFirstChild(FeatureConfig.Firedamp.OriginalModuleName)
		or UpdatedModules:FindFirstChild(FeatureConfig.Firedamp.DisabledModuleName), UpdatedModules
end

Functions.RemoveFiredampCameraEffect = function(Object)
	if Object and FeatureConfig.Firedamp.CameraEffects[Object.Name] then
		Object:Destroy()
	end
end

Functions.SetFiredampState = function(Value)
	Functions.DisconnectConnection("AntiFiredampCamera")
	Functions.DisconnectConnection("AntiFiredampModule")

	local FiredampModule, UpdatedModules = Functions.GetFiredampModule()
	if FiredampModule then
		FiredampModule.Name = Value
			and FeatureConfig.Firedamp.DisabledModuleName
			or FeatureConfig.Firedamp.OriginalModuleName
	end

	for _, Room in CurrentRooms:GetChildren() do
		if Room:GetAttribute("Firedamp_Old") == nil then
			local CurrentValue = Room:GetAttribute("Firedamp")
			Room:SetAttribute("Firedamp_Old", CurrentValue ~= nil and CurrentValue or false)
		end
		if Value then
			Room:SetAttribute("Firedamp", false)
		else
			Room:SetAttribute("Firedamp", Room:GetAttribute("Firedamp_Old"))
		end
	end

	if Value and Camera then
		for _, Object in Camera:GetChildren() do
			Functions.RemoveFiredampCameraEffect(Object)
		end
		Connections.AntiFiredampCamera = Camera.ChildAdded:Connect(Functions.RemoveFiredampCameraEffect)
	end

	if Value and UpdatedModules then
		Connections.AntiFiredampModule = UpdatedModules.ChildAdded:Connect(function(Object)
			if Object.Name == FeatureConfig.Firedamp.OriginalModuleName then
				Object.Name = FeatureConfig.Firedamp.DisabledModuleName
			end
		end)
	end
end

Functions.SetObjectEnabled = function(Object, Value)
	if not Object then return end
	pcall(function() Object.Enabled = Value end)
end

Functions.ApplyHasteCameraEffects = function(Value)
	if not Camera then return end
	local HasteActive = Services.Workspace:FindFirstChild(FeatureConfig.Haste.EntityName) ~= nil
	for _, Object in Camera:GetChildren() do
		if Object.Name == FeatureConfig.Haste.CameraEffectName then
			Functions.SetObjectEnabled(Object, not (Value and HasteActive))
		end
	end
end

Functions.BindHasteAmbience = function()
	Functions.DisconnectConnection("HasteAmbienceChanged")
	if not Toggles.DisableHasteJumpscare or not Toggles.DisableHasteJumpscare.Value then return end

	local ClientRemote = FloorReplicated:FindFirstChild("ClientRemote")
	local Haste = ClientRemote and ClientRemote:FindFirstChild("Haste")
	local Ambience = Haste and Haste:FindFirstChild("Ambience")
	if not Ambience or not Ambience:IsA("Sound") then return end

	pcall(function() Ambience.Playing = false end)
	Connections.HasteAmbienceChanged = Ambience:GetPropertyChangedSignal("Playing"):Connect(function()
		if Toggles.DisableHasteJumpscare.Value and Ambience.Playing then
			Ambience.Playing = false
		end
	end)
end

Functions.SetHasteJumpscareState = function(Value)
	Functions.DisconnectConnection("NoHasteCameraAdded")
	Functions.DisconnectConnection("NoHasteEntityAdded")
	Functions.DisconnectConnection("NoHasteEntityRemoved")
	Functions.DisconnectConnection("HasteAmbienceChanged")

	if Value then
		Functions.BindHasteAmbience()
		if Camera then
			Connections.NoHasteCameraAdded = Camera.ChildAdded:Connect(function(Object)
				if Object.Name == FeatureConfig.Haste.CameraEffectName then
					task.defer(Functions.ApplyHasteCameraEffects, true)
				end
			end)
		end
		Connections.NoHasteEntityAdded = Services.Workspace.ChildAdded:Connect(function(Object)
			if Object.Name == FeatureConfig.Haste.EntityName then
				task.defer(Functions.ApplyHasteCameraEffects, true)
			end
		end)
		Connections.NoHasteEntityRemoved = Services.Workspace.ChildRemoved:Connect(function(Object)
			if Object.Name == FeatureConfig.Haste.EntityName then
				task.defer(Functions.ApplyHasteCameraEffects, true)
			end
		end)
	end

	Functions.ApplyHasteCameraEffects(Value)
end

Functions.SetNamedLightingEffectsRemoved = function(Value)
	if Value then
		for _, Object in Services.Lighting:GetChildren() do
			if FeatureConfig.Fog.DestroyNames[Object.Name] then
				local Clone
				pcall(function() Clone = Object:Clone() end)
				if Clone then
					table.insert(Globals.RemovedLightingEffects, {
						Clone = Clone,
						Parent = Object.Parent,
					})
				end
				local Position = table.find(Globals.FogInstances, Object)
				if Position then table.remove(Globals.FogInstances, Position) end
				Object:Destroy()
			end
		end
	elseif #Globals.RemovedLightingEffects > 0 then
		Globals.RestoringLightingEffects = true
		for _, Entry in Globals.RemovedLightingEffects do
			if Entry.Clone and Entry.Parent then
				pcall(function() Entry.Clone.Parent = Entry.Parent end)
			end
		end
		table.clear(Globals.RemovedLightingEffects)
		Globals.RestoringLightingEffects = false
	end
end

Functions.ApplyJeffBypass = function(Model, Value)
	if not Model or not Model:IsA("Model") or Model.Name ~= "JeffTheKiller" then return end
	for _, Part in Model:GetDescendants() do
		if Part:IsA("BasePart") then
			Part.CanTouch = not Value
		end
	end
end

Functions.SetAntiJeffState = function(Value)
	Functions.DisconnectConnection("AntiJeffAdded")
	Functions.DisconnectConnection("AntiJeffLoop")

	for _, Object in CurrentRooms:GetDescendants() do
		if Object:IsA("Model") and Object.Name == "JeffTheKiller" then
			if not table.find(Objects.Jeffs, Object) then table.insert(Objects.Jeffs, Object) end
			Functions.ApplyJeffBypass(Object, Value)
		end
	end

	if not Value then return end

	Connections.AntiJeffAdded = CurrentRooms.DescendantAdded:Connect(function(Object)
		if Object:IsA("Model") and Object.Name == "JeffTheKiller" then
			if not table.find(Objects.Jeffs, Object) then table.insert(Objects.Jeffs, Object) end
			Functions.ApplyJeffBypass(Object, true)
		elseif Object:IsA("BasePart") then
			local Jeff = Object:FindFirstAncestor("JeffTheKiller")
			if Jeff and Jeff:IsA("Model") then Object.CanTouch = false end
		end
	end)

	local Elapsed = 0
	Connections.AntiJeffLoop = Services.RunService.Heartbeat:Connect(function(DeltaTime)
		Elapsed += DeltaTime
		if Elapsed < FeatureConfig.AntiJeff.ScanInterval then return end
		Elapsed = 0
		for Index = #Objects.Jeffs, 1, -1 do
			local Object = Objects.Jeffs[Index]
			if Object.Parent then
				Functions.ApplyJeffBypass(Object, true)
			else
				table.remove(Objects.Jeffs, Index)
			end
		end
	end)
end

Functions.TryPushMinecart = function(Model)
	if not Model or Model.Name ~= "MinecartMoving" or not Ostium.Environment.fireproximityprompt then return end
	local Cart = Model:FindFirstChild("Cart")
	local Prompt = Cart and Cart:FindFirstChild("PushPrompt")
	local PromptPart = Prompt and (Prompt.Parent:IsA("BasePart") and Prompt.Parent or Prompt:FindFirstAncestorWhichIsA("BasePart"))
	if not Prompt or not PromptPart or not RootPart then return end

	local MaxDistance = Prompt.MaxActivationDistance or 10
	if (RootPart.Position - PromptPart.Position).Magnitude <= MaxDistance then
		Ostium.Environment.fireproximityprompt(Prompt)
	end
end

Functions.SetAutoMinecartPushState = function(Value)
	Functions.DisconnectConnection("AutoMinecartPushAdded")
	Functions.DisconnectConnection("AutoMinecartPushLoop")
	if not Value then return end

	Connections.AutoMinecartPushAdded = CurrentRooms.DescendantAdded:Connect(function(Object)
		if Object.Name == "MinecartMoving" then
			task.defer(Functions.TryPushMinecart, Object)
		end
	end)

	local Elapsed = 0
	Connections.AutoMinecartPushLoop = Services.RunService.Heartbeat:Connect(function(DeltaTime)
		Elapsed += DeltaTime
		if Elapsed < FeatureConfig.MinecartPush.ScanInterval then return end
		Elapsed = 0
		for _, Object in CurrentRooms:GetChildren() do
			if Object.Name == "MinecartMoving" then
				Functions.TryPushMinecart(Object)
			end
		end
	end)
end

Functions.GetCurrentRoomDoor = function()
	local RoomNumber = LocalPlayer:GetAttribute("CurrentRoom") or LatestRoom.Value
	local Room = CurrentRooms:FindFirstChild(tostring(RoomNumber)) or CurrentRooms:FindFirstChild(tostring(LatestRoom.Value))
	local Door = Room and Room:FindFirstChild("Door")
	if not Door then return Room, nil, nil end

	local DoorPart
	if Door:IsA("BasePart") then
		DoorPart = Door
	else
		DoorPart = Door:FindFirstChild("Door")
		if DoorPart and not DoorPart:IsA("BasePart") then DoorPart = nil end
		DoorPart = DoorPart or Door.PrimaryPart or Door:FindFirstChildWhichIsA("BasePart", true)
	end
	return Room, Door, DoorPart
end

Functions.IsLockedDoor = function(Door)
	if not Door then return false end
	local LockedAttribute = Door:GetAttribute("Locked")
	if LockedAttribute ~= nil then return LockedAttribute == true end
	return Door.Name:lower():find("locked", 1, true) ~= nil
		or Door:FindFirstChild("Lock", true) ~= nil
end

Functions.WaitForGlitchCube = function(Duration)
	local Started = tick()
	while tick() - Started < Duration do
		if Globals.GlitchCube.CancelRequested or not Toggles.GetGlitchCube.Value or Library.Unloaded then return false end
		task.wait(0.1)
	end
	return true
end

Functions.RestoreGlitchCubeMovement = function()
	if not Globals.GlitchCube.Running then return end
	Functions.SetControlValue(Toggles.VelocityManipulationToggle, Globals.GlitchCube.PreviousVelocityManipulation)
end

local DEFAULT_HIP_HEIGHT = 2.3949999809265137
local GODMODE_HIP_HEIGHT = 0.05
local POOL_SHOCK_HIP_HEIGHT = 3
local FMN_MISSING_OBJECT_CONTAINERS = {
	Deletable = true,
	Fixed = true,
}
Functions.ShouldUseRootOffsetSpoof = function()
	if Floor == "Fools" or Floor == "OldHotel" then
		return false
	end
	return (Toggles.PositionSpoof and Toggles.PositionSpoof.Value)
		or (Toggles.AntiPoolShock and Toggles.AntiPoolShock.Value)
end

Functions.ApplyRootOffsetSpoofState = function()
	if not RootPart or Floor == "Fools" or Floor == "OldHotel" then return end

	Globals.RootOffsetSpoofApplied = Globals.RootOffsetSpoofApplied == true
	local ShouldApply = Functions.ShouldUseRootOffsetSpoof() == true
	if ShouldApply == Globals.RootOffsetSpoofApplied then
		Functions.ApplyHipHeightState()
		return
	end

	RootPart.CFrame = RootPart.CFrame * CFrame.new(0, ShouldApply and -2.346 or 2.346, 0)
	Globals.RootOffsetSpoofApplied = ShouldApply
	Functions.ApplyHipHeightState()

	if ShouldApply and RemotesFolder and RemotesFolder:FindFirstChild("Crouch") then
		RemotesFolder.Crouch:FireServer(true, true)
	end
end

Functions.ApplyHipHeightState = function()
	if not Humanoid then return end
	if Toggles.PositionSpoof and Toggles.PositionSpoof.Value and Floor ~= "Fools" and Floor ~= "OldHotel" then
		Humanoid.HipHeight = GODMODE_HIP_HEIGHT
	elseif Toggles.AntiPoolShock and Toggles.AntiPoolShock.Value then
		Humanoid.HipHeight = POOL_SHOCK_HIP_HEIGHT
	else
		Humanoid.HipHeight = DEFAULT_HIP_HEIGHT
	end
end

Functions.GetRoomFromObject = function(Object)
	local Current = Object
	while Current and Current.Parent do
		if Current.Parent == CurrentRooms then
			return Current
		end
		Current = Current.Parent
	end
end

Functions.GetObjectBounds = function(Object)
	if not Object then return end
	if Object:IsA("BasePart") then
		return Object.CFrame, Object.Size
	end
	if Object:IsA("Model") then
		local Ok, CFrameValue, SizeValue = pcall(function()
			return Object:GetBoundingBox()
		end)
		if Ok then
			return CFrameValue, SizeValue
		end
		local Root = Object.PrimaryPart or Object:FindFirstChildWhichIsA("BasePart", true)
		if Root then
			return Root.CFrame, Root.Size
		end
	end
end

Functions.GetObjectTrackingKey = function(Object, RoomName, ContainerName)
	if not Object then return end
	local Success, DebugId = pcall(function()
		return Object:GetDebugId(0)
	end)
	if Success and DebugId then
		return string.format("%s/%s/%s", RoomName, ContainerName, DebugId)
	end
	return string.format("%s/%s/%s", RoomName, ContainerName, Object:GetFullName())
end

Functions.GetModelRoot = function(Object)
	if not Object then return end
	if Object:IsA("BasePart") then
		return Object
	end
	if Object:IsA("Model") then
		return Object.PrimaryPart or Object:FindFirstChild("Root") or Object:FindFirstChild("HumanoidRootPart") or Object:FindFirstChildWhichIsA("BasePart", true)
	end
	return Object:FindFirstChildWhichIsA("BasePart", true)
end

Functions.GetNearestArchivesChair = function()
	if not RootPart then return end

	local Nearest = { Distance = math.huge, Object = nil }
	for _, Object in Services.Workspace:GetDescendants() do
		if ArchivesChairNames[Object.Name] then
			local Pivot = Functions.GetModelRoot(Object)
			if Pivot then
				local Distance = (Pivot.Position - RootPart.Position).Magnitude
				if Distance < Nearest.Distance then
					Nearest.Distance = Distance
					Nearest.Object = Object
				end
			end
		end
	end

	return Nearest.Object
end

Functions.GetArchivesChairPrompt = function(Object)
	if not Object then return end
	for PromptName in ArchivesChairPromptModes do
		local Prompt = Object:FindFirstChild(PromptName, true)
		if Prompt and Prompt:IsA("ProximityPrompt") then
			return Prompt
		end
	end
	return Object:FindFirstChildWhichIsA("ProximityPrompt", true)
end

Functions.TryRestoreArchivesAnticheatBypass = function(Reason)
	local CurrentCharacter = Character
	if not CurrentCharacter or not RootPart then return end
	if not Toggles.ArchivesAnticheatBypass or not Toggles.ArchivesAnticheatBypass.Value then return end
	if GameData:FindFirstChild("ArchivesDayPhase") == nil then return end

	Globals.ArchivesAnticheatRecoveryState = Globals.ArchivesAnticheatRecoveryState or {
		Active = false,
		LastAttempt = 0,
		LastNotify = 0,
	}

	local RecoveryState = Globals.ArchivesAnticheatRecoveryState
	if RecoveryState.Active or os.clock() - RecoveryState.LastAttempt < 1.25 then return end

	RecoveryState.Active = true
	RecoveryState.LastAttempt = os.clock()

	if os.clock() - RecoveryState.LastNotify > 1 then
		RecoveryState.LastNotify = os.clock()
		Functions.Notify({
			Title = "Archives anticheat re-enabled.",
			Body = "Trying to restore it with a nearby chair" .. (Reason and (" (" .. Reason .. ").") or ".")
		})
	end

	task.spawn(function()
		local Chair = Functions.GetNearestArchivesChair()
		local Prompt = Functions.GetArchivesChairPrompt(Chair)
		if not Chair or not Prompt then
			RecoveryState.Active = false
			return
		end

		local MiscFolder = Services.Workspace:FindFirstChild("Misc")
		if not MiscFolder then
			MiscFolder = Instance.new("Folder")
			MiscFolder.Name = "Misc"
			MiscFolder.Parent = Services.Workspace
		end

		local TargetCFrame = RootPart.CFrame * CFrame.new(0, 0, -4)
		pcall(function()
			Chair.Parent = MiscFolder
			if Chair:IsA("Model") then
				Chair:PivotTo(TargetCFrame)
			elseif Chair:IsA("BasePart") then
				Chair.CFrame = TargetCFrame
			end
		end)

		task.wait(0.1)
		pcall(function()
			Functions.ForceFirePrompt(Prompt)
		end)

		local ModeName = ArchivesChairPromptModes[Prompt.Name] or "SeatedInSeat"
		task.wait(0.35)
		if Character == CurrentCharacter and Toggles.ArchivesAnticheatBypass and Toggles.ArchivesAnticheatBypass.Value then
			Functions.TryArchivesAnticheatBypass(ModeName)
		end

		task.wait(0.35)
		RecoveryState.Active = false
	end)
end

local ArchivesAnticheatModes = {
	SeatedInSeat = { RemoteName = "SeatControl", Label = "Seat" },
	PushingCart = { RemoteName = "CartControl", Label = "Cart" },
}

Functions.TryArchivesAnticheatBypass = function(AttributeName)
	local Config = ArchivesAnticheatModes[AttributeName]
	local CurrentCharacter = Character
	if not Config or not CurrentCharacter or not Toggles.ArchivesAnticheatBypass or not Toggles.ArchivesAnticheatBypass.Value then return end
	if GameData:FindFirstChild("ArchivesDayPhase") == nil then return end

	local IsModeActive = CurrentCharacter:GetAttribute(AttributeName) == true
	local IsMovementLocked = CurrentCharacter:GetAttribute("RestrictMovement") == true
	if not IsModeActive and not IsMovementLocked then return end

	Globals.ArchivesAnticheatBypassState = Globals.ArchivesAnticheatBypassState or {}
	local Stamp = os.clock()
	Globals.ArchivesAnticheatBypassState[AttributeName] = Stamp

	task.delay(0.25, function()
		if Character ~= CurrentCharacter then return end
		if not Toggles.ArchivesAnticheatBypass or not Toggles.ArchivesAnticheatBypass.Value then return end
		if GameData:FindFirstChild("ArchivesDayPhase") == nil then return end
		if Globals.ArchivesAnticheatBypassState[AttributeName] ~= Stamp then return end

		local ModeActive = CurrentCharacter:GetAttribute(AttributeName) == true
		local MovementLocked = CurrentCharacter:GetAttribute("RestrictMovement") == true
		if not ModeActive and not MovementLocked then return end

		pcall(function()
			CurrentCharacter:SetAttribute(AttributeName, false)
			if CurrentCharacter:GetAttribute("RestrictMovement") ~= nil then
				CurrentCharacter:SetAttribute("RestrictMovement", false)
			end
		end)

		local Remote = RemotesFolder and RemotesFolder:FindFirstChild(Config.RemoteName)
		if Remote and Remote:IsA("RemoteEvent") then
			pcall(function() Remote:FireServer() end)
		end

		if not Globals.ArchivesAnticheatNotified then
			Globals.ArchivesAnticheatNotified = true
			Functions.Notify({
				Title = "Archives anticheat bypassed.",
				Body = "Interact with a chair or cart again if the movement lock comes back."
			})
		end
	end)
end

Functions.RunGlitchCube = function()
	if Globals.GlitchCube.Running then return end
	Globals.GlitchCube.Running = true
	Globals.GlitchCube.CancelRequested = false
	Globals.GlitchCube.PreviousVelocityManipulation = Toggles.VelocityManipulationToggle.Value

	for _ = 1, FeatureConfig.GlitchCube.Attempts do
		if not Toggles.GetGlitchCube.Value or Library.Unloaded or not Character or not RootPart then break end

		local _, Door, DoorPart = Functions.GetCurrentRoomDoor()
		if Functions.IsLockedDoor(Door) and DoorPart then
			local Direction = Vector3.new(
				DoorPart.Position.X - RootPart.Position.X,
				0,
				DoorPart.Position.Z - RootPart.Position.Z
			)
			if Direction.Magnitude < 0.01 then
				Direction = Vector3.new(DoorPart.CFrame.LookVector.X, 0, DoorPart.CFrame.LookVector.Z)
			end
			if Direction.Magnitude < 0.01 then Direction = Vector3.new(0, 0, -1) end
			Direction = Direction.Unit
			local StartPosition = DoorPart.Position - (Direction * FeatureConfig.GlitchCube.DoorOffset)
			Character:PivotTo(CFrame.lookAt(StartPosition, DoorPart.Position))
			Functions.SetControlValue(Toggles.VelocityManipulationToggle, true)
			if not Functions.WaitForGlitchCube(FeatureConfig.GlitchCube.ManipulationDuration) then break end
			Functions.SetControlValue(Toggles.VelocityManipulationToggle, Globals.GlitchCube.PreviousVelocityManipulation)
		else
			Character:PivotTo(RootPart.CFrame + FeatureConfig.GlitchCube.OutsideMapOffset)
			if not Functions.WaitForGlitchCube(FeatureConfig.GlitchCube.ManipulationDuration) then break end
		end

		if not Functions.WaitForGlitchCube(FeatureConfig.GlitchCube.AttemptDelay) then break end
	end

	Functions.SetControlValue(Toggles.VelocityManipulationToggle, Globals.GlitchCube.PreviousVelocityManipulation)
	Globals.GlitchCube.Running = false
	if Toggles.GetGlitchCube.Value then
		Functions.SetControlValue(Toggles.GetGlitchCube, false)
	end
	Globals.GlitchCube.CancelRequested = false
end

Globals.PromptContainer = Instance.new("Folder")
Globals.PromptContainer.Name = "PromptContainer"
Globals.PromptContainer.Parent = GetHiddenContainer()

local ESPBlacklist = {}

Functions.AddESP = function(ESPOptions, RoomBased)
	local Object = ESPOptions.Object

	if table.find(ESPBlacklist, Object) then
		return
	end

	if RoomBased then
		local CurrentRoom = tonumber(LocalPlayer:GetAttribute("CurrentRoom"))
		local ObjectRoom = tonumber(Object:GetAttribute("ParentRoom"))

		if ObjectRoom == CurrentRoom or (table.find(Objects.Doors, Object) and ObjectRoom == CurrentRoom + 1) then
			Ostium.ESPLibrary:AddESP(ESPOptions)
		end

		local RoomConnection = LocalPlayer:GetAttributeChangedSignal("CurrentRoom"):Connect(function()
			if Ostium.ESPLibrary.ColorTable[Object] then
				ESPOptions.Color = Ostium.ESPLibrary.ColorTable[Object]
			end

			local NewCurrentRoom = tonumber(LocalPlayer:GetAttribute("CurrentRoom"))
			local ObjRoom = tonumber(Object:GetAttribute("ParentRoom"))

			if ObjRoom == NewCurrentRoom or (table.find(Objects.Doors, Object) and ObjRoom == NewCurrentRoom + 1) then
				Ostium.ESPLibrary:AddESP(ESPOptions)
			else
				Ostium.ESPLibrary:RemoveESP(Object)
			end
		end)

		table.insert(Connections, RoomConnection)
		ESPConnections[Object] = RoomConnection

		Object.Destroying:Once(function()
			RoomConnection:Disconnect()
			if Ostium then
				Ostium.ESPLibrary:RemoveESP(Object)
			end
			local Pos = table.find(Connections, RoomConnection)
			if Pos then table.remove(Connections, Pos) end
		end)
	else
		Ostium.ESPLibrary:AddESP(ESPOptions)
	end
end

Functions.RemoveESP = function(Object)
	local Conn = ESPConnections[Object]
	if Conn then
		Conn:Disconnect()
		ESPConnections[Object] = nil
		local Pos = table.find(Connections, Conn)
		if Pos then table.remove(Connections, Pos) end
	end
	Ostium.ESPLibrary:RemoveESP(Object)
end

Functions.BlacklistESP = function(Object)
	table.insert(ESPBlacklist, Object)
end

Functions.GetDoorNumber = function(Object)
	local DoorNumber = tonumber(Object.Parent.Name) or tonumber(Object.Parent.Parent.Name)
	if DoorNumber then
		DoorNumber = DoorNumber + 1
	end
	if Floor == "Mines" then
		DoorNumber = DoorNumber + 100
	end
	if Floor == "Backdoor" then
		DoorNumber = DoorNumber - 50
	end

	return tostring(DoorNumber)
end

Functions.GetLibraryCode = function()
	local Paper = Character:FindFirstChild("LibraryHintPaper")
		or Character:FindFirstChild("LibraryHintPaperHard")
		or LocalPlayer.Backpack:FindFirstChild("LibraryHintPaper")
		or LocalPlayer.Backpack:FindFirstChild("LibraryHintPaperHard")

	if Paper and Paper:FindFirstChild("UI") then
		local Code = {}
		local CodeLength = Floor == "Fools" and 10 or 5
		for I = 1, CodeLength do Code[I] = "_" end

		local HintChildren = LocalPlayer.PlayerGui.PermUI.Hints:GetChildren()
		local UIChildren = Paper.UI:GetChildren()

		for _, Hint in HintChildren do
			for _, UIChild in UIChildren do
				if Hint:IsA("ImageLabel") and UIChild:IsA("ImageLabel")
					and Hint.ImageRectOffset == UIChild.ImageRectOffset
					and Code[tonumber(UIChild.Name)]
				then
					Code[tonumber(UIChild.Name)] = Hint.TextLabel.Text
				end
			end
		end
		return table.concat(Code)
	end
	return Floor == "Fools" and "__________" or "_____"
end

Globals.UsedRandomCodes = {}
Functions.GetRandomCode = function()
    local CodeTemplate = Functions.GetLibraryCode()
    if not CodeTemplate then
        return nil
    end

    local NewCode
    local Tries = 0
    repeat
        NewCode = CodeTemplate:gsub("_", function()
            return tostring(math.random(0, 9))
        end)
        Tries = Tries + 1
    until not Globals.UsedRandomCodes[NewCode] or Tries >= 10

    Globals.UsedRandomCodes[NewCode] = true
    return NewCode
end

local Window = Library:CreateWindow({
	Title = "Ostium",
	Footer = OSTIUM_VERSION .. " | Ostium | Floor: " .. Floor,
	Icon = OSTIUM_ICON,
	NotifySide = "Right",
	ShowCustomCursor = false,
	AutoShow = true,
	Center = true,
	Resizable = true,
	ShowMobileButtons = true,
	UnlockMouseWhileOpen = true,
	GlobalSearch = true,
	TabPadding = 3,
	MenuFadeTime = 0,
	CornerRadius = 7,
})

Library.Scheme.AccentColor = Color3.fromRGB(255, 85, 85)
Library:UpdateColorsUsingRegistry()


local KeyTab = Ostium.Key:GateTab(Window)

local HomeTab = Ostium.Internal.RenderStartPane(Window)


Ostium.Key:FinishGate(KeyTab, HomeTab)

local Tabs = {
	General  = Window:AddTab("Player", "user"),
	Exploits = Window:AddTab("Exploits", "swords"),
	Visuals  = Window:AddTab("Render", "eye"),
	Floors   = Window:AddTab("Floors", "map"),
}

Groupboxes.General_Character = Tabs.General:AddLeftGroupbox("Movement")
Groupboxes.General_Character:AddToggle("SpeedBoostToggle", {
	Text = "Enable Walk Speed", Default = false, Tooltip = "Increases your walkspeed by the specified amount."
})
Groupboxes.General_Character:AddSlider("SpeedBoostSlider", {
	Text = "Walk Speed", Min = 0, Max = 100, Default = 0, Rounding = 0, Compact = true
})
Groupboxes.General_Character:AddSlider("LadderClimbSpeed", {
	Text = "Ladder Speed",
	Min = FeatureConfig.LadderSpeed.Min,
	Max = FeatureConfig.LadderSpeed.Max,
	Default = FeatureConfig.LadderSpeed.Default,
	Rounding = 0,
	Compact = true,
})
Groupboxes.General_Character:AddToggle("FlyToggle", {
	Text = "Flight", Default = false, Tooltip = "Allows you to freely fly around the map."
})
Toggles.FlyToggle:AddKeyPicker("FlyKeybind", {
	Text = "Flight", Default = "F", Mode = "Toggle", SyncToggleState = true
})
Groupboxes.General_Character:AddSlider("FlySpeed", {
	Text = "Flight Speed", Min = 0, Max = 115, Default = 20, Rounding = 0, Compact = true
})
Groupboxes.General_Character:AddDivider()
Groupboxes.General_Character:AddToggle("NoclipToggle", {
	Text = "No Clip", Default = false, Tooltip = "Allows your character to pass through solid objects."
})
Groupboxes.General_Character:AddToggle("RemoveClosetDelay", {
	Text = "Instant Closet Exit", Default = false,
	Tooltip = "Removes the short window where you can't exit out of a closet after the animation finishes."
})
Groupboxes.General_Character:AddToggle("RemoveAcceleration", {
	Text = "No Acceleration", Default = false, Tooltip = "Prevents your character from sliding while moving."
})

local CustomPhysics

Options.SpeedBoostSlider:OnChanged(function(Value)
	if RemotesFolder:FindFirstChild("Crouch") then
		RemotesFolder.Crouch:FireServer(Value and true or Functions.IsCrouching(), true)
	end
end)

Toggles.NoclipToggle:AddKeyPicker("NoclipKeybind", {
	Text = "No Clip", Default = "N", Mode = "Toggle", SyncToggleState = true
})
Toggles.RemoveAcceleration:OnChanged(function(Value)
	for Index, Old in PartProperties do
		Index.CustomPhysicalProperties = Value and CustomPhysics or Old
	end
end)

Groupboxes.General_Character:AddDivider()
Groupboxes.General_Character:AddToggle("EnableCharacterJump", {
	Text = "Allow Jump", Default = false, Tooltip = "Allows your character to jump."
})
Groupboxes.General_Character:AddToggle("EnableCharacterSlide", {
	Text = "Allow Slide", Default = false, Tooltip = "Allows your character to slide."
})
Groupboxes.General_Character:AddToggle("InfiniteJumps", {
	Text = "Inf Jump", Default = false, Tooltip = "Allows you to jump while in the air."
})
Groupboxes.General_Character:AddToggle("JumpBoostToggle", {
	Text = "Enable Jump Boost", Default = false, Tooltip = "Increases your jump power to the selected value."
})
Groupboxes.General_Character:AddSlider("JumpBoostSlider", {
	Text = "Jump Power",
	Min = FeatureConfig.JumpBoost.Min,
	Max = FeatureConfig.JumpBoost.Max,
	Default = FeatureConfig.JumpBoost.Default,
	Rounding = 0,
	Compact = true,
})

local OldJump = false
local OldSlide = false

Toggles.SpeedBoostToggle:OnChanged(function(Value)
	if Humanoid then
		Humanoid.WalkSpeed = Functions.GetCurrentSpeed() + (Value and Options.SpeedBoostSlider.Value or 0)
	end
end)
Options.LadderClimbSpeed:OnChanged(function(Value)
	if Globals.LadderSpeedOverride.Active then
		Functions.SetControlValue(Options.SpeedBoostSlider, Value)
	end
end)
Toggles.JumpBoostToggle:OnChanged(function(Value)
	if Humanoid then
		Humanoid.JumpPower = Value and Options.JumpBoostSlider.Value or (Globals.BaseJumpPower or 5)
	end
end)
Options.JumpBoostSlider:OnChanged(function(Value)
	if Humanoid and Toggles.JumpBoostToggle.Value then
		Humanoid.JumpPower = Value
	end
end)
Toggles.EnableCharacterJump:OnChanged(function(Value)
	if Character then
		Character:SetAttribute("CanJump", Value and true or OldJump)
	end
end)
Toggles.EnableCharacterSlide:OnChanged(function(Value)
	if Character then
		Character:SetAttribute("CanSlide", Value and true or OldSlide)
	end
end)

Groupboxes.General_Self = Tabs.General:AddRightGroupbox("Utility")
Groupboxes.General_Self:AddToggle("DoorReachToggle", {
	Text = "Extended Door Range", Default = false, Tooltip = "Allows you to open doors from further away."
})
Groupboxes.General_Self:AddToggle("DoorNoclip", {
	Text = "Door Noclip", Default = false, Tooltip = "Disables collision on doors so you can walk through them."
})
Groupboxes.General_Self:AddToggle("DisableIdleKick", {
	Text = "Anti AFK", Default = false, Tooltip = "Prevents the kick from being idle for 20 minutes."
})
Toggles.DisableIdleKick:OnChanged(function(Value)
	if Functions.CheckCompatability({"getconnections"}) then
		for _, Conn in Ostium.Environment.getconnections(LocalPlayer.Idled) do
			if Value then Conn:Disable() else Conn:Enable() end
		end
	end
end)
LocalPlayer.Idled:Connect(function()
	if Toggles.DisableIdleKick.Value then
		Services.VirtualUser:CaptureController()
		Services.VirtualUser:ClickButton2(Vector2.new())
	end
end)

Groupboxes.General_Self:AddDivider()
Groupboxes.General_Self:AddSlider("PromptReachSlider", {
	Text = "Interact Range", Min = 1, Max = 2, Default = 1, Rounding = 1, Compact = true
})
Groupboxes.General_Self:AddToggle("InstantPrompts", {
	Text = "Instant Interact", Default = false, Tooltip = "Allows you to trigger all prompts instantly."
})
Groupboxes.General_Self:AddToggle("PromptClip", {
	Text = "Interact Through Walls", Default = false, Tooltip = "Allows you to interact with prompts through walls."
})

Options.PromptReachSlider:OnChanged(function(Value)
	for _, Prompt in Objects.Prompts do
		Prompt.MaxActivationDistance = Prompt:GetAttribute("MaxActivationDistance_Old") * Value
	end
end)
Toggles.InstantPrompts:OnChanged(function(Value)
	for _, Prompt in Objects.Prompts do
		Prompt.HoldDuration = Value and 0 or Prompt:GetAttribute("HoldDuration_Old")
	end
end)
Toggles.PromptClip:OnChanged(function(Value)
	for _, Prompt in Objects.Prompts do
		Prompt.RequiresLineOfSight = Value and false or Prompt:GetAttribute("RequiresLineOfSight_Old")
	end
end)

Groupboxes.Self_Automation = Tabs.General:AddLeftGroupbox("Routines")
Groupboxes.Self_Automation:AddToggle("AutoBreakerBox", {
	Text = "Auto Breaker", Default = false, Tooltip = "Automatically solves the breaker box."
})
Groupboxes.Self_Automation:AddToggle("AutoSolveAnchors", {
	Text = "Auto Anchors", Default = false,
	Tooltip = "Automatically enters the correct code into anchors when you are near them."
})
Toggles.AutoBreakerBox:OnChanged(function(Value)
	if Value and CurrentRooms:FindFirstChild("ElevatorBreaker", true) then
		if not Globals.BreakerBoxInteracted then
			if not Globals.BreakerBoxNotified then
				Functions.Notify({ Title = "Interact with the breaker box.", Body = "It will be automatically solved." })
				Globals.BreakerBoxInteracted = true
			end
		else
			RemotesFolder.EBF:FireServer()
		end
	end
end)

Groupboxes.Self_Automation:AddToggle("AutoHeartbeatMinigame", { Text = "Auto Heartbeat", Default = false, Tooltip = "Prevents the 'Figure' minigame from ever failing.", Disabled = not Functions.CheckCompatability({"hookmetamethod", "newcclosure", "getnamecallmethod"}), DisabledTooltip = Globals.IncompatibleMessage })
Groupboxes.Self_Automation:AddDivider()
Groupboxes.Self_Automation:AddToggle("AutoUnlockPadlockToggle", {
	Text = "Auto Padlock", Default = false, Tooltip = "Automatically enters the code into the library padlock."
})
Groupboxes.Self_Automation:AddSlider("AutoUnlockPadlockSlider", {
	Text = "Padlock Range", Min = 1, Max = 50, Default = 10, Rounding = 0, Compact = true
})
Groupboxes.Self_Automation:AddToggle("AutoLibraryGuessCode", {
	Text = "Bruteforce Library", Default = false,
	Tooltip = "Attempts to guess the library code, but collecting some books is also necessary."
})
Groupboxes.Self_Automation:AddSlider("LibraryGuessesPerSecond", {
	Text = "Guesses / Second",
	Min = FeatureConfig.LibraryBruteforce.MinGuessesPerSecond,
	Max = FeatureConfig.LibraryBruteforce.MaxGuessesPerSecond,
	Default = FeatureConfig.LibraryBruteforce.DefaultGuessesPerSecond,
	Rounding = 0,
	Compact = true,
})
Groupboxes.Self_Automation:AddDivider()
Groupboxes.Self_Automation:AddToggle("AutoInteractToggle", {
	Text = "Auto Interact", Default = false, Tooltip = "Automatically triggers nearby prompts."
})
Toggles.AutoInteractToggle:AddKeyPicker("AutoInteractKeybind", {
	Text = "Auto Interact", Default = "R",
	Mode = "Toggle", SyncToggleState = true
})
Groupboxes.Self_Automation:AddDropdown("AutoInteractIgnoreList", {
	Text = "Blacklist",
	Values = { "Glitch Fragments", "Jeff Items", "Dropped Items", "Currency", "Minecarts", "Locks", "Seats", "Trashcans", "Carts", "Terminals", "Water Cooler", "Closets", "Paper Planes", "Stairwell Debris" },
	Default = { "Glitch Fragments", "Jeff Items", "Dropped Items", "Seats", "Trashcans", "Carts", "Terminals", "Water Cooler", "Closets", "Paper Planes", "Stairwell Debris" },
	Multi = true, AllowNull = true
})
Groupboxes.Self_Automation:AddDivider()
Groupboxes.Self_Automation:AddToggle("AutoClosetToggle", {
	Text = "Auto Hide", Default = false,
	Tooltip = "Automatically hides in a nearby closet when an entity is near."
})
Toggles.AutoClosetToggle:AddKeyPicker("AutoClosetKeybind", {
	Text = "Auto Hide", Default = "Q", Mode = "Toggle", SyncToggleState = true
})
Groupboxes.Self_Automation:AddDropdown("AutoClosetEntityList", {
	Text = "Blacklist",
	Values = { "Rush", "Ambush", "Blitz", "A-60", "A-120", "AR0xMBUSH", "RNIUSHCG==" },
	Multi = true, AllowNull = true
})
Groupboxes.Self_Automation:AddToggle("SpectateEntityToggle", {
	Text = "Watch Entity",
	Default = false,
	Tooltip = "Spectates the entity while auto hiding."
})
Groupboxes.Self_Automation:AddDropdown("SpecateEntityMode", {
	Values = {"Player to Entity", "Entity to Player"},
	Default = 1,
	AllowNull = true
})

Groupboxes.Self_Misc = Tabs.General:AddRightGroupbox("Quick Actions")
Groupboxes.Self_Misc:AddButton({
	Text = "Rejoin", Tooltip = "Makes you join a new run, click again to cancel.", DoubleClick = true,
	Func = function() RemotesFolder.PlayAgain:FireServer() end
})
Groupboxes.Self_Misc:AddButton({
	Text = "Leave", Tooltip = "Makes you teleport back to the lobby.", DoubleClick = true,
	Func = function() RemotesFolder.Lobby:FireServer() end
})
Groupboxes.Self_Misc:AddButton({
	Text = "Fake Revive",
	Tooltip = "Makes you revive, if you have a revive and haven't already revived in this run.",
	DoubleClick = true,
	Func = function() RemotesFolder.Revive:FireServer() end
})
Groupboxes.Self_Misc:AddButton({
	Text = "Reset",
	Tooltip = "Kills your character on the server. (takes around 20 seconds if replicatesignal isn't supported)",
	DoubleClick = true,
	Func = function()
		Globals.SelfKilled = true
		if Functions.CheckCompatability({"replicatesignal"}) then
			Ostium.Environment.replicatesignal(LocalPlayer.Kill)
		else
			if RemotesFolder:FindFirstChild("Underwater") then
				RemotesFolder.Underwater:FireServer(true)
			else
				Humanoid.Health = 0
			end
		end
	end
})

Groupboxes.Exploits_Bypass = Tabs.Exploits:AddLeftGroupbox("Entity Bypass")
Groupboxes.Exploits_Bypass:AddToggle("BypassGiggle",         { Text = "Anti Giggle",           Default = false, Tooltip = "Prevents 'Giggle' from attacking you." })
Groupboxes.Exploits_Bypass:AddToggle("BypassDupe",           { Text = "Anti Dupe",             Default = false, Tooltip = "Prevents you from open 'Dupe' fake doors." })
Groupboxes.Exploits_Bypass:AddToggle("BypassEyes",           { Text = "Anti Eyes",             Default = false, Tooltip = "Prevents 'Eyes' from hurting you." })
Groupboxes.Exploits_Bypass:AddToggle("BypassLookman",        { Text = "Anti Lookman",          Default = false, Tooltip = "Prevents 'Lookman' from hurting you." })
Groupboxes.Exploits_Bypass:AddToggle("BypassGloombatEggs",   { Text = "Anti Gloombat",    Default = false, Tooltip = "Prevents taking damage from stepping on 'Gloombat' eggs." })
Groupboxes.Exploits_Bypass:AddToggle("BypassSeekObstructions", { Text = "Anti Seek Walls", Default = false, Tooltip = "Prevents obstacles in the 'Seek' chase from harming you." })
Groupboxes.Exploits_Bypass:AddToggle("BypassVacuum",         { Text = "Anti Vacuum",           Default = false, Tooltip = "Prevents you from falling into 'Vacuum' fake doors." })
Groupboxes.Exploits_Bypass:AddToggle("BypassKillbricks",     { Text = "Anti Lava",       Default = false, Tooltip = "Prevents 'Lava' from hurting you." })
Groupboxes.Exploits_Bypass:AddToggle("BypassSeekingWall",    { Text = "Anti Scary Wall",     Default = false, Tooltip = "Prevents 'ScaryWall' from hurting you." })
Groupboxes.Exploits_Bypass:AddToggle("BypassSnare",          { Text = "Anti Snare",            Default = false, Tooltip = "Prevents 'Snare' from trapping you." })
Groupboxes.Exploits_Bypass:AddToggle("BypassBanana",         { Text = "Anti Banana",           Default = false, Tooltip = "Prevents 'Banana Peel' from slipping you up (sometimes doesn't work)." })
Groupboxes.Exploits_Bypass:AddToggle("BypassJeff",           { Text = "Anti Jeff",             Default = false, Tooltip = "Prevents 'Jeff the Killer' from stabbing you (sometimes doesn't work)." })

Toggles.BypassGiggle:OnChanged(function(Value)
	for _, Object in Objects.Entities do
		if Object.Name == "GiggleCeiling" then
			Object:WaitForChild("Hitbox").CanTouch = not Value
		end
	end
end)
Toggles.BypassDupe:OnChanged(function(Value)
	for _, Object in Objects.Entities do
		if Object.Name == "DoorFake" or Object.Name == "FakeDoor" then
			Object:WaitForChild("Hidden").CanTouch = not Value
			if Object:FindFirstChild("Lock") then
				Object.Lock.UnlockPrompt.Enabled = not Value
			end
		end
	end
end)
Toggles.BypassEyes:OnChanged(function(Value)
	if Value and Globals.IsEyes then
		if Floor == "Fools" or Floor == "OldHotel" then
			RemotesFolder.MotorReplication:FireServer(0, (Globals.SpoofOffset == 200 and 65 or -65), 0, false)
		else
			RemotesFolder.MotorReplication:FireServer(-650)
		end
	end
end)
Toggles.BypassLookman:OnChanged(function(Value)
	if Value and Globals.IsLookman then
		if Floor == "Fools" or Floor == "OldHotel" then
			RemotesFolder.MotorReplication:FireServer(0, (Globals.SpoofOffset == 200 and 65 or -65), 0, false)
		else
			RemotesFolder.MotorReplication:FireServer(-650)
		end
	end
end)
Toggles.BypassGloombatEggs:OnChanged(function(Value)
	for _, Object in Objects.Entities do
		for _, Part in Object:GetDescendants() do
			if Part:IsA("BasePart") then
				Part.CanTouch = not Value
			end
		end
	end
end)
Toggles.BypassSeekObstructions:OnChanged(function(Value)
	for _, Object in Objects.SeekObstructions do
		Object.CanTouch = not Value
		if Object.Name == "SeekFloodline" then
			Object.CanCollide = Value
		end
	end
	for _, Object in Objects.SeekBridges do
		Object.CanCollide = Value
		Object.Transparency = Value and 0 or 1
	end
end)
Toggles.BypassVacuum:OnChanged(function(Value)
	for _, Object in Objects.Entities do
		if Object.Name == "SideroomSpace" then
			Object:WaitForChild("Collision").CanCollide = Value
			Object:WaitForChild("Collision").CanTouch = not Value
		end
	end
end)
Toggles.BypassKillbricks:OnChanged(function(Value)
	for _, Object in Objects.Obstructions do
		if Object.Name == "Lava" then Object.CanTouch = not Value end
	end
end)
Toggles.BypassSeekingWall:OnChanged(function(Value)
	for _, Object in Objects.Obstructions do
		if Object.Name == "ScaryWall" then
			for _, Part in Object:GetDescendants() do
				if Part:IsA("BasePart") then
					Part.CanTouch = not Value
					Part.CanCollide = not Value
				end
			end
		end
	end
end)
Toggles.BypassSnare:OnChanged(function(Value)
	for _, Object in Objects.Entities do
		if Object.Name == "Snare" then
			for _, Part in Object:GetDescendants() do
				if Part:IsA("BasePart") then Part.CanTouch = not Value end
			end
		end
	end
end)
Toggles.BypassBanana:OnChanged(function(Value)
	for _, Object in Objects.Entities do
		if Object.Name == "BananaPeel" then Object.CanTouch = not Value end
	end
end)
Toggles.BypassJeff:OnChanged(function(Value)
	Functions.SetAntiJeffState(Value)
end)

Groupboxes.Exploits_BypassRight = Tabs.Exploits:AddRightGroupbox("Anticheat")
Groupboxes.Exploits_BypassRight:AddToggle("DisableAnticheat", {
	Text = "Disable Anticheat", Default = false,
	Tooltip = "Completely disables the anticheat, after interacting with a ladder."
})
Groupboxes.Exploits_BypassRight:AddToggle("VelocityManipulationToggle", {
	Text = "Anti Cheat Manipulation", Default = false,
	Tooltip = "Moves your character forward slowly, mitigating the game's anti-noclip."
})
Toggles.DisableAnticheat:OnChanged(function(Value)
	if Globals.AnticheatDisabled == true and not Value then
		RemotesFolder.ClimbLadder:FireServer()
		Globals.AnticheatDisabled = false
	end
end)
Toggles.VelocityManipulationToggle:AddKeyPicker("VelocityManipulationKeybind", {
	Text = "Anti Cheat Manipulation", Default = "V",
	Mode = Library.IsMobile and "Toggle" or "Hold", SyncToggleState = true
})
Groupboxes.Exploits_BypassRight:AddDivider()
Groupboxes.Exploits_BypassRight:AddToggle("InfiniteItemsToggle", {
	Text = "Infinite Items", Default = false,
	Tooltip = "Allows certain items to be used without draining their uses.",
	Disabled = not Functions.CheckCompatability({"fireproximityprompt"}),
	DisabledTooltip = Globals.IncompatibleMessage
})
Toggles.InfiniteItemsToggle:OnChanged(function()
	Functions.SyncFakePrompts()
end)
Groupboxes.Exploits_BypassRight:AddDropdown("InfiniteItemsList", {
	Text = "Items",
	Values = { "Lockpicks", "Skeleton Key", "Shears", "Multitool", "Paper Plane" },
	Multi = true, AllowNull = true,
	Disabled = not Functions.CheckCompatability({"fireproximityprompt"}),
	DisabledTooltip = Globals.IncompatibleMessage
})

Groupboxes.Exploits_BypassRight:AddDivider()
Groupboxes.Exploits_BypassRight:AddToggle("PositionSpoof", {
	Text = "God Mode", Default = false,
	Tooltip = "Makes your character appear underground on the server, protecting you from rush-like entities."
})
Groupboxes.Exploits_BypassRight:AddToggle("AutoGodmodeOnEntitySpawn", {
	Text = "Godmode On Entity Spawn", Default = false,
	Tooltip = "Automatically enables God Mode while specific rush-like entities are active in Workspace."
})
Groupboxes.Exploits_BypassRight:AddToggle("CrouchSpoof", {
	Text = "Fake Crouch", Default = false, Tooltip = "Makes the game think you are always crouching."
})
Toggles.PositionSpoof:OnChanged(function(Value)
	if Floor ~= "Fools" and Floor ~= "OldHotel" then
		Functions.ApplyRootOffsetSpoofState()
	end
end)
Toggles.PositionSpoof:AddKeyPicker("PositionSpoof", {
	Text = "God Mode", Default = "B", Mode = "Toggle", SyncToggleState = true
})
Toggles.AutoGodmodeOnEntitySpawn:OnChanged(function(Value)
	if Value then
		AutoGodmodeState.Elapsed = 0
	else
		if AutoGodmodeState.Forced and Toggles.PositionSpoof.Value then
			Toggles.PositionSpoof:SetValue(false)
		end
		AutoGodmodeState.Forced = false
	end
end)
Toggles.CrouchSpoof:OnChanged(function(Value)
	if RemotesFolder:FindFirstChild("Crouch") then
		RemotesFolder.Crouch:FireServer(Value and true or Functions.IsCrouching(), true)
	end
end)

Groupboxes.Exploits_Remove = Tabs.Exploits:AddLeftGroupbox("Entity Removal")
Groupboxes.Exploits_Remove:AddToggle("RemoveScreech", { Text = "Block Screech",  Default = false, Tooltip = "Prevents 'Screech' from spawning." })
Groupboxes.Exploits_Remove:AddToggle("RemoveHalt",    { Text = "Block Halt",     Default = false, Tooltip = "Prevents 'Halt' from spawning." })
Groupboxes.Exploits_Remove:AddToggle("RemoveA90",     { Text = "Block A-90",     Default = false, Tooltip = "Prevents 'A-90' from spawning." })
Groupboxes.Exploits_Remove:AddToggle("RemoveDread",   { Text = "Block Dread",    Default = false, Tooltip = "Prevents 'Dread' from spawning." })
Groupboxes.Exploits_Remove:AddToggle("RemoveSurge", { Text = "Block Surge", Default = false, Tooltip = "Prevents 'Surge' from spawning."})
Groupboxes.Exploits_Remove:AddToggle("BlockRansom", { Text = "Block Ransom", Default = false, Tooltip = "remove ransom" })
Groupboxes.Exploits_Remove:AddDivider()
Groupboxes.Exploits_Remove:AddToggle("NoScreechDamage", { Text = "Screech Godmode", Default = false, Tooltip = "Prevents 'Screech' from hurting you." })
Groupboxes.Exploits_Remove:AddToggle("NoHaltDamage",    { Text = "Halt Godmode",    Default = false, Tooltip = "Prevents 'Halt' from hurting you." })
Groupboxes.Exploits_Remove:AddToggle("NoA90Damage",     { Text = "A-90 Godmode",    Default = false, Tooltip = "Prevents 'A-90' from hurting you." })
Groupboxes.Exploits_Remove:AddToggle("NoSurgeDamage",   { Text = "Surge Godmode",   Default = false, Tooltip = "Prevents 'Surge' from hurting you." })

Toggles.NoScreechDamage:OnChanged(function(Value)
	if Value then
		FakeEvents.Screech.Parent = RemotesFolder
		FakeEvents.Screech_Real.Parent = nil
	else
		FakeEvents.Screech_Real.Parent = RemotesFolder
		FakeEvents.Screech.Parent = nil
	end
end)
Toggles.NoHaltDamage:OnChanged(function(Value)
	if Value then
		FakeEvents.Shade.Parent = RemotesFolder
		FakeEvents.Shade_Real.Parent = nil
	else
		FakeEvents.Shade_Real.Parent = RemotesFolder
		FakeEvents.Shade.Parent = nil
	end
end)
Toggles.NoA90Damage:OnChanged(function(Value)
	if RemotesFolder:FindFirstChild("A90") then
		if Value then
			FakeEvents.A90.Parent = RemotesFolder
			FakeEvents.A90_Real.Parent = nil
		else
			FakeEvents.A90_Real.Parent = RemotesFolder
			FakeEvents.A90.Parent = nil
		end
	end
end)
Toggles.NoSurgeDamage:OnChanged(function(Value)
	if RemotesFolder:FindFirstChild("SurgeRemote") then
		if Value then
			FakeEvents.Surge.Parent = RemotesFolder
			FakeEvents.Surge_Real.Parent = nil
		else
			FakeEvents.Surge_Real.Parent = RemotesFolder
			FakeEvents.Surge.Parent = nil
		end
	end
end)

local Modules = {}

Toggles.RemoveScreech:OnChanged(function(Value)
	Modules.Screech.Name = Value and "Screech_Disabled" or "Screech"
	if Modules.GlitchScreech then
		Modules.GlitchScreech.Name = Value and "GlitchScreech_Disabled" or "GlitchScreech"
	end
end)
Toggles.RemoveHalt:OnChanged(function(Value)
	Modules.Shade.Name = Value and "Shade_Disabled" or "Shade"
end)
Toggles.RemoveA90:OnChanged(function(Value)
	if Modules.A90 then
		Modules.A90.Name = Value and "A90_Disabled" or "A90"
	end
end)
Toggles.RemoveDread:OnChanged(function(Value)
	if Modules.Dread then
		Modules.Dread.Name = Value and "Dread_Disabled" or "Dread"
	end
end)
Toggles.RemoveSurge:OnChanged(function(Value)
	if Globals.SurgeFrame then
		Globals.SurgeFrame.Name = (Value and "SurgeVignette_Disabled" or "SurgeVignette")
	end
end)

Groupboxes.Exploits_Audio = Tabs.Exploits:AddRightGroupbox("Sound")
Globals.JamMuffle = Services.SoundService:WaitForChild("Main"):FindFirstChild("Jamming") or Instance.new("EqualizerSoundEffect")

Groupboxes.Exploits_Audio:AddToggle("RemoveFootstepSounds",    { Text = "Mute Footsteps",    Default = false, Tooltip = "Removes the sounds when walking." })
Groupboxes.Exploits_Audio:AddToggle("RemoveJamminMusic",       { Text = "Mute Jammin",       Default = false, Tooltip = "Removes the music and muffle effect from the 'Jammin' modifier." })
Groupboxes.Exploits_Audio:AddToggle("RemoveInteractingSounds", { Text = "Mute Interactions", Default = false, Tooltip = "Removes the sounds when interacting with proximity prompts." })

Toggles.RemoveJamminMusic:OnChanged(function(Value)
	local Jam = Globals.MainUI.Initiator.Main_Game.Health:FindFirstChild("Jam")
	if Jam then
		Jam.Volume = Value and 0 or 0.45
		Globals.JamMuffle.Enabled = LiveModifiers:FindFirstChild("Jammin") and not Value or false
	end
end)
Toggles.RemoveInteractingSounds:OnChanged(function(Value)
	local PS = Globals.MainUI.Initiator.Main_Game.PromptService
	PS.Triggered.Volume   = Value and 0 or 0.04
	PS.Holding.Volume     = Value and 0 or 0.1
	PS.Notification.Volume = Value and 0 or 0.03
	Globals.MainUI.Initiator.Main_Game.Reminder.Caption.Volume = Value and 0 or 0.1
end)

Groupboxes.Exploits_Extras = Tabs.Exploits:AddLeftGroupbox("Toolbox")

Globals.CrucifixState = { Uses = 1, Range = 30, Anything = true, Fails = false }

Groupboxes.Exploits_Extras:AddSlider("CrucifixUses", {
    Text = "Crucifix Uses", Min = 1, Max = 100, Default = 1, Rounding = 0, Compact = true,
    Callback = function(Value) Globals.CrucifixState.Uses = Value end
})
Groupboxes.Exploits_Extras:AddSlider("CrucifixRange", {
    Text = "Crucifix Range", Min = 25, Max = 100, Default = 30, Rounding = 0, Compact = true,
    Callback = function(Value) Globals.CrucifixState.Range = Value end
})
Groupboxes.Exploits_Extras:AddToggle("CrucifixAnything", {
    Text = "Crucifix Anything", Default = true,
    Callback = function(Value) Globals.CrucifixState.Anything = Value end
})
Groupboxes.Exploits_Extras:AddToggle("CrucifixFails", {
    Text = "Crucifix Fails", Default = false,
    Callback = function(Value) Globals.CrucifixState.Fails = Value end
})
Groupboxes.Exploits_Extras:AddButton({
    Text = "Get Crucifix",
    Tooltip = "Loads the Crucifix auto-use script with your settings.",
    Func = function()
        _G.Uses = Globals.CrucifixState.Uses
        _G.Range = Globals.CrucifixState.Range
        _G.OnAnything = Globals.CrucifixState.Anything
        _G.Fail = Globals.CrucifixState.Fails
        loadstring(game:HttpGet("https://raw.githubusercontent.com/PenguinManiack/Crucifix/main/Crucifix.lua"))()
    end
})
Groupboxes.Exploits_Extras:AddButton({
    Text = "Get Keyboard Script",
    Tooltip = "Loads a piano keyboard script.",
    Func = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/GGH52lan/GGH52lan/main/keyboard.txt"))()
    end
})
Groupboxes.Exploits_Extras:AddDivider()

local function FireClientRemote(Name, ...)
    if not Functions.CheckCompatability({"firesignal"}) then
        Functions.Notify({ Title = "This requires firesignal support." })
        return
    end
    local Remote = RemotesFolder and RemotesFolder:FindFirstChild(Name)
    if Remote and Remote:IsA("RemoteEvent") then
        Ostium.Environment.firesignal(Remote.OnClientEvent, ...)
    end
end

Groupboxes.Exploits_Extras:AddButton({
    Text = "Spawn Dread",
    DoubleClick = true,
    Tooltip = "Spawns the entity 'Dread' locally.",
    Func = function()
        if not Functions.CheckCompatability({"require"}) then
            Functions.Notify({ Title = "This requires require support." })
            return
        end
        local Initiator = Globals.MainUI:WaitForChild("Initiator"):WaitForChild("Main_Game")
        local Modules = Initiator:WaitForChild("RemoteListener"):WaitForChild("Modules")
        local Original = Modules:FindFirstChild("Dread") or Modules:FindFirstChild("Dread_Disabled")
        if not Original then return end
        local Clone = Original:Clone()
        Clone.Name = "_ManualDread"
        Clone.Parent = Modules
        local Dread = Ostium.Environment.require(Clone)
        local Game = Ostium.Environment.require(Initiator)
        task.spawn(function() Dread(Game, "cold") end)
        task.wait(0.25)
        task.spawn(function() Dread(Game, "spawn") end)
    end
})
Groupboxes.Exploits_Extras:AddButton({ Text = "Spawn A-90", DoubleClick = true, Tooltip = "Spawns the entity 'A-90' locally.", Func = function() FireClientRemote("A90", "spawn") end })
Groupboxes.Exploits_Extras:AddButton({ Text = "Spawn Screech", DoubleClick = true, Tooltip = "Spawns the entity 'Screech' locally.", Func = function() FireClientRemote("Screech", "spawn") end })
Groupboxes.Exploits_Extras:AddButton({
    Text = "Spawn Glitch",
    DoubleClick = true,
    Tooltip = "Spawns the entity 'Glitch' locally.",
    Func = function()
        if not Functions.CheckCompatability({"firesignal"}) then
            Functions.Notify({ Title = "This requires firesignal support." })
            return
        end
        local Remote = RemotesFolder and RemotesFolder:FindFirstChild("UseEnemyModule")
        if Remote then
            Ostium.Environment.firesignal(Remote.OnClientEvent, "Glitch", "stuff", nil, os.clock())
        end
    end
})

Groupboxes.Visuals_LeftTab = Tabs.Visuals:AddLeftTabbox("View")
Groupboxes.Visuals_Camera = Groupboxes.Visuals_LeftTab:AddTab("Camera")
Groupboxes.Visuals_Camera:AddToggle("AmbientToggle", { Text = "Ambient Light", Default = false, Tooltip = "Changes the lighting color to the specified value." })
Groupboxes.Visuals_Camera:AddSlider("FieldOfView", { Text = "FOV", Min = 1, Max = 120, Default = 70, Rounding = 0 })
Groupboxes.Visuals_Camera:AddDivider()
Groupboxes.Visuals_Camera:AddToggle("RemoveCameraShake", {
	Text = "No Camera Shake", Default = false, Tooltip = "Prevents the camera from shaking.",
	Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Visuals_Camera:AddToggle("RemoveCameraBobbing", {
	Text = "No View Bob", Default = false, Tooltip = "Prevents the camera from bobbing when moving.",
	Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Visuals_Camera:AddToggle("RemoveCutscenes", { Text = "Skip Cutscenes", Default = false, Tooltip = "Removes all non-necessary cutscenes." })
Groupboxes.Visuals_Camera:AddToggle("RemoveCameraFog", { Text = "No Fog", Default = false, Tooltip = "Removes all fog effects from the camera." })
Groupboxes.Visuals_Camera:AddDivider()
Groupboxes.Visuals_Camera:AddToggle("ThirdPersonToggle", { Text = "Third Person View", Default = false, Tooltip = "Zooms out your camera, allowing you to see your character from behind." })
Toggles.ThirdPersonToggle:AddKeyPicker("ThirdPersonKeybind", { Text = "Third Person View", Default = "T", Mode = "Toggle", SyncToggleState = true })
Groupboxes.Visuals_Camera:AddSlider("ThirdPersonOffsetX", { Text = "X Offset", Min = -10, Max = 10, Default = 1.5, Rounding = 1, Compact = true })
Groupboxes.Visuals_Camera:AddSlider("ThirdPersonOffsetY", { Text = "Y Offset", Min = -10, Max = 10, Default = 1,   Rounding = 1, Compact = true })
Groupboxes.Visuals_Camera:AddSlider("ThirdPersonOffsetZ", { Text = "Z Offset", Min = -10, Max = 10, Default = 5,   Rounding = 1, Compact = true })
Groupboxes.Visuals_Camera:AddToggle("ThirdPersonWallCheck", { Text = "Camera Collision", Default = false, Tooltip = "Prevents third person from going through walls." })
Groupboxes.Visuals_Camera:AddDivider()
Groupboxes.Visuals_Camera:AddToggle("ViewmodelOffsetToggle", {
	Text = "Hand Offset", Default = false, Tooltip = "Changes the offset of your viewmodel while holding an item.",
	Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Visuals_Camera:AddSlider("ViewmodelOffsetX", { Text = "X Offset", Min = -10, Max = 10, Default = 0, Rounding = 1, Compact = true, Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage })
Groupboxes.Visuals_Camera:AddSlider("ViewmodelOffsetY", { Text = "Y Offset", Min = -10, Max = 10, Default = 0, Rounding = 1, Compact = true, Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage })
Groupboxes.Visuals_Camera:AddSlider("ViewmodelOffsetZ", { Text = "Z Offset", Min = -10, Max = 10, Default = 0, Rounding = 1, Compact = true, Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage })

Groupboxes.Visuals_Camera:AddDivider()
Groupboxes.Visuals_Camera:AddToggle("FullbrightToggle", { Text = "Fullbright", Default = false, Tooltip = "Removes shadows and brightens the map." })
Toggles.FullbrightToggle:AddColorPicker("FullbrightColor", { Text = "Fullbright Tint", Default = Color3.new(1, 1, 1), Transparency = 0 })
Groupboxes.Visuals_Camera:AddSlider("FullbrightIntensity", { Text = "Fullbright Intensity", Min = 0, Max = 10, Default = 2, Rounding = 1, Compact = true })

Globals.OriginalBrightness = Services.Lighting.Brightness
local function ApplyFullbright()
    if not Toggles.FullbrightToggle.Value then return end
    Services.Lighting.GlobalShadows = false
    Services.Lighting.OutdoorAmbient = Options.FullbrightColor.Value
    Services.Lighting.Brightness = Options.FullbrightIntensity.Value
end
Toggles.FullbrightToggle:OnChanged(function(Value)
    Services.Lighting.GlobalShadows = not Value
    Services.Lighting.OutdoorAmbient = Value and Options.FullbrightColor.Value or Color3.new(0, 0, 0)
    Services.Lighting.Brightness = Value and Options.FullbrightIntensity.Value or Globals.OriginalBrightness
end)
Options.FullbrightColor:OnChanged(ApplyFullbright)
Options.FullbrightIntensity:OnChanged(function(Value)
    if Toggles.FullbrightToggle.Value then Services.Lighting.Brightness = Value end
end)
Connections.FullbrightGlobalShadows = Services.Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(ApplyFullbright)
Connections.FullbrightAmbient = Services.Lighting:GetPropertyChangedSignal("OutdoorAmbient"):Connect(ApplyFullbright)
Connections.FullbrightBrightness = Services.Lighting:GetPropertyChangedSignal("Brightness"):Connect(ApplyFullbright)

Groupboxes.Visuals_Camera:AddDivider()
Groupboxes.Visuals_Camera:AddToggle("FreecamToggle", { Text = "Freecam", Default = false, Tooltip = "Unlocks the camera while your character stays anchored." })
Toggles.FreecamToggle:AddKeyPicker("FreecamKeybind", { Text = "Freecam", Default = "P", Mode = "Toggle", SyncToggleState = true })

Globals.FreecamPart = nil
Globals.FreecamZoom = nil
Toggles.FreecamToggle:OnChanged(function(Value)
    if Connections.Freecam then
        Connections.Freecam:Disconnect()
        Connections.Freecam = nil
    end

    local Char = LocalPlayer.Character
    local Root = Char and Char:FindFirstChild("HumanoidRootPart")

    if not Value then
        if Root then Root.Anchored = false end
        if Globals.FreecamPart then Globals.FreecamPart:Destroy() Globals.FreecamPart = nil end
        if Globals.FreecamZoom then
            LocalPlayer.CameraMinZoomDistance = Globals.FreecamZoom.Min
            LocalPlayer.CameraMaxZoomDistance = Globals.FreecamZoom.Max
            Globals.FreecamZoom = nil
        end
        return
    end

    local ActiveCamera = Services.Workspace.CurrentCamera
    if not (Root and ActiveCamera) then return end

    Root.Anchored = true
    Globals.FreecamZoom = { Min = LocalPlayer.CameraMinZoomDistance, Max = LocalPlayer.CameraMaxZoomDistance }
    LocalPlayer.CameraMinZoomDistance = 0
    LocalPlayer.CameraMaxZoomDistance = 0

    local Part = Instance.new("Part")
    Part.Name = Ostium.ESPLibrary:GenerateRandomString()
    Part.Size = Vector3.new(0.05, 0.05, 0.05)
    Part.Transparency = 1
    Part.CanCollide = false
    Part.CanQuery = false
    Part.Anchored = true
    Part.CFrame = ActiveCamera.CFrame
    Part.Parent = Services.Workspace
    Globals.FreecamPart = Part

    local Pitch, Yaw = ActiveCamera.CFrame:ToOrientation()
    Pitch, Yaw = math.deg(Pitch), math.deg(Yaw)

    Connections.Freecam = Services.RunService.RenderStepped:Connect(function(Delta)
        if not Toggles.FreecamToggle.Value then return end
        local Cam = Services.Workspace.CurrentCamera
        local Character = LocalPlayer.Character
        local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
        local Hum = Character and Character:FindFirstChildOfClass("Humanoid")
        if not (Cam and RootPart and Hum and Part.Parent) then return end

        RootPart.Anchored = true

        local MouseDelta = Services.UserInputService:GetMouseDelta()
        Pitch = math.clamp(Pitch - MouseDelta.Y * 0.3, -80, 80)
        Yaw = Yaw - MouseDelta.X * 0.3
        Part.CFrame = CFrame.new(Part.Position) * CFrame.fromOrientation(math.rad(Pitch), math.rad(Yaw), 0)

        if Hum.MoveDirection.Magnitude > 0 then
            local LocalMove = Cam.CFrame:VectorToObjectSpace(Hum.MoveDirection)
            local Move = (Cam.CFrame.RightVector * LocalMove.X) + (Cam.CFrame.LookVector * -LocalMove.Z)
            Part.Position += Move * 50 * Delta
        end

        Cam.CFrame = Part.CFrame
        Cam.Focus = Cam.CFrame * CFrame.new(0, 0, -10)
    end)
end)


Toggles.AmbientToggle:AddColorPicker("AmbientColor", { Text = "Ambient Light", Default = Color3.fromRGB(255, 255, 255), Transparency = 0 })
Toggles.AmbientToggle:OnChanged(function(Value)
	local OldAmbient = CurrentRooms:FindFirstChild(tostring(LocalPlayer:GetAttribute("CurrentRoom"))):GetAttribute("Ambient")
	Services.TweenService:Create(Services.Lighting, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {
		Ambient = Value and Options.AmbientColor.Value or OldAmbient
	}):Play()
end)

local Main_Game
local ClientModules

Toggles.RemoveCameraBobbing:OnChanged(function(Value)
	if Main_Game then Main_Game.spring.Speed = Value and 9e9 or 8 end
end)
Toggles.RemoveCameraFog:OnChanged(function(Value)
	Services.Lighting.FogEnd = Value and 10000000 or Globals.OldFog
	for _, Object in Globals.FogInstances do
		if Object.Parent then
			Object.Density = Value and 0 or Object:GetAttribute("Density_Old")
		end
	end
	Functions.SetNamedLightingEffectsRemoved(Value)
end)
Toggles.RemoveCutscenes:OnChanged(function(Value)
    local Cutscenes = Globals.MainUI.Initiator.Main_Game.RemoteListener.Cutscenes
    for _, Object in pairs(Cutscenes:GetChildren()) do
        if table.find(CutsceneNames, Object.Name) and Object:IsA("ModuleScript") or table.find(CutsceneNames, Object:GetAttribute("OriginalName")) and Object:IsA("ModuleScript") then
            Object.Name = (Value and Object.Name .. "_Disabled" or Object:GetAttribute("OriginalName"))
        end
    end
    for _, Object in pairs(FloorReplicated:GetChildren()) do
        if table.find(CutsceneNames, Object.Name) and Object:IsA("ModuleScript") or table.find(CutsceneNames, Object:GetAttribute("OriginalName")) and Object:IsA("ModuleScript") then
            Object.Name = (Value and Object.Name .. "_Disabled" or Object:GetAttribute("OriginalName"))
        end
    end
end)

Groupboxes.Visuals_Effects = Groupboxes.Visuals_LeftTab:AddTab("World")
Groupboxes.Visuals_Effects:AddToggle("TransparentHidingSpotsToggle", { Text = "See-Through Closets", Default = false, Tooltip = "Makes a hiding spot transparent when you enter it." })
Groupboxes.Visuals_Effects:AddSlider("TransparentHidingSpotsSlider", { Text = "Transparency", Min = 0, Max = 1, Default = 0.5, Rounding = 2, Compact = true })

local function ApplyHidingTransparency(Value, SliderValue)
	for _, Object in Objects.HidingSpots do
		local IsHiding = false
		for _, Child in Object:GetDescendants() do
			if Child.Name == "HiddenPlayer" and Child.Value == Character then
				IsHiding = true
				break
			end
		end
		for _, Part in Object:GetDescendants() do
			if Part:IsA("BasePart") and Part:GetAttribute("Transparency_Old") then
				Services.TweenService:Create(Part, TweenInfo.new(0.25, Enum.EasingStyle.Linear), {
					Transparency = (Value and IsHiding) and SliderValue or Part:GetAttribute("Transparency_Old")
				}):Play()
			end
		end
	end
end

Toggles.TransparentHidingSpotsToggle:OnChanged(function(Value)
	ApplyHidingTransparency(Value, Options.TransparentHidingSpotsSlider.Value)
end)
Options.TransparentHidingSpotsSlider:OnChanged(function(Value)
	ApplyHidingTransparency(Toggles.TransparentHidingSpotsToggle.Value, Value)
end)

Groupboxes.Visuals_Effects:AddDivider()
Groupboxes.Visuals_Effects:AddToggle("DisableGlitchJumpscare",   { Text = "No Glitch Scare",   Default = false, Tooltip = "Disables the jumpscare from 'Glitch'" })
Groupboxes.Visuals_Effects:AddToggle("DisableTimothyJumpscare",  { Text = "No Timothy Scare",  Default = false, Tooltip = "Disables the jumpscare from 'Timothy'" })
Groupboxes.Visuals_Effects:AddToggle("DisableVoidJumpscare",     { Text = "No Void Scare",     Default = false, Tooltip = "Disables the jumpscare from 'Void'" })
Groupboxes.Visuals_Effects:AddToggle("DisableHasteJumpscare",    { Text = "No Haste Scare",    Default = false, Tooltip = "Disables Haste's ambience and sanity overlay." })
Groupboxes.Visuals_Effects:AddDivider()
Groupboxes.Visuals_Effects:AddToggle("DisableHideVignette",      { Text = "No Hide Overlay",      Default = false, Tooltip = "Disables the hiding screen effect." })
Groupboxes.Visuals_Effects:AddToggle("DisableFiredampEffect",    { Text = "Anti Firedamp",    Default = false, Tooltip = "Disables firedamp and removes its camera effects." })
Groupboxes.Visuals_Effects:AddToggle("DisableEntityJumpscares",  { Text = "No Entity Scares",  Default = false, Tooltip = "Disables jumpscares from entities like Rush and Ambush." })
local VoiceGetUpvalues = ExecutorSupport.Functions["debug.getupvalues"]
local VoiceSetupvalue = ExecutorSupport.Functions["debug.setupvalue"]
local VoiceActingSupported = Functions.CheckCompatibility({ "debug.getupvalues", "debug.setupvalue" })
Groupboxes.Visuals_Effects:AddToggle("DisableVoiceActing",       { Text = "No Voice Acting",   Default = false, Tooltip = "Silences the April Fools voice acting lines (Screech, Spider, Dread, Halt, etc.).", Disabled = not VoiceActingSupported, DisabledTooltip = Globals.IncompatibleMessage })

Toggles.DisableGlitchJumpscare:OnChanged(function(Value)
	Modules.Glitch.Name = Value and "Glitch_Disabled" or "Glitch"
end)
Toggles.DisableTimothyJumpscare:OnChanged(function(Value)
	Modules.SpiderJumpscare.Name = Value and "SpiderJumpscare_Disabled" or "SpiderJumpscare"
end)
Toggles.DisableVoidJumpscare:OnChanged(function(Value)
	if Modules.Void then Modules.Void.Name = Value and "Void_Disabled" or "Void" end
end)
Toggles.DisableHasteJumpscare:OnChanged(function(Value)
	Functions.SetHasteJumpscareState(Value)
end)
Toggles.DisableHideVignette:OnChanged(function(Value)
	local Vignette = Globals.MainUI:FindFirstChild("HideVignette") or Globals.MainUI.MainFrame:FindFirstChild("HideVignette")
	if Vignette then Vignette.Image = Value and "rbxassetid://0" or "rbxassetid://6100076320" end
end)
Toggles.DisableFiredampEffect:OnChanged(function(Value)
	Functions.SetFiredampState(Value)
end)
Toggles.DisableEntityJumpscares:OnChanged(function(Value)
	local Jumpscares = Globals.MainUI.Initiator.Main_Game.RemoteListener:FindFirstChild("Jumpscares")
		or Globals.MainUI.Initiator.Main_Game.RemoteListener:FindFirstChild("Jumpscares_Disabled")
	if Jumpscares then
		Jumpscares.Name = Value and "Jumpscares_Disabled" or "Jumpscares"
		for _, Object in Objects.JumpscareModules do
			Object.Name = Value and (Object:GetAttribute("OriginalName") .. "_Disabled") or Object:GetAttribute("OriginalName")
		end
	end
end)

do
	local VoiceActingFn
	local VoiceGateIndex
	local VoiceGateOriginal
	local function ResolveVoiceActing()
		if VoiceActingFn then return VoiceActingFn end
		if not VoiceActingSupported then return end
		local Module = Services.ReplicatedStorage:FindFirstChild("VoiceActing")
		if not Module then return end
		local Ok, Fn = pcall(require, Module)
		if not Ok or typeof(Fn) ~= "function" then return end
		local GotUps, Ups = pcall(VoiceGetUpvalues, Fn)
		if not GotUps then return end
		for Index, Value in Ups do
			if typeof(Value) == "boolean" then
				VoiceGateIndex = Index
				VoiceGateOriginal = Value
				break
			end
		end
		if not VoiceGateIndex then return end
		VoiceActingFn = Fn
		return VoiceActingFn
	end
	Toggles.DisableVoiceActing:OnChanged(function(Value)
		local Fn = ResolveVoiceActing()
		if not Fn then return end
		pcall(VoiceSetupvalue, Fn, VoiceGateIndex, Value and false or VoiceGateOriginal)
	end)
end

Groupboxes.Visuals_RightTab     = Tabs.Visuals:AddRightTabbox("Alerts")
Groupboxes.Visuals_Entities     = Groupboxes.Visuals_RightTab:AddTab("Notifier")
Groupboxes.Visuals_EntitySettings = Groupboxes.Visuals_RightTab:AddTab("Options")

Groupboxes.Visuals_Entities:AddDropdown("EntityList", {
	Text = "Entity List",
	Values = EntityListOptionValues,
	Multi = true, AllowNull = true
})
Groupboxes.Visuals_Entities:AddToggle("NotifyEntities",    { Text = "Entity Alerts",    Default = false, Tooltip = "Sends a notification when an entity spawns." })
Groupboxes.Visuals_Entities:AddDivider()

local ItemsToNotify = {}
for Index, Name in pairs(ItemNames) do
	if not table.find(ItemsToNotify, Name) then
		table.insert(ItemsToNotify, Name)
	end
end

Groupboxes.Visuals_Entities:AddDropdown("NotifyItemList", {
	Text = "Items",
	Values = ItemsToNotify,
	Multi = true, AllowNull = true
})
Groupboxes.Visuals_Entities:AddToggle("NotifyItemsToggle",    { Text = "Item Alerts",    Default = false, Tooltip = "Sends a notification when an item spawns." })
Groupboxes.Visuals_Entities:AddToggle("NotifyItemsShowDistance",    { Text = "Show Distance",    Default = false, Tooltip = "Shows how far away the item is in the notification." })
Groupboxes.Visuals_Entities:AddDivider()
Groupboxes.Visuals_Entities:AddToggle("NotifyLibraryCode", { Text = "Library Code Alert", Default = false, Tooltip = "Automatically solves the code for the library padlock." })
Groupboxes.Visuals_Entities:AddToggle("NotifyOxygen",      { Text = "Oxygen Meter", Default = false, Tooltip = "Shows how much oxygen you have remaining." })
Groupboxes.Visuals_Entities:AddToggle("NotifyHasteTime",   { Text = "Haste Timer",   Default = false, Tooltip = "Shows how much time you have remaining before 'Haste' spawns." })

Globals.LibraryCodeFound = false
Toggles.NotifyLibraryCode:OnChanged(function(Value)
	if Value then
		local Code = Functions.GetLibraryCode()
		if Code and not Code:find("_") and not Globals.LibraryCodeFound and CurrentRooms:FindFirstChild("50") then
			local Lock = Services.Workspace:FindFirstChild("Padlock", true)
			Functions.Notify({ Title = "Padlock code found!", Body = "The code is: '" .. Code .. "'", Time = Toggles.NotifyKeepNotifications.Value and Lock or 15 })
			Globals.LibraryCodeFound = true
		end
	end
end)

Groupboxes.Visuals_EntitySettings:AddToggle("EntityChatToggle", { Text = "Notify Chat", Default = false, Tooltip = "Sends a message in the chat when an entity spawns." })
Groupboxes.Visuals_EntitySettings:AddInput("EntityChatMessage", { Text = "Message", Default = "spawned!", Numeric = false, Placeholder = "Message" })
Groupboxes.Visuals_EntitySettings:AddDivider()
Groupboxes.Visuals_EntitySettings:AddToggle("NotifyKeepNotifications", { Text = "Keep Notifications", Default = false, Tooltip = "Certain notifications will stay on screen until they are no longer needed." })
Groupboxes.Visuals_EntitySettings:AddButton({ Text = "Test Notification", DoubleClick = false, Tooltip = "Sends a test notifcation, so you can see how your settings look.", Func = function()
	Functions.Notify({Title = "This is a test."})
end})

Groupboxes.Visuals_ESP          = Tabs.Visuals:AddRightTabbox("ESP")
Groupboxes.Visuals_ESP_Toggles  = Groupboxes.Visuals_ESP:AddTab("Targets")
Groupboxes.Visuals_ESP_Settings = Groupboxes.Visuals_ESP:AddTab("Style")

local function MakeESPToggle(ToggleKey, ColorKey, Text, Tooltip, ObjectsTable, LabelFunc, RoomBased)
	Groupboxes.Visuals_ESP_Toggles:AddToggle(ToggleKey, { Text = Text, Default = false, Tooltip = Tooltip })
	Toggles[ToggleKey]:AddColorPicker(ColorKey, { Text = Text, Default = Options[ColorKey] and Options[ColorKey].Value or Color3.new(1,1,1), Transparency = 0 })
	Toggles[ToggleKey]:OnChanged(function(Value)
		for _, Object in ObjectsTable do
			if Value then
				local Label, UseRoom = LabelFunc(Object)
				if Label then
					Functions.AddESP({ Object = Object, Text = Label, Color = Options[ColorKey].Value }, UseRoom ~= nil and UseRoom or RoomBased)
				end
			else
				Functions.RemoveESP(Object)
			end
		end
	end)
	Options[ColorKey]:OnChanged(function(Value)
		for _, Object in ObjectsTable do
			Ostium.ESPLibrary:UpdateObjectColor(Object, Value)
		end
	end)
end

Groupboxes.Visuals_ESP_Toggles:AddToggle("ObjectiveESPToggle", { Text = "Objectives", Default = false, Tooltip = "Highlights all objects required to progress." })
Toggles.ObjectiveESPToggle:AddColorPicker("ObjectiveESPColor", { Text = "Objectives", Default = Color3.fromRGB(0, 255, 0), Transparency = 0 })

local ObjectiveLabels = {
	["KeyObtain"]              = "Door Key",
	["ElectricalKeyObtain"]    = "Electrical Key",
	["MinesGenerator"]         = "Generator",
	["FuseObtain"]             = "Generator Fuse",
	["LiveHintBook"]           = "Hint Book",
	["LiveBreakerPolePickup"]  = "Fuse Breaker",
	["LibraryHintPaper"]       = "Hint Paper",
	["PickupItem"]             = "Hint Paper",
	["CringlePresent"]         = "Present",
	["LeverForGate"]           = "Gate Lever",
	["MinesGateButton"]        = "Gate Button",
	["GardenGateButton"]       = "Gate Button",
}

Toggles.ObjectiveESPToggle:OnChanged(function(Value)
	for _, Object in Objects.Objectives do
		if Value then
			local Label = ObjectiveLabels[Object.Name]
			if Object.Name == "TimerLever" then
				Label = "Time Lever [+" .. Object:GetAttribute("AddTime") .. "s]"
			elseif Object.Name == "MinesAnchor" then
				Label = "Anchor [" .. Object:WaitForChild("Sign").TextLabel.Text .. "]"
			elseif Object.Name == "WaterPump" then
				Functions.AddESP({ Object = Object.Wheel, Text = "Water Pump", Color = Options.ObjectiveESPColor.Value }, true)
			elseif Object.Name == "VineGuillotine" then
				Functions.AddESP({ Object = Object.Lever, Text = "Vine Lever", Color = Options.ObjectiveESPColor.Value }, true)
			end
			if Label then
				Functions.AddESP({ Object = Object, Text = Label, Color = Options.ObjectiveESPColor.Value }, true)
			end
		else
			Functions.RemoveESP(Object)
		end
	end
end)
Options.ObjectiveESPColor:OnChanged(function(Value)
	for _, Object in Objects.Objectives do
		Ostium.ESPLibrary:UpdateObjectColor(Object, Value)
	end
end)

Groupboxes.Visuals_ESP_Toggles:AddToggle("DoorESPToggle",       { Text = "Doors",        Default = false, Tooltip = "Highlights the next door." })
Groupboxes.Visuals_ESP_Toggles:AddToggle("HidingSpotESPToggle", { Text = "Closets", Default = false, Tooltip = "Highlights places where you can hide from entities" })
Groupboxes.Visuals_ESP_Toggles:AddToggle("PlayerESPToggle",     { Text = "Players",      Default = false, Tooltip = "Highlights other players." })
Groupboxes.Visuals_ESP_Toggles:AddToggle("ChestESPToggle",      { Text = "Loot Chests",       Default = false, Tooltip = "Highlights objects that can contain loot." })
Groupboxes.Visuals_ESP_Toggles:AddToggle("ItemESPToggle",       { Text = "Items",        Default = false, Tooltip = "Highlights all collectable items/consumables." })
Groupboxes.Visuals_ESP_Toggles:AddToggle("CurrencyESPToggle",   { Text = "Gold",     Default = false, Tooltip = "Highlights all gold that spawns." })
Groupboxes.Visuals_ESP_Toggles:AddToggle("LadderESPToggle",     { Text = "Ladders",      Default = false, Tooltip = "Highlights ladders that can be used to disable the anticheat." })
Groupboxes.Visuals_ESP_Toggles:AddToggle("VineDoorESPToggle",   { Text = "Vine Door",    Default = false, Tooltip = "Highlights Forget Me Not vine doors." })
Groupboxes.Visuals_ESP_Toggles:AddToggle("MissingObjectESPToggle", { Text = "Missing Objects", Default = false, Tooltip = "Highlights Archives props after they disappear during Forget Me Not." })
Groupboxes.Visuals_ESP_Toggles:AddDivider()
Groupboxes.Visuals_ESP_Toggles:AddDropdown("EntityESPOptions",     { 
	Text = "Entity List",
	Values = EntityESPOptionValues,
	Multi = true,
	AllowNull = true
})
Groupboxes.Visuals_ESP_Toggles:AddToggle("EntityESPToggle",     { Text = "Entities",      Default = false, Tooltip = "Highlights all entities that spawn." })

Toggles.DoorESPToggle:AddColorPicker("DoorESPColor",           { Text = "Doors",        Default = Color3.fromRGB(0, 200, 255),  Transparency = 0 })
Toggles.HidingSpotESPToggle:AddColorPicker("HidingSpotESPColor", { Text = "Closets", Default = Color3.fromRGB(255, 170, 0),  Transparency = 0 })
Toggles.PlayerESPToggle:AddColorPicker("PlayerESPColor",       { Text = "Players",      Default = Color3.fromRGB(255, 255, 255), Transparency = 0 })
Toggles.ChestESPToggle:AddColorPicker("ChestESPColor",         { Text = "Loot Chests",       Default = Color3.fromRGB(255, 255, 0),   Transparency = 0 })
Toggles.ItemESPToggle:AddColorPicker("ItemESPColor",           { Text = "Items",        Default = Color3.fromRGB(170, 0, 255),   Transparency = 0 })
Toggles.CurrencyESPToggle:AddColorPicker("CurrencyESPColor",   { Text = "Gold",     Default = Color3.fromRGB(255, 255, 0),   Transparency = 0 })
Toggles.LadderESPToggle:AddColorPicker("LadderESPColor",       { Text = "Ladders",      Default = Color3.fromRGB(255, 255, 255), Transparency = 0 })
Toggles.VineDoorESPToggle:AddColorPicker("VineDoorESPColor",   { Text = "Vine Door",    Default = Color3.fromRGB(85, 255, 127), Transparency = 0 })
Toggles.MissingObjectESPToggle:AddColorPicker("MissingObjectESPColor", { Text = "Missing Objects", Default = Color3.fromRGB(255, 233, 92), Transparency = 0 })
Toggles.EntityESPToggle:AddColorPicker("EntityESPColor",       { Text = "Entities",     Default = Color3.fromRGB(255, 0, 0),     Transparency = 0 })

local HidingSpotLabels = {
	Wardrobe = "Closet", ["Backdoor_Wardrobe"] = "Closet", Toolshed = "Closet",
	RetroWardrobe = "Closet", ["Wardrobe-FOOLS26"] = "Closet",
	Locker_Large = "Locker", Rooms_Locker = "Locker", Rooms_Locker_Fridge = "Locker",
	Bed = "Bed", Double_Bed = "Double Bed", CircularVent = "Vent", Dumpster = "Dumpster"
}
local ChestLabels = {
	ChestBox = true, ChestBoxLocked = true, Toolbox = true, Toolbox_Locked = true,
	Chest_Vine = "Vine Chest", Toolshed_Small = "Toolshed", Locker_Small_Locked = "Locked Item Locker", MouseHole = "Mouse"
}
local EntityESPLabels = {
	JeffTheKiller = "Jeff the Killer", GiggleCeiling = "Giggle",
	Snare = "Snare", GrumbleRig = "Grumble",
	Drakobloxxer = "Drakobloxxer", Hole = "Mandrake Hole", Groundskeeper = "Groundskeeper",
	LiveEntityBramble = "Bramble", Figure = "Figure", FigureRig = "Figure", FigureRagdoll = "Figure",
	FakeDoor = "Dupe", DoorFake = "Dupe",
	TellerEntity = "Teller", TellerRig = "Teller", Creak = "Creak",
	Cobbler = "Cobbler", NoiseModel = "Noise"
}

local NodeEntities = {
	Rush = true, Ambush = true, Eyes = true, Blitz = true, Lookman = true, ["A-60"] = true, ["A-120"] = true, Sally = true, ["Jeff The Killer"] = true, Monument = true, ["AR0xMBUSH"] = true, ["RNIUSHCG=="] = true,
	Bash = true, Teller = true, Creak = true
}

local StairwellDebrisNames = {
	BrokenMonitor = true,
	DinkyLamp = true,
	GweenSodaPack = true,
}

local function GetItemESPLabel(Object)
	if not Object then return end
	return ItemNames[Object.Name] or SpecialItemESPLabels[Object.Name] or (Object.Name == "Green_Herb" and "Green Herb")
end

local function GetEntityESPText(Object, Label)
	if Label == "Creak" and Object then
		local RoomNumber = Object:GetAttribute("RoomNumber")
		if RoomNumber ~= nil then
			return "Creak [" .. tostring(RoomNumber) .. "]"
		end
	end

	return Label
end

Toggles.DoorESPToggle:OnChanged(function(Value)
	for _, Object in Objects.Doors do
		if Value then Functions.AddESP({ Object = Object, Text = "Door " .. Functions.GetDoorNumber(Object), Color = Options.DoorESPColor.Value }, true)
		else Functions.RemoveESP(Object) end
	end
end)
Options.DoorESPColor:OnChanged(function(Value)
	for _, Object in Objects.Doors do Ostium.ESPLibrary:UpdateObjectColor(Object, Value) end
end)

Toggles.HidingSpotESPToggle:OnChanged(function(Value)
	for _, Object in Objects.HidingSpots do
		local Label = HidingSpotLabels[Object.Name] or (string.match(Object.Name, "^HidingSpot%d$") and "Hiding Spot")
		if Value and Label then Functions.AddESP({ Object = Object, Text = Label, Color = Options.HidingSpotESPColor.Value }, true)
		elseif not Value then Functions.RemoveESP(Object) end
	end
end)
Options.HidingSpotESPColor:OnChanged(function(Value)
	for _, Object in Objects.HidingSpots do Ostium.ESPLibrary:UpdateObjectColor(Object, Value) end
end)

Toggles.PlayerESPToggle:OnChanged(function(Value)
	task.wait()
	for _, Player in Services.Players:GetPlayers() do
		if Player.Character and Player ~= LocalPlayer then
			if Value and Player:GetAttribute("Alive") == true then
				Functions.AddESP({ Object = Player.Character, Text = Player.Name, Color = Options.PlayerESPColor.Value })
			else
				Functions.RemoveESP(Player.Character)
			end
		end
	end
end)
Options.PlayerESPColor:OnChanged(function(Value)
	for _, Player in Services.Players:GetPlayers() do
		if Player.Character and Player ~= LocalPlayer then
			Ostium.ESPLibrary:UpdateObjectColor(Player.Character, Value)
		end
	end
end)

Toggles.ChestESPToggle:OnChanged(function(Value)
	for _, Object in Objects.Chests do
		if Value then
			local Label
			if Object.Name == "ChestBox" or Object.Name == "ChestBoxLocked" then
				Label = Object:GetAttribute("Locked") and "Locked Chest" or "Chest"
			elseif Object.Name == "Toolbox" or Object.Name == "Toolbox_Locked" then
				Label = Object:GetAttribute("Locked") and "Locked Toolbox" or "Toolbox"
			elseif ChestLabels[Object.Name] and ChestLabels[Object.Name] ~= true then
				Label = ChestLabels[Object.Name]
			end
			if Label then Functions.AddESP({ Object = Object, Text = Label, Color = Options.ChestESPColor.Value }, true) end
		else
			Functions.RemoveESP(Object)
		end
	end
end)

Options.ChestESPColor:OnChanged(function(Value)
	for _, Object in Objects.Chests do Ostium.ESPLibrary:UpdateObjectColor(Object, Value) end
end)

Toggles.ItemESPToggle:OnChanged(function(Value)
	for _, Object in Objects.Items do
		if Value then
			local Label = GetItemESPLabel(Object)
			if Label then
				Functions.AddESP({ Object = Object, Text = Label, Color = Options.ItemESPColor.Value }, Object:GetAttribute("ParentRoom") ~= nil)
			end
		else
			Functions.RemoveESP(Object)
		end
	end
end)
Options.ItemESPColor:OnChanged(function(Value)
	for _, Object in Objects.Items do Ostium.ESPLibrary:UpdateObjectColor(Object, Value) end
end)

Toggles.CurrencyESPToggle:OnChanged(function(Value)
	for _, Object in Objects.Currency do
		if Value then
			local Label
			if Object.Name == "GoldPile" and Object:GetAttribute("GoldValue") then
				Label = "Gold Pile [" .. Object:GetAttribute("GoldValue") .. "]"
			elseif Object.Name == "StardustPickup" then
				Label = "Stardust Pile"
			end
			if Label then Functions.AddESP({ Object = Object, Text = Label, Color = Options.CurrencyESPColor.Value }, true) end
		else
			Functions.RemoveESP(Object)
		end
	end
end)
Options.CurrencyESPColor:OnChanged(function(Value)
	for _, Object in Objects.Currency do Ostium.ESPLibrary:UpdateObjectColor(Object, Value) end
end)

Toggles.EntityESPToggle:OnChanged(function(Value)
	for _, Object in Objects.Entities do
		if Value then
			local Label = EntityESPLabels[Object.Name]
			if not Label and Entities[Object.Name] then Label = Entities[Object.Name].Alias end
			if Label and Options.EntityESPOptions.Value[Label] then
				Functions.AddESP({ Object = Object, Text = GetEntityESPText(Object, Label), Color = Options.EntityESPColor.Value }, NodeEntities[Label] ~= true)
			else
				Functions.RemoveESP(Object)
			end
		else
			Functions.RemoveESP(Object)
		end
	end
end)

Options.EntityESPOptions:OnChanged(function(Value)
	for _, Object in Objects.Entities do
		if Toggles.EntityESPToggle.Value then
			local Label = EntityESPLabels[Object.Name]
			if not Label and Entities[Object.Name] then Label = Entities[Object.Name].Alias end
			if Label and Options.EntityESPOptions.Value[Label] then
				Functions.AddESP({ Object = Object, Text = GetEntityESPText(Object, Label), Color = Options.EntityESPColor.Value }, NodeEntities[Label] ~= true)
			else
				Functions.RemoveESP(Object)
			end
		else
			Functions.RemoveESP(Object)
		end
	end
end)

Options.EntityESPColor:OnChanged(function(Value)
	for _, Object in Objects.Entities do Ostium.ESPLibrary:UpdateObjectColor(Object, Value) end
end)

Toggles.LadderESPToggle:OnChanged(function(Value)
	for _, Object in Objects.Ladders do
		if Value then Functions.AddESP({ Object = Object, Text = "Ladder", Color = Options.LadderESPColor.Value }, true)
		else Functions.RemoveESP(Object) end
	end
end)
Options.LadderESPColor:OnChanged(function(Value)
	for _, Object in Objects.Ladders do Ostium.ESPLibrary:UpdateObjectColor(Object, Value) end
end)

Groupboxes.Visuals_ESP_Settings:AddToggle("ESPRainbow",     { Text = "Rainbow Colors", Default = false, Tooltip = "Makes the esp objects change colour like a rainbow." })
Groupboxes.Visuals_ESP_Settings:AddToggle("ESPShowDistance",{ Text = "Show Distance",  Default = true,  Tooltip = "Shows how far away your character is from the object." })
Groupboxes.Visuals_ESP_Settings:AddDivider()
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPFillTransparency",        { Text = "Fill Transparency",         Min = 0, Max = 1, Default = 0.75, Rounding = 2, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPOutlineTransparency",     { Text = "Outline Transparency",      Min = 0, Max = 1, Default = 0,    Rounding = 2, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPTextTransparency",        { Text = "Text Transparency",         Min = 0, Max = 1, Default = 0,    Rounding = 2, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPTextOutlineTransparency", { Text = "Text Outline Transparency", Min = 0, Max = 1, Default = 0,    Rounding = 2, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPFadeTime",                { Text = "Fade Time",                 Min = 0, Max = 1, Default = 0.25, Rounding = 2, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPRenderLimit",             { Text = "Render Limit",              Min = 30, Max = 240, Default = 240, Rounding = 0, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPTextSize",                { Text = "Text Size",                 Min = 12, Max = 24, Default = 20, Rounding = 0, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddDropdown("ESPTextFont", {
	Text = "Text Font",
	Values = { "Legacy","Arial","ArialBold","SourceSans","SourceSansBold","SourceSansLight","SourceSansItalic","Bodoni","Garamond","Cartoon","Code","Highway","SciFi","Arcade","Fantasy","Antique","SourceSansSemibold","Gotham","GothamMedium","GothamBold","GothamBlack","AmaticSC","Bangers","Creepster","DenkOne","Fondamento","FredokaOne","GrenzeGotisch","IndieFlower","JosefinSans","Jura","Kalam","LuckiestGuy","Merriweather","Michroma","Nunito","Oswald","PatrickHand","PermanentMarker","Roboto","RobotoCondensed","RobotoMono","Sarpanch","SpecialElite","TitilliumWeb","Ubuntu","BuilderSans","BuilderSansMedium","BuilderSansBold","BuilderSansExtraBold","Arimo","ArimoBold" },
	Default = 12
})
Groupboxes.Visuals_ESP_Settings:AddDivider()
Groupboxes.Visuals_ESP_Settings:AddDropdown("ESPTracersOrigin",  { Text = "Tracer Origin", Values = { "Bottom","Center","Top","Mouse" }, Default = 1 })
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPTracerThickness",  { Text = "Tracer Thickness", Min = 0.5, Max = 2, Default = 0.75, Rounding = 2, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddToggle("ESPTracersToggle",    { Text = "Tracers", Default = false, Tooltip = "Draws a line to highlighted objects." })
Groupboxes.Visuals_ESP_Settings:AddDivider()
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPArrowsRadius",     { Text = "Arrow Radius", Min = 100, Max = 500, Default = 250, Rounding = 0, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddToggle("ESPArrowsToggle",     { Text = "Off-Screen Arrows", Default = false, Tooltip = "Shows arrow that point to off-screen objects." })

Ostium.ESPLibrary:SetRainbow(false)
Ostium.ESPLibrary:SetShowDistance(true)
Ostium.ESPLibrary:SetFillTransparency(0.75)
Ostium.ESPLibrary:SetOutlineTransparency(0)
Ostium.ESPLibrary:SetTextTransparency(0)
Ostium.ESPLibrary:SetTextOutlineTransparency(0)
Ostium.ESPLibrary:SetRenderLimit(240)
Ostium.ESPLibrary:SetFadeTime(0.25)
Ostium.ESPLibrary:SetTextSize(20)
Ostium.ESPLibrary:SetFont(Enum.Font.Highway)
Ostium.ESPLibrary:SetTracers(false)
Ostium.ESPLibrary:SetTracerSize(0.75)
Ostium.ESPLibrary:SetTracerOrigin("Bottom")
Ostium.ESPLibrary:SetArrows(false)
Ostium.ESPLibrary:SetArrowRadius(250)
Ostium.ESPLibrary:SetDistanceSizeRatio(0.8)

Toggles.ESPRainbow:OnChanged(function(V)        Ostium.ESPLibrary:SetRainbow(V) end)
Toggles.ESPShowDistance:OnChanged(function(V)   Ostium.ESPLibrary:SetShowDistance(V) end)
Options.ESPFillTransparency:OnChanged(function(V)        Ostium.ESPLibrary:SetFillTransparency(V) end)
Options.ESPOutlineTransparency:OnChanged(function(V)     Ostium.ESPLibrary:SetOutlineTransparency(V) end)
Options.ESPTextTransparency:OnChanged(function(V)        Ostium.ESPLibrary:SetTextTransparency(V) end)
Options.ESPTextOutlineTransparency:OnChanged(function(V) Ostium.ESPLibrary:SetTextOutlineTransparency(V) end)
Options.ESPFadeTime:OnChanged(function(V)        Ostium.ESPLibrary:SetFadeTime(V) end)
Options.ESPRenderLimit:OnChanged(function(V)     Ostium.ESPLibrary:SetRenderLimit(V) end)
Options.ESPTextSize:OnChanged(function(V)        Ostium.ESPLibrary:SetTextSize(V) end)
Options.ESPTextFont:OnChanged(function(V)        Ostium.ESPLibrary:SetFont(Enum.Font[V]) end)
Toggles.ESPTracersToggle:OnChanged(function(V)   Ostium.ESPLibrary:SetTracers(V) end)
Options.ESPTracersOrigin:OnChanged(function(V)   Ostium.ESPLibrary:SetTracerOrigin(V) end)
Options.ESPTracerThickness:OnChanged(function(V) Ostium.ESPLibrary:SetTracerSize(V) end)
Toggles.ESPArrowsToggle:OnChanged(function(V)    Ostium.ESPLibrary:SetArrows(V) end)
Options.ESPArrowsRadius:OnChanged(function(V)    Ostium.ESPLibrary:SetArrowRadius(V) end)

Tabs.Floors:UpdateWarningBox({
	Visible = true,
	Title = "Floor Compatibility",
	Text = "Disabled features do not work on the current floor (" .. Floor .. ").",
})

Groupboxes.Floors_Automation = Tabs.Floors:AddRightGroupbox("Auto Tools")
Groupboxes.Floors_Automation:AddToggle("AutoSteerMinecart", {
	Text = "Auto Minecart", Default = false, Tooltip = "Automatically completes the minecart chase. (Mines only)",
	Disabled = Floor ~= "Mines" or not Functions.CheckCompatability({"require"}),
	DisabledTooltip = Floor ~= "Mines" and "This feature only works on the Mines floor." or Globals.IncompatibleMessage
})
Groupboxes.Floors_Automation:AddSlider("AutoSteerMinecartTurnDistance", {
	Text = "Turn Distance", Min = 20, Max = 40, Default = 30, Rounding = 0,
	Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Floors_Automation:AddSlider("AutoSteerMinecartDuckDistance", {
	Text = "Crouch Distance", Min = 20, Max = 40, Default = 30, Rounding = 0,
	Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Floors_Automation:AddToggle("AutoMinecartPush", {
	Text = "Auto Minecart Push",
	Default = false,
	Tooltip = "Automatically pushes nearby minecarts. (Mines only)",
	Disabled = Floor ~= "Mines" or not Functions.CheckCompatability({"fireproximityprompt"}),
	DisabledTooltip = Floor ~= "Mines" and "This feature only works on the Mines floor." or Globals.IncompatibleMessage,
})
Toggles.AutoMinecartPush:OnChanged(function(Value)
	Functions.SetAutoMinecartPushState(Value)
end)
Groupboxes.Floors_Automation:AddDivider()
Groupboxes.Floors_Automation:AddToggle("RoomsAutoWalk",             { Text = "Auto Rooms",       Default = false, Tooltip = "Automatically moves and hides from entities in The Rooms." })
Groupboxes.Floors_Automation:AddSlider("RoomsAutoWalkPathfindTimeout", { Text = "Pathfind Timeout", Min = 0.5, Max = 3, Default = 1, Rounding = 1 })
Groupboxes.Floors_Automation:AddToggle("RoomsAutoWalkIgnoreA60",    { Text = "Ignore A-60",      Default = false, Tooltip = "Continues to walk if entity 'A-60' is present, enables position spoof automatically." })
Groupboxes.Floors_Automation:AddToggle("RoomsAutoWalkShowPathToggle", { Text = "Show Path",       Default = false, Tooltip = "Shows the current path of rooms auto-walk." })
Groupboxes.Floors_Automation:AddToggle("RoomsAutoWalkSpoofFootsteps", {
    Text = "Spoof Footsteps", Default = false, Tooltip = "Makes it appear as if your character is walking normally.",
    Disabled = not Functions.CheckCompatability({"hookmetamethod", "newcclosure", "getnamecallmethod"}), DisabledTooltip = Globals.IncompatibleMessage
})

Toggles.RoomsAutoWalk:OnChanged(function()
	for _, Object in Globals.RoomsNodesFolder:GetChildren() do
		if Object.Name == "PathNode" then Object:Destroy() end
	end
end)
Toggles.RoomsAutoWalkShowPathToggle:AddColorPicker("RoomsAutoWalkShowPathColor", { Text = "Route", Default = Color3.fromRGB(255, 85, 85), Transparency = 0 })
Toggles.RoomsAutoWalkShowPathToggle:OnChanged(function(Value)
	for _, Object in Globals.RoomsNodesFolder:GetChildren() do
		if Object.Name == "PathNode" then Object.Transparency = Value and 0.5 or 1 end
	end
end)
Options.RoomsAutoWalkShowPathColor:OnChanged(function(Value)
	for _, Object in Globals.RoomsNodesFolder:GetChildren() do
		if Object.Name == "PathNode" then Object.Color = Value end
	end
end)

Functions.RoomsAutoWalk = {}
Functions.RoomsAutoWalk.GetNearestHidingSpot = function()
	local Nearest = { Distance = math.huge, Object = nil }
	for _, Object in Objects.HidingSpots do
		if Object.PrimaryPart and Object:FindFirstChild("HidePrompt") then
			local Distance = LocalPlayer:DistanceFromCharacter(Object.PrimaryPart.Position)
			if Distance < Nearest.Distance and Object.PrimaryPart.Position.Y > -10 then
				local HiddenPlayer = Object:FindFirstChild("HiddenPlayer", true)
				if HiddenPlayer and not HiddenPlayer.Value then
					Nearest.Distance = Distance
					Nearest.Object = Object
				end
			end
		end
	end
	return Nearest.Object
end

local RoomsEntityList = { "RushMoving","AmbushMoving","BackdoorRush","A60","A120","CustomEntity","GlitchRush","GlitchAmbush" }
Functions.RoomsAutoWalk.GetPathfindTarget = function()
	for _, Object in Services.Workspace:GetChildren() do
		if table.find(RoomsEntityList, Object.Name) and Object.PrimaryPart then
			local Y = Object.PrimaryPart.Position.Y
			if Y > -10 and Y < 150 then
				if Object.Name == "A60" and not Toggles.RoomsAutoWalkIgnoreA60.Value or Object.Name ~= "A60" then
					return Functions.RoomsAutoWalk.GetNearestHidingSpot() or CurrentRooms[tostring(LatestRoom.Value)]:FindFirstChild("RoomExit")
				end
			end
		end
	end
	return CurrentRooms[tostring(LatestRoom.Value)]:FindFirstChild("RoomExit")
end

Connections.RoomsAutoWalkHandler = Services.RunService.Heartbeat:Connect(function()
	if Floor ~= "Rooms" or not Toggles.RoomsAutoWalk.Value or Globals.RoomsAutoWalkActive or not CollisionPart or LatestRoom.Value >= 1000 then return end
	Globals.RoomsAutoWalkActive = true

	local Path = Services.PathfindingService:CreatePath({
		AgentCanJump = true, AgentCanClimb = false, WaypointSpacing = 4,
		AgentRadius = 1.5, AgentHeight = 1.5, Costs = { StuckPart = 8 }
	})

	if Toggles.RoomsAutoWalkIgnoreA60.Value and not Toggles.PositionSpoof.Value then
		Toggles.PositionSpoof:SetValue(true)
	end

	local TargetPart = Functions.RoomsAutoWalk.GetPathfindTarget()
	if not TargetPart then
		Globals.RoomsAutoWalkActive = false
		return
	end

	local TargetPosition
	if TargetPart.Name == "RoomExit" then
		TargetPosition = TargetPart.Position
	elseif TargetPart:FindFirstChild("HidePrompt") then
		for _, Part in TargetPart:GetDescendants() do
			if Part:IsA("BasePart") then Part.CanCollide = false end
		end
		TargetPosition = TargetPart.PrimaryPart.Position
	end

	if CollisionPart.Anchored and not TargetPart:FindFirstChild("HidePrompt") then
		Character:SetAttribute("Hiding", true)
		RemotesFolder.CamLock:FireServer()
		Character:SetAttribute("Hiding", false)
	end

	local CurrentRoom = CurrentRooms[tostring(LatestRoom.Value)]
	if CurrentRoom:FindFirstChild("Door") then
		CurrentRoom.Door.Door.CanCollide = false
	end

	if not TargetPosition or LocalPlayer:DistanceFromCharacter(TargetPosition) >= 750 then
		Globals.RoomsAutoWalkActive = false
		return
	end

	Path:ComputeAsync(CollisionPart.Position, TargetPosition)
	local Waypoints = Path:GetWaypoints()

	if #Waypoints == 0 then
		local RoomExit = CurrentRoom:FindFirstChild("RoomExit")
		if RoomExit then Humanoid:MoveTo(RoomExit.Position) end
		Globals.RoomsAutoWalkActive = false
		return
	end

	for _, Node in Globals.RoomsNodesFolder:GetChildren() do
		if Node.Name == "PathNode" then Node:Destroy() end
	end

	for _, Waypoint in Waypoints do
		local Block = Instance.new("Part", Globals.RoomsNodesFolder)
		Block.Transparency = Toggles.RoomsAutoWalkShowPathToggle.Value and 0.5 or 1
		Block.Size = Vector3.one
		Block.Position = Waypoint.Position
		Block.Shape = Enum.PartType.Ball
		Block.CanCollide = false
		Block.Anchored = true
		Block.Name = "PathNode"
		Block.Color = Options.RoomsAutoWalkShowPathColor.Value
		Block.Material = Enum.Material.ForceField
	end

	local Stuck = false
	for _, Waypoint in Waypoints do
		if Stuck or not Toggles.RoomsAutoWalk.Value then break end

		local Finished = false
		local Start = tick()

		local StepConnection = Services.RunService.RenderStepped:Connect(function()
			if Stuck or not Toggles.RoomsAutoWalk.Value then Finished = true return end

			local NewTarget = Functions.RoomsAutoWalk.GetPathfindTarget()
			if NewTarget and NewTarget:FindFirstChild("HidePrompt") and not TargetPart:FindFirstChild("HidePrompt") then
				Finished = true return
			end
			if TargetPart:FindFirstChild("HidePrompt") then
				local HidePrompt = TargetPart:FindFirstChild("HidePrompt")
				if LocalPlayer:DistanceFromCharacter(TargetPosition) < HidePrompt.MaxActivationDistance
					and Character:GetAttribute("Hiding") ~= true
				then
					Functions.ForceFirePrompt(HidePrompt)
				end
			end
			local FlatPos = Vector3.new(Waypoint.Position.X, RootPart.Position.Y, Waypoint.Position.Z)
			if LocalPlayer:DistanceFromCharacter(FlatPos) < 5 then Finished = true end
			Humanoid:MoveTo(Waypoint.Position)
		end)

		while not Finished do
			if tick() - Start > Options.RoomsAutoWalkPathfindTimeout.Value then
				local StuckBlock = Instance.new("Part", Globals.RoomsNodesFolder)
				StuckBlock.Transparency = 1
				StuckBlock.Size = Vector3.one
				StuckBlock.CFrame = Collision.CFrame
				StuckBlock.Shape = Enum.PartType.Ball
				StuckBlock.CanCollide = false
				StuckBlock.Anchored = true
				StuckBlock.Name = "StuckPart"
				local Modifier = Instance.new("PathfindingModifier", StuckBlock)
				Modifier.Label = "StuckPart"
				Stuck = true
				break
			end
			task.wait()
		end
		StepConnection:Disconnect()
		Humanoid:MoveTo(RootPart.Position)
	end

	Globals.RoomsAutoWalkActive = false
end)

Connections.RoomsHandler = CurrentRooms.ChildAdded:Connect(function(Room)
	for _, Object in Globals.RoomsNodesFolder:GetChildren() do
		if Object.Name == "StuckPart" then Object:Destroy() end
	end

	if Room:GetAttribute("RawName") and string.find(Room:GetAttribute("RawName"), "Eyestalk") then
        local PreviousNode = nil

		local function CreateEyestalkNode(WaypointPos)
			local NewNode = Instance.new("Part")
			NewNode.Size = Vector3.one
			NewNode.Transparency = 1
			NewNode.Parent = Globals.SeekNodesFolder
			NewNode.Anchored = true
			NewNode.Position = WaypointPos
			NewNode.CanCollide = false
			NewNode.Name = "SeekLightNode"

			local PrevNode = PreviousNode or NewNode
			PreviousNode = NewNode

			local NewBeam = Instance.new("Beam")
			NewBeam.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Options.ShowEyestalkPathColor.Value), ColorSequenceKeypoint.new(1, Options.ShowEyestalkPathColor.Value) })
			NewBeam.FaceCamera = true
			NewBeam.Width0 = 0.35
			NewBeam.Width1 = 0.35
			NewBeam.Brightness = 6
			NewBeam.LightInfluence = 0
			NewBeam.LightEmission = 0
			NewBeam.Enabled = true

			local Vis = Toggles.ShowEyestalkPathToggle.Value and 0 or 1
			NewBeam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, Vis), NumberSequenceKeypoint.new(1, Vis) })
			NewBeam.Parent = Globals.SeekNodesFolder

			local A0 = Instance.new("Attachment", NewNode)
			local A1 = Instance.new("Attachment", PrevNode)
			NewBeam.Attachment0 = A0
			NewBeam.Attachment1 = A1

			table.insert(Objects.EyestalkHighlights, NewBeam)
		end

		Room:WaitForChild("RoomEntrance", 9e9)
		Room:WaitForChild("RoomExit", 9e9)

		while not Room:GetAttribute("PathFound") do
			if Toggles.ShowEyestalkPathToggle.Value then
				local EyePath = game:GetService("PathfindingService"):CreatePath({
					AgentCanJump = false, AgentCanClimb = false, WaypointSpacing = 2, AgentRadius = 1, AgentHeight = 1
				})
				EyePath:ComputeAsync(RootPart.Position, Room.RoomExit.Position)
				if EyePath.Status == Enum.PathStatus.Success then
					Room:SetAttribute("PathFound", true)
					for _, Waypoint in EyePath:GetWaypoints() do
						CreateEyestalkNode(Waypoint.Position)
						task.wait()
					end
                    break
				end
			end
			task.wait(0.25)
		end
	end
end)

local ArchivesFloor = GameData:FindFirstChild("ArchivesDayPhase") ~= nil
local ArchivesDisabledTip = "You must be in the Archives floor to use this."
local ArchivesHookCompat = Functions.CheckCompatability({ "hookmetamethod", "newcclosure", "getnamecallmethod" })
local ArchivesPromptCompat = Functions.CheckCompatability({ "fireproximityprompt" })
local ArchivesCompatTypes = {
	Hook = { Enabled = ArchivesHookCompat, Tooltip = Globals.IncompatibleMessage },
	Prompt = { Enabled = ArchivesPromptCompat, Tooltip = Globals.IncompatibleMessage },
}
local ArchivesFeatureToggles = {
	{
		Name = "AntiDrones",
		Text = "Anti Drones",
		Tooltip = "Stops Drones from trampling, shoving or knocking you down.",
	},
	{
		Name = "DisableDroneEffects",
		Text = "Anti Drone Effects",
		Tooltip = "Removes the drone screen effects (blur, footstep stomps) when you get knocked down.",
	},
	{
		Name = "AntiPaperCut",
		Text = "Anti Scribbles",
		Tooltip = "Stops the Scribbles paper aeroplanes from cutting you.",
		Compat = "Hook",
	},
	{
		Name = "AntiAlma",
		Text = "Anti Alma",
		Tooltip = "Prevents Alma from noticing you by blocking her trigger box and forcing your look direction away from her.",
		Compat = "Hook",
	},
	{
		Name = "AntiPoolShock",
		Text = "Anti Pool Shock",
		Tooltip = "Raises your HipHeight so electrified pools cannot shock you. Can interfere with God Mode.",
	},
	{
		Name = "AntiPortraitHaunt",
		Text = "Anti Portrait Haunt",
		Tooltip = "Cancels the Portrait mirror-crack jumpscare before it can catch you.",
	},
	{
		Name = "PaperPlaneNoCooldown",
		Text = "Anti Paper Plane Cooldown",
		Tooltip = "Removes the Paper Plane throw cooldown so you can throw it back-to-back.",
	},
	{
		Name = "ArchivesAnticheatBypass",
		Text = "Anti Archives Anticheat",
		Tooltip = "under developement",
		ForcedDisabled = true,
	},
	{
		Name = "TellerDoorCounter",
		Text = "Show Teller Door Counter",
		Tooltip = "Appends a (passed/ticket) counter to Door ESP so you know how many doors until the Teller asks for your ticket back.",
	},
}
local ArchivesAutomationToggles = {
	{
		Name = "AutoPortraitDupe",
		Text = "Auto Portrait Dupe",
		Tooltip = "Automatically uses the mirror to duplicate your held tool (limited uses, set by the server).",
		Compat = "Prompt",
	},
	{
		Name = "AutoTellerTicket",
		Text = "Auto Teller Ticket",
		Tooltip = "Automatically gives/takes the ticket the moment the Teller's prompt becomes available.",
		Compat = "Prompt",
	},
	{
		Name = "AutoArchivesCloset",
		Text = "Auto Archives Closet",
		Tooltip = "Automatically enters nearby Archives hiding spots.",
		Compat = "Prompt",
	},
}

local StairwellFeatureToggles = {
	{
		Name = "AntiNoiseAudio",
		Text = "Anti Noise Audio",
		Tooltip = "Mutes Noise's client-side warning and emerge sounds.",
	},
	{
		Name = "AntiNoiseVisuals",
		Text = "Anti Noise Visuals",
		Tooltip = "Hides Noise's client-side model and vignette effects.",
	},
	{
		Name = "NoCreakJumpscare",
		Text = "Anti Creak Jumpscare",
		Tooltip = "Disables the local Creak death jumpscare module.",
	},
}

local StairwellAutomationToggles = {
	{
		Name = "AutoDisposeNoiseTV",
		Text = "Auto Dispose Noise TV",
		Tooltip = "Automatically uses nearby TV Stand cart prompts when they become available.",
		Compat = "Prompt",
	},
}

local function AddFloorToggle(Groupbox, Config)
	local Disabled = not ArchivesFloor
	local DisabledTooltip = ArchivesDisabledTip

	if Config.ForcedDisabled then
		Disabled = true
		DisabledTooltip = Config.Tooltip or "under developement"
	end

	if not Disabled and Config.Compat then
		local Compat = ArchivesCompatTypes[Config.Compat]
		if Compat and not Compat.Enabled then
			Disabled = true
			DisabledTooltip = Compat.Tooltip
		end
	end

	Groupbox:AddToggle(Config.Name, {
		Text = Config.Text,
		Default = Config.Default == true,
		Tooltip = Config.Tooltip,
		Disabled = Disabled,
		DisabledTooltip = DisabledTooltip,
	})
end

Groupboxes.Floors_Archives = Tabs.Floors:AddLeftGroupbox("Archives")
Groupboxes.Floors_Archives.Disabled = not ArchivesFloor
Groupboxes.Floors_Archives.DisabledTooltip = ArchivesDisabledTip
for _, Config in ArchivesFeatureToggles do
	AddFloorToggle(Groupboxes.Floors_Archives, Config)
end
Groupboxes.Floors_Archives:AddDivider()
for _, Config in ArchivesAutomationToggles do
	AddFloorToggle(Groupboxes.Floors_Archives, Config)
end

Groupboxes.Floors_Stairwell = Tabs.Floors:AddLeftGroupbox("Stairwell")
Groupboxes.Floors_Stairwell.Disabled = not ArchivesFloor
Groupboxes.Floors_Stairwell.DisabledTooltip = ArchivesDisabledTip
for _, Config in StairwellFeatureToggles do
	AddFloorToggle(Groupboxes.Floors_Stairwell, Config)
end
Groupboxes.Floors_Stairwell:AddDivider()
for _, Config in StairwellAutomationToggles do
	AddFloorToggle(Groupboxes.Floors_Stairwell, Config)
end

Groupboxes.Floors_Completion = Tabs.Floors:AddRightGroupbox("Objectives")
Groupboxes.Floors_Completion:AddButton({
    Text = "Auto Complete Dam Seek",
    Tooltip = "Automatically teleports to and interacts with each water pump.",
    Func = function()
        if LatestRoom.Value < 100 or Floor ~= "Mines" then
            Functions.Notify({Title = "You must be in Room 200 to do this."})
            return
        end

		local IsCutscene = false
		local CutsceneConnection = RemotesFolder.Cutscene.OnClientEvent:Connect(function()
			IsCutscene = true
			task.wait(7)
			IsCutscene = false
		end)

        local function GetNextPump()
            local Highest = {
                Height = -69420,
                Object = nil
            }
            for _, Object in pairs(Objects.Objectives) do
                if Object.Name == "WaterPump" and Object:GetAttribute("Ostium_Completed") ~= true then
                    if Object.PrimaryPart and Object.PrimaryPart.Position.Y > Highest.Height then
                        Highest.Object = Object
                        Highest.Height = Object.PrimaryPart.Position.Y
                    end
                end
            end
            return Highest.Object
        end

        local function HandlePump(Pump)

            while task.wait(0.1) do
				if IsCutscene then
					continue
				end

                Character:PivotTo(Pump:GetPivot())

                local Prompt = Pump:FindFirstChild("ValvePrompt", true)
                if Prompt then
                    Functions.ForceFirePrompt(Prompt)
                end

                if Pump:GetAttribute("Ostium_Completed") then
                    break
                end
            end
        end

        Functions.Notify({Title = "Attempting to complete the valves.", Body = "Please wait."})
        while task.wait(0.1) do
            local Pump = GetNextPump()
            if Pump then
                HandlePump(Pump)
            else
                break
            end
        end
        Functions.Notify({Title = "Successfully completed the valves."})
    end
})

Groupboxes.Floors_Completion:AddButton({
    Text = "Auto Complete Cringle",
    Tooltip = "Instantly completes the quest.",
    Func = function()
        local TouchPart = CurrentRooms:FindFirstChild("RippleExitDoor", true)
        if TouchPart then
            Character:PivotTo(TouchPart:GetPivot())
        end
    end
})

Groupboxes.Floors_Visuals = Tabs.Floors:AddLeftGroupbox("Pathfinding")
Groupboxes.Floors_Visuals:AddToggle("ShowSeekPathToggle", {
	Text = "Show Chase Route", Default = false, Tooltip = "Shows you the correct path in seek chases.",
	Disabled = Floor ~= "Mines"
})
Toggles.ShowSeekPathToggle:AddColorPicker("ShowSeekPathColor", { Text = "Route", Default = Color3.fromRGB(0, 170, 255), Transparency = 0 })

local function UpdateBeamVisibility(BeamTable, ColorKey, Visible)
	local Vis = Visible and 0 or 1
	local Seq = NumberSequence.new({ NumberSequenceKeypoint.new(0, Vis), NumberSequenceKeypoint.new(1, Vis) })
	for _, Beam in BeamTable do Beam.Transparency = Seq end
end
local function UpdateBeamColor(BeamTable, Value)
	local Seq = ColorSequence.new({ ColorSequenceKeypoint.new(0, Value), ColorSequenceKeypoint.new(1, Value) })
	for _, Beam in BeamTable do Beam.Color = Seq end
end

Toggles.ShowSeekPathToggle:OnChanged(function(V)  UpdateBeamVisibility(Objects.SeekHighlights, "ShowSeekPathColor", V) end)
Options.ShowSeekPathColor:OnChanged(function(V)   UpdateBeamColor(Objects.SeekHighlights, V) end)

Groupboxes.Floors_Visuals:AddToggle("ShowEyestalkPathToggle", {
	Text = "Show Eyestalk Route", Default = false, Tooltip = "Shows you the correct path in the eyestalk chase.",
	Disabled = Floor ~= "Garden"
})
Toggles.ShowEyestalkPathToggle:AddColorPicker("ShowEyestalkPathColor", { Text = "Route", Default = Color3.fromRGB(255, 0, 170), Transparency = 0 })
Toggles.ShowEyestalkPathToggle:OnChanged(function(V) UpdateBeamVisibility(Objects.EyestalkHighlights, "ShowEyestalkPathColor", V) end)
Options.ShowEyestalkPathColor:OnChanged(function(V)  UpdateBeamColor(Objects.EyestalkHighlights, V) end)

Groupboxes.Floors_Bypass = Tabs.Floors:AddLeftGroupbox("Doors & Gates")
Groupboxes.Floors_Bypass:AddToggle("RemoveSeekTrigger", {
	Text = "Skip Seek", Default = false, Tooltip = "Diables the 'Seek' chase trigger.",
	Disabled = not (Floor == "Fools" or Floor == "OldHotel") or not Functions.CheckCompatability({"firetouchinterest"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Floors_Bypass:AddToggle("RemoveFigure", {
	Text = "Delete Figure", Default = false, Tooltip = "Completely removes the entity 'Figure' (doesn't always work).",
	Disabled = not (Floor == "Fools" or Floor == "OldHotel" or Floor == "Mines") or not Functions.CheckCompatability({"isnetworkowner"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Floors_Bypass:AddToggle("AutoRevive", {
	Text = "Auto Revive", Default = false, Tooltip = "Automatically revives after dying, with unlimited respawns.",
	Disabled = not (Floor == "Fools" or Floor == "OldHotel")
})
Groupboxes.Floors_Bypass:AddToggle("FigureGodmode", {
	Text = "Figure Immunity", Default = false, Tooltip = "Prevents 'Figure' from hurting you.",
	Disabled = not (Floor == "Fools" or Floor == "OldHotel")
})
Groupboxes.Floors_Bypass:AddDivider()
Groupboxes.Floors_Bypass:AddToggle("RemoveBasementGate",  { Text = "Open Basement Gate",   Default = false, Tooltip = "Removes the gate from basement rooms.",            Disabled = not (Floor == "Fools" or Floor == "OldHotel") })
Groupboxes.Floors_Bypass:AddToggle("RemovePaintingsDoor", { Text = "Open Painting Door",  Default = false, Tooltip = "Removes the fireplace doors from painting rooms.", Disabled = not (Floor == "Fools" or Floor == "OldHotel") })
Groupboxes.Floors_Bypass:AddToggle("RemoveSkeletonDoor",  { Text = "Open Skeleton Door",   Default = false, Tooltip = "Removes the skeleton door from the infirmary.",    Disabled = Floor ~= "Fools" })

do
	
	
	
	
	
	
	

	local AGENT_RADIUS = 3    
	local REACH_DISTANCE = 4  
	local WALK_SPEED = 14     

	local function GetBramble()
		for _, Model in Services.Workspace:GetChildren() do
			if Model:IsA("Model") then
				if string.find(Model.Name, "Bramble") then return Model end
				local Head = Model:FindFirstChild("Head")
				if Head and Head:FindFirstChild("LanternNeon") then return Model end
			end
		end
	end

	local function IsBrambleLightOn()
		local Bramble = GetBramble()
		if not Bramble then return false end
		local Head = Bramble:FindFirstChild("Head")
		local Lantern = Head and Head:FindFirstChild("LanternNeon")
		if not Lantern then return false end
		local Attachment = Lantern:FindFirstChild("Attachment")
		local Beam = Attachment and Attachment:FindFirstChild("Beam")
		if Beam then return Beam.Enabled end
		return Lantern.Material == Enum.Material.Neon
	end

	local function FindMazeRoom()
		for _, Room in Services.Workspace.CurrentRooms:GetChildren() do
			local Assets = Room:FindFirstChild("Assets")
			if Assets and Assets:FindFirstChild("GateSetup") then return Room end
		end
	end

	local function CollectLevers(Room)
		local Levers = {}
		for _, Setup in Room.Assets:GetChildren() do
			if Setup.Name == "GateSetup" then
				local ButtonModel = Setup:FindFirstChild("GardenGateButton")
				local Button = ButtonModel and ButtonModel:FindFirstChild("Button")
				local Prompt = Button and Button:FindFirstChild("ActivateEventPrompt")
				if Prompt and Prompt.Enabled then
					table.insert(Levers, { Button = Button, Prompt = Prompt })
				end
			end
		end
		return Levers
	end

	
	local function OrderByRoute(Levers, FromPosition)
		local Ordered, Remaining, Current = {}, table.clone(Levers), FromPosition
		while #Remaining > 0 do
			local BestIndex, BestDist = 1, math.huge
			for Index, Lever in Remaining do
				local Dist = (Lever.Button.Position - Current).Magnitude
				if Dist < BestDist then BestDist, BestIndex = Dist, Index end
			end
			local Chosen = table.remove(Remaining, BestIndex)
			Current = Chosen.Button.Position
			table.insert(Ordered, Chosen)
		end
		return Ordered
	end

	local function StopMoving(Humanoid, Root)
		Humanoid:MoveTo(Root.Position)
		Humanoid:Move(Vector3.zero, false)
	end

	
	local function WaitForDarkness(Humanoid, Root)
		while IsBrambleLightOn() do
			if not Globals.MazeRunning then return false end
			StopMoving(Humanoid, Root)
			task.wait(0.05)
		end
		return true
	end

	local function WalkTo(TargetPosition)
		local Char = LocalPlayer.Character
		local Humanoid = Char and Char:FindFirstChildOfClass("Humanoid")
		local Root = Char and Char.PrimaryPart
		if not (Humanoid and Root) then return false end

		local Path = Services.PathfindingService:CreatePath({
			AgentRadius = AGENT_RADIUS,
			AgentHeight = 5,
			AgentCanJump = false,
			WaypointSpacing = 4,
		})
		local Ok = pcall(function() Path:ComputeAsync(Root.Position, TargetPosition) end)
		local Waypoints = (Ok and Path.Status == Enum.PathStatus.Success) and Path:GetWaypoints() or nil
		if not Waypoints or #Waypoints == 0 then
			Waypoints = { { Position = TargetPosition } } 
		end

		for _, Waypoint in Waypoints do
			if not Globals.MazeRunning then return false end
			local Started = tick()
			while (Root.Position - Waypoint.Position).Magnitude > REACH_DISTANCE do
				if not Globals.MazeRunning then return false end
				if IsBrambleLightOn() then
					if not WaitForDarkness(Humanoid, Root) then return false end
					Started = tick() 
				else
					Humanoid:MoveTo(Waypoint.Position)
				end
				if tick() - Started > 8 then break end 
				task.wait(0.05)
			end
		end
		return true
	end

	Groupboxes.Floors_Bypass:AddDivider()
	Groupboxes.Floors_Bypass:AddButton({
		Text = "Complete Maze",
		DoubleClick = true,
		Tooltip = "Auto-walks to each Outdoors maze lever and pulls it, freezing whenever Bramble's light is on. Press again to cancel.",
		Disabled = Floor ~= "Garden" or not Functions.CheckCompatability({ "fireproximityprompt" }),
		DisabledTooltip = Globals.IncompatibleMessage,
		Func = function()
			if Globals.MazeRunning then
				Globals.MazeRunning = false 
				Functions.Notify({ Title = "Maze run cancelled." })
				return
			end

			local Room = FindMazeRoom()
			if not Room then
				Functions.Notify({ Title = "Maze not found.", Body = "Stand in the maze room, then try again." })
				return
			end

			local Char = LocalPlayer.Character
			local Root = Char and Char.PrimaryPart
			local Humanoid = Char and Char:FindFirstChildOfClass("Humanoid")
			if not (Root and Humanoid) then return end

			local Levers = OrderByRoute(CollectLevers(Room), Root.Position)
			if #Levers == 0 then
				Functions.Notify({ Title = "All maze levers are already pulled." })
				return
			end

			Globals.MazeRunning = true
			Functions.Notify({ Title = "Completing maze...", Body = "Walking to " .. #Levers .. " lever(s). Press again to cancel." })

			
			
			
			
			local PrevWalkSpeed = Humanoid.WalkSpeed
			pcall(function() Humanoid.WalkSpeed = (PrevWalkSpeed or 16) + WALK_SPEED end)

			task.spawn(function()
				for _, Lever in Levers do
					if not Globals.MazeRunning then break end
					if Lever.Prompt.Enabled then
						
						pcall(function() Humanoid.WalkSpeed = (PrevWalkSpeed or 16) + WALK_SPEED end)
						WalkTo(Lever.Button.Position)
						if not Globals.MazeRunning then break end
						
						for _ = 1, 12 do
							if not Lever.Prompt.Enabled then break end
							if IsBrambleLightOn() then
								WaitForDarkness(Humanoid, Root)
							end
							Ostium.Environment.fireproximityprompt(Lever.Prompt)
							task.wait(0.1)
						end
					end
				end

				
				pcall(function()
					local C = LocalPlayer.Character
					local H = C and C:FindFirstChildOfClass("Humanoid")
					if H then H.WalkSpeed = PrevWalkSpeed end
				end)

				local Finished = Globals.MazeRunning
				Globals.MazeRunning = false
				Functions.Notify({ Title = Finished and "Maze complete." or "Maze run stopped.", Body = "Levers pulled where reachable." })
			end)
		end,
	})
end

local ObstructionNames = { ThingToOpen = "RemoveBasementGate", MovingDoor = "RemovePaintingsDoor", Wax_Door = "RemoveSkeletonDoor" }
for ObjName, ToggleName in ObstructionNames do
	Toggles[ToggleName]:OnChanged(function(Value)
		for _, Object in Objects.Obstructions do
			if Object.Name == ObjName then
				Object:PivotTo(Value and CFrame.new(-10000, -10000, -10000) or Object:GetAttribute("OriginalPosition"))
			end
		end
	end)
end

Groupboxes.Floors_Farming = Tabs.Floors:AddLeftGroupbox("Grinding")

Globals.KnobFarmStarted = false

Groupboxes.Floors_Farming:AddButton({
	Text = "Knob Farm",
	Capability = "LobbyKnobFarm",
	DoubleClick = true,
	Tooltip = "Returns to the lobby, then automatically starts the saved Knob Farm continuation.",
	Func = function()
		if Globals.KnobFarmStarted then
			Functions.Notify({ Title = "Knob Farm", Body = "The lobby handoff is already running." })
			return
		end

		local Queue = ExecutorSupport.Functions.queue_on_teleport
		local ReadFile = ExecutorSupport.Functions.readfile
		local IsFile = ExecutorSupport.Functions.isfile or isfile
		local FarmFile = "ostium_knobfarm.lua"

		if type(Queue) ~= "function" or type(ReadFile) ~= "function" then
			Functions.Notify({
				Title = "Knob Farm",
				Body = "Your executor needs queue_on_teleport and readfile.",
			})
			return
		end

		if type(IsFile) == "function" and not IsFile(FarmFile) then
			Functions.Notify({
				Title = "Knob Farm",
				Body = "No saved Knob Farm continuation was found. Start Knob Farm from the lobby once first.",
			})
			return
		end

		local OkRead, Source = pcall(ReadFile, FarmFile)
		if not OkRead or type(Source) ~= "string" or Source == "" then
			Functions.Notify({
				Title = "Knob Farm",
				Body = "Could not read the saved Knob Farm continuation.",
			})
			return
		end

		if type(delfile) == "function" then
	if type(isfile) == "function" then
		if isfile("ostium_knobfarm_stop.txt") then
			pcall(function()
				delfile("ostium_knobfarm_stop.txt")
			end)
		end
	end
end

		local OkQueue = pcall(Queue, Source)
		if not OkQueue then
			Functions.Notify({
				Title = "Knob Farm",
				Body = "Failed to queue Knob Farm for the lobby teleport.",
			})
			return
		end

		Globals.KnobFarmStarted = true
		Functions.Notify({
			Title = "Knob Farm",
			Body = "Returning to the lobby. Knob Farm will continue automatically.",
		})

		Globals.KnobFarmStarted = true

local LobbyRemote = RemotesFolder and RemotesFolder:FindFirstChild("Lobby")
if not LobbyRemote then
	Globals.KnobFarmStarted = false
	Functions.Notify({
		Title = "Knob Farm",
		Body = "Could not find the lobby remote."
	})
	return
end

Functions.Notify({
	Title = "Knob Farm",
	Body = "Run Knob Farm in lobby"
})

task.wait(1)

LobbyRemote:FireServer()
	end
})

Groupboxes.Floors_Farming:AddToggle("GetGlitchCube", {
	Text = "Get Glitch Cube",
	Default = false,
	Tooltip = "Triggers Glitch three times. Disable this toggle at any time to stop.",
})
Toggles.GetGlitchCube:OnChanged(function(Value)
	if Value then
		task.spawn(Functions.RunGlitchCube)
	else
		Globals.GlitchCube.CancelRequested = true
		Functions.RestoreGlitchCubeMovement()
	end
end)

Groupboxes.Floors_Farming:AddButton({
	Text = "Death Farm",
	DoubleClick = true,
	Tooltip = "Skips the starter elevator and rejoins runs to farm deaths.",
	Disabled = not Functions.CheckCompatability({"fireproximityprompt", "replicatesignal"}),
	DisabledTooltip = Globals.IncompatibleMessage,
	Func = function()
		local Source = [[
local stopped = false

if _G.DEATH_FARM then
    return
end

_G.DEATH_FARM = true

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local RemotesFolder = ReplicatedStorage:WaitForChild("RemotesFolder", 999)

local PlayAgain = RemotesFolder:WaitForChild("PlayAgain", 999)
local Crouch = RemotesFolder:WaitForChild("Crouch", 999)
local environment = getgenv and getgenv() or _G
local synEnvironment = rawget(environment, "syn")
local fluxusEnvironment = rawget(environment, "fluxus")
local queue = queue_on_teleport
    or queueonteleport
    or rawget(environment, "queue_on_teleport")
    or rawget(environment, "queueonteleport")
    or (synEnvironment and synEnvironment.queue_on_teleport)
    or (fluxusEnvironment and fluxusEnvironment.queue_on_teleport)

player.OnTeleport:Connect(function()
    if queue and readfile then
        queue(readfile("doorsdeathfarm.txt"))
    end
end)

local character = player.Character or player.CharacterAdded:Wait()

task.spawn(function()
    local state = true

    while task.wait() do
        Crouch:FireServer(state, state)
    end
end)

local room = workspace
    :WaitForChild("CurrentRooms", 999)
    :WaitForChild("0", 999)

local elevator = room:WaitForChild("StarterElevator", 999)

local CFrame1 = CFrame.new(
    249.999954,
    -0.373500377,
    -9.99999714,
    0.99999994,
    0,
    0.00037855946,
    0,
    1,
    0,
    -0.00037855946,
    0,
    0.99999994
)

local CFrame2 = CFrame.new(
    243.364471,
    -0.373500377,
    -50.2721786,
    0.066934742,
    0,
    0.997757375,
    0,
    1,
    0,
    -0.997757375,
    0,
    0.066934742
)

local CFrame3 = CFrame.new(
    265.486267,
    -0.400000364,
    -48.4754181,
    0.999383152,
    3.15590509e-09,
    0.0351186804,
    -2.2460569e-09,
    1,
    -2.59472621e-08,
    -0.0351186804,
    2.5852378e-08,
    0.999383152
)

local ended = false

local function hasKey()
    local backpack = player:FindFirstChild("Backpack")

    return character:FindFirstChild("Key")
        or (backpack and backpack:FindFirstChild("Key"))
end

RemotesFolder.PreRunShop:FireServer({})

fireproximityprompt(
    elevator.Model.Model.SkipButton.SkipPrompt
)

workspace.CurrentRooms.ChildAdded:Once(function()
    ended = true

    task.wait(0.1)
    replicatesignal(player.Kill)

    task.wait(0.1)
    PlayAgain:FireServer()
end)

RemotesFolder.Statistics.OnClientEvent:Connect(function()
    stopped = true

    if stopped then
        return
    end

    PlayAgain:FireServer()
end)

character:PivotTo(CFrame1)

while not hasKey() do
    character.PrimaryPart.CFrame =
        room.Assets.KeyObtain.Hitbox.CFrame

    fireproximityprompt(
        room.Assets.KeyObtain.ModulePrompt
    )

    task.wait()
end

character:PivotTo(CFrame2)

local function getOpenPrompt()
    for _, instance in room.Door:GetDescendants() do
        if instance:IsA("ProximityPrompt") then
            return instance
        end
    end
end

local promptUnlock = getOpenPrompt()

while not ended do
    character.PrimaryPart.CFrame = CFrame3
    fireproximityprompt(promptUnlock)
    task.wait()
end
]]

		if writefile then
			pcall(writefile, "doorsdeathfarm.txt", Source)
		end
		loadstring(Source)()
	end
})

local MainHook
local OtherHook

local function IsToggleEnabled(Name)
	local Ok, Toggle = pcall(function()
		return Toggles and Toggles[Name]
	end)
	if not Ok or Toggle == nil then
		return false
	end

	local ValueOk, Value = pcall(function()
		return Toggle.Value
	end)
	return ValueOk and Value == true
end

if Functions.CheckCompatability({"hookmetamethod", "newcclosure", "getnamecallmethod"}) then
	MainHook = Ostium.Environment.hookmetamethod(game, "__namecall", Ostium.Environment.newcclosure(function(Self, ...)
		local Args = { ... }
		if Ostium and Ostium.Environment then
			local Method = Ostium.Environment.getnamecallmethod()

			if Self.Name == "Crouch" and Method == "FireServer" then
				if IsToggleEnabled("CrouchSpoof") or IsToggleEnabled("PositionSpoof") then
					Args[1] = true
				end
				Args[2] = true
				local FireServer = Self.FireServer
				return FireServer(Self, table.unpack(Args))
			end

			if (Self.Name == "ClutchHeartbeat" or Self.Name == "HideMonster") and Method == "FireServer" and IsToggleEnabled("AutoHeartbeatMinigame") then
				return
			end

			if Self.Name == "MotorReplication" and Method == "FireServer" then
				local DoBypass = (IsToggleEnabled("BypassEyes") and Globals.IsEyes) or (IsToggleEnabled("BypassLookman") and Globals.IsLookman)
				if DoBypass then
					if Floor == "Fools" or Floor == "OldHotel" then
						Args[1] = 0 Args[2] = (Globals.SpoofOffset == 200 and 65 or -65) Args[3] = 0 Args[4] = false
					else
						Args[1] = -650
					end
				end
			end

			if Method == "FireServer" then
				if Self.Name == "IfYoureExploitingDeleteThis" and IsToggleEnabled("AntiPaperCut") then
					return
				end
				if IsToggleEnabled("AntiAlma") and AlmaRemoteBlocklist[Self.Name] then
					return
				end
				if IsToggleEnabled("AntiDrones") and (Self.Name == "WalkedInto" or Self.Name == "ShoulderChecked" or Self.Name == "Trampled") then
					return
				end
			end
		end
		return MainHook(Self, table.unpack(Args))
	end))

    OtherHook = Ostium.Environment.hookmetamethod(game, "__index", Ostium.Environment.newcclosure(function(Self, Property)
        local Real = OtherHook(Self, Property)

        if Property == "MoveDirection"
            and Self == Humanoid
            and Globals.RoomsAutoWalkActive
            and IsToggleEnabled("RoomsAutoWalkSpoofFootsteps")
            and Floor == "Rooms"
            and Character
            and RootPart
            and not Character:GetAttribute("Hiding") then
            return RootPart.CFrame.LookVector
        end
        
        return Real
    end))
end

if Services.ReplicatedStorage:FindFirstChild("ModulesClient") then
	ClientModules = Services.ReplicatedStorage.ModulesClient
else
	ClientModules = Services.ReplicatedStorage.ClientModules
end

Modules = {
	Glitch         = ClientModules.EntityModules.Glitch,
	Shade          = ClientModules.EntityModules.Shade,
	Void           = ClientModules.EntityModules:FindFirstChild("Void"),
	SpiderJumpscare = nil,
	A90            = nil,
	Screech        = nil,
	Dread          = nil,
	GlitchScreech  = nil,
}

local CharacterOldConnectionKeys = {
	"MainHandler", "JumpHandler", "SlideHandler", "LibraryCodeHandler1", "LibraryCodeHandler2",
	"OxygenConnection", "AnimationHandler", "AutoHideConnection", "AutoReviveHandler",
	"SHMFixer", "AnticheatDisabler", "AnticheatEnableDetector1", "AnticheatEnableDetector2",
	"AutoSteerMinecartDuckHandler", "AutoSolveAnchorsConnection", "InfiniteJumpsConnection1", "InfiniteJumpsConnection2",
	"FootstepHandler", "LadderSpeedHandler", "AntiFiredampCamera", "NoHasteCameraAdded",
	"ArchivesAnticheatSeatHandler", "ArchivesAnticheatCartHandler", "ArchivesAnticheatRestrictHandler"
}

Globals.IsTyping = false
Connections.TextBoxConnection1 = Services.UserInputService.TextBoxFocused:Connect(function()
	Globals.IsTyping = true
end)
Connections.TextBoxConnection2 = Services.UserInputService.TextBoxFocusReleased:Connect(function()
	Globals.IsTyping = false
end)

Functions.HandleCharacter = function(NewCharacter)
	Functions.SetLadderSpeedOverride(false)
	for _, Key in CharacterOldConnectionKeys do
		if Connections[Key] then
			Connections[Key]:Disconnect()
			Connections[Key] = nil
		end
	end

	while not LocalPlayer.PlayerGui:FindFirstChild("MainUI") do
		task.wait()
	end

	Character = NewCharacter
	Humanoid = NewCharacter:WaitForChild("Humanoid", 9e9)
	RootPart = NewCharacter:FindFirstChild("HumanoidRootPart")
	Camera   = Services.Workspace.CurrentCamera
	Globals.BaseJumpPower = Humanoid.JumpPower

	Globals.OldCamera = Camera
	Globals.MainUI = LocalPlayer.PlayerGui.MainUI

	Collision = NewCharacter:WaitForChild("Collision")
	CollisionPart  = NewCharacter:FindFirstChild("CollisionPart") or NewCharacter:FindFirstChild("Collision")
	CollisionClone = Collision:Clone()
	CollisionClone.Parent = NewCharacter
	CollisionClone.Name = "CollisionClone"
	CollisionClone.Massless = true

	CollisionPartClone = CollisionPart:Clone()
	CollisionPartClone.Parent = NewCharacter
	CollisionPartClone.Name = "CollisionPartClone"
	CollisionPartClone.CanCollide = false
	CollisionPartClone.Massless = true

	if CollisionPartClone:FindFirstChild("CollisionCrouch") then
		CollisionPartClone.CollisionCrouch:Destroy()
	end

	Character:SetAttribute("SpeedBoost", 0)
	Character:SetAttribute("SpeedBoostBehind", 0)
	Character:SetAttribute("SpeedBoostExtra", 0)

	OldJump  = NewCharacter:GetAttribute("CanJump")
	OldSlide = NewCharacter:GetAttribute("CanSlide")

	if Toggles.EnableCharacterJump.Value  then Character:SetAttribute("CanJump",  true) end
	if Toggles.EnableCharacterSlide.Value then Character:SetAttribute("CanSlide", true) end
	if Toggles.JumpBoostToggle.Value then Humanoid.JumpPower = Options.JumpBoostSlider.Value end

	if Functions.CheckCompatability({"require"}) then
		Main_Game = Ostium.Environment.require(Globals.MainUI.Initiator.Main_Game)
	end

	if Main_Game and Toggles.RemoveCameraBobbing.Value then
		Main_Game.spring.Speed = 9e9
	end

	if Main_Game and Functions.CheckCompatability({"require"}) then
		local Controls = require(LocalPlayer.PlayerScripts.PlayerModule):GetControls()
		local OriginalGetMoveVector = Controls.GetMoveVector
		Globals.OriginalGetMoveVector = OriginalGetMoveVector
		Controls.GetMoveVector = function(...)
			if Toggles.AutoSteerMinecart.Value and Floor == "Mines" then
				local Node = Globals.NearestTurnNode
				if Node and Functions.GetMinecart() then
					local Turn = Node:GetAttribute("Turn")
					return Turn == "Left" and Vector3.new(-1, 0, 0) or Turn == "Right" and Vector3.new(1, 0, 0) or Vector3.zero
				end
			end
			return OriginalGetMoveVector(...)
		end
	end

	Globals.AutoMinecartDucked = false
	Globals.LastDuck = tick()
	Connections.AutoSteerMinecartDuckHandler = Services.RunService.Heartbeat:Connect(function()
		if not Toggles.AutoSteerMinecart.Value or not Functions.GetMinecart() or tick() - Globals.LastDuck < 0.1 then return end
		Globals.NearestTurnNode = Functions.GetNearestTurnNode()

		if not Globals.AutoMinecartDucked and Functions.GetNearestDuckBoard() then
			Main_Game.crouch(true)
			Globals.AutoMinecartDucked = true
		elseif not Functions.GetNearestDuckBoard() and Globals.AutoMinecartDucked then
			Main_Game.crouch(false)
			Globals.AutoMinecartDucked = false
		end
		if Main_Game then
			Main_Game.fovtarget = Options.FieldOfView.Value
		else
			Camera.FieldOfView = Options.FieldOfView.Value
		end
		Globals.LastDuck = tick()
	end)

	Globals.AnticheatDisabled = false
	Globals.ArchivesAnticheatNotified = false
	Globals.ArchivesAnticheatBypassState = {}
	Globals.ArchivesAnticheatRecoveryState = {}
	Functions.ApplyHipHeightState()

	local UIModules = Globals.MainUI.Initiator.Main_Game.RemoteListener.Modules
	Modules.A90             = UIModules:FindFirstChild("A90")
	Modules.Screech         = UIModules.Screech
	Modules.Dread           = UIModules:FindFirstChild("Dread")
	Modules.SpiderJumpscare = UIModules.SpiderJumpscare

	if Toggles.RemoveScreech.Value    then Modules.Screech.Name = "Screech_Disabled" end
	if Toggles.RemoveA90.Value and Modules.A90   then Modules.A90.Name = "A90_Disabled" end
	if Toggles.RemoveDread.Value and Modules.Dread then Modules.Dread.Name = "Dread_Disabled" end
	if Toggles.DisableTimothyJumpscare.Value then Modules.SpiderJumpscare.Name = "SpiderJumpscare_Disabled" end

	if Toggles.DisableHideVignette.Value then
		local Vignette = Globals.MainUI:FindFirstChild("HideVignette") or Globals.MainUI.MainFrame:FindFirstChild("HideVignette")
		if Vignette then Vignette.Image = "rbxassetid://0" end
	end
	if Toggles.DisableFiredampEffect.Value then Functions.SetFiredampState(true) end
	if Toggles.DisableHasteJumpscare.Value then Functions.SetHasteJumpscareState(true) end
	if Toggles.RemoveInteractingSounds.Value then
		local PS = Globals.MainUI.Initiator.Main_Game.PromptService
		PS.Triggered.Volume = 0
		PS.Holding.Volume   = 0
		PS.Notification.Volume = 0
		Globals.MainUI.Initiator.Main_Game.Reminder.Caption.Volume = 0
	end
	if Toggles.DisableEntityJumpscares.Value then
		local JS = Globals.MainUI.Initiator.Main_Game.RemoteListener:FindFirstChild("Jumpscares")
		if JS then JS.Name = "Jumpscares_Disabled" end
	end
    local Cutscenes = Globals.MainUI.Initiator.Main_Game.RemoteListener.Cutscenes
    for _, Object in pairs(Cutscenes:GetChildren()) do
        if table.find(CutsceneNames, Object.Name) and Object:IsA("ModuleScript") then
            Object:SetAttribute("OriginalName", Object.Name)
            if Toggles.RemoveCutscenes.Value then
                Object.Name = Object.Name .. "_Disabled"
            end
        end
    end
    for _, Object in pairs(FloorReplicated:GetChildren()) do
        if table.find(CutsceneNames, Object.Name) and Object:IsA("ModuleScript") then
            Object:SetAttribute("OriginalName", Object.Name)
            if Toggles.RemoveCutscenes.Value then
                Object.Name = Object.Name .. "_Disabled"
            end
        end
    end

	CustomPhysics = PhysicalProperties.new(
		100,
		RootPart.CustomPhysicalProperties.Friction,
		RootPart.CustomPhysicalProperties.Elasticity,
		RootPart.CustomPhysicalProperties.FrictionWeight,
		RootPart.CustomPhysicalProperties.ElasticityWeight
	)
	for _, Part in NewCharacter:GetDescendants() do
		if Part:IsA("BasePart") then
			PartProperties[Part] = Part.CustomPhysicalProperties
			if Toggles.RemoveAcceleration.Value then
				Part.CustomPhysicalProperties = CustomPhysics
			end
		end
	end

	Connections.LibraryCodeHandler1 = LocalPlayer.PlayerGui.PermUI.Hints.ChildAdded:Connect(function()
		if Toggles.NotifyLibraryCode.Value then
			local Code = Functions.GetLibraryCode()
			if Code and not Code:find("_") and not Globals.LibraryCodeFound then
				local Lock = Services.Workspace:FindFirstChild("Padlock", true)
				Functions.Notify({ Title = "Padlock code found!", Body = "The code is: '" .. Code .. "'", Time = Toggles.NotifyKeepNotifications.Value and Lock or 15 })
				Globals.LibraryCodeFound = true
			end
		end
	end)

	Connections.LibraryCodeHandler2 = Character.ChildAdded:Connect(function(Child)
		if (Child.Name == "LibraryHintPaper" or Child.Name == "LibraryHintPaperHard") and Toggles.NotifyLibraryCode.Value then
			local Code = Functions.GetLibraryCode()
			if Code and not Code:find("_") and not Globals.LibraryCodeFound then
				local Lock = Services.Workspace:FindFirstChild("Padlock", true)
				Functions.Notify({ Title = "Padlock code found!", Body = "The code is: '" .. Code .. "'", Time = Toggles.NotifyKeepNotifications.Value and Lock or 15 })
				Globals.LibraryCodeFound = true
			end
		end
	end)

	Connections.FootstepHandler = Character.ChildAdded:Connect(function(Object)
		if Object:IsA("Sound") and Object.Name == "Sound" and Toggles.RemoveFootstepSounds.Value then
			Object.Volume = 0
		end
	end)

	Globals.OldOxygen = Character:GetAttribute("Oxygen")
	Connections.OxygenConnection = Character:GetAttributeChangedSignal("Oxygen"):Connect(function()
		local NewOxy = Character:GetAttribute("Oxygen")
		if NewOxy < Globals.OldOxygen and Toggles.NotifyOxygen.Value then
			Functions.Caption(Functions.FormatOxygen(NewOxy), true)
		end
		Globals.OldOxygen = NewOxy
	end)

	Connections.AutoReviveHandler = LocalPlayer:GetAttributeChangedSignal("Alive"):Connect(function()
		if LocalPlayer:GetAttribute("Alive") == false and Toggles.AutoRevive.Value then
			if Floor == "Fools" or Floor == "OldHotel" then
				while LocalPlayer:GetAttribute("Alive") ~= true do
					RemotesFolder.Revive:FireServer()
					task.wait(0.5)
				end
			end
		end
	end)

	Connections.SHMFixer = RootPart:GetPropertyChangedSignal("Anchored"):Connect(function()
		task.wait()
		if Floor == "Fools" and RootPart.Anchored and Character:GetAttribute("Hiding") ~= true then
			RootPart.Anchored = false
		end
	end)

	Connections.AnticheatDisabler = Character:GetAttributeChangedSignal("Climbing"):Connect(function()
		if Character:GetAttribute("Climbing") == true and Toggles.DisableAnticheat.Value and not Globals.AnticheatDisabled then
			task.wait(0.25)
			Character:SetAttribute("Climbing", false)
			Functions.Notify({ Title = "Successfully disabled the anticheat.", Body = "It will be re-enabled after a cutscene or halt room." })
			Globals.AnticheatDisabled = true
		end
	end)

	Connections.ArchivesAnticheatSeatHandler = Character:GetAttributeChangedSignal("SeatedInSeat"):Connect(function()
		if Character:GetAttribute("SeatedInSeat") == true then
			Functions.TryArchivesAnticheatBypass("SeatedInSeat")
		end
	end)
	Connections.ArchivesAnticheatCartHandler = Character:GetAttributeChangedSignal("PushingCart"):Connect(function()
		if Character:GetAttribute("PushingCart") == true then
			Functions.TryArchivesAnticheatBypass("PushingCart")
		end
	end)
	Connections.ArchivesAnticheatRestrictHandler = Character:GetAttributeChangedSignal("RestrictMovement"):Connect(function()
		if Character:GetAttribute("RestrictMovement") ~= true then return end
		local ActiveMode
		for AttributeName in ArchivesAnticheatModes do
			if Character:GetAttribute(AttributeName) == true then
				ActiveMode = AttributeName
				Functions.TryArchivesAnticheatBypass(AttributeName)
				break
			end
		end
		if not ActiveMode then
			Functions.TryRestoreArchivesAnticheatBypass("movement lock")
		end
	end)
	for AttributeName in ArchivesAnticheatModes do
		if Character:GetAttribute(AttributeName) == true then
			task.defer(Functions.TryArchivesAnticheatBypass, AttributeName)
		end
	end

	Connections.LadderSpeedHandler = Character:GetAttributeChangedSignal("Climbing"):Connect(function()
		Functions.SetLadderSpeedOverride(Character:GetAttribute("Climbing") == true)
	end)
	Functions.SetLadderSpeedOverride(Character:GetAttribute("Climbing") == true)

	Connections.AnticheatEnableDetector1 = RemotesFolder:WaitForChild("Cutscene").OnClientEvent:Connect(function(CutsceneName)
		if Globals.AnticheatDisabled and not CutsceneName:find("SewerSeek") then
			Globals.AnticheatDisabled = false
			Functions.Notify({ Title = "The anticheat has been re-enabled.", Body = "Interact with a ladder to disable it again." })
		end
		if Toggles.ArchivesAnticheatBypass and Toggles.ArchivesAnticheatBypass.Value and GameData:FindFirstChild("ArchivesDayPhase") ~= nil then
			task.delay(0.35, function()
				Functions.TryRestoreArchivesAnticheatBypass("cutscene")
			end)
		end
	end)

	Connections.AnticheatEnableDetector2 = RemotesFolder:WaitForChild("UseEnemyModule").OnClientEvent:Connect(function(ModuleName)
		if ModuleName == "Void" or ModuleName == "Glitch" then
			if Globals.AnticheatDisabled then
				Globals.AnticheatDisabled = false
				Functions.Notify({ Title = "The anticheat has been re-enabled.", Body = "Interact with a ladder to disable it again." })
			end
			LocalPlayer:SetAttribute("CurrentRoom", LatestRoom.Value)
		end
	end)

	Connections.AnimationHandler = Character.ChildAdded:Connect(function()
		local ToolNames = { "Lockpick","Shears","SkeletonKey","Key","GeneratorFuse","KeyElectrical","KeyBackdoor","KeyIron", "Multitool" }
		local Tool
		for _, Name in ToolNames do
			Tool = Character:FindFirstChild(Name)
			if Tool then break end
		end
		if not Tool then return end

		local UseAnim = Tool:FindFirstChild("use", true) or Tool:FindFirstChild("promptanim", true)
		if UseAnim then
			UseAnim = Humanoid:LoadAnimation(UseAnim)
			UseAnim.Priority = Enum.AnimationPriority.Action4
			Globals.UseAnimation = UseAnim
		end
		local UseAnimBreak = Tool:FindFirstChild("usefinish", true) or Tool:FindFirstChild("promptanimend", true) or Tool:FindFirstChild("lockpickuse", true)
		if UseAnimBreak then
			UseAnimBreak = Humanoid:LoadAnimation(UseAnimBreak)
			UseAnimBreak.Priority = Enum.AnimationPriority.Action4
			Globals.UseAnimationBreak = UseAnimBreak
		end
	end)

	Connections.JumpHandler = Character:GetAttributeChangedSignal("CanJump"):Connect(function()
		local Val = Character:GetAttribute("CanJump")
		if Toggles.EnableCharacterJump.Value and Val ~= true or not Toggles.EnableCharacterJump.Value then
			OldJump = Val
		end
		if Toggles.EnableCharacterJump.Value then Character:SetAttribute("CanJump", true) end
	end)

	Connections.SlideHandler = Character:GetAttributeChangedSignal("CanSlide"):Connect(function()
		local Val = Character:GetAttribute("CanSlide")
		if Toggles.EnableCharacterSlide.Value and Val ~= true or not Toggles.EnableCharacterSlide.Value then
			OldSlide = Val
		end
		if Toggles.EnableCharacterSlide.Value then Character:SetAttribute("CanSlide", true) end
	end)

	Connections.InfiniteJumpsConnection1 = Services.UserInputService.InputBegan:Connect(function(Input)
		if Input.KeyCode == Enum.KeyCode.Space and Toggles.InfiniteJumps.Value and not Globals.IsTyping then
			Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end)

	local JumpButton = Globals.MainUI.MainFrame.MobileButtons:FindFirstChild("JumpButton")
	if JumpButton then
		Connections.InfiniteJumpsConnection2 = JumpButton.MouseButton1Down:Connect(function()
			if Toggles.InfiniteJumps.Value then
				Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end)
	end

	Globals.SpoofOffset = 0
	Globals.LastAutoHide = tick()
	Connections.AutoHideConnection = Services.RunService.Heartbeat:Connect(function()
		if not Toggles.AutoClosetToggle.Value or tick() - Globals.LastAutoHide <= 0.1 then
			Globals.AutoClosetActive = false
			return
		end
		local Entity = Functions.GetNearestEntity(true, Options.AutoClosetEntityList.Value)
		if Entity then
			local Closet = Functions.GetNearestHidingSpot()
			if Character:GetAttribute("Hiding") ~= true and Closet then
				Globals.AutoClosetActive = true
				Functions.ForceFirePrompt(Closet:FindFirstChild("HidePrompt") or Closet:FindFirstChild("InteractPrompt", true))
			end
			if Character:GetAttribute("Hiding") then
				if Toggles.SpectateEntityToggle.Value and Entity.PrimaryPart then
					Globals.SpectateEntity = Entity
				end
			end
		elseif Character:GetAttribute("Hiding") == true then
			Globals.SpectateEntity = nil
			Globals.AutoClosetActive = false
			RemotesFolder.CamLock:FireServer()
		else
			Globals.SpectateEntity = nil
		end
		Globals.LastAutoHide = tick()
	end)

	Globals.LastAutoAnchor = tick()
	Connections.AutoSolveAnchorsConnection = Services.RunService.Heartbeat:Connect(function()
		if not Toggles.AutoSolveAnchors.Value then return end
		if not Globals.MainUI:FindFirstChild("AnchorHintFrame") then return end
		if tick() - Globals.LastAutoAnchor <= 0.1 then return end
		local Anchor = Functions.GetCurrentAnchor()
		if Anchor and LocalPlayer:DistanceFromCharacter(Anchor.PrimaryPart.Position) < Anchor.ActivateEventPrompt.MaxActivationDistance and not Anchor:GetAttribute("Activated") then
			Anchor:WaitForChild("AnchorRemote"):InvokeServer(Globals.MainUI.AnchorHintFrame.Code.Text)
		end
		Globals.LastAutoAnchor = tick()
	end)

	Globals.ManipulateBody = Instance.new("BodyVelocity")
	Globals.ManipulateBody.MaxForce = Vector3.new(9e9, 9e9, 9e9)

	Globals.FlyBody = Instance.new("BodyVelocity")
	Globals.FlyBody.MaxForce = Vector3.new(9e9, 9e9, 9e9)

	Globals.SelfKilled = false
	Globals.ThirdPersonParts = {}
	for _, Object in Character:GetDescendants() do
		if Object:IsA("Accessory") and Object:FindFirstChild("Handle") then
			table.insert(Globals.ThirdPersonParts, Object.Handle)
		end
	end
	table.insert(Globals.ThirdPersonParts, Character:WaitForChild("Head"))

	Globals.LastAnimationCheck = tick()
	Globals.LastCrouchFire = tick()
	Globals.OriginalC1 = Character.LowerTorso.Root.C1

	local RayParams = RaycastParams.new()
	RayParams.FilterType = Enum.RaycastFilterType.Exclude

	local MainFrame = Globals.MainUI:FindFirstChild("MainFrame")
	if MainFrame and MainFrame:FindFirstChild("SurgeVignette") then
		Globals.SurgeFrame = MainFrame.SurgeVignette
		if Toggles.RemoveSurge.Value then
			Globals.SurgeFrame.Name = "SurgeVignette_Disabled"
		end
	end

	Connections.MainHandler = Services.RunService.RenderStepped:Connect(function()
		if Services.Workspace:FindFirstChild("Camera") then
			Camera = Services.Workspace:FindFirstChild("Camera")
		end

		if Toggles.SpeedBoostToggle.Value then
			Humanoid.WalkSpeed = Functions.GetCurrentSpeed() + Options.SpeedBoostSlider.Value
		end
		if Toggles.JumpBoostToggle.Value then
			Humanoid.JumpPower = Options.JumpBoostSlider.Value
		end

		if Globals.Lagging or (Options.SpeedBoostSlider.Value <= 6 and Options.FlySpeed.Value <= 21) then
			CollisionPartClone.Massless = true
		end

		Globals.IsEyes    = Services.Workspace:FindFirstChild("Eyes") ~= nil or Services.Workspace:FindFirstChild("Lookman") ~= nil
		Globals.IsLookman = Services.Workspace:FindFirstChild("BackdoorLookman") ~= nil

		if Toggles.AmbientToggle.Value then
			Services.TweenService:Create(Services.Lighting, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), { Ambient = Options.AmbientColor.Value }):Play()
		end

		if Main_Game then
			if Toggles.RemoveCameraShake.Value     then Main_Game.csgo = CFrame.new() end
			if Toggles.ViewmodelOffsetToggle.Value then
				Main_Game.tooloffset = Vector3.new(Options.ViewmodelOffsetX.Value, Options.ViewmodelOffsetY.Value, Options.ViewmodelOffsetZ.Value)
			else
				Main_Game.tooloffset = Vector3.zero
			end
		end

		if Globals.SelfKilled and Globals.MainUI:FindFirstChild("Statistics") then
			Globals.MainUI.Statistics.Death.Text = "Died to Ostium"
		end

		local MainFrame = Globals.MainUI:FindFirstChild("MainFrame")
		if MainFrame then
			local Effects = MainFrame.Healthbar:FindFirstChild("Effects")
			if Effects and Effects:FindFirstChild("Crouching") then
				Effects.Crouching.Visible = Functions.IsCrouching()
			end
		end

		if (Toggles.CrouchSpoof.Value or Functions.ShouldUseRootOffsetSpoof()) and RemotesFolder:FindFirstChild("Crouch") then
			RemotesFolder.Crouch:FireServer(true, true)
		end

		if Floor ~= "Fools" and Floor ~= "OldHotel" and not Camera:FindFirstChild("MinecartRig") then
			RootPart.CanCollide = false
		end

		for _, Part in Character:GetChildren() do
			if Part:IsA("BasePart") then Part.CanCollide = false end
		end

		if LocalPlayer:GetAttribute("Alive") == true then
			Services.SoundService:WaitForChild("Main").Volume = 1
		end

		if Floor == "OldHotel" or Floor == "Fools" then
			local SpoofOffset = Toggles.PositionSpoof.Value and Functions.GetNearestEntity() and 200 or Toggles.FigureGodmode.Value and Functions.GetNearestFigure() and 200 or 0
			Globals.SpoofOffset = SpoofOffset
			Collision.Position = RootPart.Position + Vector3.new(0, SpoofOffset, 0)
			Collision.CanCollide = false
			if Floor == "Fools" then
				Collision.CollisionCrouch.CanCollide = false
				CollisionClone.CollisionCrouch.CanCollide = false
			end
			RootPart.CanCollide = not (Toggles.NoclipToggle.Value or Toggles.VelocityManipulationToggle.Value)
		else
			Collision.CanCollide = false
			if Collision:FindFirstChild("CollisionCrouch") then Collision.CollisionCrouch.CanCollide = false end

			if CollisionClone:FindFirstChild("CollisionCrouch") then
				local IsCrouch = Functions.IsCrouching()
				CollisionClone.CanCollide = not (Toggles.NoclipToggle.Value or Toggles.VelocityManipulationToggle.Value or IsCrouch)
				CollisionClone.CollisionCrouch.CanCollide = not (Toggles.NoclipToggle.Value or Toggles.VelocityManipulationToggle.Value or not IsCrouch)
			else
				RootPart.CanCollide = not (Toggles.NoclipToggle.Value or Toggles.VelocityManipulationToggle.Value)
			end

			local UseOffsetSpoof = Functions.ShouldUseRootOffsetSpoof()
			if Character:FindFirstChild("LowerTorso") and Character.LowerTorso:FindFirstChild("Root") then
				Character.LowerTorso.Root.C1 = Globals.OriginalC1 * CFrame.new(0, UseOffsetSpoof and -2.346 or 0, 0)
			end

			local SpoofY = UseOffsetSpoof and 2.328 or 0.18
			Collision.Position     = RootPart.Position + Vector3.new(0, SpoofY, 0)
			CollisionPart.Position = RootPart.Position + Vector3.new(0, SpoofY, 0)

			if Collision:FindFirstChild("CollisionCrouch") and CollisionClone:FindFirstChild("CollisionCrouch") then
				local CrouchY = UseOffsetSpoof and 1.328 or -0.982
				Collision.CollisionCrouch.Position = RootPart.Position + Vector3.new(0, CrouchY, 0)
				CollisionClone.CollisionCrouch.CollisionGroup = Collision.CollisionCrouch.CollisionGroup
			end
			if CollisionClone:FindFirstChild("CollisionCrouch") then
				CollisionClone.CollisionCrouch.Position = RootPart.Position + Vector3.new(0, UseOffsetSpoof and 0.75 or -0.982, 0)
			end
		end

		CollisionClone.CollisionGroup = Collision.CollisionGroup
		CollisionClone.Position = RootPart.Position + Vector3.new(0, Functions.ShouldUseRootOffsetSpoof() and 1.75 or 0.18, 0)

		if Toggles.VelocityManipulationToggle.Value then
			Globals.ManipulateBody.Parent = RootPart
			Globals.ManipulateBody.Velocity = RootPart.CFrame.LookVector * 2.25
		else
			Globals.ManipulateBody.Parent = nil
		end

		if Toggles.FlyToggle.Value then
			Globals.FlyBody.Parent = RootPart
			Globals.FlyBody.Velocity = Functions.GetFlyVelocity() * Options.FlySpeed.Value
		else
			Globals.FlyBody.Parent = nil
		end

		local DoEyesBypass = (IsToggleEnabled("BypassEyes") and Globals.IsEyes) or (IsToggleEnabled("BypassLookman") and Globals.IsLookman)
		if DoEyesBypass then
			if Floor == "Fools" or Floor == "OldHotel" then
				RemotesFolder.MotorReplication:FireServer(0, (Globals.SpoofOffset == 200 and 65 or -65), 0, false)
			else
				RemotesFolder.MotorReplication:FireServer(-650)
			end
		end

		if RemotesFolder:FindFirstChild("Crouch") and tick() - Globals.LastCrouchFire > 0.1 then
			local IsCrouch = Functions.IsCrouching()
			if IsToggleEnabled("CrouchSpoof") or IsToggleEnabled("PositionSpoof") then IsCrouch = true end
			RemotesFolder.Crouch.FireServer(RemotesFolder.Crouch, IsCrouch, true)
			Globals.LastCrouchFire = tick()
		end

		if tick() - Globals.LastAnimationCheck > 0.1 then
			local Sliding = false
			for _, Anim in Humanoid:GetPlayingAnimationTracks() do
				if Anim.Name == "Slide" then Sliding = true break end
			end
			Globals.Sliding = Sliding
			Globals.LastAnimationCheck = tick()
		end

		Character:SetAttribute("Sliding", Globals.Sliding)
		if Character:GetAttribute("Crouching") ~= Functions.IsCrouching() then
			Character:SetAttribute("Crouching", Functions.IsCrouching())
		end

		RayParams.FilterDescendantsInstances = { Character }
		local TPOffset = CFrame.new(Options.ThirdPersonOffsetX.Value, Options.ThirdPersonOffsetY.Value, Options.ThirdPersonOffsetZ.Value)
		local Direction = (Camera.CFrame * TPOffset).Position - Camera.CFrame.Position
		local WallResult = Services.Workspace:Spherecast(Camera.CFrame.Position, 0.2, Direction, RayParams)

		if Toggles.ThirdPersonToggle.Value then
			if Toggles.ThirdPersonWallCheck.Value and WallResult and WallResult.Instance.CanCollide then
				local NewPos = Camera.CFrame.Position + Direction.Unit * WallResult.Distance
				Camera.CFrame = CFrame.new(NewPos, NewPos + Camera.CFrame.LookVector)
			else
				Camera.CFrame = Camera.CFrame * TPOffset
			end
		end

		for _, Part in Globals.ThirdPersonParts do
			Part.Transparency = Toggles.ThirdPersonToggle.Value and 0 or 1
			Part.LocalTransparencyModifier = Toggles.ThirdPersonToggle.Value and 0 or 1
		end

		if Globals.SpectateEntity and Toggles.AutoClosetToggle.Value and Toggles.SpectateEntityToggle.Value then
			local Entity = Globals.SpectateEntity

			local CamPosition
			if Options.SpecateEntityMode.Value == "Player to Entity" then
				CamPosition = CFrame.lookAt(Character.Head.Position, Entity.PrimaryPart.Position)
			else
				CamPosition = CFrame.lookAt(Entity.PrimaryPart.Position, Character.Head.Position)
			end

			Camera.CFrame = CamPosition
		end

		if Main_Game then
			task.wait()
			Main_Game.fovtarget = Options.FieldOfView.Value
		else
			Camera.FieldOfView = Options.FieldOfView.Value
		end

		if Toggles.RemoveClosetDelay.Value
			and Humanoid.MoveDirection ~= Vector3.zero
			and (CollisionPart.Anchored or RootPart.Anchored)
			and Character:GetAttribute("AnimatingClient") ~= true
			and Character:GetAttribute("Hiding") == true
		then
			RemotesFolder.CamLock:FireServer()
		end

		local ClosestPlayer = { Distance = math.huge, Object = nil }
		for _, Player in Services.Players:GetPlayers() do
			if Player.Character and Player ~= LocalPlayer then
				local Root = Player.Character:FindFirstChild("HumanoidRootPart")
				if Root then
					local D = (Camera.CFrame.Position - Root.Position).Magnitude
					if D < ClosestPlayer.Distance then
						ClosestPlayer.Distance = D
						ClosestPlayer.Object = Player
					end
				end
			end
		end
		if ClosestPlayer.Object and LocalPlayer:GetAttribute("Alive") ~= true then
			LocalPlayer:SetAttribute("CurrentRoom", ClosestPlayer.Object:GetAttribute("CurrentRoom"))
		end
	end)

	task.wait(1)
	if Functions.ShouldUseRootOffsetSpoof() then
		Functions.ApplyRootOffsetSpoofState()
	end

	local Jam = Globals.MainUI.Initiator.Main_Game.Health:FindFirstChild("Jam")
	if Jam and Toggles.RemoveJamminMusic.Value then
		Jam.Volume = 0
		Globals.JamMuffle.Enabled = false
	end
end

Functions.HandleHidingTransparency = function(Model)
	local Parts = {}
	for _, Part in Model:GetDescendants() do
		if Part:IsA("BasePart") then
			Part:SetAttribute("Transparency_Old", Part.Transparency)
			table.insert(Parts, Part)
		end
		if Part.Name == "HiddenPlayer" then
			local HideConn = Part:GetPropertyChangedSignal("Value"):Connect(function()
				for _, P in Parts do
					if P:GetAttribute("Transparency_Old") then
						Services.TweenService:Create(P, TweenInfo.new(0.25, Enum.EasingStyle.Linear), {
							Transparency = (Part.Value == Character and Toggles.TransparentHidingSpotsToggle.Value)
								and Options.TransparentHidingSpotsSlider.Value
								or P:GetAttribute("Transparency_Old")
						}):Play()
					end
				end
			end)
			table.insert(Connections, HideConn)
			Model.Destroying:Once(function()
				HideConn:Disconnect()
				local Pos = table.find(Connections, HideConn)
				if Pos then table.remove(Connections, Pos) end
			end)
		end
	end
end

Functions.HandleObject = function(Object)
	for _, Room in CurrentRooms:GetChildren() do
		if Object:IsDescendantOf(Room) then
			Object:SetAttribute("ParentRoom", tonumber(Room.Name))
			break
		end
		task.wait()
	end

	if Object.Parent == CurrentRooms then
		local FiredampVal = Object:GetAttribute("Firedamp")
		Object:SetAttribute("Firedamp_Old", FiredampVal ~= nil and FiredampVal or false)
		if Toggles.DisableFiredampEffect.Value then
			Object:SetAttribute("Firedamp", false)
		end
	end

	local Name = Object.Name

	if Name == "KeyObtain" then
		task.spawn(function()
			task.wait(0.5)
			if Object.Parent then
				if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Door Key", Color = Options.ObjectiveESPColor.Value }, true) end
				table.insert(Objects.Objectives, Object)
			end
		end)
	elseif Name == "ElectricalKeyObtain" then
		task.spawn(function()
			task.wait(0.5)
			if Object.Parent then
				if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Electrical Key", Color = Options.ObjectiveESPColor.Value }, true) end
				table.insert(Objects.Objectives, Object)
			end
		end)
	elseif Name == "TimerLever" then
		task.spawn(function()
			task.wait(0.5)
			if Object.Parent then
				Object:SetAttribute("AddTime", Object.TakeTimer.TextLabel.Text == "01:00" and 60 or 30)
				if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Time Lever [+" .. Object:GetAttribute("AddTime") .. "s]", Color = Options.ObjectiveESPColor.Value }, true) end
				Object:WaitForChild("Main").SoundToPlay.Played:Once(function()
					Functions.RemoveESP(Object)
					Functions.BlacklistESP(Object)
				end)
				table.insert(Objects.Objectives, Object)
			end
		end)
	elseif Name == "LiveHintBook" then
		if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Hint Book", Color = Options.ObjectiveESPColor.Value }, true) end
		table.insert(Objects.Objectives, Object)
	elseif Name == "LiveBreakerPolePickup" then
		if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Fuse Breaker", Color = Options.ObjectiveESPColor.Value }, true) end
		for _, Child in Object:GetChildren() do
			if Child.Name == "ActivateEventPrompt" and (Child.MaxActivationDistance == 5 or Child:GetAttribute("MaxActivationDistance_Old") == 5) then
				Child:Destroy()
			end
		end
		table.insert(Objects.Objectives, Object)
	elseif Name == "LibraryHintPaper" or Name == "PickupItem" then
		if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Hint Paper", Color = Options.ObjectiveESPColor.Value }, true) end
		table.insert(Objects.Objectives, Object)
	elseif Name == "MinesAnchor" then
		if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Anchor [" .. Object:WaitForChild("Sign").TextLabel.Text .. "]", Color = Options.ObjectiveESPColor.Value }, true) end
		Object:GetAttributeChangedSignal("Activated"):Once(function()
			Functions.RemoveESP(Object)
			Functions.BlacklistESP(Object)
		end)
		table.insert(Objects.Objectives, Object)
	elseif Name == "WaterPump" then
		if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object:WaitForChild("Wheel"), Text = "Water Pump", Color = Options.ObjectiveESPColor.Value }, true) end
		Object:WaitForChild("Wheel").Sound.Played:Once(function()
			Object:SetAttribute("Ostium_Completed", true)

			Functions.RemoveESP(Object.Wheel)
			Functions.BlacklistESP(Object.Wheel)
		end)
		table.insert(Objects.Objectives, Object)
	elseif Name == "CringlePresent" then
		if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Present", Color = Options.ObjectiveESPColor.Value }, true) end
		Object:WaitForChild("ToolProp").Highlight:Destroy()
		table.insert(Objects.Objectives, Object)
	elseif Name == "LeverForGate" then
		if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Gate Lever", Color = Options.ObjectiveESPColor.Value }, true) end
		Object:WaitForChild("Main").SoundToPlay.Played:Once(function()
			Functions.RemoveESP(Object)
			Functions.BlacklistESP(Object)
		end)
		table.insert(Objects.Objectives, Object)
	elseif Name == "VineGuillotine" then
		if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object.Lever, Text = "Vine Lever", Color = Options.ObjectiveESPColor.Value }, true) end
		Object.Lever:WaitForChild("ActivateEventPrompt"):GetAttributeChangedSignal("Interactions"):Once(function()
			Functions.RemoveESP(Object)
			Functions.BlacklistESP(Object)
		end)
		table.insert(Objects.Objectives, Object)
	elseif Name == "MandrakeLive" then
		if Toggles.ObjectiveESPToggle.Value and Options.EntityESPOptions.Value["Mandrake Hole"] then Functions.AddESP({ Object = Object.Hole, Text = "Mandrake Hole", Color = Options.EntityESPColor.Value }, true) end
		table.insert(Objects.Entities, Object.Hole)
	elseif Name == "MinesGenerator" then
		task.spawn(function()
			task.wait(0.75)
			if Object.Parent then
				if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Generator", Color = Options.ObjectiveESPColor.Value }, true) end
				Object:WaitForChild("Lever").Sound.Played:Once(function()
					Functions.RemoveESP(Object)
					Functions.BlacklistESP(Object)
				end)
				table.insert(Objects.Objectives, Object)
			end
		end)
	elseif Name == "FuseObtain" then
		if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Generator Fuse", Color = Options.ObjectiveESPColor.Value }, true) end
		Object:WaitForChild("Hitbox").FuseModel:GetPropertyChangedSignal("LocalTransparencyModifier"):Once(function()
			Functions.RemoveESP(Object)
			Functions.BlacklistESP(Object)
		end)
		table.insert(Objects.Objectives, Object)
	elseif Name == "MinesGateButton" then
		if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Gate Button", Color = Options.ObjectiveESPColor.Value }, true) end
		Object.Parent:WaitForChild("MinesGate").Main.SoundOpen.Played:Once(function()
			Functions.RemoveESP(Object)
			Functions.BlacklistESP(Object)
		end)
		table.insert(Objects.Objectives, Object)
	elseif Name == "GardenGateButton" then
		if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Gate Button", Color = Options.ObjectiveESPColor.Value }, true) end
		Object.Parent:WaitForChild("GardenGate").Collision.Sound.Played:Once(function()
			Functions.RemoveESP(Object)
			Functions.BlacklistESP(Object)
		end)
		table.insert(Objects.Objectives, Object)
	elseif Name == "Ladder" then
		if Toggles.LadderESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Ladder", Color = Options.LadderESPColor.Value }, true) end
		table.insert(Objects.Ladders, Object)
	elseif Name == "Door" and Object.Parent and tonumber(Object.Parent.Name) then
		local DoorParts = {}
		for _, Child in Object:GetChildren() do
			if Child.Name == "Door" and Child:IsA("BasePart") then
				table.insert(DoorParts, Child)
			end
		end

		if #DoorParts == 2 then
			local HighlightModel = Instance.new("Model", Object)
			HighlightModel.Name = "HighlightModel"
			Instance.new("Humanoid", HighlightModel).Name = "HighlightHumanoid"
			HighlightModel:SetAttribute("ParentRoom", tonumber(Object.Parent.Name))

			for _, DoorPart in DoorParts do
				local HP = Instance.new("Part", HighlightModel)
				HP.Transparency = 0.999
				HP.Size = DoorPart.Size
				HP.CanCollide = false
				HP.CFrame = DoorPart.CFrame
				HP.Name = "HighlightPart"
				HP.Material = Enum.Material.Plastic
				HP:SetAttribute("ParentRoom", tonumber(Object.Parent.Name))
				local W = Instance.new("WeldConstraint", HP)
				W.Part0 = HP W.Part1 = DoorPart W.Enabled = true
			end
			table.insert(Objects.Doors, HighlightModel)
			if Toggles.DoorESPToggle.Value then Functions.AddESP({ Object = HighlightModel, Text = "Door " .. Functions.GetDoorNumber(Object), Color = Options.DoorESPColor.Value }, true) end
		else
			local Root = Object:WaitForChild("Door", 9e9)
			local HP = Instance.new("Part", Object)
			HP.Transparency = 0.999
			HP.Size = Root.Size
			HP.CanCollide = false
			HP.CFrame = Root.CFrame
			HP.Name = "HighlightPart"
			HP.Material = Enum.Material.Plastic
			HP:SetAttribute("ParentRoom", tonumber(Object.Parent.Name))
			local W = Instance.new("WeldConstraint", HP)
			W.Part0 = HP W.Part1 = Root W.Enabled = true
			Instance.new("Humanoid", Object).Name = "HighlightHumanoid"
			table.insert(Objects.Doors, HP)
			if Toggles.DoorESPToggle.Value then Functions.AddESP({ Object = HP, Text = "Door " .. Functions.GetDoorNumber(Object), Color = Options.DoorESPColor.Value }, true) end
		end

		local LastDoorFire = tick()
		local DoorConn = Services.RunService.Heartbeat:Connect(function()
			if Toggles.DoorNoclip.Value then
				for _, Part in Object:GetChildren() do
					if Part.Name == "Door" and Part:IsA("BasePart") and Part.CanCollide then Part.CanCollide = false end
				end
			end
			if Object:FindFirstChild("Door") and Object:FindFirstChild("ClientOpen") then
				if LocalPlayer:DistanceFromCharacter(Object.Door.Position) < 75
					and tick() - LastDoorFire > 0.1
					and (Toggles.DoorReachToggle.Value or Functions.GetMinecart())
				then
					Object.ClientOpen:FireServer()
					LastDoorFire = tick()
				end
			end
		end)
		Object:WaitForChild("Door"):WaitForChild("Open").Played:Once(function()
			DoorConn:Disconnect()
		end)
		table.insert(Connections, DoorConn)

	elseif Name == "PathLights" then
		local ObjectsToHighlight = {}
		local PLConn = Object.ChildAdded:Connect(function(Child)
			table.insert(ObjectsToHighlight, Child)
		end)
		for _, Child in Object:GetChildren() do
			table.insert(ObjectsToHighlight, Child)
		end

		local function CreateSeekNode(Light)
			if Light.Name ~= "SeekGuidingLight" or Light:GetAttribute("Highlighted") then return end
			Light:SetAttribute("Highlighted", true)

			local NewNode = Instance.new("Part")
			NewNode.Size = Vector3.one
			NewNode.Transparency = 1
			NewNode.Parent = Globals.SeekNodesFolder
			NewNode.Anchored = true
			NewNode.CFrame = Light.CFrame
			NewNode.CanCollide = false
			NewNode.Name = "SeekLightNode"

			local PrevNode2 = PreviousNode or NewNode
			PreviousNode = NewNode

			local Beam = Instance.new("Beam")
			Beam.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Options.ShowSeekPathColor.Value), ColorSequenceKeypoint.new(1, Options.ShowSeekPathColor.Value) })
			Beam.FaceCamera = true
			Beam.Width0 = 0.35
			Beam.Width1 = 0.35
			Beam.Brightness = 6
			Beam.LightInfluence = 0
			Beam.LightEmission = 0
			Beam.Enabled = true
			local Vis = Toggles.ShowSeekPathToggle.Value and 0 or 1
			Beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, Vis), NumberSequenceKeypoint.new(1, Vis) })
			Beam.Parent = Globals.SeekNodesFolder
			local A0 = Instance.new("Attachment", NewNode)
			local A1 = Instance.new("Attachment", PrevNode2)
			Beam.Attachment0 = A0
			Beam.Attachment1 = A1
			table.insert(Objects.SeekHighlights, Beam)
		end

		task.spawn(function()
			while task.wait() do
				local Light = table.remove(ObjectsToHighlight, 1)
				if Light then CreateSeekNode(Light) end
			end
		end)

		table.insert(Connections, PLConn)
		table.insert(Objects.PathLights, Object)
		Object.Destroying:Once(function() PLConn:Disconnect() end)
	elseif Name == "SeekMovingNewClone" then
		local Connection = Object.Destroying:Connect(function()
			for _, Folder in pairs(Objects.PathLights) do
				Folder:ClearAllChildren()
			end
			Globals.SeekNodesFolder:ClearAllChildren()
		end)
		table.insert(Connections, Connection)
	elseif Name == "Bridge" then
		for _, Child in Object:GetChildren() do
			if Child.Name == "PlayerBarrier" and Child.Size.Y == 2.75 and (Child.Rotation.X == 0 or Child.Rotation.X == 180) then
				local NewBridge = Child:Clone()
				NewBridge.CFrame = NewBridge.CFrame * CFrame.new(0, 0, -5)
				NewBridge.Name = Ostium.ESPLibrary:GenerateRandomString()
				NewBridge.Size = Vector3.new(NewBridge.Size.X, NewBridge.Size.Y, 11)
				NewBridge.Parent = Object
				NewBridge.CanCollide = Toggles.BypassSeekObstructions.Value
				NewBridge.Color = Color3.fromRGB(0, 255, 255)
				NewBridge.Transparency = Toggles.BypassSeekObstructions.Value and 0 or 1
				NewBridge.Material = Enum.Material.ForceField
				table.insert(Objects.SeekBridges, NewBridge)
			end
			task.wait()
		end
    elseif Name == "MinecartRig" then
        Globals.Minecart = Object
	elseif Name == "RunnerNodes" then
		local function IsBehind(Part1, Part2)
			local P1 = (Part1.CFrame + Part1.CFrame.LookVector).Position
			local P2 = (Part1.CFrame + Part1.CFrame.LookVector * -1).Position
			return (P1 - Part2.Position).Magnitude > (P2 - Part2.Position).Magnitude
		end
		local function GetDirection(Part1, Part2)
			local RightDist = Part1.CFrame.RightVector:Dot(Part1.Position - Part2.Position)
			if RightDist > 0.5    then return IsBehind(Part1, Part2) and "Right" or "Left" end
			if RightDist < -0.5   then return IsBehind(Part1, Part2) and "Left" or "Right" end
			return "Straight"
		end
		local function GetClosestNode(Node)
			local Best, BestDist = nil, math.huge
			local NodeID2 = tonumber(Node.Name:split("MinecartNode")[2])
			for _, OtherNode in Object:GetChildren() do
				local OtherID = tonumber(OtherNode.Name:split("MinecartNode")[2])
				if OtherNode ~= Node and OtherID and NodeID2 and OtherID > NodeID2 then
					local D = (Node.Position - OtherNode.Position).Magnitude
					if D < BestDist and OtherNode:GetAttribute("DistanceBlacklist") ~= true then
						BestDist = D Best = OtherNode
					end
				end
			end
			return Best
		end

		for _, Node in Object:GetChildren() do
			local NodeID = tonumber(Node.Name:split("MinecartNode")[2])
			if Node:GetAttribute("DeathType") then Node:SetAttribute("DistanceBlacklist", true) end
			for I = 1, 20 do
				local NextNode = NodeID and Object:FindFirstChild("MinecartNode" .. NodeID + I)
				if NextNode and NextNode:GetAttribute("DeathType") ~= nil then
					Node:SetAttribute("DistanceBlacklist", true)
				end
			end
			local PrevNode3 = NodeID and Object:FindFirstChild("MinecartNode" .. NodeID - 1)
			if PrevNode3 and PrevNode3:GetAttribute("ForceConnect") then
				Node:SetAttribute("DistanceBlacklist", nil)
			end
			task.wait()
		end

		for _, Node in Object:GetChildren() do
			if Node:GetAttribute("ForceConnect") then
				local NextNode = GetClosestNode(Node)
				if NextNode then
					Node:SetAttribute("Turn", GetDirection(Node, NextNode))
					table.insert(Objects.SeekNodes, Node)
				end
			end
			task.wait()
		end

	elseif Name == "EyestalkEndCutscene" then
		Object.Name = "_EyestalkEndCutscene"
	elseif Name == "DuckBoard" then
		table.insert(Objects.SeekDuckBoards, Object)
	elseif HidingSpotLabels[Name] then
		if Toggles.HidingSpotESPToggle.Value then Functions.AddESP({ Object = Object, Text = HidingSpotLabels[Name], Color = Options.HidingSpotESPColor.Value }, true) end
		Functions.HandleHidingTransparency(Object)
		table.insert(Objects.HidingSpots, Object)
	elseif string.match(Name, "^HidingSpot%d$") then
		if Toggles.HidingSpotESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Hiding Spot", Color = Options.HidingSpotESPColor.Value }, true) end
		table.insert(Objects.HidingSpots, Object)
	elseif Name == "TellerRig" or Name == "Creak" or Name == "Cobbler" then
		local LabelMap = { TellerRig = "Teller", Creak = "Creak", Cobbler = "Cobbler" }
		local Label = LabelMap[Name]
		if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value[Label] then
			Functions.AddESP({ Object = Object, Text = GetEntityESPText(Object, Label), Color = Options.EntityESPColor.Value }, false)
		end
		table.insert(Objects.Entities, Object)
	elseif Name == "TellerEntity" then
		table.insert(Objects.Entities, Object)
	elseif Name == "Lava" then
		if Toggles.BypassKillbricks.Value then Object.CanTouch = false end
		table.insert(Objects.Obstructions, Object)
	elseif Name == "ScaryWall" then
		for _, Part in Object:GetDescendants() do
			if Part:IsA("BasePart") then
				Part.CanTouch = not Toggles.BypassSeekingWall.Value
				Part.CanCollide = not Toggles.BypassSeekingWall.Value

                local Connection1 = Part:GetPropertyChangedSignal("CanTouch"):Connect(function()
                    if Part.CanTouch == Toggles.BypassSeekingWall.Value then
                        Part.CanTouch = not Toggles.BypassSeekingWall.Value
                    end
                end)
                local Connection2 = Part:GetPropertyChangedSignal("CanCollide"):Connect(function()
                    if Part.CanCollide == Toggles.BypassSeekingWall.Value then
                        Part.CanCollide = not Toggles.BypassSeekingWall.Value
                    end
                end)

                table.insert(Connections, Connection1)
                table.insert(Connections, Connection2)
            end
		end
		table.insert(Objects.Obstructions, Object)
	elseif Name == "ChestBox" or Name == "ChestBoxLocked" then
		if Toggles.ChestESPToggle.Value then Functions.AddESP({ Object = Object, Text = Object:GetAttribute("Locked") and "Locked Chest" or "Chest", Color = Options.ChestESPColor.Value }, true) end
		table.insert(Objects.Chests, Object)
	elseif Name == "Toolbox" or Name == "Toolbox_Locked" then
		if Toggles.ChestESPToggle.Value then Functions.AddESP({ Object = Object, Text = Object:GetAttribute("Locked") and "Locked Toolbox" or "Toolbox", Color = Options.ChestESPColor.Value }, true) end
		table.insert(Objects.Chests, Object)
	elseif Name == "Chest_Vine" then
		if Toggles.ChestESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Vine Chest", Color = Options.ChestESPColor.Value }, true) end
		table.insert(Objects.Chests, Object)
	elseif Name == "Toolshed_Small" then
		if Toggles.ChestESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Toolshed", Color = Options.ChestESPColor.Value }, true) end
		table.insert(Objects.Chests, Object)
	elseif Name == "Locker_Small_Locked" then
		if Toggles.ChestESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Locked Item Locker", Color = Options.ChestESPColor.Value }, true) end
		table.insert(Objects.Chests, Object)
	elseif Name == "MouseHole" then
		if Toggles.ChestESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Mouse", Color = Options.ChestESPColor.Value }, true) end
		table.insert(Objects.Chests, Object)
	elseif SpecialItemESPLabels[Name] then
		if Toggles.ItemESPToggle.Value then Functions.AddESP({ Object = Object, Text = GetItemESPLabel(Object), Color = Options.ItemESPColor.Value }, Object:GetAttribute("ParentRoom") ~= nil) end
		table.insert(Objects.Items, Object)
	elseif ItemNames[Name] and Object:FindFirstChild("ModulePrompt") then
		if Toggles.ItemESPToggle.Value then Functions.AddESP({ Object = Object, Text = GetItemESPLabel(Object), Color = Options.ItemESPColor.Value }, Object:GetAttribute("ParentRoom") ~= nil) end
		if Name == "LotusHolder" or Name == "LotusPetalPickup" then
			Object.Handle:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
				Ostium.ESPLibrary:RemoveESP(Object)
				Functions.BlacklistESP(Object)
			end)
		end

		if Toggles.NotifyItemsToggle.Value and Options.NotifyItemList.Value[ItemNames[Name]] and Object.Parent.Name ~= "Drops" then
			if Toggles.NotifyItemsShowDistance.Value then
				Functions.Notify({ Title = "Item '" .. ItemNames[Name] .. "' has spawned.", Body = "It is '" .. math.round(LocalPlayer:DistanceFromCharacter(Object.PrimaryPart.Position)) .. "' studs away from you." })
			else
				Functions.Notify({ Title = "Item '" .. ItemNames[Name] .. "' has spawned."})
			end
		end

		table.insert(Objects.Items, Object)
	elseif Name == "Green_Herb" then
		if Toggles.ItemESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Green Herb", Color = Options.ItemESPColor.Value }, true) end
		table.insert(Objects.Items, Object)
	elseif Name == "GoldPile" and Object:GetAttribute("GoldValue") then
		if Toggles.CurrencyESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Gold Pile [" .. Object:GetAttribute("GoldValue") .. "]", Color = Options.CurrencyESPColor.Value }, true) end
		table.insert(Objects.Currency, Object)
	elseif Name == "StardustPickup" then
		if Toggles.CurrencyESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Stardust Pile", Color = Options.CurrencyESPColor.Value }, true) end
		table.insert(Objects.Currency, Object)
	elseif Name == "GiggleCeiling" then
		if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Giggle"] then Functions.AddESP({ Object = Object, Text = "Giggle", Color = Options.EntityESPColor.Value }, true) end
		if Toggles.BypassGiggle.Value then Object:WaitForChild("Hitbox").CanTouch = false end
		table.insert(Objects.Entities, Object)
	elseif Name == "GloomPile" then
		if Toggles.BypassGloombatEggs.Value then
			for _, Part in Object:GetDescendants() do
				if Part:IsA("BasePart") then Part.CanTouch = false
				end
			end
		end
		local Connection = Object.DescendantAdded:Connect(function(Part)
			if Part:IsA("BasePart") then Part.CanTouch = false end
		end)

		if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Gloombat Eggs"] then
			Functions.AddESP({ Object = Object, Text = "Gloombat Eggs", Color = Options.EntityESPColor.Value })
		end

		table.insert(Connections, Connection)
		table.insert(Objects.Entities, Object)
	elseif Name == "TriggerEventCollision" and Functions.CheckCompatability({"firetouchinterest"}) then
		if (Floor == "Fools" or Floor == "OldHotel") and Toggles.RemoveSeekTrigger.Value then
			task.spawn(function()
				while Object:IsDescendantOf(game) do
					for _, Part in Object:GetChildren() do
						if Part:IsA("BasePart") then
							Ostium.Environment.firetouchinterest(RootPart, Part, 0)
							task.wait()
							Ostium.Environment.firetouchinterest(RootPart, Part, 1)
						end
					end
					task.wait()
				end
			end)
		end
		table.insert(Objects.EventTriggers, Object)
	elseif Name == "DoorFake" or Name == "FakeDoor" then
		if Object.Parent and Object:FindFirstChild("Hidden") then
			if Toggles.BypassDupe.Value then
				Object:WaitForChild("Hidden").CanTouch = false
				local Lock = Object:FindFirstChild("Lock")
				if Lock and Lock:FindFirstChild("UnlockPrompt") then Lock.UnlockPrompt.Enabled = false end
			end
			if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Dupe"] then
				Functions.AddESP({ Object = Object, Text = "Dupe", Color = Options.EntityESPColor.Value }, true)
			end
			table.insert(Objects.Entities, Object)
		end
	elseif Name == "SideroomSpace" then
		if Toggles.BypassVacuum.Value then
			Object:WaitForChild("Collision").CanCollide = true
			Object:WaitForChild("Collision").CanTouch = false
		end
		table.insert(Objects.Entities, Object)
	elseif Name == "Snare" then
		if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Snare"] then Functions.AddESP({ Object = Object, Text = "Snare", Color = Options.EntityESPColor.Value }, true) end
		for _, Part in Object:GetDescendants() do
			if Part:IsA("BasePart") then Part.CanTouch = not Toggles.BypassSnare.Value end
		end
		local Connection = Object.DescendantAdded:Connect(function(Part)
			if Part:IsA("BasePart") then Part.CanTouch = not Toggles.BypassSnare.Value end
		end)
		table.insert(Connections, Connection)
		table.insert(Objects.Entities, Object)

		if Object:FindFirstChild("Snare") then
			Object:WaitForChild("Snare"):WaitForChild("Roots").Transparency = 1
			Object:WaitForChild("Snare"):WaitForChild("SnareBase").Transparency = 1
		end
		if Object:FindFirstChild("Void") then
			Object.Void.Transparency = 0
			Object.Void.Color = Color3.fromRGB(76, 67, 55)
		end
	elseif Name == "Seek_Arm" or Name == "ChandelierObstruction" then
		for _, Part in Object:GetDescendants() do
			if Part:IsA("BasePart") then
				Part.CanTouch = not Toggles.BypassSeekObstructions.Value
				table.insert(Objects.SeekObstructions, Part)
			end
		end
	elseif Name == "SeekFloodline" then
		Object.CanCollide = Toggles.BypassSeekObstructions.Value
		local FloodConn = Object:GetPropertyChangedSignal("CanCollide"):Connect(function()
			if Object.CanCollide ~= Toggles.BypassSeekObstructions.Value then
				Object.CanCollide = Toggles.BypassSeekObstructions.Value
			end
		end)
		Object.Destroying:Once(function() FloodConn:Disconnect() end)
		table.insert(Objects.SeekObstructions, Object)
	elseif Object:GetAttribute("RawName") and Object:GetAttribute("RawName"):find("Halt") or Object:GetAttribute("Shade") == true then
		if Toggles.NotifyEntities.Value and Options.EntityList.Value["Halt"] then
			Functions.Notify({ Title = "Entity 'Halt' will spawn in the next room.", Image = EntityIcons["Halt"] })
			if Toggles.EntityChatToggle.Value then Functions.SendChat("Halt next room!") end
		end
		local HaltLogConn
		HaltLogConn = Services.LogService.MessageOut:Connect(function(Message)
			if Message == "client teleporting" then
				if Globals.AnticheatDisabled then
					Globals.AnticheatDisabled = false
					Functions.Notify({ Title = "The anticheat has been re-enabled.", Body = "Interact with a ladder to disable it again." })
				end
				HaltLogConn:Disconnect()
			end
		end)
	elseif Name == "BananaPeel" then
		if Toggles.BypassBanana.Value then Object.CanTouch = false end
		table.insert(Objects.Entities, Object)
	elseif Name == "JeffTheKiller" then
		Functions.ApplyJeffBypass(Object, Toggles.BypassJeff.Value)
		if not table.find(Objects.Jeffs, Object) then table.insert(Objects.Jeffs, Object) end
		if not table.find(Objects.Entities, Object) then table.insert(Objects.Entities, Object) end
	elseif Name == "GrumbleRig" then
		if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Grumble"] then Functions.AddESP({ Object = Object, Text = "Grumble", Color = Options.EntityESPColor.Value }, true) end
		table.insert(Objects.Entities, Object)
	elseif Name == "LiveEntityBramble" then
		if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Bramble"] then Functions.AddESP({ Object = Object, Text = "Bramble", Color = Options.EntityESPColor.Value }, true) end
		table.insert(Objects.Entities, Object)
	elseif Name == "Groundskeeper" then
		if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Groundskeeper"] then Functions.AddESP({ Object = Object, Text = "Groundskeeper", Color = Options.EntityESPColor.Value }, true) end
		if Toggles.NotifyEntities.Value and Options.EntityList.Value["Groundskeeper"] then
			local ED = Entities["Groundskeeper"]
			Functions.Notify({ Title = ED.NotifyMessage.Title, Body = ED.NotifyMessage.Body, Image = EntityIcons["Groundskeeper"] })
		end
		table.insert(Objects.Entities, Object)
	elseif Name == "Figure" or Name == "FigureRig" or Name == "FigureRagdoll" then
		for _, Part in Object:GetDescendants() do
			if Part:IsA("BasePart") then
				Part.CanTouch = false
			end
		end
		if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Figure"] then Functions.AddESP({ Object = Object, Text = "Figure", Color = Options.EntityESPColor.Value }, true) end
		table.insert(Objects.Entities, Object)
		if Toggles.RemoveFigure.Value and Functions.CheckCompatability({"isnetworkowner"}) then
			if Floor == "Mines" then
				for _, Part in Object:GetDescendants() do
					if Part:IsA("BasePart") then
						task.spawn(function()
							if Ostium.Environment.isnetworkowner(Part) then
								Part.Position = Vector3.new(-49999, -49999, -49999)
							end
						end)
					end
				end
			elseif Floor == "OldHotel" or Floor == "Fools" then
				CurrentRooms.ChildAdded:Wait()
				for _, Part in Object:GetDescendants() do
					if Part:IsA("BasePart") then
						Part.CanCollide = false
						task.spawn(function()
							while Ostium.Environment.isnetworkowner(Part) do
								Part.Position = Vector3.new(math.random(-29999,29999), math.random(-29999,29999), math.random(-29999,29999))
								task.wait()
							end
						end)
					end
				end
			end
		end
	elseif (Name == "ThingToOpen" or Name == "MovingDoor") and (Floor == "Fools" or Floor == "OldHotel")
		or Name == "Wax_Door" and Floor == "Fools"
	then
		Object:SetAttribute("OriginalPosition", Object:GetPivot())
		local ToggleMap = { ThingToOpen = "RemoveBasementGate", MovingDoor = "RemovePaintingsDoor", Wax_Door = "RemoveSkeletonDoor" }
		if ToggleMap[Name] and Toggles[ToggleMap[Name]].Value then
			Object:PivotTo(CFrame.new(-10000, -10000, -10000))
		end
		table.insert(Objects.Obstructions, Object)
	elseif Name == "ElevatorBreaker" then
		if Toggles.AutoBreakerBox.Value and not Globals.BreakerBoxNotified then
			Functions.Notify({ Title = "Interact with the breaker box.", Body = "It will be automatically solved." })
			Globals.BreakerBoxNotified = true
		end
		Connections.BreakerConnection = Object:WaitForChild("SurfaceGui").Frame.Code:GetPropertyChangedSignal("Text"):Connect(function()
			if Toggles.AutoBreakerBox.Value then
				if not Globals.BreakerBoxStartNotified and (Floor == "Fools" or Floor == "OldHotel") then
					Functions.Notify({ Title = "Attempting to solve the breaker box.", Body = "Please wait." })
					Globals.BreakerBoxStartNotified = true
				end
				RemotesFolder.EBF:FireServer()
			end
			Globals.BreakerBoxInteracted = true
		end)
	elseif Name == "ElevatorCar" then
		local ElevConn = Object.DescendantAdded:Connect(function(Desc)
			if Toggles.AutoBreakerBox.Value and Desc.Name == "TouchInterest" and not Globals.BreakerBoxFinishedNotified then
				Functions.Notify({ Title = "Successfully solved the breaker box.", Body = "Try going to the elevator!" })
				Globals.BreakerBoxFinishedNotified = true
			end
		end)
		Object.Destroying:Once(function() ElevConn:Disconnect() end)
	elseif Object.ClassName == "ProximityPrompt" and not Object:GetAttribute("FakePrompt") then
		local PreserveRealLockPrompt = Functions.ShouldPreserveRealLockPrompt(Object)
		if not PreserveRealLockPrompt and Functions.ShouldModifyPrompt(Object) and Object:HasTag("DisableWhenEnabledOnClient") then
			Object:RemoveTag("DisableWhenEnabledOnClient")
		end

		Object:SetAttribute("HoldDuration_Old", Object.HoldDuration)
		Object:SetAttribute("RequiresLineOfSight_Old", Object.RequiresLineOfSight)
		Object:SetAttribute("MaxActivationDistance_Old", Object.MaxActivationDistance)

		if not PreserveRealLockPrompt and Functions.ShouldModifyPrompt(Object) then
			if Toggles.InstantPrompts.Value    then Object.HoldDuration = 0 end
			if Toggles.PromptClip.Value        then Object.RequiresLineOfSight = false end
			Object.MaxActivationDistance = Object:GetAttribute("MaxActivationDistance_Old") * Options.PromptReachSlider.Value
		end

		if Functions.ShouldUseFakePrompts() and Functions.IsLockPrompt(Object) then
			local ExistingFakePrompt
			for Prompt, RealPrompt in FakePrompts do
				if RealPrompt == Object then
					ExistingFakePrompt = Prompt
					break
				end
			end

			if not ExistingFakePrompt then
				local FakePrompt = Object:Clone()
				FakePrompt:SetAttribute("FakePrompt", true)
				task.wait()
				FakePrompt.Parent = Object.Parent

				FakePrompt:SetAttribute("HoldDuration_Old", Object:GetAttribute("HoldDuration_Old"))
				FakePrompt:SetAttribute("RequiresLineOfSight_Old", Object:GetAttribute("RequiresLineOfSight_Old"))
				FakePrompt:SetAttribute("MaxActivationDistance_Old", Object:GetAttribute("MaxActivationDistance_Old"))

				FakePrompt.HoldDuration = Object.HoldDuration
				FakePrompt.RequiresLineOfSight = Object.RequiresLineOfSight
				FakePrompt.MaxActivationDistance = Object.MaxActivationDistance

				if Toggles.InstantPrompts.Value    then FakePrompt.HoldDuration = 0 end
				if Toggles.PromptClip.Value        then FakePrompt.RequiresLineOfSight = false end
				FakePrompt.MaxActivationDistance = FakePrompt:GetAttribute("MaxActivationDistance_Old") * Options.PromptReachSlider.Value

				FakePrompts[FakePrompt] = Object
				pcall(function() Object.Parent = Globals.PromptContainer end)

				local FPEnabledConn = Object:GetPropertyChangedSignal("Enabled"):Connect(function()
					FakePrompt.Enabled = Object.Enabled
				end)
				Object:GetPropertyChangedSignal("ActionText"):Once(function()
					Functions.RestoreFakePrompt(FakePrompt)
					FPEnabledConn:Disconnect()
				end)
				Object.Destroying:Once(function()
					FakePrompts[FakePrompt] = nil
					FakePrompt:Destroy()
					FPEnabledConn:Disconnect()
				end)
				table.insert(Connections, FPEnabledConn)
				table.insert(Objects.Prompts, FakePrompt)

				FakePrompt.Enabled = false
				task.wait()
				FakePrompt.Enabled = Object.Enabled
			end
		end
		table.insert(Objects.Prompts, Object)
	elseif Name == "Padlock" then
		local LastLibraryGuess = 0
		Connections.PadlockConnection = Services.RunService.Heartbeat:Connect(function()
			if Object.PrimaryPart then
				local Distance = LocalPlayer:DistanceFromCharacter(Object.PrimaryPart.Position)
				if Toggles.AutoUnlockPadlockToggle.Value then
					local Code = Functions.GetLibraryCode()
					if Code and tonumber(Code) and Distance < Options.AutoUnlockPadlockSlider.Value then
						RemotesFolder.PL:FireServer(Code)
					end
				end
				local GuessInterval = 1 / Options.LibraryGuessesPerSecond.Value
				if Toggles.AutoLibraryGuessCode.Value and LatestRoom.Value == 50 and tick() - LastLibraryGuess >= GuessInterval then
					local Code = Functions.GetRandomCode()
					if Code then RemotesFolder.PL:FireServer(Code) end
					LastLibraryGuess = tick()
				end
			end
		end)
		Object.Destroying:Once(function()
			if Connections.PadlockConnection then
				Connections.PadlockConnection:Disconnect()
				Connections.PadlockConnection = nil
			end
		end)
	end
end

Connections.PromptAnimationFixer1 = Services.ProximityPromptService.PromptButtonHoldBegan:Connect(function(Object)
	if not Object:GetAttribute("FakePrompt") then return end
	local ToolNames = { "Lockpick","Shears","SkeletonKey","Key","GeneratorFuse","KeyElectrical","KeyBackdoor","KeyIron", "Multitool" }
	local AnimateToolNames = { "Lockpick","Shears","SkeletonKey","Key","KeyElectrical","KeyBackdoor","KeyIron", "Multitool" }
	local Tool
	for _, N in ToolNames do Tool = Character:FindFirstChild(N) if Tool then break end end

	local Prompt = Object
	local IsLockPrompt = Functions.IsLockPrompt(Prompt)
	if IsLockPrompt then
		if Options.AutoInteractIgnoreList.Value["Locks"] then return end
		local KeyItems = { "Key","GeneratorFuse","KeyBackdoor","KeyElectrical","KeyIron","Lockpick","SkeletonKey","Shears","Multitool" }
		local OffhandKeyItems = { "Key","GeneratorFuse","KeyElectrical","KeyIron" }
		local HasKey = false
		for _, K in KeyItems do if Functions.HasItem(K, true) then HasKey = true break end end
		for _, K in OffhandKeyItems do if Functions.HasItem(K) then HasKey = true break end end
		if not HasKey then return end
	end

	if Prompt.Parent.Name == "CuttableVines" and not Functions.HasItem("Shears", true) and not Functions.HasItem("Multitool", true) or Prompt.Parent.Name == "Chest_Vine" and not Functions.HasItem("Shears", true) and not Functions.HasItem("Multitool", true) or Prompt.Parent.Name == "Cellar" and not Functions.HasItem("Shears", true) and not Functions.HasItem("Multitool", true) then return end
	if Prompt.Parent.Name == "SkullLock" and not Functions.HasItem("SkeletonKey", true) then return end
	if Prompt.Parent.Name == "Lock1" and not Functions.HasItem("Lockpick", true) and not Functions.HasItem("Multitool", true) or Prompt.Parent.Name == "Lock2" and not Functions.HasItem("Lockpick", true) and not Functions.HasItem("Multitool", true) then return end
	if Functions.HasItem("Shears", true) and IsLockPrompt and Prompt.Parent.Name ~= "CuttableVines" and Prompt.Parent.Name ~= "Chest_Vine" and Prompt.Parent.Name ~= "Cellar" then return end
	
	if Tool and table.find(AnimateToolNames, Tool.Name) and Globals.UseAnimation then
		Globals.UseAnimationBreak:Stop()
		Globals.UseAnimation:Stop()
		Globals.UseAnimation:Play()
		if Tool.Name == "Shears" then Tool:WaitForChild("Handle"):WaitForChild("sound_prompt"):Play() end
	end
end)

local AllowedInstances = {
	Lava=true, GoldPile=true, KeyObtain=true, Drakobloxxer=true, FuseObtain=true,
	MinesGenerator=true, JeffTheKiller=true, Snare=true, FakeDoor=true, DoorFake=true, SideroomSpace=true,
	ChestBox=true, ChestBoxLocked=true, Chest_Vine=true, Locker_Small_Locked=true, Toolbox=true,
	Toolbox_Locked=true, Wardrobe=true, ["Wardrobe-FOOLS26"]=true, Toolshed=true, Toolshed_Small=true,
	Bed=true, MinesAnchor=true, Double_Bed=true, RetroWardrobe=true, Backdoor_Wardrobe=true,
	Rooms_Locker=true, Rooms_Locker_Fridge=true, Locker_Large=true, FigureRig=true, FigureRagdoll=true,
	TimerLever=true, Lever=true, Seek_Arm=true, ChandelierObstruction=true, ScaryWall=true, Ladder=true,
	CircularVent=true, Dumpster=true, SquareGrate=true, TriggerEventCollision=true, GrumbleRig=true,
	GiggleCeiling=true, MinesGateButton=true, ElectricalKeyObtain=true, LibraryHintPaper=true,
	WaterPump=true, CringlePresent=true, Wheel=true, PickupItem=true, LiveHintBook=true,
	LiveBreakerPolePickup=true, LeverForGate=true, GloomPile=true, SeekFloodline=true, Door=true,
	Green_Herb=true, Bridge=true, MouseHole=true, BananaPeel=true, NannerPeel=true, PowerupPad=true,
	IndustrialGate=true, CollisionFloor=true, ElevatorCar=true, Wax_Door=true, ThingToOpen=true,
	MovingDoor=true, StardustPickup=true, Hole=true, Groundskeeper=true, MandrakeLive=true,
	GardenGateButton=true, LotusPetalPickup=true, VineGuillotine=true, LiveEntityBramble=true,
	RiftSpawn=true, ElevatorBreaker=true, RunnerNodes=true, PathLights=true, DuckBoard=true,
	Padlock=true, EyestalkEndCutscene=true, MinecartRig=true, SeekMovingNewClone=true,
	HidingSpot1=true, HidingSpot2=true, HidingSpot3=true, HidingSpot4=true, HidingSpot5=true,
	HidingSpot6=true, HidingSpot7=true, HidingSpot8=true, HidingSpot9=true,
	TellerEntity=true, TellerRig=true, Creak=true, Cobbler=true,
	BrokenMonitor=true, DinkyLamp=true, GweenSodaPack=true, TV_Stand=true
}

Connections.GeneratedObjectObserver = Ostium.ESPLibrary:ObserveGenerated(Services.Workspace, {
	MaxPerStep = 1,
	Match = function(Object)
		return AllowedInstances[Object.Name]
			or Object.ClassName == "ProximityPrompt"
			or Object.Parent == CurrentRooms
			or ItemNames[Object.Name] ~= nil
	end,
	OnAdded = function(Object)
		Functions.HandleObject(Object)
	end,
})

for _, Player in Services.Players:GetPlayers() do
	if Player ~= LocalPlayer then
		if Player.Character and Toggles.PlayerESPToggle.Value then
			Functions.AddESP({ Object = Player.Character, Text = Player.Name, Color = Options.PlayerESPColor.Value })
		end
		local CharConn = Player.CharacterAdded:Connect(function(NewCharacter)
			if Toggles.PlayerESPToggle.Value then
				Functions.AddESP({ Object = NewCharacter, Text = Player.Name, Color = Options.PlayerESPColor.Value })
			end
		end)
		local DeadConn = Player:GetAttributeChangedSignal("Alive"):Connect(function()
			if Player:GetAttribute("Alive") ~= true and Player.Character then
				Functions.RemoveESP(Player.Character)
			end
		end)
		table.insert(Connections, CharConn)
		table.insert(Connections, DeadConn)
		Player.Destroying:Once(function()
			CharConn:Disconnect()
			DeadConn:Disconnect()
		end)
	end
end

Connections.PlayerHandler = Services.Players.PlayerAdded:Connect(function(Player)
	if Player == LocalPlayer then return end
	if Player.Character and Toggles.PlayerESPToggle.Value then
		Functions.AddESP({ Object = Player.Character, Text = Player.Name, Color = Options.PlayerESPColor.Value })
	end
	local CharConn = Player.CharacterAdded:Connect(function(NewCharacter)
		if Toggles.PlayerESPToggle.Value then
			Functions.AddESP({ Object = NewCharacter, Text = Player.Name, Color = Options.PlayerESPColor.Value })
		end
	end)
	local DeadConn = Player:GetAttributeChangedSignal("Alive"):Connect(function()
		if Player:GetAttribute("Alive") ~= true and Player.Character then
			Functions.RemoveESP(Player.Character)
		end
	end)
	table.insert(Connections, CharConn)
	table.insert(Connections, DeadConn)
	Player.Destroying:Once(function()
		CharConn:Disconnect()
		DeadConn:Disconnect()
	end)
end)

local PromptsToFire = {}
local PromptCooldown = {}
local LockPromptNames = {
	UnlockPrompt = true,
	SkullPrompt = true,
	LockPrompt = true,
	ThingToEnable = true,
	FusesPrompt = true,
}

Functions.FirePrompt      = Ostium.Environment.fireproximityprompt
Functions.ForceFirePrompt = Ostium.Environment.fireproximityprompt

if not Functions.FirePrompt then
	Functions.FirePrompt = function(Prompt)
		if not Prompt:IsA("ProximityPrompt") or PromptCooldown[Prompt] or table.find(PromptsToFire, Prompt) or not Camera then return end
		table.insert(PromptsToFire, Prompt)
	end
	Functions.ForceFirePrompt = Functions.FirePrompt

	task.spawn(function()
		while task.wait() do
			local Prompt = table.remove(PromptsToFire, 1)
			if not Prompt then continue end
			PromptCooldown[Prompt] = true

			local OldDist   = Prompt.MaxActivationDistance
			local OldEnable = Prompt.Enabled
			local OldParent = Prompt.Parent
			local OldHold   = Prompt.HoldDuration
			local OldLOS    = Prompt.RequiresLineOfSight

			Prompt.MaxActivationDistance = 99999
			Prompt.Enabled = true
			Prompt.HoldDuration = 0
			Prompt.RequiresLineOfSight = false

			local TempPart = Instance.new("Part")
			TempPart.Parent = Services.Workspace
			TempPart.CanCollide = false TempPart.CanQuery = false TempPart.CanTouch = false
			TempPart.Anchored = true TempPart.Transparency = 1
			TempPart.Size = Vector3.new(0.001, 0.001, 0.001)
			TempPart.Position = Camera.CFrame:ToWorldSpace(CFrame.new(0, 0, -0.1)).Position

			if not Prompt or not OldParent then
				TempPart:Destroy()
				PromptCooldown[Prompt] = nil
				continue
			end

			pcall(function() Prompt.Parent = TempPart end)

			local Shown, Fired = false, false

			local ShownConn = Services.ProximityPromptService.PromptShown:Connect(function(P)
				if P == Prompt then Shown = true end
			end)
			local FiredConn = Prompt.Triggered:Connect(function() Fired = true end)

			local T1 = 0
			while not Shown and T1 < 5 do T1 += 1 task.wait() end

			local T2 = 0
			while not Fired and T2 < 5 do
				Prompt:InputHoldBegin()
				Prompt:InputHoldEnd()
				T2 += 1 task.wait()
			end

			Prompt.MaxActivationDistance = OldDist
			Prompt.Enabled = OldEnable
			Prompt.HoldDuration = OldHold
			Prompt.RequiresLineOfSight = OldLOS
			pcall(function() Prompt.Parent = OldParent end)
			task.wait()
			PromptCooldown[Prompt] = nil
			TempPart:Destroy()
			ShownConn:Disconnect()
			FiredConn:Disconnect()
		end
	end)
end

local AutoInteractBlacklist = {
	HidePrompt=true, RiftPrompt=true, StarRiftPrompt=true, InteractPrompt=true, ClimbPrompt=true,
	DonatePrompt=true, DialoguePrompt=true, RevivePrompt=true, EnterPrompt=true, AnimatePrompt=true,
	ToolEventPrompt=true, Prompt=true, PropPrompt=true
}

local function PromptHasAncestorName(Prompt, NameMap)
	local Current = Prompt and Prompt.Parent
	while Current do
		if NameMap[Current.Name] then
			return true
		end
		Current = Current.Parent
	end
	return false
end

Functions.IsLockPrompt = function(Prompt)
	if not Prompt then return false end

	return LockPromptNames[Prompt.Name]
		or (Prompt.Parent and Prompt.Parent:GetAttribute("Locked") == true)
		or (Prompt.Parent and Prompt.Parent.Parent and Prompt.Parent.Parent.Name == "Locker_Small_Locked" and Prompt.Name == "ActivateEventPrompt")
end

Functions.IsNativeLockPrompt = function(Prompt)
	if not Prompt then return false end

	return LockPromptNames[Prompt.Name]
		or (Prompt.Parent and Prompt.Parent.Parent and Prompt.Parent.Parent.Name == "Locker_Small_Locked" and Prompt.Name == "ActivateEventPrompt")
end

Functions.ShouldUseFakePrompts = function()
	return false
end

Functions.ShouldPreserveRealLockPrompt = function(Prompt)
	return Functions.IsNativeLockPrompt(Prompt) and not Functions.ShouldUseFakePrompts()
end

Functions.ShouldModifyPrompt = function(Prompt)
	if not Prompt then return false end

	return Prompt:GetAttribute("FakePrompt")
		or Toggles.InstantPrompts.Value
		or Toggles.PromptClip.Value
		or Options.PromptReachSlider.Value ~= 1
end

Functions.RestoreFakePrompt = function(FakePrompt)
	local RealPrompt = FakePrompts[FakePrompt]
	if not RealPrompt then return end

	FakePrompts[FakePrompt] = nil
	if RealPrompt.Parent == Globals.PromptContainer and FakePrompt.Parent then
		RealPrompt.Parent = FakePrompt.Parent
	end
	if FakePrompt.Parent then
		FakePrompt:Destroy()
	end
end

Functions.SyncFakePrompts = function()
	if not Functions.CheckCompatability({"fireproximityprompt"}) then return end

	if not Functions.ShouldUseFakePrompts() then
		for Prompt in FakePrompts do
			Functions.RestoreFakePrompt(Prompt)
		end
		return
	end

	for _, Prompt in Objects.Prompts do
		if Prompt
			and Prompt.Parent
			and Prompt:IsA("ProximityPrompt")
			and not Prompt:GetAttribute("FakePrompt")
			and Functions.IsLockPrompt(Prompt)
		then
			Functions.HandleObject(Prompt)
		end
	end
end

local TriggerDebounce = false

Functions.TriggerPrompt = function(Prompt)
	if AutoInteractBlacklist[Prompt.Name] then return end
	if not Prompt or not Prompt.Parent then return end
	if TriggerDebounce then return end

	local ParentItem = Functions.HasItem(Prompt.Parent.Name)
	if ParentItem and ParentItem:GetAttribute("Durability") and ParentItem:GetAttribute("DurabilityMax")
		and ParentItem:GetAttribute("Durability") >= ParentItem:GetAttribute("DurabilityMax")
	then return end

	local IsLockPrompt = Functions.IsLockPrompt(Prompt)

	if IsLockPrompt then
		if Options.AutoInteractIgnoreList.Value["Locks"] then return end
		local KeyItems = { "Key","GeneratorFuse","KeyBackdoor","KeyElectrical","KeyIron","Lockpick","SkeletonKey","Shears","Multitool" }
		local OffhandKeyItems = { "Key","GeneratorFuse","KeyElectrical","KeyIron" }
		local HasKey = false
		for _, K in KeyItems do if Functions.HasItem(K, true) then HasKey = true break end end
		for _, K in OffhandKeyItems do if Functions.HasItem(K) then HasKey = true break end end
		if not HasKey then return end
	end

	if Prompt.Parent.Name == "CuttableVines" and not Functions.HasItem("Shears", true) and not Functions.HasItem("Multitool", true) or Prompt.Parent.Name == "Chest_Vine" and not Functions.HasItem("Shears", true) and not Functions.HasItem("Multitool", true) or Prompt.Parent.Name == "Cellar" and not Functions.HasItem("Shears", true) and not Functions.HasItem("Multitool", true) then return end
	if Prompt.Parent.Name == "SkullLock" and not Functions.HasItem("SkeletonKey", true) then return end
	if Prompt.Parent.Name == "Lock1" and not Functions.HasItem("Lockpick", true) and not Functions.HasItem("Multitool", true) or Prompt.Parent.Name == "Lock2" and not Functions.HasItem("Lockpick", true) and not Functions.HasItem("Multitool", true) then return end
	if Functions.HasItem("Shears", true) and IsLockPrompt and Prompt.Parent.Name ~= "CuttableVines" and Prompt.Parent.Name ~= "Chest_Vine" and Prompt.Parent.Name ~= "Cellar" then return end

	if Prompt.Parent.Name == "GlitchCube" and Options.AutoInteractIgnoreList.Value["Glitch Fragments"] then return end

	if (Prompt.Parent.Name == "KeyObtain" and (Functions.HasItem("Key") or Functions.HasItem("KeyBackdoor")))
		or (Prompt.Parent.Name == "ElectricalKeyObtain" and Functions.HasItem("KeyElectrical"))
	then return end

	if Prompt:IsDescendantOf(Drops) and Options.AutoInteractIgnoreList.Value["Dropped Items"] then return end
	if Prompt.Parent.Name == "TrackLever" then return end
	if Prompt.Name == "ActivateEventPrompt" and (Prompt.ActionText == "Close"
		or Prompt.Parent.Name == "ElevatorBreaker"
		or (Prompt.Parent.Parent and Prompt.Parent.Parent.Name == "IndustrialGate"))
	then return end
	if Prompt.Name == "ActivateEventPrompt" and (Prompt.Parent.Name == "Padlock" or Prompt.Parent.Name == "MinesAnchor") then return end
	if Prompt.Parent.Name == "LeverForGate" and Prompt:GetAttribute("Interactions") then return end
	if Prompt.Parent.Parent and (Prompt.Parent.Parent.Name == "DoorFake" or Prompt.Parent.Parent.Name == "FakeDoor") then return end
	if Prompt.Parent:GetAttribute("JeffShop") and Options.AutoInteractIgnoreList.Value["Jeff Items"] then return end
	if Prompt:GetAttribute("AutoInteractIgnore") then return end
	if Prompt.Name == "PushPrompt" and Options.AutoInteractIgnoreList.Value["Minecarts"] then return end
	if (Prompt.Parent.Name == "GoldPile" or Prompt.Parent.Name == "StardustPickup") and Options.AutoInteractIgnoreList.Value["Currency"] then return end
	if Prompt.Name == "SeatPrompt" and Options.AutoInteractIgnoreList.Value["Seats"] then return end
	if Prompt.Name == "InteractPrompt" and PromptHasAncestorName(Prompt, ArchivesChairNames) then return end
	if Prompt.Name == "TrashcanPrompt" and Options.AutoInteractIgnoreList.Value["Trashcans"] then return end
	if Prompt.Name == "CartPrompt" and Options.AutoInteractIgnoreList.Value["Carts"] then return end
	if Prompt.Name == "ActivateEventPrompt" and Prompt:FindFirstAncestor("ArchivesTerminal") then return end
	if Prompt.Name == "InteractPrompt" and Prompt:FindFirstAncestor("ArchivesWaterCooler") and Options.AutoInteractIgnoreList.Value["Water Cooler"] then return end
	if Prompt.Name == "InteractPrompt" and string.match(Prompt.Parent.Name, "^HidingSpot%d$") and Options.AutoInteractIgnoreList.Value["Closets"] then return end
	if (Prompt.Parent.Name == "PaperPlane" or Prompt.Parent.Name == "PaperPlanePickup") and Options.AutoInteractIgnoreList.Value["Paper Planes"] then return end
	if PromptHasAncestorName(Prompt, StairwellDebrisNames) and Options.AutoInteractIgnoreList.Value["Stairwell Debris"] then return end

	if Prompt.Parent.Name == "Bandage" then
		local BPack = Functions.HasItem("BandagePack")
		if Humanoid.Health >= Humanoid.MaxHealth and not BPack then return end
		if BPack and BPack:GetAttribute("Durability") >= BPack:GetAttribute("DurabilityMax") then return end
	end

	if Prompt.Parent.Name == "Battery" then
		local Tool = Character:FindFirstChildOfClass("Tool")
		local BPack = Functions.HasItem("BatteryPack")
		if not Tool and not BPack then return end
		if Tool and Tool:GetAttribute("LightSource") then
			if Tool:GetAttribute("Durability") and Tool:GetAttribute("DurabilityMax")
				and Tool:GetAttribute("Durability") > Tool:GetAttribute("DurabilityMax")
			then return end
		elseif not BPack then
			return
		end
		if BPack and BPack:GetAttribute("Durability") >= BPack:GetAttribute("DurabilityMax") then return end
	end

	if Prompt.Name == "HerbPrompt" then
		local Effects = Globals.MainUI.MainFrame.Healthbar:FindFirstChild("Effects")
		if Effects and Effects.HerbGreenEffect.Visible then return end
	end

	if (Prompt.Parent.Name == "LibraryHintPaper" or Prompt.Parent.Name == "PickupItem") and (Functions.HasItem("LibraryHintPaper") or Functions.HasItem("LibraryHintPaperHard")) then return end
	if Prompt.Parent.Name == "AlarmClock" and Functions.HasItem("AlarmClock") then return end
	if Prompt.Parent.Name == "KeyObtainFake" or Prompt.Parent.Name == "TithingPlate" then return end

	Functions.FirePrompt(Prompt)
	TriggerDebounce = true
	if Floor == "OldHotel" then task.wait() end
	TriggerDebounce = false
end

Globals.LastAutoInteractFire = tick()
Connections.AutoInteract = Services.RunService.Heartbeat:Connect(function()
	local Active = Toggles.AutoInteractToggle.Value
    if not Active then return end
    if tick() - Globals.LastAutoInteractFire < 1/60 then return end

	for _, Prompt in Objects.Prompts do
        if Prompt:GetAttribute("ParentRoom") and tonumber(Prompt:GetAttribute("ParentRoom")) ~= tonumber(LocalPlayer:GetAttribute("CurrentRoom")) then continue end

		if Prompt.Parent and (Prompt.Parent:IsA("BasePart") or Prompt.Parent:IsA("Model")) then
			local Distance
			if Prompt.Parent:IsA("BasePart") then
				Distance = LocalPlayer:DistanceFromCharacter(Prompt.Parent.Position)
			else
				Distance = LocalPlayer:DistanceFromCharacter(Prompt.Parent:GetPivot().Position)
			end
			if Distance <= Prompt.MaxActivationDistance and Prompt.Enabled or Distance <= Prompt.MaxActivationDistance and Prompt.Name == "LongPushPrompt" or Distance <= Prompt.MaxActivationDistance and Prompt.Name == "BigPropPrompt" then
				task.spawn(Functions.TriggerPrompt, Prompt)
			end
		end
	end
    Globals.LastAutoInteractFire = tick()
end)

Connections.InfiniteItemsHandler = Services.ProximityPromptService.PromptTriggered:Connect(function(Object)
	if not Object:GetAttribute("FakePrompt") then return end

	local ToolNames = { "Lockpick","Shears","SkeletonKey","Key","GeneratorFuse","KeyElectrical","KeyBackdoor","KeyIron", "Multitool" }
	local AnimateToolNames = { "Lockpick","Shears","SkeletonKey","Key","KeyElectrical","KeyBackdoor","KeyIron", "Multitool" }
	local Tool
	for _, N in ToolNames do Tool = Character:FindFirstChild(N) if Tool then break end end

	local Prompt = Object
	local IsLockPrompt = Functions.IsLockPrompt(Prompt)
	if IsLockPrompt then
		if Options.AutoInteractIgnoreList.Value["Locks"] then return end
		local KeyItems = { "Key","GeneratorFuse","KeyBackdoor","KeyElectrical","KeyIron","Lockpick","SkeletonKey","Shears","Multitool" }
		local OffhandKeyItems = { "Key","GeneratorFuse","KeyElectrical","KeyIron" }
		local HasKey = false
		for _, K in KeyItems do if Functions.HasItem(K, true) then HasKey = true break end end
		for _, K in OffhandKeyItems do if Functions.HasItem(K) then HasKey = true break end end
		if not HasKey then return end
	end

	if Prompt.Parent.Name == "CuttableVines" and not Functions.HasItem("Shears", true) and not Functions.HasItem("Multitool", true) or Prompt.Parent.Name == "Chest_Vine" and not Functions.HasItem("Shears", true) and not Functions.HasItem("Multitool", true) or Prompt.Parent.Name == "Cellar" and not Functions.HasItem("Shears", true) and not Functions.HasItem("Multitool", true) then return end
	if Prompt.Parent.Name == "SkullLock" and not Functions.HasItem("SkeletonKey", true) then return end
	if Prompt.Parent.Name == "Lock1" and not Functions.HasItem("Lockpick", true) and not Functions.HasItem("Multitool", true) or Prompt.Parent.Name == "Lock2" and not Functions.HasItem("Lockpick", true) and not Functions.HasItem("Multitool", true) then return end
	if Functions.HasItem("Shears", true) and IsLockPrompt and Prompt.Parent.Name ~= "CuttableVines" and Prompt.Parent.Name ~= "Chest_Vine" and Prompt.Parent.Name ~= "Cellar" then return end

	if Tool and table.find(AnimateToolNames, Tool.Name) and Globals.UseAnimation and Globals.UseAnimationBreak then
		Globals.UseAnimation:Stop()
		Globals.UseAnimationBreak:Stop()
		Globals.UseAnimationBreak:Play()
		if Tool.Name == "Shears" then Tool:WaitForChild("Handle"):WaitForChild("sound_prompt"):Play() end
	end

	local AnyTool = Character:FindFirstChildOfClass("Tool")
	local ToolData = AnyTool and ItemNames[AnyTool.Name]
	if AnyTool and ToolData and Toggles.InfiniteItemsToggle.Value and Options.InfiniteItemsList.Value[ToolData] then
		Drops.ChildAdded:Once(function(NewTool)
			local Prompt = NewTool:FindFirstChild("ModulePrompt")
			local RealPrompt = FakePrompts[Object]
			Functions.FirePrompt(Prompt)
			Functions.FirePrompt(RealPrompt)
		end)
		Character.ChildAdded:Once(function(NewTool)
			if NewTool.Name == "Shears" then NewTool:WaitForChild("Handle"):WaitForChild("sound_promptend"):Play() end
		end)
		RemotesFolder.DropItem:FireServer(AnyTool)
	else
		local RealPrompt = FakePrompts[Object]
		Functions.FirePrompt(RealPrompt)
	end
end)

Connections.FloorReplicatedHandler = FloorReplicated.DescendantAdded:Connect(function(Object)
	if Toggles.DisableHasteJumpscare.Value and Object.Name == "Ambience" and Object:FindFirstAncestor("Haste") then
		task.defer(Functions.BindHasteAmbience)
	end
	if Object.Name == "GlitchScreech" then
		Modules.GlitchScreech = Object
		if Toggles.RemoveScreech.Value then Object.Name = "GlitchScreech_Disabled" end
	end
	if Object.Name == "Jumpscare_CreakDeath" and Object:IsA("ModuleScript") then
		Object:SetAttribute("OriginalName", Object:GetAttribute("OriginalName") or Object.Name)
		if Toggles.NoCreakJumpscare.Value then Object.Name = "Jumpscare_CreakDeath_Disabled" end
	end
	if Object.Name:find("Jumpscare") and Object:IsA("ModuleScript")
		and not Object.Name:find("Eyestalk") and not Object.Name:find("Groundskeeper") and not Object.Name:find("Monument")
	then
		Object:SetAttribute("OriginalName", Object.Name)
		if Toggles.DisableEntityJumpscares.Value then Object.Name = Object.Name .. "_Disabled" end
		table.insert(Objects.JumpscareModules, Object)
	end
end)

if FloorReplicated:FindFirstChild("DigitalTimer") then
	Connections.HasteTimerConnection = FloorReplicated.DigitalTimer:GetPropertyChangedSignal("Value"):Connect(function()
		if Toggles.NotifyHasteTime.Value then Functions.Caption(Functions.GetHasteTime(), true) end
	end)
end

Connections.FogHandler = Services.Lighting:GetPropertyChangedSignal("FogEnd"):Connect(function()
	if Services.Lighting.FogEnd ~= 10000000 then
		Globals.OldFog = Services.Lighting.FogEnd
	end
	if Toggles.RemoveCameraFog.Value then
		Services.Lighting.FogEnd = 10000000
	end
end)

Connections.FogHandler2 = Services.Lighting.DescendantAdded:Connect(function(Object)
	if Toggles.RemoveCameraFog.Value and FeatureConfig.Fog.DestroyNames[Object.Name] and not Globals.RestoringLightingEffects then
		task.defer(Functions.SetNamedLightingEffectsRemoved, true)
	end
	if not Object:IsA("Atmosphere") then return end
	Object:SetAttribute("Density_Old", Object.Density)
	if Toggles.RemoveCameraFog.Value then Object.Density = 0 end

	local AtmoConn2 = Object:GetPropertyChangedSignal("Density"):Connect(function()
		if Object.Density ~= 0 then Object:SetAttribute("Density_Old", Object.Density) end
		if Toggles.RemoveCameraFog.Value then Object.Density = 0 end
	end)
	Object.Destroying:Once(function()
		AtmoConn2:Disconnect()
		local Position = table.find(Globals.FogInstances, Object)
		if Position then table.remove(Globals.FogInstances, Position) end
	end)
	table.insert(Connections, AtmoConn2)
	table.insert(Globals.FogInstances, Object)
end)

do
	local CollectionService   = game:GetService("CollectionService")
	local fireproximityprompt = Ostium.Environment.fireproximityprompt
	local getconnections      = Ostium.Environment.getconnections
	local PlayerGui           = LocalPlayer:WaitForChild("PlayerGui")

	local RED   = Color3.fromRGB(255, 0, 0)
	local GREEN = Color3.fromRGB(0, 255, 0)

	local State = {
		ESP        = setmetatable({}, { __mode = "k" }),
		Prompts    = setmetatable({}, { __mode = "k" }),
		LastFired  = setmetatable({}, { __mode = "k" }),
		DroneConns = setmetatable({}, { __mode = "k" }),
		AlmaObjects = setmetatable({}, { __mode = "k" }),
		AlmaTriggers = setmetatable({}, { __mode = "k" }),
		AlmaLookElapsed = 0,
		MissingRooms = setmetatable({}, { __mode = "k" }),
		MissingPlaceholders = {},
		DroneStampedeRemote = nil,
		DroneStampedeElapsed = 0,
		Ticket        = nil,
		DoorsPassed   = 0,
		RansomElapsed = 0,
	}
	local Archives = {}

	local function IsArchives()
		return GameData:FindFirstChild("ArchivesDayPhase") ~= nil
	end
	local function GetMainUI()
		return Globals.MainUI or PlayerGui:FindFirstChild("MainUI")
	end
	local function SafeDestroy(Object)
		task.defer(function() pcall(function() Object:Destroy() end) end)
	end
	local function EntitySelected(Label)
		return Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value[Label]
	end

	do
		local NoiseAudioNames = {
			Threat = true,
			ThreatSevere = true,
			EmergeCue = true,
		}
		local NoiseVisualGuiNames = {
			NoiseVignette = true,
		}

		local function AddObjectEntry(Array, Object)
			if not Object or table.find(Array, Object) then return end
			table.insert(Array, Object)
		end

		local function RemoveObjectEntry(Array, Object)
			local Index = table.find(Array, Object)
			if Index then
				table.remove(Array, Index)
			end
		end

		local function DestroyMissingPlaceholder(Key)
			local Placeholder = State.MissingPlaceholders[Key]
			if not Placeholder then return end
			State.MissingPlaceholders[Key] = nil
			Functions.RemoveESP(Placeholder)
			RemoveObjectEntry(Objects.MissingObjects, Placeholder)
			SafeDestroy(Placeholder)
		end

		local function CreateMissingPlaceholder(Record)
			if not Record or not Record.CFrame or not Record.Size then return end

			local Placeholder = State.MissingPlaceholders[Record.Key]
			if not Placeholder or not Placeholder.Parent then
				Placeholder = Instance.new("Part")
				Placeholder.Name = "OstiumMissingObject"
				Placeholder.Parent = Globals.ArchivesESPFolder
				Placeholder.Anchored = true
				Placeholder.CanCollide = false
				Placeholder.CanTouch = false
				Placeholder.CanQuery = false
				Placeholder.Transparency = 1
				Placeholder.CastShadow = false
				Placeholder.Material = Enum.Material.SmoothPlastic
				Placeholder:SetAttribute("ParentRoom", Record.RoomName)
				Placeholder:SetAttribute("OstiumLabel", Record.Label)
				State.MissingPlaceholders[Record.Key] = Placeholder
				AddObjectEntry(Objects.MissingObjects, Placeholder)
				Placeholder.Destroying:Once(function()
					State.MissingPlaceholders[Record.Key] = nil
					RemoveObjectEntry(Objects.MissingObjects, Placeholder)
				end)
			end

			Placeholder.Size = Vector3.new(
				math.max(Record.Size.X, 0.25),
				math.max(Record.Size.Y, 0.25),
				math.max(Record.Size.Z, 0.25)
			)
			Placeholder.CFrame = Record.CFrame
			Placeholder:SetAttribute("OstiumLabel", Record.Label)
			Archives.ApplyMissingPlaceholderESP(Placeholder)
		end

		local function MarkMissingObject(Record)
			if not Record or Record.Lost then return end
			Record.Lost = true
			CreateMissingPlaceholder(Record)
		end

		local function TrackMissingObject(RoomState, ContainerName, Object)
			if not Object or not Object.Parent then return end
			if not (Object:IsA("Model") or Object:IsA("BasePart")) then return end

			local Room = RoomState.Room
			local Key = Functions.GetObjectTrackingKey(Object, Room.Name, ContainerName)
			local CFrameValue, SizeValue = Functions.GetObjectBounds(Object)
			if not CFrameValue or not SizeValue then return end

			DestroyMissingPlaceholder(Key)

			local Record = {
				Key = Key,
				Room = Room,
				RoomName = Room.Name,
				Name = Object.Name,
				Label = string.format("%s [%s]", Object.Name, Room.Name),
				CFrame = CFrameValue,
				Size = SizeValue,
				Lost = false,
			}
			RoomState.Records[Key] = Record

			local function OnLost()
				if RoomState.Records[Key] ~= Record then return end
				MarkMissingObject(Record)
			end

			table.insert(RoomState.Connections, Object.Destroying:Connect(OnLost))
			table.insert(RoomState.Connections, Object.AncestryChanged:Connect(function()
				if not Object:IsDescendantOf(Services.Workspace) then
					OnLost()
				end
			end))
		end

		local function HookMissingContainer(RoomState, ContainerName, Container)
			if not Container then return end
			for _, Child in Container:GetChildren() do
				task.defer(TrackMissingObject, RoomState, ContainerName, Child)
			end
			table.insert(RoomState.Connections, Container.ChildAdded:Connect(function(Child)
				task.defer(TrackMissingObject, RoomState, ContainerName, Child)
			end))
		end

		local function GetArchivesRoomRuntime(Room)
			if not Room then return end
			for _, Child in Room:GetChildren() do
				if Archives.IsArchivesRoomRuntime(Child) then
					return Child
				end
			end
		end


		function Archives.SetCreakJumpscareState(Value)
			local CreakModule = FloorReplicated and (
				FloorReplicated:FindFirstChild("Jumpscare_CreakDeath", true)
				or FloorReplicated:FindFirstChild("Jumpscare_CreakDeath_Disabled", true)
			)
			if not CreakModule or not CreakModule:IsA("ModuleScript") then return end
			CreakModule:SetAttribute("OriginalName", CreakModule:GetAttribute("OriginalName") or CreakModule.Name)
			CreakModule.Name = Value and "Jumpscare_CreakDeath_Disabled" or CreakModule:GetAttribute("OriginalName")
		end

		function Archives.ApplyNoiseAudioObject(Object)
			if not Object or not Object:IsA("Sound") or not NoiseAudioNames[Object.Name] then return end
			if Object:GetAttribute("OstiumNoiseVolume") == nil then
				Object:SetAttribute("OstiumNoiseVolume", Object.Volume)
			end
			Object.Volume = Toggles.AntiNoiseAudio.Value and 0 or Object:GetAttribute("OstiumNoiseVolume")
		end

		function Archives.ApplyNoiseVisualObject(Object)
			if not Object then return end

			if Object.Name == "NoiseModel" and Object:IsA("Model") then
				for _, Descendant in Object:GetDescendants() do
					if Descendant:IsA("BasePart") then
						if Descendant:GetAttribute("OstiumNoiseTransparency") == nil then
							Descendant:SetAttribute("OstiumNoiseTransparency", Descendant.Transparency)
						end
						Descendant.Transparency = Toggles.AntiNoiseVisuals.Value and 1 or Descendant:GetAttribute("OstiumNoiseTransparency")
					elseif Descendant:IsA("Decal") or Descendant:IsA("Texture") then
						if Descendant:GetAttribute("OstiumNoiseTransparency") == nil then
							Descendant:SetAttribute("OstiumNoiseTransparency", Descendant.Transparency)
						end
						Descendant.Transparency = Toggles.AntiNoiseVisuals.Value and 1 or Descendant:GetAttribute("OstiumNoiseTransparency")
					elseif Descendant:IsA("ParticleEmitter") or Descendant:IsA("Beam") or Descendant:IsA("Trail") then
						if Descendant:GetAttribute("OstiumNoiseEnabled") == nil then
							Descendant:SetAttribute("OstiumNoiseEnabled", Descendant.Enabled)
						end
						Descendant.Enabled = Toggles.AntiNoiseVisuals.Value and false or Descendant:GetAttribute("OstiumNoiseEnabled")
					elseif Descendant:IsA("Highlight") then
						if Descendant:GetAttribute("OstiumNoiseEnabled") == nil then
							Descendant:SetAttribute("OstiumNoiseEnabled", Descendant.Enabled)
						end
						Descendant.Enabled = Toggles.AntiNoiseVisuals.Value and false or Descendant:GetAttribute("OstiumNoiseEnabled")
					elseif Descendant:IsA("PointLight") or Descendant:IsA("SpotLight") or Descendant:IsA("SurfaceLight") then
						if Descendant:GetAttribute("OstiumNoiseEnabled") == nil then
							Descendant:SetAttribute("OstiumNoiseEnabled", Descendant.Enabled)
						end
						Descendant.Enabled = Toggles.AntiNoiseVisuals.Value and false or Descendant:GetAttribute("OstiumNoiseEnabled")
					elseif Descendant:IsA("BillboardGui") or Descendant:IsA("SurfaceGui") then
						if Descendant:GetAttribute("OstiumNoiseEnabled") == nil then
							Descendant:SetAttribute("OstiumNoiseEnabled", Descendant.Enabled)
						end
						Descendant.Enabled = Toggles.AntiNoiseVisuals.Value and false or Descendant:GetAttribute("OstiumNoiseEnabled")
					elseif Descendant:IsA("GuiObject") then
						if Descendant:GetAttribute("OstiumNoiseVisible") == nil then
							Descendant:SetAttribute("OstiumNoiseVisible", Descendant.Visible)
						end
						Descendant.Visible = Toggles.AntiNoiseVisuals.Value and false or Descendant:GetAttribute("OstiumNoiseVisible")
					end
				end
				return
			end

			if NoiseVisualGuiNames[Object.Name] and Object:IsA("GuiObject") then
				if Object:GetAttribute("OstiumNoiseVisible") == nil then
					Object:SetAttribute("OstiumNoiseVisible", Object.Visible)
				end
				Object.Visible = Toggles.AntiNoiseVisuals.Value and false or Object:GetAttribute("OstiumNoiseVisible")
			elseif NoiseVisualGuiNames[Object.Name] and Object:IsA("LayerCollector") then
				if Object:GetAttribute("OstiumNoiseEnabled") == nil then
					Object:SetAttribute("OstiumNoiseEnabled", Object.Enabled)
				end
				Object.Enabled = Toggles.AntiNoiseVisuals.Value and false or Object:GetAttribute("OstiumNoiseEnabled")
			end
		end

		function Archives.RefreshNoiseAudio()
			local NoiseModule = FloorReplicated and FloorReplicated:FindFirstChild("ClientRemote") and FloorReplicated.ClientRemote:FindFirstChild("NoiseTV")
			if NoiseModule then
				for _, Descendant in NoiseModule:GetDescendants() do
					Archives.ApplyNoiseAudioObject(Descendant)
				end
			end
			local CurrentCamera = Services.Workspace.CurrentCamera or Camera
			if CurrentCamera then
				for _, Descendant in CurrentCamera:GetDescendants() do
					Archives.ApplyNoiseAudioObject(Descendant)
				end
			end
		end

		function Archives.RefreshNoiseVisuals()
			local CurrentCamera = Services.Workspace.CurrentCamera or Camera
			if CurrentCamera then
				for _, Descendant in CurrentCamera:GetDescendants() do
					Archives.ApplyNoiseVisualObject(Descendant)
				end
			end
			local MainUI = GetMainUI()
			if MainUI then
				for _, Descendant in MainUI:GetDescendants() do
					Archives.ApplyNoiseVisualObject(Descendant)
				end
			end
		end

		function Archives.FireLookAwayReplication()
			if Floor == "Fools" or Floor == "OldHotel" then
				RemotesFolder.MotorReplication:FireServer(0, (Globals.SpoofOffset == 200 and 65 or -65), 0, false)
			else
				RemotesFolder.MotorReplication:FireServer(-650)
			end
		end

		function Archives.ApplyAlmaTrigger(Object)
			if not Object then return end
			local Disable = Toggles.AntiAlma.Value
			local function ApplyPart(Part)
				if Part:GetAttribute("OstiumAlmaCanTouch") == nil then
					Part:SetAttribute("OstiumAlmaCanTouch", Part.CanTouch)
				end
				Part.CanTouch = Disable and false or Part:GetAttribute("OstiumAlmaCanTouch")
			end
			if Object:IsA("BasePart") then
				ApplyPart(Object)
			else
				for _, Part in Object:GetDescendants() do
					if Part:IsA("BasePart") then
						ApplyPart(Part)
					end
				end
			end
		end

		function Archives.RegisterAlmaObject(Object)
			if not Object or State.AlmaObjects[Object] then return end
			State.AlmaObjects[Object] = true
			Object.Destroying:Once(function()
				State.AlmaObjects[Object] = nil
			end)
		end

		function Archives.RegisterAlmaTrigger(Object)
			if not Object or State.AlmaTriggers[Object] then return end
			State.AlmaTriggers[Object] = true
			Archives.ApplyAlmaTrigger(Object)
			Object.Destroying:Once(function()
				State.AlmaTriggers[Object] = nil
			end)
		end

		function Archives.IsAlmaActive()
			for Object in State.AlmaObjects do
				if Object and Object.Parent then
					return true
				end
			end
			return false
		end

		function Archives.ApplyMissingPlaceholderESP(Placeholder)
			if not Placeholder then return end
			if Toggles.MissingObjectESPToggle.Value then
				Functions.AddESP({
					Object = Placeholder,
					Text = Placeholder:GetAttribute("OstiumLabel") or Placeholder.Name,
					Color = Options.MissingObjectESPColor.Value,
				}, true)
			else
				Functions.RemoveESP(Placeholder)
			end
		end

		function Archives.CleanupMissingRoom(Room)
			local RoomState = State.MissingRooms[Room]
			if not RoomState then return end
			State.MissingRooms[Room] = nil

			for _, Connection in RoomState.Connections do
				pcall(function() Connection:Disconnect() end)
			end
			for Key in RoomState.Records do
				DestroyMissingPlaceholder(Key)
			end
		end

		function Archives.IsVineDoorModel(Object)
			if not Object or not Object:IsA("Model") then return false end
			local Base = Object:FindFirstChild("Base")
			return Base ~= nil
				and Base:FindFirstChild("EntryPrompt") ~= nil
				and Object:FindFirstChild("Entrance") ~= nil
				and Object:FindFirstChild("Exit") ~= nil
		end

		function Archives.IsArchivesRoomRuntime(Object)
			if not Object or not Object.Parent then return false end

			local Assets = Object:FindFirstChild("Assets")
			if Assets and (Assets:FindFirstChild("Deletable") or Assets:FindFirstChild("Fixed")) then
				return true
			end

			if Object:FindFirstChild("ForgetMeNotVineDoors") then
				return true
			end

			for _, Child in Object:GetChildren() do
				if Archives.IsVineDoorModel(Child) then
					return true
				end
			end

			return false
		end

		function Archives.RegisterVineDoor(Model)
			if not Archives.IsVineDoorModel(Model) then return end
			if table.find(Objects.VineDoors, Model) then return end

			local Room = Functions.GetRoomFromObject(Model)
			if Room then
				Model:SetAttribute("ParentRoom", tonumber(Room.Name) or Room.Name)
			end

			AddObjectEntry(Objects.VineDoors, Model)
			Model.Destroying:Once(function()
				RemoveObjectEntry(Objects.VineDoors, Model)
				Functions.RemoveESP(Model)
			end)
		end

		function Archives.RefreshVineDoorESP()
			for Index = #Objects.VineDoors, 1, -1 do
				local Model = Objects.VineDoors[Index]
				if not Model or not Model.Parent then
					if Model then Functions.RemoveESP(Model) end
					table.remove(Objects.VineDoors, Index)
				elseif Toggles.VineDoorESPToggle.Value then
					Functions.AddESP({
						Object = Model,
						Text = "Vine Door",
						Color = Options.VineDoorESPColor.Value,
					}, true)
				else
					Functions.RemoveESP(Model)
				end
			end
		end


		function Archives.HookArchivesRoom(Room)
			if not Room or State.MissingRooms[Room] then return end

			local Runtime = GetArchivesRoomRuntime(Room)
			if not Runtime then return end

			local RoomState = {
				Room = Room,
				Connections = {},
				Records = {},
			}
			State.MissingRooms[Room] = RoomState

			local Assets = Runtime:FindFirstChild("Assets")
			if Assets then
				for ContainerName in FMN_MISSING_OBJECT_CONTAINERS do
					HookMissingContainer(RoomState, ContainerName, Assets:FindFirstChild(ContainerName))
				end
			end

			for _, Descendant in Runtime:GetDescendants() do
				if Archives.IsVineDoorModel(Descendant) then
					Archives.RegisterVineDoor(Descendant)
				end
			end

			table.insert(RoomState.Connections, Runtime.DescendantAdded:Connect(function(Descendant)
				if Archives.IsVineDoorModel(Descendant) then
					Archives.RegisterVineDoor(Descendant)
					Archives.RefreshVineDoorESP()
				end
			end))
			table.insert(RoomState.Connections, Room.Destroying:Connect(function()
				Archives.CleanupMissingRoom(Room)
				Archives.RefreshVineDoorESP()
			end))
		end
	end

	function Archives.TrackEntityDestroy(Object)
		Object.Destroying:Once(function() State.ESP[Object] = nil end)
	end

	function Archives.AddEntityESP(Object, Label, Colour)
		if not Object or not Object.Parent or State.ESP[Object] then return end
		State.ESP[Object] = Label
		Functions.AddESP({ Object = Object, Text = GetEntityESPText(Object, Label), Color = Colour or Options.EntityESPColor.Value }, false)
		Archives.TrackEntityDestroy(Object)
	end

	function Archives.GetWaterPoolColor(Pool)
		return Pool:GetAttribute("Electrified") and RED or GREEN
	end
	function Archives.AddWaterPoolESP(Pool)
		if not EntitySelected("Water Pool") or State.ESP[Pool] then return end
		Archives.AddEntityESP(Pool, "Water Pool", Archives.GetWaterPoolColor(Pool))
		local Conn = Pool:GetAttributeChangedSignal("Electrified"):Connect(function()
			if State.ESP[Pool] then Ostium.ESPLibrary:UpdateObjectColor(Pool, Archives.GetWaterPoolColor(Pool)) end
		end)
		table.insert(Connections, Conn)
		Pool.Destroying:Once(function() Conn:Disconnect() end)
	end

	function Archives.ApplyEntityInstance(Object)
		if not Toggles.EntityESPToggle.Value or not IsArchives() then return end
		local Name = Object.Name
		if Name == "ArchivesFihTank" then
			if EntitySelected("Fih") then
				local Fih = Object:FindFirstChild("Fih")
				if Fih then Archives.AddEntityESP(Fih, "Fih") end
			end
		elseif Name == "NoiseModel" and Object:IsA("Model") then
			if EntitySelected("Noise") then Archives.AddEntityESP(Object, "Noise") end
		elseif string.find(Name, "^MirrorRig_Portrait") then
			if EntitySelected("Portrait") then Archives.AddEntityESP(Object, "Portrait") end
		elseif Name == "Water" and Object:IsA("Model") and (Object:FindFirstChild("Pool1") or Object:FindFirstChild("Pool2")) then
			for _, Pool in Object:GetChildren() do
				if string.match(Pool.Name, "^Pool%d+$") then Archives.AddWaterPoolESP(Pool) end
			end
		end
	end

	function Archives.GetDroneESPPart(Model)
		if not Model or not Model.Parent then return end

		local Root = Model:FindFirstChild("Root") or Model:FindFirstChild("HumanoidRootPart") or Model.PrimaryPart
		if not Root or not Root:IsA("BasePart") then
			Root = Model:FindFirstChildWhichIsA("BasePart")
		end
		if not Root then return end

		local ESPPart = Model:FindFirstChild("ostiumesp")
		if ESPPart and not ESPPart:IsA("BasePart") then
			ESPPart:Destroy()
			ESPPart = nil
		end

		if not ESPPart then
			ESPPart = Instance.new("Part")
			ESPPart.Name = "ostiumesp"
			ESPPart.Size = Vector3.new(math.max(Root.Size.X, 1), math.max(Root.Size.Y, 1), 0.02)
			ESPPart.Transparency = 0.99
			ESPPart.CanCollide = false
			ESPPart.CanTouch = false
			ESPPart.CanQuery = false
			ESPPart.Anchored = false
			ESPPart.Massless = true
			ESPPart.CastShadow = false
			ESPPart.Material = Enum.Material.Plastic
			ESPPart.CFrame = Root.CFrame
			ESPPart.Parent = Model

			local Weld = Instance.new("WeldConstraint")
			Weld.Name = "ostiumesp"
			Weld.Part0 = ESPPart
			Weld.Part1 = Root
			Weld.Parent = ESPPart
		else
			ESPPart.Size = Vector3.new(math.max(Root.Size.X, 1), math.max(Root.Size.Y, 1), 0.02)
			ESPPart.Transparency = 0.99
			ESPPart.CanCollide = false
			ESPPart.CanTouch = false
			ESPPart.CanQuery = false
			ESPPart.Anchored = false
			ESPPart.Massless = true
			ESPPart.CastShadow = false
			ESPPart.CFrame = Root.CFrame

			local Weld = ESPPart:FindFirstChildWhichIsA("WeldConstraint")
			if not Weld then
				Weld = Instance.new("WeldConstraint")
				Weld.Name = "ostiumesp"
				Weld.Parent = ESPPart
			end
			Weld.Part0 = ESPPart
			Weld.Part1 = Root
		end

		return ESPPart
	end

	function Archives.ApplyDroneESP(Model)
		if not EntitySelected("Drone") then return end
		local ESPPart = Archives.GetDroneESPPart(Model)
		if ESPPart then
			Archives.AddEntityESP(ESPPart, "Drone")
		end
	end

	function Archives.RecolourEntities(Colour)
		for Object, Label in State.ESP do
			if Label ~= "Water Pool" then Ostium.ESPLibrary:UpdateObjectColor(Object, Colour) end
		end
	end

	function Archives.ScanEntities()
		for _, Model in CollectionService:GetTagged("DronesEntity") do Archives.ApplyDroneESP(Model) end
		for _, Object in Services.Workspace:GetDescendants() do Archives.ApplyEntityInstance(Object) end
		local CurrentCamera = Services.Workspace.CurrentCamera or Camera
		if CurrentCamera then
			for _, Object in CurrentCamera:GetDescendants() do Archives.ApplyEntityInstance(Object) end
		end
	end

	local function RefreshEntities()
		for Object, Label in State.ESP do
			if not EntitySelected(Label) then
				Functions.RemoveESP(Object)
				State.ESP[Object] = nil
			end
		end
		if Toggles.EntityESPToggle.Value then Archives.ScanEntities() end
	end

	local function KillDroneHits(Model)
		if not getconnections then return end
		local Stored = State.DroneConns[Model] or {}
		for _, Name in { "Trampled", "ShoulderChecked", "WalkedInto" } do
			local Remote = Model:FindFirstChild(Name)
			if Remote and Remote:IsA("RemoteEvent") then
				local Ok, Conns = pcall(getconnections, Remote.OnClientEvent)
				if Ok and Conns then
					for _, Conn in Conns do
						pcall(function() Conn:Disable() end)
						table.insert(Stored, Conn)
					end
				end
			end
		end
		State.DroneConns[Model] = Stored
	end
	local function RestoreDroneHits()
		for Model, Conns in State.DroneConns do
			for _, Conn in Conns do pcall(function() Conn:Enable() end) end
			State.DroneConns[Model] = nil
		end
	end

	local function GetDroneStampedeRemote()
		local Cached = State.DroneStampedeRemote
		if Cached and Cached.Parent then
			return Cached
		end

		for _, Room in CurrentRooms:GetChildren() do
			local Clock = Room:FindFirstChild("ArchivesClock", true)
			if Clock then
				local Remote = Clock:FindFirstChild("LookedAtRemote")
				if Remote and Remote:IsA("RemoteEvent") then
					State.DroneStampedeRemote = Remote
					return Remote
				end
			end
		end
	end

	local function FireDroneStampedeRemote()
		local Remote = GetDroneStampedeRemote()
		if not Remote then return end
		pcall(function()
			Remote:FireServer()
		end)
	end

	local function HookDrone(Model)
		task.spawn(function()
			Archives.ApplyDroneESP(Model)
			if Toggles.AntiDrones.Value then
				KillDroneHits(Model)
				task.wait(0.25)
				if Toggles.AntiDrones.Value then KillDroneHits(Model) end
			end
		end)
	end

	local function TrackPrompt(Object)
		if Object.ClassName ~= "ProximityPrompt" then return end
		local Name = Object.Name
		if Name == "PortraitDupePrompt" then
			State.Prompts[Object] = "dupe"
		elseif Name == "GiveTakePrompt" then
			State.Prompts[Object] = "teller"
		elseif Name == "InteractPrompt" and Object.Parent and string.match(Object.Parent.Name, "^HidingSpot%d$") then
			State.Prompts[Object] = "closet"
		end
	end

	Functions.RefreshTellerDoorLabels = function()
		local Suffix = ""
		if Toggles.TellerDoorCounter.Value and State.Ticket then
			Suffix = " (" .. State.DoorsPassed .. "/" .. State.Ticket .. ")"
		end
		for _, Object in Objects.Doors do
			if Object and Object.Parent then
				pcall(function()
					Ostium.ESPLibrary:UpdateObjectText(Object, "Door " .. Functions.GetDoorNumber(Object) .. Suffix)
				end)
			end
		end
	end

	local function SetTicket(Number)
		State.Ticket = Number
		State.DoorsPassed = 0
		Functions.RefreshTellerDoorLabels()
	end
	local function ClearTicket()
		if not State.Ticket then return end
		State.Ticket = nil
		State.DoorsPassed = 0
		Functions.RefreshTellerDoorLabels()
	end

	local function InspectTellerPayload(Request, Data)
	if typeof(Data) ~= "table" then
		return
	end

	if Data.Player ~= nil then
		if Data.Player ~= LocalPlayer then
			return
		end
	end

	local Anim = Data.AnimName
	if Anim == nil then
		Anim = Request
	end

	if Anim == "HoldTicket" then
		if type(Data.TicketNumber) == "number" then
			SetTicket(Data.TicketNumber)
		end
		return
	end

	if Anim == "GiveTicket" then
		if type(Data.TicketNumber) == "number" then
			SetTicket(Data.TicketNumber)
		end
		return
	end

	if Anim == "TakeTicket" then
		ClearTicket()
		return
	end

	if Anim == "ServingTakeTicket" then
		ClearTicket()
		return
	end

	if Anim == "Deactivate" then
		ClearTicket()
	end
end

	local function HookTeller(Model)
		if Model.Name ~= "TellerEntity" then return end
		local Event = Model:WaitForChild("TellerEvent", 5)
		if not Event then return end
		table.insert(Connections, Event.OnClientEvent:Connect(InspectTellerPayload))
		local Reliable = Event:FindFirstChild("Reliable")
		if Reliable then
			table.insert(Connections, Reliable.OnClientEvent:Connect(InspectTellerPayload))
		end
		Model.Destroying:Once(ClearTicket)
	end

	local function HookPaperPlane(Tool)
		if Tool.Name ~= "PaperPlane" or Tool:GetAttribute("Ostium_PPHooked") then return end
		Tool:SetAttribute("Ostium_PPHooked", true)
		local function Clear()
			if Toggles.PaperPlaneNoCooldown.Value and Tool:GetAttribute("OnCooldown") == true then
				Tool:SetAttribute("OnCooldown", false)
			end
		end
		local Conn = Tool:GetAttributeChangedSignal("OnCooldown"):Connect(Clear)
		table.insert(Connections, Conn)
		Tool.Destroying:Once(function() Conn:Disconnect() end)
		Clear()
	end
	local function ScanForPaperPlane(Container)
		if not Container then return end
		for _, Tool in Container:GetChildren() do HookPaperPlane(Tool) end
	end
	local function BindBackpack()
		local Backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
		if not Backpack then return end
		ScanForPaperPlane(Backpack)
		table.insert(Connections, Backpack.ChildAdded:Connect(HookPaperPlane))
	end
	local function BindCharacter(Char)
		if not Char then return end
		ScanForPaperPlane(Char)
		table.insert(Connections, Char.ChildAdded:Connect(HookPaperPlane))
	end

	local function KillRansomAttack()
		if not getconnections or not getnilinstances then return end
		for _, Object in getnilinstances() do
			if Object.Name == "RansomAttack" and Object:IsA("RemoteEvent") then
				local Ok, Conns = pcall(getconnections, Object.OnClientEvent)
				if Ok and Conns then
					for _, Conn in Conns do pcall(function() Conn:Disable() end) end
				end
			end
		end
	end

	function Archives.HandleNoiseDescendant(Object)
		if Toggles.AntiNoiseAudio.Value then
			Archives.ApplyNoiseAudioObject(Object)
		end
		if Toggles.AntiNoiseVisuals.Value then
			Archives.ApplyNoiseVisualObject(Object)
		end
	end

	function Archives.HandleAlmaDescendant(Object)
		if AlmaTriggerNames[Object.Name] then
			Archives.RegisterAlmaTrigger(Object)
			return
		end

		if AlmaModelNames[Object.Name] then
			Archives.RegisterAlmaObject(Object)
			if Toggles.AntiAlma.Value then
				Archives.FireLookAwayReplication()
			end
		end
	end

	function Archives.HandleRuntimeDescendant(Object)
		if Archives.IsArchivesRoomRuntime(Object) and Object.Parent and Object.Parent.Parent == CurrentRooms then
			task.defer(Archives.HookArchivesRoom, Object.Parent)
		end
		if Archives.IsVineDoorModel(Object) then
			Archives.RegisterVineDoor(Object)
			Archives.RefreshVineDoorESP()
		end
	end

	function Archives.HandleDroneDescendant(Object)
		if Toggles.AntiDrones.Value and CollectionService:HasTag(Object, "DronesEntity") then
			KillDroneHits(Object)
		end

		if Object.Name == "LookedAtRemote" and Object:IsA("RemoteEvent") then
			local Clock = Object.Parent
			if Clock and Clock.Name == "ArchivesClock" then
				State.DroneStampedeRemote = Object
			end
		end
	end

	function Archives.HandleSafetyDescendant(Object)
		if Toggles.NoCreakJumpscare.Value and Object.Name == "Jumpscare_CreakDeath" and Object:IsA("ModuleScript") then
			Archives.SetCreakJumpscareState(true)
		end
		if Toggles.AntiPaperCut.Value and Object.Name == "ScribblesPaper" then
			SafeDestroy(Object)
		end
		if Toggles.AntiPortraitHaunt.Value and Object.Name == "crack" and Object:FindFirstChild("portraithauntreal") then
			SafeDestroy(Object)
		end
	end

	function Archives.OnWorkspaceDescendant(Object)
		TrackPrompt(Object)
		if Toggles.EntityESPToggle.Value then task.defer(Archives.ApplyEntityInstance, Object) end
		Archives.HandleNoiseDescendant(Object)
		Archives.HandleSafetyDescendant(Object)
		Archives.HandleAlmaDescendant(Object)
		Archives.HandleRuntimeDescendant(Object)
		Archives.HandleDroneDescendant(Object)
	end

	for _, Object in Services.Workspace:GetDescendants() do Archives.OnWorkspaceDescendant(Object) end
	Connections.ArchivesWorkspace = Services.Workspace.DescendantAdded:Connect(Archives.OnWorkspaceDescendant)
	local CurrentCamera = Services.Workspace.CurrentCamera or Camera
	if CurrentCamera then
		Connections.ArchivesCameraEntities = CurrentCamera.DescendantAdded:Connect(function(Object)
			if Toggles.EntityESPToggle.Value then task.defer(Archives.ApplyEntityInstance, Object) end
		end)
	end
	for _, Room in CurrentRooms:GetChildren() do
		task.defer(Archives.HookArchivesRoom, Room)
	end
	Connections.ArchivesRoomHandler = CurrentRooms.ChildAdded:Connect(function(Room)
		task.defer(Archives.HookArchivesRoom, Room)
	end)

	for _, Model in CollectionService:GetTagged("DronesEntity") do HookDrone(Model) end
	Connections.ArchivesDrones = CollectionService:GetInstanceAddedSignal("DronesEntity"):Connect(HookDrone)

	Connections.ArchivesLighting = Services.Lighting.DescendantAdded:Connect(function(Object)
		if Toggles.DisableDroneEffects.Value and Object.Name == "DroneBlur" then SafeDestroy(Object) end
		if Toggles.AntiNoiseAudio.Value then Archives.ApplyNoiseAudioObject(Object) end
		if Toggles.AntiNoiseVisuals.Value then Archives.ApplyNoiseVisualObject(Object) end
	end)

	task.spawn(function()
		local MainUI = PlayerGui:WaitForChild("MainUI", 9e9)
		if not MainUI then return end
		Connections.ArchivesMainUI = MainUI.DescendantAdded:Connect(function(Object)
			if Toggles.DisableDroneEffects.Value and Object.Name == "Footsteps" then
				SafeDestroy(Object)
			elseif Toggles.AntiPortraitHaunt.Value and Object.Name == "WeirdVignetteLive" then
				SafeDestroy(Object)
			end
			if Toggles.AntiNoiseAudio.Value then Archives.ApplyNoiseAudioObject(Object) end
			if Toggles.AntiNoiseVisuals.Value then Archives.ApplyNoiseVisualObject(Object) end
		end)
	end)

	local LiveEntities = Services.Workspace:FindFirstChild("LiveEntities")
	if LiveEntities then
		for _, Model in LiveEntities:GetChildren() do task.spawn(HookTeller, Model) end
		Connections.ArchivesLiveEntities = LiveEntities.ChildAdded:Connect(function(Model)
			task.spawn(HookTeller, Model)
		end)
	end

	BindBackpack()
	BindCharacter(LocalPlayer.Character)
	Connections.ArchivesBackpackWatch = LocalPlayer.ChildAdded:Connect(function(Child)
		if Child:IsA("Backpack") then task.defer(BindBackpack) end
	end)
	Connections.ArchivesCharacterWatch = LocalPlayer.CharacterAdded:Connect(BindCharacter)

	Connections.ArchivesRoomMove = LocalPlayer:GetAttributeChangedSignal("CurrentRoom"):Connect(function()
		if State.Ticket then State.DoorsPassed = State.DoorsPassed + 1 end
		task.defer(function()
			if Toggles.TellerDoorCounter.Value then Functions.RefreshTellerDoorLabels() end
		end)
	end)

	Connections.ArchivesPromptLoop = Services.RunService.Heartbeat:Connect(function()
		if not fireproximityprompt or not RootPart then return end
		if not Toggles.AutoPortraitDupe.Value and not Toggles.AutoTellerTicket.Value and not Toggles.AutoArchivesCloset.Value and not Toggles.AutoDisposeNoiseTV.Value then return end
		for Prompt, Kind in State.Prompts do
			if typeof(Prompt) ~= "Instance" or not Prompt.Parent or not Prompt.Enabled then continue end
			local On = (Kind == "dupe" and Toggles.AutoPortraitDupe.Value)
				or (Kind == "teller" and Toggles.AutoTellerTicket.Value)
				or (Kind == "closet" and Toggles.AutoArchivesCloset.Value)
			if not On then continue end
			local Anchor = Prompt.Parent:IsA("BasePart") and Prompt.Parent or Prompt:FindFirstAncestorWhichIsA("BasePart")
			if not Anchor or (RootPart.Position - Anchor.Position).Magnitude > (Prompt.MaxActivationDistance + 2) then continue end
			if Kind == "closet" then
				if not State.LastFired[Prompt] then
					State.LastFired[Prompt] = tick()
					pcall(fireproximityprompt, Prompt)
				end
			elseif tick() - (State.LastFired[Prompt] or 0) > 0.4 then
				State.LastFired[Prompt] = tick()
				pcall(fireproximityprompt, Prompt)
			end
		end

		if Toggles.AutoDisposeNoiseTV.Value then
			for _, Object in Objects.Items do
				if Object.Name ~= "TV_Stand" or not Object.Parent then continue end
				local Prompt = Object:FindFirstChild("CartPrompt", true)
				local Anchor = Object:IsA("BasePart") and Object or (Object.PrimaryPart or Object:FindFirstChildWhichIsA("BasePart", true))
				if Prompt and Prompt:IsA("ProximityPrompt") and Prompt.Enabled and Anchor then
					local Distance = (RootPart.Position - Anchor.Position).Magnitude
					if Distance <= (Prompt.MaxActivationDistance + 2) and tick() - (State.LastFired[Prompt] or 0) > 0.4 then
						State.LastFired[Prompt] = tick()
						pcall(fireproximityprompt, Prompt)
					end
				end
			end
		end
	end)

	Connections.ArchivesRansomLoop = Services.RunService.Heartbeat:Connect(function(Delta)
		if not Toggles.BlockRansom.Value then return end
		State.RansomElapsed = State.RansomElapsed + Delta
		if State.RansomElapsed < 0.15 then return end
		State.RansomElapsed = 0
		local Live = Services.Workspace:FindFirstChild("LiveEntities")
		if not Live then return end
		for _, Descendant in Live:GetDescendants() do
			local Name = Descendant.Name
			if Name == "RansomGui" and Descendant:IsA("SurfaceGui") then
				Descendant.Enabled = false
			elseif Name == "RansomVignette" then
				pcall(function() Descendant.Visible = false end)
			elseif Name == "GlitchLoop" and Descendant:IsA("Sound") then
				Descendant.Volume = 0
			elseif Name == "RansomEffect" then
				for _, Effect in Descendant:GetDescendants() do
					if Effect:IsA("ParticleEmitter") or Effect:IsA("Beam") or Effect:IsA("Light") then
						Effect.Enabled = false
					end
				end
			end
		end
	end)

	Connections.ArchivesDroneStampedeLoop = Services.RunService.Heartbeat:Connect(function(Delta)
		if not Toggles.AntiDrones.Value then return end
		State.DroneStampedeElapsed = State.DroneStampedeElapsed + Delta
		if State.DroneStampedeElapsed < 0.5 then return end
		State.DroneStampedeElapsed = 0
		FireDroneStampedeRemote()
	end)
	Connections.ArchivesAlmaLoop = Services.RunService.Heartbeat:Connect(function(Delta)
		State.AlmaLookElapsed = State.AlmaLookElapsed + Delta
		if State.AlmaLookElapsed < 0.1 then return end
		State.AlmaLookElapsed = 0
		if not Toggles.AntiAlma.Value then return end

		for Trigger in State.AlmaTriggers do
			if Trigger and Trigger.Parent then
				Archives.ApplyAlmaTrigger(Trigger)
			end
		end

		if Archives.IsAlmaActive() then
			Archives.FireLookAwayReplication()
		end
	end)

	Toggles.EntityESPToggle:OnChanged(RefreshEntities)
	Options.EntityESPOptions:OnChanged(RefreshEntities)
	Options.EntityESPColor:OnChanged(Archives.RecolourEntities)
	Toggles.VineDoorESPToggle:OnChanged(Archives.RefreshVineDoorESP)
	Options.VineDoorESPColor:OnChanged(Archives.RefreshVineDoorESP)
	Toggles.MissingObjectESPToggle:OnChanged(function()
		for _, Placeholder in Objects.MissingObjects do
			Archives.ApplyMissingPlaceholderESP(Placeholder)
		end
	end)
	Options.MissingObjectESPColor:OnChanged(function()
		for _, Placeholder in Objects.MissingObjects do
			if Placeholder and Placeholder.Parent then
				Ostium.ESPLibrary:UpdateObjectColor(Placeholder, Options.MissingObjectESPColor.Value)
			end
		end
	end)

	Toggles.AntiDrones:OnChanged(function(Value)
		if Value then
			State.DroneStampedeElapsed = 0
			for _, Model in CollectionService:GetTagged("DronesEntity") do KillDroneHits(Model) end
			FireDroneStampedeRemote()
		else
			RestoreDroneHits()
			State.DroneStampedeRemote = nil
		end
	end)

	Toggles.DisableDroneEffects:OnChanged(function(Value)
		if not Value then return end
		for _, Object in Services.Lighting:GetChildren() do
			if Object.Name == "DroneBlur" then SafeDestroy(Object) end
		end
		local MainUI = GetMainUI()
		if MainUI then
			for _, Object in MainUI:GetDescendants() do
				if Object.Name == "Footsteps" then SafeDestroy(Object) end
			end
		end
	end)

	Toggles.AntiPoolShock:OnChanged(function()
		Functions.ApplyRootOffsetSpoofState()
	end)
	Toggles.AntiAlma:OnChanged(function()
		for Trigger in State.AlmaTriggers do
			if Trigger and Trigger.Parent then
				Archives.ApplyAlmaTrigger(Trigger)
			end
		end
		if Toggles.AntiAlma.Value and Archives.IsAlmaActive() then
			Archives.FireLookAwayReplication()
		end
	end)

	Toggles.PaperPlaneNoCooldown:OnChanged(function(Value)
		if not Value then return end
		local Backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
		ScanForPaperPlane(Backpack)
		ScanForPaperPlane(LocalPlayer.Character)
		local Plane = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("PaperPlane"))
			or (Backpack and Backpack:FindFirstChild("PaperPlane"))
		if Plane then Plane:SetAttribute("OnCooldown", false) end
	end)

	Toggles.ArchivesAnticheatBypass:OnChanged(function(Value)
		if not Value or not Character then return end
		if Character:GetAttribute("RestrictMovement") == true then
			Functions.TryRestoreArchivesAnticheatBypass("toggle")
		end
		for AttributeName in ArchivesAnticheatModes do
			if Character:GetAttribute(AttributeName) == true then
				Functions.TryArchivesAnticheatBypass(AttributeName)
			end
		end
	end)

	Toggles.AntiNoiseAudio:OnChanged(function()
		Archives.RefreshNoiseAudio()
	end)

	Toggles.AntiNoiseVisuals:OnChanged(function()
		Archives.RefreshNoiseVisuals()
	end)

	Toggles.NoCreakJumpscare:OnChanged(function(Value)
		Archives.SetCreakJumpscareState(Value)
	end)

	Toggles.BlockRansom:OnChanged(function(Value)
		if Value then KillRansomAttack() end
	end)

	Toggles.TellerDoorCounter:OnChanged(function() Functions.RefreshTellerDoorLabels() end)

	if Toggles.AntiNoiseAudio.Value then Archives.RefreshNoiseAudio() end
	if Toggles.AntiNoiseVisuals.Value then Archives.RefreshNoiseVisuals() end
	if Toggles.NoCreakJumpscare.Value then Archives.SetCreakJumpscareState(true) end
end

local RusherAliases = { Rush=true, Ambush=true, Eyes=true, Lookman=true, Blitz=true, ["A-60"]=true, ["A-120"]=true, AR0xMBUSH=true, ["RNIUSHCG=="]=true, ["Custom Entity"]=true, Bash=true }

Connections.EntityHandler = Services.Workspace.ChildAdded:Connect(function(Entity)
	local EntityData = Entities[Entity.Name]
	if not EntityData then return end

	while not Entity.PrimaryPart do
		for _, Child in Entity:GetChildren() do
			if Child:IsA("BasePart") then Entity.PrimaryPart = Child end
		end
		task.wait()
	end
	task.wait(0.1)

	if not Entity.PrimaryPart or LocalPlayer:DistanceFromCharacter(Entity.PrimaryPart.Position) >= 10000 then return end

	local Alias = EntityData.Alias
    local RealAlias = Alias
	if Options.EntityList.Value[Alias] and Toggles.NotifyEntities.Value then
		local NotifyTitle = EntityData.NotifyMessage.Title
		local NotifyBody  = EntityData.NotifyMessage.Body
		local NotifyImage = EntityIcons[Entity.Name]

		if Entity.Name == "RushMoving" and Entity.PrimaryPart.Name ~= "RushNew" then
			NotifyTitle = NotifyTitle:gsub("Rush", Entity.PrimaryPart.Name)
			NotifyImage = Entity.PrimaryPart:WaitForChild("Attachment").ParticleEmitter.Texture
			Alias = Entity.PrimaryPart.Name
		end

		Functions.Notify({ Title = NotifyTitle, Body = NotifyBody, Image = NotifyImage, Time = Toggles.NotifyKeepNotifications.Value and Entity or nil })

		if Toggles.EntityChatToggle.Value then
			Functions.SendChat(Alias .. " " .. Options.EntityChatMessage.Value)
		end
	end

	if Entity.Name ~= "GloombatSwarm" then
		if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value[RealAlias] then
			if Entity.Name == "MonumentEntity" then
				Functions.AddESP({ Object = Entity.Top, Text = Alias, Color = Options.EntityESPColor.Value })
			else
				Functions.AddESP({ Object = Entity, Text = Alias, Color = Options.EntityESPColor.Value })
			end
		end
		table.insert(Objects.Entities, Entity)
	end

	if RusherAliases[EntityData.Alias] then
		Instance.new("Humanoid", Entity).Name = "HighlightHumanoid"
		local Root = Entity.PrimaryPart
		if Root then Root.Transparency = 0.999 Root.Material = Enum.Material.Plastic end
	end

	if Entity.Name == "Lookman" then
		CurrentRooms.ChildAdded:Wait()
		task.wait(10)
		Entity:Destroy()
	end
end)

local LastClean = tick()
Connections.Cleaner = Services.RunService.Heartbeat:Connect(function()
	if tick() - LastClean <= 0.5 then return end
	LastClean = tick()

	for ArrayName, Array in Objects do
		local I = #Array
		while I >= 1 do
			local Object = Array[I]
			if Object == nil or not Object:IsDescendantOf(Services.Workspace) then
				table.remove(Array, I)
				local Conn = ESPConnections[Object]
				if Conn then
					Conn:Disconnect()
					ESPConnections[Object] = nil
					local Pos = table.find(Connections, Conn)
					if Pos then table.remove(Connections, Pos) end
				end
			end
			I -= 1
		end
	end
end)

local LastPromptFix = tick()
Connections.PromptFixer = Services.RunService.Heartbeat:Connect(function()
	if tick() - LastPromptFix <= 0.5 then return end
	LastPromptFix = tick()
	if not Toggles.InstantPrompts.Value and not Toggles.PromptClip.Value and Options.PromptReachSlider.Value == 1 then
		return
	end

	for _, Prompt in Objects.Prompts do
		if not Functions.ShouldPreserveRealLockPrompt(Prompt)
			and Functions.ShouldModifyPrompt(Prompt)
			and Prompt:HasTag("DisableWhenEnabledOnClient")
		then
			Prompt:RemoveTag("DisableWhenEnabledOnClient")
		end
	end
end)

Connections.AutoGodmodeWatcher = Services.RunService.Heartbeat:Connect(function(Delta)
	if not Toggles.AutoGodmodeOnEntitySpawn.Value then return end

	AutoGodmodeState.Elapsed += Delta
	if AutoGodmodeState.Elapsed < 0.1 then return end
	AutoGodmodeState.Elapsed = 0

	local Threat = Functions.GetAutoGodmodeEntity()
	if Threat then
		if not Toggles.PositionSpoof.Value then
			AutoGodmodeState.Forced = true
			Toggles.PositionSpoof:SetValue(true)
		end
	elseif AutoGodmodeState.Forced then
		AutoGodmodeState.Forced = false
		if Toggles.PositionSpoof.Value then
			Toggles.PositionSpoof:SetValue(false)
		end
	end
end)

local CaptionConfig = FeatureConfig.DiscordCaption
local CaptionDelay = math.random(CaptionConfig.DelayMin, CaptionConfig.DelayMax)
task.delay(math.max(0, CaptionDelay - (tick() - LoadStart)), function()
	if Library.Unloaded then return end
	local Success = pcall(function()
		local DoorsCaptions = loadstring(game:HttpGet(CaptionConfig.Url))()
		DoorsCaptions.caption(CaptionConfig.Text, "info", CaptionConfig.Duration)
	end)
	if not Success and not Library.Unloaded then
		Functions.Caption(CaptionConfig.Text, false)
	end
end)

if LocalPlayer.Character then
	task.spawn(function() Functions.HandleCharacter(LocalPlayer.Character) end)
end

LocalPlayer.CharacterAdded:Connect(function(NewCharacter)
	if Connections.MainHandler then
		Connections.MainHandler:Disconnect()
		Connections.MainHandler = nil
	end
	task.wait(0.5)
	Functions.HandleCharacter(NewCharacter)
end)

Library:OnUnload(function()
	Functions.SetLadderSpeedOverride(false)
	Functions.RestoreGlitchCubeMovement()
	Globals.GlitchCube.Running = false

	for Key, Connection in Connections do
		if type(Key) == "string" then
			pcall(function() Connection:Disconnect() end)
		else
			pcall(function() Key:Disconnect() end)
			pcall(function() Connection:Disconnect() end)
		end
	end

	Functions.SetAntiJeffState(false)
	Functions.SetFiredampState(false)
	Functions.SetHasteJumpscareState(false)
	Functions.SetNamedLightingEffectsRemoved(false)

	for _, Object in Objects.Entities do
		if Object.Name == "Snare" or Object.Name == "GiggleCeiling" then
			local Hitbox = Object:FindFirstChild("Hitbox")
			if Hitbox then Hitbox.CanTouch = true end
		end
		if Object.Name == "GloomPile" then
			for _, Part in Object:GetDescendants() do
				if Part:IsA("BasePart") then Part.CanTouch = true end
			end
		end
		if Object.Name == "FakeDoor" or Object.Name == "DoorFake" then
			local Hidden = Object:FindFirstChild("Hidden")
			if Hidden then Hidden.CanTouch = true end
			local Lock = Object:FindFirstChild("Lock")
			if Lock and Lock:FindFirstChild("UnlockPrompt") then Lock.UnlockPrompt.Enabled = true end
		end
		if Object.Name == "SideroomSpace" then
			local Coll = Object:FindFirstChild("Collision")
			if Coll then Coll.CanCollide = false Coll.CanTouch = true end
		end
	end

	for _, Object in Objects.SeekBridges do Object:Destroy() end

	for _, Fog in Globals.FogInstances do
		if Fog.Parent then Fog.Density = Fog:GetAttribute("Density_Old") end
	end
	Services.Lighting.FogEnd = Globals.OldFog

	if Globals.ArchivesESPFolder then
		Globals.ArchivesESPFolder:Destroy()
	end

	local Vignette = Globals.MainUI:FindFirstChild("HideVignette") or Globals.MainUI.MainFrame:FindFirstChild("HideVignette")
	if Vignette then Vignette.Image = "rbxassetid://6100076320" end

	local ModuleRestores = {
		Screech = "Screech", Glitch = "Glitch", Shade = "Shade",
		SpiderJumpscare = "SpiderJumpscare", A90 = "A90", Dread = "Dread", Void = "Void"
	}
	for Key, OriginalName in ModuleRestores do
		if Modules[Key] then Modules[Key].Name = OriginalName end
	end
	local CreakJumpscare = FloorReplicated and FloorReplicated:FindFirstChild("Jumpscare_CreakDeath_Disabled", true)
		or (FloorReplicated and FloorReplicated:FindFirstChild("Jumpscare_CreakDeath", true))
	if CreakJumpscare and CreakJumpscare:IsA("ModuleScript") then
		CreakJumpscare.Name = CreakJumpscare:GetAttribute("OriginalName") or "Jumpscare_CreakDeath"
	end

	FakeEvents.Screech:Destroy()
	FakeEvents.Screech_Real.Parent = RemotesFolder
	FakeEvents.Shade:Destroy()
	FakeEvents.Shade_Real.Parent = RemotesFolder

	if FakeEvents.A90_Real then
		FakeEvents.A90:Destroy()
		FakeEvents.A90_Real.Parent = RemotesFolder
	end
	if FakeEvents.Surge_Real then
		FakeEvents.Surge:Destroy()
		FakeEvents.Surge_Real.Parent = RemotesFolder
	end

	Globals.SeekNodesFolder:Destroy()
	Globals.RoomsNodesFolder:Destroy()
	Globals.ManipulateBody:Destroy()

	local OldAmbient = CurrentRooms:FindFirstChild(tostring(LocalPlayer:GetAttribute("CurrentRoom"))):GetAttribute("Ambient")
	Services.TweenService:Create(Services.Lighting, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), { Ambient = OldAmbient }):Play()

	for _, Prompt in Objects.Prompts do
		if FakePrompts[Prompt] then
			FakePrompts[Prompt].Parent = Prompt.Parent
			Prompt:Destroy()
		end
		if Prompt.Parent then
			Prompt.HoldDuration = Prompt:GetAttribute("HoldDuration_Old") or Prompt.HoldDuration
			Prompt.RequiresLineOfSight = Prompt:GetAttribute("RequiresLineOfSight_Old") or Prompt.RequiresLineOfSight
			Prompt.MaxActivationDistance = Prompt:GetAttribute("MaxActivationDistance_Old") or Prompt.MaxActivationDistance
		end
	end

	Character:SetAttribute("CanJump",  OldJump)
	Character:SetAttribute("CanSlide", OldSlide)

	for _, Object in Services.Workspace:GetDescendants() do
		task.spawn(function() Functions.RemoveESP(Object) end)
	end

	Humanoid.WalkSpeed  = Functions.GetCurrentSpeed()
	Humanoid.JumpPower  = Globals.BaseJumpPower or 5
	Functions.ApplyHipHeightState()

	local BaseY = 0.18
	Collision.Position          = RootPart.Position + Vector3.new(0, BaseY, 0)
	CollisionPart.Position      = RootPart.Position + Vector3.new(0, BaseY, 0)
	CollisionPartClone.Position = RootPart.Position + Vector3.new(0, BaseY, 0)

	if Character:FindFirstChild("LowerTorso") and Character.LowerTorso:FindFirstChild("Root") then
		Character.LowerTorso.Root.C1 = Globals.OriginalC1
	end
	if Collision:FindFirstChild("CollisionCrouch") then
		Collision.CollisionCrouch.Position = RootPart.Position + Vector3.new(0, -0.982, 0)
	end

	CollisionClone:Destroy()
	CollisionPartClone:Destroy()
	Ostium.ESPLibrary:Unload()

	if Main_Game then
		Main_Game.fovtarget   = 70
		Main_Game.spring.Speed = 8
		Main_Game.tooloffset   = Vector3.zero
	end

	if Globals.OriginalGetMoveVector then 
		local Controls = require(LocalPlayer.PlayerScripts.PlayerModule):GetControls()
		Controls.GetMoveVector = Globals.OriginalGetMoveVector
	end
	if MainHook and Ostium and Ostium.Environment and Ostium.Environment.hookmetamethod then
		pcall(function()
			Ostium.Environment.hookmetamethod(game, "__namecall", MainHook)
		end)
		MainHook = nil
	end
	if OtherHook and Ostium and Ostium.Environment and Ostium.Environment.hookmetamethod then
		pcall(function()
			Ostium.Environment.hookmetamethod(game, "__index", OtherHook)
		end)
		OtherHook = nil
	end

	getgenv().__o = nil
	getgenv().OstiumLoaded = nil
end)

while not Globals.MainUI do task.wait() end
Ostium.Internal.RenderConfigPane(Window)
Functions.Notify({ Title = "Successfully loaded in " .. math.floor((tick() - LoadStart) * 1000) / 1000 .. " seconds." , Body = "Press '" .. tostring(Options.MenuKeybind.Value) .. "' to toggle the UI."})


if Loading then
    pcall(function() Loading:Continue() end)
    Loading = nil
end
