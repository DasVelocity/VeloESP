local getgenv = getgenv or function()
	return shared
end

local Environment = getgenv()

if Environment.VeloESP and Environment.VeloESP._Destroyed ~= true then
	return Environment.VeloESP
end

local cloneref = cloneref or function(Object)
	return Object
end

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local function SafeCall(Callback, ...)
	if typeof(Callback) ~= "function" then
		return nil
	end

	local Packed = table.pack(xpcall(Callback, debug.traceback, ...))

	if not Packed[1] then
		warn("[VeloESP] callback error:\n" .. tostring(Packed[2]))
		return nil
	end

	return table.unpack(Packed, 2, Packed.n)
end

local function New(ClassName, Properties)
	local Object = Instance.new(ClassName)

	for Property, Value in pairs(Properties or {}) do
		if Property ~= "Parent" then
			Object[Property] = Value
		end
	end

	if Properties and Properties.Parent ~= nil then
		Object.Parent = Properties.Parent
	end

	return Object
end

local function Destroy(Object)
	if Object ~= nil then
		pcall(function()
			Object:Destroy()
		end)
	end
end

local function ShallowCopy(Source)
	local Result = {}

	for Key, Value in pairs(Source or {}) do
		Result[Key] = Value
	end

	return Result
end

local function DeepCopy(Source)
	if typeof(Source) ~= "table" then
		return Source
	end

	local Result = {}

	for Key, Value in pairs(Source) do
		Result[Key] = DeepCopy(Value)
	end

	return Result
end

local function Merge(Target, Source)
	for Key, Value in pairs(Source or {}) do
		if typeof(Value) == "table" and typeof(Target[Key]) == "table" then
			Merge(Target[Key], Value)
		else
			Target[Key] = Value
		end
	end

	return Target
end

local function Resolve(Value, Object, Fallback)
	if typeof(Value) == "function" then
		local Success, Result = pcall(Value, Object)
		return if Success and Result ~= nil then Result else Fallback
	end

	return if Value ~= nil then Value else Fallback
end

local function ClampNumber(Value, Min, Max, Fallback)
	Value = tonumber(Value)

	if Value == nil then
		return Fallback
	end

	return math.clamp(Value, Min, Max)
end

local function GetCamera()
	if Camera == nil or Camera.Parent == nil then
		Camera = workspace.CurrentCamera
	end

	return Camera
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
			or Target:FindFirstChild("HumanoidRootPart")
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

	if Target:IsA("Camera") then
		return Target.CFrame
	end

	local Part = GetPart(Target)
	return if Part then Part.CFrame else nil
end

local function GetBounds(Target)
	if typeof(Target) ~= "Instance" then
		return nil, nil
	end

	if Target:IsA("Model") then
		local Success, CFrame, Size = pcall(function()
			return Target:GetBoundingBox()
		end)

		if Success then
			return CFrame, Size
		end
	end

	if Target:IsA("BasePart") then
		return Target.CFrame, Target.Size
	end

	if Target:IsA("Attachment") then
		return Target.WorldCFrame, Vector3.new(1, 1, 1)
	end

	local Part = GetPart(Target)
	return if Part then Part.CFrame, Part.Size else nil, nil
end

local function WorldToViewport(Position)
	local ActiveCamera = GetCamera()

	if ActiveCamera == nil then
		return Vector3.zero, false
	end

	return ActiveCamera:WorldToViewportPoint(Position)
end

local function GetDistance(Target, From)
	local CFrame = GetCFrame(Target)

	if CFrame == nil then
		return math.huge
	end

	if typeof(From) == "Instance" then
		local FromCFrame = GetCFrame(From)
		if FromCFrame then
			return (CFrame.Position - FromCFrame.Position).Magnitude
		end
	elseif typeof(From) == "Vector3" then
		return (CFrame.Position - From).Magnitude
	end

	local ActiveCamera = GetCamera()
	return if ActiveCamera then (CFrame.Position - ActiveCamera.CFrame.Position).Magnitude else math.huge
end

local function UpdateLine(Frame, PointA, PointB, Thickness)
	local Delta = PointB - PointA
	local Center = PointA + Delta / 2

	Frame.AnchorPoint = Vector2.new(0.5, 0.5)
	Frame.Position = UDim2.fromOffset(Center.X, Center.Y)
	Frame.Size = UDim2.fromOffset(math.max(1, Delta.Magnitude), math.max(1, Thickness))
	Frame.Rotation = math.deg(math.atan2(Delta.Y, Delta.X))
end

local function GetModelCorners(Target)
	local CFrame, Size = GetBounds(Target)

	if not (CFrame and Size) then
		return false, {}, {}, 0, 0, 0, 0
	end

	local X, Y, Z = Size.X / 2, Size.Y / 2, Size.Z / 2
	local WorldCorners = {
		CFrame * Vector3.new(X, Y, Z),
		CFrame * Vector3.new(X, Y, -Z),
		CFrame * Vector3.new(X, -Y, Z),
		CFrame * Vector3.new(X, -Y, -Z),
		CFrame * Vector3.new(-X, Y, Z),
		CFrame * Vector3.new(-X, Y, -Z),
		CFrame * Vector3.new(-X, -Y, Z),
		CFrame * Vector3.new(-X, -Y, -Z),
	}

	local ScreenCorners = {}
	local OnScreen = false
	local MinX, MinY = math.huge, math.huge
	local MaxX, MaxY = -math.huge, -math.huge

	for Index, Corner in ipairs(WorldCorners) do
		local ScreenPoint, Visible = WorldToViewport(Corner)
		ScreenCorners[Index] = ScreenPoint

		if ScreenPoint.Z > 0 then
			OnScreen = OnScreen or Visible
			MinX = math.min(MinX, ScreenPoint.X)
			MinY = math.min(MinY, ScreenPoint.Y)
			MaxX = math.max(MaxX, ScreenPoint.X)
			MaxY = math.max(MaxY, ScreenPoint.Y)
		end
	end

	if MinX == math.huge then
		return false, WorldCorners, ScreenCorners, 0, 0, 0, 0
	end

	return OnScreen, WorldCorners, ScreenCorners, MinX, MinY, MaxX, MaxY
