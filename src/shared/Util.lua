local Util = {}

-- Create an instance: Util.make("Frame", { Size = ..., Parent = ... }, { children... })
function Util.make(className, props, children)
	local inst = Instance.new(className)
	local parent
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Util.corner(radius)
	return Util.make("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function Util.stroke(color, thickness, transparency)
	return Util.make("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Util.flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

function Util.isFiniteVector(v)
	return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z
		and math.abs(v.X) < 1e5 and math.abs(v.Y) < 1e5 and math.abs(v.Z) < 1e5
end

function Util.now()
	return workspace:GetServerTimeNow()
end

return Util
