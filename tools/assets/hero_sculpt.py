"""Original, deterministic player sculpt and groom on the licensed human rig.

No runtime subdivision or hair particles: the build emits a bounded skinned
mesh, retaining UVs, source identity, individual fingers and every motion clip.
"""
import math
import random


FACE_TARGETS = {
    'head/head-square': 0.18,
    'chin/chin-width-incr': 0.42,
    'chin/chin-prominent-incr': 0.18,
    'cheek/l-cheek-bones-incr': 0.28,
    'cheek/r-cheek-bones-incr': 0.28,
    'cheek/l-cheek-volume-decr': 0.08,
    'cheek/r-cheek-volume-decr': 0.08,
    'nose/nose-greek-incr': 0.07,
    'nose/nose-width1-decr': 0.10,
    'eyes/l-eye-eyefold-down': 0.18,
    'eyes/r-eye-eyefold-down': 0.18,
    'eyes/l-eye-height2-decr': 0.08,
    'eyes/r-eye-height2-decr': 0.08,
    'eyebrows/eyebrows-angle-down': 0.13,
}


def sculpt(base, cache):
    for name, amount in FACE_TARGETS.items():
        for line in (cache / ('core/targets/' + name + '.target')).read_text().splitlines():
            fields = line.split()
            if len(fields) == 4 and fields[0].isdigit():
                point = base[int(fields[0])]
                for i in range(3): point[i] += float(fields[i + 1]) * amount


def mix_vectors(items):
    return [sum(p[i] * amount for p, amount in items) for i in range(3)]


def mix_weights(items):
    result = {}
    for source, amount in items:
        for joint, value in source.items(): result[joint] = result.get(joint, 0.) + value * amount
    return result


def beard_mask(point):
    x, y, z = point
    def smooth(lo, hi, value):
        t = max(0., min(1., (value-lo)/(hi-lo)))
        return t*t*(3.-2.*t)
    line = 1.693+abs(x)*.42
    mask = (1.-smooth(line-.003,line+.003,y))*smooth(1.619,1.630,y)*smooth(.062,.125,z)
    lip = (1.-smooth(.025,.034,abs(x)))*smooth(1.661,1.669,y)*(1.-smooth(1.681,1.685,y))
    return mask*(1.-lip)


def subdivide(vertices, uvs, faces, weights):
    """One Loop step, with continuous position normals across UV seams.

    Open edges are fixed so the smoothed head still meets the untouched neck.
    The source mesh is never modified: resident humans keep their own topology.
    """
    used = sorted({v for _, face in faces for v, uv in face})
    compact = {v: i for i, v in enumerate(used)}
    points = [vertices[v] for v in used]
    influences = [weights[v] for v in used]
    edges, neighbours = {}, [set() for _ in used]
    compact_faces = [(material, [(compact[v], uv) for v, uv in face]) for material, face in faces]
    for _, face in compact_faces:
        a, b, c = [pair[0] for pair in face]
        for x, y, opposite in [(a, b, c), (b, c, a), (c, a, b)]:
            edges.setdefault(tuple(sorted((x, y))), []).append(opposite)
            neighbours[x].add(y); neighbours[y].add(x)
    boundary = {v for edge, opposite in edges.items() if len(opposite) != 2 for v in edge}
    out, blend = [], []
    for i, point in enumerate(points):
        count = len(neighbours[i])
        beta = (3. / 16 if count == 3 else 3. / (8 * count)) if count else 0.
        terms = [(i, 1. - count * beta)] + [(n, beta) for n in neighbours[i]]
        if i in boundary: terms = [(i, 1.)]
        out.append(mix_vectors([(points[j], k) for j, k in terms]))
        blend.append(mix_weights([(influences[j], k) for j, k in terms]))
    edge_ids = {}
    for (a, b), opposite in edges.items():
        terms = [(a, .375), (b, .375)] + [(c, .125) for c in opposite] if len(opposite) == 2 else [(a, .5), (b, .5)]
        edge_ids[(a, b)] = len(out)
        out.append(mix_vectors([(points[j], k) for j, k in terms]))
        blend.append(mix_weights([(influences[j], k) for j, k in terms]))
    texcoords, uv_ids, triangles = list(uvs), {}, []
    def midpoint(a, b):
        vertex = edge_ids[tuple(sorted((a[0], b[0])))]
        key = tuple(sorted((a[1], b[1])))
        if key not in uv_ids:
            uv_ids[key] = len(texcoords)
            texcoords.append([(uvs[a[1]][i] + uvs[b[1]][i]) * .5 for i in range(2)])
        return (vertex, uv_ids[key])
    for material, (a, b, c) in compact_faces:
        ab, bc, ca = midpoint(a, b), midpoint(b, c), midpoint(c, a)
        triangles.extend([(material, f) for f in [(a, ab, ca), (ab, b, bc), (ca, bc, c), (ab, bc, ca)]])
    return out, texcoords, triangles, blend