end

local function CreateLine(Parent, Name)
	return New("Frame", {
		Parent = Parent,
		Name = Name,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Visible = false,
	})
end

local function BuildComponentSettings(Value, Defaults)
	if typeof(Value) == "table" then
		return Merge(DeepCopy(Defaults), Value)
	end

	local Result = DeepCopy(Defaults)

	if typeof(Value) == "boolean" then
		Result.Enabled = Value
	end

	return Result
end

local GuiParent = nil
local StorageParent = ReplicatedStorage
local CoreGuiAllowed = false

do
	local TestGui = Instance.new("ScreenGui")
	local Success = pcall(function()
		TestGui.Parent = CoreGui
	end)

	CoreGuiAllowed = Success == true
	GuiParent = if CoreGuiAllowed then CoreGui else LocalPlayer:WaitForChild("PlayerGui")

	Destroy(TestGui)
end

local Root = New("ScreenGui", {
	Parent = GuiParent,
	Name = "VeloESP",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 999999,
})

pcall(function()
	Root.ClipToDeviceSafeArea = false
end)

local OverlayRoot = New("Folder", {
	Parent = Root,
	Name = "Overlay",
})

local BillboardRoot = New("Folder", {
	Parent = Root,
	Name = "Billboards",
})

local WorldRoot = New("Folder", {
	Parent = Root,
	Name = "World",
})

local HiddenRoot = New("Folder", {
	Parent = StorageParent,
	Name = "VeloESPStorage",
})

local Defaults = {
	Name = nil,
	Model = nil,
	TextModel = nil,
	Visible = true,
	Color = Color3.new(1, 1, 1),
	MaxDistance = 5000,
	Offset = Vector3.new(0, 2.5, 0),
	StudsOffset = nil,
	TextSize = 14,
	Font = nil,
	Text = true,
	Distance = true,
	Billboard = true,
	Highlight = true,
	ESPType = "Highlight",
	Thickness = 0.08,
	Transparency = 0.65,
	SurfaceColor = Color3.new(1, 1, 1),
	FillColor = nil,
	OutlineColor = nil,
	FillTransparency = 0.65,
	OutlineTransparency = 0,
	Tracer = {
		Enabled = false,
		Color = Color3.new(1, 1, 1),
		Thickness = 2,
		Transparency = 0,
		From = "Bottom",
	},
	Arrow = {
		Enabled = false,
		Color = Color3.new(1, 1, 1),
		CenterOffset = 420,
		Size = 36,
	},
	Box2D = {
		Enabled = false,
		Color = Color3.new(1, 1, 1),
		Thickness = 1,
		Transparency = 0,
		Filled = false,
		FillTransparency = 0.75,
	},
	Box3D = {
		Enabled = false,
		Color = Color3.new(1, 1, 1),
		Thickness = 1,
		Transparency = 0,
	},
	Skeleton = {
		Enabled = false,
		Color = Color3.new(1, 1, 1),
		Thickness = 1,
		Transparency = 0,
	},
	BeforeUpdate = nil,
	AfterUpdate = nil,
	OnDestroyFunc = nil,
	OnDestroy = nil,
}

local AllowedTracerFrom = {
	top = true,
	bottom = true,
	center = true,
	mouse = true,
}

local AllowedESPType = {
	text = true,
	highlight = true,
	selectionbox = true,
	adornment = true,
	boxadornment = true,
	sphereadornment = true,
	cylinderadornment = true,
}

local Box3DIndices = {
	{ 1, 2 }, { 2, 4 }, { 4, 3 }, { 3, 1 },
	{ 5, 6 }, { 6, 8 }, { 8, 7 }, { 7, 5 },
	{ 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 },
}

local SkeletonSegments = {
	R15 = {
		{ "Head", "UpperTorso" },
		{ "UpperTorso", "LowerTorso" },
		{ "UpperTorso", "LeftUpperArm" },
		{ "LeftUpperArm", "LeftLowerArm" },
		{ "LeftLowerArm", "LeftHand" },
		{ "UpperTorso", "RightUpperArm" },
		{ "RightUpperArm", "RightLowerArm" },
		{ "RightLowerArm", "RightHand" },
		{ "LowerTorso", "LeftUpperLeg" },
		{ "LeftUpperLeg", "LeftLowerLeg" },
		{ "LeftLowerLeg", "LeftFoot" },
		{ "LowerTorso", "RightUpperLeg" },
		{ "RightUpperLeg", "RightLowerLeg" },
		{ "RightLowerLeg", "RightFoot" },
	},
	R6 = {
		{ "Head", "Torso" },
		{ "Torso", "Left Arm" },
		{ "Torso", "Right Arm" },
		{ "Torso", "Left Leg" },
		{ "Torso", "Right Leg" },
	},
}

local VeloESP = {
	Version = "5.0.0",
	_Destroyed = false,
	_Objects = setmetatable({}, { __mode = "k" }),
	_Watchers = {},
	_Connections = {},
	Roots = {
		Gui = Root,
		Overlay = OverlayRoot,
		Billboards = BillboardRoot,
		World = WorldRoot,
		Storage = HiddenRoot,
	},
	Settings = {
		Enabled = true,
		IgnoreCharacter = true,
		Rainbow = false,
		RainbowSpeed = 0.15,
		RainbowSaturation = 0.8,
		RainbowValue = 1,
		Billboards = true,
		Distance = true,
		Highlighters = true,
		Tracers = true,
		Arrows = true,
		Boxes2D = true,
		Boxes3D = true,
		Skeleton = true,
		Font = Enum.Font.RobotoMono,
		TextSize = 14,
	},
}

