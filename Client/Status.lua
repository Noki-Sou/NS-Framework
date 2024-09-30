export type StatusProperty = {
	ID: string?,
	Class: string?,
	Value: any?,
	Disabled: boolean?,
	DebrisTime: number?,
	Expiration: number?,
	Domain: "Client"? | "Server"?,
	Connections: {Updated: BindableEvent, OnStatusRemoved: BindableEvent}?,
}

export type Status = StatusProperty & {
	Remove: (self: StatusProperty) -> (),
	Debris: (self: StatusProperty, ExpirationTime: number) -> (),
}

local HttpService = game:GetService('HttpService')
local RunService = game:GetService('RunService')

local IsServer = RunService:IsServer()
local IsClient = RunService:IsClient()

local StatusFunction = {}

function StatusFunction:Remove()
	self.Connections.OnStatusRemoved:Fire(self)
end

function StatusFunction:Debris(ExpirationTime: number)
	task.delay(ExpirationTime or 0, function()
		self:Remove()
	end)

	return self
end

local Status = {}

function Status.new(self, Class: string, Properties: StatusProperty)
	local Properties = Properties or {}

	local Properties: StatusProperty = {
		ID = HttpService:GenerateGUID(false),
		Class = Class,
		Value = Properties.Value or false,
		Disabled = Properties.Disabled or false,
		DebrisTime = Properties.DebrisTime or nil,
		Expiration = Properties.Expiration or nil,
		Domain = IsClient and 'Client' or 'Server',
		Connections = {OnStatusRemoved = self.OnStatusRemoved, Updated = self.Updated},
		Debris = StatusFunction.Debris,
		Remove = StatusFunction.Remove
	}

	local proxy = setmetatable({index = Properties}, {
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
				rtable.Connections.Updated:Fire(rtable, index, value)
			end
		end,
	})

	return proxy
end

return {Status, StatusFunction}
