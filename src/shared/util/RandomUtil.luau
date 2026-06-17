--!strict
-- RandomUtil.luau
-- Shared randomness helpers so weighted rolls (rarities, drops) live in one place.

local RandomUtil = {}

-- Picks one entry from an ordered list using each entry's `weight` field.
-- Higher weight = more likely. Returns the chosen entry (the table itself).
function RandomUtil.weightedPick<T>(entries: { T & { weight: number } }): T
	local total = 0
	for _, entry in entries do
		total += entry.weight
	end

	local roll = math.random() * total
	for _, entry in entries do
		roll -= entry.weight
		if roll <= 0 then
			return entry
		end
	end

	-- Floating-point fallback: return the last entry.
	return entries[#entries]
end

-- Returns a random element from a plain array (uniform chance), or nil if empty.
function RandomUtil.pick<T>(array: { T }): T?
	if #array == 0 then
		return nil
	end
	return array[math.random(#array)]
end

-- Returns a shuffled shallow copy of `array` (Fisher-Yates). Leaves the original
-- untouched so callers can reuse source lists.
function RandomUtil.shuffled<T>(array: { T }): { T }
	local copy = table.clone(array)
	for i = #copy, 2, -1 do
		local j = math.random(i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

return RandomUtil
