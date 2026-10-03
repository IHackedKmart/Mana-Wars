--!strict
-- Small vector helpers used by hit detection on the server and effects on the client.

local Geometry = {}

-- Closest distance between segment p1->q1 and segment p2->q2.
-- Returns the distance and the parameter (0..1) along the first segment.
function Geometry.segmentSegment(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3): (number, number)
	local d1 = q1 - p1
	local d2 = q2 - p2
	local r = p1 - p2
	local a = d1:Dot(d1)
	local e = d2:Dot(d2)
	local f = d2:Dot(r)
	local s, t
	local EPS = 1e-6
	if a <= EPS and e <= EPS then
		return (p1 - p2).Magnitude, 0
	end
	if a <= EPS then
		s = 0
		t = math.clamp(f / e, 0, 1)
	else
		local c = d1:Dot(r)
		if e <= EPS then
			t = 0
			s = math.clamp(-c / a, 0, 1)
		else
			local b = d1:Dot(d2)
			local denom = a * e - b * b
			if denom ~= 0 then
				s = math.clamp((b * f - c * e) / denom, 0, 1)
			else
				s = 0
			end
			t = (b * s + f) / e
			if t < 0 then
				t = 0
				s = math.clamp(-c / a, 0, 1)
			elseif t > 1 then
				t = 1
				s = math.clamp((b - c) / a, 0, 1)
			end
		end
	end
	local c1 = p1 + d1 * s
	local c2 = p2 + d2 * t
	return (c1 - c2).Magnitude, s
end

-- Rotates a direction around the world Y axis (and then a local right axis) by degrees.
function Geometry.fan(direction: Vector3, yawDegrees: number, pitchDegrees: number?): Vector3
	local cf = CFrame.lookAt(Vector3.zero, direction)
	local rotated = cf * CFrame.Angles(math.rad(pitchDegrees or 0), math.rad(yawDegrees), 0)
	return rotated.LookVector
end

-- Random direction inside a cone of `degrees` around `direction`.
function Geometry.jitter(direction: Vector3, degrees: number, rng: Random): Vector3
	if degrees <= 0 then
		return direction
	end
	local cf = CFrame.lookAt(Vector3.zero, direction)
	local angle = math.rad(degrees) * math.sqrt(rng:NextNumber())
	local roll = rng:NextNumber(0, math.pi * 2)
	return (cf * CFrame.Angles(0, 0, roll) * CFrame.Angles(angle, 0, 0)).LookVector
end

function Geometry.reflect(v: Vector3, normal: Vector3): Vector3
	return v - normal * (2 * v:Dot(normal))
end

function Geometry.flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Geometry.safeUnit(v: Vector3, fallback: Vector3?): Vector3
	if v.Magnitude < 1e-4 then
		return fallback or Vector3.new(0, 0, -1)
	end
	return v.Unit
end

return Geometry
