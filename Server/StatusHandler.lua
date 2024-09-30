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

export type StatusContainer = StatusProperty & {
	Add: (Class: string, Properties: Status_Type.StatusProperty) -> Status_Type.Status,
	Remove: (ID: string) -> (),
	FindClass: (Class: string) -> Status_Type.Status,
	RemoveByClass: (Class: string) -> ()
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
	for _,v in self.Container do
		if v.Class == Class then
			Status = v
			break
		end
	end
	return Status
end

function StatusFunction:RemoveByClass(Class: string)
	local Status: Status_Type.Status = self:FindClass(Class)
	if Status then
		Status:Remove()
	end
end

function StatusHandler.new(Container: Instance, Overwrite: boolean): StatusContainer
	if not Container then
		return
	end

	if StatusHandler.Containers[Container] and not Overwrite then
		return StatusHandler.Containers[Container]
	end

	local IsPlayer = typeof(Container) == 'Instance' and Container.Parent and Players:GetPlayerFromCharacter(Container.Parent)
	local StatusContainer: StatusProperty = {
		Container = Container,
		Status = {},
		OnStatusAdded = Signal.new(),
		OnStatusRemoved = Signal.new(),
		Updated = Signal.new()
	}

	StatusHandler.Containers[Container] = setmetatable(StatusContainer, {__index = StatusFunction})

	if IsPlayer then
		StatusContainer.OnStatusRemoved:Connect(function(Status)
			if not StatusContainer.Status[Status.ID] then return end
			
			StatusContainer.Status[Status.ID] = nil
			StatusRequest:FireClient(IsPlayer, {
				UpdateType = 'Remove',
				Status = Status.ID
			})
		end)

		StatusContainer.OnStatusAdded:Connect(function(Status)
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

		StatusContainer.Updated:Connect(function(Status)
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

	return StatusContainer
end

function StatusHandler:WaitForContainer(Container: Instance?)
	repeat task.wait() until StatusHandler.Containers[Container]

	return StatusHandler.Containers[Container]
end

return StatusHandler
