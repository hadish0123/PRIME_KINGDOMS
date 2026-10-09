from __future__ import annotations
import json
import math
from pathlib import Path
import re
import struct
import tempfile
from urllib.parse import unquote, urlparse
import uuid
import zipfile
import bpy
import bmesh
from mathutils import Vector
from .safety import SafetyError

PRESETS={'android_low':{'triangles':3000,'texture':512,'ratios':[1,.5,.22,.08]},'android_medium':{'triangles':8000,'texture':1024,'ratios':[1,.6,.3,.12]},'android_high':{'triangles':16000,'texture':2048,'ratios':[1,.65,.35,.15]}}

class Pipeline:
    def __init__(self,d):self.d=d;self.o=d.ops
    def handlers(self):
        h={n:getattr(self,n) for n in ['export_for_godot','prime_export_to_godot','create_lods','optimize_for_android','render_preview','viewport_screenshot','render_turntable','prime_asset_review','prime_scene_review','prime_polish_asset','prime_polish_scene','prime_smoke_test']}
        for n in ['import_glb','import_gltf','import_fbx','import_obj']:h[n]=lambda a,n=n:self.import_asset(n,a)
        for n in ['export_glb','export_gltf','export_fbx','export_animation']:h[n]=lambda a,n=n:self.export_asset(n,a)
        for n in ['bake_normal','bake_ao','bake_diffuse','bake_roughness','bake_metallic','bake_texture_atlas']:h[n]=lambda a,n=n:self.bake(n,a)
        return h
    def output_dir(self):
        if not self.d.paths.roots:raise SafetyError('Approve an output directory first')
        return self.d.paths.directory(str(self.d.paths.roots[0]/'.prime-artifacts'),create=True)
    def selected_export(self,names=None):
        roots=[self.o.object(n) for n in names] if names else list(bpy.context.selected_objects)
        if not roots:raise SafetyError('Select asset objects or pass objects explicitly; scene-wide exports are not implicit')
        obs=[]
        for root in roots:
            obs.extend(x for x in self.o.members(root) if not x.get('prime_source_hidden'))
        return list(dict.fromkeys(obs))
    def validate_dependencies(self,p):
        def check(uri,base):
            if uri.startswith('data:'):
                if len(uri)>64*1024*1024:raise SafetyError('Embedded data URI is too large')
                return
            u=urlparse(uri)
            if u.scheme or u.netloc or '?' in uri or '#' in uri:raise SafetyError('External import URLs are denied')
            self.d.paths.resolve(str(base/unquote(uri)))
        if p.suffix.lower() in ['.gltf','.glb']:
            if p.suffix.lower()=='.glb':
                data=p.read_bytes()
                if len(data)<20 or data[:4]!=b'glTF':raise SafetyError('Invalid GLB header')
                version,length=struct.unpack_from('<II',data,4)
                if version!=2 or length!=len(data):raise SafetyError('Invalid GLB size/version')
                chunk_length,chunk_type=struct.unpack_from('<II',data,12)
                if chunk_type!=0x4E4F534A or chunk_length>16*1024*1024:raise SafetyError('Invalid GLB JSON chunk')
                doc=json.loads(data[20:20+chunk_length])
            else:doc=json.loads(p.read_text(encoding='utf-8'))
            for item in doc.get('images',[])+doc.get('buffers',[]):
                if 'uri' in item:check(item['uri'],p.parent)
        elif p.suffix.lower()=='.obj':
            for line in p.read_text(encoding='utf-8',errors='strict').splitlines():
                if line.startswith('mtllib '):
                    for name in line[7:].split():
                        mtl=self.d.paths.resolve(str(p.parent/name),extension={'.mtl'})
                        for row in mtl.read_text(encoding='utf-8',errors='strict').splitlines():
                            if row.split(' ',1)[0].lower().startswith(('map_','bump','disp','decal')):
                                # Keep the security boundary conservative for MTL options and filenames with spaces.
                                parts=row.split()
                                if len(parts)!=2:raise SafetyError('MTL texture references must be simple approved relative paths')
                                check(parts[1],mtl.parent)
        elif p.suffix.lower()=='.fbx':
            from io_scene_fbx import parse_fbx
            root,_version=parse_fbx.parse(str(p))
            def walk(node):
                if node.id in {b'FileName',b'Filename',b'RelativeFilename'}:
                    for prop in node.props:
                        if isinstance(prop,bytes):
                            value=prop.decode('utf-8',errors='strict').rstrip('\x00')
                            if value:
                                ref=Path(value)
                                self.d.paths.resolve(str(ref if ref.is_absolute() else p.parent/ref))
                for child in node.elems:walk(child)
            walk(root)
    def import_asset(self,n,a):
        ext={'import_glb':{'.glb'},'import_gltf':{'.gltf'},'import_fbx':{'.fbx'},'import_obj':{'.obj'}}[n];p=self.d.paths.resolve(a['path'],extension=ext)
        if p.stat().st_size>256*1024*1024:raise SafetyError('Import exceeds 256 MiB safety limit')
        self.validate_dependencies(p);before=set(bpy.data.objects)
        if n in ['import_glb','import_gltf']:bpy.ops.import_scene.gltf(filepath=str(p),import_pack_images=True)
        elif n=='import_fbx':bpy.ops.import_scene.fbx(filepath=str(p),use_image_search=False)
        else:bpy.ops.wm.obj_import(filepath=str(p))
        imported=list(set(bpy.data.objects)-before);self.o.verify_resources(imported)
        return {'path':str(p),'objects':[self.o.info(o) for o in imported],'triangles':sum(self.o.triangles(o) for o in imported),'bounding_box':self.o.bounds(imported),'materials':sorted({s.material.name for o in imported for s in o.material_slots if s.material}),'textures':[{'name':i.name,'size':list(i.size)} for i in self.o.scene_images(imported)]}
    def export_asset(self,n,a):
        if n=='export_animation':n='export_glb';a=dict(a,animations=True)
        extension={'.fbx'} if n=='export_fbx' else {'.gltf'} if n=='export_gltf' else {'.glb'}
        p=self.d.paths.resolve(a['path'],write=True,overwrite=a.get('overwrite',False),extension=extension)
        obs=self.selected_export(a.get('objects'));self.o.verify_resources(obs)
        previous=list(bpy.context.selected_objects);active=bpy.context.view_layer.objects.active
        hidden={o:(o.hide_get(),o.hide_render) for o in obs}
        if n=='export_gltf':
            # Export into a fresh approved directory, then atomically publish every sidecar after conflict checks.
            folder=self.d.paths.directory(str(p.parent/('.prime-gltf-'+uuid.uuid4().hex)),create=True);target=folder/p.name
        else:folder=None;target=p
        try:
            for o in bpy.context.selected_objects:o.select_set(False)
            for o in obs:o.hide_set(False);o.hide_render=False;o.select_set(True)
            bpy.context.view_layer.objects.active=next((o for o in obs if o.type=='MESH'),obs[0])
            if n=='export_fbx':bpy.ops.export_scene.fbx(filepath=str(target),use_selection=True,apply_unit_scale=True,axis_forward='-Z',axis_up='Y',add_leaf_bones=False,bake_anim=a.get('animations',True),use_mesh_modifiers=a.get('apply_modifiers',True),path_mode='COPY',embed_textures=True)
            else:
                bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLTF_SEPARATE' if n=='export_gltf' else 'GLB',use_selection=True,export_yup=True,export_extras=True,export_apply=a.get('apply_modifiers',True),export_animations=a.get('animations',True),export_materials='EXPORT',export_texcoords=True,export_normals=True,export_tangents=True)
            artifacts=[]
            if folder:
                outputs=[x for x in folder.rglob('*') if x.is_file()]
                for source in outputs:
                    dest=p.parent/source.relative_to(folder);self.d.paths.directory(str(dest.parent),create=True);self.d.paths.resolve(str(dest),write=True,overwrite=a.get('overwrite',False))
                for source in outputs:source.replace(p.parent/source.relative_to(folder))
                for child in sorted(folder.rglob('*'),reverse=True):
                    if child.is_dir():child.rmdir()
                folder.rmdir()
            else:artifacts=[self.d.artifact(p,'application/octet-stream' if n=='export_fbx' else 'model/gltf-binary')]
            return {'path':str(p),'file_size':p.stat().st_size,'triangle_count':sum(self.o.triangles(o) for o in obs),'objects':[o.name for o in obs],'artifacts':artifacts}
        finally:
            for o,(view,render) in hidden.items():o.hide_set(view);o.hide_render=render
            for o in bpy.context.selected_objects:o.select_set(False)
            for o in previous:
                if o.name in bpy.context.view_layer.objects:o.select_set(True)
            bpy.context.view_layer.objects.active=active
    def godot_validation(self,obs,path=None):
        meshes=[o for o in obs if o.type=='MESH'];issues=[];warnings=[]
        for o in meshes:
            if any(abs(v-1)>1e-4 for v in o.scale):warnings.append(o.name+': unapplied scale (glTF carries the transform)')
            if o.scale.x*o.scale.y*o.scale.z<0:issues.append(o.name+': negative scale may flip normals')
            if not o.data.uv_layers:warnings.append(o.name+': no UV map')
            if any(p.area<1e-10 for p in o.data.polygons):issues.append(o.name+': zero-area faces')
            for m in [s.material for s in o.material_slots if s.material and s.material.use_nodes]:
                if any(n.type in {'TEX_NOISE','TEX_VORONOI','BUMP'} for n in m.node_tree.nodes):warnings.append(m.name+': procedural detail needs texture baking for glTF; Principled base values still export')
        for ob in obs:
            if ob.type=='ARMATURE':
                v=self.o.validate_armature({'object':ob.name});warnings.extend(ob.name+': '+i for i in v['issues'])
        images=self.o.scene_images(obs)
        for i in images:
            if not i.packed_file and i.source=='FILE' and not Path(bpy.path.abspath(i.filepath)).is_file():issues.append('Missing texture '+i.name)
        if path:
            data=Path(path).read_bytes()
            if data[:4]!=b'glTF' or len(data)<20 or struct.unpack_from('<I',data,8)[0]!=len(data):issues.append('GLB container validation failed')
        return {'valid':not issues,'issues':issues,'warnings':list(dict.fromkeys(warnings)),'scale':{'unit':'metres','gltf_up_axis':'Y','godot_up_axis':'Y'},'rotation':'Blender Z-up converted to glTF/Godot Y-up','normals':'exported','materials':sorted({s.material.name for o in meshes for s in o.material_slots if s.material}),'textures':[{'name':i.name,'size':list(i.size),'packed':bool(i.packed_file)} for i in images],'armatures':[o.name for o in obs if o.type=='ARMATURE'],'animations':[a.name for a in bpy.data.actions],'file_size':Path(path).stat().st_size if path else None,'triangle_count':sum(self.o.triangles(o) for o in meshes)}
    def export_for_godot(self,a):
        if Path(a['path']).suffix.lower()!='.glb':raise SafetyError('Godot assets use .glb')
        obs=self.selected_export(a.get('objects'));validation=self.godot_validation(obs)
        if not validation['valid']:raise SafetyError('Godot validation failed: '+'; '.join(validation['issues']))
        result=self.export_asset('export_glb',a);result['validation']=self.godot_validation(obs,result['path']);return result
    def prime_export_to_godot(self,a):
        if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]{0,100}',a['asset_name']):raise SafetyError('Asset name must be a filename-safe identifier')
        root=self.d.paths.directory(a['project_root']);folder=self.d.paths.directory(str(root/'client/assets/models'/a['asset_type']),create=True);name=a['asset_name'];p=folder/(name+'.glb');meta_path=folder/(name+'.metadata.json');script_path=folder/(name+'.gd');scene_path=folder/(name+'.tscn')
        for x in [p,meta_path,script_path,scene_path]:self.d.paths.resolve(str(x),write=True,overwrite=a.get('overwrite',False))
        obs=self.selected_export(a.get('objects'));result=self.export_for_godot({'path':str(p),'objects':a.get('objects',[o.name for o in obs]),'overwrite':a.get('overwrite',False),'animations':True})
        tier=a.get('quality_tier','android_medium');distance=a.get('recommended_distance',40);lods=[{'name':o.name,'level':int(o.get('prime_lod_level',0)),'triangles':self.o.triangles(o)} for o in obs if o.get('prime_lod_level') is not None and o.type=='MESH']
        metadata={'asset_name':name,'triangle_count':sum(self.o.triangles(o) for o in obs if o.type=='MESH' and int(o.get('prime_lod_level',0))==0),'materials':result['validation']['materials'],'textures':result['validation']['textures'],'lods':lods,'bounding_box':self.o.bounds(obs),'recommended_distance':distance,'android_quality_tier':tier,'godot_validation':result['validation'],'lod_distances':[0,distance*.4,distance*.7,distance],'style':'Medieval semi-realistic premium mobile strategy'}
        meta_path.write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
        # The wrapper implements real Godot 4 LOD visibility. Mesh names alone do not enable automatic switching.
        script='extends Node3D\n\nfunc _ready() -> void:\n    _configure_lods(self)\n\nfunc _configure_lods(node: Node) -> void:\n    if node is MeshInstance3D:\n        var level: int = -1\n        var text: String = str(node.name)\n        for i in range(4):\n            if text.ends_with("_LOD" + str(i)):\n                level = i\n        if level >= 0:\n            var bounds: Array[float] = [0.0, '+str(distance*.4)+', '+str(distance*.7)+', '+str(distance)+', 100000.0]\n            node.visibility_range_begin = bounds[level]\n            node.visibility_range_end = bounds[level + 1]\n            node.visibility_range_begin_margin = 0.0\n            node.visibility_range_end_margin = 0.0\n            node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED\n            node.visible = true\n    for child in node.get_children():\n        _configure_lods(child)\n'
        script_path.write_text(script,encoding='utf-8');prefix='res://assets/models/'+a['asset_type']+'/'+name
        scene_path.write_text('[gd_scene load_steps=3 format=3]\n\n[ext_resource type="PackedScene" path="'+prefix+'.glb" id="1"]\n[ext_resource type="Script" path="'+prefix+'.gd" id="2"]\n\n[node name="'+name+'" instance=ExtResource("1")]\nscript = ExtResource("2")\n',encoding='utf-8')
        result['metadata']=metadata;result['metadata_path']=str(meta_path);result['godot_scene_path']=str(scene_path);result['artifacts'] += [self.d.artifact(meta_path,'application/json'),self.d.artifact(script_path,'application/octet-stream'),self.d.artifact(scene_path,'application/octet-stream')]
        return result
    def create_lods(self,a):
        source=self.o.object(a['object']);meshes=[o for o in self.o.meshes([source.name]) if o.get('prime_lod_level') is None and not o.get('prime_source_hidden')]
        if not meshes:
            meshes=[o for o in self.o.meshes([source.name]) if o.get('prime_source_hidden')]
        if not meshes:raise SafetyError('Asset has no source meshes')
        if any(any(m.type=='ARMATURE' for m in o.modifiers) or o.data.shape_keys for o in meshes):raise SafetyError('Automatic static LOD generation refuses skinned meshes or shape keys; preserve the rig and create authored unit LODs')
        ratios=a.get('ratios',PRESETS[a.get('preset','android_medium')]['ratios'])
        if ratios[0]!=1 or any(ratios[i]<ratios[i+1] for i in range(3)):raise SafetyError('LOD ratios must start at 1 and decrease')
        base=source.name;uid=source.get('prime_source_id') or uuid.uuid4().hex;source['prime_source_id']=uid
        for level in range(4):
            existing=bpy.data.objects.get(base+'_LOD'+str(level))
            if existing:
                if existing.get('prime_lod_source')!=uid:raise SafetyError('LOD output name is occupied by an unrelated object')
                bpy.data.objects.remove(existing,do_unlink=True)
        clones=[]
        for ob in meshes:
            copy=ob.copy();copy.data=ob.data.copy();copy.parent=None;copy.matrix_world=ob.matrix_world.copy();copy.hide_render=False;bpy.context.collection.objects.link(copy);copy.hide_set(False);copy['prime_source_hidden']=False;clones.append(copy)
            self.o.activate(copy)
            for modifier in list(copy.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
        self.o.select_objects({'objects':[x.name for x in clones]});bpy.ops.object.join();lod0=bpy.context.object;lod0.name=base+'_LOD0';lod0['prime_lod_source']=uid;lod0['prime_lod_level']=0
        matrix=lod0.matrix_world.copy();lod0.parent=source;lod0.matrix_world=matrix
        levels=[lod0]
        for level in range(1,4):
            self.d.checkpoint(level/5);copy=lod0.copy();copy.data=lod0.data.copy();bpy.context.collection.objects.link(copy);copy.name=base+'_LOD'+str(level);copy['prime_lod_level']=level;self.o.activate(copy)
            # Apply existing static modifiers once so a ratio has a predictable evaluated triangle base.
            for m in list(copy.modifiers):
                if m.type not in {'ARMATURE'}:bpy.ops.object.modifier_apply(modifier=m.name)
            dec=copy.modifiers.new('PRIME_LOD','DECIMATE');dec.ratio=ratios[level];dec.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=dec.name);copy.hide_render=True;copy.hide_set(True);levels.append(copy)
        for ob in meshes:ob['prime_source_hidden']=True;ob.hide_render=True;ob.hide_set(True)
        self.o.activate(source if source.type=='EMPTY' else lod0)
        return {'lods':[{'name':o.name,'level':level,'triangles':self.o.triangles(o),'ratio':ratios[level]} for level,o in enumerate(levels)],'source':source.name,'preset':a.get('preset','android_medium')}
    def material_signature(self,m):
        if m.animation_data:return None
        # Compare only graphs whose render-affecting fields are covered below.
        # Complex/procedural/node-group graphs are preserved rather than guessed equal.
        supported={'BSDF_PRINCIPLED','OUTPUT_MATERIAL','TEX_IMAGE','NORMAL_MAP','MATH'}
        if m.use_nodes and any(n.type not in supported for n in m.node_tree.nodes):return None
        signature={'diffuse':list(m.diffuse_color),'settings':{key:getattr(m,key,None) for key in ['use_backface_culling','surface_render_method','blend_method','alpha_threshold','displacement_method']},'nodes':[],'links':[]}
        if m.use_nodes:
            for n in m.node_tree.nodes:
                values=[]
                for socket in n.inputs:
                    if hasattr(socket,'default_value'):
                        value=socket.default_value
                        try:value=list(value)
                        except TypeError:value=value if isinstance(value,(int,float,str,bool)) else str(value)
                        values.append((socket.name,value))
                fields={key:getattr(n,key,None) for key in ['operation','use_clamp','space','uv_map','interpolation','projection','projection_blend','extension','target','is_active_output','distribution']}
                signature['nodes'].append((n.name,n.bl_idname,values,n.image.name if n.type=='TEX_IMAGE' and n.image else None,fields))
            signature['links']=[(l.from_node.name,l.from_socket.identifier,l.to_node.name,l.to_socket.identifier) for l in m.node_tree.links]
        return json.dumps(signature,sort_keys=True)
    def optimize_for_android(self,a):
        preset=PRESETS[a.get('preset','android_medium')];before=self.o.analyze_scene_performance({});targets=self.o.meshes(a.get('objects'));targets=[o for o in targets if o.get('prime_lod_level') is None]
        if not targets:raise SafetyError('No source meshes selected')
        self.o.verify_resources(targets);budget=a.get('triangle_budget',preset['triangles']);total=sum(self.o.triangles(o) for o in targets);ratio=min(1,budget/max(1,total));skipped=[];deleted=[];signatures={};merged=0;removed_slots=0
        for i,ob in enumerate(list(targets)):
            self.d.checkpoint(i/max(1,len(targets))*.6)
            if ob.hide_render and not ob.get('prime_source_hidden') and a.get('remove_hidden_geometry',True):
                deleted.append(ob.name);bpy.data.objects.remove(ob,do_unlink=True);targets.remove(ob);continue
            if ob.data.shape_keys or any(m.type=='ARMATURE' for m in ob.modifiers):skipped.append(ob.name+': rig/shape keys preserved');continue
            self.o.activate(ob)
            for m in list(ob.modifiers):
                if m.type in {'BEVEL','WEIGHTED_NORMAL','DECIMATE','TRIANGULATE','SOLIDIFY'}:bpy.ops.object.modifier_apply(modifier=m.name)
            bm=bmesh.new();bm.from_mesh(ob.data)
            if a.get('remove_hidden_geometry',True):
                hidden=[f for f in bm.faces if f.hide]
                if hidden:bmesh.ops.delete(bm,geom=hidden,context='FACES')
            loose=[v for v in bm.verts if not v.link_faces]
            if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
            bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0001);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
            if ratio<.999:
                dec=ob.modifiers.new('PRIME_Android','DECIMATE');dec.ratio=ratio;dec.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=dec.name)
            if not ob.data.uv_layers:self.o.smart_uv_project({'object':ob.name})
            for idx,m in enumerate(list(ob.data.materials)):
                if m:
                    signature=self.material_signature(m)
                    if signature is not None:
                        if signature in signatures and signatures[signature]!=m:ob.data.materials[idx]=signatures[signature];merged+=1
                        else:signatures[signature]=m
                    else:skipped.append(m.name+': complex or animated shader graph preserved during material matching')
            # Clearing Blender material slots resets polygon indices. Preserve the
            # assignments first, and merge slots that now reference the same material.
            assignments=[p.material_index for p in ob.data.polygons];used=sorted(set(assignments));old=list(ob.data.materials);mapping={};compact=[]
            if old:
                for idx in used:
                    material=old[idx] if idx<len(old) else old[0]
                    if material not in compact:compact.append(material)
                    mapping[idx]=compact.index(material)
                removed_slots+=len(old)-len(compact)
                ob.data.materials.clear()
                for material in compact:
                    if material is None:bpy.ops.object.material_slot_add()
                    else:ob.data.materials.append(material)
                for poly,original in zip(ob.data.polygons,assignments):poly.material_index=mapping[original]
        max_size=a.get('max_texture_size',preset['texture']);resized=[]
        for image in self.o.scene_images(targets):
            if max(image.size)>max_size:
                old=list(image.size);factor=max_size/max(old);image.scale(max(1,int(old[0]*factor)),max(1,int(old[1]*factor)));image.pack();resized.append({'texture':image.name,'before':old,'after':list(image.size)})
        for m in list(bpy.data.materials):
            if m.users==0:bpy.data.materials.remove(m)
        roots=[self.o.object(n) for n in a.get('objects',[]) if n in bpy.data.objects] or list(dict.fromkeys(o.parent if o.parent and o.parent.get('prime_asset_type') else o for o in targets))
        lods=[]
        if a.get('generate_lods',True):
            for root in roots:
                self.d.checkpoint(.7)
                if root.type in {'MESH','EMPTY'}:
                    try:lods.append(self.create_lods({'object':root.name,'preset':a.get('preset','android_medium')}))
                    except SafetyError as e:skipped.append(root.name+': '+str(e))
        asset_after=sum(self.o.triangles(o) for o in targets if o.name in bpy.data.objects)
        after=self.o.analyze_scene_performance({});return {'before':before,'after':after,'asset_before_triangles':total,'asset_after_triangles':asset_after,'triangle_budget':budget,'budget_met':asset_after<=budget,'scene_budget_met':after['triangle_count']<=budget,'merged_material_slots':merged,'removed_material_slots':removed_slots,'resized_textures':resized,'removed_hidden_objects':deleted,'lods':lods,'uv_validation':[{'object':o.name,**self.o.validate_uv({'object':o.name})} for o in targets if o.name in bpy.data.objects],'excessive_material_slots':[o.name for o in targets if o.name in bpy.data.objects and len(o.data.materials)>8],'skipped':list(dict.fromkeys(skipped))}
    def bake(self,n,a):
        ob=self.o.object(a['object']);sources=self.o.meshes(a.get('source_objects')) if a.get('source_objects') else []
        if n=='bake_texture_atlas':
            sources=self.o.meshes([ob.name]);clones=[]
            for source in sources:
                clone=source.copy();clone.data=source.data.copy();clone.parent=None;clone.matrix_world=source.matrix_world.copy();bpy.context.collection.objects.link(clone);clone.hide_set(False);clone.hide_render=False;clones.append(clone)
            if not clones:raise SafetyError('Atlas source has no meshes')
            self.o.select_objects({'objects':[x.name for x in clones]});bpy.ops.object.join();ob=bpy.context.object;ob.name=a['object']+'_Atlas';self.o.smart_uv_project({'object':ob.name,'margin':.02})
        if ob.type!='MESH':raise SafetyError('Bake target must be a mesh')
        self.o.verify_resources([ob]+sources);p=self.d.paths.resolve(a['path'],write=True,overwrite=a.get('overwrite',False),extension={'.png'})
        if not ob.data.uv_layers:self.o.smart_uv_project({'object':ob.name})
        image=bpy.data.images.new('PRIME_Bake_'+uuid.uuid4().hex[:8],width=a.get('width',1024),height=a.get('height',1024),alpha=True);image.filepath_raw=str(p);image.file_format='PNG';image.colorspace_settings.name='sRGB' if n in {'bake_diffuse','bake_texture_atlas'} else 'Non-Color'
        if not ob.data.materials:self.o.assign_material({'object':ob.name,'material':self.o.create_material({'name':'PRIME_Bake_Material_'+uuid.uuid4().hex[:6]})['material']})
        temporary=[];restore=[];scene=bpy.context.scene;engine=scene.render.engine;samples=scene.cycles.samples;selected_to_active=scene.render.bake.use_selected_to_active;old_margin=scene.render.bake.margin;old_cage=scene.render.bake.cage_extrusion
        try:
            scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=a.get('samples',32);scene.render.bake.use_selected_to_active=bool(sources);scene.render.bake.margin=a.get('margin',8);scene.render.bake.cage_extrusion=a.get('cage_extrusion',.01)
            for material in ob.data.materials:
                if not material:continue
                material.use_nodes=True;nodes=material.node_tree.nodes;tex=nodes.new('ShaderNodeTexImage');tex.image=image;nodes.active=tex;temporary.append((material,tex))
            if n=='bake_metallic':
                for material in {s.material for source in ([ob]+sources) for s in source.material_slots if s.material}:
                    material.use_nodes=True;nodes=material.node_tree.nodes;links=material.node_tree.links;bs=next((x for x in nodes if x.type=='BSDF_PRINCIPLED'),None);output=next((x for x in nodes if x.type=='OUTPUT_MATERIAL' and x.is_active_output),None)
                    if not bs or not output:continue
                    previous=[l.from_socket for l in output.inputs['Surface'].links];emission=nodes.new('ShaderNodeEmission');emission.inputs['Color'].default_value=(bs.inputs['Metallic'].default_value,)*3+(1,)
                    if bs.inputs['Metallic'].links:links.new(bs.inputs['Metallic'].links[0].from_socket,emission.inputs['Color'])
                    links.new(emission.outputs[0],output.inputs['Surface']);restore.append((material,output,previous,emission))
            self.o.select_objects({'objects':[x.name for x in sources if x!=ob]+[ob.name]});bpy.context.view_layer.objects.active=ob
            kind={'bake_normal':'NORMAL','bake_ao':'AO','bake_diffuse':'DIFFUSE','bake_roughness':'ROUGHNESS','bake_metallic':'EMIT','bake_texture_atlas':'DIFFUSE'}[n]
            self.d.checkpoint(.2);bpy.ops.object.bake(type=kind,pass_filter={'COLOR'} if kind=='DIFFUSE' else {'COLOR','DIRECT','INDIRECT'});self.d.checkpoint(.9);image.save()
            if n=='bake_texture_atlas':
                mat=bpy.data.materials.new(ob.name+'_Material');mat.use_nodes=True;ob.data.materials.clear();ob.data.materials.append(mat);self.o.assign_texture({'material':mat.name,'texture':image.name,'channel':'Base Color'})
            return {'object':ob.name,'texture':image.name,'path':str(p),'size':list(image.size),'artifacts':[self.d.artifact(p,'image/png')]}
        finally:
            for material,output,previous,emission in restore:
                material.node_tree.nodes.remove(emission)
                for socket in previous:material.node_tree.links.new(socket,output.inputs['Surface'])
            for material,tex in temporary:
                if tex.name in material.node_tree.nodes:material.node_tree.nodes.remove(tex)
            scene.render.engine=engine;scene.cycles.samples=samples;scene.render.bake.use_selected_to_active=selected_to_active;scene.render.bake.margin=old_margin;scene.render.bake.cage_extrusion=old_cage
    def render_preview(self,a):
        scene=bpy.context.scene;self.o.verify_resources();camera=self.o.object(a['camera'],'CAMERA') if a.get('camera') else scene.camera
        if camera is None:
            bounds=self.o.bounds([o for o in scene.objects if o.type=='MESH' and not o.hide_render]);target=[(bounds['min'][i]+bounds['max'][i])/2 for i in range(3)];self.o.setup_strategy_game_lighting({'target':target,'size':max(5,max(bounds['dimensions'])*1.7)});camera=scene.camera
        folder=self.output_dir();p=self.d.paths.resolve(a.get('path',str(folder/('preview-'+uuid.uuid4().hex[:8]+'.png'))),write=True,overwrite=a.get('overwrite',False),extension={'.png'})
        settings={k:getattr(scene.render,k) for k in ['engine','resolution_x','resolution_y','resolution_percentage','film_transparent','filepath']};old_camera=scene.camera;old_samples=scene.cycles.samples;old_format=scene.render.image_settings.file_format
        try:
            scene.camera=camera;scene.render.engine='CYCLES' if a.get('engine','Eevee')=='Cycles' else 'BLENDER_EEVEE_NEXT' if bpy.app.version>=(4,2,0) else 'BLENDER_EEVEE';scene.render.resolution_x=a.get('width',512);scene.render.resolution_y=a.get('height',512);scene.render.resolution_percentage=100;scene.render.film_transparent=a.get('transparent_background',False);scene.render.filepath=str(p);scene.render.image_settings.file_format='PNG';scene.cycles.samples=a.get('samples',32);scene.cycles.device='CPU'
            if hasattr(scene,'eevee') and hasattr(scene.eevee,'taa_render_samples'):scene.eevee.taa_render_samples=a.get('samples',32)
            self.d.checkpoint(.1);bpy.ops.render.render(write_still=True);self.d.checkpoint(.95)
            return {'path':str(p),'width':a.get('width',512),'height':a.get('height',512),'engine':a.get('engine','Eevee'),'camera':camera.name,'artifacts':[self.d.artifact(p,'image/png')]}
        finally:
            for k,v in settings.items():setattr(scene.render,k,v)
            scene.camera=old_camera;scene.cycles.samples=old_samples;scene.render.image_settings.file_format=old_format
    def viewport_screenshot(self,a):
        if bpy.app.background:raise SafetyError('Viewport capture requires a Blender window; use render_preview in a headless session')
        area=next((x for w in bpy.context.window_manager.windows for x in w.screen.areas if x.type=='VIEW_3D'),None)
        if area is None:raise SafetyError('No 3D viewport is open')
        p=self.d.paths.resolve(a.get('path',str(self.output_dir()/('viewport-'+uuid.uuid4().hex[:8]+'.png'))),write=True,overwrite=a.get('overwrite',False),extension={'.png'});scene=bpy.context.scene;previous=scene.render.filepath;old_format=scene.render.image_settings.file_format
        try:
            scene.render.filepath=str(p);scene.render.image_settings.file_format='PNG';region=next(x for x in area.regions if x.type=='WINDOW')
            with bpy.context.temp_override(area=area,region=region):bpy.ops.render.opengl(write_still=True,view_context=True)
            return {'path':str(p),'capture':'actual viewport','artifacts':[self.d.artifact(p,'image/png')]}
        finally:scene.render.filepath=previous;scene.render.image_settings.file_format=old_format
    def render_turntable(self,a):
        ob=self.o.object(a['object']);old=ob.rotation_euler.copy();folder=self.d.paths.directory(str(self.output_dir()/('turntable-'+uuid.uuid4().hex[:8])),create=True);files=[]
        try:
            for i in range(a.get('frames',12)):
                self.d.checkpoint(i/a.get('frames',12));ob.rotation_euler.z=old.z+2*math.pi*i/a.get('frames',12);path=folder/f'frame-{i:03}.png';result=self.render_preview({k:v for k,v in dict(a,path=str(path)).items() if k not in ['frames','object']});files.append(path)
            archive=folder.parent/(folder.name+'.zip')
            with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
                for p in files:z.write(p,p.name)
            return {'frames':len(files),'format':'PNG sequence ZIP','path':str(archive),'artifacts':[self.d.artifact(files[0],'image/png'),self.d.artifact(archive,'application/zip')]}
        finally:ob.rotation_euler=old
    def prime_asset_review(self,a):
        root=self.o.object(a['object']);meshes=[o for o in self.o.meshes([root.name]) if not o.hide_render];triangles=sum(self.o.triangles(o) for o in meshes);materials={s.material for o in meshes for s in o.material_slots if s.material};images=self.o.scene_images(meshes);bbox=self.o.bounds(meshes);issues=[];tier=root.get('prime_quality','android_medium');preset=PRESETS.get(tier,PRESETS['android_medium']);uvs=[self.o.validate_uv({'object':o.name}) for o in meshes];validation=self.godot_validation(meshes);lod_coverage=any(o.get('prime_lod_level') is not None for o in self.o.meshes([root.name]))
        triangle_score=max(0,min(100,100*preset['triangles']/max(1,triangles)));texture_score=max(0,min(100,100*preset['texture']/max([max(i.size) for i in images] or [preset['texture']])));pbr_count=sum(m.use_nodes and any(n.type=='BSDF_PRINCIPLED' for n in m.node_tree.nodes) for m in materials);mat_score=100*pbr_count/max(1,len(materials));uv_score=100*sum(u['valid'] for u in uvs)/max(1,len(uvs));style_score=100 if root.get('prime_style') else 50
        if triangles>preset['triangles']:issues.append('Reduce triangle count or choose a higher Android tier')
        if not lod_coverage:issues.append('Generate LOD0–LOD3')
        if any(not u['valid'] for u in uvs):issues.append('Fix missing or degenerate UVs')
        if len(materials)>8:issues.append('Atlas materials to reduce draw calls')
        issues.extend(validation['issues']);issues.extend(validation['warnings'])
        visual_proxy=(uv_score+mat_score+style_score)/3;dimensions=bbox['dimensions'];silhouette=90 if len(meshes)>1 and max(dimensions)>0 else 60
        return {'asset':root.name,'scores':{'visual_quality':round(visual_proxy),'silhouette':silhouette,'material_quality':round(mat_score),'mobile_performance':round((triangle_score+texture_score+(100 if lod_coverage else 40))/3),'triangle_budget':round(triangle_score),'texture_budget':round(texture_score),'godot_compatibility':100 if validation['valid'] else 40,'style_consistency':style_score},'triangle_count':triangles,'texture_memory':sum(i.size[0]*i.size[1]*4 for i in images),'bounding_box':bbox,'suggestions':list(dict.fromkeys(issues)),'scoring_method':'Geometry, PBR-node, UV, style-tag and budget heuristics. Visual quality and silhouette are proxy scores; inspect a render before art approval.'}
    def prime_scene_review(self,a):
        report=self.o.analyze_scene_performance({});roots=[o for o in bpy.context.scene.objects if o.get('prime_asset_type')];buildings=[o for o in roots if o.get('prime_asset_type') not in ['road','tree','rock','grass','terrain']];roads=[o for o in roots if o.get('prime_asset_type')=='road'];bounds=self.o.bounds([o for o in bpy.context.scene.objects if o.type=='MESH' and not o.hide_render]);area=max(1,bounds['dimensions'][0]*bounds['dimensions'][1]);suggestions=[];lods=sum(any(x.get('prime_lod_level') is not None for x in self.o.members(o)) for o in roots)
        if report['triangle_count']>150000:suggestions.append('Village triangle count is above the medium Android scene budget')
        if report['estimated_draw_calls']>150:suggestions.append('Use atlases, static merging and Godot MultiMesh for repeated props')
        if not roads and buildings:suggestions.append('Add readable connecting roads')
        if report['light_count']>4:suggestions.append('Reduce realtime lights and bake indirect lighting')
        if lods<len(roots):suggestions.append('Add missing LOD coverage')
        return {'performance':report,'building_density':len(buildings)/area,'road_layout':{'road_assets':len(roads),'review':'Connectivity needs top-down render review'},'visual_hierarchy':{'stages':{stage:sum(o.get('prime_stage')==stage for o in buildings) for stage in ['Village','Town','City','Country','Kingdom','Empire']},'review':'Inspect a strategy-camera render for hierarchy'},'lighting':{'lights':report['light_count'],'active_camera':bpy.context.scene.camera.name if bpy.context.scene.camera else None},'terrain_readability':{'terrain_assets':sum(o.get('prime_asset_type')=='terrain' for o in roots),'needs_render_review':True},'prop_density':(len(roots)-len(buildings))/area,'lod_coverage':lods/max(1,len(roots)),'suggestions':suggestions}
    def prime_polish_asset(self,a):
        ob=self.o.object(a['object']);before=self.prime_asset_review({'object':ob.name})
        for mesh in [o for o in self.o.meshes([ob.name]) if o.get('prime_lod_level') is None]:
            if mesh.data.shape_keys or any(m.type=='ARMATURE' for m in mesh.modifiers):continue
            self.o.merge_by_distance({'object':mesh.name});self.o.recalculate_normals({'object':mesh.name});self.o.shade_smooth({'object':mesh.name})
            if not any(m.type=='BEVEL' for m in mesh.modifiers):self.o.add_modifier({'object':mesh.name,'type':'Bevel','width':a.get('bevel_width',.03),'segments':2})
            if not any(m.type=='WEIGHTED_NORMAL' for m in mesh.modifiers):self.o.add_modifier({'object':mesh.name,'type':'WeightedNormal'})
            if not mesh.data.uv_layers:self.o.smart_uv_project({'object':mesh.name})
            for m in [s.material for s in mesh.material_slots if s.material]:
                m.use_nodes=True;bs=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
                if bs and not bs.inputs['Roughness'].is_linked:bs.inputs['Roughness'].default_value=max(.25,min(.85,bs.inputs['Roughness'].default_value))
        optimization=self.optimize_for_android({'objects':[ob.name],'preset':a.get('preset','android_medium')});ob['prime_quality']=a.get('preset','android_medium');return {'before':before,'after':self.prime_asset_review({'object':ob.name}),'optimization':optimization}
    def prime_polish_scene(self,a):
        before=self.prime_scene_review({});bounds=self.o.bounds([o for o in bpy.context.scene.objects if o.type=='MESH' and not o.hide_render]);target=[(bounds['min'][i]+bounds['max'][i])/2 for i in range(3)];light=self.o.setup_strategy_game_lighting({'size':a.get('size',max(20,max(bounds['dimensions'])*1.3)),'target':target});reports=[]
        roots=[o for o in bpy.context.scene.objects if o.get('prime_asset_type')]
        for i,root in enumerate(roots):self.d.checkpoint(i/max(1,len(roots)));reports.append(self.prime_polish_asset({'object':root.name,'preset':a.get('preset','android_medium')}))
        return {'before':before,'after':self.prime_scene_review({}),'lighting':light,'assets':reports,'prop_distribution':'Preserved authored placement; use scene review/render to choose additional props'}
    def prime_smoke_test(self,a):
        folder=self.d.paths.directory(a['output_dir']);name='PRIME_Smoke_'+uuid.uuid4().hex[:8];before=set(bpy.data.objects);material=None;steps=[]
        def step(n,result):steps.append({'step':n,'passed':True,'result':result})
        try:
            self.o.primitive('create_cube',{'name':name});step('Create Cube',{'name':name});material=self.o.create_pbr_material({'name':name+'_PBR','base_color':[.42,.28,.12,1],'metallic':.15,'roughness':.55})['material'];self.o.assign_material({'object':name,'material':material});step('Apply PBR Material',{'material':material});self.o.add_modifier({'object':name,'type':'Bevel','width':.05,'segments':2});step('Bevel',{});step('UV',self.o.smart_uv_project({'object':name}));lod=self.create_lods({'object':name,'preset':'android_medium'});step('LOD',lod)
            root=self.o.object(name);lod0=self.o.object(lod['lods'][0]['name']);preview=self.render_preview({'engine':'Cycles','width':256,'height':256,'samples':8,'path':str(folder/(name+'.png')),'overwrite':a.get('overwrite',False)});step('Render Preview',{k:v for k,v in preview.items() if k!='artifacts'})
            glb=self.export_for_godot({'path':str(folder/(name+'.glb')),'objects':[l['name'] for l in lod['lods']],'overwrite':a.get('overwrite',False)});step('Export GLB',{k:v for k,v in glb.items() if k not in {'artifacts','validation'}});step('Validate Godot Asset',glb['validation'])
            result={'passed':all(s['passed'] for s in steps) and glb['validation']['valid'],'steps':steps,'artifacts':preview['artifacts']+glb['artifacts'],'cleanup':a.get('cleanup',True)}
        finally:
            if a.get('cleanup',True):
                for ob in list(set(bpy.data.objects)-before):bpy.data.objects.remove(ob,do_unlink=True)
                if material in bpy.data.materials:bpy.data.materials.remove(bpy.data.materials[material],do_unlink=True)
                step('Cleanup',{'objects_removed':True})
        return result
