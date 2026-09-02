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

local PropertyCache = setmetatable({}, { __mode = "k" })

local function Destroy(Object)
	if Object ~= nil then
		PropertyCache[Object] = nil

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

		if Success and Result ~= nil then
			return Result
		end

		return Fallback
	end

	if Value ~= nil then
		return Value
	end

	return Fallback
end

local function ClampNumber(Value, Min, Max, Fallback)
	Value = tonumber(Value)

	if Value == nil then
		return Fallback
	end

	return math.clamp(Value, Min, Max)
end

local function SetProperty(Object, Property, Value)
	if Object == nil then
		return
	end

	local Cache = PropertyCache[Object]

	if Cache == nil then
		Cache = {}
		PropertyCache[Object] = Cache
	end

	if Cache[Property] == Value then
		return
	end

	Cache[Property] = Value
	Object[Property] = Value
end

local function Approach(Current, Target, Step)
	if Current < Target then
		return math.min(Current + Step, Target)
	elseif Current > Target then
		return math.max(Current - Step, Target)
	end

	return Target
end

local function GetSmoothingAlpha(Speed, DeltaTime)
	Speed = tonumber(Speed) or 0
	DeltaTime = math.max(0, tonumber(DeltaTime) or 1 / 60)

	if Speed <= 0 then
		return 1
	end

	return 1 - math.exp(-Speed * DeltaTime)
end

local function SmoothVector2(Current, Target, Speed, DeltaTime)
	if Target == nil then
		return nil
	end

	if Current == nil then
		return Target
	end

	local Alpha = GetSmoothingAlpha(Speed, DeltaTime)

	if Alpha >= 1 then
		return Target
	end

	return Current + ((Target - Current) * Alpha)
end

local function ApplyAlphaTransparency(BaseTransparency, Alpha)
	BaseTransparency = tonumber(BaseTransparency) or 0
	Alpha = tonumber(Alpha) or 1

	if BaseTransparency < 0 then
		BaseTransparency = 0
	elseif BaseTransparency > 1 then
		BaseTransparency = 1
	end

	if Alpha < 0 then
		Alpha = 0
	elseif Alpha > 1 then
		Alpha = 1
	end

	return 1 - ((1 - BaseTransparency) * Alpha)
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
		local Success, Pivot = pcall(function()
			return Target:GetPivot()
		end)

		if Success then
			return Pivot
		end

		return nil
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

	if Part then
		return Part.CFrame
	end

	return nil
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

	if Part then
		return Part.CFrame, Part.Size
	end

	return nil, nil
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

	if ActiveCamera then
		return (CFrame.Position - ActiveCamera.CFrame.Position).Magnitude
	end

	return math.huge
end

local function UpdateLine(Frame, PointA, PointB, Thickness)
	local Delta = PointB - PointA
	local Center = PointA + Delta / 2

	SetProperty(Frame, "AnchorPoint", Vector2.new(0.5, 0.5))
	SetProperty(Frame, "Position", UDim2.fromOffset(Center.X, Center.Y))
	SetProperty(Frame, "Size", UDim2.fromOffset(math.max(1, Delta.Magnitude), math.max(1, Thickness)))
	SetProperty(Frame, "Rotation", math.deg(math.atan2(Delta.Y, Delta.X)))
end

local ModelCornerSigns = {
	{ 1, 1, 1 },
	{ 1, 1, -1 },
	{ 1, -1, 1 },
	{ 1, -1, -1 },
	{ -1, 1, 1 },
	{ -1, 1, -1 },
	{ -1, -1, 1 },
	{ -1, -1, -1 },
}

local function GetModelCorners(Target, ScreenCorners)
	local CFrame, Size = GetBounds(Target)

	if not (CFrame and Size) then
		return false, nil, ScreenCorners or {}, 0, 0, 0, 0
	end

	local ActiveCamera = GetCamera()

	if ActiveCamera == nil then
		return false, nil, ScreenCorners or {}, 0, 0, 0, 0
	end

	ScreenCorners = ScreenCorners or {}

	local OnScreen = false
	local MinX, MinY = math.huge, math.huge
	local MaxX, MaxY = -math.huge, -math.huge
	local X, Y, Z = Size.X / 2, Size.Y / 2, Size.Z / 2

	for Index = 1, 8 do
		local Sign = ModelCornerSigns[Index]
		local ScreenPoint, Visible = ActiveCamera:WorldToViewportPoint(CFrame * Vector3.new(X * Sign[1], Y * Sign[2], Z * Sign[3]))
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
		return false, nil, ScreenCorners, 0, 0, 0, 0
	end

	return OnScreen, nil, ScreenCorners, MinX, MinY, MaxX, MaxY
end

local function GetProjectedVisibility(Target, ScreenCorners, ResolvedCFrame)
	local CFrame = ResolvedCFrame or GetCFrame(Target)

	if CFrame == nil then
		return nil, false, false, ScreenCorners, 0, 0, 0, 0
	end

	local ScreenPosition, OnScreen = WorldToViewport(CFrame.Position)
	local BoundsVisible = OnScreen
	local MinX, MinY, MaxX, MaxY = 0, 0, 0, 0

	local ShouldCheckBounds = not OnScreen and (
		Target:IsA("Model")
		or Target:IsA("BasePart")
		or Target:IsA("Attachment")
	)

	if ShouldCheckBounds then
		local CornerVisible
		CornerVisible, _, ScreenCorners, MinX, MinY, MaxX, MaxY = GetModelCorners(Target, ScreenCorners)
		BoundsVisible = CornerVisible == true
	end

	return CFrame, ScreenPosition, OnScreen, BoundsVisible, ScreenCorners, MinX, MinY, MaxX, MaxY
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
	if CoreGuiAllowed then
		GuiParent = CoreGui
	else
		GuiParent = LocalPlayer:WaitForChild("PlayerGui")
	end

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

local HighlightRegistry = setmetatable({}, { __mode = "k" })
local ActiveHighlightESPs = setmetatable({}, { __mode = "k" })

local function TargetsOverlap(First, Second)
	if typeof(First) ~= "Instance" or typeof(Second) ~= "Instance" then
		return false
	end

	return First == Second or First:IsDescendantOf(Second) or Second:IsDescendantOf(First)
end

local function ApplyHighlightRecord(Record)
	local Highlight = Record.Highlight
	if Highlight == nil or Highlight.Parent == nil then
		return
	end

	local ShouldSuppress = next(Record.Suppressors) ~= nil
	local Wanted = Record.WantedEnabled == true

	Record.InternalChange = true
	if ShouldSuppress then
		if Highlight.Enabled then
			Highlight.Enabled = false
		end
	elseif Highlight.Enabled ~= Wanted then
		Highlight.Enabled = Wanted
	end
	Record.InternalChange = false
end

local function RefreshRegisteredHighlight(Record)
	local Highlight = Record.Highlight
	if Highlight == nil or Highlight.Parent == nil then
		return
	end

	for Object in pairs(Record.Suppressors) do
		if Object._SuppressedHighlights then
			Object._SuppressedHighlights[Highlight] = nil
		end
	end
	table.clear(Record.Suppressors)

	local Adornee = Highlight.Adornee
	if Adornee ~= nil then
		for Object in pairs(ActiveHighlightESPs) do
			if Object.Destroyed ~= true and Object._HighlighterActive == true and TargetsOverlap(Object.CurrentSettings.Model, Adornee) then
				Record.Suppressors[Object] = true
				Object._SuppressedHighlights = Object._SuppressedHighlights or setmetatable({}, { __mode = "k" })
				Object._SuppressedHighlights[Highlight] = true
			end
		end
	end

	ApplyHighlightRecord(Record)
end

local function RegisterExternalHighlight(Highlight)
	if not Highlight:IsA("Highlight") or Highlight:IsDescendantOf(WorldRoot) or HighlightRegistry[Highlight] then
		return
	end

	local Record = {
		Highlight = Highlight,
		WantedEnabled = Highlight.Enabled,
		InternalChange = false,
		Suppressors = setmetatable({}, { __mode = "k" }),
	}
	HighlightRegistry[Highlight] = Record

	Record.EnabledConnection = Highlight:GetPropertyChangedSignal("Enabled"):Connect(function()
		if Record.InternalChange then
			return
		end

		Record.WantedEnabled = Highlight.Enabled
		if next(Record.Suppressors) ~= nil and Highlight.Enabled then
			ApplyHighlightRecord(Record)
		end
	end)

	Record.AdorneeConnection = Highlight:GetPropertyChangedSignal("Adornee"):Connect(function()
		RefreshRegisteredHighlight(Record)
	end)

	RefreshRegisteredHighlight(Record)
end

