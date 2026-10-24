extends "res://tools/benchmark_grass_issue13.gd"
## Additional per-frame ground-truth observer, not part of timed tick().
var near_missing_frames:=0
var checked_frames:=0
var longest_gap_s:=0.0
var current_gap_s:=0.0
var near_ready_s:=-1.0
var max_near_missing:=0

func sample_frame() -> float:
	var delta: float=await super.sample_frame()
	var bands:=visible_missing()
	var near_count: int=bands["0_48"]+bands["48_76"]
	if stage=="cold" and near_count==0 and near_ready_s<0:near_ready_s=(Time.get_ticks_usec()-start_usec)/1000000.0
	if stage=="travel_18mps_camera":
		checked_frames+=1;max_near_missing=maxi(max_near_missing,near_count)
		if near_count>0:
			near_missing_frames+=1;current_gap_s+=delta;longest_gap_s=maxf(longest_gap_s,current_gap_s)
		else:current_gap_s=0
	return delta

func tag() -> String:return super.tag()+"_continuous"

func delivery_result() -> Dictionary:
	return {"checked_frames":checked_frames,"near_missing_frames":near_missing_frames,"maximum_near_missing":max_near_missing,"longest_gap_s":longest_gap_s,"near_ready_s":near_ready_s,"range_m":76,"observer":"Every rendered frame; actual camera frustum versus requested nonempty-or-unknown 3D volumes. Conservative until sampled/baked. Not a pixel visibility/occlusion test."}
