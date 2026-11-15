extends SceneTree
var failures := 0
func _initialize():
 call_deferred("run")
func run():
 var camera := Camera3D.new()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=6
 camera.position=Vector3(0,3,10)
 root.add_child(camera)
 camera.look_at(Vector3(0,0.7,0))
 camera.make_current()
 var names=["DecorationBushSmall","DecorationBush","DecorationBushBig","DecorationBushForest","DecorationBushForestBig"]
 var helper=load("res://scripts/view/sprite_occlusion.gd").new()
 for i in names.size():
  var bush=load("res://scenes/world/%s.tscn"%names[i]).instantiate()
  root.add_child(bush)
  bush.scale=Vector3.ONE*1.4
  bush.position=camera.global_basis.x*(i-2)*2.0
  var sprite: SpriteBase3D=bush.canopy_sprite()
  var center: Vector3=helper.sprite_point(sprite,Vector2(0.5,0.5),camera)
  bush.update_holes({1:center},camera,0.2)
  if bush.hole_radius>=1.15 or bush._holes.size()!=1 or sprite.modulate.a!=1.0:
   failures+=1
   push_error("Bush cutout configuration failed: "+names[i])
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://reports/bush-dither-variants.png")
 var world=load("res://scenes/WorldView.tscn").instantiate()
 root.add_child(world)
 var state=load("res://scripts/simulation/game_state.gd").create_initial()
 var original=JSON.stringify(state)
 world.setup(state)
 var count: int=world._decoration_occluders.size()
 if count==0:
  failures+=1
  push_error("Decorative bushes not registered for occlusion")
 world.update_occlusion(camera,0.2)
 world.setup(state)
 if count!=world._decoration_occluders.size() or JSON.stringify(state)!=original:
  failures+=1
  push_error("Rebuild duplicates occluders or mutates state")
 world.free()
 print("%s bush dither: five variants, smaller holes, registration and rebuild" % ("PASS" if failures==0 else "FAIL"))
 quit(failures)
