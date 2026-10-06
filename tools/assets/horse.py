"""Restore a pinned CC0 anatomical horse, skin missing accessories, author gait.

The original .blend is data only (--disable-autoexec). Blender is pinned by hash.
Runtime output is a native GLB, not a Blender dependency on Android.
"""
from pathlib import Path
import os, sys, hashlib, subprocess, tarfile, urllib.request

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[1]
VERSION = '4.5.9'
BLENDER_SHA = 'dcdc3eca6c9825bb35a8033b689c053f3cb5a9b0cd2a61b2eac2a49436b4ad3d'

def restore_blender():
    override = os.environ.get('PRIME_BLENDER')
    if override: return override
    cache = BASE/'cache/blender'
    exe = cache/f'blender-{VERSION}-linux-x64/blender'
    if exe.exists(): return str(exe)
    cache.mkdir(parents=True, exist_ok=True)
    archive = cache/f'blender-{VERSION}-linux-x64.tar.xz'
    url = f'https://download.blender.org/release/Blender4.5/{archive.name}'
    request = urllib.request.Request(url, headers={'User-Agent':'PRIME-KINGDOMS-asset-build/0.5'})
    with urllib.request.urlopen(request,timeout=45) as source, archive.open('wb') as target:
        while block := source.read(4*1024*1024): target.write(block)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != BLENDER_SHA:
        raise ValueError('Blender source checksum mismatch')
    with tarfile.open(archive) as package: package.extractall(cache, filter='data')
    exe.chmod(0o755)
    return str(exe)