VeloESP.GlobalConfig = VeloESP.Settings

local ESP = {}
ESP.__index = ESP

local function NormalizeOptions(Target, Options)
	local Final = DeepCopy(Defaults)
	Merge(Final, Options or {})

	Final.Model = Final.Model or Target
	Final.TextModel = Final.TextModel or Final.Model
	Final.Name = Final.Name or (Final.Model and Final.Model.Name) or "ESP"
	Final.StudsOffset = Final.StudsOffset or Final.Offset
	Final.Font = Final.Font or VeloESP.Settings.Font
	Final.TextSize = Final.TextSize or VeloESP.Settings.TextSize

	if Final.FillColor == nil then
		Final.FillColor = Final.Color
	end

	if Final.OutlineColor == nil then
		Final.OutlineColor = Final.Color
	end

	Final.Tracer = BuildComponentSettings(Final.Tracer, Defaults.Tracer)
	Final.Arrow = BuildComponentSettings(Final.Arrow, Defaults.Arrow)
	Final.Box2D = BuildComponentSettings(Final.Box2D or Final.Box, Defaults.Box2D)
	Final.Box3D = BuildComponentSettings(Final.Box3D, Defaults.Box3D)
	Final.Skeleton = BuildComponentSettings(Final.Skeleton, Defaults.Skeleton)

	if typeof(Final.Box) == "boolean" then
		Final.Box2D.Enabled = Final.Box
	end

	if typeof(Final.TracerFrom) == "string" then
		Final.Tracer.From = Final.TracerFrom
	end

	local TracerFrom = string.lower(tostring(Final.Tracer.From or "Bottom"))
	Final.Tracer.From = if AllowedTracerFrom[TracerFrom] then TracerFrom else "bottom"

	local Type = string.lower(tostring(Final.ESPType or "Highlight"))
	Final.ESPType = if AllowedESPType[Type] then Type else "highlight"

	Final.MaxDistance = tonumber(Final.MaxDistance) or Defaults.MaxDistance
	Final.Thickness = tonumber(Final.Thickness) or Defaults.Thickness
	Final.Transparency = ClampNumber(Final.Transparency, 0, 1, Defaults.Transparency)
	Final.FillTransparency = ClampNumber(Final.FillTransparency, 0, 1, Defaults.FillTransparency)
	Final.OutlineTransparency = ClampNumber(Final.OutlineTransparency, 0, 1, Defaults.OutlineTransparency)

	return Final
end

function ESP:_GetColor(Base)
	if VeloESP.Settings.Rainbow then
		return Color3.fromHSV(
			(os.clock() * VeloESP.Settings.RainbowSpeed) % 1,
			VeloESP.Settings.RainbowSaturation,
			VeloESP.Settings.RainbowValue
		)
	end

	return Base or self.CurrentSettings.Color
end

function ESP:_CreateBillboard()
	local Settings = self.CurrentSettings
	local Adornee = GetPart(Settings.TextModel or Settings.Model)

	if Adornee == nil then
		return
	end

	local Billboard = New("BillboardGui", {
		Parent = BillboardRoot,
		Name = "Billboard",
		Adornee = Adornee,
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Size = UDim2.fromOffset(260, 58),
		StudsOffset = Settings.StudsOffset,
		Enabled = false,
	})

	local Label = New("TextLabel", {
		Parent = Billboard,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Font = Settings.Font,
		RichText = true,
		Text = "",
		TextColor3 = Settings.Color,
		TextSize = Settings.TextSize,
		TextStrokeTransparency = 0,
		TextWrapped = true,
	})

	self.UI.Billboard = Billboard
	self.UI.Label = Label
end

function ESP:_CreateHighlighter()
	local Settings = self.CurrentSettings
	local Type = Settings.ESPType

	if Type == "text" or Settings.Highlight == false then
		return
	end

	local Target = Settings.Model
	local Part = GetPart(Target)
	local _, Size = GetBounds(Target)
	local Highlighter = nil

	if string.find(Type, "adornment") then
		if Part == nil then
			return
		end

		Size = Size or Part.Size

		if Type == "sphereadornment" then
			Highlighter = New("SphereHandleAdornment", {
				Parent = WorldRoot,
				Name = "SphereAdornment",
				Adornee = Part,
				AlwaysOnTop = true,
				ZIndex = 10,
				Radius = math.max(Size.X, Size.Y, Size.Z) * 0.62,
				Color3 = Settings.Color,
				Transparency = Settings.Transparency,
				Visible = false,
			})
		elseif Type == "cylinderadornment" then
			Highlighter = New("CylinderHandleAdornment", {
				Parent = WorldRoot,
				Name = "CylinderAdornment",
				Adornee = Part,
				AlwaysOnTop = true,
				ZIndex = 10,
				Height = Size.Y,
				Radius = math.max(Size.X, Size.Z) * 0.55,
				CFrame = CFrame.Angles(math.rad(90), 0, 0),
				Color3 = Settings.Color,
				Transparency = Settings.Transparency,
				Visible = false,
			})
		else
			Highlighter = New("BoxHandleAdornment", {
				Parent = WorldRoot,
				Name = "BoxAdornment",
				Adornee = Part,
				AlwaysOnTop = true,
				ZIndex = 10,
				Size = Size,
				Color3 = Settings.Color,
				Transparency = Settings.Transparency,
				Visible = false,
			})
		end
	elseif Type == "selectionbox" then
		Highlighter = New("SelectionBox", {
			Parent = WorldRoot,
			Name = "SelectionBox",
			Adornee = Target,
			Color3 = Settings.Color,
			LineThickness = Settings.Thickness,
			SurfaceColor3 = Settings.SurfaceColor,
			SurfaceTransparency = Settings.Transparency,
			Visible = false,
		})
	elseif Type == "highlight" then
		Highlighter = New("Highlight", {
			Parent = WorldRoot,
			Name = "Highlight",
			Adornee = Target,
			DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
			FillColor = Settings.FillColor,
			OutlineColor = Settings.OutlineColor,
			FillTransparency = Settings.FillTransparency,
			OutlineTransparency = Settings.OutlineTransparency,
			Enabled = false,
		})
	end

	self.UI.Highlighter = Highlighter
