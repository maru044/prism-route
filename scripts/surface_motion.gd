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
	# Only retry motion blocked by a near-vertical edge, not ordinary slopes.
	var blocked:=false
	for i in body.get_slide_collision_count():
		var hit:=body.get_slide_collision(i)
		if hit.get_normal().y<cos(body.floor_max_angle) and hit.get_normal().dot(motion.normalized())<-.1:
			blocked=true;break
	if not blocked:return
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
	if landing.get_normal().y<cos(body.floor_max_angle):return
	var target:=forward;target.origin+=landing.get_travel()
	var rise:=target.origin.y-start.origin.y
	# A same-height landing also resolves a spurious seam edge. Require a
	# supported landing; do not turn this into a jump across a real drop.
	if rise< -margin*2 or rise>max_step_height+margin:return
	# The downward sweep already stops before penetration. A zero-motion
	# recovery query here would incorrectly reject valid floor contact.
	body.global_transform=target
	body.set_meta("surface_steps",int(body.get_meta("surface_steps",0))+1)
	body.velocity=Vector3(0,-.5,0)
	body.move_and_slide()
	body.velocity.x=wanted.x;body.velocity.z=wanted.z