local function UnregisterExternalHighlight(Highlight)
	local Record = HighlightRegistry[Highlight]
	if Record == nil then
		return
	end

	for Object in pairs(Record.Suppressors) do
		if Object._SuppressedHighlights then
			Object._SuppressedHighlights[Highlight] = nil
		end
	end

	if Record.EnabledConnection then
		Record.EnabledConnection:Disconnect()
	end
	if Record.AdorneeConnection then
		Record.AdorneeConnection:Disconnect()
	end

	HighlightRegistry[Highlight] = nil
end

local function SetHighlightConflictProtection(Object, Active)
	if Active then
		if Object._HighlighterActive == true then
			return
		end

		Object._HighlighterActive = true
		ActiveHighlightESPs[Object] = true
		Object._SuppressedHighlights = Object._SuppressedHighlights or setmetatable({}, { __mode = "k" })

		for Highlight, Record in pairs(HighlightRegistry) do
			if Highlight.Parent and TargetsOverlap(Object.CurrentSettings.Model, Highlight.Adornee) then
				Record.Suppressors[Object] = true
				Object._SuppressedHighlights[Highlight] = true
				ApplyHighlightRecord(Record)
			end
		end
		return
	end

	if Object._HighlighterActive ~= true then
		return
	end

	Object._HighlighterActive = false
	ActiveHighlightESPs[Object] = nil

	for Highlight in pairs(Object._SuppressedHighlights or {}) do
		local Record = HighlightRegistry[Highlight]
		if Record then
			Record.Suppressors[Object] = nil
			ApplyHighlightRecord(Record)
		end
	end

	if Object._SuppressedHighlights then
		table.clear(Object._SuppressedHighlights)
	end
end

local Defaults = {
	Name = nil,
	Model = nil,
	TextModel = nil,
	Visible = true,
	Color = Color3.new(1, 1, 1),
	MaxDistance = 5000,
	Offset = Vector3.zero,
	StudsOffset = nil,
	TextSize = 14,
	Font = nil,
	Text = true,
	Distance = true,
	TextTransparency = 0,
	TextStrokeTransparency = 0,
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
		Smoothness = 0,
	},
	Arrow = {
		Enabled = false,
		Color = Color3.new(1, 1, 1),
		CenterOffset = 420,
		Size = 36,
	},
	EdgeBeacon = {
		Enabled = false,
		Color = Color3.new(1, 1, 1),
		Margin = 28,
		Length = 34,
		Thickness = 2,
		DotSize = 5,
		Pulse = true,
		PulseSpeed = 1.25,
		Label = true,
		Distance = true,
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		Transparency = 0,
		PulseTransparency = 0.72,
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
		UpdateRate = 0.045,
		Smoothness = 16,
	},
	Fade = {
		Enabled = false,
		Speed = 14,
		InSpeed = nil,
		OutSpeed = nil,
		Distance = false,
		Near = 0,
		Far = nil,
		Min = 0,
		Max = 1,
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
	Version = "5.4.0",
	_Destroyed = false,
	_Objects = setmetatable({}, { __mode = "k" }),
	_ObjectList = {},
	_Watchers = {},
	_Connections = {},
	_SmoothObjects = setmetatable({}, { __mode = "k" }),
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
		Arrows = false,
		EdgeBeacons = true,
		Boxes2D = true,
		Boxes3D = true,
		Skeleton = false,
		Font = Enum.Font.Oswald,
		TextSize = 14,
		UpdateRate = 0,
		NearUpdateRate = 0,
		FarUpdateRate = 0.12,
		FarDistance = 650,
		MaxPerFrame = 120,
		FrameBudget = 1 / 300,
		BudgetCheckInterval = 8,
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
	Final.EdgeBeacon = BuildComponentSettings(Final.EdgeBeacon or Final.Arrow, Defaults.EdgeBeacon)
	Final.Box2D = BuildComponentSettings(Final.Box2D or Final.Box, Defaults.Box2D)
	Final.Box3D = BuildComponentSettings(Final.Box3D, Defaults.Box3D)
	Final.Skeleton = BuildComponentSettings(Final.Skeleton, Defaults.Skeleton)
	Final.Fade = BuildComponentSettings(Final.Fade, Defaults.Fade)

	if typeof(Final.Box) == "boolean" then
		Final.Box2D.Enabled = Final.Box
	end

	if typeof(Final.TracerFrom) == "string" then
		Final.Tracer.From = Final.TracerFrom
	end

	local TracerFrom = string.lower(tostring(Final.Tracer.From or "Bottom"))
	if AllowedTracerFrom[TracerFrom] then
		Final.Tracer.From = TracerFrom
	else
		Final.Tracer.From = "bottom"
	end

	local Type = string.lower(tostring(Final.ESPType or "Highlight"))
	if AllowedESPType[Type] then
		Final.ESPType = Type
	else
		Final.ESPType = "highlight"
	end

	Final.MaxDistance = tonumber(Final.MaxDistance) or Defaults.MaxDistance
	Final.Thickness = tonumber(Final.Thickness) or Defaults.Thickness
	Final.Transparency = ClampNumber(Final.Transparency, 0, 1, Defaults.Transparency)
	Final.FillTransparency = ClampNumber(Final.FillTransparency, 0, 1, Defaults.FillTransparency)
	Final.OutlineTransparency = ClampNumber(Final.OutlineTransparency, 0, 1, Defaults.OutlineTransparency)
	Final.TextTransparency = ClampNumber(Final.TextTransparency, 0, 1, Defaults.TextTransparency)
	Final.TextStrokeTransparency = ClampNumber(Final.TextStrokeTransparency, 0, 1, Defaults.TextStrokeTransparency)
	Final.EdgeBeacon.Margin = math.max(0, tonumber(Final.EdgeBeacon.Margin) or Defaults.EdgeBeacon.Margin)
	Final.EdgeBeacon.Length = math.max(8, tonumber(Final.EdgeBeacon.Length) or Defaults.EdgeBeacon.Length)
	Final.EdgeBeacon.Thickness = math.max(1, tonumber(Final.EdgeBeacon.Thickness) or Defaults.EdgeBeacon.Thickness)
	Final.EdgeBeacon.DotSize = math.max(2, tonumber(Final.EdgeBeacon.DotSize) or Defaults.EdgeBeacon.DotSize)
	Final.EdgeBeacon.PulseSpeed = math.max(0, tonumber(Final.EdgeBeacon.PulseSpeed) or Defaults.EdgeBeacon.PulseSpeed)
	Final.EdgeBeacon.TextSize = math.max(8, tonumber(Final.EdgeBeacon.TextSize) or Defaults.EdgeBeacon.TextSize)
	Final.EdgeBeacon.Transparency = ClampNumber(Final.EdgeBeacon.Transparency, 0, 1, Defaults.EdgeBeacon.Transparency)
	Final.EdgeBeacon.PulseTransparency = ClampNumber(Final.EdgeBeacon.PulseTransparency, 0, 1, Defaults.EdgeBeacon.PulseTransparency)
	if typeof(Final.EdgeBeacon.Font) ~= "EnumItem" then
		Final.EdgeBeacon.Font = Defaults.EdgeBeacon.Font
	end
	Final.Tracer.Smoothness = math.max(0, tonumber(Final.Tracer.Smoothness) or Defaults.Tracer.Smoothness)
	Final.Skeleton.UpdateRate = math.max(0, tonumber(Final.Skeleton.UpdateRate) or Defaults.Skeleton.UpdateRate)
	Final.Skeleton.Smoothness = math.max(0, tonumber(Final.Skeleton.Smoothness) or Defaults.Skeleton.Smoothness)
	Final.Fade.Speed = math.max(0, tonumber(Final.Fade.Speed) or Defaults.Fade.Speed)
	Final.Fade.InSpeed = math.max(0, tonumber(Final.Fade.InSpeed) or Final.Fade.Speed)
	Final.Fade.OutSpeed = math.max(0, tonumber(Final.Fade.OutSpeed) or Final.Fade.Speed)
	Final.Fade.Near = math.max(0, tonumber(Final.Fade.Near) or Defaults.Fade.Near)
	Final.Fade.Far = tonumber(Final.Fade.Far) or Final.MaxDistance
	Final.Fade.Min = ClampNumber(Final.Fade.Min, 0, 1, Defaults.Fade.Min)
	Final.Fade.Max = ClampNumber(Final.Fade.Max, 0, 1, Defaults.Fade.Max)

	return Final
end

function ESP:_GetColor(Base)
	if VeloESP.Settings.Rainbow then
		return VeloESP._RainbowColor or Base or self.CurrentSettings.Color
	end

	return Base or self.CurrentSettings.Color
end

function ESP:_GetFadeTarget(Visible, Distance)
	local Fade = self.CurrentSettings.Fade

	if Visible ~= true then
		return 0
	end

	if Fade.Enabled ~= true then
		return 1
	end

	if Fade.Distance == true then
		local Near = Fade.Near
		local Far = math.max(Near + 1, Fade.Far or self.CurrentSettings.MaxDistance)
		local Percent = 1 - math.clamp((Distance - Near) / (Far - Near), 0, 1)

		return math.clamp(Fade.Min + ((Fade.Max - Fade.Min) * Percent), 0, 1)
	end

	return Fade.Max
end

function ESP:_StepFade(TargetAlpha, DeltaTime)
	local Fade = self.CurrentSettings.Fade

	if Fade.Enabled ~= true then
		self._Alpha = TargetAlpha
		return TargetAlpha
	end

	local Speed = Fade.OutSpeed

	if TargetAlpha > self._Alpha then
		Speed = Fade.InSpeed
	end

	self._Alpha = Approach(self._Alpha, TargetAlpha, (DeltaTime or 1 / 60) * Speed)

	return self._Alpha
end

function ESP:_CreateBillboard()
	if self.UI.Billboard and self.UI.Label then
		return
	end

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
	self._TextAdornee = Adornee
end

function ESP:_CreateHighlighter()
	if self.UI.Highlighter then
		return
	end

	local Settings = self.CurrentSettings
	local Type = Settings.ESPType

	if Type == "text" or Settings.Highlight == false then
		return
	end

	local Target = Settings.Model
	local Part = nil
	local Size = nil
	local Highlighter = nil

	if string.find(Type, "adornment") then
		Part = GetPart(Target)
		if Part == nil then
			return
		end

		local _, BoundsSize = GetBounds(Target)
		Size = BoundsSize or Part.Size

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

local function HighlighterMatchesType(Highlighter, Type)
	if Highlighter == nil then
		return false
	end

	if Type == "highlight" then
		return Highlighter:IsA("Highlight")
	elseif Type == "selectionbox" then
		return Highlighter:IsA("SelectionBox")
	elseif Type == "sphereadornment" then
		return Highlighter:IsA("SphereHandleAdornment")
	elseif Type == "cylinderadornment" then
		return Highlighter:IsA("CylinderHandleAdornment")
	elseif string.find(Type, "adornment") then
		return Highlighter:IsA("BoxHandleAdornment")
	end

	return true
end

function ESP:_CreateOverlay()
	self.UI.Tracer = CreateLine(OverlayRoot, "Tracer")

	local EdgeBeacon = New("Frame", {
		Parent = OverlayRoot,
		Name = "EdgeBeacon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(1, 1),
		Visible = false,
	})

	local BeaconPulse = New("Frame", {
		Parent = EdgeBeacon,
		Name = "Pulse",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 0),
		ZIndex = 1,
	})
	New("UICorner", {
		Parent = BeaconPulse,
		CornerRadius = UDim.new(1, 0),
	})
	local BeaconPulseStroke = New("UIStroke", {
		Parent = BeaconPulse,
		Name = "PulseStroke",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = self.CurrentSettings.Color,
		Thickness = 1.5,
		Transparency = 1,
	})

	local BeaconBackdrop = New("Frame", {
		Parent = EdgeBeacon,
		Name = "Backdrop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(10, 13, 18),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 0),
		ZIndex = 2,
	})
	New("UICorner", {
		Parent = BeaconBackdrop,
		CornerRadius = UDim.new(1, 0),
	})
	local BeaconBackdropStroke = New("UIStroke", {
		Parent = BeaconBackdrop,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = self.CurrentSettings.Color,
		Thickness = 1,
		Transparency = 0.5,
	})

	local BeaconIndicator = New("Frame", {
		Parent = EdgeBeacon,
		Name = "Indicator",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 0),
		ZIndex = 3,
	})
	local BeaconChevronTop = New("Frame", {
		Parent = BeaconIndicator,
		Name = "ChevronTop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = self.CurrentSettings.Color,
		BorderSizePixel = 0,
		ZIndex = 3,
	})
	New("UICorner", {
		Parent = BeaconChevronTop,
		CornerRadius = UDim.new(1, 0),
	})
	local BeaconChevronBottom = New("Frame", {
		Parent = BeaconIndicator,
		Name = "ChevronBottom",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = self.CurrentSettings.Color,
		BorderSizePixel = 0,
		ZIndex = 3,
	})
	New("UICorner", {
		Parent = BeaconChevronBottom,
		CornerRadius = UDim.new(1, 0),
	})
	local BeaconDot = New("Frame", {
		Parent = BeaconIndicator,
		Name = "Core",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = self.CurrentSettings.Color,
		BorderSizePixel = 0,
		ZIndex = 3,
	})
	New("UICorner", {
		Parent = BeaconDot,
		CornerRadius = UDim.new(1, 0),
	})

	local BeaconLabelPanel = New("Frame", {
		Parent = EdgeBeacon,
		Name = "LabelPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(10, 13, 18),
		BackgroundTransparency = 0.16,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.fromOffset(132, 26),
		Visible = false,
		ZIndex = 4,
	})
	New("UICorner", {
		Parent = BeaconLabelPanel,
		CornerRadius = UDim.new(0, 7),
	})
	local BeaconLabelStroke = New("UIStroke", {
		Parent = BeaconLabelPanel,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(255, 255, 255),
		Thickness = 1,
		Transparency = 0.84,
	})
	local BeaconAccent = New("Frame", {
		Parent = BeaconLabelPanel,
		Name = "Accent",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = self.CurrentSettings.Color,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 7, 0.5, 0),
		Size = UDim2.fromOffset(3, 12),
		ZIndex = 5,
	})
	New("UICorner", {
		Parent = BeaconAccent,
		CornerRadius = UDim.new(1, 0),
	})

	local BeaconLabel = New("TextLabel", {
		Parent = BeaconLabelPanel,
		Name = "Label",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = self.CurrentSettings.EdgeBeacon.Font,
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -24, 1, 0),
		Text = "",
		TextColor3 = Color3.fromRGB(242, 246, 255),
		TextStrokeTransparency = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
	})

	self.UI.EdgeBeacon = {
		Root = EdgeBeacon,
		Pulse = BeaconPulse,
		PulseStroke = BeaconPulseStroke,
		Backdrop = BeaconBackdrop,
		BackdropStroke = BeaconBackdropStroke,
		Indicator = BeaconIndicator,
		ChevronTop = BeaconChevronTop,
		ChevronBottom = BeaconChevronBottom,
		Dot = BeaconDot,
		LabelPanel = BeaconLabelPanel,
		LabelStroke = BeaconLabelStroke,
		Accent = BeaconAccent,
		Label = BeaconLabel,
	}

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

	local Settings = self.CurrentSettings
	local NeedsOverlay = Settings.Tracer.Enabled == true
		or Settings.EdgeBeacon.Enabled == true
		or Settings.Box2D.Enabled == true
		or Settings.Box3D.Enabled == true
		or Settings.Skeleton.Enabled == true

	if NeedsOverlay then
		self:_CreateOverlay()
	end
