extends RefCounted

# Original raised ornament, batched with the production wardrobe by bone.
var wardrobe: RefCounted
func _init(owner: RefCounted) -> void: wardrobe = owner

func cord(bone: String,points: PackedVector3Array,radius: float,at: Vector3 = Vector3.ZERO,axis: Basis = Basis.IDENTITY) -> void:
	var builder = SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for i in range(points.size()):
		var tangent = (points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		var normal = tangent.cross(Vector3.FORWARD).normalized()
		if normal.length_squared()<0.1: normal = tangent.cross(Vector3.RIGHT).normalized()
		var binormal = tangent.cross(normal).normalized()
		var ring_points = PackedVector3Array()
		for j in range(6):
			var angle = j*TAU/6.0
			ring_points.append(points[i]+(normal*cos(angle)+binormal*sin(angle))*radius)
		rings.append(ring_points)
	for i in range(rings.size()-1):
		for j in range(6):
			for pair in [[0,0],[1,0],[0,1],[0,1],[1,0],[1,1]]:
				builder.set_uv(Vector2(float(j+pair[1])/6.0,float(i+pair[0])/float(rings.size()-1)))
				builder.add_vertex(rings[i+pair[0]][(j+pair[1])%6])
	builder.generate_normals()
	builder.generate_tangents()
	builder.index()
	wardrobe.piece(bone,builder.commit(),at,"gold",axis)

func plate_point(angle: float,v: float,radius: float,length_value: float,taper: float) -> Vector3:
	var r = radius*lerpf(1.0,taper,v)+pow(absf(v-0.5)*2.0,12.0)*0.0025
	var ridge = pow(maxf(cos(angle),0.0),16.0)*radius*0.09
	return Vector3(sin(angle)*r,(v-0.5)*length_value,cos(angle)*r*0.86+ridge)+Vector3(sin(angle),0,cos(angle))*0.0018

func plate(bone: String,radius: float,length_value: float,at: Vector3,axis: Basis,taper: float,arc: float) -> void:
	for v in [0.045,0.955]:
		var edge = PackedVector3Array()
		for i in range(49): edge.append(plate_point((float(i)/48.0-0.5)*arc,v,radius,length_value,taper))
		cord(bone,edge,0.0016,at,axis)
	if length_value<0.10: return
	for side in [-1.0,1.0]:
		var stem = PackedVector3Array()
		for i in range(25):
			var t = float(i)/24.0
			stem.append(plate_point(side*(0.13+sin(t*PI)*0.20),lerpf(0.14,0.86,t),radius,length_value,taper))
		cord(bone,stem,0.0010,at,axis)
		for branch in range(3):
			var curl = PackedVector3Array()
			for i in range(21):
				var t = float(i)/20.0
				curl.append(plate_point(side*(0.35+0.26*sin(t*TAU*0.88)*(1.0-t*0.78)),0.28+branch*0.20+0.065*cos(t*TAU*0.88)*(1.0-t*0.78),radius,length_value,taper))
			cord(bone,curl,0.0010,at,axis)

func lion(bone: String,at: Vector3,size_value: float = 0.044) -> void:
	wardrobe.sphere(bone,size_value,at,"steel",Vector3(1,1,0.21))
	wardrobe.ring(bone,size_value*0.98,size_value*0.065,at+Vector3(0,0,size_value*0.16),"gold",Basis(Vector3.RIGHT,PI*0.5))
	for i in range(16):
		var a = i*TAU/16.0
		wardrobe.sphere(bone,size_value*0.22,at+Vector3(sin(a),cos(a),0.29)*size_value*0.70,"gold",Vector3(0.65,1.6,0.35))
	wardrobe.sphere(bone,size_value*0.54,at+Vector3(0,0.05,0.30)*size_value,"gold",Vector3(0.88,1.13,0.42))
	for side in [-1.0,1.0]:
		wardrobe.sphere(bone,size_value*0.16,at+Vector3(side*0.38,0.42,0.35)*size_value,"gold",Vector3(1,1.15,0.5))
		wardrobe.sphere(bone,size_value*0.065,at+Vector3(side*0.20,0.12,0.53)*size_value,"dark",Vector3(1.2,0.55,0.4))
		wardrobe.sphere(bone,size_value*0.20,at+Vector3(side*0.13,-0.13,0.54)*size_value,"gold",Vector3(1,0.80,0.55))
	wardrobe.sphere(bone,size_value*0.12,at+Vector3(0,-0.02,0.64)*size_value,"dark",Vector3(1.1,0.65,0.40))
	wardrobe.sphere(bone,size_value*0.22,at+Vector3(0,-0.34,0.40)*size_value,"gold",Vector3(0.75,0.65,0.45))
