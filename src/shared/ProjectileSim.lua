--!strict
-- Projectile motion shared by the server (authoritative) and the client (visuals).
-- Both sides step the same maths, and the server sends corrections for anything that
-- depends on the world (homing targets, bounces, sticking) so the two stay in sync.

local ProjectileSim = {}

ProjectileSim.Gravity = 98 -- studs/s^2 for gravity = 1
ProjectileSim.MaxSpeed = 420

export type State = {
	pos: Vector3,
	vel: Vector3,
	age: number,
	speed: number,
	gravity: number,
	homing: number,
	accelerate: number,
	erratic: number,
	orbit: boolean,
	orbitRadius: number,
	orbitAngle: number,
	orbitHeight: number,
	boomerangAt: number,
	returning: boolean,
	stuck: boolean,
	rng: Random,
}

export type Params = {
	pos: Vector3,
	dir: Vector3,
	speed: number,
	gravity: number?,
	homing: number?,
	accelerate: number?,
	erratic: number?,
	orbit: boolean?,
	orbitRadius: number?,
	orbitAngle: number?,
	boomerangAt: number?,
	seed: number?,
}

function ProjectileSim.new(p: Params): State
	return {
		pos = p.pos,
		vel = p.dir * p.speed,
		age = 0,
		speed = p.speed,
		gravity = p.gravity or 0,
		homing = p.homing or 0,
		accelerate = p.accelerate or 0,
		erratic = p.erratic or 0,
		orbit = p.orbit == true,
		orbitRadius = p.orbitRadius or 7,
		orbitAngle = p.orbitAngle or 0,
		orbitHeight = 1.5,
		boomerangAt = p.boomerangAt or 0,
		returning = false,
		stuck = false,
		rng = Random.new(p.seed or 1),
	}
end

-- casterPos: needed for orbit / boomerang. targetPos: current homing target, if any.
function ProjectileSim.step(s: State, dt: number, casterPos: Vector3?, targetPos: Vector3?)
	s.age += dt
	if s.stuck then
		return
	end

	if s.orbit then
		if casterPos then
			local angular = math.clamp(s.speed / math.max(s.orbitRadius, 1), 2, 9)
			s.orbitAngle += angular * dt
			local offset = Vector3.new(math.cos(s.orbitAngle), 0, math.sin(s.orbitAngle)) * s.orbitRadius
			local newPos = casterPos + offset + Vector3.new(0, s.orbitHeight, 0)
			local tangent = Vector3.new(-math.sin(s.orbitAngle), 0, math.cos(s.orbitAngle))
			s.vel = tangent * s.speed
			s.pos = newPos
		end
		return
	end

	if s.accelerate > 0 then
		s.speed = math.min(ProjectileSim.MaxSpeed, s.speed * (1 + s.accelerate * dt))
		if s.vel.Magnitude > 1e-3 then
			s.vel = s.vel.Unit * s.speed
		end
	end

	if s.boomerangAt > 0 and s.age >= s.boomerangAt and casterPos then
		s.returning = true
		local back = casterPos + Vector3.new(0, 1.5, 0) - s.pos
		if back.Magnitude > 0.01 then
			local desired = back.Unit * s.speed
			s.vel = s.vel:Lerp(desired, math.clamp(7 * dt, 0, 1))
		end
	elseif s.homing > 0 and targetPos then
		local to = targetPos - s.pos
		if to.Magnitude > 0.5 and s.vel.Magnitude > 1e-3 then
			local speed = s.vel.Magnitude
			local dir = s.vel.Unit:Lerp(to.Unit, math.clamp(s.homing * dt, 0, 1))
			if dir.Magnitude > 1e-3 then
				s.vel = dir.Unit * speed
			end
		end
	end

	if s.erratic > 0 and s.vel.Magnitude > 1e-3 then
		local axis = Vector3.new(s.rng:NextNumber(-1, 1), s.rng:NextNumber(-1, 1), s.rng:NextNumber(-1, 1))
		if axis.Magnitude > 1e-3 then
			local angle = (s.rng:NextNumber() - 0.5) * s.erratic * 9 * dt
			s.vel = CFrame.fromAxisAngle(axis.Unit, angle):VectorToWorldSpace(s.vel)
		end
	end

	if s.gravity ~= 0 then
		s.vel += Vector3.new(0, -ProjectileSim.Gravity * s.gravity * dt, 0)
	end

	s.pos += s.vel * dt
end

return ProjectileSim
