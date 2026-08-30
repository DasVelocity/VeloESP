--!nocheck
--[[

	██╗   ██╗███████╗██╗      ██████╗ ███████╗███████╗██████╗
	██║   ██║██╔════╝██║     ██╔═══██╗██╔════╝██╔════╝██╔══██╗
	██║   ██║█████╗  ██║     ██║   ██║█████╗  ███████╗██████╔╝
	╚██╗ ██╔╝██╔══╝  ██║     ██║   ██║██╔══╝  ╚════██║██╔═══╝
	 ╚████╔╝ ███████╗███████╗╚██████╔╝███████╗███████║██║
	  ╚═══╝  ╚══════╝╚══════╝ ╚═════╝ ╚══════╝╚══════╝╚═╝

							  v1.0.0

							VeloESP

]]

-- // Services // --
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

-- // Variables // --
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Environment = (getgenv and getgenv()) or shared

if Environment.VeloESP and not Environment.VeloESP._Destroyed then
	return Environment.VeloESP
end

-- // Core Functions // --
local function New(ClassName, Properties)
	local Object = Instance.new(ClassName)

	for Property, Value in Properties or {} do
		if Property == "Parent" then
			continue
		end

		Object[Property] = Value
	end

	-- // Parent last // --
	if Properties and Properties.Parent then
		Object.Parent = Properties.Parent
	end

	return Object
end

local function Destroy(Object)
	if not Object then
		return
	end

	pcall(Object.Destroy, Object)
end

local function CloneTable(Source)
	local Result = {}

	for Key, Value in Source do
		Result[Key] = Value
	end

	return Result
end

local function Merge(Target, Source)
	for Key, Value in Source or {} do
		Target[Key] = Value
	end

	return Target
end

local function GetPart(Target)
	if typeof(Target) ~= "Instance" then
		return nil
	end

	if Target:IsA("BasePart") then
		return Target
	end

	if Target:IsA("Model") then
		return Target.PrimaryPart
			or Target:FindFirstChildWhichIsA("BasePart", true)
	end

	return Target:FindFirstChildWhichIsA("BasePart", true)
end

local function GetCFrame(Target)
	if typeof(Target) ~= "Instance" then
		return nil
	end

	if Target:IsA("Model") then
		return Target:GetPivot()
	end

	if Target:IsA("BasePart") then
		return Target.CFrame
	end

	if Target:IsA("Attachment") then
		return Target.WorldCFrame
	end

	local Part = GetPart(Target)
	return Part and Part.CFrame or nil
end

local function GetBounds(Target)
	if typeof(Target) ~= "Instance" then
		return nil, nil
	end

	if Target:IsA("Model") then
		return Target:GetBoundingBox()
	end

	if Target:IsA("BasePart") then
		return Target.CFrame, Target.Size
	end

	local Part = GetPart(Target)

	if Part then
		return Part.CFrame, Part.Size
	end

	return nil, nil
end

local function WorldToViewport(Position)
	if Camera == nil then
		Camera = workspace.CurrentCamera
	end

	if Camera == nil then
		return Vector3.zero, false
	end

	return Camera:WorldToViewportPoint(Position)
end

local function DistanceFromCamera(Target)
	if Camera == nil then
		Camera = workspace.CurrentCamera
	end

	local CFrame = GetCFrame(Target)

	if not (Camera and CFrame) then
		return math.huge
	end

	return (CFrame.Position - Camera.CFrame.Position).Magnitude
end

local function UpdateLine(Frame, PointA, PointB, Thickness)
	local Delta = PointB - PointA
	local Center = PointA + Delta / 2

	Frame.AnchorPoint = Vector2.new(0.5, 0.5)
	Frame.Position = UDim2.fromOffset(Center.X, Center.Y)
	Frame.Size = UDim2.fromOffset(Delta.Magnitude, Thickness)
	Frame.Rotation = math.deg(math.atan2(Delta.Y, Delta.X))
end