end

function ESP:_CreateOverlay()
	self.UI.Tracer = CreateLine(OverlayRoot, "Tracer")
	self.UI.Arrow = New("TextLabel", {
		Parent = OverlayRoot,
		Name = "Arrow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = ">",
		TextColor3 = self.CurrentSettings.Color,
		TextScaled = true,
		TextStrokeTransparency = 0,
		Visible = false,
	})

	local Box = New("Frame", {
		Parent = OverlayRoot,
		Name = "Box2D",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
	})

	local Fill = New("Frame", {
		Parent = Box,
		Name = "Fill",
		BackgroundColor3 = self.CurrentSettings.Color,
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	})

	self.UI.Box = Box
	self.UI.BoxFill = Fill
	self.UI.BoxLines = {
		Top = CreateLine(Box, "Top"),
		Bottom = CreateLine(Box, "Bottom"),
		Left = CreateLine(Box, "Left"),
		Right = CreateLine(Box, "Right"),
	}

	self.UI.Box3D = {}
	for Index = 1, #Box3DIndices do
		self.UI.Box3D[Index] = CreateLine(OverlayRoot, "Box3D_" .. tostring(Index))
	end

	self.UI.Skeleton = {}
	for Index = 1, #SkeletonSegments.R15 do
		self.UI.Skeleton[Index] = CreateLine(OverlayRoot, "Bone_" .. tostring(Index))
	end
end

function ESP:_Create()
	self:_CreateBillboard()
	self:_CreateHighlighter()
	self:_CreateOverlay()
end

function ESP:_SetHighlighterVisible(Visible)
	local Highlighter = self.UI.Highlighter

	if Highlighter == nil then
		return
	end

	if Highlighter:IsA("Highlight") then
		Highlighter.Enabled = Visible
	else
		Highlighter.Visible = Visible
	end
end

function ESP:_HideAll()
	if self.UI.Billboard then
		self.UI.Billboard.Enabled = false
	end

	self:_SetHighlighterVisible(false)

	if self.UI.Tracer then
		self.UI.Tracer.Visible = false
	end

	if self.UI.Arrow then
		self.UI.Arrow.Visible = false
	end

	if self.UI.Box then
		self.UI.Box.Visible = false
	end

	for _, Line in pairs(self.UI.Box3D or {}) do
		Line.Visible = false
	end

	for _, Line in pairs(self.UI.Skeleton or {}) do
		Line.Visible = false
	end
end

function ESP:_UpdateBillboard(Visible, OnScreen, Distance)
	local Billboard = self.UI.Billboard
	local Label = self.UI.Label
	local Settings = self.CurrentSettings
	local Enabled = Visible and OnScreen and Settings.Text == true and Settings.Billboard ~= false and VeloESP.Settings.Billboards == true

	if Billboard == nil or Label == nil then
		return
	end

	Billboard.Enabled = Enabled

	if not Enabled then
		return
	end

	local Name = tostring(Settings.Name or self.Target.Name)
	local Text = Name

	if Settings.Distance == true and VeloESP.Settings.Distance == true then
		Text = string.format('%s\n<font size="11">[%d studs]</font>', Name, math.floor(Distance + 0.5))
	end

	Billboard.Adornee = GetPart(Settings.TextModel or Settings.Model)
	Billboard.StudsOffset = Settings.StudsOffset
	Label.Text = Text
	Label.TextColor3 = self:_GetColor(Settings.Color)
	Label.Font = Settings.Font or VeloESP.Settings.Font
	Label.TextSize = Settings.TextSize or VeloESP.Settings.TextSize
end

function ESP:_UpdateHighlighter(Visible, OnScreen)
	local Highlighter = self.UI.Highlighter
	local Settings = self.CurrentSettings
	local Enabled = Visible and OnScreen and VeloESP.Settings.Highlighters == true

	if Highlighter == nil then
		return
	end

	self:_SetHighlighterVisible(Enabled)

	if not Enabled then
		return
	end

	local Type = Settings.ESPType
	local Color = self:_GetColor(Settings.Color)

	if Highlighter:IsA("Highlight") then
		Highlighter.Adornee = Settings.Model
		Highlighter.FillColor = self:_GetColor(Settings.FillColor)
		Highlighter.OutlineColor = self:_GetColor(Settings.OutlineColor)
		Highlighter.FillTransparency = Settings.FillTransparency
		Highlighter.OutlineTransparency = Settings.OutlineTransparency
	elseif Highlighter:IsA("SelectionBox") then
		Highlighter.Adornee = Settings.Model
		Highlighter.Color3 = Color
		Highlighter.LineThickness = Settings.Thickness
		Highlighter.SurfaceColor3 = Settings.SurfaceColor
		Highlighter.SurfaceTransparency = Settings.Transparency
	else
		local Part = GetPart(Settings.Model)
		local _, Size = GetBounds(Settings.Model)
		Highlighter.Adornee = Part
		Highlighter.Color3 = Color
		Highlighter.Transparency = Settings.Transparency

		if Size then
			if Type == "sphereadornment" then
				Highlighter.Radius = math.max(Size.X, Size.Y, Size.Z) * 0.62
			elseif Type == "cylinderadornment" then
				Highlighter.Height = Size.Y
				Highlighter.Radius = math.max(Size.X, Size.Z) * 0.55
			elseif Highlighter:IsA("BoxHandleAdornment") then
				Highlighter.Size = Size
			end
		end
	end
