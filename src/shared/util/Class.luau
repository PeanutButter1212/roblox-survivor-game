--!strict
-- Class.luau
-- Tiny helper for OOP in Luau. Returns a fresh class table whose `.__index`
-- points at itself, so instances created with `setmetatable({}, MyClass)` inherit
-- the class's methods. Keeps the metatable boilerplate out of every module.

local Class = {}

-- Creates and returns a new, empty class table ready for `:method()` definitions
-- and `setmetatable({}, cls)` construction.
--
-- The `any` return is deliberate: the strict typechecker infers the returned table as
-- `{ __index: t1 }` and then rejects every `function MyClass:method()` defined on it.
-- Returning `any` opts these class tables out of that, which keeps `scripts/check.sh`
-- reporting real problems instead of ~250 lines of the same false positive.
function Class.new(): any
	local cls = {}
	cls.__index = cls
	return cls
end

return Class
