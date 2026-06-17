--!strict
-- Class.luau
-- Tiny helper for OOP in Luau. Returns a fresh class table whose `.__index`
-- points at itself, so instances created with `setmetatable({}, MyClass)` inherit
-- the class's methods. Keeps the metatable boilerplate out of every module.

local Class = {}

-- Creates and returns a new, empty class table ready for `:method()` definitions
-- and `setmetatable({}, cls)` construction.
function Class.new()
	local cls = {}
	cls.__index = cls
	return cls
end

return Class
