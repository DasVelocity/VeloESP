--!nocheck
--!nolint UnknownGlobal

local getgenv = getgenv or function()
	return shared
end

local ExistingTest = getgenv().VeloESP_Test

if ExistingTest then
	pcall(function()
		ExistingTest.ClearTestParts()
	end)

	pcall(function()
		ExistingTest.HeartbeatConnection:Disconnect()
	end)

	getgenv().VeloESP_Test = nil
end

-- // Clear Old VeloESP // --
if getgenv().VeloESP then
	pcall(function()
		getgenv().VeloESP.Destroy()
	end)

	getgenv().VeloESP = nil
end

-- // Libraries // --
local OBSIDIAN_URL = "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua"
local VELOESP_URL = "https://raw.githubusercontent.com/DasVelocity/VeloESP/refs/heads/main/VeloESP.lua"

local function LoadRemote(Name, Url)
	local Separator = "?"

	if string.find(Url, "?", 1, true) then
		Separator = "&"
	end

	local Source = game:HttpGet(Url .. Separator .. "cachebust=" .. tostring(os.time()))
	local Chunk, CompileError = loadstring(Source)

	assert(
		typeof(Chunk) == "function",
		string.format("%s failed to compile:\n%s", Name, tostring(CompileError))
	)

	return Chunk()
end

local Library = LoadRemote("Obsidian", OBSIDIAN_URL)
local VeloESP = LoadRemote("VeloESP", VELOESP_URL)

assert(VeloESP.Add and VeloESP.watch and VeloESP.WatchPlayers, "Hosted VeloESP.lua is missing the advanced API.")

-- // Services // --
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- // Variables // --
local LocalPlayer = Players.LocalPlayer

local State = {
	Players = false,
	Objects = false,
	TestParts = false,

	Highlights = true,
	Billboards = true,
	Distance = true,
	Tracers = true,
	EdgeBeacons = true,
	Boxes2D = true,
	Boxes3D = true,
	Skeleton = false,
	Rainbow = false,
	Fade = true,
	UltraPerformance = true,
}

local TestFolder = nil
local TestHandles = {}

local function ApplyGlobalSettings()
	local FarUpdateRate = 0.06
	local FarDistance = 900

	if State.UltraPerformance then
		FarUpdateRate = 0.16
		FarDistance = 550
	end

	VeloESP.Configure({
		Enabled = true,
		Rainbow = State.Rainbow,
		Highlighters = State.Highlights,
		Billboards = State.Billboards,
		Distance = State.Distance,
		Tracers = State.Tracers,
		EdgeBeacons = State.EdgeBeacons,
		Arrows = false,
		Boxes2D = State.Boxes2D,
		Boxes3D = State.Boxes3D,
		Skeleton = State.Skeleton,
		UpdateRate = 0,
		NearUpdateRate = 0,
		FarUpdateRate = FarUpdateRate,
		FarDistance = FarDistance,
	})
end

ApplyGlobalSettings()

local PlayerESP = VeloESP.WatchPlayers({
	Enabled = false,
	Name = function(Player)
		return Player.DisplayName ~= Player.Name
			and (Player.DisplayName .. " @" .. Player.Name)
			or Player.Name
	end,
	Color = function(Player)
		local Hue = (Player.UserId % 255) / 255
		return Color3.fromHSV(Hue, 0.75, 1)
	end,
	ESPType = "Highlight",
	Highlight = true,
	Text = true,
	Distance = true,
	MaxDistance = 5000,
	FillTransparency = 0.75,
	OutlineTransparency = 0,
	Tracer = {
		Enabled = true,
		From = "Bottom",
		Thickness = 2,
	},
	EdgeBeacon = {
		Enabled = true,
		Margin = 26,
		Length = 46,
		DotSize = 11,
		Pulse = true,
		Label = true,
	},
	Box2D = {
		Enabled = true,
		Thickness = 1,
		Filled = false,
	},
	Box3D = {
		Enabled = true,
		Thickness = 1,
	},
	Skeleton = {
		Enabled = State.Skeleton,
		Thickness = 1,
		UpdateRate = 0.06,
	},
	Fade = {
		Enabled = State.Fade,
		Speed = 18,
		OutSpeed = 24,
		Distance = true,
		Near = 60,
		Far = 5000,
		Min = 0.28,
		Max = 1,
	},
})

