-- The battle royale's storm circles: a plan of ever smaller circles, each inside the last, and where
-- the storm is at any moment of the match. The storm closes on each circle in turn: first the next
-- circle is revealed and the storm holds, then its wall moves in (the centre sliding over too).

local StormCircles = {}

export type Circle = { wait: number, shrink: number, radius: number, dps: number }

export type Stage = {
	holdUntil: number, -- seconds into the match
	shrinkUntil: number,
	fromCenter: Vector3,
	fromRadius: number,
	toCenter: Vector3,
	toRadius: number,
	dps: number,
}

export type State = {
	stage: number,
	shrinking: boolean,
	center: Vector3,
	radius: number,
	dps: number, -- what being outside costs right now
	nextCenter: Vector3,
	nextRadius: number,
}

-- `islandRadius` scales the circles; each new circle fits inside the one before and stays well
-- inside the coast.
function StormCircles.plan(circles: { Circle }, islandRadius: number, height: number, rng: Random): { Stage }
	local stages: { Stage } = {}
	local center = Vector3.new(0, height, 0)
	local radius = islandRadius + 60
	local t = 0
	for _, circle in circles do
		local toRadius = circle.radius * islandRadius
		local slack = math.max(0, radius - toRadius)
		local inland = math.max(0, islandRadius * 0.8 - toRadius)
		local toCenter = center
		for _ = 1, 30 do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(0, slack)
			local candidate = center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
			if Vector3.new(candidate.X, 0, candidate.Z).Magnitude <= inland then
				toCenter = candidate
				break
			end
		end
		local holdUntil = t + circle.wait
		local shrinkUntil = holdUntil + circle.shrink
		table.insert(stages, {
			holdUntil = holdUntil,
			shrinkUntil = shrinkUntil,
			fromCenter = center,
			fromRadius = radius,
			toCenter = toCenter,
			toRadius = toRadius,
			dps = circle.dps,
		})
		t = shrinkUntil
		center, radius = toCenter, toRadius
	end
	return stages
end

-- Where the storm is `elapsed` seconds into the match.
function StormCircles.at(stages: { Stage }, elapsed: number): State
	for i, s in stages do
		if elapsed < s.shrinkUntil then
			local previousDps = if i > 1 then stages[i - 1].dps else 0
			if elapsed < s.holdUntil then
				return {
					stage = i,
					shrinking = false,
					center = s.fromCenter,
					radius = s.fromRadius,
					dps = previousDps,
					nextCenter = s.toCenter,
					nextRadius = s.toRadius,
				}
			end
			local alpha = (elapsed - s.holdUntil) / math.max(0.001, s.shrinkUntil - s.holdUntil)
			return {
				stage = i,
				shrinking = true,
				center = s.fromCenter:Lerp(s.toCenter, alpha),
				radius = s.fromRadius + (s.toRadius - s.fromRadius) * alpha,
				dps = s.dps,
				nextCenter = s.toCenter,
				nextRadius = s.toRadius,
			}
		end
	end
	local last = stages[#stages]
	return {
		stage = #stages + 1,
		shrinking = false,
		center = last.toCenter,
		radius = last.toRadius,
		dps = last.dps,
		nextCenter = last.toCenter,
		nextRadius = last.toRadius,
	}
end

return StormCircles
