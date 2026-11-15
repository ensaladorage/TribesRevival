extends SceneTree
var failures:=0
func _initialize(): call_deferred("run")
func run():
 var world=load("res://scenes/WorldView.tscn").instantiate()
 root.add_child(world)
 var camera:=Camera3D.new()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=5
 root.add_child(camera)
 camera.position=Vector3(10,9.9,10)
 camera.look_at(Vector3(0,0.7,0))
 camera.make_current()
 var actor=load("res://scenes/actors/Gatherer.tscn").instantiate()
 world.add_child(actor)
 actor.set_meta("kind","gatherer")
 world._views["actor"]=actor
 var checks:=0
 var misplaced:=0
 for name in ["DecorationBushSmall","DecorationBush","DecorationBushBig","DecorationBushForest","DecorationBushForestBig"]:
  var bush=load("res://scenes/world/%s.tscn"%name).instantiate()
  world.add_child(bush)
  bush.scale=Vector3.ONE*1.4
  world._decoration_occluders.append(bush)
  for flip in [false,true]:
   bush.canopy_sprite().flip_h=flip
   for x in range(-8,9):
    for z in range(-8,9):
     actor.position=Vector3(x*0.15,0,z*0.15)
     bush.update_holes({},camera,1.0)
     world.update_occlusion(camera,1.0)
     if DisplayServer.get_name() != "headless" and name == "DecorationBushForestBig" and not flip and x == -4 and z == -4:
      await process_frame
      await RenderingServer.frame_post_draw
      root.get_texture().get_image().save_png("res://reports/bush-character-dither.png")
     for hole in bush._holes.values():
      checks+=1
      if not world._occlusion.covers(bush.canopy_sprite(),bush.canopy_region,PackedVector3Array([hole.center]),camera):
       misplaced+=1
  world._decoration_occluders.clear()
  bush.free()
 if checks==0 or misplaced>0:
  failures+=1
  push_error("Misplaced bush holes: %d / %d"%[misplaced,checks])
 world.free()
 camera.free()
 print("%s bush occlusion: %d actual actor overlaps, %d misplaced centers"%["PASS" if failures==0 else "FAIL",checks,misplaced])
 quit(failures)