end

function ESP:_SetHighlighterVisible(Visible)
	local Highlighter = self.UI.Highlighter

	if Highlighter == nil then
		return
	end

	if Highlighter:IsA("Highlight") then
		SetHighlightConflictProtection(self, Visible == true)
		SetProperty(Highlighter, "Enabled", Visible)
	else
		SetProperty(Highlighter, "Visible", Visible)
	end
end

function ESP:_HideAll()
	if self.UI.Billboard then
		SetProperty(self.UI.Billboard, "Enabled", false)
	end

	self:_SetHighlighterVisible(false)

	if self.UI.Tracer then
		SetProperty(self.UI.Tracer, "Visible", false)
	end

	if self._TracerState then
		self._TracerState.Visible = false
		self._TracerState.TargetTo = nil
		self._TracerState.CurrentFrom = nil
		self._TracerState.CurrentTo = nil
	end

	if self.UI.EdgeBeacon and self.UI.EdgeBeacon.Root then
		SetProperty(self.UI.EdgeBeacon.Root, "Visible", false)
	end

	if self.UI.Box then
		SetProperty(self.UI.Box, "Visible", false)
	end

	for _, Line in pairs(self.UI.Box3D or {}) do
		SetProperty(Line, "Visible", false)
	end

	for _, Line in pairs(self.UI.Skeleton or {}) do
		SetProperty(Line, "Visible", false)
	end

	if self._SkeletonState then
		self._SkeletonState.VisibleCount = 0

		for _, LineState in pairs(self._SkeletonState.Lines or {}) do
			LineState.Visible = false
			LineState.TargetA = nil
			LineState.TargetB = nil
			LineState.CurrentA = nil
			LineState.CurrentB = nil
		end
	end

	self._SkeletonVisible = false
	self:_RefreshSmoothOverlayRegistration()
end