end

function ESP:_UpdateBox2D(Visible, OnScreen)
	local Settings = self.CurrentSettings
	local BoxSettings = Settings.Box2D
	local Box = self.UI.Box
	local BoundsVisible, _, _, MinX, MinY, MaxX, MaxY = GetModelCorners(Settings.Model)
	local Enabled = Visible and OnScreen and BoundsVisible and BoxSettings.Enabled == true and VeloESP.Settings.Boxes2D == true

	if Box == nil then
		return
	end

	Box.Visible = Enabled

	if not Enabled then
		return
	end

	local Thickness = math.max(1, tonumber(BoxSettings.Thickness) or 1)
	local Color = self:_GetColor(BoxSettings.Color)

	Box.Position = UDim2.fromOffset(MinX, MinY)
	Box.Size = UDim2.fromOffset(math.max(1, MaxX - MinX), math.max(1, MaxY - MinY))
	self.UI.BoxFill.BackgroundColor3 = Color
	self.UI.BoxFill.BackgroundTransparency = if BoxSettings.Filled then ClampNumber(BoxSettings.FillTransparency, 0, 1, 0.75) else 1

	local Lines = self.UI.BoxLines
	Lines.Top.Position = UDim2.fromOffset(0, 0)
	Lines.Top.Size = UDim2.new(1, 0, 0, Thickness)
	Lines.Bottom.AnchorPoint = Vector2.new(0, 1)
	Lines.Bottom.Position = UDim2.new(0, 0, 1, 0)
	Lines.Bottom.Size = UDim2.new(1, 0, 0, Thickness)
	Lines.Left.Position = UDim2.fromOffset(0, 0)
	Lines.Left.Size = UDim2.new(0, Thickness, 1, 0)
	Lines.Right.AnchorPoint = Vector2.new(1, 0)
	Lines.Right.Position = UDim2.new(1, 0, 0, 0)
	Lines.Right.Size = UDim2.new(0, Thickness, 1, 0)

	for _, Line in pairs(Lines) do
		Line.Visible = true
		Line.BackgroundColor3 = Color
		Line.BackgroundTransparency = ClampNumber(BoxSettings.Transparency, 0, 1, 0)
	end
end

function ESP:_UpdateBox3D(Visible)
	local Settings = self.CurrentSettings
	local BoxSettings = Settings.Box3D
	local CornerOnScreen, _, ScreenCorners = GetModelCorners(Settings.Model)
	local Enabled = Visible and CornerOnScreen and BoxSettings.Enabled == true and VeloESP.Settings.Boxes3D == true

	for Index, Line in ipairs(self.UI.Box3D) do
		local Pair = Box3DIndices[Index]
		local PointA = Pair and ScreenCorners[Pair[1]]
		local PointB = Pair and ScreenCorners[Pair[2]]
		local ShowLine = Enabled and PointA and PointB and PointA.Z > 0 and PointB.Z > 0

		Line.Visible = ShowLine == true

		if ShowLine then
			Line.BackgroundColor3 = self:_GetColor(BoxSettings.Color)
			Line.BackgroundTransparency = ClampNumber(BoxSettings.Transparency, 0, 1, 0)
			UpdateLine(
				Line,
				Vector2.new(PointA.X, PointA.Y),
				Vector2.new(PointB.X, PointB.Y),
				BoxSettings.Thickness
			)
		end
	end
end

function ESP:_GetTracerOrigin()
	local ActiveCamera = GetCamera()

	if ActiveCamera == nil then
		return Vector2.zero
	end

	local Viewport = ActiveCamera.ViewportSize
	local From = string.lower(tostring(self.CurrentSettings.Tracer.From or "bottom"))

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

function ESP:_UpdateTracer(Visible, OnScreen, ScreenPosition)
	local Tracer = self.UI.Tracer
	local Settings = self.CurrentSettings.Tracer
	local Enabled = Visible and OnScreen and Settings.Enabled == true and VeloESP.Settings.Tracers == true

	if Tracer == nil then
		return
	end

	Tracer.Visible = Enabled

	if not Enabled then
		return
	end

	UpdateLine(
		Tracer,
		self:_GetTracerOrigin(),
		Vector2.new(ScreenPosition.X, ScreenPosition.Y),
		Settings.Thickness
	)

	Tracer.BackgroundColor3 = self:_GetColor(Settings.Color)
	Tracer.BackgroundTransparency = ClampNumber(Settings.Transparency, 0, 1, 0)
end