local WorldESP = VeloESP.watch(workspace, {
	Enabled = false,
	Interval = 0.2,
	Match = function(Object)
		if not Object:IsA("Model") and not Object:IsA("BasePart") then
			return false
		end

		local Name = string.lower(Object.Name)

		return string.find(Name, "key") ~= nil
			or string.find(Name, "door") ~= nil
			or string.find(Name, "chest") ~= nil
			or string.find(Name, "lever") ~= nil
			or string.find(Name, "objective") ~= nil
	end,
	Name = function(Object)
		return Object.Name
	end,
	Color = function(Object)
		local Name = string.lower(Object.Name)

		if string.find(Name, "door") then
			return Color3.fromRGB(0, 170, 255)
		elseif string.find(Name, "key") then
			return Color3.fromRGB(80, 255, 110)
		elseif string.find(Name, "chest") then
			return Color3.fromRGB(255, 190, 70)
		end

		return Color3.fromRGB(255, 85, 255)
	end,
	ESPType = "SelectionBox",
	Highlight = true,
	Text = true,
	Distance = true,
	MaxDistance = 7500,
	Transparency = 0.7,
	Tracer = {
		Enabled = true,
		From = "Mouse",
		Thickness = 2,
	},
	EdgeBeacon = {
		Enabled = true,
		Margin = 26,
		Length = 42,
		DotSize = 10,
		Pulse = true,
		Label = true,
	},
	Box2D = {
		Enabled = true,
		Thickness = 1,
		Filled = true,
		FillTransparency = 0.85,
	},
	Box3D = {
		Enabled = true,
		Thickness = 1,
	},
	Fade = {
		Enabled = State.Fade,
		Speed = 16,
		OutSpeed = 24,
		Distance = true,
		Near = 80,
		Far = 7500,
		Min = 0.2,
		Max = 1,
	},
})

local function ClearTestParts()
	for _, Handle in ipairs(TestHandles) do
		if Handle and Handle.Destroy then
			Handle:Destroy()
		end
	end

	table.clear(TestHandles)

	if TestFolder then
		TestFolder:Destroy()
		TestFolder = nil
	end
end

local function CreateTestPart(Name, Offset, Color, ESPType)
	local Character = LocalPlayer.Character
	local Root = Character and Character:FindFirstChild("HumanoidRootPart")
	local Origin = Root and Root.CFrame or CFrame.new(0, 8, 0)

	local Part = Instance.new("Part")
	Part.Name = Name
	Part.Anchored = true
	Part.CanCollide = false
	Part.Material = Enum.Material.Neon
	Part.Color = Color
	Part.Size = Vector3.new(3, 5, 3)
	Part.CFrame = Origin * CFrame.new(Offset)
	Part.Parent = TestFolder

	local Handle = VeloESP.Add({
		Name = Name .. " (" .. ESPType .. ")",
		Model = Part,
		ESPType = ESPType,
		Color = Color,
		FillColor = Color,
		OutlineColor = Color,
		SurfaceColor = Color,
		Text = true,
		Distance = true,
		MaxDistance = 10000,
		Transparency = 0.55,
		FillTransparency = 0.72,
		OutlineTransparency = 0,
		Tracer = {
			Enabled = true,
			Color = Color,
			From = "Bottom",
			Thickness = 2,
		},
		EdgeBeacon = {
			Enabled = true,
			Color = Color,
			Margin = 28,
			Length = 48,
			DotSize = 12,
			Pulse = true,
			Label = true,
		},
		Box2D = {
			Enabled = true,
			Color = Color,
			Thickness = 1,
			Filled = true,
			FillTransparency = 0.88,
		},
		Box3D = {
			Enabled = true,
			Color = Color,
			Thickness = 1,
		},
		Fade = {
			Enabled = State.Fade,
			Speed = 18,
			OutSpeed = 24,
			Distance = true,
			Near = 25,
			Far = 10000,
			Min = 0.2,
			Max = 1,
		},
	})

	table.insert(TestHandles, Handle)
end

local function SpawnTestParts()
	ClearTestParts()

	TestFolder = Instance.new("Folder")
	TestFolder.Name = "VeloESP_TestParts"
	TestFolder.Parent = workspace

	CreateTestPart("VeloESP_Highlight", Vector3.new(-10, 0, -28), Color3.fromRGB(85, 170, 255), "Highlight")
	CreateTestPart("VeloESP_SelectionBox", Vector3.new(-4, 0, -36), Color3.fromRGB(255, 210, 80), "SelectionBox")
	CreateTestPart("VeloESP_BoxAdornment", Vector3.new(4, 0, -36), Color3.fromRGB(120, 255, 140), "Adornment")
	CreateTestPart("VeloESP_Sphere", Vector3.new(10, 0, -28), Color3.fromRGB(255, 95, 170), "SphereAdornment")
	CreateTestPart("VeloESP_Cylinder", Vector3.new(0, 0, -48), Color3.fromRGB(180, 140, 255), "CylinderAdornment")
end

