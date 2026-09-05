local getgenv = getgenv or function()
	return shared
end

local Environment = getgenv()
local VERSION = "5.6.0"

if Environment.VeloESP and Environment.VeloESP._Destroyed ~= true then
	local Existing = Environment.VeloESP
	if Existing.Version == VERSION then
		return Existing
	end

	
	
	if type(Existing.Destroy) == "function" then
		local Success, Message = pcall(Existing.Destroy)
		assert(Success, "[VeloESP] could not retire the previous renderer: " .. tostring(Message))
	end
end

local cloneref = cloneref or function(Object)
	return Object
end

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local TextService = cloneref(game:GetService("TextService"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))

local DataModel = game
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Util = {}

local WeakKeys = { __mode = "k" }
local Traceback = debug.traceback

function Util.WeakTable()
	return setmetatable({}, WeakKeys)
end

local PropertyCache = Util.WeakTable()

function Util.SafeCall(Callback, ...)
	if typeof(Callback) ~= "function" then
		return nil
	end

	local Ok, A, B, C, D = xpcall(Callback, Traceback, ...)

	if not Ok then
		warn("[VeloESP] callback error:\n" .. tostring(A))
		return nil
	end

	return A, B, C, D
end

function Util.New(ClassName, Properties)
	local Object = Instance.new(ClassName)

	if Properties ~= nil then
		for Property, Value in pairs(Properties) do
			if Property ~= "Parent" then
				Object[Property] = Value
			end
		end

		if Properties.Parent ~= nil then
			Object.Parent = Properties.Parent
		end
	end

	return Object
end

local function DestroyOne(Object)
	Object:Destroy()
end

function Util.Destroy(Object)
	if Object ~= nil then
		PropertyCache[Object] = nil
		pcall(DestroyOne, Object)
	end
end

function Util.ShallowCopy(Source)
	if Source == nil then
		return {}
	end

	return table.clone(Source)
end

function Util.DeepCopy(Source)
	if typeof(Source) ~= "table" then
		return Source
	end

	local Result = table.clone(Source)

	for Key, Value in pairs(Result) do
		if typeof(Value) == "table" then
			Result[Key] = Util.DeepCopy(Value)
		end
	end

	return Result
end

function Util.CloneTemplate(Source, NestedKeys)
	local Result = table.clone(Source)

	for Index = 1, #NestedKeys do
		local Key = NestedKeys[Index]
		local Value = Result[Key]

		if type(Value) == "table" then
			Result[Key] = table.clone(Value)
		end
	end

	return Result
end

function Util.Merge(Target, Source)
	if Source == nil then
		return Target
	end

	for Key, Value in pairs(Source) do
		if typeof(Value) == "table" and typeof(Target[Key]) == "table" then
			Util.Merge(Target[Key], Value)
		else
			Target[Key] = Value
		end
	end

	return Target
end

function Util.Resolve(Value, Object, Fallback)
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

function Util.ClampNumber(Value, Min, Max, Fallback)
	Value = tonumber(Value)

	if Value == nil then
		return Fallback
	end

	return math.clamp(Value, Min, Max)
end

function Util.SetProperty(Object, Property, Value)
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

function Util.ForgetProperties(Object)
	PropertyCache[Object] = nil
end

function Util.Approach(Current, Target, Step)
	if Current < Target then
		return math.min(Current + Step, Target)
	elseif Current > Target then
		return math.max(Current - Step, Target)
	end

	return Target
end

function Util.GetSmoothingAlpha(Speed, DeltaTime)
	Speed = tonumber(Speed) or 0
	DeltaTime = math.max(0, tonumber(DeltaTime) or 1 / 60)

	if Speed <= 0 then
		return 1
	end

	return 1 - math.exp(-Speed * DeltaTime)
end

function Util.SmoothVector2(Current, Target, Speed, DeltaTime)
	if Target == nil then
		return nil
	end

	if Current == nil then
		return Target
	end

	local Alpha = Util.GetSmoothingAlpha(Speed, DeltaTime)

	if Alpha >= 1 then
		return Target
	end

	return Current + ((Target - Current) * Alpha)
end

function Util.ApplyAlphaTransparency(BaseTransparency, Alpha)
	
	
	if Alpha == 1 and type(BaseTransparency) == "number" then
		if BaseTransparency < 0 then
			return 0
		elseif BaseTransparency > 1 then
			return 1
		end

		return BaseTransparency
	end

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

local WeakTable = Util.WeakTable
local SafeCall = Util.SafeCall
local New = Util.New
local Destroy = Util.Destroy
local ShallowCopy = Util.ShallowCopy
local DeepCopy = Util.DeepCopy
local CloneTemplate = Util.CloneTemplate
local Merge = Util.Merge
local Resolve = Util.Resolve
local SetProperty = Util.SetProperty
local Approach = Util.Approach
local SmoothVector2 = Util.SmoothVector2
local ApplyAlphaTransparency = Util.ApplyAlphaTransparency

local Queue = {}
Queue.__index = Queue

function Queue.new()
	return setmetatable({ Items = {}, Head = 1, Tail = 0 }, Queue)
end

function Queue:Push(Item)
	local Tail = self.Tail + 1
	self.Tail = Tail
	self.Items[Tail] = Item
end

function Queue:Pop()
	local Head = self.Head

	if Head > self.Tail then
		self:Clear()
		return nil
	end

	local Items = self.Items
	local Item = Items[Head]
	Items[Head] = nil
	if Head == self.Tail then
		self.Head = 1
		self.Tail = 0
	else
		self.Head = Head + 1
		
		
		if Head >= 1024 and Head >= self.Tail / 2 then
			local Remaining = self.Tail - Head
			table.move(Items, Head + 1, self.Tail, 1)
			for Index = Remaining + 1, self.Tail do
				Items[Index] = nil
			end
			self.Head = 1
			self.Tail = Remaining
		end
	end
	return Item
end

function Queue:IsEmpty()
	return self.Head > self.Tail
end

function Queue:Clear()
	if self.Tail > 0 then
		table.clear(self.Items)
	end

	self.Head = 1
	self.Tail = 0
end

function Queue:ForEach(Callback)
	local Items = self.Items

	for Index = self.Head, self.Tail do
		local Item = Items[Index]

		if Item ~= nil then
			Callback(Item)
		end
	end
end

local Screen = {
	CameraPosition = nil,
	ViewportSize = nil,
	Frame = 0,
}

function Screen.GetCamera()
	if Camera == nil or Camera.Parent == nil then
		Camera = workspace.CurrentCamera
	end

	return Camera
end

function Screen.BeginFrame()
	Screen.Frame += 1
	Screen.CameraPosition = nil
	Screen.ViewportSize = nil
end

function Screen.GetCameraPosition()
	local Position = Screen.CameraPosition

	if Position == nil then
		local ActiveCamera = Screen.GetCamera()

		if ActiveCamera == nil then
			return nil
		end

		Position = ActiveCamera.CFrame.Position
		Screen.CameraPosition = Position
	end

	return Position
end

function Screen.GetViewportSize()
	local Size = Screen.ViewportSize

	if Size == nil then
		local ActiveCamera = Screen.GetCamera()

		if ActiveCamera == nil then
			return nil
		end

		Size = ActiveCamera.ViewportSize
		Screen.ViewportSize = Size
	end

	return Size
end

function Screen.WorldToViewport(Position)
	local ActiveCamera = Screen.GetCamera()

	if ActiveCamera == nil then
		return Vector3.zero, false
	end

	return ActiveCamera:WorldToViewportPoint(Position)
end

local GetCamera = Screen.GetCamera
local GetCameraPosition = Screen.GetCameraPosition
local GetViewportSize = Screen.GetViewportSize
local WorldToViewport = Screen.WorldToViewport

local Kind = {
	Other = 0,
	Part = 1,
	Model = 2,
	Attachment = 3,
	Camera = 4,
}

local KindProbes = {
	{ "BasePart", Kind.Part },
	{ "Model", Kind.Model },
	{ "Attachment", Kind.Attachment },
	{ "Camera", Kind.Camera },
}

local KIND_OTHER = Kind.Other
local KIND_PART = Kind.Part
local KIND_MODEL = Kind.Model
local KIND_ATTACHMENT = Kind.Attachment
local KIND_CAMERA = Kind.Camera

local UnitSize = Vector3.new(1, 1, 1)

local Geometry = {
	KindCache = WeakTable(),
}

function Geometry.GetKind(Target)
	local Cache = Geometry.KindCache
	local Resolved = Cache[Target]

	if Resolved ~= nil then
		return Resolved
	end

	Resolved = KIND_OTHER

	for Index = 1, #KindProbes do
		local Probe = KindProbes[Index]

		if Target:IsA(Probe[1]) then
			Resolved = Probe[2]
			break
		end
	end

	Cache[Target] = Resolved
	return Resolved
end

local GetKind = Geometry.GetKind

function Geometry.GetPart(Target)
	if typeof(Target) ~= "Instance" then
		return nil
	end

	local Resolved = GetKind(Target)

	if Resolved == KIND_PART then
		return Target
	end

	if Resolved == KIND_MODEL then
		return Target.PrimaryPart
			or Target:FindFirstChild("HumanoidRootPart")
			or Target:FindFirstChildWhichIsA("BasePart", true)
	end

	return Target:FindFirstChildWhichIsA("BasePart", true)
end

local GetPart = Geometry.GetPart

function Geometry.GetCFrame(Target)
	if typeof(Target) ~= "Instance" then
		return nil
	end

	local Resolved = GetKind(Target)

	if Resolved == KIND_PART then
		return Target.CFrame
	end

	if Resolved == KIND_MODEL then
		local Success, Pivot = pcall(Target.GetPivot, Target)

		if Success then
			return Pivot
		end

		return nil
	end

	if Resolved == KIND_ATTACHMENT then
		return Target.WorldCFrame
	end

	if Resolved == KIND_CAMERA then
		return Target.CFrame
	end

	local Part = GetPart(Target)

	if Part then
		return Part.CFrame
	end

	return nil
end

local GetCFrame = Geometry.GetCFrame

function Geometry.GetBounds(Target)
	if typeof(Target) ~= "Instance" then
		return nil, nil
	end
	if Geometry.BoundsTarget == Target then
		return Geometry.BoundsCFrame, Geometry.BoundsSize
	end

	local Resolved = GetKind(Target)

	if Resolved == KIND_MODEL then
		local Success, BoundsCFrame, Size = pcall(Target.GetBoundingBox, Target)

		if Success then
			Geometry.BoundsTarget = Target
			Geometry.BoundsCFrame = BoundsCFrame
			Geometry.BoundsSize = Size
			return BoundsCFrame, Size
		end
	end

	if Resolved == KIND_PART then
		return Target.CFrame, Target.Size
	end

	if Resolved == KIND_ATTACHMENT then
		return Target.WorldCFrame, UnitSize
	end

	local Part = GetPart(Target)

	if Part then
		return Part.CFrame, Part.Size
	end

	return nil, nil
end

local GetBounds = Geometry.GetBounds

function Geometry.GetDistance(Target, From)
	local Origin = GetCFrame(Target)

	if Origin == nil then
		return math.huge
	end

	if typeof(From) == "Instance" then
		local FromCFrame = GetCFrame(From)

		if FromCFrame then
			return (Origin.Position - FromCFrame.Position).Magnitude
		end
	elseif typeof(From) == "Vector3" then
		return (Origin.Position - From).Magnitude
	end

	local CameraPosition = GetCameraPosition()

	if CameraPosition then
		return (Origin.Position - CameraPosition).Magnitude
	end

	return math.huge
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