def refine_face(vertices, uvs, faces, weights):
    """Spend the second smoothing step on facial landmarks, not the skull.

    Subdivision fixes boundary vertices and creates collinear boundary edges.
    Reuse equal boundary positions so shading stays continuous at the join.
    """
    def visible(face):
        return all(1.630 < vertices[v][1] < 1.748 and vertices[v][2] > .132 and abs(vertices[v][0]) < .047
                   for v, uv in face)
    fine = [(m, f) for m, f in faces if visible(f)]
    rest = [(m, f) for m, f in faces if not visible(f)]
    fv, fu, ff, fw = subdivide(vertices, uvs, fine, weights)
    points, influence = list(vertices), list(weights)
    lookup = {tuple(round(x, 8) for x in p): i for i, p in enumerate(points)}
    mapping = {}
    for i, p in enumerate(fv):
        key = tuple(round(x, 8) for x in p)
        if key not in lookup:
            lookup[key] = len(points)
            points.append(p); influence.append(fw[i])
        mapping[i] = lookup[key]
    offset = len(uvs)
    rest.extend((m, [(mapping[v], uv + offset) for v, uv in f]) for m, f in ff)
    return points, list(uvs) + fu, rest, influence


def add(a, b): return [a[i] + b[i] for i in range(3)]
def sub(a, b): return [a[i] - b[i] for i in range(3)]
def mul(a, amount): return [v * amount for v in a]
def cross(a, b): return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
def unit(a):
    size = math.sqrt(sum(v * v for v in a))
    return mul(a, 1. / max(size, 1e-12))


def curve(controls, t):
    value = min(t, .999999) * (len(controls) - 1)
    i, f = int(value), value % 1.
    p0, p1 = controls[max(i - 1, 0)], controls[i]
    p2, p3 = controls[min(i + 1, len(controls) - 1)], controls[min(i + 2, len(controls) - 1)]
    return [.5 * ((2*p1[a]) + (-p0[a]+p2[a])*f + (2*p0[a]-5*p1[a]+4*p2[a]-p3[a])*f*f + (-p0[a]+3*p1[a]-3*p2[a]+p3[a])*f*f*f) for a in range(3)]


