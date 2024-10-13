--!nocheck

local StatusHandler = {
	Containers = {}
}

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local StatusRequest = ReplicatedStorage:WaitForChild('Requests'):WaitForChild('Status')
local StatusReplicator = ReplicatedStorage:WaitForChild('StatusReplicator')

local Signal = require(StatusReplicator.Signal)
local Status_Type = require(StatusReplicator.Status)
local Status, StatusClassFunction = Status_Type[1], Status_Type[2]

local IsServer = RunService:IsServer()
local IsClient = RunService:IsClient()

export type StatusProperty = {
	Container: any,
	Status: {Status_Type.Status},
	OnStatusAdded: Signal.Signal<any>,
	OnStatusRemoved: Signal.Signal<any>,
	Updated: Signal.Signal<any>
}

export type StatusFunction = StatusProperty & {
	Add: (Class: string, Properties: Status_Type.StatusProperty) -> Status_Type.Status,
	Remove: (ID: string) -> (),
	FindClass: (Class: string) -> Status_Type.Status,
	RemoveByClass: (Class: string) -> (),
	GetStatusHash: () -> {Status_Type.Status}
}

local StatusFunction = {}
function StatusFunction:Add(Class: string, Properties: Status_Type.StatusProperty?)
	local StatusClass = Status.new(self, Class, Properties)
	
	self.Status[StatusClass.ID] = StatusClass
	self.OnStatusAdded:Fire(StatusClass)

	return StatusClass
end

function StatusFunction:Remove(ID: string)
	local Status: Status_Type.Status = self.Container[self.ID]
	if Status then
		Status:Remove()
	end
end

function StatusFunction:FindClass(Class: string)
	local Status
	for _,v in self.Status do
		if v.Class == Class then
			Status = v
			break
		end
	end
	return Status
end

function StatusFunction:GetStatusHash(IncludeDisabled: boolean)
	local Hash = {}

	for _, v in pairs(self.Status) do
		if v.Disabled and not IncludeDisabled then
			continue
		end

		Hash[v.Class] = true
	end

	return Hash
end

function StatusFunction:ListenAdded(Class: string, IncludeDisabled: boolean, Callback): RBXScriptConnection
	local Connection; Connection = self.OnStatusAdded:Connect(function(Status: Status_Type.Status)
		if Status.Class == Class then
			Connection:Disconnect()
			Callback(Status)
		end
	end)

	if StatusFunction:FindClass(Class, IncludeDisabled) then
		Connection:Disconnect()
		task.spawn(Callback, self:FindClass(Class, IncludeDisabled))
	end

	return Connection
end

local StunType = {
	Stun = {
		'Stun',
		'StunHeavy'
	},
	StunHeavy = {
		'StunHeavy'
	}
}

function StatusFunction:ListenStunAdded(Class: string, IncludeDisabled: boolean, Callback): RBXScriptConnection
	local Connection; Connection = self.OnStatusAdded:Connect(function(Status: Status_Type.Status)
		if StunType[Status.Class] and table.find(StunType[Status.Class], Status.Class) then
			Connection:Disconnect()
			Callback(Status)
		end
	end)

	if StatusFunction:FindClass(Class, IncludeDisabled) then
		Connection:Disconnect()
		task.spawn(Callback, self:FindClass(Class, IncludeDisabled))
	end

	return Connection
end

function StatusFunction:ListenRemoved(Class: string, IncludeDisabled: boolean, Callback): RBXScriptConnection
	local Connection; Connection = self.OnStatusRemoved:Connect(function(Status: Status_Type.Status)
		if Status.Class == Class then
			Callback(Status)
			Connection:Disconnect()
		end
	end)

	return Connection
end

function StatusFunction:ListenRemoving(Class: string, IncludeDisabled: boolean, Callback): RBXScriptConnection
	local Connection; Connection = self.OnStatusRemoving:Connect(function(Status: Status_Type.Status)
		if Status.Class == Class then
			Callback(Status)
			Connection:Disconnect()
		end
	end)

	return Connection
end

function StatusFunction:RemoveByClass(Class: string)
	local Status: Status_Type.Status = self:FindClass(Class)
	if Status then
		Status:Remove()
	end
end

function StatusHandler.new(Container: Instance, Overwrite: boolean): StatusFunction
	if not Container then
		return
	end

	if StatusHandler.Containers[Container] and not Overwrite then
		return StatusHandler.Containers[Container]
	end

	local IsPlayer = typeof(Container) == 'Instance' and Container.Parent and Players:GetPlayerFromCharacter(Container.Parent)
	local StatusFunction: StatusProperty = {
		Container = Container,
		Status = {},
		OnStatusAdded = Signal.new(),
		OnStatusRemoved = Signal.new(),
		Updated = Signal.new()
	}

	StatusHandler.Containers[Container] = setmetatable(StatusFunction, {__index = StatusFunction})

	if IsPlayer then
		StatusFunction.OnStatusRemoved:Connect(function(Status)
			if not StatusFunction.Status[Status.ID] then return end
			
			StatusFunction.Status[Status.ID] = nil
			StatusRequest:FireClient(IsPlayer, {
				UpdateType = 'Remove',
				Status = Status.ID
			})
		end)

		StatusFunction.OnStatusAdded:Connect(function(Status)
			StatusRequest:FireClient(IsPlayer, {
				UpdateType = 'Update',
				Status = {
					ID = Status.ID,
					Class = Status.Class,
					Value = Status.Value or false,
					Disabled = Status.Disabled or false,
					DebrisTime = Status.DebrisTime or nil,
					Expiration = Status.Expiration or nil,
					Domain = 'Server'
				}
			})
		end)

		StatusFunction.Updated:Connect(function(Status)
			StatusRequest:FireClient(IsPlayer, {
				UpdateType = 'Update',
				Status = {
					ID = Status.ID,
					Class = Status.Class,
					Value = Status.Value or false,
					Disabled = Status.Disabled or false,
					DebrisTime = Status.DebrisTime or nil,
					Expiration = Status.Expiration or nil,
					Domain = 'Server'
				}
			})
		end)

		StatusRequest:FireClient(IsPlayer, {
			UpdateType = 'Clear'
		})

		StatusRequest:FireClient(IsPlayer, {
			UpdateType = 'UpdateContainer',
			Status = Container
		})
	end

	return StatusFunction
end

function StatusHandler:WaitForContainer(Container: Instance?)
	repeat task.wait() until StatusHandler.Containers[Container]

	return StatusHandler.Containers[Container]
end

return StatusHandler