function Geometry.GetModelCorners(Target, ScreenCorners)
	local BoundsCFrame, Size = GetBounds(Target)

	if not (BoundsCFrame and Size) then
		return false, nil, ScreenCorners or {}, 0, 0, 0, 0
	end

	local ActiveCamera = GetCamera()

	if ActiveCamera == nil then
		return false, nil, ScreenCorners or {}, 0, 0, 0, 0
	end

	ScreenCorners = ScreenCorners or table.create(8)

	local OnScreen = false
	local MinX, MinY = math.huge, math.huge
	local MaxX, MaxY = -math.huge, -math.huge
	local X, Y, Z = Size.X / 2, Size.Y / 2, Size.Z / 2

	for Index = 1, 8 do
		local Sign = ModelCornerSigns[Index]
		local ScreenPoint, Visible = ActiveCamera:WorldToViewportPoint(BoundsCFrame * Vector3.new(X * Sign[1], Y * Sign[2], Z * Sign[3]))
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

local GetModelCorners = Geometry.GetModelCorners

function Geometry.GetProjectedVisibility(Target, ScreenCorners, ResolvedCFrame)
	local Origin = ResolvedCFrame or GetCFrame(Target)

	if Origin == nil then
		return nil, false, false, ScreenCorners, 0, 0, 0, 0
	end

	local ScreenPosition, OnScreen = WorldToViewport(Origin.Position)
	local BoundsVisible = OnScreen
	local MinX, MinY, MaxX, MaxY = 0, 0, 0, 0
	local ShouldCheckBounds = false

	if not OnScreen then
		local Resolved = GetKind(Target)
		ShouldCheckBounds = Resolved == KIND_MODEL or Resolved == KIND_PART or Resolved == KIND_ATTACHMENT
	end

	if ShouldCheckBounds then
		local CornerVisible
		CornerVisible, _, ScreenCorners, MinX, MinY, MaxX, MaxY = GetModelCorners(Target, ScreenCorners)
		BoundsVisible = CornerVisible == true
	end

	return Origin, ScreenPosition, OnScreen, BoundsVisible, ScreenCorners, MinX, MinY, MaxX, MaxY
end

local GetProjectedVisibility = Geometry.GetProjectedVisibility

local Draw = {}

function Draw.UpdateLine(Frame, PointA, PointB, Thickness)
	local Delta = PointB - PointA
	local Center = PointA + Delta / 2

	SetProperty(Frame, "AnchorPoint", Vector2.new(0.5, 0.5))
	SetProperty(Frame, "Position", UDim2.fromOffset(Center.X, Center.Y))
	SetProperty(Frame, "Size", UDim2.fromOffset(math.max(1, Delta.Magnitude), math.max(1, Thickness)))
	SetProperty(Frame, "Rotation", math.deg(math.atan2(Delta.Y, Delta.X)))
end

function Draw.CreateLine(Parent, Name)
	return New("Frame", {
		Parent = Parent,
		Name = Name,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Visible = false,
	})
end

local UpdateLine = Draw.UpdateLine
local CreateLine = Draw.CreateLine

local function BuildComponentSettings(Value, Template, PreMerged)
	if typeof(Value) == "table" then
		if Value == PreMerged then
			return Value
		end

		return Merge(table.clone(Template), Value)
	end

	local Result = table.clone(Template)

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

Draw.Path2DSupported = false
Draw.TracerPoints = WeakTable()

Draw.TracerIsPath = WeakTable()

do
	local Success = pcall(function()
		local Probe = Instance.new("Path2D")
		Probe.Parent = Root
		Probe.Closed = false
		Probe.Color3 = Color3.new(1, 1, 1)
		Probe.Thickness = 2
		Probe.Visible = false
		Probe:SetControlPoints({
			Path2DControlPoint.new(UDim2.fromOffset(0, 0)),
			Path2DControlPoint.new(UDim2.fromOffset(1, 1)),
		})
		Probe:Destroy()
	end)

	Draw.Path2DSupported = Success == true
end

local TracerPointCache = Draw.TracerPoints
local TracerIsPath = Draw.TracerIsPath

function Draw.CreateTracerLine(Parent, Name)
	if Draw.Path2DSupported then
		local Success, Path = pcall(function()
			return New("Path2D", {
				Parent = Root,
				Name = Name,
				Closed = false,
				Color3 = Color3.new(1, 1, 1),
				Thickness = 2,
				ZIndex = 2,
				Visible = false,
			})
		end)

		if Success and Path then
			TracerIsPath[Path] = true
			return Path
		end

		Draw.Path2DSupported = false
	end

	return CreateLine(Parent, Name)
end

function Draw.UpdateTracerLine(Line, PointA, PointB, Thickness, Color, Transparency)
	if Line == nil then
		return nil
	end

	if TracerIsPath[Line] then
		local Cache = TracerPointCache[Line]

		if Cache == nil then
			Cache = {}
			TracerPointCache[Line] = Cache
		end

		if Cache.AX ~= PointA.X or Cache.AY ~= PointA.Y or Cache.BX ~= PointB.X or Cache.BY ~= PointB.Y then
			
			
			
			local Points = Cache.Points

			if Points == nil then
				Points = table.create(2)
				Cache.Points = Points
			end

			Points[1] = Path2DControlPoint.new(UDim2.fromOffset(PointA.X, PointA.Y))
			Points[2] = Path2DControlPoint.new(UDim2.fromOffset(PointB.X, PointB.Y))

			local Success = pcall(Line.SetControlPoints, Line, Points)

			if not Success then
				Draw.Path2DSupported = false
				TracerPointCache[Line] = nil
				TracerIsPath[Line] = nil

				local Parent = Line.Parent
				Destroy(Line)

				local Replacement = CreateLine(Parent or Root, "Tracer")
				UpdateLine(Replacement, PointA, PointB, Thickness)
				SetProperty(Replacement, "BackgroundColor3", Color)
				SetProperty(Replacement, "BackgroundTransparency", Transparency)
				SetProperty(Replacement, "Visible", true)

				return Replacement
			end

			Cache.AX, Cache.AY, Cache.BX, Cache.BY = PointA.X, PointA.Y, PointB.X, PointB.Y
		end

		SetProperty(Line, "Thickness", math.max(1, Thickness))
		SetProperty(Line, "Color3", Color)
		pcall(SetProperty, Line, "Transparency", Transparency)

		return Line
	end

	UpdateLine(Line, PointA, PointB, Thickness)
	SetProperty(Line, "BackgroundColor3", Color)
	SetProperty(Line, "BackgroundTransparency", Transparency)

	return Line
end

local CreateTracerLine = Draw.CreateTracerLine
local UpdateTracerLine = Draw.UpdateTracerLine

local Text = {
	Bounds = Vector2.new(4096, 4096),
	Cache = {},
	Count = 0,
	Limit = 512,
	Entries = {},
	Cursor = 1,
}

function Text.Measure(Value, TextSize, Font)
	local Cache = Text.Cache
	local FontBucket = Cache[Font]

	if FontBucket == nil then
		FontBucket = {}
		Cache[Font] = FontBucket
	end

	local SizeBucket = FontBucket[TextSize]

	if SizeBucket == nil then
		SizeBucket = {}
		FontBucket[TextSize] = SizeBucket
	end

	local Cached = SizeBucket[Value]

	if Cached ~= nil then
		return Cached
	end

	local Success, Result = pcall(TextService.GetTextSize, TextService, Value, TextSize, Font, Text.Bounds)

	if not (Success and typeof(Result) == "Vector2") then
		local Characters = utf8.len(Value) or #Value
		Result = Vector2.new(Characters * TextSize * 0.54, TextSize)
	end

	
	
	local Slot = Text.Cursor
	local Entry = Text.Entries[Slot]
	if Entry then
		local OldBucket = Entry.Bucket
		OldBucket[Entry.Value] = nil
		if OldBucket ~= SizeBucket and next(OldBucket) == nil then
			local OldFontBucket = Cache[Entry.Font]
			OldFontBucket[Entry.Size] = nil
			if next(OldFontBucket) == nil then
				Cache[Entry.Font] = nil
			end
		end
	else
		Entry = {}
		Text.Entries[Slot] = Entry
		Text.Count += 1
	end
	Entry.Bucket = SizeBucket
	Entry.Value = Value
	Entry.Font = Font
	Entry.Size = TextSize
	Text.Cursor = Slot % Text.Limit + 1
	SizeBucket[Value] = Result

	return Result
end

local MeasureText = Text.Measure

local Conflict = {
	Index = {
		Registry = WeakTable(),
		Active = WeakTable(),
		HighlightsByAdornee = WeakTable(),
		HighlightsUnderNode = WeakTable(),
		ActiveByTarget = WeakTable(),
		ActiveUnderNode = WeakTable(),
	},
	
	Scratch = {
		Ancestors = table.create(32),
		Seen = WeakTable(),
		Visit = table.create(64),
	},
}

local ConflictIndex = Conflict.Index
local ConflictScratch = Conflict.Scratch
local HighlightRegistry = ConflictIndex.Registry
local AncestorScratch = ConflictScratch.Ancestors
local SeenScratch = ConflictScratch.Seen
local VisitScratch = ConflictScratch.Visit

local function AddIndexed(Index, Key, Value)
	local Bucket = Index[Key]

	if Bucket == nil then
		Bucket = setmetatable({}, WeakKeys)
		Index[Key] = Bucket
	end

	Bucket[Value] = true
end

local function RemoveIndexed(Index, Key, Value)
	local Bucket = Index[Key]

	if Bucket == nil then
		return
	end

	Bucket[Value] = nil

	if next(Bucket) == nil then
		Index[Key] = nil
	end
end

local function CollectAncestors(Object)
	local Count = 0
	local Current = Object

	while typeof(Current) == "Instance" do
		Count += 1
		AncestorScratch[Count] = Current

		if Current == workspace then
			break
		end

		Current = Current.Parent
	end
	for Index = Count + 1, #AncestorScratch do
		AncestorScratch[Index] = nil
	end

	return Count
end

local HighlightSide = {
	ExactIndex = ConflictIndex.HighlightsByAdornee,
	NodeIndex = ConflictIndex.HighlightsUnderNode,
	KeyField = "IndexedAdornee",
	NodesField = "IndexNodes",
}

local ActiveSide = {
	ExactIndex = ConflictIndex.ActiveByTarget,
	NodeIndex = ConflictIndex.ActiveUnderNode,
	KeyField = "_IndexedHighlightTarget",
	NodesField = "_HighlightIndexNodes",
}

local function Unindex(Side, Holder)
	local Key = Holder[Side.KeyField]

	if typeof(Key) ~= "Instance" then
		return
	end

	RemoveIndexed(Side.ExactIndex, Key, Holder)

	local Nodes = Holder[Side.NodesField]

	if Nodes ~= nil then
		local NodeIndex = Side.NodeIndex

		for Index = 1, #Nodes do
			RemoveIndexed(NodeIndex, Nodes[Index], Holder)
		end

		table.clear(Nodes)
	end

	Holder[Side.KeyField] = nil
end

local function Reindex(Side, Holder, Key)
	Unindex(Side, Holder)

	if typeof(Key) ~= "Instance" then
		return
	end

	Holder[Side.KeyField] = Key

	local Nodes = Holder[Side.NodesField]

	if Nodes == nil then
		Nodes = {}
		Holder[Side.NodesField] = Nodes
	end

	AddIndexed(Side.ExactIndex, Key, Holder)

	local Count = CollectAncestors(Key)
	local NodeIndex = Side.NodeIndex

	for Index = 1, Count do
		local Node = AncestorScratch[Index]
		Nodes[Index] = Node
		AddIndexed(NodeIndex, Node, Holder)
	end
end

