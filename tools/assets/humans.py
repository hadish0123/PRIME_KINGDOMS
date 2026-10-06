"""Build game-ready clothed CC0 humans and original skeletal motion as GLB.

This is a standalone data converter, not MakeHuman application code. Source
mesh/morph/weights/garment pins live in sources.json. The mesh retains real
anatomy, UV seams, fitted clothes, eyes and hair; helper geometry is excluded.
All locomotion is in place. Two-bone IK keeps stance feet level while the
controller supplies movement. No binary model or external runtime is needed
to reproduce the generated assets.
"""
import array
import json
import math
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[2]
CACHE = ROOT / 'tools/assets/cache/human'
OUTPUT = ROOT / 'client/assets/humans'


def add(a, b): return [a[i] + b[i] for i in range(3)]
def sub(a, b): return [a[i] - b[i] for i in range(3)]
def mul(a, k): return [v * k for v in a]
def dot(a, b): return sum(a[i] * b[i] for i in range(3))
def cross(a, b): return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
def length(a): return math.sqrt(dot(a, a))
def unit(a): return mul(a, 1/max(length(a), 1e-12))


def quat_mul(a, b):
    av, bv = a[:3], b[:3]
    return add(add(mul(bv, a[3]), mul(av, b[3])), cross(av, bv)) + [a[3]*b[3]-dot(av, bv)]


def quat_inverse(q): return [-q[0], -q[1], -q[2], q[3]]


def align(a, b):
    a, b = unit(a), unit(b)
    c = cross(a, b)
    q = c + [1+dot(a, b)]
    n = math.sqrt(sum(v*v for v in q))
    if n < 1e-8: return [1., 0., 0., 0.]
    return [v/n for v in q]


def axis(axis_number, radians):
    q = [0., 0., 0., math.cos(radians/2)]
    q[axis_number] = math.sin(radians/2)
    return q


def load_obj(path):
    vertices, uvs, faces = [], [], []
    group = ''
    for line in path.read_text().splitlines():
        values = line.split()
        if not values: continue
        if values[0] == 'v': vertices.append(list(map(float, values[1:4])))
        elif values[0] == 'vt': uvs.append([float(values[1]), 1-float(values[2])])
        elif values[0] == 'g': group = ' '.join(values[1:])
        elif values[0] == 'f':
            face = []
            for token in values[1:]:
                ids = token.split('/')
                face.append((int(ids[0])-1, int(ids[1])-1 if len(ids)>1 and ids[1] else 0))
            for i in range(1, len(face)-1): faces.append((group, [face[0], face[i], face[i+1]]))
    return vertices, uvs, faces