local function GetScreenBounds(Target)
	local CFrame, Size = GetBounds(Target)

	if not (CFrame and Size) then
		return nil
	end

	-- // Corners // --
	local Half = Size / 2
	local Corners = {
		Vector3.new(-Half.X, -Half.Y, -Half.Z),
		Vector3.new(-Half.X, -Half.Y,  Half.Z),
		Vector3.new(-Half.X,  Half.Y, -Half.Z),
		Vector3.new(-Half.X,  Half.Y,  Half.Z),
		Vector3.new( Half.X, -Half.Y, -Half.Z),
		Vector3.new( Half.X, -Half.Y,  Half.Z),
		Vector3.new( Half.X,  Half.Y, -Half.Z),
		Vector3.new( Half.X,  Half.Y,  Half.Z),
	}

	local MinX, MinY = math.huge, math.huge
	local MaxX, MaxY = -math.huge, -math.huge
	local OnScreen = false

	for _, Corner in Corners do
		local Point = WorldToViewport(CFrame:PointToWorldSpace(Corner))

		if Point.Z <= 0 then
			continue
		end

		OnScreen = true

		MinX = math.min(MinX, Point.X)
		MinY = math.min(MinY, Point.Y)

		MaxX = math.max(MaxX, Point.X)
		MaxY = math.max(MaxY, Point.Y)
	end

	if not OnScreen then
		return nil
	end

	return {
		X = MinX,
		Y = MinY,

		Width = MaxX - MinX,
		Height = MaxY - MinY
	}
end

-- // GUI Variables // --
local GuiParent = LocalPlayer:WaitForChild("PlayerGui")
local CoreGuiAllowed = false

-- // Thread Identity Test // --
do
	local TestGui = Instance.new("ScreenGui")

	local Success = pcall(function()
		TestGui.Parent = CoreGui
	end)

	CoreGuiAllowed = Success

	if CoreGuiAllowed then
		GuiParent = CoreGui
	end

	TestGui:Destroy()
end

-- // GUI // --
local Root = New("ScreenGui", {
	Parent = GuiParent,
	Name = "VeloESP",

	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 999999
})

local OverlayRoot = New("Folder", {
	Parent = Root,
	Name = "Overlay"
})

local BillboardRoot = New("Folder", {
	Parent = Root,
	Name = "Billboards"
})

local WorldRoot = New("Folder", {
	Parent = Root,
	Name = "World"
})

-- // Library // --
local VeloESP = {
	Version = "3.0.0",
	_Destroyed = false,

	-- // ESP // --
	_Objects = {},

	-- // Connections // --
	_Connections = {},

	-- // Global Config // --
	Settings = {
		Enabled = true,

		Rainbow = false,
		RainbowSpeed = 0.15,
		RainbowSaturation = 0.8,
		RainbowValue = 1,

		Font = Enum.Font.RobotoMono,
		TextSize = 14
	}
}

-- // Default Settings // --
local Defaults = {
	Name = nil,
	Color = Color3.new(1, 1, 1),

	MaxDistance = 5000,

	Text = true,
	Distance = true,

	Highlight = true,
	Box = false,
	Tracer = false,
	Arrow = false,
	Skeleton = false,

	TracerFrom = "Bottom",

	Offset = Vector3.new(0, 2.5, 0),

	FillTransparency = 0.75,
	OutlineTransparency = 0,

	Thickness = 2
}

-- // Type Checks // --
local AllowedTracerFrom = {
	top = true,
	bottom = true,
	center = true,
	mouse = true
}

-- // ESP Object // --
local ESP = {}
ESP.__index = ESP

function ESP:_GetColor()
	if not VeloESP.Settings.Rainbow then
		return self.Options.Color
	end

	local Hue = (os.clock() * VeloESP.Settings.RainbowSpeed) % 1

	return Color3.fromHSV(
		Hue,
		VeloESP.Settings.RainbowSaturation,
		VeloESP.Settings.RainbowValue
	)
end

