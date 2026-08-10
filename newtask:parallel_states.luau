--!optimize 2
--!strict

local States  = {};
local _0x023  = SharedTable.new();

function States.IsParallel(): (boolean)
		
	local Changed = pcall(function()
		_0x023.__env = true;
	end);
	
	return not Changed;
end;


return setmetatable({}, {
	__index    = States,
	__newindex = function(): () 
		error("Cannot write new index to protected table", 2);
	end,
	__metatable = "The metatable is locked",
});
