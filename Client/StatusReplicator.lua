local Signal = require(script.Signal)
local Status_Type = require(script.Status)
local Status, StatusClassFunction = Status_Type[1], Status_Type[2]

export type StatusContainer = {
	Container: any,
	Status: {Status_Type.Status},
	OnStatusAdded: Signal.Signal<any>,
	OnStatusRemoved: Signal.Signal<any>,
	Updated: Signal.Signal<any>,
	WaitForContainer: (self: StatusContainer) -> StatusContainer,
	FindClass: (self: StatusContainer, Class: string) -> Status_Type.Status,
	RemoveByClass: (self: StatusContainer, Class: string) -> (),
	Remove: (self: StatusContainer, ID: string) -> (),
	Add: (self: StatusContainer, Class: string, Properties: Status_Type.StatusProperty?) -> Status_Type.Status
}

export type Status = Status_Type.Status

local StatusReplicator: StatusContainer = {
	Status = {},
	Container = nil,
	OnStatusAdded = Signal.new(),
	OnStatusRemoved = Signal.new(),
	Updated = Signal.new(),
	WaitForContainer = nil,
	RemoveByClass = nil,
	Remove = nil,
	FindClass = nil,
	Add = nil
}

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local StatusRequest = ReplicatedStorage:WaitForChild('Requests'):WaitForChild('Status')

local IsServer = RunService:IsServer()
local IsClient = RunService:IsClient()

-- This function Add a new status with specified class and properties
function StatusReplicator:Add(Class: string, Properties: Status_Type.StatusProperty?)
	if not StatusReplicator.Container then
		return warn('Container is not loaded')
	end
	
	local StatusClass = Status.new(self, Class, Properties)

	StatusReplicator.Status[StatusClass.ID] = StatusClass
	StatusReplicator.OnStatusAdded:Fire(StatusClass)

	return StatusClass
end

-- This function Removes a Status by it's ID
function StatusReplicator:Remove(ID: string)
	local Status: Status_Type.Status = self.Container[self.ID]
	if Status then
		Status:Remove()
	end
end

-- This function Find a status by it's class
function StatusReplicator:FindClass(Class: string)
	local Status
	for _,v in StatusReplicator.Status do
		if v.Class == Class then
			Status = v
			break
		end
	end
	return Status
end

-- This function Removes a Status by it's class
function StatusReplicator:RemoveByClass(Class: string)
	local Status: Status_Type.Status = self:FindClass(Class)
	if Status then
		Status:Remove()
	end
end

-- This function waits until the container gets updated by the server
function StatusReplicator:WaitForContainer()
	repeat task.wait() until StatusReplicator.Container
	return StatusReplicator.Container
end

-- Handle status removals
StatusReplicator.OnStatusRemoved:Connect(function(Status)
	if not StatusReplicator.Status[Status.ID] then return end

	StatusReplicator.Status[Status.ID] = nil
end)

-- This will handle all the cross communication betwen server and client
StatusRequest.OnClientEvent:Connect(function(Request)
	local Status = Request.Status

	if Request.UpdateType == 'UpdateContainer' then
		StatusReplicator.Container = Status
		return
	end

	if Request.UpdateType == 'Clear' then
		StatusReplicator.Container = nil		
		for _,v in pairs(StatusReplicator.Status) do
			v:Remove()
		end
		return
	end

	if not StatusReplicator.Container then
		StatusReplicator:WaitForContainer()
	end

	if Request.UpdateType == 'Remove' then
		local Existing = StatusReplicator.Status[Status]
		if Existing then
			Existing:Remove()
		end
	end

	if Request.UpdateType == 'Update' then
		local Existing = StatusReplicator.Status[Status.ID]
		if Existing then
			for i,v in pairs(Status) do
				Existing[i] = v
			end
		else
			Status.Connections = {
				Updated = StatusReplicator.Updated,
				OnStatusRemoved = StatusReplicator.OnStatusRemoved
			}
			Status.Debris = StatusClassFunction.Debris
			Status.Remove = StatusClassFunction.Remove
			
			local proxy = setmetatable({index = Status}, {
				__index = function(k, index: string)
					local rtable = rawget(k, 'index')
					return rtable and rtable[index]
				end,
				__tostring = function(k)
					local rtable = rawget(k, 'index')
					local str_format = ("\n| [Class]: %s \n| [Disabled]: %s \n| [Value]: %s \n| [Domain]: %s\n")
					return str_format:format(rtable.Class, rtable.Disabled and '✓' or '✕', tostring(rtable.Value), rtable.Domain)
				end,
				__newindex = function(k, index: any, value: any)
					local rtable = rawget(k, 'index')

					rawset(rtable, index, value)

					if rtable.Connections then
						rtable.Connections.Updated:Fire(rtable)
					end
				end
			})
			
			StatusReplicator.Status[Status.ID] = proxy

			StatusReplicator.OnStatusAdded:Fire(StatusReplicator.Status[Status.ID])
		end
	end
end)

return StatusReplicator
