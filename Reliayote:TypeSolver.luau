--!optimize 2
--!strict

--[[
	i dont know why its called TypeSolver but yes why not
]]

local TypeSolver = {};


TypeSolver.__index = TypeSolver;
TypeSolver.__newindex = function() return error("Reliayote.TypeSolver metadata cannot be modified"); end;
TypeSolver.__tostring = function() return "Reliayote, TypeSolver"; end;

--[[Compares object's and given potential type]]
TypeSolver.IsA = function(Object: any, Potential: string): (boolean)
	return (typeof(Object) == Potential);
end;

--[[Checks if object is nil or not]]
TypeSolver.IsNull = function(Object: any): (boolean)
	return (Object == nil);
end;

--[[Same as TypeSolver.IsA but strictly checking, if arguments are missing - throws an exception]]
TypeSolver.StrictIsA = function(Object: any, Potential: string): (boolean)

	if Potential ~= nil then
		return (typeof(Object) == Potential);
	end;

	return error(string.format("%s, missing arguments: #1 %s, #2 %s", tostring(TypeSolver), tostring(Object), tostring(Potential)));
end;

--[[Checks if object matches one of the given types in array]]
TypeSolver.IsManyA = function(Object: any, Potentials: {string}): (boolean)
	local objType = typeof(Object);
	for i = 1, #Potentials do
		if objType == Potentials[i] then 
			return true; 
		end;
	end;
	return false;
end;

--[[Safely checks if object is a Roblox Instance and matches the given class name]]
TypeSolver.IsInstanceA = function(Object: Instance, ClassName: string): (boolean)
	if typeof(Object) == "Instance" then
		return Object:IsA(ClassName);
	end;
	return false;
end;

--[[Validates table structure against a dictionary of types]]
TypeSolver.StructureMatches = function(Table: any, Schema: {[string]: string}): (boolean)
	if typeof(Table) ~= "table" then return false; end;
	for key, expectedType in Schema do
		if typeof(Table[key]) ~= expectedType then 
			return false; 
		end;
	end;
	return true;
end;

return setmetatable({}, TypeSolver);