local function ApplyFadeSettings()
	local Settings = {
		Fade = {
			Enabled = State.Fade,
		},
	}

	if PlayerESP.Set then
		PlayerESP:Set(Settings)
	end

	WorldESP:Set(Settings)

	for _, Handle in ipairs(TestHandles) do
		if Handle and Handle.Set then
			Handle:Set(Settings)
		end
	end
end

-- // Window // --
local Window = Library:CreateWindow({
	Title = "VeloESP",
	Footer = "VeloESP v" .. tostring(VeloESP.Version),
	AutoShow = true,
	Center = true,
	Resizable = true,
	ShowCustomCursor = false,
	UnlockMouseWhileOpen = true,
	TabPadding = 3,
	MenuFadeTime = 0,
	CornerRadius = 7,
})

local ESPTab = Window:AddTab("ESP", "eye")
local MainGroup = ESPTab:AddLeftGroupbox("Targets")
local ComponentGroup = ESPTab:AddLeftGroupbox("Components")
local VisualGroup = ESPTab:AddLeftGroupbox("Visuals")

MainGroup:AddToggle("VeloESPPlayers", {
	Text = "Player ESP",
	Default = false,
	Callback = function(Value)
		State.Players = Value
		PlayerESP:SetEnabled(Value)
	end,
})

MainGroup:AddToggle("VeloESPObjects", {
	Text = "World Object ESP",
	Default = false,
	Callback = function(Value)
		State.Objects = Value
		WorldESP:SetEnabled(Value)
	end,
})

MainGroup:AddToggle("VeloESPTestParts", {
	Text = "Spawn Test ESP",
	Default = false,
	Callback = function(Value)
		State.TestParts = Value

		if Value then
			SpawnTestParts()
		else
			ClearTestParts()
		end
	end,
})

ComponentGroup:AddToggle("VeloESPHighlights", {
	Text = "Highlighters",
	Default = true,
	Callback = function(Value)
		State.Highlights = Value
		ApplyGlobalSettings()
	end,
})

ComponentGroup:AddToggle("VeloESPBillboards", {
	Text = "Text Billboards",
	Default = true,
	Callback = function(Value)
		State.Billboards = Value
		ApplyGlobalSettings()
	end,
})

ComponentGroup:AddToggle("VeloESPDistance", {
	Text = "Distance Text",
	Default = true,
	Callback = function(Value)
		State.Distance = Value
		ApplyGlobalSettings()
	end,
})

ComponentGroup:AddToggle("VeloESPTracers", {
	Text = "Tracers",
	Default = true,
	Callback = function(Value)
		State.Tracers = Value
		ApplyGlobalSettings()
	end,
})

ComponentGroup:AddToggle("VeloESPEdgeBeacons", {
	Text = "Edge Beacons",
	Default = true,
	Callback = function(Value)
		State.EdgeBeacons = Value
		ApplyGlobalSettings()
	end,
})

ComponentGroup:AddToggle("VeloESP2DBoxes", {
	Text = "2D Boxes",
	Default = true,
	Callback = function(Value)
		State.Boxes2D = Value
		ApplyGlobalSettings()
	end,
})

ComponentGroup:AddToggle("VeloESP3DBoxes", {
	Text = "3D Boxes",
	Default = true,
	Callback = function(Value)
		State.Boxes3D = Value
		ApplyGlobalSettings()
	end,
})

ComponentGroup:AddToggle("VeloESPSkeleton", {
	Text = "Skeleton",
	Default = false,
	Callback = function(Value)
		State.Skeleton = Value
		ApplyGlobalSettings()
	end,
})

VisualGroup:AddToggle("VeloESPRainbow", {
	Text = "Rainbow",
	Default = false,
	Callback = function(Value)
		State.Rainbow = Value
		ApplyGlobalSettings()
	end,
})

VisualGroup:AddToggle("VeloESPFade", {
	Text = "Fade",
	Default = true,
	Callback = function(Value)
		State.Fade = Value
		ApplyFadeSettings()
	end,
})

VisualGroup:AddToggle("VeloESPUltraPerformance", {
	Text = "Ultra Performance",
	Default = true,
	Callback = function(Value)
		State.UltraPerformance = Value
		ApplyGlobalSettings()
	end,
})

VisualGroup:AddDivider()

VisualGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
	Default = "RightShift",
	NoUI = true,
	Text = "Menu keybind",
})

Library.ToggleKeybind = Library.Options.MenuKeybind

local HeartbeatConnection = RunService.Heartbeat:Connect(function()
	if State.TestParts and TestFolder == nil then
		SpawnTestParts()
	end
end)

getgenv().VeloESP_Test = {
	Library = Library,
	VeloESP = VeloESP,
	PlayerESP = PlayerESP,
	WorldESP = WorldESP,
	SpawnTestParts = SpawnTestParts,
	ClearTestParts = ClearTestParts,
	HeartbeatConnection = HeartbeatConnection,
}
