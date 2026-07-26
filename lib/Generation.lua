local Generation = {}

type table = {
	[any]: any
}

--// NUEVO: FastlyParse (reemplazo de Roblox-parser)
local FastlyParse = loadstring(game:HttpGet('https://raw.githubusercontent.com/depthso/FastlyParse/refs/heads/main/dist/init.lua'))()

--// Cargar soporte para Roblox
FastlyParse:ImportPlatform("Roblox")

--// Modules
local Config
local Hook

local ThisScript = script

function Generation:Init(Configuration: table)
    local Modules = Configuration.Modules

	--// Modules
	Config = Modules.Config
	Hook = Modules.Hook
end

function Generation:SetSwapsCallback(Callback: (Interface: table) -> ())
	self.SwapsCallback = Callback
end

function Generation:GetBase(Module): string
	local Code = "-- Generated with sigma spy BOIIIIIIIII (+9999999 AURA)\n\n"

	--// Generate variables code con FastlyParse
	Code ..= Module:GenerateCodeSegment("Script")

	return Code
end

function Generation:GetSwaps()
	local Func = self.SwapsCallback
	local Swaps = {}

	local Interface = {}
	function Interface:AddSwap(Object: Instance, Data: table)
		if not Object then return end
		Swaps[Object] = Data
	end

	--// Invoke GetSwaps function
	Func(Interface)

	return Swaps
end

function Generation:PickVariableName()
	local Names = Config.VariableNames
	return Names[math.random(1, #Names)]
end

function Generation:NewParser()
	local VariableName = self:PickVariableName()

	--// Swaps
	local Swaps = self:GetSwaps()

	--// Load parser module con FastlyParse
	local Module = FastlyParse.new({
		VariableBase = VariableName,
		Swaps = Swaps,
		Platform = "Roblox"
	})

	return Module
end

type RemoteScript = {
	Remote: Instance,
	IsReceive: boolean?,
	Args: table,
	Method: string
}
function Generation:RemoteScript(Module, Data: RemoteScript): string
	local Remote = Data.Remote
	local IsReceive = Data.IsReceive
	local Args = Data.Args
	local Method = Data.Method

	local ClassName = Hook:Index(Remote, "ClassName")
	local IsNilParent = Hook:Index(Remote, "Parent") == nil
	
	--// Parse arguments con FastlyParse
	local ParsedArgs = Module:Parse(Args, {
		NoBrackets = true
	})
	
	--// Contar argumentos
	local ItemsCount = #Args

	--// Create remote variable con FastlyParse:Format
	local RemoteVariable = Module:Format(Remote)

	--// Make code
	local Code = self:GetBase(Module)
	
	--// Firesignal script for client recieves
	if IsReceive then
		local Second = ItemsCount == 0 and "" or `, {ParsedArgs}`
		local Signal = `{RemoteVariable}.{Method}`

		Code ..= `\n-- This data was received from the server`
		Code ..= `\nfiresignal({Signal}{Second})`
		return Code
	end
	
	--// Remote invoke script
	Code ..= `\n{RemoteVariable}:{Method}({ParsedArgs})`
	return Code
end

function Generation:ConnectionsTable(Signal: RBXScriptSignal): table
	local Connections = getconnections(Signal)
	local DataArray = {}

	for _, Connection in next, Connections do
		local Function = Connection.Function
		local Script = rawget(getfenv(Function), "script")

		--// Skip if self
		if Script == ThisScript then continue end

		--// Connection data
		local Data = {
			Function = Function,
			State = Connection.State,
			Script = Script
		}

		table.insert(DataArray, Data)
	end

	return DataArray
end

function Generation:TableScript(Table: table)
	local Module = self:NewParser()

	--// Parse arguments con FastlyParse
	local ParsedTable = Module:Parse(Table)

	--// Generate script
	local Code = self:GetBase(Module)
	Code ..= `\nreturn {ParsedTable}`

	return Code
end

return Generation