function ESP:_UpdateArrow(Visible, OnScreen, ScreenPosition)
	local Arrow = self.UI.Arrow
	local Settings = self.CurrentSettings.Arrow
	local Enabled = Visible and not OnScreen and Settings.Enabled == true and VeloESP.Settings.Arrows == true

	if Arrow == nil then
		return
	end

	Arrow.Visible = Enabled

	if not Enabled then
		return
	end

	local ActiveCamera = GetCamera()

	if ActiveCamera == nil then
		return
	end

	local Viewport = ActiveCamera.ViewportSize
	local Center = Vector2.new(Viewport.X / 2, Viewport.Y / 2)
	local Direction = Vector2.new(ScreenPosition.X, ScreenPosition.Y) - Center

	if ScreenPosition.Z < 0 then
		Direction = -Direction
	end

	if Direction.Magnitude < 0.001 then
		Direction = Vector2.new(0, -1)
	else
		Direction = Direction.Unit
	end

	local Radius = math.min(Viewport.X, Viewport.Y) * ((tonumber(Settings.CenterOffset) or 420) / 1000)
	local Position = Center + Direction * Radius
	local Size = tonumber(Settings.Size) or 36

	Arrow.Size = UDim2.fromOffset(Size, Size)
	Arrow.Position = UDim2.fromOffset(Position.X, Position.Y)
	Arrow.Rotation = math.deg(math.atan2(Direction.Y, Direction.X))
	Arrow.TextColor3 = self:_GetColor(Settings.Color)
end

function ESP:_UpdateSkeleton(Visible, OnScreen)
	local Settings = self.CurrentSettings
	local SkeletonSettings = Settings.Skeleton
	local Lines = self.UI.Skeleton
	local Enabled = Visible
		and OnScreen
		and SkeletonSettings.Enabled == true
		and VeloESP.Settings.Skeleton == true
		and typeof(Settings.Model) == "Instance"
		and Settings.Model:IsA("Model")

	if not Enabled then
		for _, Line in ipairs(Lines) do
			Line.Visible = false
		end
		return
	end

	local Humanoid = Settings.Model:FindFirstChildWhichIsA("Humanoid")
	local RigType = if Humanoid and Humanoid.RigType == Enum.HumanoidRigType.R15 then "R15" else "R6"
	local Segments = SkeletonSegments[RigType]

	for Index, Line in ipairs(Lines) do
		local Segment = Segments[Index]

		if Segment == nil then
			Line.Visible = false
			continue
		end

		local First = Settings.Model:FindFirstChild(Segment[1])
		local Second = Settings.Model:FindFirstChild(Segment[2])

		if not (First and Second and First:IsA("BasePart") and Second:IsA("BasePart")) then
			Line.Visible = false
			continue
		end

		local PointA = WorldToViewport(First.Position)
		local PointB = WorldToViewport(Second.Position)
		local ShowLine = PointA.Z > 0 and PointB.Z > 0
		Line.Visible = ShowLine

		if ShowLine then
			Line.BackgroundColor3 = self:_GetColor(SkeletonSettings.Color)
			Line.BackgroundTransparency = ClampNumber(SkeletonSettings.Transparency, 0, 1, 0)
			UpdateLine(
				Line,
				Vector2.new(PointA.X, PointA.Y),
				Vector2.new(PointB.X, PointB.Y),
				SkeletonSettings.Thickness
			)
		end
	end
end

function ESP:_Update()
	if self.Destroyed then
		return
	end

	local Settings = self.CurrentSettings

	if not (Settings.Model and Settings.Model.Parent) then
		self:Destroy()
		return
	end

	if VeloESP.Settings.Enabled ~= true or self.Hidden == true or Settings.Visible == false then
		self:_HideAll()
		return
	end

	local CFrame = GetCFrame(Settings.Model)

	if CFrame == nil then
		self:_HideAll()
		return
	end

	local Distance = GetDistance(Settings.Model)
	local Visible = Distance <= Settings.MaxDistance
	local ScreenPosition, OnScreen = WorldToViewport(CFrame.Position)

	self._LastDistance = Distance
	self._LastScreenPosition = ScreenPosition
	self._OnScreen = OnScreen

	if Settings.BeforeUpdate then
		SafeCall(Settings.BeforeUpdate, self)
	end

	self:_UpdateBillboard(Visible, OnScreen, Distance)
	self:_UpdateHighlighter(Visible, OnScreen)
	self:_UpdateBox2D(Visible, OnScreen)
	self:_UpdateBox3D(Visible)
	self:_UpdateTracer(Visible, OnScreen, ScreenPosition)
	self:_UpdateArrow(Visible, OnScreen, ScreenPosition)
	self:_UpdateSkeleton(Visible, OnScreen)

	if Settings.AfterUpdate then
		SafeCall(Settings.AfterUpdate, self)
	end
end

function ESP:Set(Options)
	assert(typeof(Options) == "table", "Argument #1 must be a table.")

	Merge(self.CurrentSettings, Options)
	self.CurrentSettings = NormalizeOptions(self.Target, self.CurrentSettings)
	self.Options = self.CurrentSettings

	return self
end

function ESP:Show()
	self.Hidden = false
	self.CurrentSettings.Visible = true
	return self
end

function ESP:Hide()
	self.Hidden = true
	self.CurrentSettings.Visible = false
	self:_HideAll()
	return self
end

function ESP:Toggle()
	if self.Hidden or self.CurrentSettings.Visible == false then
		return self:Show()
	end

	return self:Hide()
end

function ESP:ToggleVisibility()
	return self:Toggle()
end

function ESP:SetEveryColor(Color, IncludeComponents)
	self.CurrentSettings.Color = Color
	self.CurrentSettings.FillColor = Color
	self.CurrentSettings.OutlineColor = Color
	self.CurrentSettings.SurfaceColor = Color

	if IncludeComponents == true then
		self.CurrentSettings.Tracer.Color = Color
		self.CurrentSettings.Arrow.Color = Color
		self.CurrentSettings.Box2D.Color = Color
		self.CurrentSettings.Box3D.Color = Color
		self.CurrentSettings.Skeleton.Color = Color
	end

	return self
end