function ESP:_UpdateBillboard(Visible, TargetOnScreen, Distance, Alpha)
	local Settings = self.CurrentSettings
	local Billboard = self.UI.Billboard
	local Label = self.UI.Label
	if (Billboard == nil or Label == nil)
		and Settings.Text == true
		and Settings.Billboard ~= false
		and VeloESP.Settings.Billboards == true
	then
		self:_CreateBillboard()
		Billboard = self.UI.Billboard
		Label = self.UI.Label
	end

	local Enabled = Visible and TargetOnScreen and Alpha > 0.01 and Settings.Text == true and Settings.Billboard ~= false and VeloESP.Settings.Billboards == true

	if Billboard == nil or Label == nil then
		return
	end

	SetProperty(Billboard, "Enabled", Enabled)

	if not Enabled then
		return
	end

	local Name = tostring(Settings.Name or self.Target.Name)
	local Text = Name

	if Settings.Distance == true and VeloESP.Settings.Distance == true then
		Text = string.format('%s\n<font size="11">[%d studs]</font>', Name, math.floor(Distance + 0.5))
	end

	local TextTarget = Settings.TextModel or Settings.Model
	local Adornee = self._TextAdornee
	if Adornee == nil or Adornee.Parent == nil or (Adornee ~= TextTarget and not Adornee:IsDescendantOf(TextTarget)) then
		Adornee = GetPart(TextTarget)
		self._TextAdornee = Adornee
	end
	SetProperty(Billboard, "Adornee", Adornee)
	SetProperty(Billboard, "StudsOffset", Settings.StudsOffset)
	SetProperty(Label, "Text", Text)
	SetProperty(Label, "TextColor3", self:_GetColor(Settings.Color))
	SetProperty(Label, "TextTransparency", ApplyAlphaTransparency(Settings.TextTransparency, Alpha))
	SetProperty(Label, "TextStrokeTransparency", ApplyAlphaTransparency(Settings.TextStrokeTransparency, Alpha))
	SetProperty(Label, "Font", Settings.Font or VeloESP.Settings.Font)
	SetProperty(Label, "TextSize", Settings.TextSize or VeloESP.Settings.TextSize)
end

function ESP:_UpdateHighlighter(Visible, TargetOnScreen, Alpha)
	local Settings = self.CurrentSettings
	local Highlighter = self.UI.Highlighter
	local Type = Settings.ESPType

	if Highlighter and not HighlighterMatchesType(Highlighter, Type) then
		self:_SetHighlighterVisible(false)
		Destroy(Highlighter)
		self.UI.Highlighter = nil
		Highlighter = nil
	end

	if Highlighter == nil
		and Settings.Highlight ~= false
		and Settings.ESPType ~= "text"
		and VeloESP.Settings.Highlighters == true
	then
		self:_CreateHighlighter()
		Highlighter = self.UI.Highlighter
	end

	local Enabled = Visible and TargetOnScreen and Alpha > 0.01 and VeloESP.Settings.Highlighters == true

	if Highlighter == nil then
		return
	end

	self:_SetHighlighterVisible(Enabled)

	if not Enabled then
		return
	end

	local Color = self:_GetColor(Settings.Color)

	if Highlighter:IsA("Highlight") then
		SetProperty(Highlighter, "Adornee", Settings.Model)
		SetProperty(Highlighter, "FillColor", self:_GetColor(Settings.FillColor))
		SetProperty(Highlighter, "OutlineColor", self:_GetColor(Settings.OutlineColor))
		SetProperty(Highlighter, "FillTransparency", ApplyAlphaTransparency(Settings.FillTransparency, Alpha))
		SetProperty(Highlighter, "OutlineTransparency", ApplyAlphaTransparency(Settings.OutlineTransparency, Alpha))
	elseif Highlighter:IsA("SelectionBox") then
		SetProperty(Highlighter, "Adornee", Settings.Model)
		SetProperty(Highlighter, "Color3", Color)
		SetProperty(Highlighter, "LineThickness", Settings.Thickness)
		SetProperty(Highlighter, "SurfaceColor3", Settings.SurfaceColor)
		SetProperty(Highlighter, "SurfaceTransparency", ApplyAlphaTransparency(Settings.Transparency, Alpha))
	else
		local Part = GetPart(Settings.Model)
		local _, Size = GetBounds(Settings.Model)
		SetProperty(Highlighter, "Adornee", Part)
		SetProperty(Highlighter, "Color3", Color)
		SetProperty(Highlighter, "Transparency", ApplyAlphaTransparency(Settings.Transparency, Alpha))

		if Size then
			if Type == "sphereadornment" then
				SetProperty(Highlighter, "Radius", math.max(Size.X, Size.Y, Size.Z) * 0.62)
			elseif Type == "cylinderadornment" then
				SetProperty(Highlighter, "Height", Size.Y)
				SetProperty(Highlighter, "Radius", math.max(Size.X, Size.Z) * 0.55)
			elseif Highlighter:IsA("BoxHandleAdornment") then
				SetProperty(Highlighter, "Size", Size)
			end
		end
	end
end

function ESP:_UpdateBox2D(Visible, TargetOnScreen, Alpha, BoundsVisible, MinX, MinY, MaxX, MaxY)
	local Settings = self.CurrentSettings
	local BoxSettings = Settings.Box2D
	local Box = self.UI.Box
	if Box == nil then
		return
	end

	if BoxSettings.Enabled ~= true or VeloESP.Settings.Boxes2D ~= true then
		if Box.Visible then
			SetProperty(Box, "Visible", false)
		end

		return
	end

	local Enabled = Visible and TargetOnScreen and Alpha > 0.01 and BoundsVisible

	SetProperty(Box, "Visible", Enabled)

	if not Enabled then
		return
	end

	local Thickness = math.max(1, tonumber(BoxSettings.Thickness) or 1)
	local Color = self:_GetColor(BoxSettings.Color)

	SetProperty(Box, "Position", UDim2.fromOffset(MinX, MinY))
	SetProperty(Box, "Size", UDim2.fromOffset(math.max(1, MaxX - MinX), math.max(1, MaxY - MinY)))
	SetProperty(self.UI.BoxFill, "BackgroundColor3", Color)

	if BoxSettings.Filled then
		SetProperty(self.UI.BoxFill, "BackgroundTransparency", ApplyAlphaTransparency(BoxSettings.FillTransparency, Alpha))
	else
		SetProperty(self.UI.BoxFill, "BackgroundTransparency", 1)
	end

	local Lines = self.UI.BoxLines
	SetProperty(Lines.Top, "Position", UDim2.fromOffset(0, 0))
	SetProperty(Lines.Top, "Size", UDim2.new(1, 0, 0, Thickness))
	SetProperty(Lines.Bottom, "AnchorPoint", Vector2.new(0, 1))
	SetProperty(Lines.Bottom, "Position", UDim2.new(0, 0, 1, 0))
	SetProperty(Lines.Bottom, "Size", UDim2.new(1, 0, 0, Thickness))
	SetProperty(Lines.Left, "Position", UDim2.fromOffset(0, 0))
	SetProperty(Lines.Left, "Size", UDim2.new(0, Thickness, 1, 0))
	SetProperty(Lines.Right, "AnchorPoint", Vector2.new(1, 0))
	SetProperty(Lines.Right, "Position", UDim2.new(1, 0, 0, 0))
	SetProperty(Lines.Right, "Size", UDim2.new(0, Thickness, 1, 0))

	for _, Line in pairs(Lines) do
		SetProperty(Line, "Visible", true)
		SetProperty(Line, "BackgroundColor3", Color)
		SetProperty(Line, "BackgroundTransparency", ApplyAlphaTransparency(BoxSettings.Transparency, Alpha))
	end
end

function ESP:_UpdateBox3D(Visible, Alpha, CornerOnScreen, ScreenCorners)
	if self.UI.Box3D == nil then
		return
	end

	local Settings = self.CurrentSettings
	local BoxSettings = Settings.Box3D
	local Enabled = Visible and Alpha > 0.01 and CornerOnScreen and BoxSettings.Enabled == true and VeloESP.Settings.Boxes3D == true

	if not Enabled and self._Box3DVisible ~= true then
		return
	end

	self._Box3DVisible = Enabled

	if not Enabled or ScreenCorners == nil then
		for _, Line in ipairs(self.UI.Box3D or {}) do
			SetProperty(Line, "Visible", false)
		end
		return
	end

	local Color = self:_GetColor(BoxSettings.Color)
	local Transparency = ApplyAlphaTransparency(BoxSettings.Transparency, Alpha)

	for Index, Line in ipairs(self.UI.Box3D or {}) do
		local Pair = Box3DIndices[Index]
		local PointA = Pair and ScreenCorners[Pair[1]]
		local PointB = Pair and ScreenCorners[Pair[2]]
		local ShowLine = Enabled and PointA and PointB and PointA.Z > 0 and PointB.Z > 0

		SetProperty(Line, "Visible", ShowLine == true)

		if ShowLine then
			SetProperty(Line, "BackgroundColor3", Color)
			SetProperty(Line, "BackgroundTransparency", Transparency)
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