function ESP:_Create()
	local Target = self.Target
	local Options = self.Options
	local Part = GetPart(Target)

	-- // Billboard // --
	if Part then
		local Billboard = New("BillboardGui", {
			Parent = BillboardRoot,
			Name = "Text",

			Adornee = Part,
			AlwaysOnTop = true,
			LightInfluence = 0,

			Size = UDim2.fromOffset(240, 55),
			StudsOffset = Options.Offset
		})

		local Label = New("TextLabel", {
			Parent = Billboard,

			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,

			RichText = true,
			Text = "",
			TextColor3 = Options.Color,
			TextStrokeTransparency = 0,
			TextWrapped = true,

			Font = VeloESP.Settings.Font,
			TextSize = VeloESP.Settings.TextSize
		})

		self.UI.Text = Billboard
		self.UI.Label = Label
	end

	-- // Highlight // --
	self.UI.Highlight = New("Highlight", {
		Parent = WorldRoot,
		Name = "Highlight",

		Adornee = Target,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,

		FillColor = Options.Color,
		OutlineColor = Options.Color,

		FillTransparency = Options.FillTransparency,
		OutlineTransparency = Options.OutlineTransparency
	})

	-- // Box // --
	local Box = New("Frame", {
		Parent = OverlayRoot,
		Name = "Box",

		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false
	})

	self.UI.Box = Box
	self.UI.BoxLines = {}

	for _, Name in {"Top", "Bottom", "Left", "Right"} do
		self.UI.BoxLines[Name] = New("Frame", {
			Parent = Box,
			Name = Name,

			BorderSizePixel = 0,
			BackgroundColor3 = Options.Color
		})
	end

	-- // Tracer // --
	self.UI.Tracer = New("Frame", {
		Parent = OverlayRoot,
		Name = "Tracer",

		BorderSizePixel = 0,
		BackgroundColor3 = Options.Color,
		Visible = false
	})

	-- // Arrow // --
	self.UI.Arrow = New("TextLabel", {
		Parent = OverlayRoot,
		Name = "Arrow",

		BackgroundTransparency = 1,
		BorderSizePixel = 0,

		AnchorPoint = Vector2.new(0.5, 0.5),

		Text = "▲",
		TextScaled = true,
		TextStrokeTransparency = 0,

		Font = Enum.Font.GothamBold,
		TextColor3 = Options.Color,

		Visible = false
	})

	-- // Skeleton // --
	self.UI.Skeleton = {}

	for Index = 1, 14 do
		self.UI.Skeleton[Index] = New("Frame", {
			Parent = OverlayRoot,
			Name = "Bone" .. Index,

			BorderSizePixel = 0,
			BackgroundColor3 = Options.Color,
			Visible = false
		})
	end
end

function ESP:_HideAll()
	if self.UI.Text then
		self.UI.Text.Enabled = false
	end

	if self.UI.Highlight then
		self.UI.Highlight.Enabled = false
	end

	if self.UI.Box then
		self.UI.Box.Visible = false
	end

	if self.UI.Tracer then
		self.UI.Tracer.Visible = false
	end

	if self.UI.Arrow then
		self.UI.Arrow.Visible = false
	end

	for _, Line in self.UI.Skeleton do
		Line.Visible = false
	end
end

-- // Component Updates // --
function ESP:_UpdateText(Visible, IsOnScreen, Distance)
	if not self.UI.Text then
		return
	end

	local Enabled = Visible
		and IsOnScreen
		and self.Options.Text

	self.UI.Text.Enabled = Enabled

	if not Enabled then
		return
	end

	local Name = self.Options.Name or self.Target.Name

	self.UI.Text.StudsOffset = self.Options.Offset

	self.UI.Label.TextColor3 = self:_GetColor()
	self.UI.Label.Font = VeloESP.Settings.Font
	self.UI.Label.TextSize = VeloESP.Settings.TextSize

	if self.Options.Distance then
		self.UI.Label.Text = string.format(
			'%s\n<font size="11">[%d studs]</font>',
			Name,
			math.floor(Distance + 0.5)
		)
	else
		self.UI.Label.Text = Name
	end
