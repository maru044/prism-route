extends RefCounted
## Step over small grounded discontinuities using full-body swept queries.
## All three legs (up, forward, down) must be clear; no airborne gap jumping.

static func move(body: CharacterBody3D,delta: float,max_step_height: float) -> void:
	var start:=body.global_transform
	var wanted:=body.velocity
	var grounded:=body.is_on_floor()
	body.move_and_slide()
	if max_step_height<=0 or not grounded or wanted.y>0:return
	var motion:=Vector3(wanted.x,0,wanted.z)*delta
	if motion.length_squared()<0.000001:return
	var actual:=body.global_position-start.origin;actual.y=0
	if actual.dot(motion.normalized())>=motion.length()*0.9:return
	if body.is_on_floor():
		# Ordinary slope projection reduces horizontal travel even with no
		# obstacle. Compare against that projected motion before retrying a step.
		var floor_motion:=motion.slide(body.get_floor_normal());floor_motion.y=0.
		if actual.dot(motion.normalized())>=floor_motion.dot(motion.normalized())*.9:return
	# Jolt can report only an upward floor normal at a stair seam even when
	# horizontal motion is blocked. Validate the full up/forward/down route
	# instead of requiring a vertical contact normal before trying the step.
	var margin:=body.safe_margin
	var lift:=max_step_height+margin*2
	var ceiling:=KinematicCollision3D.new()
	if body.test_move(start,Vector3.UP*lift,ceiling,margin,false):
		lift=maxf(0.0,ceiling.get_travel().y-margin)
	if lift<margin*3:return
	var elevated:=start;elevated.origin.y+=lift
	if body.test_move(elevated,motion,null,margin,false):return
	var forward:=elevated;forward.origin+=motion
	var landing:=KinematicCollision3D.new()
	if not body.test_move(forward,Vector3.DOWN*(lift+margin*3),landing,margin,false):return
	var support:=_landing_support(body,landing,motion.normalized())
	if support.is_empty():
		# At the rounded capsule/step corner, slide projection can erase all
		# horizontal speed. Preserve the request while the clear sweep is valid
		# so acceleration can reach a walkable contact on the next frames.
		body.velocity.x=wanted.x;body.velocity.z=wanted.z
		return
	var target:=forward;target.origin+=landing.get_travel()
	if support.has("position"):
		# Fully clear the sharp riser rather than repeatedly sliding back from
		# a shallow capsule-corner contact at low walking speed.
		var bottom:=INF
		for shape in body.get_children():
			if shape is CollisionShape3D and not shape.disabled:
				var bounds: AABB=shape.global_transform*shape.shape.get_debug_mesh().get_aabb()
				bottom=minf(bottom,bounds.position.y)
		var foot_offset:=body.global_position.y-bottom if is_finite(bottom) else 0.
		target.origin.y=maxf(target.origin.y,support.position.y+foot_offset+margin)
	var rise:=target.origin.y-start.origin.y
	# A same-height landing also resolves a spurious seam edge. Require a
	# supported landing; do not turn this into a jump across a real drop.
	if rise< -margin*2 or rise>minf(max_step_height+margin,lift):return
	# The downward sweep already stops before penetration. A zero-motion
	# recovery query here would incorrectly reject valid floor contact.
	body.global_transform=target
	body.set_meta("surface_steps",int(body.get_meta("surface_steps",0))+1)
	# Keep the sweep landing: a second floor-snapped move can pull the capsule
	# back onto the lower tread before it has crossed the rounded stair edge.
	body.velocity=Vector3(wanted.x,0.,wanted.z)

static func _landing_support(body: CharacterBody3D,hit: KinematicCollision3D,direction: Vector3) -> Dictionary:
	if hit.get_normal().y>=cos(body.floor_max_angle):return {"walkable":true}
	# Capsule corner normals at a sharp riser are not the supporting triangle's
	# slope. Confirm the actual top face just inside the contact before stepping.
	var contact:=hit.get_position()+direction*.006
	var query:=PhysicsRayQueryParameters3D.create(contact+Vector3.UP*.025,contact-Vector3.UP*.025,body.collision_mask)
	query.exclude=[body.get_rid()]
	var support:=body.get_world_3d().direct_space_state.intersect_ray(query)
	return support if not support.is_empty() and support.normal.y>=cos(body.floor_max_angle) else {}