function ESP:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true
	self.Deleted = true

	if self.OriginalSettings.OnDestroy then
		SafeCall(self.OriginalSettings.OnDestroy.Fire, self.OriginalSettings.OnDestroy)
	end

	if self.OriginalSettings.OnDestroyFunc then
		SafeCall(self.OriginalSettings.OnDestroyFunc, self)
	end

	for _, Object in pairs(self.UI) do
		if typeof(Object) == "Instance" then
			Destroy(Object)
		elseif typeof(Object) == "table" then
			for _, Nested in pairs(Object) do
				if typeof(Nested) == "Instance" then
					Destroy(Nested)
				end
			end
		end
	end

	VeloESP._Objects[self.Target] = nil
	table.clear(self.UI)
end

function VeloESP.new(Target, Options)
	assert(VeloESP._Destroyed ~= true, "VeloESP is destroyed, please reload it.")
	assert(typeof(Target) == "Instance", "Argument #1 must be an Instance.")

	if Options ~= nil then
		assert(typeof(Options) == "table", "Argument #2 must be a table.")
	end

	local Existing = VeloESP._Objects[Target]

	if Existing then
		Existing:Destroy()
	end

	local Settings = NormalizeOptions(Target, Options)
	local Object = setmetatable({
		Index = tostring(Target:GetDebugId()) .. "_" .. tostring(math.random(100000, 999999)),
		Target = Target,
		Hidden = false,
		Destroyed = false,
		Deleted = false,
		OriginalSettings = DeepCopy(Settings),
		CurrentSettings = Settings,
		Options = Settings,
		UI = {},
	}, ESP)

	VeloESP._Objects[Target] = Object
	Object:_Create()
	Object:_Update()

	return Object
end

function VeloESP:Add(Settings)
	assert(typeof(Settings) == "table", "Argument #1 must be a table.")
	assert(typeof(Settings.Model) == "Instance", "Settings.Model must be an Instance.")

	return VeloESP.new(Settings.Model, Settings)
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

	for _, Object in pairs(VeloESP._Objects) do
		table.insert(Objects, Object)
	end

	for _, Object in ipairs(Objects) do
		Object:Destroy()
	end
end

function VeloESP.Configure(Options)
	assert(typeof(Options) == "table", "Argument #1 must be a table.")

	Merge(VeloESP.Settings, Options)
	return VeloESP
end

local Watcher = {}
Watcher.__index = Watcher

local function MatchesRule(Rule, Object)
	local Match = Rule.Match

	if typeof(Match) == "string" then
		return Object.Name == Match
	elseif typeof(Match) == "table" then
		if Match[Object.Name] ~= nil then
			return Match[Object.Name] == true
		end

		return table.find(Match, Object.Name) ~= nil
	elseif typeof(Match) == "function" then
		local Success, Result = pcall(Match, Object)
		return Success and Result == true
	end

	return false
end

function Watcher:_BuildOptions(Object)
	local Rule = self.Rule
	local Options = {}

	for Key, Value in pairs(Rule) do
		if Key ~= "Match" and Key ~= "Enabled" and Key ~= "Interval" and Key ~= "Visible" then
			Options[Key] = Resolve(Value, Object, Value)
		end
	end

	Options.Name = Resolve(Rule.Name, Object, Object.Name)
	Options.Model = Object
	return Options
end

function Watcher:_ShouldShow(Object)
	if self.Destroyed or self.Enabled ~= true then
		return false
	end

	if not (Object and Object.Parent) then
		return false
	end

	if not MatchesRule(self.Rule, Object) then
		return false
	end

	if self.Rule.Visible == nil then
		return true
	end

	return Resolve(self.Rule.Visible, Object, false) == true
end

function Watcher:_RemoveObject(Object)
	self.Objects[Object] = nil

	local Handle = self.Handles[Object]
	if Handle then
		Handle:Destroy()
		self.Handles[Object] = nil
	end
end

function Watcher:_UpdateObject(Object)
	if self.Destroyed then
		return
	end

	if not (Object and Object.Parent) then
		self:_RemoveObject(Object)
		return
	end

	if not MatchesRule(self.Rule, Object) then
		self:_RemoveObject(Object)
		return
	end

	self.Objects[Object] = true

	if not self:_ShouldShow(Object) then
		self:_RemoveObject(Object)
		return
	end

	local Options = self:_BuildOptions(Object)
	local Handle = self.Handles[Object]

	if Handle and Handle.Destroyed ~= true then
		Handle:Set(Options)
	else
		self.Handles[Object] = VeloESP.new(Object, Options)
	end
end

function Watcher:_Scan()
	if self.Destroyed then
		return
	end

	if MatchesRule(self.Rule, self.Root) then
		self:_UpdateObject(self.Root)
	end

	for _, Object in ipairs(self.Root:GetDescendants()) do
		if MatchesRule(self.Rule, Object) then
			self:_UpdateObject(Object)
		end
	end
end

function Watcher:_Refresh()
	local Objects = {}

	for Object in pairs(self.Objects) do
		table.insert(Objects, Object)
	end

	for _, Object in ipairs(Objects) do
		self:_UpdateObject(Object)
	end
end

function Watcher:SetEnabled(Value)
	self.Enabled = Value == true

	if self.Enabled then
		self:_Scan()
		self:_Refresh()
	else
		for Object in pairs(self.Handles) do
			self:_RemoveObject(Object)
		end
	end

	return self
end

function Watcher:Enable()
	return self:SetEnabled(true)
end

function Watcher:Disable()
	return self:SetEnabled(false)
end

function Watcher:Toggle()
	return self:SetEnabled(not self.Enabled)
end

function Watcher:Set(Options)
	assert(typeof(Options) == "table", "Argument #1 must be a table.")

	Merge(self.Rule, Options)
	self:_Refresh()
	return self
end

function Watcher:Refresh()
	self:_Scan()
	self:_Refresh()
	return self
end