end

function ESP:_UpdateHighlight(Visible)
	local Highlight = self.UI.Highlight
	local Enabled = Visible and self.Options.Highlight

	Highlight.Enabled = Enabled

	if not Enabled then
		return
	end

	local Color = self:_GetColor()

	Highlight.Adornee = self.Target
	Highlight.FillColor = Color
	Highlight.OutlineColor = Color

	Highlight.FillTransparency = self.Options.FillTransparency
	Highlight.OutlineTransparency = self.Options.OutlineTransparency
end

function ESP:_UpdateBox(Visible, IsOnScreen)
	local Enabled = Visible
		and IsOnScreen
		and self.Options.Box

	local Bounds = if Enabled then GetScreenBounds(self.Target) else nil

	self.UI.Box.Visible = Bounds ~= nil

	if not Bounds then
		return
	end

	local Thickness = math.max(1, self.Options.Thickness)
	local Color = self:_GetColor()

	self.UI.Box.Position = UDim2.fromOffset(Bounds.X, Bounds.Y)
	self.UI.Box.Size = UDim2.fromOffset(Bounds.Width, Bounds.Height)

	local Top = self.UI.BoxLines.Top
	local Bottom = self.UI.BoxLines.Bottom
	local Left = self.UI.BoxLines.Left
	local Right = self.UI.BoxLines.Right

	Top.AnchorPoint = Vector2.zero
	Top.Position = UDim2.fromOffset(0, 0)
	Top.Size = UDim2.new(1, 0, 0, Thickness)

	Bottom.AnchorPoint = Vector2.new(0, 1)
	Bottom.Position = UDim2.new(0, 0, 1, 0)
	Bottom.Size = UDim2.new(1, 0, 0, Thickness)

	Left.AnchorPoint = Vector2.zero
	Left.Position = UDim2.fromOffset(0, 0)
	Left.Size = UDim2.new(0, Thickness, 1, 0)

	Right.AnchorPoint = Vector2.new(1, 0)
	Right.Position = UDim2.new(1, 0, 0, 0)
	Right.Size = UDim2.new(0, Thickness, 1, 0)

	for _, Line in self.UI.BoxLines do
		Line.BackgroundColor3 = Color
	end
end

function ESP:_GetTracerOrigin()
	if Camera == nil then
		Camera = workspace.CurrentCamera
	end

	if Camera == nil then
		return Vector2.zero
	end

	local Viewport = Camera.ViewportSize
	local From = string.lower(tostring(self.Options.TracerFrom))

	if AllowedTracerFrom[From] == nil then
		From = "bottom"
	end

	if From == "top" then
		return Vector2.new(Viewport.X / 2, 0)

	elseif From == "center" then
		return Vector2.new(Viewport.X / 2, Viewport.Y / 2)

	elseif From == "mouse" then
		local Mouse = UserInputService:GetMouseLocation()
		return Vector2.new(Mouse.X, Mouse.Y)
	end

	return Vector2.new(Viewport.X / 2, Viewport.Y)
end

function ESP:_UpdateTracer(Visible, IsOnScreen, ScreenPosition)
	local Tracer = self.UI.Tracer
	local Enabled = Visible
		and IsOnScreen
		and self.Options.Tracer

	Tracer.Visible = Enabled

	if not Enabled then
		return
	end

	UpdateLine(
		Tracer,
		self:_GetTracerOrigin(),
		Vector2.new(ScreenPosition.X, ScreenPosition.Y),
		self.Options.Thickness
	)

	Tracer.BackgroundColor3 = self:_GetColor()
end