function ESP:_RefreshSmoothOverlayRegistration()
	local Active = false
	local TracerState = self._TracerState

	if TracerState and TracerState.Visible == true and (tonumber(TracerState.Smoothness) or 0) > 0 then
		Active = true
	end

	local SkeletonState = self._SkeletonState

	if SkeletonState and (SkeletonState.VisibleCount or 0) > 0 and (tonumber(SkeletonState.Smoothness) or 0) > 0 then
		Active = true
	end

	if Active then
		VeloESP._SmoothObjects[self] = true
	else
		VeloESP._SmoothObjects[self] = nil
	end
end

function ESP:_RenderTracer(DeltaTime)
	local Tracer = self.UI.Tracer
	local State = self._TracerState

	if Tracer == nil or State == nil or State.Visible ~= true or State.TargetTo == nil then
		if Tracer then
			SetProperty(Tracer, "Visible", false)
		end

		return false
	end

	local Model = self.CurrentSettings and self.CurrentSettings.Model

	if typeof(Model) == "Instance" and Model.Parent ~= nil then
		local CFrame = GetCFrame(Model)

		if CFrame ~= nil then
			local ScreenPosition = WorldToViewport(CFrame.Position)

			if ScreenPosition.Z > 0 then
				State.TargetTo = Vector2.new(ScreenPosition.X, ScreenPosition.Y)
			else
				SetProperty(Tracer, "Visible", false)
				return false
			end
		end
	end

	State.CurrentFrom = self:_GetTracerOrigin()
	State.CurrentTo = SmoothVector2(State.CurrentTo, State.TargetTo, State.Smoothness, DeltaTime)

	SetProperty(Tracer, "Visible", true)
	UpdateLine(Tracer, State.CurrentFrom, State.CurrentTo, State.Thickness)
	SetProperty(Tracer, "BackgroundColor3", State.Color)
	SetProperty(Tracer, "BackgroundTransparency", State.Transparency)

	return true
end

function ESP:_RenderSkeleton(DeltaTime)
	local State = self._SkeletonState
	local Lines = self.UI.Skeleton

	if State == nil or Lines == nil then
		return false
	end

	local AnyVisible = false

	for Index, Line in ipairs(Lines) do
		local LineState = State.Lines and State.Lines[Index]
		local ShowLine = LineState ~= nil
			and LineState.Visible == true
			and LineState.TargetA ~= nil
			and LineState.TargetB ~= nil

		SetProperty(Line, "Visible", ShowLine == true)

		if ShowLine then
			LineState.CurrentA = SmoothVector2(LineState.CurrentA, LineState.TargetA, State.Smoothness, DeltaTime)
			LineState.CurrentB = SmoothVector2(LineState.CurrentB, LineState.TargetB, State.Smoothness, DeltaTime)
			SetProperty(Line, "BackgroundColor3", State.Color)
			SetProperty(Line, "BackgroundTransparency", State.Transparency)
			UpdateLine(Line, LineState.CurrentA, LineState.CurrentB, State.Thickness)
			AnyVisible = true
		end
	end

	return AnyVisible
end

function ESP:_PresentOverlays(DeltaTime)
	if self.Destroyed then
		VeloESP._SmoothObjects[self] = nil
		return
	end

	local Active = false
	local TracerState = self._TracerState

	if TracerState and TracerState.Visible == true and (tonumber(TracerState.Smoothness) or 0) > 0 then
		Active = self:_RenderTracer(DeltaTime) or Active
	end

	local SkeletonState = self._SkeletonState

	if SkeletonState and (SkeletonState.VisibleCount or 0) > 0 and (tonumber(SkeletonState.Smoothness) or 0) > 0 then
		Active = self:_RenderSkeleton(DeltaTime) or Active
	end

	if not Active then
		VeloESP._SmoothObjects[self] = nil
	end
end

function ESP:_UpdateTracer(Visible, OnScreen, ScreenPosition, Alpha)
	local Tracer = self.UI.Tracer
	local Settings = self.CurrentSettings.Tracer
	local Enabled = Visible and OnScreen and Alpha > 0.01 and Settings.Enabled == true and VeloESP.Settings.Tracers == true

	if Tracer == nil then
		if self._TracerState then
			self._TracerState.Visible = false
			self._TracerState.TargetTo = nil
		end

		self:_RefreshSmoothOverlayRegistration()
		return
	end

	if not Enabled then
		SetProperty(Tracer, "Visible", false)

		if self._TracerState then
			self._TracerState.Visible = false
			self._TracerState.TargetTo = nil
			self._TracerState.CurrentFrom = nil
			self._TracerState.CurrentTo = nil
		end

		self:_RefreshSmoothOverlayRegistration()
		return
	end

	local State = self._TracerState or {}
	self._TracerState = State
	State.Visible = true
	State.TargetTo = Vector2.new(ScreenPosition.X, ScreenPosition.Y)
	State.Thickness = Settings.Thickness
	State.Color = self:_GetColor(Settings.Color)
	State.Transparency = ApplyAlphaTransparency(Settings.Transparency, Alpha)
	State.Smoothness = Settings.Smoothness

	if State.Smoothness <= 0 then
		State.CurrentFrom = self:_GetTracerOrigin()
		State.CurrentTo = State.TargetTo
		self:_RenderTracer(0)
	end

	self:_RefreshSmoothOverlayRegistration()
end

