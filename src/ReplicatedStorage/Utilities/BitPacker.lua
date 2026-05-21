local ID_BITS = 0b0000_0000_0000_0000_0000_0111_1111_1111
local ORIENTATION_BITS = 0b0000_0000_0000_0111_1111_1000_0000_0000
local X_BITS = 0b1111_1111_1111_1000_0000_0000_0000_0000
local Y_BITS = 0b0000_0000_0000_0000_0001_1111_1111_1111
local Z_BITS = 0b0000_0011_1111_1111_1110_0000_0000_0000

local bitpacker = {}

function bitpacker.PackData(ID, orientation, X, Y, Z)
	local chunk1 = bit32.band(ID, ID_BITS)
	chunk1 += bit32.band(bit32.lshift(orientation, 11), ORIENTATION_BITS)
	chunk1 += bit32.band(bit32.lshift(X, 19), X_BITS)

	local chunk2 = bit32.band(Y, Y_BITS)
	chunk2 += bit32.band(bit32.lshift(Z, 13), Z_BITS)

	local buf = buffer.create(8)
	buffer.writeu32(buf, 0, chunk1)
	buffer.writeu32(buf, 4, chunk2)
	return buf
end

function bitpacker.UnpackData(buf)
	local chunk1 = buffer.readu32(buf, 0)
	local chunk2 = buffer.readu32(buf, 4)

	local ID = bit32.extract(chunk1, 0, 11)
	local orientation = bit32.extract(chunk1, 11, 8)
	local X = bit32.extract(chunk1, 19, 13)
	local Y = bit32.extract(chunk2, 0, 13)
	local Z = bit32.extract(chunk2, 13, 13)

	return ID, orientation, X, Y, Z
end

function bitpacker.Sign(n, bits)
	return (n >= 2 ^ (bits - 1)) and (n - 2 ^ bits) or n
end

function bitpacker.Unsign(n, bits)
	return (n < 0) and (n + 2 ^ bits) or n
end

return bitpacker