function ESP:_UpdateArrow(Visible, IsOnScreen, ScreenPosition)
	local Arrow = self.UI.Arrow
	local Enabled = Visible
		and not IsOnScreen
		and self.Options.Arrow

	Arrow.Visible = Enabled

	if not Enabled then
		return
	end

	if Camera == nil then
		Camera = workspace.CurrentCamera
	end

	if Camera == nil then
		return
	end

	local Viewport = Camera.ViewportSize
	local Center = Vector2.new(Viewport.X / 2, Viewport.Y / 2)

	local Direction = Vector2.new(
		ScreenPosition.X,
		ScreenPosition.Y
	) - Center

	if ScreenPosition.Z < 0 then
		Direction = -Direction
	end

	if Direction.Magnitude <= 0.001 then
		Direction = Vector2.new(0, -1)
	else
		Direction = Direction.Unit
	end

	local Radius = math.min(Viewport.X, Viewport.Y) * 0.42
	local Position = Center + Direction * Radius

	Arrow.Size = UDim2.fromOffset(25, 25)
	Arrow.Position = UDim2.fromOffset(Position.X, Position.Y)
	Arrow.Rotation = math.deg(math.atan2(Direction.Y, Direction.X)) + 90
	Arrow.TextColor3 = self:_GetColor()
end

-- // Skeleton Sequences // --
local R15 = {
	{"Head", "UpperTorso"},
	{"UpperTorso", "LowerTorso"},

	{"UpperTorso", "LeftUpperArm"},
	{"LeftUpperArm", "LeftLowerArm"},
	{"LeftLowerArm", "LeftHand"},

	{"UpperTorso", "RightUpperArm"},
	{"RightUpperArm", "RightLowerArm"},
	{"RightLowerArm", "RightHand"},

	{"LowerTorso", "LeftUpperLeg"},
	{"LeftUpperLeg", "LeftLowerLeg"},
	{"LeftLowerLeg", "LeftFoot"},

	{"LowerTorso", "RightUpperLeg"},
	{"RightUpperLeg", "RightLowerLeg"},
	{"RightLowerLeg", "RightFoot"}
}

local R6 = {
	{"Head", "Torso"},

	{"Torso", "Left Arm"},
	{"Torso", "Right Arm"},

	{"Torso", "Left Leg"},
	{"Torso", "Right Leg"}
}

function ESP:_UpdateSkeleton(Visible)
	local Lines = self.UI.Skeleton

	if not Visible
		or not self.Options.Skeleton
		or not self.Target:IsA("Model")
	then
		for _, Line in Lines do
			Line.Visible = false
		end

		return
	end

	local Sequence = if self.Target:FindFirstChild("UpperTorso")
		then R15
		else R6

	local Color = self:_GetColor()

	for Index, Line in Lines do
		local Segment = Sequence[Index]

		if not Segment then
			Line.Visible = false
			continue
		end

		local First = self.Target:FindFirstChild(Segment[1])
		local Second = self.Target:FindFirstChild(Segment[2])

		if not First
			or not Second
			or not First:IsA("BasePart")
			or not Second:IsA("BasePart")
		then
			Line.Visible = false
			continue
		end

		local PointA, VisibleA = WorldToViewport(First.Position)
		local PointB, VisibleB = WorldToViewport(Second.Position)

		if PointA.Z <= 0
			or PointB.Z <= 0
			or not (VisibleA or VisibleB)
		then
			Line.Visible = false
			continue
		end

		Line.Visible = true
		Line.BackgroundColor3 = Color

		UpdateLine(
			Line,
			Vector2.new(PointA.X, PointA.Y),
			Vector2.new(PointB.X, PointB.Y),
			self.Options.Thickness
		)
	end
end

function ESP:_Update()
	if self.Destroyed then
		return
	end

	-- // Target // --
	if not (self.Target and self.Target.Parent) then
		self:Destroy()
		return
	end

	if not VeloESP.Settings.Enabled or self.Hidden then
		self:_HideAll()
		return
	end

	local CFrame = GetCFrame(self.Target)

	if not CFrame then
		self:_HideAll()
		return
	end

	-- // Visibility // --
	local Distance = DistanceFromCamera(self.Target)
	local Visible = Distance <= self.Options.MaxDistance
	local ScreenPosition, IsOnScreen = WorldToViewport(CFrame.Position)

	-- // Components // --
	self:_UpdateText(Visible, IsOnScreen, Distance)
	self:_UpdateHighlight(Visible)
	self:_UpdateBox(Visible, IsOnScreen)
	self:_UpdateTracer(Visible, IsOnScreen, ScreenPosition)
	self:_UpdateArrow(Visible, IsOnScreen, ScreenPosition)
	self:_UpdateSkeleton(Visible)