function ESP:_UpdateEdgeBeacon(Visible, OnScreen, ScreenPosition, Distance, Alpha)
	local Beacon = self.UI.EdgeBeacon
	local Settings = self.CurrentSettings.EdgeBeacon
	local GlobalEnabled = VeloESP.Settings.EdgeBeacons == true or VeloESP.Settings.Arrows == true
	local Enabled = Visible and Alpha > 0.01 and not OnScreen and Settings.Enabled == true and GlobalEnabled

	if Beacon == nil or Beacon.Root == nil then
		return
	end

	SetProperty(Beacon.Root, "Visible", Enabled)

	if not Enabled then
		return
	end

	local ActiveCamera = GetCamera()

	if ActiveCamera == nil then
		SetProperty(Beacon.Root, "Visible", false)
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

	local IconSize = math.clamp(Settings.Length, 28, 42)
	local Margin = Settings.Margin + (IconSize / 2) + 4
	local BoundsX = math.max(8, (Viewport.X / 2) - Margin)
	local BoundsY = math.max(8, (Viewport.Y / 2) - Margin)
	local ScaleX = math.huge
	local ScaleY = math.huge

	if math.abs(Direction.X) > 0.001 then
		ScaleX = BoundsX / math.abs(Direction.X)
	end

	if math.abs(Direction.Y) > 0.001 then
		ScaleY = BoundsY / math.abs(Direction.Y)
	end

	local Position = Center + Direction * math.min(ScaleX, ScaleY)
	local Color = self:_GetColor(Settings.Color)
	local DotSize = math.clamp(Settings.DotSize, 3, 8)
	local Thickness = math.clamp(Settings.Thickness, 1, 4)
	local Transparency = ApplyAlphaTransparency(Settings.Transparency, Alpha)
	local IndicatorInset = IconSize * 0.25
	local IndicatorSize = IconSize - (IndicatorInset * 2)
	local BaseX = IndicatorSize * 0.28
	local TipX = IndicatorSize * 0.72
	local TopY = IndicatorSize * 0.24
	local MiddleY = IndicatorSize * 0.5
	local BottomY = IndicatorSize * 0.76
	local Name = tostring(self.CurrentSettings.Name or self.Target.Name)
	local LabelText = Name
	local ShowDistance = Settings.Distance == true and VeloESP.Settings.Distance == true

	if ShowDistance then
		LabelText = string.format("%s  ·  %d studs", Name, math.floor(Distance + 0.5))
	end

	local LabelHeight = math.max(24, Settings.TextSize + 12)
	local LabelCharacters = utf8.len(LabelText) or #LabelText
	local LabelWidth = math.clamp((LabelCharacters * Settings.TextSize * 0.54) + 34, 92, 188)
	LabelWidth = math.min(LabelWidth, math.max(1, Viewport.X - 16))
	LabelHeight = math.min(LabelHeight, math.max(1, Viewport.Y - 16))
	local LabelGap = (IconSize / 2) + (LabelHeight / 2) + 8
	local DesiredLabelCenter = Position - (Direction * LabelGap)
	local LabelHalfWidth = LabelWidth / 2
	local LabelHalfHeight = LabelHeight / 2
	local SafeInset = 8
	local LabelCenter = Vector2.new(
		math.clamp(DesiredLabelCenter.X, LabelHalfWidth + SafeInset, Viewport.X - LabelHalfWidth - SafeInset),
		math.clamp(DesiredLabelCenter.Y, LabelHalfHeight + SafeInset, Viewport.Y - LabelHalfHeight - SafeInset)
	)
	local LabelOffset = LabelCenter - Position

	SetProperty(Beacon.Root, "Position", UDim2.fromOffset(Position.X, Position.Y))
	SetProperty(Beacon.Backdrop, "Size", UDim2.fromOffset(IconSize, IconSize))
	SetProperty(Beacon.Backdrop, "BackgroundTransparency", ApplyAlphaTransparency(0.12, Alpha))
	SetProperty(Beacon.BackdropStroke, "Color", Color)
	SetProperty(Beacon.BackdropStroke, "Transparency", ApplyAlphaTransparency(0.52, Alpha))

	SetProperty(Beacon.Indicator, "Size", UDim2.fromOffset(IndicatorSize, IndicatorSize))
	SetProperty(Beacon.Indicator, "Rotation", math.deg(math.atan2(Direction.Y, Direction.X)))
	UpdateLine(Beacon.ChevronTop, Vector2.new(BaseX, TopY), Vector2.new(TipX, MiddleY), Thickness)
	UpdateLine(Beacon.ChevronBottom, Vector2.new(TipX, MiddleY), Vector2.new(BaseX, BottomY), Thickness)
	SetProperty(Beacon.ChevronTop, "BackgroundColor3", Color)
	SetProperty(Beacon.ChevronTop, "BackgroundTransparency", Transparency)
	SetProperty(Beacon.ChevronBottom, "BackgroundColor3", Color)
	SetProperty(Beacon.ChevronBottom, "BackgroundTransparency", Transparency)

	SetProperty(Beacon.Dot, "Size", UDim2.fromOffset(DotSize, DotSize))
	SetProperty(Beacon.Dot, "Position", UDim2.fromOffset(BaseX, MiddleY))
	SetProperty(Beacon.Dot, "BackgroundColor3", Color)
	SetProperty(Beacon.Dot, "BackgroundTransparency", math.clamp(Transparency + 0.1, 0, 1))

	if Settings.Pulse == true and Settings.PulseSpeed > 0 then
		local Phase = ((os.clock() * Settings.PulseSpeed) + (self._Seed or 0)) % 1
		local PulseSize = IconSize + 4 + (12 * Phase)
		local PulseBaseTransparency = ApplyAlphaTransparency(Settings.PulseTransparency, Alpha)

		SetProperty(Beacon.Pulse, "Visible", true)
		SetProperty(Beacon.Pulse, "Size", UDim2.fromOffset(PulseSize, PulseSize))
		SetProperty(Beacon.PulseStroke, "Color", Color)
		SetProperty(Beacon.PulseStroke, "Transparency", PulseBaseTransparency + ((1 - PulseBaseTransparency) * Phase))
	else
		SetProperty(Beacon.Pulse, "Visible", false)
	end

	SetProperty(Beacon.LabelPanel, "Visible", Settings.Label == true)
	SetProperty(Beacon.LabelPanel, "Position", UDim2.fromOffset(LabelOffset.X, LabelOffset.Y))
	SetProperty(Beacon.LabelPanel, "Size", UDim2.fromOffset(LabelWidth, LabelHeight))
	SetProperty(Beacon.LabelPanel, "BackgroundTransparency", ApplyAlphaTransparency(0.16, Alpha))
	SetProperty(Beacon.LabelStroke, "Transparency", ApplyAlphaTransparency(0.84, Alpha))
	SetProperty(Beacon.Accent, "BackgroundColor3", Color)
	SetProperty(Beacon.Accent, "BackgroundTransparency", ApplyAlphaTransparency(0.04, Alpha))
	SetProperty(Beacon.Label, "Font", Settings.Font or Enum.Font.GothamMedium)
	SetProperty(Beacon.Label, "TextSize", Settings.TextSize)
	SetProperty(Beacon.Label, "TextTransparency", ApplyAlphaTransparency(0.04, Alpha))

	if Settings.Label == true then
		SetProperty(Beacon.Label, "Text", LabelText)
	end
end

function ESP:_GetSkeletonCache()
	local Model = self.CurrentSettings.Model

	if not (typeof(Model) == "Instance" and Model:IsA("Model")) then
		return nil
	end

	local Humanoid = Model:FindFirstChildWhichIsA("Humanoid")
	local RigType = "R6"

	if Humanoid and Humanoid.RigType == Enum.HumanoidRigType.R15 then
		RigType = "R15"
	end

	local Cache = self._SkeletonCache

	if Cache and Cache.Model == Model and Cache.RigType == RigType then
		return Cache
	end

	local Segments = SkeletonSegments[RigType]
	local Parts = {}

	for Index, Segment in ipairs(Segments) do
		local First = Model:FindFirstChild(Segment[1])
		local Second = Model:FindFirstChild(Segment[2])

		if First and Second and First:IsA("BasePart") and Second:IsA("BasePart") then
			Parts[Index] = { First, Second }
		end
	end

	Cache = {
		Model = Model,
		RigType = RigType,
		Segments = Segments,
		Parts = Parts,
	}
	self._SkeletonCache = Cache

	return Cache
end

