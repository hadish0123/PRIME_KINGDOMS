extends RefCounted

# Original raised ornament, batched with the production wardrobe by bone.
var owner_ref: WeakRef
var wardrobe: RefCounted:
	get: return owner_ref.get_ref()
func _init(owner: RefCounted) -> void: owner_ref = weakref(owner)

func cord(bone: String,points: PackedVector3Array,radius: float,at: Vector3 = Vector3.ZERO,axis: Basis = Basis.IDENTITY,surface: String = "gold") -> void:
	var builder = SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_smooth_group(0)
	var rings: Array[PackedVector3Array] = []
	for i in range(points.size()):
		var tangent = (points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		var normal = tangent.cross(Vector3.FORWARD).normalized()
		if normal.length_squared()<0.1: normal = tangent.cross(Vector3.RIGHT).normalized()
		var binormal = tangent.cross(normal).normalized()
		var ring_points = PackedVector3Array()
		for j in range(4):
			var angle = j*TAU/4.0
			ring_points.append(points[i]+(normal*cos(angle)+binormal*sin(angle))*radius)
		rings.append(ring_points)
	for i in range(rings.size()-1):
		for j in range(4):
			for pair in [[0,0],[1,0],[0,1],[0,1],[1,0],[1,1]]:
				builder.set_uv(Vector2(float(j+pair[1])/4.0,float(i+pair[0])/float(rings.size()-1)))
				builder.add_vertex(rings[i+pair[0]][(j+pair[1])%4])
	builder.generate_normals()
	builder.generate_tangents()
	builder.index()
	wardrobe.piece(bone,builder.commit(),at,surface,axis)

func plate_point(angle: float,v: float,radius: float,length_value: float,taper: float) -> Vector3:
	return wardrobe.shell_point(angle,v,radius,length_value,taper)+Vector3(sin(angle),0,cos(angle))*0.0018

func plate(bone: String,radius: float,length_value: float,at: Vector3,axis: Basis,taper: float,arc: float) -> void:
	for v in [0.045,0.955]:
		var edge = PackedVector3Array()
		for i in range(33): edge.append(plate_point((float(i)/32.0-0.5)*arc,v,radius,length_value,taper))
		cord(bone,edge,0.0016,at,axis)
	if length_value<0.10: return
	for side in [-1.0,1.0]:
		var stem = PackedVector3Array()
		for i in range(17):
			var t = float(i)/16.0
			stem.append(plate_point(side*(0.13+sin(t*PI)*0.20),lerpf(0.14,0.86,t),radius,length_value,taper))
		cord(bone,stem,0.0010,at,axis)
		for branch in range(3):
			var curl = PackedVector3Array()
			for i in range(15):
				var t = float(i)/14.0
				curl.append(plate_point(side*(0.35+0.26*sin(t*TAU*0.88)*(1.0-t*0.78)),0.28+branch*0.20+0.065*cos(t*TAU*0.88)*(1.0-t*0.78),radius,length_value,taper))
			cord(bone,curl,0.0010,at,axis)

func relief_height(x: float,y: float) -> float:
	var r = sqrt(x*x+y*y)
	var dome = sqrt(maxf(0.0,1.0-r*r))*0.075
	var brow = exp(-pow((absf(x)-0.23)/0.17,2)-pow((y-0.22)/0.10,2))*0.090
	var sockets = exp(-pow((absf(x)-0.24)/0.12,2)-pow((y-0.10)/0.055,2))*0.070
	var bridge = exp(-pow(x/0.13,2)-pow((y-0.08)/0.27,2))*0.13
	var muzzle = exp(-pow((absf(x)-0.16)/0.20,2)-pow((y+0.19)/0.14,2))*0.13
	var chin = exp(-pow(x/0.23,2)-pow((y+0.37)/0.12,2))*0.06
	var mouth = exp(-pow(x/0.22,2)-pow((y+0.285)/0.022,2))*0.06
	return 0.07+dome+brow-sockets+bridge+muzzle+chin-mouth

func lion(bone: String,at: Vector3,size_value: float = 0.044) -> void:
	# A continuous carved relief: brows, recessed eyes, muzzle and a pointed
	# radiating mane. Its silhouette and shading do not rely on stacked balls.
	wardrobe.sphere(bone,size_value,at,"steel",Vector3(1,1,0.10))
	wardrobe.ring(bone,size_value*0.97,size_value*0.040,at+Vector3(0,0,size_value*0.13),"gold",Basis(Vector3.RIGHT,PI*0.5))
	var mane = SurfaceTool.new()
	mane.begin(Mesh.PRIMITIVE_TRIANGLES)
	mane.set_smooth_group(0)
	for leaf in range(18):
		var angle = float(leaf)/18.0*TAU
		for row in range(5):
			for col in range(3):
				for pair in [[0,0],[1,0],[0,1],[0,1],[1,0],[1,1]]:
					var t = float(row+pair[0])/5.0
					var u = float(col+pair[1])/3.0
					var curl = angle+sin(t*PI)*0.13*(1.0 if leaf%2 else -1.0)
					var r = lerpf(0.34,0.90,t)
					var width_value = sin(t*PI)*0.10
					var lateral = (u-0.5)*2.0*width_value
					mane.set_uv(Vector2(float(leaf)/18.0+u/18.0,t))
					mane.add_vertex(Vector3(sin(curl)*r+cos(curl)*lateral,cos(curl)*r-sin(curl)*lateral,0.12+sin(t*PI)*0.075*sin(u*PI))*size_value)
	mane.generate_normals()
	mane.generate_tangents()
	mane.index()
	wardrobe.piece(bone,mane.commit(),at,"gold")
	var face = SurfaceTool.new()
	face.begin(Mesh.PRIMITIVE_TRIANGLES)
	face.set_smooth_group(0)
	for row in range(18):
		for col in range(18):
			var x_center = (float(col)+0.5)/18.0*1.08-0.54
			var y_center = (float(row)+0.5)/18.0*1.05-0.49
			if pow(x_center/0.54,2)+pow((y_center-0.035)/0.525,2)>1.0: continue
			for pair in [[0,0],[1,0],[0,1],[0,1],[1,0],[1,1]]:
				var x = float(col+pair[1])/18.0*1.08-0.54
				var y = float(row+pair[0])/18.0*1.05-0.49
				var h = relief_height(x,y)
				face.set_uv(Vector2((x+0.54)/1.08,(y+0.49)/1.05))
				face.add_vertex(Vector3(x,y,h)*size_value)
	face.generate_normals()
	face.generate_tangents()
	face.index()
	wardrobe.piece(bone,face.commit(),at,"gold")
	for direction in [-1.0,1.0]:
		var eye = SurfaceTool.new()
		eye.begin(Mesh.PRIMITIVE_TRIANGLES)
		eye.set_smooth_group(0)
		for point in [Vector2(-0.10,0),Vector2(0,0.029),Vector2(0.10,0),Vector2(-0.10,0),Vector2(0.10,0),Vector2(0,-0.019)]:
			var x = direction*(0.24+point.x)
			var y = 0.10+point.y
			eye.set_uv(Vector2.ZERO)
			eye.add_vertex(Vector3(x,y,relief_height(x,y)+0.001)*size_value)
		eye.generate_normals()
		eye.index()
		wardrobe.piece(bone,eye.commit(),at,"dark")