end

-- // ESP Methods // --
function ESP:Set(Options)
	assert(typeof(Options) == "table", "Argument #1 must be a table.")

	Merge(self.Options, Options)
	return self
end

function ESP:Show()
	self.Hidden = false
	return self
end

function ESP:Hide()
	self.Hidden = true
	self:_HideAll()

	return self
end

function ESP:Toggle()
	if self.Hidden then
		self:Show()
	else
		self:Hide()
	end

	return self
end

function ESP:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true

	-- // Destroy components // --
	if self.UI.Text then
		Destroy(self.UI.Text)
	end

	Destroy(self.UI.Highlight)
	Destroy(self.UI.Box)
	Destroy(self.UI.Tracer)
	Destroy(self.UI.Arrow)

	for _, Line in self.UI.Skeleton do
		Destroy(Line)
	end

	VeloESP._Objects[self.Target] = nil
	table.clear(self.UI)
end

-- // Library Methods // --
function VeloESP.new(Target, Options)
	assert(not VeloESP._Destroyed, "VeloESP is destroyed, please reload it.")
	assert(typeof(Target) == "Instance", "Argument #1 must be an Instance.")

	if Options ~= nil then
		assert(typeof(Options) == "table", "Argument #2 must be a table.")
	end

	-- // Remove existing ESP // --
	local Existing = VeloESP._Objects[Target]

	if Existing then
		Existing:Destroy()
	end

	-- // Settings // --
	local FinalOptions = CloneTable(Defaults)
	Merge(FinalOptions, Options)

	if FinalOptions.Name == nil then
		FinalOptions.Name = Target.Name
	end

	-- // ESP Data // --
	local Object = setmetatable({
		Target = Target,
		Options = FinalOptions,

		Hidden = false,
		Destroyed = false,

		UI = {}
	}, ESP)

	VeloESP._Objects[Target] = Object

	Object:_Create()
	Object:_Update()

	return Object
end

function VeloESP.Get(Target)
	return VeloESP._Objects[Target]
end

function VeloESP.Remove(Target)
	local Object = VeloESP._Objects[Target]

	if Object then
		Object:Destroy()
	end
end

function VeloESP.Clear()
	if VeloESP._Destroyed then
		return
	end

	local Objects = {}

	for _, Object in VeloESP._Objects do
		table.insert(Objects, Object)
	end

	for _, Object in Objects do
		Object:Destroy()
	end
end

function VeloESP.Configure(Options)
	assert(typeof(Options) == "table", "Argument #1 must be a table.")

	Merge(VeloESP.Settings, Options)
	return VeloESP
end

function VeloESP.Destroy()
	if VeloESP._Destroyed then
		return
	end

	-- // Destroy library // --
	VeloESP.Clear()
	VeloESP._Destroyed = true

	-- // Clear connections // --
	for _, Connection in VeloESP._Connections do
		if Connection and Connection.Connected then
			Connection:Disconnect()
		end
	end

	table.clear(VeloESP._Connections)

	-- // Destroy GUI // --
	Destroy(Root)

	-- // Clear getgenv // --
	if Environment.VeloESP == VeloESP then
		Environment.VeloESP = nil
	end
end

-- // Connections // --
table.insert(
	VeloESP._Connections,
	RunService.RenderStepped:Connect(function()
		if VeloESP._Destroyed then
			return
		end

		if Camera == nil then
			Camera = workspace.CurrentCamera
		end

		local Objects = {}

		for _, Object in VeloESP._Objects do
			table.insert(Objects, Object)
		end

		for _, Object in Objects do
			Object:_Update()
		end
	end)
)

-- // Export // --
Environment.VeloESP = VeloESP
return VeloESP