local function GatherOverlapping(ExactIndex, NodeIndex, Anchor)
	if typeof(Anchor) ~= "Instance" then
		return 0
	end

	local Count = 0
	table.clear(SeenScratch)

	local Under = NodeIndex[Anchor]

	if Under then
		for Holder in pairs(Under) do
			if not SeenScratch[Holder] then
				SeenScratch[Holder] = true
				Count += 1
				VisitScratch[Count] = Holder
			end
		end
	end

	local Depth = CollectAncestors(Anchor)

	for Index = 1, Depth do
		local Bucket = ExactIndex[AncestorScratch[Index]]

		if Bucket then
			for Holder in pairs(Bucket) do
				if not SeenScratch[Holder] then
					SeenScratch[Holder] = true
					Count += 1
					VisitScratch[Count] = Holder
				end
			end
		end
	end

	return Count
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

local function AddSuppressor(Record, Object)
	if not Record or not Object or Object.Destroyed == true or Object._HighlighterActive ~= true then
		return
	end

	local Highlight = Record.Highlight

	if not Highlight or not Highlight.Parent then
		return
	end

	Record.Suppressors[Object] = true

	local Suppressed = Object._SuppressedHighlights

	if Suppressed == nil then
		Suppressed = WeakTable()
		Object._SuppressedHighlights = Suppressed
	end

	Suppressed[Highlight] = true
end

local function RefreshRegisteredHighlight(Record)
	local Highlight = Record.Highlight

	if Highlight == nil or Highlight.Parent == nil then
		return
	end

	for Object in pairs(Record.Suppressors) do
		local Suppressed = Object._SuppressedHighlights

		if Suppressed then
			Suppressed[Highlight] = nil
		end
	end

	table.clear(Record.Suppressors)

	local Adornee = Highlight.Adornee
	Reindex(HighlightSide, Record, Adornee)

	if Adornee ~= nil then
		local Count = GatherOverlapping(ConflictIndex.ActiveByTarget, ConflictIndex.ActiveUnderNode, Adornee)

		for Index = 1, Count do
			local Object = VisitScratch[Index]
			VisitScratch[Index] = nil
			AddSuppressor(Record, Object)
		end
	end

	ApplyHighlightRecord(Record)
end

function Conflict.Register(Highlight)
	if HighlightRegistry[Highlight] ~= nil or Highlight:IsDescendantOf(WorldRoot) then
		return
	end

	local Record = {
		Highlight = Highlight,
		WantedEnabled = Highlight.Enabled,
		InternalChange = false,
		Suppressors = WeakTable(),
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

function Conflict.Unregister(Highlight)
	local Record = HighlightRegistry[Highlight]

	if Record == nil then
		return
	end

	Unindex(HighlightSide, Record)

	for Object in pairs(Record.Suppressors) do
		local Suppressed = Object._SuppressedHighlights

		if Suppressed then
			Suppressed[Highlight] = nil
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

function Conflict.SetActive(Object, Active)
	if Active then
		if Object._HighlighterActive == true then
			return
		end

		Object._HighlighterActive = true
		ConflictIndex.Active[Object] = true

		if Object._SuppressedHighlights == nil then
			Object._SuppressedHighlights = WeakTable()
		end

		local Target = Object.CurrentSettings and Object.CurrentSettings.Model
		Reindex(ActiveSide, Object, Target)

		local Count = GatherOverlapping(ConflictIndex.HighlightsByAdornee, ConflictIndex.HighlightsUnderNode, Target)

		for Index = 1, Count do
			local Record = VisitScratch[Index]
			VisitScratch[Index] = nil
			AddSuppressor(Record, Object)
			ApplyHighlightRecord(Record)
		end

		return
	end

	if Object._HighlighterActive ~= true then
		return
	end

	Object._HighlighterActive = false
	ConflictIndex.Active[Object] = nil
	Unindex(ActiveSide, Object)

	local Suppressed = Object._SuppressedHighlights

	if Suppressed ~= nil then
		for Highlight in pairs(Suppressed) do
			local Record = HighlightRegistry[Highlight]

			if Record then
				Record.Suppressors[Object] = nil
				ApplyHighlightRecord(Record)
			end
		end

		table.clear(Suppressed)
	end
end

local RegisterExternalHighlight = Conflict.Register
local UnregisterExternalHighlight = Conflict.Unregister
local SetHighlightConflictProtection = Conflict.SetActive

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
		Length = 38,
		Thickness = 2,
		DotSize = 5,
		Pulse = false,
		PulseSpeed = 1.25,
		Label = true,
		Distance = true,
		TextSize = 13,
		Font = Enum.Font.Oswald,
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

local HighlightClass = {
	None = 0,
	Fill = 1,
	Selection = 2,
	Box = 3,
	Sphere = 4,
	Cylinder = 5,
}

local HIGHLIGHT_CLASS_NONE = HighlightClass.None
local HIGHLIGHT_CLASS_FILL = HighlightClass.Fill
local HIGHLIGHT_CLASS_SELECTION = HighlightClass.Selection
local HIGHLIGHT_CLASS_BOX = HighlightClass.Box
local HIGHLIGHT_CLASS_SPHERE = HighlightClass.Sphere
local HIGHLIGHT_CLASS_CYLINDER = HighlightClass.Cylinder

local ESPTypes = {
	text = { Class = HIGHLIGHT_CLASS_NONE },
	highlight = { Class = HIGHLIGHT_CLASS_FILL, ClassName = "Highlight" },
	selectionbox = { Class = HIGHLIGHT_CLASS_SELECTION, ClassName = "SelectionBox" },
	adornment = { Class = HIGHLIGHT_CLASS_BOX, ClassName = "BoxHandleAdornment", NeedsPart = true },
	boxadornment = { Class = HIGHLIGHT_CLASS_BOX, ClassName = "BoxHandleAdornment", NeedsPart = true },
	sphereadornment = { Class = HIGHLIGHT_CLASS_SPHERE, ClassName = "SphereHandleAdornment", NeedsPart = true },
	cylinderadornment = { Class = HIGHLIGHT_CLASS_CYLINDER, ClassName = "CylinderHandleAdornment", NeedsPart = true },
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
	Version = VERSION,
	_Destroyed = false,
	_Objects = WeakTable(),
	_ObjectList = {},
	_UpdateList = {},
	_Watchers = {},
	_Connections = {},
	_SmoothObjects = WeakTable(),
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
		
		
		HighlightScanPerFrame = 24,
		ReapPerFrame = 8,
		ReapSweepFrames = 60,
		
		
		
		HighlightConflictProtection = true,
	},
	_AnyOverlay = true,
	_AnyRateLimit = true,
	_ReapCursor = 1,
	_Elapsed = 0,
}

VeloESP.GlobalConfig = VeloESP.Settings

local function AddUpdateObject(Object)
	if Object._UpdateListIndex then return end
	local List = VeloESP._UpdateList
	local Index = #List + 1
	List[Index] = Object
	Object._UpdateListIndex = Index
	Object._LastUpdateTime = VeloESP._Elapsed
	Object._UpdateElapsed = 0
	Object._LastDistance = nil
end

local function RemoveUpdateObject(Object)
	local Index = Object._UpdateListIndex
	if not Index then return end

	local List = VeloESP._UpdateList
	local LastIndex = #List
	local Last = List[LastIndex]

	List[Index] = Last
	List[LastIndex] = nil

	if Last and Last ~= Object then
		Last._UpdateListIndex = Index
	end

	Object._UpdateListIndex = nil

	local Cursor = VeloESP._UpdateCursor or 1
	if Cursor > #List then
		VeloESP._UpdateCursor = 1
	elseif Index < Cursor then
		VeloESP._UpdateCursor = math.max(1, Cursor - 1)
	end
end

local function RegisterWatcher(Object)
	local List = VeloESP._Watchers
	Object._WatcherIndex = #List + 1
	List[Object._WatcherIndex] = Object
end

local function RemoveWatcher(Object)
	local Index = Object._WatcherIndex
	if Index == nil then
		return
	end
	local List = VeloESP._Watchers
	local LastIndex = #List
	local Last = List[LastIndex]
	List[Index] = Last
	List[LastIndex] = nil
	if Last ~= nil and Last ~= Object then
		Last._WatcherIndex = Index
	end
	Object._WatcherIndex = nil
end

local Pool = {
	Limit = 64,
	Kinds = {},
}

local function DefinePool(Name, Quiet, IsUsable)
	local Kind = {
		Name = Name,
		Items = {},
		Count = 0,
		
		Free = {},
		FreeCount = 0,
		Quiet = Quiet,
		IsUsable = IsUsable,
	}

	Pool.Kinds[Name] = Kind
	return Kind
end

local function TakeEntry(Kind)
	local Count = Kind.FreeCount

	if Count > 0 then
		local Entry = Kind.Free[Count]
		Kind.Free[Count] = nil
		Kind.FreeCount = Count - 1
		return Entry
	end

	return {}
end

local function GiveBackEntry(Kind, Entry)
	Entry.Instance = nil
	Entry.Label = nil

	local Count = Kind.FreeCount + 1
	Kind.FreeCount = Count
	Kind.Free[Count] = Entry
end

local HighlightPool = DefinePool("Highlight", function(Entry)
	local Highlight = Entry.Instance
	Highlight.Enabled = false
	Highlight.Adornee = nil
	Highlight.Parent = HiddenRoot
end, function(Entry)
	return Entry.Instance.Parent ~= nil
end)

local BillboardPool = DefinePool("Billboard", function(Entry)
	local Gui = Entry.Instance
	Gui.Enabled = false
	Gui.Adornee = nil
	Gui.Parent = HiddenRoot
end, function(Entry)
	return Entry.Instance.Parent ~= nil and Entry.Label.Parent == Entry.Instance
end)

function Pool.Acquire(Kind)
	while Kind.Count > 0 do
		local Count = Kind.Count
		local Entry = Kind.Items[Count]
		Kind.Items[Count] = nil
		Kind.Count = Count - 1

		
		
		if Kind.IsUsable(Entry) then
			return Entry
		end
		Destroy(Entry.Instance)
		GiveBackEntry(Kind, Entry)
	end
	return nil
end

function Pool.Release(Kind, Entry)
	if Entry == nil or Entry.Instance == nil then
		return false
	end

	if Kind.Count >= Pool.Limit then
		Destroy(Entry.Instance)
		GiveBackEntry(Kind, Entry)
		return true
	end

	if not pcall(Kind.Quiet, Entry) then
		Destroy(Entry.Instance)
		GiveBackEntry(Kind, Entry)
		return true
	end

	
	
	Util.ForgetProperties(Entry.Instance)

	if Entry.Label ~= nil then
		Util.ForgetProperties(Entry.Label)
	end

	local Count = Kind.Count + 1
	Kind.Count = Count
	Kind.Items[Count] = Entry
	return true
end

function Pool.AcquireHighlight()
	local Entry = Pool.Acquire(HighlightPool)

	if Entry == nil then
		return nil
	end

	local Highlight = Entry.Instance
	GiveBackEntry(HighlightPool, Entry)
	return Highlight
end

function Pool.ReleaseHighlight(Highlight)
	if Highlight == nil then
		return
	end

	local Entry = TakeEntry(HighlightPool)
	Entry.Instance = Highlight
	Pool.Release(HighlightPool, Entry)
end

function Pool.AcquireBillboard()
	local Entry = Pool.Acquire(BillboardPool)

	if Entry == nil then
		return nil, nil
	end

	local Gui, Label = Entry.Instance, Entry.Label
	GiveBackEntry(BillboardPool, Entry)
	return Gui, Label
end

function Pool.ReleaseBillboard(Gui, Label)
	if Gui == nil or Label == nil then
		Destroy(Gui)
		Destroy(Label)
		return
	end

	local Entry = TakeEntry(BillboardPool)
	Entry.Instance = Gui
	Entry.Label = Label
	Pool.Release(BillboardPool, Entry)
end