class GLB:
    def __init__(self):
        self.binary = bytearray()
        self.image_ids = {}
        self.doc = {'asset': {'version': '2.0', 'generator': 'PRIME KINGDOMS human pipeline 0.5'},
                    'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': [{'name': 'Human', 'children': []}],
                    'bufferViews': [], 'accessors': [], 'meshes': [], 'skins': [], 'materials': [],
                    'images': [], 'textures': [], 'samplers': [{'magFilter': 9729, 'minFilter': 9987}],
                    'animations': []}

    def view(self, data):
        while len(self.binary)%4: self.binary.append(0)
        result = len(self.doc['bufferViews'])
        self.doc['bufferViews'].append({'buffer': 0, 'byteOffset': len(self.binary), 'byteLength': len(data)})
        self.binary.extend(data)
        return result

    def accessor(self, values, kind, component=5126, bounds=False):
        size = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[kind]
        flat = values if size == 1 else [x for v in values for x in v]
        packed = array.array({5126: 'f', 5123: 'H', 5125: 'I'}[component], flat).tobytes()
        item = {'bufferView': self.view(packed), 'componentType': component, 'count': len(flat)//size, 'type': kind}
        if bounds:
            item['min'] = [min(flat[i::size]) for i in range(size)]
            item['max'] = [max(flat[i::size]) for i in range(size)]
        self.doc['accessors'].append(item)
        return len(self.doc['accessors'])-1

    def texture(self, image):
        key = str(image)
        if key in self.image_ids: return self.image_ids[key]
        tex = len(self.doc['textures'])
        self.doc['images'].append({'bufferView': self.view(image.read_bytes()), 'mimeType': 'image/png'})
        self.doc['textures'].append({'source': len(self.doc['images'])-1, 'sampler': 0})
        self.image_ids[key] = tex
        return tex

    def material(self, name, color, roughness=0.8, image=None, alpha=False, metallic=0, normal=None):
        item = {'name': name, 'doubleSided': alpha, 'pbrMetallicRoughness': {
            'baseColorFactor': color, 'metallicFactor': metallic, 'roughnessFactor': roughness}}
        if image:
            tex = self.texture(image)
            item['pbrMetallicRoughness']['baseColorTexture'] = {'index': tex}
        if normal: item['normalTexture'] = {'index': self.texture(normal), 'scale': 0.6}
        if alpha: item.update({'alphaMode': 'MASK', 'alphaCutoff': 0.4})
        self.doc['materials'].append(item)
        return len(self.doc['materials'])-1

    def mesh(self, name, vertices, uvs, faces, weights, materials):
        normals = [[0., 0., 0.] for _ in vertices]
        for _, face in faces:
            a, b, c = (vertices[v] for v, uv in face)
            n = cross(sub(b, a), sub(c, a))
            for v, uv in face: normals[v] = add(normals[v], n)
        normals = [unit(n) for n in normals]
        grouped = {}
        for material, face in faces: grouped.setdefault(material, []).append(face)
        primitives = []
        for material, triangles in grouped.items():
            unique, positions, normal, texcoords, joints, influence, indices = {}, [], [], [], [], [], []
            for face in triangles:
                for v, uv in face:
                    key = (v, uv)
                    if key not in unique:
                        unique[key] = len(positions)
                        positions.append(vertices[v]); normal.append(normals[v]); texcoords.append(uvs[uv] if uvs else [0., 0.])
                        w = sorted(weights[v].items(), key=lambda x: x[1], reverse=True)[:4]
                        w += [(0, 0.)]*(4-len(w))
                        total = max(sum(x[1] for x in w), 1e-9)
                        joints.append([x[0] for x in w]); influence.append([max(0., x[1])/total for x in w])
                    indices.append(unique[key])
            primitives.append({'attributes': {'POSITION': self.accessor(positions, 'VEC3', bounds=True),
                'NORMAL': self.accessor(normal, 'VEC3'), 'TEXCOORD_0': self.accessor(texcoords, 'VEC2'),
                'JOINTS_0': self.accessor(joints, 'VEC4', 5123), 'WEIGHTS_0': self.accessor(influence, 'VEC4')},
                'indices': self.accessor(indices, 'SCALAR', 5125), 'material': materials[material]})
        self.doc['meshes'].append({'name': name, 'primitives': primitives})
        self.doc['nodes'].append({'name': name, 'mesh': len(self.doc['meshes'])-1, 'skin': 0})
        self.doc['nodes'][0]['children'].append(len(self.doc['nodes'])-1)

    def save(self, path):
        self.doc['buffers'] = [{'byteLength': len(self.binary)}]
        text = json.dumps(self.doc, separators=(',', ':')).encode()
        text += b' '*((-len(text))%4)
        self.binary.extend(b'\0'*((-len(self.binary))%4))
        path.write_bytes(struct.pack('<4sII', b'glTF', 2, 28+len(text)+len(self.binary)) +
                         struct.pack('<I4s', len(text), b'JSON') + text +
                         struct.pack('<I4s', len(self.binary), b'BIN\0') + self.binary)


def proxy(path, base, weights, transform):
    original, uvs, faces = load_obj(path.with_suffix('.obj'))
    mapping, deleted, reading = [], set(), False
    for line in path.read_text().splitlines():
        s = line.split()
        if not s or s[0].startswith('#'): continue
        if s[0] == 'verts': reading = True; continue
        if s[0] == 'delete_verts': reading = False; continue
        if s[0][0].isdigit():
            if reading:
                if len(s) == 1: mapping.append(([int(s[0])], [1.], [0., 0., 0.]))
                else: mapping.append((list(map(int, s[:3])), list(map(float, s[3:6])), list(map(float, s[6:9]))))
            else:
                index = 0
                while index < len(s):
                    token = s[index]
                    if index+2 < len(s) and s[index+1] == '-':
                        deleted.update(range(int(token), int(s[index+2])+1))
                        index += 3
                        continue
                    if ':' in token:
                        a, b = map(int, token.split(':')); deleted.update(range(a, b+1))
                    else: deleted.add(int(token))
                    index += 1
        elif reading: reading = False
    assert len(mapping) == len(original), f'Proxy mapping differs: {path}'
    vertices, influences = [], []
    for ids, blend, offset in mapping:
        p = offset[:]
        w = {}
        for v, b in zip(ids, blend):
            p = add(p, mul(base[v], b))
            for bone, value in weights[v].items(): w[bone] = w.get(bone, 0.) + max(0., b)*value
        vertices.append(transform(p)); influences.append(w or {0: 1.})
    return vertices, uvs, faces, influences, deleted


def solve_limb(head, middle, end, target, bend):
    upper, lower = length(sub(middle, head)), length(sub(end, middle))
    ray = sub(target, head); distance = min(length(ray), upper+lower-0.001)
    direction = unit(ray)
    along = (upper*upper-lower*lower+distance*distance)/(2*max(distance, 0.001))
    height = math.sqrt(max(0., upper*upper-along*along))
    normal = unit(sub(bend, mul(direction, dot(direction, bend))))
    knee = add(add(head, mul(direction, along)), mul(normal, height))
    top = align(sub(middle, head), sub(knee, head))
    bottom_world = align(sub(end, middle), sub(target, knee))
    bottom = quat_mul(quat_inverse(top), bottom_world)
    return top, bottom, quat_inverse(bottom_world)


def animate(glb, heads, bone_ids):
    identity = [0., 0., 0., 1.]
    clips = [('idle', 3.2), ('walk', 1.0), ('run', 0.68), ('jump', 0.28),
             ('fall', 0.8), ('land', 0.26), ('guard', 4.0), ('work', 2.6),
             ('draw', 0.85), ('sheathe', 0.85), ('attack', 0.72),
             ('lie_down', 0.65), ('prone', 2.8), ('crawl', 1.4),
             ('stand_up', 0.65), ('ride', 1.0)]
    for clip, duration in clips:
        count = int(duration*30)+1
        times = [i*duration/(count-1) for i in range(count)]
        tracks = {bone: [] for bone in bone_ids}
        root_positions = []
        for t in times:
            cycle = t/duration
            moving = clip in ('walk', 'run')
            running = clip == 'run'
            bob = (0.024 if running else 0.008)*math.cos(4*math.pi*cycle) if moving else 0.002*math.sin(cycle*math.tau)
            crouch = 0.10*math.sin(math.pi*cycle) if clip == 'land' else (0.07 if clip in ('jump', 'fall') else 0.)
            displacement = [0., bob-crouch, 0.]
            poses = {bone: identity[:] for bone in bone_ids}
            poses['spine03'] = axis(0, -0.1 if running else 0.015*math.sin(cycle*math.tau))
            poses['head'] = axis(1, 0.14*math.sin(cycle*math.tau) if clip == 'guard' else 0.018*math.sin(cycle*math.tau))
            lying = clip in ('lie_down', 'prone', 'crawl', 'stand_up')
            if lying:
                amount = cycle if clip == 'lie_down' else (1-cycle if clip == 'stand_up' else 1.)
                amount = amount*amount*(3-2*amount)
                poses['root'] = axis(0, math.pi*0.5*amount)
                displacement = [0., -0.72*amount, 0.]
                poses['head'] = axis(0, -0.25*amount)
            elif clip == 'attack':
                poses['spine03'] = quat_mul(axis(1, -0.30*math.sin(cycle*math.tau)), axis(0, -0.07*math.sin(cycle*math.pi)))
            elif clip == 'ride':
                displacement = [0., 0.012*math.sin(cycle*math.tau), 0.]
            for side, sign in [('L', 1), ('R', -1)]:
                phase = (cycle+(0 if side == 'L' else 0.5))%1
                stance = 0.50 if running else 0.62
                stride = 0.62 if running else 0.37
                swing = max(0., (phase-stance)/(1-stance))
                z = stride*(0.5-phase/stance) if phase < stance else stride*(-0.5+swing*swing*(3-2*swing))
                lift = (0.20 if running else 0.10)*math.sin(math.pi*swing)
                thigh, calf, foot = ['upperleg01.'+side, 'lowerleg01.'+side, 'foot.'+side]
                target = heads[foot][:]
                if moving: target = add(target, [0., lift-bob, z])
                elif clip in ('jump', 'fall'):
                    target = add(target, [0., 0.10 if side=='L' else 0.06, 0.14 if side=='L' else -0.06])
                elif lying:
                    target = add(target, [sign*0.015, 0.04, 0.07*math.sin(phase*math.tau) if clip == 'crawl' else 0.])
                elif clip == 'ride':
                    target = add(heads[thigh], [sign*0.29, -0.57, 0.15])
                else: target = sub(target, displacement)
                poses[thigh], poses[calf], poses[foot] = solve_limb(heads[thigh], heads[calf], heads[foot], target, [sign*0.25 if clip == 'ride' else 0., 0., 1.])
                arm, forearm, hand = ['upperarm01.'+side, 'lowerarm01.'+side, 'wrist.'+side]
                shoulder = heads[arm]
                target = add(shoulder, [sign*0.05, -0.50, 0.025])
                if moving:
                    swing = math.sin(phase*math.tau)
                    target = add(shoulder, [sign*0.065, -0.41 if running else -0.49, -(0.22 if running else 0.15)*swing])
                elif clip in ('jump', 'fall'):
                    target = add(shoulder, [sign*0.12, -0.30, 0.22])
                elif clip == 'work':
                    target = add(shoulder, [-sign*0.06, -0.29+0.035*math.sin(cycle*math.tau), 0.23])
                elif clip in ('draw', 'sheathe') and side == 'R':
                    phase_value = cycle if clip == 'draw' else 1-cycle
                    start = add(shoulder, [-0.05, -0.50, 0.025])
                    grip = [0.16, 1.03, 0.22]
                    finish = add(shoulder, [-0.10, -0.37, 0.25])
                    a, b, blend = (start, grip, phase_value/0.46) if phase_value < 0.46 else (grip, finish, (phase_value-0.46)/0.54)
                    blend = blend*blend*(3-2*blend)
                    target = add(mul(a,1-blend),mul(b,blend))
                elif clip == 'attack' and side == 'R':
                    target = add(shoulder, [-0.08-0.20*math.sin(cycle*math.pi), -0.18+0.23*math.sin(cycle*math.tau), 0.37+0.13*math.sin(cycle*math.pi)])
                elif lying:
                    target = add(shoulder,[sign*0.11,-0.25+0.10*math.sin(phase*math.tau) if clip == 'crawl' else -0.38,0.19])
                elif clip == 'ride':
                    target = add(shoulder,[-sign*0.045,-0.28,0.30])
                poses[arm], poses[forearm], poses[hand] = solve_limb(heads[arm], heads[forearm], heads[hand], target, [sign*0.25, 0., -1.])
                # Feet counter-rotate to keep their soles flat; wrists follow the
                # forearms. Counter-rotating hands froze them in the original T pose.
                poses[hand] = identity[:]
            for bone in bone_ids: tracks[bone].append(poses[bone])
            root_positions.append(add(heads['root'], displacement))
        animation = {'name': clip, 'samplers': [], 'channels': []}
        input_id = glb.accessor(times, 'SCALAR', bounds=True)
        for bone, quaternions in tracks.items():
            sampler = len(animation['samplers'])
            animation['samplers'].append({'input': input_id, 'output': glb.accessor(quaternions, 'VEC4'), 'interpolation': 'LINEAR'})
            animation['channels'].append({'sampler': sampler, 'target': {'node': bone_ids[bone], 'path': 'rotation'}})
        animation['samplers'].append({'input': input_id, 'output': glb.accessor(root_positions, 'VEC3'), 'interpolation': 'LINEAR'})
        animation['channels'].append({'sampler': len(animation['samplers'])-1, 'target': {'node': bone_ids['root'], 'path': 'translation'}})
        glb.doc['animations'].append(animation)


def build(role):
    base, uvs, all_faces = load_obj(CACHE/'core/3dobjs/base.obj')
    for name, weight in [('caucasian-male-young', 0.68), ('caucasian-male-old', 0.32)]:
        target = CACHE/('core/targets/macrodetails/'+name+'.target')
        for line in target.read_text().splitlines():
            v = line.split()
            if len(v)==4 and v[0].isdigit(): base[int(v[0])] = add(base[int(v[0])], mul(list(map(float, v[1:])), weight))
    body_faces = [(0, face) for group, face in all_faces if group == 'body']
    used = {v for _, face in body_faces for v, uv in face}
    bottom, top = min(base[v][1] for v in used), max(base[v][1] for v in used)
    scale = 1.85/(top-bottom)
    def transform(v): return [v[0]*scale, (v[1]-bottom)*scale, v[2]*scale]
    skeleton = json.loads((CACHE/'core/rigs/default.mhskel').read_text())
    selected = ['root', 'spine03', 'spine01', 'neck03', 'head']
    for side in ['L', 'R']:
        selected += [s+'.'+side for s in ['clavicle', 'upperarm01', 'lowerarm01', 'wrist', 'upperleg01', 'lowerleg01', 'foot']]
    def parent_of(bone):
        parent = skeleton['bones'][bone]['parent']
        while parent and parent not in selected: parent = skeleton['bones'][parent]['parent']
        return parent
    def selected_ancestor(bone):
        while bone not in selected: bone = skeleton['bones'][bone]['parent'] or 'root'
        return selected.index(bone)
    weights = [{} for _ in base]
    for bone, influences in json.loads((CACHE/'core/rigs/default_weights.mhw').read_text())['weights'].items():
        mapped = selected_ancestor(bone)
        for vertex, value in influences: weights[vertex][mapped] = weights[vertex].get(mapped, 0.)+value
    for w in weights:
        if not w: w[0] = 1.
    heads = {}
    for bone in selected:
        joint = skeleton['joints'][skeleton['bones'][bone]['head']]
        heads[bone] = transform([sum(base[v][i] for v in joint)/len(joint) for i in range(3)])
    glb = GLB()
    bone_ids = {}
    for bone in selected:
        bone_ids[bone] = len(glb.doc['nodes']); glb.doc['nodes'].append({'name': bone, 'children': [], 'translation': heads[bone]})
    for bone in selected:
        parent = parent_of(bone)
        if parent:
            glb.doc['nodes'][bone_ids[parent]]['children'].append(bone_ids[bone])
            glb.doc['nodes'][bone_ids[bone]]['translation'] = sub(heads[bone], heads[parent])
        else: glb.doc['nodes'][0]['children'].append(bone_ids[bone])
    inverse = []
    for bone in selected:
        h = heads[bone]; inverse.append([1.,0.,0.,0.,0.,1.,0.,0.,0.,0.,1.,0.,-h[0],-h[1],-h[2],1.])
    glb.doc['skins'].append({'name': 'HumanRig', 'joints': [bone_ids[b] for b in selected],
                            'skeleton': bone_ids['root'], 'inverseBindMatrices': glb.accessor(inverse, 'MAT4')})
    skin_path = CACHE/'system/skins/young_caucasian_male/young_lightskinned_male_diffuse.png'
    skin = glb.material('Skin', [1., 0.96, 0.92, 1.], 0.62, skin_path)
    cloth_colors = {'player': [0.08,0.14,0.18,1.], 'soldier': [0.28,0.25,0.20,1.], 'villager': [0.46,0.39,0.28,1.]}
    diffuse = CACHE/'system/clothes/male_casualsuit01/male_casualsuit01_diffuse.png'
    normal = CACHE/'system/clothes/male_casualsuit01/male_casualsuit01_normal.png'
    cloth = glb.material('Fabric', [1.,1.,1.,1.], 0.92, diffuse, normal=normal)
    trousers = glb.material('Trousers', [1.,1.,1.,1.], 0.9, diffuse, normal=normal)
    boots = glb.material('Boots', [0.10,0.065,0.038,1.], 0.8)
    eye = glb.material('Eyes', [1.,1.,1.,1.], 0.24, CACHE/'system/eyes/materials/brown_eye.png')
    hair = glb.material('Hair', [0.27,0.18,0.10,1.], 0.88, CACHE/'system/hair/short01/short01_diffuse.png', True)
    brow = glb.material('Brows', [0.32,0.22,0.16,1.], 0.9, CACHE/'system/eyebrows/eyebrow001/eyebrow001.png', True)
    cv, cu, cf, cw, deleted = proxy(CACHE/'system/clothes/male_casualsuit01/male_casualsuit01.mhclo', base, weights, transform)
    clothed_faces = []
    for _, face in cf:
        y = sum(cv[v][1] for v, uv in face)/3
        clothed_faces.append((1 if y < 0.95 else 0, face))
    glb.mesh('Garments', cv, cu, clothed_faces, cw, {0: cloth, 1: trousers})
    skin_faces = []
    for _, face in body_faces:
        if any(v in deleted for v, uv in face): continue
        y = sum(transform(base[v])[1] for v, uv in face)/3
        skin_faces.append((1 if y<0.16 else 0, face))
    glb.mesh('Anatomy', list(map(transform, base)), uvs, skin_faces, weights, {0: skin, 1: boots})
    for name, path, mat in [('Eyes', 'eyes/low-poly/low-poly', eye), ('Hair', 'hair/short01/short01', hair), ('Brows', 'eyebrows/eyebrow001/eyebrow001', brow)]:
        v, uv, faces, w, _ = proxy(CACHE/('system/'+path+'.mhclo'), base, weights, transform)
        glb.mesh(name, v, uv, [(0, f) for _, f in faces], w, {0: mat})
    animate(glb, heads, bone_ids)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    dest = OUTPUT/'human.glb'; glb.save(dest)
    print(f'Clothed human {role}: {sum(len(m["primitives"]) for m in glb.doc["meshes"])} surfaces, {len(selected)} bones, {len(glb.doc["animations"])} animations, {dest.stat().st_size} bytes')


if __name__ == '__main__':
    build('player')
    for obsolete in ['player', 'soldier', 'villager']:
        (OUTPUT/(obsolete+'.glb')).unlink(missing_ok=True)