function ESP:_UpdateSkeleton(Visible, OnScreen, Alpha, DeltaTime)
	if self.UI.Skeleton == nil then
		if self._SkeletonState then
			self._SkeletonState.VisibleCount = 0
			self:_RefreshSmoothOverlayRegistration()
		end

		return
	end

	local Settings = self.CurrentSettings
	local SkeletonSettings = Settings.Skeleton
	local Lines = self.UI.Skeleton or {}
	local Enabled = Visible
		and OnScreen
		and Alpha > 0.01
		and SkeletonSettings.Enabled == true
		and VeloESP.Settings.Skeleton == true
		and typeof(Settings.Model) == "Instance"
		and Settings.Model:IsA("Model")

	if not Enabled then
		if self._SkeletonVisible ~= true then
			if self._SkeletonState then
				self._SkeletonState.VisibleCount = 0
				self:_RefreshSmoothOverlayRegistration()
			end

			return
		end

		self._SkeletonVisible = false

		for _, Line in ipairs(Lines) do
			SetProperty(Line, "Visible", false)
		end

		local State = self._SkeletonState

		if State then
			State.VisibleCount = 0

			for _, LineState in pairs(State.Lines or {}) do
				LineState.Visible = false
				LineState.TargetA = nil
				LineState.TargetB = nil
				LineState.CurrentA = nil
				LineState.CurrentB = nil
			end
		end

		self:_RefreshSmoothOverlayRegistration()
		return
	end

	self._SkeletonElapsed = (self._SkeletonElapsed or 0) + (DeltaTime or 1 / 60)

	if self._SkeletonVisible == true and SkeletonSettings.UpdateRate > 0 and self._SkeletonElapsed < SkeletonSettings.UpdateRate then
		return
	end

	self._SkeletonElapsed = 0

	local Cache = self:_GetSkeletonCache()

	if Cache == nil then
		self._SkeletonVisible = false

		for _, Line in ipairs(Lines) do
			SetProperty(Line, "Visible", false)
		end

		if self._SkeletonState then
			self._SkeletonState.VisibleCount = 0
		end

		self:_RefreshSmoothOverlayRegistration()
		return
	end

	local State = self._SkeletonState

	if State == nil then
		State = {
			Lines = table.create(#Lines),
			VisibleCount = 0,
		}
		self._SkeletonState = State
	end

	State.Color = self:_GetColor(SkeletonSettings.Color)
	State.Transparency = ApplyAlphaTransparency(SkeletonSettings.Transparency, Alpha)
	State.Thickness = SkeletonSettings.Thickness
	State.Smoothness = SkeletonSettings.Smoothness

	local VisibleCount = 0

	for Index, Line in ipairs(Lines) do
		local Segment = Cache.Segments[Index]
		local LineState = State.Lines[Index]

		if LineState == nil then
			LineState = {}
			State.Lines[Index] = LineState
		end

		if Segment == nil then
			SetProperty(Line, "Visible", false)
			LineState.Visible = false
			LineState.TargetA = nil
			LineState.TargetB = nil
			LineState.CurrentA = nil
			LineState.CurrentB = nil
			continue
		end

		local Parts = Cache.Parts[Index]

		if Parts == nil or Parts[1].Parent == nil or Parts[2].Parent == nil then
			SetProperty(Line, "Visible", false)
			LineState.Visible = false
			LineState.TargetA = nil
			LineState.TargetB = nil
			LineState.CurrentA = nil
			LineState.CurrentB = nil
			continue
		end

		local First = Parts[1]
		local Second = Parts[2]
		local PointA = WorldToViewport(First.Position)
		local PointB = WorldToViewport(Second.Position)
		local ShowLine = PointA.Z > 0 and PointB.Z > 0
		LineState.Visible = ShowLine == true

		if ShowLine then
			VisibleCount += 1
			LineState.TargetA = Vector2.new(PointA.X, PointA.Y)
			LineState.TargetB = Vector2.new(PointB.X, PointB.Y)
		else
			SetProperty(Line, "Visible", false)
			LineState.TargetA = nil
			LineState.TargetB = nil
			LineState.CurrentA = nil
			LineState.CurrentB = nil
		end
	end

	State.VisibleCount = VisibleCount
	self._SkeletonVisible = VisibleCount > 0

	if VisibleCount > 0 and State.Smoothness <= 0 then
		self:_RenderSkeleton(0)
	end

	self:_RefreshSmoothOverlayRegistration()
end

function ESP:_GetUpdateRate(Distance)
	local GlobalRate = tonumber(VeloESP.Settings.UpdateRate) or 0

	if GlobalRate > 0 then
		return GlobalRate
	end

	local FarDistance = tonumber(VeloESP.Settings.FarDistance) or 650

	if Distance and Distance >= FarDistance then
		return tonumber(VeloESP.Settings.FarUpdateRate) or 0
	end

	return tonumber(VeloESP.Settings.NearUpdateRate) or 0
end

function ESP:_Update(DeltaTime)
	if self.Destroyed then
		return
	end

	DeltaTime = DeltaTime or 1 / 60

	local Settings = self.CurrentSettings

	if not (Settings.Model and Settings.Model.Parent) then
		self:Destroy()
		return
	end

	local CFrame = GetCFrame(Settings.Model)
	local ProjectedCFrame, ScreenPosition, OnScreen, BoundsVisible, ScreenCorners, MinX, MinY, MaxX, MaxY = GetProjectedVisibility(Settings.Model, self._ScreenCorners, CFrame)

	if ProjectedCFrame == nil or ScreenPosition == nil then
		self:_HideAll()
		return
	end

	local ActiveCamera = GetCamera()
	local Distance = math.huge

	if ActiveCamera then
		Distance = (ProjectedCFrame.Position - ActiveCamera.CFrame.Position).Magnitude
	end

	self._UpdateElapsed = (self._UpdateElapsed or 0) + DeltaTime

	local BaseVisible = VeloESP.Settings.Enabled == true
		and self.Hidden ~= true
		and Settings.Visible ~= false
		and Distance <= Settings.MaxDistance
	local TargetAlpha = self:_GetFadeTarget(BaseVisible, Distance)
	local UpdateRate = self:_GetUpdateRate(Distance)
	local IsFading = math.abs((self._Alpha or TargetAlpha) - TargetAlpha) > 0.01

	if UpdateRate > 0 and self._UpdateElapsed < UpdateRate and IsFading ~= true then
		return
	end

	self._UpdateElapsed = 0

	local Alpha = self:_StepFade(TargetAlpha, DeltaTime)
	local Visible = Alpha > 0.01

	if Visible ~= true then
		self:_HideAll()
		return
	end

	local NeedsCorners = OnScreen
		and (
			(Settings.Box2D.Enabled == true and VeloESP.Settings.Boxes2D == true)
			or (Settings.Box3D.Enabled == true and VeloESP.Settings.Boxes3D == true)
		)
	local CornerOnScreen = BoundsVisible

	if NeedsCorners then
		CornerOnScreen, _, ScreenCorners, MinX, MinY, MaxX, MaxY = GetModelCorners(Settings.Model, ScreenCorners)
	end

	self._LastDistance = Distance
	self._LastScreenPosition = ScreenPosition
	self._OnScreen = OnScreen
	self._BoundsVisible = BoundsVisible
	self._Alpha = Alpha

	if Settings.BeforeUpdate then
		SafeCall(Settings.BeforeUpdate, self)
	end

	self:_UpdateBillboard(Visible, BoundsVisible, Distance, Alpha)
	self:_UpdateHighlighter(Visible, BoundsVisible, Alpha)
	self:_UpdateBox2D(Visible, BoundsVisible, Alpha, CornerOnScreen, MinX, MinY, MaxX, MaxY)
	self:_UpdateBox3D(Visible, Alpha, CornerOnScreen, ScreenCorners)
	self:_UpdateTracer(Visible, OnScreen, ScreenPosition, Alpha)
	self:_UpdateEdgeBeacon(Visible, BoundsVisible, ScreenPosition, Distance, Alpha)
	self:_UpdateSkeleton(Visible, OnScreen, Alpha, DeltaTime)

	if Settings.AfterUpdate then
		SafeCall(Settings.AfterUpdate, self)
	end
end

function ESP:Set(Options)
	assert(typeof(Options) == "table", "Argument #1 must be a table.")

	Merge(self.CurrentSettings, Options)
	self.CurrentSettings = NormalizeOptions(self.Target, self.CurrentSettings)
	self.Options = self.CurrentSettings
	self._SkeletonCache = nil
	self._TracerState = nil
	self._SkeletonState = nil
	self._TextAdornee = nil
	self._SkeletonVisible = false
	VeloESP._SmoothObjects[self] = nil

	if self.UI.Tracer then
		SetProperty(self.UI.Tracer, "Visible", false)
	end

	for _, Line in pairs(self.UI.Skeleton or {}) do
		SetProperty(Line, "Visible", false)
	end

	local Settings = self.CurrentSettings
	local NeedsOverlay = Settings.Tracer.Enabled == true
		or Settings.EdgeBeacon.Enabled == true
		or Settings.Box2D.Enabled == true
		or Settings.Box3D.Enabled == true
		or Settings.Skeleton.Enabled == true

	if NeedsOverlay and self.UI.Tracer == nil then
		self:_CreateOverlay()
	end

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

	if self.CurrentSettings.Fade.Enabled ~= true then
		self:_HideAll()
	end

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
		self.CurrentSettings.EdgeBeacon.Color = Color
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
	VeloESP._SmoothObjects[self] = nil
	SetHighlightConflictProtection(self, false)

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

	if self._ListIndex then
		local List = VeloESP._ObjectList
		local Last = List[#List]

		List[self._ListIndex] = Last
		List[#List] = nil

		if Last and Last ~= self then
			Last._ListIndex = self._ListIndex
		end

		self._ListIndex = nil
	end

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
	local StartAlpha = 1

	if Settings.Fade.Enabled == true then
		StartAlpha = 0
	end

	local Object = setmetatable({
		Index = Target.Name .. "_" .. tostring(math.random(100000, 999999)),
		Target = Target,
		Hidden = false,
		Destroyed = false,
		Deleted = false,
		_Alpha = StartAlpha,
		_Seed = math.random(),
		_UpdateElapsed = 0,
		_ScreenCorners = table.create(8),
		OriginalSettings = DeepCopy(Settings),
		CurrentSettings = Settings,
		Options = Settings,
		UI = {},
	}, ESP)

	VeloESP._Objects[Target] = Object
	Object._ListIndex = #VeloESP._ObjectList + 1
	VeloESP._ObjectList[Object._ListIndex] = Object

	Object:_Create()
	Object:_Update()

	return Object
end

function VeloESP.Add(SelfOrSettings, MaybeSettings)
	local Settings = MaybeSettings or SelfOrSettings

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

	for Index = #VeloESP._ObjectList, 1, -1 do
		local Object = VeloESP._ObjectList[Index]

		if Object then
			Object:Destroy()
		end
	end

	for _, Object in pairs(VeloESP._Objects) do
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

local GeneratedObserver = {}
GeneratedObserver.__index = GeneratedObserver

function GeneratedObserver:_Matches(Object)
	local Match = self.Options.Match

	if Match == nil then
		return true
	end

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

function GeneratedObserver:_Enqueue(Object, IsScan)
	if self.Destroyed or self.Enabled ~= true then
		return
	end

	if not (Object and Object.Parent) then
		return
	end

	if self.Queued[Object] == true or not self:_Matches(Object) then
		return
	end

	self.Queued[Object] = true

	if IsScan == true then
		self.ScanQueue[#self.ScanQueue + 1] = Object
	else
		self.Queue[#self.Queue + 1] = Object
	end
end

function GeneratedObserver:_ProcessObject(Object)
	if self.Destroyed or self.Enabled ~= true then
		return
	end

	if not (Object and Object.Parent) then
		return
	end

	if not self:_Matches(Object) then
		return
	end

	local Options = self.Options

	if typeof(Options.OnAdded) == "function" then
		SafeCall(Options.OnAdded, Object, self)
	end

	if typeof(Options.BuildOptions) == "function" then
		local ESPOptions = SafeCall(Options.BuildOptions, Object, self)

		if typeof(ESPOptions) == "table" then
			ESPOptions.Model = ESPOptions.Model or ESPOptions.Object or Object
			ESPOptions.Object = nil

			if typeof(ESPOptions.Model) == "Instance" then
				self.Handles[Object] = VeloESP.Add(ESPOptions)
			end
		end
	elseif typeof(Options.ESP) == "table" then
		local ESPOptions = DeepCopy(Options.ESP)
		ESPOptions.Model = ESPOptions.Model or Object
		ESPOptions.Name = Resolve(ESPOptions.Name, Object, ESPOptions.Name or Object.Name)
		ESPOptions.Color = Resolve(ESPOptions.Color, Object, ESPOptions.Color)
		self.Handles[Object] = VeloESP.Add(ESPOptions)
	end
end

function GeneratedObserver:_PopQueue(Queue, HeadKey)
	local Head = self[HeadKey]
	local Object = Queue[Head]

	if Object == nil then
		if Head > 1 then
			table.clear(Queue)
			self[HeadKey] = 1
		end
		return nil
	end

	Queue[Head] = nil
	self[HeadKey] = Head + 1
	return Object
end

function GeneratedObserver:_Flush()
	if self.Destroyed or self.Enabled ~= true then
		return
	end

	local MaxPerStep = math.max(1, tonumber(self.Options.MaxPerStep) or 1)
	local Processed = 0

	while Processed < MaxPerStep do
		local Object = self:_PopQueue(self.Queue, "QueueHead")
		if Object == nil then
			Object = self:_PopQueue(self.ScanQueue, "ScanQueueHead")
		end

		if Object == nil then
			break
		end

		self.Queued[Object] = nil
		self:_ProcessObject(Object)
		Processed += 1
	end
end

function GeneratedObserver:_Scan()
	self.ScanGeneration += 1
	local Generation = self.ScanGeneration

	for Index = self.ScanQueueHead, #self.ScanQueue do
		local Object = self.ScanQueue[Index]
		if Object then
			self.Queued[Object] = nil
		end
	end
	table.clear(self.ScanQueue)
	self.ScanQueueHead = 1

	local ScanBatchSize = math.max(1, tonumber(self.Options.ScanBatchSize) or 200)
	local Root = self.Root

	task.spawn(function()
		if self.Options.IncludeRoot == true then
			self:_Enqueue(Root, true)
		end

		local Descendants = Root:GetDescendants()

		for Index, Object in ipairs(Descendants) do
			if self.Destroyed or self.Enabled ~= true or self.ScanGeneration ~= Generation then
				return
			end

			self:_Enqueue(Object, true)

			if Index % ScanBatchSize == 0 then
				task.wait()
			end
		end
	end)
end

function GeneratedObserver:SetEnabled(Value)
	self.Enabled = Value == true

	if self.Enabled then
		self:_Scan()
	else
		self.ScanGeneration += 1
		table.clear(self.Queue)
		self.QueueHead = 1
		table.clear(self.ScanQueue)
		self.ScanQueueHead = 1
		table.clear(self.Queued)

		for Object, Handle in pairs(self.Handles) do
			if Handle and Handle.Destroyed ~= true then
				Handle:Destroy()
			end

			self.Handles[Object] = nil
		end
	end

	return self
end

function GeneratedObserver:Refresh()
	self:_Scan()
	return self
end

function GeneratedObserver:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true

	for _, Connection in ipairs(self.Connections) do
		if Connection and Connection.Connected then
			Connection:Disconnect()
		end
	end

	for _, Handle in pairs(self.Handles) do
		if Handle and Handle.Destroyed ~= true then
			Handle:Destroy()
		end
	end

	self.ScanGeneration += 1
	table.clear(self.Connections)
	table.clear(self.Queue)
	self.QueueHead = 1
	table.clear(self.ScanQueue)
	self.ScanQueueHead = 1
	table.clear(self.Queued)
	table.clear(self.Handles)
end

function GeneratedObserver:Disconnect()
	self:Destroy()
end

function VeloESP.ObserveGenerated(RootObject, Options)
	assert(VeloESP._Destroyed ~= true, "VeloESP is destroyed, please reload it.")
	assert(typeof(RootObject) == "Instance", "Argument #1 must be an Instance.")
	assert(typeof(Options) == "table", "Argument #2 must be a table.")

	local Object = setmetatable({
		Root = RootObject,
		Options = Options,
		Enabled = Options.Enabled ~= false,
		Destroyed = false,
		Queue = {},
		QueueHead = 1,
		ScanQueue = {},
		ScanQueueHead = 1,
		ScanGeneration = 0,
		Queued = setmetatable({}, { __mode = "k" }),
		Handles = setmetatable({}, { __mode = "k" }),
		Connections = {},
	}, GeneratedObserver)

	table.insert(Object.Connections, RootObject.DescendantAdded:Connect(function(Descendant)
		Object:_Enqueue(Descendant)
	end))

	table.insert(Object.Connections, RootObject.DescendantRemoving:Connect(function(Descendant)
		Object.Queued[Descendant] = nil

		local Handle = Object.Handles[Descendant]

		if Handle and Handle.Destroyed ~= true then
			Handle:Destroy()
		end

		Object.Handles[Descendant] = nil
	end))

	table.insert(Object.Connections, RunService.RenderStepped:Connect(function()
		Object:_Flush()
	end))

	if Object.Enabled then
		Object:_Scan()
	end

	table.insert(VeloESP._Watchers, Object)
	return Object
end

VeloESP.Observe = VeloESP.ObserveGenerated
VeloESP.WatchGenerated = VeloESP.ObserveGenerated

function VeloESP.WatchPlayers(Options)
	local PlayerSettings = DeepCopy(Options or {})
	local Handles = {}
	local Connections = {}
	local Controller = {
		Enabled = PlayerSettings.Enabled ~= false,
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

		local PlayerOptions = DeepCopy(PlayerSettings)
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

	function Controller:Set(NewOptions)
		assert(typeof(NewOptions) == "table", "Argument #1 must be a table.")

		Merge(PlayerSettings, NewOptions)

		for _, Handle in pairs(Handles) do
			if Handle and Handle.Destroyed ~= true then
				Handle:Set(NewOptions)
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

	for Highlight in pairs(HighlightRegistry) do
		UnregisterExternalHighlight(Highlight)
	end

	Destroy(Root)
	Destroy(HiddenRoot)

	if Environment.VeloESP == VeloESP then
		Environment.VeloESP = nil
	end
end

for _, Descendant in ipairs(workspace:GetDescendants()) do
	if Descendant:IsA("Highlight") then
		RegisterExternalHighlight(Descendant)
	end
end

table.insert(VeloESP._Connections, workspace.DescendantAdded:Connect(function(Descendant)
	if Descendant:IsA("Highlight") then
		RegisterExternalHighlight(Descendant)
	end
end))

table.insert(VeloESP._Connections, workspace.DescendantRemoving:Connect(function(Descendant)
	if Descendant:IsA("Highlight") then
		UnregisterExternalHighlight(Descendant)
	end
end))

table.insert(VeloESP._Connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	Camera = workspace.CurrentCamera
end))

table.insert(VeloESP._Connections, RunService.RenderStepped:Connect(function(DeltaTime)
	if VeloESP._Destroyed then
		return
	end

	local ObjectList = VeloESP._ObjectList
	local Count = #ObjectList

	if Count == 0 then
		VeloESP._UpdateCursor = 1
		return
	end

	if VeloESP.Settings.Rainbow then
		VeloESP._RainbowColor = Color3.fromHSV(
			(os.clock() * VeloESP.Settings.RainbowSpeed) % 1,
			VeloESP.Settings.RainbowSaturation,
			VeloESP.Settings.RainbowValue
		)
	end

	local MaxPerFrame = tonumber(VeloESP.Settings.MaxPerFrame) or math.huge
	local FrameBudget = tonumber(VeloESP.Settings.FrameBudget) or 0
	local BudgetCheckInterval = math.max(1, tonumber(VeloESP.Settings.BudgetCheckInterval) or 8)
	local FrameStarted = FrameBudget > 0 and os.clock() or 0
	local BudgetCounter = 0
	local Updated = 0
	local Visited = 0
	local Index = VeloESP._UpdateCursor or 1

	if Index > Count then
		Index = 1
	end

	while Visited < Count do
		local Object = ObjectList[Index]
		Visited += 1

		if Object == nil or Object.Destroyed == true then
			local Last = ObjectList[Count]
			ObjectList[Index] = Last
			ObjectList[Count] = nil
			Count -= 1

			if Last and Last ~= Object then
				Last._ListIndex = Index
			end

			if Count == 0 then
				Index = 1
				break
			elseif Index > Count then
				Index = 1
			end
		else
			Object._ListIndex = Index
			Object:_Update(DeltaTime)
			Updated += 1
			Index += 1

			if Index > Count then
				Index = 1
			end

			if Updated >= MaxPerFrame then
				break
			end

			if FrameBudget > 0 then
				BudgetCounter += 1

				if BudgetCounter >= BudgetCheckInterval then
					BudgetCounter = 0

					if os.clock() - FrameStarted >= FrameBudget then
						break
					end
				end
			end
		end
	end

	VeloESP._UpdateCursor = Index

	for Object in pairs(VeloESP._SmoothObjects) do
		if Object.Destroyed == true then
			VeloESP._SmoothObjects[Object] = nil
		else
			Object:_PresentOverlays(DeltaTime)
		end
	end
end))

Environment.VeloESP = VeloESP
return VeloESP
