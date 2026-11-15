extends SceneTree
var failures := 0
func _initialize():
 call_deferred("run")
func run():
 var camera := Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 4
 camera.position = Vector3(0,0,10)
 root.add_child(camera)
 camera.make_current()
 var tree = load("res://scenes/world/Tree.tscn").instantiate()
 root.add_child(tree)
 for mesh in tree.find_children("*", "MeshInstance3D", true, false): mesh.visible=false
 var sprite: AnimatedSprite3D = tree.canopy_sprite()
 sprite.stop()
 var img := Image.create(8,8,false,Image.FORMAT_RGBA8)
 img.fill(Color.GREEN)
 var frames := SpriteFrames.new()
 frames.add_frame("default",ImageTexture.create_from_image(img))
 sprite.sprite_frames=frames
 sprite.animation="default"
 sprite.transform=Transform3D.IDENTITY
 sprite.offset=Vector2.ZERO
 sprite.pixel_size=0.5
 tree.update_holes({1:Vector3.ZERO},camera,1.0)
 await process_frame
 await RenderingServer.frame_post_draw
 var capture := root.get_texture().get_image()
 var inner_green:=0
 var outer_missing:=0
 var edge_green:=0
 var edge_missing:=0
 var height:=capture.get_height()
 var width:=capture.get_width()
 for y in height:
  for x in width:
   var point:=Vector2(x+0.5-width/2.0,height/2.0-y-0.5)*4.0/height
   var r:=point.length()
   var color:=capture.get_pixel(x,y)
   var green:=color.g>0.9 and color.r<0.1
   if r<0.9 and green: inner_green+=1
   if r>1.7 and absf(point.x)<1.9 and absf(point.y)<1.9 and not green: outer_missing+=1
   if r>1.3 and r<1.5:
    if green: edge_green+=1
    else: edge_missing+=1
 if inner_green>0 or outer_missing>0 or edge_green==0 or edge_missing==0:
  failures+=1
  push_error("Invalid dither: %s" % [str([inner_green,outer_missing,edge_green,edge_missing])])
 capture.save_png("res://reports/dither-pixel-test.png")
 tree.free()
 camera.free()
 print("%s dither pixels: empty center, opaque exterior, mixed edge" % ("PASS" if failures==0 else "FAIL"))
 quit(failures)