def groom(glb, head_joint):
    """Layered parted waves with individual curved locks and tapered flyaways."""
    rng = random.Random(6172026)
    points, uvs, faces, weights = [], [], [], []
    def lock(controls, width, number, depth=.28, segments=20, columns=6, wave=.004):
        start = len(points)
        phase = rng.random() * math.tau
        for row in range(segments + 1):
            t = row / segments
            center = curve(controls, t)
            tangent = unit(sub(curve(controls, min(1., t+.005)), curve(controls, max(0., t-.005))))
            outward = unit(sub(center, [0., 1.744, .049]))
            normal = unit(cross(tangent, outward))
            if sum(x*x for x in normal)<.1: normal = unit(cross(tangent, [0., 0., 1.]))
            binormal = unit(cross(tangent, normal))
            loose = math.sin(t * math.pi * .5)
            center = add(center, mul(normal, math.sin(t*math.tau*2.0+phase)*wave*loose))
            center = add(center, mul(binormal, math.cos(t*math.tau*1.7+phase)*wave*.65*loose))
            taper = max(.025, (1.-t)**.45) * (.8 + .2*math.sin(t*math.pi))
            for col in range(columns):
                angle = col * math.tau / columns
                p = add(center, add(mul(normal, math.cos(angle)*width*taper), mul(binormal, math.sin(angle)*width*depth*taper)))
                points.append(p); weights.append({head_joint: 1.})
                uvs.append([col / columns + number * 2., t])
        for row in range(segments):
            for col in range(columns):
                a = start + row * columns + col
                b = start + row * columns + (col+1) % columns
                c, d = a + columns, b + columns
                faces.extend([(0, [(a, a), (b, b), (c, c)]), (0, [(b, b), (d, d), (c, c)])])
    number = 0
    # Side locks grow from an off-centre part and turn around the ears.
    for side in [-1., 1.]:
        for i in range(25):
            z = -.067 + i * .0079
            high = math.sqrt(max(0., 1.-((z-.050)/.137)**2))
            y = 1.744 + high * .130
            front = max(0., min(1., (z-.060)/.072))
            controls = [[.014, y, z], [side*.046, y+.006, z+.006],
                        [side*.088, 1.804+(y-1.82)*.22, z+.006],
                        [side*(.106+front*.005), 1.755, z-.006],
                        [side*.106, 1.701+front*.046+rng.uniform(-.008,.008), z-.020],
                        [side*(.090+front*.009), 1.641+front*.090+rng.uniform(-.01,.01), z-.012]]
            lock(controls, .007+rng.random()*.0045, number, wave=.009+front*.004)
            number += 1
    # Nape curls cover the rear scalp; they never grow through the cheek.
    for i in range(22):
        x = -.095+i*.009
        controls = [[x*.6, 1.843, -.013], [x*.88, 1.809, -.059],
                    [x, 1.748, -.089], [x*1.04, 1.691, -.083],
                    [x*.94, 1.622+rng.random()*.026, -.051]]
        lock(controls, .006+rng.random()*.004, number, wave=.006)
        number += 1
    # Asymmetric overlapping forelocks, with gaps small enough for a visible hairline.
    for i in range(12):
        d = i / 11.
        controls = [[.020, 1.858+d*.010, .116-d*.037],
                    [-.025, 1.887, .147-d*.021], [-.074, 1.844-d*.005, .166-d*.013],
                    [-.081+d*.014, 1.797-d*.014, .169-d*.007],
                    [-.094+d*.012, 1.764-d*.012, .147-d*.008]]
        lock(controls, .007+rng.random()*.003, number, wave=.006)
        number += 1
    # Overlapping crown waves cover actual roots instead of exposing a broad
    # opaque scalp band. The entire groom remains a single skinned surface.
    for side in [-1., 1.]:
        for i in range(12):
            z = -.006 + i * .012
            controls = [[.010, 1.847 + math.sin(i*.23)*.013, z],
                        [side*.038, 1.859, z+.020],
                        [side*.071, 1.829, z+.029],
                        [side*.087, 1.797, z+.019],
                        [side*.094, 1.763, z+.006]]
            lock(controls, .0075+rng.random()*.002, number, depth=.28, wave=.004)
            number += 1
    # Fine loose strands at the silhouette, authored into one bounded draw surface.
    for i in range(18):
        side = -1. if i % 2 else 1.
        z = -.045+rng.random()*.125
        controls = [[side*.076, 1.817, z], [side*.113, 1.778, z+.014],
                    [side*.119, 1.730, z-.012], [side*.110, 1.683, z-.025]]
        lock(controls, .001+rng.random()*.0015, number, depth=.6, segments=18, columns=4, wave=.006)
        number += 1
    material = glb.material('Groom', [.11, .061, .028, 1.], .72)
    glb.mesh('WavyGroom', points, uvs, faces, weights, {0: material})
    print(f'Hero groom: {number} locks, {len(faces)} triangles')


def beard(glb, vertices, body_faces, head_joint):
    rng = random.Random(50662026)
    points, faces, weights = [], [], []
    for _, face in body_faces:
        a, b, c = [vertices[v] for v, uv in face]
        center = mul(add(add(a, b), c), 1/3)
        normal = cross(sub(b, a), sub(c, a))
        area = math.sqrt(sum(x*x for x in normal)) / 2.
        normal = unit(normal)
        if not (1.627 < center[1] < 1.727 and center[2] > .057 and normal[2] > .05): continue
        tangent = unit(cross(normal, [0., 1., 0.]))
        bitangent = unit(cross(normal, tangent))
        for _ in range(min(10, round(area * 45000))):
            u, v = rng.random(), rng.random()
            if u+v>1.: u,v=1.-u,1.-v
            root = add(a, add(mul(sub(b, a), u), mul(sub(c, a), v)))
            x, y, z = root
            # Cheek line, sideburns, moustache and a clear lip opening.
            if y > 1.693 + abs(x) * .42: continue
            if abs(x) < .031 and 1.667 < y < 1.683: continue
            if abs(x) < .012 and y > 1.692: continue
            normal_root = add(root, mul(normal, .0003))
            height = .0023 + rng.random()*.0035
            direction = unit(add(mul(normal, .45), [x*.9, -.75, .08]))
            radius = .00016 + rng.random()*.00010
            start = len(points)
            for row, width in [(0, radius), (1, radius*.65), (2, .000015)]:
                p = add(normal_root, mul(direction, height*row*.5))
                for side in range(3):
                    angle = side*math.tau/3.
                    points.append(add(p, add(mul(tangent, math.cos(angle)*width), mul(bitangent, math.sin(angle)*width))))
                    weights.append({head_joint:1.})
            for row in range(2):
                for side in range(3):
                    a0=start+row*3+side; b0=start+row*3+(side+1)%3
                    faces.extend([(0,[(a0,0),(b0,0),(a0+3,0)]),(0,[(b0,0),(b0+3,0),(a0+3,0)])])
    material = glb.material('BeardFibers', [.085, .048, .024, 1.], .87)
    glb.mesh('FittedBeard', points, [], faces, weights, {0:material})
    print(f'Hero fitted beard: {len(faces)} triangles')