local AcquireHighlight = Pool.AcquireHighlight
local ReleaseHighlight = Pool.ReleaseHighlight
local AcquireBillboard = Pool.AcquireBillboard
local ReleaseBillboard = Pool.ReleaseBillboard

local ESP = {}
ESP.__index = ESP

function ESP:_BindModelWatch()
	local Model = self.CurrentSettings and self.CurrentSettings.Model

	if self._WatchedModel == Model then
		return
	end

	local Existing = self._ModelWatch

	if Existing then
		Existing:Disconnect()
		self._ModelWatch = nil
	end

	self._WatchedModel = Model

	if typeof(Model) ~= "Instance" then
		return
	end

	local Ok, Connection = pcall(function()
		return Model.Destroying:Connect(function()
			self:Destroy()
		end)
	end)

	if Ok then
		self._ModelWatch = Connection
	end
end

local ComponentSpecs = {
	{ Key = "Tracer" },
	{ Key = "Arrow" },
	{ Key = "EdgeBeacon", Alias = "Arrow" },
	{ Key = "Box2D", Alias = "Box" },
	{ Key = "Box3D" },
	{ Key = "Skeleton" },
	{ Key = "Fade" },
}

local ComponentKeys = table.create(#ComponentSpecs)

for Index = 1, #ComponentSpecs do
	ComponentKeys[Index] = ComponentSpecs[Index].Key
end

local NumberRules = {
	{ Field = "MaxDistance" },
	{ Field = "Thickness" },
	{ Field = "Transparency", Min = 0, Max = 1 },
	{ Field = "FillTransparency", Min = 0, Max = 1 },
	{ Field = "OutlineTransparency", Min = 0, Max = 1 },
	{ Field = "TextTransparency", Min = 0, Max = 1 },
	{ Field = "TextStrokeTransparency", Min = 0, Max = 1 },
	{ Table = "EdgeBeacon", Field = "Margin", Min = 0 },
	{ Table = "EdgeBeacon", Field = "Length", Min = 8 },
	{ Table = "EdgeBeacon", Field = "Thickness", Min = 1 },
	{ Table = "EdgeBeacon", Field = "DotSize", Min = 2 },
	{ Table = "EdgeBeacon", Field = "PulseSpeed", Min = 0 },
	{ Table = "EdgeBeacon", Field = "TextSize", Min = 8 },
	{ Table = "EdgeBeacon", Field = "Transparency", Min = 0, Max = 1 },
	{ Table = "EdgeBeacon", Field = "PulseTransparency", Min = 0, Max = 1 },
	{ Table = "Tracer", Field = "Smoothness", Min = 0 },
	{ Table = "Skeleton", Field = "UpdateRate", Min = 0 },
	{ Table = "Skeleton", Field = "Smoothness", Min = 0 },
	{ Table = "Fade", Field = "Speed", Min = 0 },
	{ Table = "Fade", Field = "Near", Min = 0 },
	{ Table = "Fade", Field = "Min", Min = 0, Max = 1 },
	{ Table = "Fade", Field = "Max", Min = 0, Max = 1 },
}

local function NormalizeOptions(Target, Options)
	local Final = CloneTemplate(Defaults, ComponentKeys)

	if Options ~= nil then
		Merge(Final, Options)
	end

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

	for Index = 1, #ComponentSpecs do
		local Spec = ComponentSpecs[Index]
		local Key = Spec.Key
		local Value = Final[Key]

		if Value == nil or Value == false then
			local Alias = Spec.Alias

			if Alias ~= nil and Final[Alias] ~= nil then
				Value = Final[Alias]
			end
		end

		Final[Key] = BuildComponentSettings(Value, Defaults[Key], Final[Key])
	end

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
	if ESPTypes[Type] ~= nil then
		Final.ESPType = Type
	else
		Final.ESPType = "highlight"
	end

	
	
	
	for Index = 1, #NumberRules do
		local Rule = NumberRules[Index]
		local Holder = Rule.Table and Final[Rule.Table] or Final
		local Template = Rule.Table and Defaults[Rule.Table] or Defaults
		local Field = Rule.Field
		local Value = tonumber(Holder[Field])

		if Value == nil then
			Value = Template[Field]
		end

		if Rule.Max ~= nil then
			Holder[Field] = math.clamp(Value, Rule.Min, Rule.Max)
		elseif Rule.Min ~= nil then
			Holder[Field] = math.max(Rule.Min, Value)
		else
			Holder[Field] = Value
		end
	end

	if typeof(Final.EdgeBeacon.Font) ~= "EnumItem" then
		Final.EdgeBeacon.Font = Defaults.EdgeBeacon.Font
	end

	
	Final.Fade.InSpeed = math.max(0, tonumber(Final.Fade.InSpeed) or Final.Fade.Speed)
	Final.Fade.OutSpeed = math.max(0, tonumber(Final.Fade.OutSpeed) or Final.Fade.Speed)
	Final.Fade.Far = tonumber(Final.Fade.Far) or Final.MaxDistance

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

	local Billboard, Label = AcquireBillboard()

	if Billboard ~= nil then
		Billboard.Adornee = Adornee
		Billboard.StudsOffset = Settings.StudsOffset
		Billboard.Enabled = false
		Billboard.Parent = BillboardRoot
		Label.Font = Settings.Font
		Label.Text = ""
		Label.TextColor3 = Settings.Color
		Label.TextSize = Settings.TextSize
		Label.TextTransparency = 0
		Label.TextStrokeTransparency = 0
	else
		Billboard = New("BillboardGui", {
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

		Label = New("TextLabel", {
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
	end

	self.UI.Billboard = Billboard
	self.UI.Label = Label
	self._TextAdornee = Adornee
	
	
	self._LabelText = nil
	self._LabelName = nil
	self._LabelStuds = nil
	self._BbColor = nil
	self._BbTextTransparency = nil
	self._BbStrokeTransparency = nil
	self._BbFont = nil
	self._BbTextSize = nil
	self._BbStudsOffset = nil
end

ESPTypes.highlight.Build = function(Settings, Target)
	local Highlighter = AcquireHighlight()

	if Highlighter ~= nil then
		Highlighter.Adornee = Target
		Highlighter.FillColor = Settings.FillColor
		Highlighter.OutlineColor = Settings.OutlineColor
		Highlighter.FillTransparency = Settings.FillTransparency
		Highlighter.OutlineTransparency = Settings.OutlineTransparency
		Highlighter.Enabled = false
		Highlighter.Parent = WorldRoot
		return Highlighter
	end

	return New("Highlight", {
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

ESPTypes.selectionbox.Build = function(Settings, Target)
	return New("SelectionBox", {
		Parent = WorldRoot,
		Name = "SelectionBox",
		Adornee = Target,
		Color3 = Settings.Color,
		LineThickness = Settings.Thickness,
		SurfaceColor3 = Settings.SurfaceColor,
		SurfaceTransparency = Settings.Transparency,
		Visible = false,
	})
end

ESPTypes.sphereadornment.Build = function(Settings, Target, Part, Size)
	return New("SphereHandleAdornment", {
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
end

ESPTypes.cylinderadornment.Build = function(Settings, Target, Part, Size)
	return New("CylinderHandleAdornment", {
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
end

ESPTypes.adornment.Build = function(Settings, Target, Part, Size)
	return New("BoxHandleAdornment", {
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

ESPTypes.boxadornment.Build = ESPTypes.adornment.Build

function ESP:_CreateHighlighter()
	if self.UI.Highlighter then
		return
	end

	local Settings = self.CurrentSettings
	local Type = Settings.ESPType

	if Settings.Highlight == false then
		return
	end

	local Spec = ESPTypes[Type]

	if Spec == nil or Spec.Build == nil then
		return
	end

	local Target = Settings.Model
	local Highlighter

	if Spec.NeedsPart then
		local Part = GetPart(Target)

		if Part == nil then
			return
		end

		local _, BoundsSize = GetBounds(Target)
		Highlighter = Spec.Build(Settings, Target, Part, BoundsSize or Part.Size)
	else
		Highlighter = Spec.Build(Settings, Target)
	end

	self.UI.Highlighter = Highlighter
	self._HighlighterClass = Highlighter ~= nil and Spec.Class or nil
	self._HighlighterType = Highlighter ~= nil and Type or nil
	self._HlFill = nil
	self._HlOutline = nil
	self._HlFillTransparency = nil
	self._HlOutlineTransparency = nil
end

local function HighlighterMatchesType(Highlighter, Type)
	if Highlighter == nil then
		return false
	end

	local Spec = ESPTypes[Type]

	if Spec == nil or Spec.ClassName == nil then
		return true
	end

	return Highlighter:IsA(Spec.ClassName)
end

function ESP:_EnsureTracer()
	if self.UI.Tracer == nil then
		self.UI.Tracer = CreateTracerLine(OverlayRoot, "Tracer")
	end

	return self.UI.Tracer
end

function ESP:_EnsureEdgeBeacon()
	if self.UI.EdgeBeacon ~= nil then
		return self.UI.EdgeBeacon
	end

	local Color = self.CurrentSettings.Color

	local EdgeBeacon = New("Frame", {
		Parent = OverlayRoot,
		Name = "EdgeBeacon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(1, 1),
		Visible = false,
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
		BackgroundColor3 = Color,
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
		BackgroundColor3 = Color,
		BorderSizePixel = 0,
		ZIndex = 3,
	})
	New("UICorner", {
		Parent = BeaconChevronBottom,
		CornerRadius = UDim.new(1, 0),
	})

	local BeaconLabel = New("TextLabel", {
		Parent = EdgeBeacon,
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = self.CurrentSettings.EdgeBeacon.Font,
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.fromOffset(140, 24),
		Text = "",
		TextColor3 = Color,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.35,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 5,
	})

	self.UI.EdgeBeacon = {
		Root = EdgeBeacon,
		Indicator = BeaconIndicator,
		ChevronTop = BeaconChevronTop,
		ChevronBottom = BeaconChevronBottom,
		Label = BeaconLabel,
	}

	return self.UI.EdgeBeacon
end

function ESP:_EnsureBox2D()
	if self.UI.Box ~= nil then
		return self.UI.Box
	end

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

	return Box
end

function ESP:_EnsureBox3D()
	local Lines = self.UI.Box3D

	if Lines ~= nil then
		return Lines
	end

	Lines = table.create(#Box3DIndices)

	for Index = 1, #Box3DIndices do
		Lines[Index] = CreateLine(OverlayRoot, "Box3D_" .. Index)
	end

	self.UI.Box3D = Lines
	return Lines
end

function ESP:_EnsureSkeleton()
	local Lines = self.UI.Skeleton

	if Lines ~= nil then
		return Lines
	end

	local Count = #SkeletonSegments.R15
	Lines = table.create(Count)

	for Index = 1, Count do
		Lines[Index] = CreateLine(OverlayRoot, "Bone_" .. Index)
	end

	self.UI.Skeleton = Lines
	return Lines
end

local OverlayParts = {
	{ Key = "Tracer", Global = "Tracers", Ensure = "_EnsureTracer" },
	
	{ Key = "EdgeBeacon", Global = "EdgeBeacons", AltGlobal = "Arrows", Ensure = "_EnsureEdgeBeacon" },
	{ Key = "Box2D", Global = "Boxes2D", Ensure = "_EnsureBox2D" },
	{ Key = "Box3D", Global = "Boxes3D", Ensure = "_EnsureBox3D" },
	{ Key = "Skeleton", Global = "Skeleton", Ensure = "_EnsureSkeleton" },
}

local ActiveOverlayKeys = table.create(#OverlayParts)
local ActiveOverlayCount = 0

function ESP:_CreateOverlay()
	local Settings = self.CurrentSettings

	for Index = 1, #OverlayParts do
		local Part = OverlayParts[Index]
		local Component = Settings[Part.Key]

		if Component ~= nil and Component.Enabled == true then
			self[Part.Ensure](self)
		end
	end
end

function ESP:_Create()
	
	
end

function ESP:_SetHighlighterVisible(Visible)
	local Highlighter = self.UI.Highlighter

	if Highlighter == nil then
		return
	end

	if self._HighlighterClass == HIGHLIGHT_CLASS_FILL then
		SetHighlightConflictProtection(self, Visible == true)
		SetProperty(Highlighter, "Enabled", Visible)
	else
		SetProperty(Highlighter, "Visible", Visible)
	end
end

function ESP:_HideAll()
	if self._AllHidden == true then
		return
	end

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

	local Box3DLines = self.UI.Box3D

	if Box3DLines ~= nil then
		for _, Line in ipairs(Box3DLines) do
			SetProperty(Line, "Visible", false)
		end
	end

	local SkeletonLines = self.UI.Skeleton

	if SkeletonLines ~= nil then
		for _, Line in ipairs(SkeletonLines) do
			SetProperty(Line, "Visible", false)
		end
	end

	local SkeletonState = self._SkeletonState

	if SkeletonState ~= nil then
		SkeletonState.VisibleCount = 0

		local LineStates = SkeletonState.Lines

		if LineStates ~= nil then
			for _, LineState in pairs(LineStates) do
				LineState.Visible = false
				LineState.TargetA = nil
				LineState.TargetB = nil
				LineState.CurrentA = nil
				LineState.CurrentB = nil
			end
		end
	end

	self._SkeletonVisible = false
	self._AllHidden = true
	self:_RefreshSmoothOverlayRegistration()
end

function ESP:_UpdateBillboard(Visible, TargetOnScreen, Distance, Alpha)
	local Settings = self.CurrentSettings
	local Billboard = self.UI.Billboard
	local Label = self.UI.Label

	local Enabled = Settings.Text == true
		and Settings.Billboard ~= false
		and VeloESP.Settings.Billboards == true
		and Visible
		and TargetOnScreen
		and Alpha > 0.01

	if Billboard == nil or Label == nil then
		if not Enabled then
			return
		end

		self:_CreateBillboard()
		Billboard = self.UI.Billboard
		Label = self.UI.Label

		if Billboard == nil or Label == nil then
			return
		end
	end

	SetProperty(Billboard, "Enabled", Enabled)

	if not Enabled then
		return
	end

	
	
	
	local Name = Settings.Name

	if type(Name) ~= "string" then
		Name = Name ~= nil and tostring(Name) or self.Target.Name
	end

	local ShowDistance = Settings.Distance == true and VeloESP.Settings.Distance == true
	local Studs = ShowDistance and math.floor(Distance + 0.5) or -1
	local Text = self._LabelText

	if Text == nil or self._LabelName ~= Name or self._LabelStuds ~= Studs then
		if ShowDistance then
			Text = string.format('%s\n<font size="11">[%d studs]</font>', Name, Studs)
		else
			Text = Name
		end

		self._LabelText = Text
		self._LabelName = Name
		self._LabelStuds = Studs
	end

	local TextTarget = Settings.TextModel or Settings.Model
	local Adornee = self._TextAdornee
	if Adornee == nil or Adornee.Parent == nil or (Adornee ~= TextTarget and not Adornee:IsDescendantOf(TextTarget)) then
		Adornee = GetPart(TextTarget)
		self._TextAdornee = Adornee
	end
	SetProperty(Billboard, "Adornee", Adornee)
	SetProperty(Label, "Text", Text)

	
	
	
	
	local Color = self:_GetColor(Settings.Color)
	local TextTransparency = ApplyAlphaTransparency(Settings.TextTransparency, Alpha)
	local StrokeTransparency = ApplyAlphaTransparency(Settings.TextStrokeTransparency, Alpha)
	local Font = Settings.Font or VeloESP.Settings.Font
	local TextSize = Settings.TextSize or VeloESP.Settings.TextSize
	local StudsOffset = Settings.StudsOffset

	if self._BbColor ~= Color
		or self._BbTextTransparency ~= TextTransparency
		or self._BbStrokeTransparency ~= StrokeTransparency
		or self._BbFont ~= Font
		or self._BbTextSize ~= TextSize
		or self._BbStudsOffset ~= StudsOffset
	then
		self._BbColor = Color
		self._BbTextTransparency = TextTransparency
		self._BbStrokeTransparency = StrokeTransparency
		self._BbFont = Font
		self._BbTextSize = TextSize
		self._BbStudsOffset = StudsOffset

		SetProperty(Billboard, "StudsOffset", StudsOffset)
		SetProperty(Label, "TextColor3", Color)
		SetProperty(Label, "TextTransparency", TextTransparency)
		SetProperty(Label, "TextStrokeTransparency", StrokeTransparency)
		SetProperty(Label, "Font", Font)
		SetProperty(Label, "TextSize", TextSize)
	end
end

function ESP:_UpdateHighlighter(Visible, TargetOnScreen, Alpha)
	local Settings = self.CurrentSettings
	local Highlighter = self.UI.Highlighter
	local Type = Settings.ESPType

	
	
	
	if Highlighter ~= nil and self._HighlighterType ~= Type then
		if HighlighterMatchesType(Highlighter, Type) then
			self._HighlighterType = Type
		else
			self:_SetHighlighterVisible(false)

			if self._HighlighterClass == HIGHLIGHT_CLASS_FILL then
				ReleaseHighlight(Highlighter)
			else
				Destroy(Highlighter)
			end

			self.UI.Highlighter = nil
			self._HighlighterType = nil
			self._HighlighterClass = nil
			Highlighter = nil
		end
	end

	local GlobalEnabled = VeloESP.Settings.Highlighters == true
	local Enabled = Visible and TargetOnScreen and Alpha > 0.01
		and GlobalEnabled and Settings.Highlight ~= false and Type ~= "text"

	if Highlighter == nil then
		if not Enabled then
			return
		end

		self:_CreateHighlighter()
		Highlighter = self.UI.Highlighter

		if Highlighter == nil then
			return
		end
	end

	self:_SetHighlighterVisible(Enabled)

	if not Enabled then
		return
	end

	local Class = self._HighlighterClass

	if Class == HIGHLIGHT_CLASS_FILL then
		SetProperty(Highlighter, "Adornee", Settings.Model)

		
		
		local FillColor = self:_GetColor(Settings.FillColor)
		local OutlineColor = self:_GetColor(Settings.OutlineColor)
		local FillTransparency = ApplyAlphaTransparency(Settings.FillTransparency, Alpha)
		local OutlineTransparency = ApplyAlphaTransparency(Settings.OutlineTransparency, Alpha)

		if self._HlFill ~= FillColor
			or self._HlOutline ~= OutlineColor
			or self._HlFillTransparency ~= FillTransparency
			or self._HlOutlineTransparency ~= OutlineTransparency
		then
			self._HlFill = FillColor
			self._HlOutline = OutlineColor
			self._HlFillTransparency = FillTransparency
			self._HlOutlineTransparency = OutlineTransparency

			SetProperty(Highlighter, "FillColor", FillColor)
			SetProperty(Highlighter, "OutlineColor", OutlineColor)
			SetProperty(Highlighter, "FillTransparency", FillTransparency)
			SetProperty(Highlighter, "OutlineTransparency", OutlineTransparency)
		end

		return
	end

	local Color = self:_GetColor(Settings.Color)

	if Class == HIGHLIGHT_CLASS_SELECTION then
		SetProperty(Highlighter, "Adornee", Settings.Model)
		SetProperty(Highlighter, "Color3", Color)
		SetProperty(Highlighter, "LineThickness", Settings.Thickness)
		SetProperty(Highlighter, "SurfaceColor3", Settings.SurfaceColor)
		SetProperty(Highlighter, "SurfaceTransparency", ApplyAlphaTransparency(Settings.Transparency, Alpha))
		return
	end

	local Part = GetPart(Settings.Model)
	local _, Size = GetBounds(Settings.Model)
	SetProperty(Highlighter, "Adornee", Part)
	SetProperty(Highlighter, "Color3", Color)
	SetProperty(Highlighter, "Transparency", ApplyAlphaTransparency(Settings.Transparency, Alpha))

	if Size then
		if Class == HIGHLIGHT_CLASS_SPHERE then
			SetProperty(Highlighter, "Radius", math.max(Size.X, Size.Y, Size.Z) * 0.62)
		elseif Class == HIGHLIGHT_CLASS_CYLINDER then
			SetProperty(Highlighter, "Height", Size.Y)
			SetProperty(Highlighter, "Radius", math.max(Size.X, Size.Z) * 0.55)
		elseif Class == HIGHLIGHT_CLASS_BOX then
			SetProperty(Highlighter, "Size", Size)
		end
	end
end

function ESP:_UpdateBox2D(Visible, TargetOnScreen, Alpha, BoundsVisible, MinX, MinY, MaxX, MaxY)
	local Settings = self.CurrentSettings
	local BoxSettings = Settings.Box2D
	local Box = self.UI.Box

	if BoxSettings.Enabled ~= true or VeloESP.Settings.Boxes2D ~= true then
		if Box ~= nil and Box.Visible then
			SetProperty(Box, "Visible", false)
		end

		return
	end

	local Enabled = Visible and TargetOnScreen and Alpha > 0.01 and BoundsVisible
	if Box == nil then
		if not Enabled then
			return
		end
		Box = self:_EnsureBox2D()
	end

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
	local Settings = self.CurrentSettings
	local BoxSettings = Settings.Box3D
	local Enabled = Visible and Alpha > 0.01 and CornerOnScreen and BoxSettings.Enabled == true and VeloESP.Settings.Boxes3D == true

	if not Enabled and self._Box3DVisible ~= true then
		return
	end

	local Lines = self.UI.Box3D

	if Lines == nil then
		if not Enabled then
			self._Box3DVisible = false
			return
		end

		Lines = self:_EnsureBox3D()
	end

	self._Box3DVisible = Enabled

	if not Enabled or ScreenCorners == nil then
		for _, Line in ipairs(Lines) do
			SetProperty(Line, "Visible", false)
		end
		return
	end

	local Color = self:_GetColor(BoxSettings.Color)
	local Transparency = ApplyAlphaTransparency(BoxSettings.Transparency, Alpha)

	for Index, Line in ipairs(Lines) do
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

local TracerOrigins = {
	top = function(Viewport)
		return Vector2.new(Viewport.X / 2, 0)
	end,
	center = function(Viewport)
		return Vector2.new(Viewport.X / 2, Viewport.Y / 2)
	end,
	bottom = function(Viewport)
		return Vector2.new(Viewport.X / 2, Viewport.Y)
	end,
	mouse = function()
		local Mouse = UserInputService:GetMouseLocation()
		return Vector2.new(Mouse.X, Mouse.Y)
	end,
}

function ESP:_GetTracerOrigin()
	local Viewport = GetViewportSize()

	if Viewport == nil then
		return Vector2.zero
	end

	local From = self.CurrentSettings.Tracer.From
	local Origin = type(From) == "string" and TracerOrigins[From] or nil

	if Origin == nil then
		Origin = TracerOrigins.bottom
	end

	return Origin(Viewport)
end

function ESP:_RefreshSmoothOverlayRegistration()
	local Active = false
	local TracerState = self._TracerState

	if TracerState and TracerState.Visible == true then
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

function ESP:_RenderTracer(DeltaTime, ProjectedPosition)
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
		local ScreenPosition = ProjectedPosition
		if ScreenPosition == nil and self._ProjectionFrame == Screen.Frame and self._ProjectionModel == Model then
			ScreenPosition = self._LastScreenPosition
		end
		if ScreenPosition == nil then
			local CFrame = GetCFrame(Model)
			if CFrame ~= nil then
				ScreenPosition = WorldToViewport(CFrame.Position)
			end
		end

		if ScreenPosition ~= nil then

			if ScreenPosition.Z > 0 then
				State.TargetTo = Vector2.new(ScreenPosition.X, ScreenPosition.Y)
			else
				SetProperty(Tracer, "Visible", false)
				State.CurrentTo = nil
				return true
			end
		end
	end

	State.CurrentFrom = self:_GetTracerOrigin()
	State.CurrentTo = SmoothVector2(State.CurrentTo, State.TargetTo, State.Smoothness, DeltaTime)

	SetProperty(Tracer, "Visible", true)
	self.UI.Tracer = UpdateTracerLine(Tracer, State.CurrentFrom, State.CurrentTo, State.Thickness, State.Color, State.Transparency)
	State.PresentedFrame = Screen.Frame

	return true
end

function ESP:_RenderSkeleton(DeltaTime)
	local State = self._SkeletonState
	local Lines = self.UI.Skeleton

	if State == nil or Lines == nil then
		return false
	end

	local AnyVisible = false
	local SmoothingAlpha = Util.GetSmoothingAlpha(State.Smoothness, DeltaTime)

	for Index, Line in ipairs(Lines) do
		local LineState = State.Lines and State.Lines[Index]
		local ShowLine = LineState ~= nil
			and LineState.Visible == true
			and LineState.TargetA ~= nil
			and LineState.TargetB ~= nil

		SetProperty(Line, "Visible", ShowLine == true)

		if ShowLine then
			if LineState.CurrentA == nil or SmoothingAlpha >= 1 then
				LineState.CurrentA = LineState.TargetA
			else
				LineState.CurrentA += (LineState.TargetA - LineState.CurrentA) * SmoothingAlpha
			end
			if LineState.CurrentB == nil or SmoothingAlpha >= 1 then
				LineState.CurrentB = LineState.TargetB
			else
				LineState.CurrentB += (LineState.TargetB - LineState.CurrentB) * SmoothingAlpha
			end
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

	if TracerState and TracerState.Visible == true and TracerState.PresentedFrame ~= Screen.Frame then
		Active = self:_RenderTracer(DeltaTime) or Active
	elseif TracerState and TracerState.Visible == true then
		Active = true
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
		if not Enabled then
			local State = self._TracerState

			if State == nil then
				return
			end

			State.Visible = false
			State.TargetTo = nil
			self:_RefreshSmoothOverlayRegistration()
			return
		end

		Tracer = self:_EnsureTracer()
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
		self:_RenderTracer(0, ScreenPosition)
	end

	self:_RefreshSmoothOverlayRegistration()
end

function ESP:_UpdateEdgeBeacon(Visible, OnScreen, ScreenPosition, Distance, Alpha)
	local Beacon = self.UI.EdgeBeacon
	local Settings = self.CurrentSettings.EdgeBeacon
	local Enabled = Settings.Enabled == true
		and Visible
		and Alpha > 0.01
		and not OnScreen
		and (VeloESP.Settings.EdgeBeacons == true or VeloESP.Settings.Arrows == true)

	if Beacon == nil then
		if not Enabled then
			return
		end

		Beacon = self:_EnsureEdgeBeacon()
	end

	if Beacon.Root == nil then
		return
	end

	SetProperty(Beacon.Root, "Visible", Enabled)

	if not Enabled then
		return
	end

	local Viewport = GetViewportSize()

	if Viewport == nil then
		SetProperty(Beacon.Root, "Visible", false)
		return
	end

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

	local ArrowSize = math.clamp(Settings.Length, 24, 48)
	local Margin = Settings.Margin + (ArrowSize / 2)
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
	Position = Vector2.new(math.floor(Position.X + 0.5), math.floor(Position.Y + 0.5))
	local Color = self:_GetColor(Settings.Color)
	local Thickness = math.clamp(Settings.Thickness, 1, 4)
	local Transparency = ApplyAlphaTransparency(Settings.Transparency, Alpha)
	local BaseX = ArrowSize * 0.16
	local TipX = ArrowSize * 0.84
	local TopY = ArrowSize * 0.08
	local MiddleY = ArrowSize * 0.5
	local BottomY = ArrowSize * 0.92
	local Name = self.CurrentSettings.Name or self.Target.Name
	if type(Name) ~= "string" then
		Name = tostring(Name)
	end
	local ShowDistance = Settings.Distance == true and VeloESP.Settings.Distance == true
	local Studs = ShowDistance and math.floor(Distance + 0.5) or -1
	local LabelText = self._BeaconText
	if LabelText == nil or self._BeaconName ~= Name or self._BeaconStuds ~= Studs then
		LabelText = ShowDistance and string.format("%s  ·  %d studs", Name, Studs) or Name
		self._BeaconText = LabelText
		self._BeaconName = Name
		self._BeaconStuds = Studs
	end

	local LabelFont = Settings.Font or VeloESP.Settings.Font or Enum.Font.Oswald
	local TextBounds = self._BeaconTextBounds
	if TextBounds == nil or self._BeaconMeasuredText ~= LabelText
		or self._BeaconFont ~= LabelFont or self._BeaconTextSize ~= Settings.TextSize then
		TextBounds = MeasureText(LabelText, Settings.TextSize, LabelFont)
		self._BeaconTextBounds = TextBounds
		self._BeaconMeasuredText = LabelText
		self._BeaconFont = LabelFont
		self._BeaconTextSize = Settings.TextSize
	end
	local LabelWidth = math.clamp(math.ceil(TextBounds.X) + 8, 24, math.max(24, math.min(260, Viewport.X - 8)))
	local LabelHeight = math.min(math.ceil(TextBounds.Y) + 2, math.max(1, Viewport.Y - 8))
	local Axis
	local LabelGap

	if math.abs(Direction.X) >= math.abs(Direction.Y) then
		Axis = Vector2.new(Direction.X >= 0 and 1 or -1, 0)
		LabelGap = (ArrowSize / 2) + (LabelWidth / 2) + 6
	else
		Axis = Vector2.new(0, Direction.Y >= 0 and 1 or -1)
		LabelGap = (ArrowSize / 2) + (LabelHeight / 2) + 6
	end

	local DesiredLabelCenter = Position - (Axis * LabelGap)
	local LabelHalfWidth = LabelWidth / 2
	local LabelHalfHeight = LabelHeight / 2
	local SafeInset = 4
	local LabelCenter = Vector2.new(
		math.clamp(DesiredLabelCenter.X, LabelHalfWidth + SafeInset, Viewport.X - LabelHalfWidth - SafeInset),
		math.clamp(DesiredLabelCenter.Y, LabelHalfHeight + SafeInset, Viewport.Y - LabelHalfHeight - SafeInset)
	)
	local LabelOffset = LabelCenter - Position
	LabelOffset = Vector2.new(math.floor(LabelOffset.X + 0.5), math.floor(LabelOffset.Y + 0.5))

	SetProperty(Beacon.Root, "Position", UDim2.fromOffset(Position.X, Position.Y))
	SetProperty(Beacon.Indicator, "Rotation", math.deg(math.atan2(Direction.Y, Direction.X)))
	if self._BeaconArrowSize ~= ArrowSize or self._BeaconThickness ~= Thickness then
		self._BeaconArrowSize = ArrowSize
		self._BeaconThickness = Thickness
		SetProperty(Beacon.Indicator, "Size", UDim2.fromOffset(ArrowSize, ArrowSize))
		UpdateLine(Beacon.ChevronTop, Vector2.new(BaseX, TopY), Vector2.new(TipX, MiddleY), Thickness)
		UpdateLine(Beacon.ChevronBottom, Vector2.new(TipX, MiddleY), Vector2.new(BaseX, BottomY), Thickness)
	end
	SetProperty(Beacon.ChevronTop, "BackgroundColor3", Color)
	SetProperty(Beacon.ChevronTop, "BackgroundTransparency", Transparency)
	SetProperty(Beacon.ChevronBottom, "BackgroundColor3", Color)
	SetProperty(Beacon.ChevronBottom, "BackgroundTransparency", Transparency)

	SetProperty(Beacon.Label, "Visible", Settings.Label == true)
	SetProperty(Beacon.Label, "Position", UDim2.fromOffset(LabelOffset.X, LabelOffset.Y))
	SetProperty(Beacon.Label, "Size", UDim2.fromOffset(LabelWidth, LabelHeight))
	SetProperty(Beacon.Label, "TextColor3", Color)
	SetProperty(Beacon.Label, "Font", LabelFont)
	SetProperty(Beacon.Label, "TextSize", Settings.TextSize)
	SetProperty(Beacon.Label, "TextTransparency", Transparency)
	SetProperty(Beacon.Label, "TextStrokeTransparency", ApplyAlphaTransparency(0.35, Alpha))

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
		Projected = {},
	}
	self._SkeletonCache = Cache

	return Cache
end

function ESP:_UpdateSkeleton(Visible, OnScreen, Alpha, DeltaTime)
	local Settings = self.CurrentSettings
	local SkeletonSettings = Settings.Skeleton
	local Enabled = SkeletonSettings.Enabled == true
		and Visible
		and OnScreen
		and Alpha > 0.01
		and VeloESP.Settings.Skeleton == true
		and typeof(Settings.Model) == "Instance"
		and GetKind(Settings.Model) == KIND_MODEL

	local Lines = self.UI.Skeleton

	if Lines == nil then
		if not Enabled then
			local State = self._SkeletonState

			if State ~= nil then
				State.VisibleCount = 0
				self:_RefreshSmoothOverlayRegistration()
			end

			return
		end

		Lines = self:_EnsureSkeleton()
	end

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

		if State ~= nil then
			State.VisibleCount = 0

			local LineStates = State.Lines

			if LineStates ~= nil then
				for _, LineState in pairs(LineStates) do
					LineState.Visible = false
					LineState.TargetA = nil
					LineState.TargetB = nil
					LineState.CurrentA = nil
					LineState.CurrentB = nil
				end
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
	local Projected = Cache.Projected
	table.clear(Projected)

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

		if Parts == nil or Parts[1].Parent ~= Settings.Model or Parts[2].Parent ~= Settings.Model then
			local First = Settings.Model:FindFirstChild(Segment[1])
			local Second = Settings.Model:FindFirstChild(Segment[2])
			if First and Second and GetKind(First) == KIND_PART and GetKind(Second) == KIND_PART then
				Parts = { First, Second }
				Cache.Parts[Index] = Parts
			else
				Parts = nil
				Cache.Parts[Index] = nil
			end
		end
		if Parts == nil then
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
		
		
		local PointA = Projected[First]
		if PointA == nil then
			PointA = WorldToViewport(First.Position)
			Projected[First] = PointA
		end
		local PointB = Projected[Second]
		if PointB == nil then
			PointB = WorldToViewport(Second.Position)
			Projected[Second] = PointB
		end
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

local function RefreshActiveOverlays()
	local Settings = VeloESP.Settings
	local Count = 0

	for Index = 1, #OverlayParts do
		local Part = OverlayParts[Index]

		if Settings[Part.Global] == true or (Part.AltGlobal ~= nil and Settings[Part.AltGlobal] == true) then
			Count += 1
			ActiveOverlayKeys[Count] = Part.Key
		end
	end

	for Index = Count + 1, ActiveOverlayCount do
		ActiveOverlayKeys[Index] = nil
	end

	ActiveOverlayCount = Count
	return Count > 0
end

VeloESP._AnyOverlay = RefreshActiveOverlays()

function ESP:_NeedsScreenOverlays()
	local Count = ActiveOverlayCount

	if Count == 0 then
		return false
	end

	local Settings = self.CurrentSettings

	for Index = 1, Count do
		local Component = Settings[ActiveOverlayKeys[Index]]

		if Component ~= nil and Component.Enabled == true then
			return true
		end
	end

	return false
end

function ESP:_GetUpdateRate(Distance, NeedsOverlays)
	if NeedsOverlays == nil then
		NeedsOverlays = self:_NeedsScreenOverlays()
	end

	if NeedsOverlays or VeloESP._AnyRateLimit == false then
		return 0
	end

	local Cache = VeloESP._RateCache
	local GlobalRate, FarDistance, FarRate, NearRate

	if Cache then
		GlobalRate, FarDistance, FarRate, NearRate = Cache[1], Cache[2], Cache[3], Cache[4]
	else
		local GlobalSettings = VeloESP.Settings
		GlobalRate = tonumber(GlobalSettings.UpdateRate) or 0
		FarDistance = tonumber(GlobalSettings.FarDistance) or 650
		FarRate = tonumber(GlobalSettings.FarUpdateRate) or 0
		NearRate = tonumber(GlobalSettings.NearUpdateRate) or 0
	end

	if GlobalRate > 0 then
		return GlobalRate
	end

	if Distance and Distance >= FarDistance then
		return FarRate
	end

	return NearRate
end

function ESP:_Update(DeltaTime)
	if self.Destroyed then
		return
	end

	DeltaTime = DeltaTime or 1 / 60
	
	
	Geometry.BoundsTarget = nil

	local Settings = self.CurrentSettings

	if not (Settings.Model and Settings.Model.Parent) then
		self:Destroy()
		return
	end

	self._UpdateElapsed = (self._UpdateElapsed or 0) + DeltaTime

	
	
	
	local NeedsOverlays = ActiveOverlayCount > 0 and self:_NeedsScreenOverlays() or false
	local RateLimited = NeedsOverlays == false and VeloESP._AnyRateLimit ~= false

	if RateLimited and self._LastDistance ~= nil and Settings.Fade.Enabled ~= true then
		local CachedRate = self:_GetUpdateRate(self._LastDistance, NeedsOverlays)
		if CachedRate > 0 and self._UpdateElapsed < CachedRate then
			return
		end
	end

	local CFrame = GetCFrame(Settings.Model)

	if CFrame == nil then
		self:_HideAll()
		return
	end

	local CameraPosition = GetCameraPosition()
	local Distance = math.huge

	if CameraPosition then
		Distance = (CFrame.Position - CameraPosition).Magnitude
	end

	local BaseVisible = VeloESP.Settings.Enabled == true
		and self.Hidden ~= true
		and Settings.Visible ~= false
		and Distance <= Settings.MaxDistance
	local TargetAlpha = self:_GetFadeTarget(BaseVisible, Distance)

	if RateLimited then
		local UpdateRate = self:_GetUpdateRate(Distance, NeedsOverlays)

		if UpdateRate > 0 and self._UpdateElapsed < UpdateRate then
			local IsFading = math.abs((self._Alpha or TargetAlpha) - TargetAlpha) > 0.01

			if IsFading ~= true then
				return
			end
		end
	end

	self._UpdateElapsed = 0

	local Alpha = self:_StepFade(TargetAlpha, DeltaTime)
	local Visible = Alpha > 0.01

	self._LastDistance = Distance
	self._Alpha = Alpha

	if Visible ~= true then
		self:_HideAll()
		if self.Hidden == true or Settings.Visible == false then
			RemoveUpdateObject(self)
		end
		return
	end

	local NeedsProjection = NeedsOverlays

	local ScreenPosition = self._LastScreenPosition
	local OnScreen = true
	local BoundsVisible = true
	local ScreenCorners = self._ScreenCorners
	local MinX, MinY, MaxX, MaxY = 0, 0, 0, 0

	if NeedsProjection then
		local ProjectedCFrame
		ProjectedCFrame, ScreenPosition, OnScreen, BoundsVisible, ScreenCorners, MinX, MinY, MaxX, MaxY = GetProjectedVisibility(Settings.Model, self._ScreenCorners, CFrame)

		if ProjectedCFrame == nil or ScreenPosition == nil then
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

		self._ScreenCorners = ScreenCorners
		self._LastScreenPosition = ScreenPosition
		self._ProjectionFrame = Screen.Frame
		self._ProjectionModel = Settings.Model
		self._OnScreen = OnScreen
		self._BoundsVisible = BoundsVisible

		if Settings.BeforeUpdate then
			SafeCall(Settings.BeforeUpdate, self)
			if self.Destroyed then
				return
			end
			Geometry.BoundsTarget = nil
			self._ProjectionFrame = nil
		end

		self._AllHidden = false

		self:_UpdateBillboard(Visible, BoundsVisible, Distance, Alpha)
		self:_UpdateHighlighter(Visible, BoundsVisible, Alpha)
		self:_UpdateBox2D(Visible, BoundsVisible, Alpha, CornerOnScreen, MinX, MinY, MaxX, MaxY)
		self:_UpdateBox3D(Visible, Alpha, CornerOnScreen, ScreenCorners)
		self:_UpdateTracer(Visible, OnScreen, ScreenPosition, Alpha)
		self:_UpdateEdgeBeacon(Visible, BoundsVisible, ScreenPosition, Distance, Alpha)
		self:_UpdateSkeleton(Visible, OnScreen, Alpha, DeltaTime)
		self._OverlaysDirty = true
	else
		self._OnScreen = true
		self._BoundsVisible = true

		if Settings.BeforeUpdate then
			SafeCall(Settings.BeforeUpdate, self)
			if self.Destroyed then
				return
			end
			Geometry.BoundsTarget = nil
		end

		self._AllHidden = false

		self:_UpdateBillboard(Visible, true, Distance, Alpha)
		self:_UpdateHighlighter(Visible, true, Alpha)

		
		
		
		if self._OverlaysDirty ~= false then
			self:_UpdateBox2D(Visible, false, Alpha, false, 0, 0, 0, 0)
			self:_UpdateBox3D(Visible, Alpha, false, ScreenCorners)
			self:_UpdateTracer(Visible, false, ScreenPosition, Alpha)
			self:_UpdateEdgeBeacon(Visible, false, ScreenPosition, Distance, Alpha)
			self:_UpdateSkeleton(Visible, false, Alpha, DeltaTime)
			self._OverlaysDirty = false
		end
	end

	if Settings.AfterUpdate then
		SafeCall(Settings.AfterUpdate, self)
		self._ProjectionFrame = nil
	end
	Geometry.BoundsTarget = nil
end

function ESP:Set(Options)
	assert(typeof(Options) == "table", "Argument #1 must be a table.")

	self._OverlaysDirty = true
	Merge(self.CurrentSettings, Options)
	self.CurrentSettings = NormalizeOptions(self.Target, self.CurrentSettings)
	self.Options = self.CurrentSettings
	self:_BindModelWatch()

	if self.Hidden == true or self.CurrentSettings.Visible == false then
		if self.CurrentSettings.Fade.Enabled == true and self._Alpha > 0.01 then
			AddUpdateObject(self)
		else
			self:_HideAll()
			RemoveUpdateObject(self)
		end
	else
		AddUpdateObject(self)
	end

	if self._HighlighterActive == true then
		SetHighlightConflictProtection(self, false)
		SetHighlightConflictProtection(self, true)
	end

	self._SkeletonCache = nil
	self._TracerState = nil
	self._SkeletonState = nil
	self._TextAdornee = nil
	self._SkeletonVisible = false
	VeloESP._SmoothObjects[self] = nil

	if self.UI.Tracer then
		SetProperty(self.UI.Tracer, "Visible", false)
	end

	local SkeletonLines = self.UI.Skeleton

	if SkeletonLines ~= nil then
		for _, Line in ipairs(SkeletonLines) do
			SetProperty(Line, "Visible", false)
		end
	end

	return self
end

function ESP:Show()
	self.Hidden = false
	self._OverlaysDirty = true
	self.CurrentSettings.Visible = true
	AddUpdateObject(self)
	return self
end

function ESP:Hide()
	self.Hidden = true
	self.CurrentSettings.Visible = false
	if self.CurrentSettings.Fade.Enabled == true and self._Alpha > 0.01 then
		AddUpdateObject(self)
	else
		self:_HideAll()
		RemoveUpdateObject(self)
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
	if Geometry.BoundsTarget == self.CurrentSettings.Model then
		Geometry.BoundsTarget = nil
	end
	self.Deleted = true
	VeloESP._SmoothObjects[self] = nil
	RemoveUpdateObject(self)
	SetHighlightConflictProtection(self, false)

	if self._ModelWatch then
		self._ModelWatch:Disconnect()
		self._ModelWatch = nil
	end

	self._WatchedModel = nil

	if self.OriginalSettings.OnDestroy then
		SafeCall(self.OriginalSettings.OnDestroy.Fire, self.OriginalSettings.OnDestroy)
	end

	if self.OriginalSettings.OnDestroyFunc then
		SafeCall(self.OriginalSettings.OnDestroyFunc, self)
	end

	
	
	local UI = self.UI

	if self._HighlighterClass == HIGHLIGHT_CLASS_FILL and UI.Highlighter ~= nil then
		ReleaseHighlight(UI.Highlighter)
		UI.Highlighter = nil
	end

	if UI.Billboard ~= nil then
		ReleaseBillboard(UI.Billboard, UI.Label)
		UI.Billboard = nil
		UI.Label = nil
	end

	self._HighlighterClass = nil
	self._HighlighterType = nil

	for _, Object in pairs(UI) do
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
		Index = Target.Name .. "_" .. math.random(100000, 999999),
		Target = Target,
		Hidden = false,
		Destroyed = false,
		Deleted = false,
		_Alpha = StartAlpha,
		_Seed = math.random(),
		_UpdateElapsed = 0,
		_LastUpdateTime = VeloESP._Elapsed,
		
		
		
		OriginalSettings = CloneTemplate(Settings, ComponentKeys),
		CurrentSettings = Settings,
		Options = Settings,
		UI = {},
	}, ESP)

	VeloESP._Objects[Target] = Object
	Object._ListIndex = #VeloESP._ObjectList + 1
	VeloESP._ObjectList[Object._ListIndex] = Object
	if Settings.Visible ~= false then
		AddUpdateObject(Object)
	end

	Object:_BindModelWatch()
	if Settings.DeferredCreation ~= true then
		
		
		Screen.CameraPosition = nil
		Screen.ViewportSize = nil
		Object:_Update()
	end

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

local function SettingsMatch(Current, Proposed)
	for Key, Value in pairs(Proposed) do
		local Existing = Current[Key]
		if (Key == "ESPType" or Key == "From") and type(Value) == "string" then
			Value = string.lower(Value)
		end
		if type(Value) == "table" and type(Existing) == "table" then
			if not SettingsMatch(Existing, Value) then
				return false
			end
		elseif Existing ~= Value then
			return false
		end
	end
	return true
end

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

function Watcher:_RemoveObject(Object, KeepTracked)
	if KeepTracked ~= true then
		self.Objects[Object] = nil
	end

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
		self:_RemoveObject(Object, true)
		return
	end

	local Options = self:_BuildOptions(Object)
	local Handle = self.Handles[Object]

	if Handle and Handle.Destroyed ~= true then
		if not SettingsMatch(Handle.CurrentSettings, Options) then
			Handle:Set(Options)
		end
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
	for Object in pairs(self.Objects) do
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
	RemoveWatcher(self)

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
		Objects = WeakTable(),
		Handles = WeakTable(),
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

	RegisterWatcher(Object)
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
		self.ScanQueue:Push(Object)
	else
		self.LiveQueue:Push(Object)
	end
end

function GeneratedObserver:_ProcessObject(Object)
	if self.Destroyed or self.Enabled ~= true then
		return
	end

	if not (Object and Object.Parent)
		or (Object ~= self.Root and not Object:IsDescendantOf(self.Root)) then
		return
	end

	if not self:_Matches(Object) then
		return
	end

	local Options = self.Options

	if typeof(Options.OnAdded) == "function" then
		SafeCall(Options.OnAdded, Object, self)
	end
	if self.Destroyed or self.Enabled ~= true then
		return
	end

	if typeof(Options.BuildOptions) == "function" then
		local ESPOptions = SafeCall(Options.BuildOptions, Object, self)

		if typeof(ESPOptions) == "table" then
			ESPOptions.Model = ESPOptions.Model or ESPOptions.Object or Object
			ESPOptions.Object = nil

			if typeof(ESPOptions.Model) == "Instance" then
				local Handle = self.Handles[Object]
				if Handle and Handle.Destroyed ~= true and Handle.Target == ESPOptions.Model then
					if not SettingsMatch(Handle.CurrentSettings, ESPOptions) then
						Handle:Set(ESPOptions)
					end
				else
					if Handle and Handle.Destroyed ~= true then
						Handle:Destroy()
					end
					self.Handles[Object] = VeloESP.Add(ESPOptions)
				end
			end
		end
	elseif typeof(Options.ESP) == "table" then
		local ESPOptions = DeepCopy(Options.ESP)
		ESPOptions.Model = ESPOptions.Model or Object
		ESPOptions.Name = Resolve(ESPOptions.Name, Object, ESPOptions.Name or Object.Name)
		ESPOptions.Color = Resolve(ESPOptions.Color, Object, ESPOptions.Color)
		local Handle = self.Handles[Object]
		if Handle and Handle.Destroyed ~= true and Handle.Target == ESPOptions.Model then
			if not SettingsMatch(Handle.CurrentSettings, ESPOptions) then
				Handle:Set(ESPOptions)
			end
		else
			if Handle and Handle.Destroyed ~= true then
				Handle:Destroy()
			end
			self.Handles[Object] = VeloESP.Add(ESPOptions)
		end
	end
end

function GeneratedObserver:_Flush()
	if self.Destroyed or self.Enabled ~= true then
		return
	end

	local MaxPerStep = math.max(1, tonumber(self.Options.MaxPerStep) or 1)

	for _ = 1, MaxPerStep do
		local Object = self.LiveQueue:Pop() or self.ScanQueue:Pop()

		if Object == nil then
			return
		end

		
		
		if self.Queued[Object] == true then
			self.Queued[Object] = nil
			self:_ProcessObject(Object)
		end
	end
end

function GeneratedObserver:_Scan()
	self.ScanGeneration += 1
	local Generation = self.ScanGeneration

	local Queued = self.Queued
	self.ScanQueue:ForEach(function(Object)
		Queued[Object] = nil
	end)
	self.ScanQueue:Clear()

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
		self.LiveQueue:Clear()
		self.ScanQueue:Clear()
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
	RemoveWatcher(self)

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
	self.LiveQueue:Clear()
	self.ScanQueue:Clear()
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
		LiveQueue = Queue.new(),
		ScanQueue = Queue.new(),
		ScanGeneration = 0,
		Queued = WeakTable(),
		Handles = WeakTable(),
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

	table.insert(Object.Connections, RunService.Heartbeat:Connect(function()
		Object:_Flush()
	end))

	if Object.Enabled then
		Object:_Scan()
	end

	RegisterWatcher(Object)
	return Object
end

VeloESP.Observe = VeloESP.ObserveGenerated
VeloESP.WatchGenerated = VeloESP.ObserveGenerated

function VeloESP.WatchPlayers(Options)
	local PlayerSettings = DeepCopy(Options or {})
	local Handles = {}
	local Connections = {}
	local CharacterConnections = {}
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

		if CharacterConnections[Player] then
			CharacterConnections[Player]:Disconnect()
		end
		CharacterConnections[Player] = Player.CharacterAdded:Connect(function(Character)
			AddCharacter(Player, Character)
		end)

		if Player.Character then
			AddCharacter(Player, Player.Character)
		end
	end

	for _, Player in ipairs(Players:GetPlayers()) do
		TrackPlayer(Player)
	end

	table.insert(Connections, Players.PlayerAdded:Connect(TrackPlayer))
	table.insert(Connections, Players.PlayerRemoving:Connect(function(Player)
		RemovePlayer(Player)
		local Connection = CharacterConnections[Player]
		if Connection then
			Connection:Disconnect()
			CharacterConnections[Player] = nil
		end
	end))

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
		RemoveWatcher(self)

		for _, Connection in ipairs(Connections) do
			if Connection and Connection.Connected then
				Connection:Disconnect()
			end
		end

		for Player in pairs(Handles) do
			RemovePlayer(Player)
		end
		for Player, Connection in pairs(CharacterConnections) do
			Connection:Disconnect()
			CharacterConnections[Player] = nil
		end
		table.clear(Connections)
	end

	RegisterWatcher(Controller)
	return Controller
end

function VeloESP.Destroy()
	if VeloESP._Destroyed then
		return
	end

	for Index = #VeloESP._Watchers, 1, -1 do
		local Watch = VeloESP._Watchers[Index]
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

Conflict.Pending = Queue.new()
Conflict.PendingSet = WeakTable()

local PendingQueue = Conflict.Pending
local PendingSet = Conflict.PendingSet

local function QueueExternalHighlight(Highlight)
	if PendingSet[Highlight] ~= nil or HighlightRegistry[Highlight] ~= nil then
		return
	end

	PendingSet[Highlight] = true
	PendingQueue:Push(Highlight)
end

local function FlushExternalHighlights(Budget)
	for _ = 1, Budget do
		local Highlight = PendingQueue:Pop()

		if Highlight == nil then
			return
		end

		local IsPending = PendingSet[Highlight] == true
		PendingSet[Highlight] = nil

		if IsPending and Highlight.Parent ~= nil and Highlight:IsDescendantOf(workspace) then
			RegisterExternalHighlight(Highlight)
		end
	end
end

task.spawn(function()
	local Descendants = workspace:GetDescendants()

	for Index = 1, #Descendants do
		if VeloESP._Destroyed then
			return
		end

		local Descendant = Descendants[Index]

		if Descendant.ClassName == "Highlight" and VeloESP.Settings.HighlightConflictProtection ~= false then
			QueueExternalHighlight(Descendant)
		end

		if Index % 400 == 0 then
			task.wait()
		end
	end
end)

local ConflictSettings = VeloESP.Settings

table.insert(VeloESP._Connections, workspace.DescendantAdded:Connect(function(Descendant)
	if Descendant.ClassName == "Highlight" and ConflictSettings.HighlightConflictProtection ~= false then
		QueueExternalHighlight(Descendant)
	end
end))

table.insert(VeloESP._Connections, workspace.DescendantRemoving:Connect(function(Descendant)
	if Descendant.ClassName == "Highlight" then
		PendingSet[Descendant] = nil
		UnregisterExternalHighlight(Descendant)
	end
end))

table.insert(VeloESP._Connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	Camera = workspace.CurrentCamera
end))

local function ReapDeadObjects(Budget)
	local List = VeloESP._ObjectList
	local Count = #List

	if Count == 0 then
		VeloESP._ReapCursor = 1
		return
	end

	
	
	
	local SweepFrames = tonumber(VeloESP.Settings.ReapSweepFrames) or 90
	local Needed = math.ceil(Count / math.max(1, SweepFrames))

	if Needed > Budget then
		Budget = Needed
	end

	local Index = VeloESP._ReapCursor or 1

	if Index > Count then
		Index = 1
	end

	for _ = 1, math.min(Budget, Count) do
		local Object = List[Index]

		if Object == nil or Object.Destroyed == true then
			Index += 1
		else
			local Model = Object.CurrentSettings and Object.CurrentSettings.Model
			local Dead = typeof(Model) ~= "Instance"

			if not Dead then
				
				
				
				
				Dead = Model.Parent == nil or not Model:IsDescendantOf(DataModel)
			end

			if Dead then
				Object:Destroy()
				Count = #List
			else
				Index += 1
			end
		end

		if Count == 0 then
			Index = 1
			break
		end

		if Index > Count then
			Index = 1
		end
	end

	VeloESP._ReapCursor = Index
end

table.insert(VeloESP._Connections, RunService.Heartbeat:Connect(function()
	if VeloESP._Destroyed then
		return
	end
	local Settings = VeloESP.Settings
	FlushExternalHighlights(tonumber(Settings.HighlightScanPerFrame) or 24)
	ReapDeadObjects(tonumber(Settings.ReapPerFrame) or 6)
end))

table.insert(VeloESP._Connections, RunService.RenderStepped:Connect(function(DeltaTime)
	if VeloESP._Destroyed then
		return
	end

	local Settings = VeloESP.Settings
	VeloESP._Elapsed += DeltaTime
	local Elapsed = VeloESP._Elapsed

	Screen.BeginFrame()
	VeloESP._AnyOverlay = RefreshActiveOverlays()

	local ObjectList = VeloESP._UpdateList
	local Count = #ObjectList

	if Count == 0 then
		VeloESP._UpdateCursor = 1
		return
	end

	if Settings.Rainbow then
		VeloESP._RainbowColor = Color3.fromHSV(
			(os.clock() * Settings.RainbowSpeed) % 1,
			Settings.RainbowSaturation,
			Settings.RainbowValue
		)
	end

	local RateCache = VeloESP._RateCache

	if RateCache == nil then
		RateCache = table.create(4)
		VeloESP._RateCache = RateCache
	end

	RateCache[1] = tonumber(Settings.UpdateRate) or 0
	RateCache[2] = tonumber(Settings.FarDistance) or 650
	RateCache[3] = tonumber(Settings.FarUpdateRate) or 0
	RateCache[4] = tonumber(Settings.NearUpdateRate) or 0
	VeloESP._AnyRateLimit = RateCache[1] > 0 or RateCache[3] > 0 or RateCache[4] > 0

	local MaxPerFrame = tonumber(Settings.MaxPerFrame) or math.huge
	local FrameBudget = tonumber(Settings.FrameBudget) or 0
	local BudgetCheckInterval = math.max(1, tonumber(Settings.BudgetCheckInterval) or 8)
	local FrameStarted = FrameBudget > 0 and os.clock() or 0
	local BudgetCounter = 0
	local Updated = 0
	local Visited = 0
	local VisitLimit = Count
	local Index = VeloESP._UpdateCursor or 1

	if Index > Count then
		Index = 1
	end

	while Visited < VisitLimit and Count > 0 do
		local Object = ObjectList[Index]
		Visited += 1

		if Object == nil or Object.Destroyed == true then
			local Last = ObjectList[Count]
			ObjectList[Index] = Last
			ObjectList[Count] = nil
			Count -= 1

			if Last and Last ~= Object then
				Last._UpdateListIndex = Index
			end

			if Count == 0 then
				Index = 1
				break
			elseif Index > Count then
				Index = 1
			end
		else
			Object._UpdateListIndex = Index
			local ObjectDelta = Elapsed - (Object._LastUpdateTime or (Elapsed - DeltaTime))
			Object._LastUpdateTime = Elapsed
			Object:_Update(ObjectDelta)
			Updated += 1
			
			
			
			Count = #ObjectList
			if ObjectList[Index] == Object then
				Index += 1
			end
			if Count == 0 then
				Index = 1
				break
			end

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

	if next(VeloESP._SmoothObjects) ~= nil then
		for Object in pairs(VeloESP._SmoothObjects) do
			if Object.Destroyed == true then
				VeloESP._SmoothObjects[Object] = nil
			else
				Object:_PresentOverlays(DeltaTime)
			end
		end
	end
end))

Environment.VeloESP = VeloESP
return VeloESP
