--!strict
-- Shared type definitions for the spell system. No runtime logic lives here.

export type Recipe = {
	form: string,
	element: string?,
	mods: { string }?,
	trigger: string?,
	payload: Recipe?,
}

export type StatusDef = {
	kind: string, -- "Burn" | "Chill" | "Venom" | "Mark"
	dps: number?,
	duration: number,
	slow: number?,
	maxStacks: number?,
}

-- A compiled spell: every number the server needs to execute it and the client needs to draw it.
export type Spec = {
	name: string,
	form: string,
	element: string,
	kind: string, -- "Projectile" | "Beam" | "Nova" | "Chain" | "Meteor" | "Blink" | "Aegis" | "Wall"
	depth: number,

	-- economy
	mana: number,
	castDelay: number,
	recharge: number,
	hpCost: number,

	-- core numbers
	damage: number,
	directMult: number, -- 0 for forms that only hurt through explosions or zones
	speed: number,
	lifetime: number,
	size: number,
	gravity: number,
	count: number,
	spread: number,
	range: number,
	radius: number,

	-- projectile behaviour
	bounces: number,
	pierce: number,
	homing: number,
	explodeRadius: number,
	explodeMult: number,
	explodeOnExpire: boolean,
	stick: boolean,
	proximity: number,
	armTime: number,
	zoneOnImpact: boolean,
	zoneRadius: number,
	zoneDuration: number,
	zoneMult: number,
	chainJumps: number,
	chainRange: number,
	boomerangAt: number,
	blinkDistance: number,
	shieldAmount: number,
	shieldDuration: number,
	meteorHeight: number,
	orbit: boolean,
	orbitRadius: number,
	accelerate: number,
	erratic: number,
	phasing: boolean,
	vortex: number,
	echo: number,
	shatter: number,
	hold: number, -- seconds frozen in place before moving (Stasis); instant forms are delayed instead
	hover: number, -- projectile stops and hovers after this many seconds (Sentry)
	turretRate: number, -- a hovering sentry shoots `turretShot` at the nearest enemy this often
	turretRange: number,
	pull: number, -- drags nearby enemies toward the projectile while it flies (Magnetic, Black Hole)
	auraDps: number, -- damages enemies near the projectile while it flies (Tornado, Black Hole)
	auraRadius: number,
	auraLift: number, -- upward kick on each aura tick (Tornado)
	hydra: number, -- extra copies spawned every time it bounces
	fractal: number, -- generations of self-copies spawned when it ends
	skyfall: boolean, -- comes down from the sky onto the aim point instead of leaving the wand
	swap: boolean, -- the caster swaps places with whoever it hits
	chaos: boolean, -- every hit rolls a random damage multiplier and a random status
	rewind: number, -- sends whoever it hits back to where they were this many seconds ago
	wallWidth: number, -- Wall form: size of the conjured wall
	wallHeight: number,

	-- on-hit effects
	knockback: number,
	lift: number,
	crit: number,
	lifesteal: number,
	arc: number,
	status: StatusDef?,
	mark: number,

	-- trigger
	trigger: string?,
	payload: Spec?,
	shard: Spec?,
	turretShot: Spec?,
	fractalChild: Spec?,

	-- visuals
	color: { number },
	color2: { number },
}

export type Part = {
	id: string,
	name: string,
	category: string, -- "Form" | "Element" | "Modifier" | "Trigger"
	rarity: string,
	icon: string,
	description: string,
	color: { number },
	-- forms
	kind: string?,
	base: { [string]: any }?,
	-- elements
	elementApply: ((spec: Spec) -> ())?,
	-- modifiers
	apply: ((spec: Spec) -> ())?,
	post: ((spec: Spec) -> ())?,
	-- triggers
	triggerMana: number?,
	-- names
	adjective: string?,
	noun: string?,
}

return {}