function Watcher:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true

	for _, Connection in ipairs(self.Connections) do
		if Connection and Connection.Connected then
			Connection:Disconnect()
		end
	end

	for Object in pairs(self.Handles) do
		self:_RemoveObject(Object)
	end

	table.clear(self.Connections)
	table.clear(self.Objects)
	table.clear(self.Handles)
end

function VeloESP.watch(RootObject, Rule)
	assert(VeloESP._Destroyed ~= true, "VeloESP is destroyed, please reload it.")
	assert(typeof(RootObject) == "Instance", "Argument #1 must be an Instance.")
	assert(typeof(Rule) == "table", "Argument #2 must be a table.")
	assert(
		typeof(Rule.Match) == "string" or typeof(Rule.Match) == "table" or typeof(Rule.Match) == "function",
		"Rule.Match must be a string, table, or function."
	)

	local Object = setmetatable({
		Root = RootObject,
		Rule = ShallowCopy(Rule),
		Enabled = Rule.Enabled ~= false,
		Destroyed = false,
		Objects = setmetatable({}, { __mode = "k" }),
		Handles = setmetatable({}, { __mode = "k" }),
		Connections = {},
		Elapsed = 0,
		Interval = tonumber(Rule.Interval) or 0.15,
	}, Watcher)

	table.insert(Object.Connections, RootObject.DescendantAdded:Connect(function(Descendant)
		if MatchesRule(Object.Rule, Descendant) then
			task.defer(function()
				if Object.Destroyed ~= true and Descendant.Parent then
					Object:_UpdateObject(Descendant)
				end
			end)
		end
	end))

	table.insert(Object.Connections, RootObject.DescendantRemoving:Connect(function(Descendant)
		if Object.Objects[Descendant] then
			Object:_RemoveObject(Descendant)
		end
	end))

	table.insert(Object.Connections, RunService.Heartbeat:Connect(function(DeltaTime)
		if Object.Destroyed or Object.Enabled ~= true then
			return
		end

		Object.Elapsed += DeltaTime

		if Object.Elapsed >= Object.Interval then
			Object.Elapsed = 0
			Object:_Refresh()
		end
	end))

	if Object.Enabled then
		Object:_Scan()
	end

	table.insert(VeloESP._Watchers, Object)
	return Object
end

function VeloESP.WatchPlayers(Options)
	local Handles = {}
	local Connections = {}
	local Controller = {
		Enabled = Options == nil or Options.Enabled ~= false,
		Destroyed = false,
	}

	local function RemovePlayer(Player)
		if Handles[Player] then
			Handles[Player]:Destroy()
			Handles[Player] = nil
		end
	end

	local function AddCharacter(Player, Character)
		if Controller.Destroyed or Controller.Enabled ~= true or Player == LocalPlayer then
			return
		end

		RemovePlayer(Player)

		local PlayerOptions = DeepCopy(Options or {})
		PlayerOptions.Enabled = nil
		PlayerOptions.Model = Character
		PlayerOptions.Name = Resolve(PlayerOptions.Name, Player, Player.DisplayName or Player.Name)
		PlayerOptions.Color = Resolve(PlayerOptions.Color, Player, Color3.fromRGB(255, 255, 255))

		Handles[Player] = VeloESP.new(Character, PlayerOptions)
	end

	local function TrackPlayer(Player)
		if Player == LocalPlayer then
			return
		end

		table.insert(Connections, Player.CharacterAdded:Connect(function(Character)
			AddCharacter(Player, Character)
		end))

		if Player.Character then
			AddCharacter(Player, Player.Character)
		end
	end

	for _, Player in ipairs(Players:GetPlayers()) do
		TrackPlayer(Player)
	end

	table.insert(Connections, Players.PlayerAdded:Connect(TrackPlayer))
	table.insert(Connections, Players.PlayerRemoving:Connect(RemovePlayer))

	function Controller:SetEnabled(Value)
		self.Enabled = Value == true

		if self.Enabled then
			for _, Player in ipairs(Players:GetPlayers()) do
				if Player.Character then
					AddCharacter(Player, Player.Character)
				end
			end
		else
			for Player in pairs(Handles) do
				RemovePlayer(Player)
			end
		end

		return self
	end

	function Controller:Destroy()
		if self.Destroyed then
			return
		end

		self.Destroyed = true

		for _, Connection in ipairs(Connections) do
			if Connection and Connection.Connected then
				Connection:Disconnect()
			end
		end

		for Player in pairs(Handles) do
			RemovePlayer(Player)
		end
	end

	return Controller
end

function VeloESP.Destroy()
	if VeloESP._Destroyed then
		return
	end

	for _, Watch in ipairs(VeloESP._Watchers) do
		if Watch and Watch.Destroyed ~= true then
			Watch:Destroy()
		end
	end

	table.clear(VeloESP._Watchers)
	VeloESP.Clear()
	VeloESP._Destroyed = true

	for _, Connection in ipairs(VeloESP._Connections) do
		if Connection and Connection.Connected then
			Connection:Disconnect()
		end
	end

	table.clear(VeloESP._Connections)
	Destroy(Root)
	Destroy(HiddenRoot)

	if Environment.VeloESP == VeloESP then
		Environment.VeloESP = nil
	end
end

table.insert(VeloESP._Connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	Camera = workspace.CurrentCamera
end))

table.insert(VeloESP._Connections, RunService.RenderStepped:Connect(function()
	if VeloESP._Destroyed then
		return
	end

	local Objects = {}

	for _, Object in pairs(VeloESP._Objects) do
		table.insert(Objects, Object)
	end

	for _, Object in ipairs(Objects) do
		Object:_Update()
	end
end))

Environment.VeloESP = VeloESP
return VeloESP
