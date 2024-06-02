--!nocheck

-- // FullName: ServerStorage.StatusHandler
-- // Type: Server Module (Server Only)

--[[ Example Usage

-- // SERVER

local StatusHandler = require(ServerStorage.StatusHandler)
local Container = StatusHandler:New(Humanoid)

Container:Add("Speed", {Value = 10})

-- // CLIENT

local StatusReplicator = require(ServerStorage.StatusReplicator)
StatusReplicator:WaitForContainer()

RunService.RenderStepped:Connect(function()
	local Speed = 16
	local StatusHash = Status:GetStatusHash()
	
	if StatusHash.Speed then
		Speed += StatusReplicator:FindClass('Speed').Value
	end

	Humanoid.WalkSpeed = Speed
end)

]]

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local HttpService = game:GetService('HttpService')
local Requests = ReplicatedStorage:WaitForChild('Requests')
local ReplicatedStatus = Requests:WaitForChild('Status')

export type Type_Status = {
	ID: string,
	Class: string,
	Value: any,
	Created: number,
	Disabled: boolean,
	Remove: (self) -> nil,
	Debris: (self, Lifetime: number) -> Type_Status
}

export type StatusContainer = {
	Add: (self, Class: string, Properties: {}) -> Type_Status,
	FindClass: (self, Class: string, IncludeDisabeld: boolean) -> Type_Status,
	FindValue: (self, Value: any, IncludeDisabeld: boolean) -> Type_Status,
	GetStatusHash: (self) -> {[any]: string},
	ListenAdded: (self, Class: string, IncludeDisabeld: boolean) -> nil,
	ListenRemoved: (self, Class: string, IncludeDisabeld: boolean) -> nil,
	ListenRemoving: (self, Class: string, IncludeDisabeld: boolean) -> nil,
	OnStatusAdded: RBXScriptSignal,
	OnStatusRemoved: RBXScriptSignal,
	OnStatusRemoving: RBXScriptSignal
}

local module = {
	StatusContainers = {}
}

local Signal = {}
function Signal:Connect(Callback)
	local Event = self.Signal

	if not Event then
		Event = Instance.new('BindableEvent')
		self.Signal = Event
	end

	return Event.Event:Connect(function(Status: Type_Status)
		Callback(Status)
	end)
end

function Signal:Fire(Status: Type_Status)
	local Event: BindableEvent = self.Signal

	if Event then
		Event:Fire(Status)
	end
end

function module:New(Container: Humanoid): StatusContainer
	if module.StatusContainers[Container] then
		return module.StatusContainers[Container]
	end
	
	local StatusContainer = {
		Player = game:GetService('Players'):GetPlayerFromCharacter(Container.Parent),
		Container = Container,
		Effects = {}
	}

	function StatusContainer:Add(Class: string, Properties): Type_Status
		local Properties = Properties or {}

		local Status = {
			ID = HttpService:GenerateGUID(false),
			Class = Class,
			Value = Properties.Value or true,
			Disabled = Properties.Disabled or false,
			Domain = 'Client'
		}

		function Status:Remove()
			if not StatusContainer.Effects[self.ID] then return end

			if StatusContainer.OnStatusRemoved then
				StatusContainer.OnStatusRemoved:Fire(self.index)
			end

			StatusContainer.Effects[self.ID] = nil
		end

		function Status:Debris(Lifetime: number): Type_Status
			if StatusContainer.OnStatusRemoving then
				StatusContainer.OnStatusRemoving:Fire(self.index)
			end
			
			task.delay(Lifetime, function()
				self:Remove()
			end)

			return self
		end

		local MetatableSet = {
			__index = function(k, i)
				local rtable = rawget(k, "index")
				return rtable and rtable[i]
			end,
			__newindex = function(k, i, v)
				local rtable = rawget(k, "index")
				if rtable then
					local val = rtable[i]
					rtable[i] = v
					if (not val or val ~= v) and StatusContainer.OnStatusAdded then
						StatusContainer.OnStatusAdded:Fire(rtable)
					end
				end
			end
		}

		local Status = setmetatable({index = Status}, MetatableSet) :: Type_Status

		StatusContainer.Effects[Status.ID] = Status

		if StatusContainer.OnStatusAdded then
			StatusContainer.OnStatusAdded:Fire(Status.index)
		end

		return Status :: Type_Status
	end

	function StatusContainer:AddMany(Classes: {string}): Type_Status
		local Statuses = {}

		for i,v in pairs(Classes) do
			table.insert(Statuses,StatusContainer:Add(v))
		end

		return unpack(Statuses)
	end

	function StatusContainer:FindClass(Class: string, IncludeDisabled: boolean): Type_Status
		for _, v in pairs(self.Effects) do
			if v.Class ~= Class then
				continue
			end

			if v.Disabled and not IncludeDisabled then
				continue
			end

			return v
		end

		return nil
	end

	function StatusContainer:FindValue(Value: any, IncludeDisabled: boolean): Type_Status
		for _, v in pairs(self.Effects) do
			if v.Value ~= Value then
				continue
			end

			if v.Disabled and not IncludeDisabled then
				continue
			end

			return v
		end

		return nil
	end

	function StatusContainer:GetStatusHash(IncludeDisabled: boolean): {string}
		local Hash = {}

		for _, v in pairs(self.Effects) do
			if v.Disabled and not IncludeDisabled then
				continue
			end

			Hash[v.Class] = true
		end

		return Hash
	end
	
	function StatusContainer:ListenAdded(Class: string, IncludeDisabled: boolean, Callback)
		local Connection;Connection = StatusContainer.OnStatusAdded:Connect(function(Status: Type_Status)
			if Status.Class == Class then
				Callback(Status)
				Connection:Disconnect()
			end
		end)
	end

	function StatusContainer:ListenRemoved(Class: string, IncludeDisabled: boolean, Callback)
		local Connection;Connection = StatusContainer.OnStatusRemoved:Connect(function(Status: Type_Status)
			if Status.Class == Class then
				Callback(Status)
				Connection:Disconnect()
			end
		end)
	end

	function StatusContainer:ListenRemoving(Class: string, IncludeDisabled: boolean, Callback)
		local Connection;Connection = StatusContainer.OnStatusRemoving:Connect(function(Status: Type_Status)
			if Status.Class == Class then
				Callback(Status)
				Connection:Disconnect()
			end
		end)
	end

	StatusContainer.OnStatusAdded = setmetatable({},{__index = Signal})
	StatusContainer.OnStatusRemoved = setmetatable({},{__index = Signal})
	StatusContainer.OnStatusRemoving = setmetatable({},{__index = Signal})

	if StatusContainer.Player then
		StatusContainer.OnStatusAdded:Connect(function(Status: Type_Status)
			ReplicatedStatus.Update:FireClient(StatusContainer.Player,{
				UpdateType = 'Add',
				Status = {
					ID = Status.ID,
					Class = Status.Class,
					Value = Status.Value,
					Disabled = Status.Disabled
				}
			})
		end)

		StatusContainer.OnStatusRemoved:Connect(function(Status: string)
			ReplicatedStatus.Update:FireClient(StatusContainer.Player,{
				UpdateType = 'Remove',
				Status = Status.ID
			})
		end)
	end

	module.StatusContainers[Container] = StatusContainer

	return StatusContainer
end

function module:WaitForContainer(Container: Humanoid): StatusContainer
	repeat
		task.wait()
	until module.StatusContainers[Container]

	return module.StatusContainers[Container]
end

return module
