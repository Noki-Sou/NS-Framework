--!nocheck

--[[ Example Usage:

local Hitbox = require(ServerStorage.Hitbox)

-- Basic Usage

local Hit = Hitbox.new({
	Ignore = {},
	Include = workspace.Live,
	IncludeDead = true,
	Hitbox = 5,
	Debounce = 0.1,
	Lifetime = 0.1,
	Origin = RootPart.CFrame * CFrame.new(0,0,-4),
	Visualize = true
}):Cast():Connect(function(...)
	print(...)
end)

-- // Analysis: [
	HitAmount: Debounce / Lifetime (1),
	HitboxSize: 5 (Vector3.new(5,5,5))
]

-- MeshPart Usage

local Hit = Hitbox.new({
	Ignore = {},
	Include = workspace.Live,
	IncludeDead = true,
	Hitbox = WhirlwindMesh,
	Debounce = 0.1,
	Lifetime = 1,
	Origin = RootPart.CFrame * CFrame.new(0,0,-4),
	Visualize = true
}):Cast():Connect(function(...)
	print(...)
end)

-- // Analysis: [
	HitAmount: Debounce / Lifetime (10),
	HitboxSize: MeshPart.Size
]

-- Dynamic Usage
-- // With Dynamic hitbox, it will follow the part's position with a weld

local Hit = Hitbox.new({
	Ignore = {},
	Include = workspace.Live,
	IncludeDead = true,
	Hitbox = WhirlwindMesh,
	Debounce = 0.1,
	Lifetime = 1,
	Origin = RootPart,
	Offset = CFrame.new(0,0,-3)
	Visualize = true
}):Cast():Connect(function(...)
	print(...)
end)

-- // Analysis: [
	HitAmount: Debounce / Lifetime (10),
	HitboxSize: MeshPart.Size
]

]]

export type Character = Model & {
	Humanoid: Humanoid,
	HumanoidRootPart: Part
}

export type HitboxProperties = {
	Ignore: {Character},
	Include: Instance,
	IncludeDead: boolean,
	Hitbox: BasePart | Vector3 | number,
	Shape: "Sphere" | "Block" | "Cylinder",
	Debounce: number,
	Lifetime: number,
	Origin: Part | CFrame | Vector3,
	Offset: CFrame | Vector3,
	Visualize: boolean
}

export type HitboxModule = HitboxProperties & {
	Cast: (self) -> RBXScriptSignal
}

local Signal = {}
Signal.__index = Signal

function Signal:Connect(Callback)
	local Event = self.Signal

	if not Event then
		Event = Instance.new('BindableEvent')
		self.Signal = Event
	end

	return Event.Event:Connect(function(...)
		Callback(...)
	end)
end

function Signal:Fire(...)
	local Event: BindableEvent = self.Signal

	if Event then
		Event:Fire(...)
	end
end

local Hitbox = {} :: {
	new: (HitboxProperties: HitboxProperties) -> HitboxModule,
	HitboxProperties: {}
}

Hitbox.HitboxProperties = {
	Transparency = 1,
	CanCollide = false,
	Anchored = true,
	Color = Color3.fromRGB(255, 0, 0),
	Material = Enum.Material.Neon,
	CastShadow = false
}

Hitbox.__index = Hitbox

function Hitbox:Scan()
	local Connect_ret = self.Hitbox.Touched:Connect(function() end)
	local TouchingParts = self.Hitbox:GetTouchingParts()
	Connect_ret:Disconnect()
	
	return TouchingParts
end

function Hitbox:Cast()
	self.Hitbox.Parent = workspace:FindFirstChild('Hitboxes') or workspace
	
	local Scan: {Character} = self.Include:GetChildren()
	local Targets: {Character} = {}
	local Hitted = {}
	
	for i,v in pairs(Scan) do
		local Humanoid: Humanoid = v:FindFirstChild('Humanoid')
		if not Humanoid then
			continue
		end
		
		if Humanoid.Health <= 0 and not self.IncludeDead then
			continue
		end
		
		if table.find(self.Ignore, v) then
			continue
		end
		
		table.insert(Targets, v)
	end
	
	task.spawn(function()
		local StartTime = tick()
		while tick() - StartTime <= self.Lifetime do
			local Parts = self:Scan()
			for i,v in pairs(Parts) do
				local Target: Character = v.Parent

				if not table.find(Targets, Target) then
					continue
				end

				if Hitted[Target] then
					continue
				end

				task.spawn(function()
					repeat task.wait() until self.OnHit.Signal
					self.OnHit:Fire(Target)
				end)

				Hitted[Target] = true
				task.delay(self.Debounce, function()
					Hitted[Target] = nil
				end)
			end

			task.wait()
		end

		self.Hitbox:Destroy()
	end)
	
	return self.OnHit
end

function Hitbox.new(Properties: HitboxProperties)
	local Properties = {
		Ignore = Properties.Ignore or {},
		Include = Properties.Include or workspace,
		IncludeDead = Properties.IncludeDead or false,
		Hitbox = Properties.Hitbox or 3,
		Shape = Properties.Shape or "Block",
		Debounce = Properties.Debounce or 0.1,
		Lifetime = Properties.Lifetime or 0.1,
		Origin = Properties.Origin,
		Offset = Properties.Offset or CFrame.new(0,0,0),
		Visualize = Properties.Visualize or false
	}
	
	if not Properties.Origin then
		return warn('Hitbox "Origin" is missing.')
	end
	
	local self = setmetatable(Properties, Hitbox)
	self.OnHit = setmetatable({}, Signal)
	self.Ended = setmetatable({}, Signal)
	
	-- // Hitbox Check

	if typeof(self.Hitbox) == 'Instance' then
		self.Hitbox = self.Hitbox:Clone()
	end
	
	if typeof(self.Hitbox) == 'number' then
		local v = self.Hitbox
		
		self.Hitbox = Vector3.new(v, v, v)
	end
	
	if typeof(self.Hitbox) == 'Vector3' then
		local Size = self.Hitbox
		
		self.Hitbox = Instance.new('Part')
		self.Hitbox.Size = Size
		self.Hitbox.Shape = self.Shape
	end
	
	-- // Apply Hitbox Properties
	
	for i,v in pairs(Hitbox.HitboxProperties) do
		self.Hitbox[i] = v
	end
	
	-- // Origin Check
	
	if typeof(self.Origin) == "Vector3" then
		self.Origin = CFrame.new(self.Origin)
	end
	
	if typeof(self.Origin) == "Instance" then
		self.Hitbox.Anchored = false
		
		if typeof(self.Offset) == 'Vector3' then
			self.Offset = CFrame.new(self.Offset)
		end
		
		local Weld = Instance.new('Weld')
		Weld.Part0 = self.Origin
		Weld.Part1 = self.Hitbox
		Weld.C1 = self.Offset
		Weld.Parent = self.Origin
	end
	
	if typeof(self.Origin) == 'CFrame' then
		self.Hitbox.CFrame = self.Origin
	end
	
	if self.Visualize then
		self.Hitbox.Transparency = 0.7
	end
	
	return self
end

return Hitbox