def build():
    import bpy, math
    from mathutils import Vector, Matrix
    bpy.ops.wm.open_mainfile(filepath=str(BASE/'cache/horse/riggedHorse.blend'), load_ui=False, use_scripts=False)
    rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    bpy.context.view_layer.objects.active=rig
    rig.select_set(True)
    if bpy.context.object.mode != 'OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
    rig.animation_data_clear()
    for bone in rig.pose.bones:
        bone.rotation_mode = 'XYZ'
        bone.rotation_euler = (0,0,0)
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    for o in list(bpy.data.objects):
        if o not in meshes and o != rig: bpy.data.objects.remove(o,do_unlink=True)
    # Original Blender-Internal textures were packed; rebuild physical materials.
    for material, diffuse, normal, roughness in [
        ('Material','HorseMain4k00.png','HorseMain4k00Norm00.p',0.86),
        ('Material.003','Hair12Main2k.png','Hair12Main2kNorm.png',0.93),
        ('Eye_brown','eye_texture.bmp.001',None,0.26)]:
        mat = bpy.data.materials[material]
        mat.use_nodes = True
        nodes,links=mat.node_tree.nodes,mat.node_tree.links
        nodes.clear()
        out=nodes.new('ShaderNodeOutputMaterial'); principled=nodes.new('ShaderNodeBsdfPrincipled')
        principled.inputs['Roughness'].default_value=roughness
        links.new(principled.outputs['BSDF'],out.inputs['Surface'])
        image=nodes.new('ShaderNodeTexImage');image.image=bpy.data.images[diffuse]
        links.new(image.outputs['Color'],principled.inputs['Base Color'])
        if normal:
            texture=nodes.new('ShaderNodeTexImage');texture.image=bpy.data.images[normal]
            texture.image.colorspace_settings.name='Non-Color'
            bump=nodes.new('ShaderNodeNormalMap');bump.inputs['Strength'].default_value=0.45
            links.new(texture.outputs['Color'],bump.inputs['Color']);links.new(bump.outputs['Normal'],principled.inputs['Normal'])
    # Hair, eyes and tail in the source were unweighted. Attach to nearest bones.
    centers=[(b.name,rig.matrix_world@((b.head_local+b.tail_local)*0.5)) for b in rig.data.bones]
    for obj in meshes:
        if any(m.type=='ARMATURE' for m in obj.modifiers): continue
        for vertex in obj.data.vertices:
            world=obj.matrix_world@vertex.co
            bone=min(centers,key=lambda x:(world-x[1]).length_squared)[0]
            group=obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
            group.add([vertex.index],1.0,'REPLACE')
        obj.modifiers.new('AccessorySkin','ARMATURE').object=rig
    # IK targets stay outside exported selection; animations bake the rig motion.
    chains=[('front.L','Bone_L.002',0.0),('front.R','Bone_R.002',0.5),
            ('hind.L','Bone_L.005',0.75),('hind.R','Bone_R.005',0.25)]
    targets=[]
    for name,bone,phase in chains:
        target=bpy.data.objects.new('IK-'+name,None);bpy.context.collection.objects.link(target)
        rest=rig.matrix_world@rig.data.bones[bone].tail_local
        target.location=rest
        constraint=rig.pose.bones[bone].constraints.new('IK')
        constraint.target=target;constraint.chain_count=3;constraint.use_stretch=False
        targets.append((target,rest,phase,name))
    bpy.context.scene.render.fps=30
    for name,duration in [('idle',3.0),('walk',1.1),('trot',0.76),('gallop',0.66),('jump',0.8)]:
        if rig.animation_data:
            for track in rig.animation_data.nla_tracks:track.mute=True
        action=bpy.data.actions.new(name)
        rig.animation_data_create();rig.animation_data.action=action
        for frame in range(round(duration*30)+1):
            cycle=frame/(round(duration*30))
            bpy.context.scene.frame_set(frame)
            for b in rig.pose.bones:b.rotation_euler=(0,0,0);b.location=(0,0,0)
            for target,rest,phase,limb in targets:
                p=(cycle+phase)%1
                if name=='trot':p=(cycle+(0 if limb in ['front.L','hind.R'] else 0.5))%1
                if name=='gallop':p=(cycle+{'front.L':0.,'front.R':0.12,'hind.L':0.50,'hind.R':0.62}[limb])%1
                stance=0.62 if name=='walk' else (0.34 if name=='trot' else 0.18)
                swing=max(0,(p-stance)/(1-stance))
                stride=4.0 if name=='walk' else (5.3 if name=='trot' else 6.3)
                offset=stride*(0.5-p/stance) if p<stance else stride*(-0.5+swing*swing*(3-2*swing))
                lift=(0.80 if name=='walk' else 1.30)*math.sin(math.pi*swing)
                if name=='idle':offset=lift=0
                if name=='jump':offset=0;lift=math.sin(math.pi*cycle)*(2.0 if limb.startswith('front') else 1.5)
                target.location=rest+Vector((0,offset,lift))
            rig.pose.bones['Bone.001'].rotation_euler.x=0.035*math.sin(cycle*math.tau)
            rig.pose.bones['Bone.003'].rotation_euler.y=0.08*math.sin(cycle*math.tau)
            bpy.context.view_layer.update()
            # Store evaluated constraint results directly, so exported clips do
            # not depend on helpers, Blender IK or an active NLA target action.
            matrices={b.name:b.matrix.copy() for b in rig.pose.bones}
            for b in rig.pose.bones:
                for c in b.constraints:c.mute=True
            for b in rig.pose.bones:b.matrix=matrices[b.name]
            bpy.context.view_layer.update()
            for b in rig.pose.bones:
                b.keyframe_insert('rotation_euler',frame=frame)
                b.keyframe_insert('location',frame=frame)
            for b in rig.pose.bones:
                for c in b.constraints:c.mute=False
        track=rig.animation_data.nla_tracks.new();track.name=name
        track.strips.new(name,0,action)
        rig.animation_data.action=None
    for b in rig.pose.bones:
        for c in list(b.constraints): b.constraints.remove(c)
        b.rotation_euler=(0,0,0);b.location=(0,0,0)
    for track in rig.animation_data.nla_tracks:track.mute=False
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    points=[obj.matrix_world@Vector(corner) for obj in meshes for corner in obj.bound_box]
    low=Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    scale=1.88/(high.z-low.z)
    # GLTF changes Blender's +Z up to +Y; source horse faces -Y -> +Z.
    normalize=Matrix.Diagonal((scale,scale,scale,1))@Matrix.Translation(Vector((-(high.x+low.x)/2,-(high.y+low.y)/2,-low.z)))
    # Capture every world transform before moving the armature. Several source
    # meshes already parent to it; applying normalization to those and then to
    # the rig would apply the scale twice and leave a tiny floating horse.
    normalized={obj:normalize@obj.matrix_world.copy() for obj in meshes+[rig]}
    # Keep the exported skeleton and skinned meshes in one identity space.
    # Godot derives skinned bounds from mesh-local data; a scaled armature
    # parent plus baked mesh vertices otherwise scales those bounds twice.
    rig.data.transform(normalized[rig])
    rig.matrix_world=Matrix.Identity(4)
    for obj in meshes:
        obj.data.transform(normalized[obj])
        obj.parent=rig;obj.matrix_parent_inverse=Matrix.Identity(4)
        obj.matrix_world=Matrix.Identity(4)
        obj.data.validate(clean_customdata=False)
    for action in bpy.data.actions:
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        if curve.data_path.endswith('.location'):
                            for key in curve.keyframe_points:
                                key.co.y*=scale
                                key.handle_left.y*=scale
                                key.handle_right.y*=scale
    for obj in bpy.context.view_layer.objects:obj.select_set(False)
    for obj in meshes+[rig]:obj.select_set(True)
    bpy.context.view_layer.objects.active=rig
    output=ROOT/'client/assets/horse/horse.glb';output.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,
        export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,
        export_bake_animation=True,export_cameras=False,export_lights=False)
    print('ANATOMICAL_HORSE',len(rig.data.bones),'bones, idle/walk/trot/gallop/jump',output.stat().st_size,'bytes')

if __name__=='__main__':
    if '--horse-worker' in sys.argv:build()
    else:subprocess.run([restore_blender(),'--background','--factory-startup','--disable-autoexec','--python-exit-code','1','--python',str(Path(__file__).resolve()),'--','--horse-worker'],check=True)
