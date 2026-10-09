from __future__ import annotations
import math
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector
from .safety import SafetyError

class Operations:
    def __init__(self,d):self.d=d
    def handlers(self):
        h={n:getattr(self,n) for n in ['blender_status','get_blender_version','get_scene_info','get_active_object','get_selected_objects','get_recent_logs','list_scenes','create_scene','list_collections','create_collection','delete_collection','list_objects','get_object','select_objects','set_active_object','duplicate_object','rename_object','delete_object','hide_object','show_object','apply_transforms','set_origin','create_curve','create_text','add_modifier','remove_modifier','apply_modifier','join_objects','separate_object','merge_by_distance','recalculate_normals','shade_smooth','shade_flat','analyze_mesh','analyze_scene_performance','list_materials','create_material','create_pbr_material','duplicate_material','assign_material','remove_material','load_texture','assign_texture','create_pbr_texture_set','resize_texture','validate_texture_resolution','find_missing_textures','pack_textures','smart_uv_project','unwrap_uv','pack_uv_islands','validate_uv','set_texel_density','list_cameras','create_camera','set_active_camera','set_camera_transform','delete_light','setup_strategy_game_lighting','save_blend','save_blend_as','create_snapshot','undo','redo','list_actions','list_animations','play_animation','set_animation_range','validate_animation','list_armatures','get_bones','validate_armature','apply_pose','retarget_basic_animation']}
        for n in ['set_location','set_rotation','set_scale','set_transform']:h[n]=lambda a,n=n:self.transform(n,a)
        for n in ['create_cube','create_plane','create_cylinder','create_cone','create_sphere']:h[n]=lambda a,n=n:self.primitive(n,a)
        for n in ['boolean_union','boolean_difference','boolean_intersect']:h[n]=lambda a,n=n:self.boolean(n,a)
        for n in ['create_sun','create_area_light','create_point_light']:h[n]=lambda a,n=n:self.light(n,a)
        return h
    def object(self,name,kind=None):
        ob=bpy.data.objects.get(name)
        if ob is None:raise SafetyError('Object not found: '+name)
        if ob.name not in bpy.context.scene.objects:raise SafetyError('Object is not in the active scene')
        if kind and ob.type!=kind:raise SafetyError('Expected '+kind+' object')
        return ob
    def material(self,name):
        m=bpy.data.materials.get(name)
        if m is None:raise SafetyError('Material not found: '+name)
        return m
    def activate(self,ob):
        for x in bpy.context.selected_objects:x.select_set(False)
        ob.hide_set(False);ob.select_set(True);bpy.context.view_layer.objects.active=ob
    def members(self,ob):
        return [ob]+list(ob.children_recursive)
    def meshes(self,names=None):
        obs=[]
        for ob in ([self.object(n) for n in names] if names else list(bpy.context.selected_objects) or list(bpy.context.scene.objects)):
            obs.extend(x for x in self.members(ob) if x.type=='MESH')
        return list(dict.fromkeys(obs))
    def triangles(self,ob):
        if ob.type!='MESH':return 0
        deps=bpy.context.evaluated_depsgraph_get();evaluated=ob.evaluated_get(deps);mesh=evaluated.to_mesh()
        try:mesh.calc_loop_triangles();return len(mesh.loop_triangles)
        finally:evaluated.to_mesh_clear()
    def bounds(self,objects):
        bpy.context.view_layer.update()
        pts=[ob.matrix_world@Vector(c) for ob in objects if ob.type in {'MESH','CURVE','FONT','SURFACE'} for c in ob.bound_box]
        if not pts:return {'min':[0,0,0],'max':[0,0,0],'dimensions':[0,0,0]}
        low=[min(p[i] for p in pts) for i in range(3)];high=[max(p[i] for p in pts) for i in range(3)]
        return {'min':low,'max':high,'dimensions':[high[i]-low[i] for i in range(3)]}
    def info(self,ob):
        return {'name':ob.name,'type':ob.type,'location':list(ob.location),'rotation':[math.degrees(v) for v in ob.rotation_euler],'scale':list(ob.scale),'dimensions':list(ob.dimensions),'triangles':self.triangles(ob),'materials':[s.material.name if s.material else None for s in ob.material_slots],'modifiers':[{'name':m.name,'type':m.type} for m in ob.modifiers],'parent':ob.parent.name if ob.parent else None,'children':[c.name for c in ob.children],'hidden':ob.hide_get(),'bounding_box':self.bounds(self.members(ob))}
    def blender_status(self,a):return {'connected':True,'version':bpy.app.version_string,'background':bpy.app.background,'scene':bpy.context.scene.name,'active_object':bpy.context.object.name if bpy.context.object else None}
    def get_blender_version(self,a):return {'version':bpy.app.version_string,'version_tuple':list(bpy.app.version),'platform':__import__('platform').system()}
    def get_scene_info(self,a):return dict(self.analyze_scene_performance(a),scene=bpy.context.scene.name,active_object=bpy.context.object.name if bpy.context.object else None,selected_objects=[o.name for o in bpy.context.selected_objects],frame=bpy.context.scene.frame_current)
    def get_active_object(self,a):return {'object':self.info(bpy.context.object) if bpy.context.object else None}
    def get_selected_objects(self,a):return {'objects':[self.info(o) for o in bpy.context.selected_objects]}
    def get_recent_logs(self,a):return {'logs':list(self.d.logs)[-a.get('limit',50):]}
    def list_scenes(self,a):return {'scenes':[s.name for s in bpy.data.scenes],'active':bpy.context.scene.name}
    def create_scene(self,a):
        if a['name'] in bpy.data.scenes:raise SafetyError('Scene name already exists')
        s=bpy.data.scenes.new(a['name'])
        if a.get('activate',True):bpy.context.window.scene=s
        return {'scene':s.name}
    def list_collections(self,a):return {'collections':[{'name':c.name,'objects':len(c.objects),'children':[x.name for x in c.children]} for c in bpy.data.collections]}
    def create_collection(self,a):
        if a['name'] in bpy.data.collections:raise SafetyError('Collection already exists')
        parent=bpy.data.collections.get(a.get('parent','')) if a.get('parent') else bpy.context.scene.collection
        if parent is None:raise SafetyError('Parent collection not found')
        c=bpy.data.collections.new(a['name']);parent.children.link(c);return {'collection':c.name}
    def delete_collection(self,a):
        c=bpy.data.collections.get(a['collection'])
        if c is None:raise SafetyError('Collection not found')
        if a.get('delete_objects'):
            for ob in list(c.all_objects):bpy.data.objects.remove(ob,do_unlink=True)
        else:
            for ob in list(c.all_objects):
                if ob.name not in bpy.context.scene.collection.objects:bpy.context.scene.collection.objects.link(ob)
        bpy.data.collections.remove(c);return {'deleted_collection':a['collection']}
    def list_objects(self,a):return {'objects':[self.info(o) for o in bpy.context.scene.objects]}
    def get_object(self,a):return {'object':self.info(self.object(a['object']))}
    def select_objects(self,a):
        obs=[self.object(n) for n in a['objects']]
        if not a.get('extend'):
            for x in bpy.context.selected_objects:x.select_set(False)
        for o in obs:o.hide_set(False);o.select_set(True)
        bpy.context.view_layer.objects.active=obs[0];return {'selected':[o.name for o in bpy.context.selected_objects]}
    def set_active_object(self,a):ob=self.object(a['object']);self.activate(ob);return {'active_object':ob.name}
    def duplicate_object(self,a):
        ob=self.object(a['object']);copy=ob.copy()
        if ob.data:copy.data=ob.data.copy()
        copy.name=a.get('name',ob.name+'_copy');bpy.context.collection.objects.link(copy);return {'object':self.info(copy)}
    def rename_object(self,a):
        ob=self.object(a['object'])
        if a['name'] in bpy.data.objects and a['name']!=ob.name:raise SafetyError('Object name already exists')
        ob.name=a['name'];return {'object':ob.name}
    def delete_object(self,a):
        ob=self.object(a['object']);names=[x.name for x in self.members(ob)]
        for x in reversed(self.members(ob)):bpy.data.objects.remove(x,do_unlink=True)
        return {'deleted_objects':names}
    def hide_object(self,a):
        ob=self.object(a['object'])
        for x in self.members(ob):x.hide_set(True);x.hide_render=True
        return {'hidden':ob.name}
    def show_object(self,a):
        ob=self.object(a['object'])
        for x in self.members(ob):x.hide_set(False);x.hide_render=False
        return {'shown':ob.name}
    def transform(self,n,a):
        ob=self.object(a['object'])
        for k in ['location','rotation','scale']:
            if k in a:
                if k=='rotation':ob.rotation_euler=[math.radians(v) for v in a[k]]
                else:setattr(ob,k,a[k])
        bpy.context.view_layer.update();return {'object':self.info(ob)}
    def apply_transforms(self,a):
        ob=self.object(a['object']);self.activate(ob);bpy.ops.object.transform_apply(location=a.get('location',False),rotation=a.get('rotation',True),scale=a.get('scale',True));return {'object':self.info(ob)}
    def set_origin(self,a):
        ob=self.object(a['object']);self.activate(ob);mode={'geometry':'ORIGIN_GEOMETRY','cursor':'ORIGIN_CURSOR','center_of_mass':'ORIGIN_CENTER_OF_MASS'}[a.get('mode','geometry')]
        bpy.ops.object.origin_set(type=mode,center='MEDIAN');return {'object':self.info(ob)}
    def primitive(self,n,a):
        location=a.get('location',[0,0,0]);radius=a.get('radius',1);depth=a.get('depth',2);segments=a.get('segments',16)
        if n=='create_cube':bpy.ops.mesh.primitive_cube_add(size=a.get('size',2),location=location)
        elif n=='create_plane':bpy.ops.mesh.primitive_plane_add(size=a.get('size',2),location=location)
        elif n=='create_cylinder':bpy.ops.mesh.primitive_cylinder_add(vertices=segments,radius=radius,depth=depth,location=location)
        elif n=='create_cone':bpy.ops.mesh.primitive_cone_add(vertices=segments,radius1=radius,radius2=0,depth=depth,location=location)
        else:bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=max(4,segments//2),radius=radius,location=location)
        ob=bpy.context.object;ob.name=a.get('name',n.removeprefix('create_').title())
        if 'rotation' in a:ob.rotation_euler=[math.radians(v) for v in a['rotation']]
        if 'scale' in a:ob.scale=a['scale']
        return {'object':self.info(ob)}
    def create_curve(self,a):
        curve=bpy.data.curves.new(a.get('name','PRIME_Curve'),'CURVE');curve.dimensions='3D';curve.bevel_depth=a.get('bevel_depth',.05);curve.resolution_u=8
        spline=curve.splines.new('POLY');points=a.get('points',[[0,0,0],[1,0,0]]);spline.points.add(len(points)-1)
        for p,co in zip(spline.points,points):p.co=(*co,1)
        ob=bpy.data.objects.new(curve.name,curve);bpy.context.collection.objects.link(ob);ob.location=a.get('location',[0,0,0]);return {'object':self.info(ob)}
    def create_text(self,a):
        data=bpy.data.curves.new(a.get('name','PRIME_Text'),'FONT');data.body=a.get('text','PRIME');data.extrude=.02
        ob=bpy.data.objects.new(data.name,data);bpy.context.collection.objects.link(ob);ob.location=a.get('location',[0,0,0]);return {'object':self.info(ob)}
    def add_modifier(self,a):
        ob=self.object(a['object'],'MESH');types={'Bevel':'BEVEL','Mirror':'MIRROR','Array':'ARRAY','Solidify':'SOLIDIFY','Subdivision':'SUBSURF','Decimate':'DECIMATE','WeightedNormal':'WEIGHTED_NORMAL'}
        m=ob.modifiers.new(a.get('modifier','PRIME_'+a['type']),types[a['type']])
        if m.type=='BEVEL':m.width=a.get('width',.03);m.segments=a.get('segments',2);m.limit_method='ANGLE'
        elif m.type=='MIRROR':m.use_axis=[a.get('axis','X')==x for x in ['X','Y','Z']]
        elif m.type=='ARRAY':m.count=a.get('count',2);m.relative_offset_displace=a.get('offset',[1.1,0,0])
        elif m.type=='SOLIDIFY':m.thickness=a.get('thickness',.05)
        elif m.type=='SUBSURF':m.levels=a.get('levels',1);m.render_levels=m.levels
        elif m.type=='DECIMATE':m.ratio=a.get('ratio',.5)
        else:m.keep_sharp=True
        return {'modifier':m.name,'object':ob.name,'triangles':self.triangles(ob)}
    def remove_modifier(self,a):
        ob=self.object(a['object']);m=ob.modifiers.get(a['modifier'])
        if m is None:raise SafetyError('Modifier not found')
        ob.modifiers.remove(m);return {'removed':a['modifier']}
    def apply_modifier(self,a):
        ob=self.object(a['object']);self.activate(ob)
        if a['modifier'] not in ob.modifiers:raise SafetyError('Modifier not found')
        bpy.ops.object.modifier_apply(modifier=a['modifier']);return {'object':self.info(ob)}
    def join_objects(self,a):
        obs=[self.object(n,'MESH') for n in a['objects']];self.select_objects({'objects':a['objects']});bpy.ops.object.join();ob=bpy.context.object
        if a.get('name'):ob.name=a['name']
        return {'object':self.info(ob)}
    def separate_object(self,a):
        ob=self.object(a['object'],'MESH');self.activate(ob);before=set(bpy.data.objects)
        bpy.ops.object.mode_set(mode='EDIT')
        try:
            if a.get('mode','loose')!='selected':bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.mesh.separate(type={'loose':'LOOSE','material':'MATERIAL','selected':'SELECTED'}[a.get('mode','loose')])
        finally:bpy.ops.object.mode_set(mode='OBJECT')
        return {'objects':[o.name for o in set(bpy.data.objects)-before]+[ob.name]}
    def merge_by_distance(self,a):
        ob=self.object(a['object'],'MESH');mesh=ob.data;bm=bmesh.new();bm.from_mesh(mesh);before=len(bm.verts)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=a.get('distance',.0001));bm.to_mesh(mesh);after=len(bm.verts);bm.free();mesh.update();return {'merged_vertices':before-after}
    def recalculate_normals(self,a):
        ob=self.object(a['object'],'MESH');bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free();ob.data.update();return {'object':ob.name}
    def shade_smooth(self,a):
        ob=self.object(a['object'],'MESH')
        for p in ob.data.polygons:p.use_smooth=True
        return {'object':ob.name,'shading':'smooth'}
    def shade_flat(self,a):
        ob=self.object(a['object'],'MESH')
        for p in ob.data.polygons:p.use_smooth=False
        return {'object':ob.name,'shading':'flat'}
    def boolean(self,n,a):
        ob=self.object(a['object'],'MESH');other=self.object(a['operand'],'MESH')
        if ob==other:raise SafetyError('Boolean operands must be different objects')
        m=ob.modifiers.new('PRIME_Boolean','BOOLEAN');m.operation={'boolean_union':'UNION','boolean_difference':'DIFFERENCE','boolean_intersect':'INTERSECT'}[n];m.object=other;m.solver='EXACT'
        if a.get('apply',True):self.activate(ob);bpy.ops.object.modifier_apply(modifier=m.name)
        if a.get('delete_operand'):bpy.data.objects.remove(other,do_unlink=True)
        return {'object':self.info(ob)}
    def analyze_mesh(self,a):
        ob=self.object(a['object'],'MESH');mesh=ob.data;mesh.calc_loop_triangles();bm=bmesh.new();bm.from_mesh(mesh)
        result={'vertices':len(mesh.vertices),'edges':len(mesh.edges),'faces':len(mesh.polygons),'triangles':self.triangles(ob),'ngons':sum(len(p.vertices)>4 for p in mesh.polygons),'non_manifold':sum(not e.is_manifold for e in bm.edges),'loose_geometry':{'vertices':sum(not v.link_edges for v in bm.verts),'edges':sum(not e.link_faces for e in bm.edges)},'dimensions':list(ob.dimensions),'bounding_box':self.bounds([ob]),'materials':[m.name for m in mesh.materials if m],'uv_layers':[x.name for x in mesh.uv_layers],'vertex_groups':[x.name for x in ob.vertex_groups]};bm.free();return result
    def scene_images(self,obs=None):
        materials={s.material for o in (obs or bpy.context.scene.objects) for s in o.material_slots if s.material}
        trees=[m.node_tree for m in materials if m.use_nodes]
        if obs is None:
            trees += [x.node_tree for x in [bpy.context.scene.world]+[o.data for o in bpy.context.scene.objects if o.type=='LIGHT'] if x and x.use_nodes]
            if bpy.context.scene.use_nodes:trees.append(bpy.context.scene.node_tree)
        images=set();visited=set()
        def walk(tree):
            if not tree or tree in visited:return
            visited.add(tree)
            for node in tree.nodes:
                if hasattr(node,'image') and node.image:images.add(node.image)
                if node.type=='GROUP':walk(node.node_tree)
        for tree in trees:walk(tree)
        return images
    def verify_resources(self,obs=None):
        for image in self.scene_images(obs):
            if image.source in {'FILE','SEQUENCE','MOVIE','TILED'} and not image.packed_file:
                filename=bpy.path.abspath(image.filepath)
                if filename:self.d.paths.resolve(filename)
        for lib in bpy.data.libraries:self.d.paths.resolve(bpy.path.abspath(lib.filepath))
        for data in list(bpy.data.cache_files)+list(bpy.data.movieclips)+list(bpy.data.volumes):
            if data.filepath:self.d.paths.resolve(bpy.path.abspath(data.filepath))
        for font in bpy.data.fonts:
            if font.filepath and not font.filepath.startswith('<') and not font.packed_file:self.d.paths.resolve(bpy.path.abspath(font.filepath))
        if obs is None and bpy.context.scene.use_nodes:
            def check_outputs(tree,visited):
                if tree in visited:return
                visited.add(tree)
                for node in tree.nodes:
                    if node.type=='OUTPUT_FILE':
                        base=self.d.paths.directory(bpy.path.abspath(node.base_path))
                        for slot in node.file_slots:self.d.paths.resolve(str(base/(slot.path+'0001.png')),write=True,overwrite=True)
                    elif node.type=='GROUP' and node.node_tree:check_outputs(node.node_tree,visited)
            check_outputs(bpy.context.scene.node_tree,set())
    def analyze_scene_performance(self,a):
        obs=list(bpy.context.scene.objects);visible=[o for o in obs if not o.hide_render and not o.hide_get()];meshes=[o for o in visible if o.type=='MESH'];materials={s.material for o in meshes for s in o.material_slots if s.material};images=self.scene_images(meshes)
        return {'object_count':len(obs),'mesh_count':len([o for o in obs if o.type=='MESH']),'visible_mesh_count':len(meshes),'triangle_count':sum(self.triangles(o) for o in meshes),'material_count':len(materials),'texture_count':len(images),'estimated_texture_memory':int(sum(i.size[0]*i.size[1]*max(4,i.channels)*(4 if i.is_float else 1)*4/3 for i in images)),'light_count':sum(o.type=='LIGHT' for o in visible),'armature_count':sum(o.type=='ARMATURE' for o in visible),'animation_count':len(bpy.data.actions),'estimated_draw_calls':sum(max(1,len({p.material_index for p in o.data.polygons})) for o in meshes),'estimate_note':'Uncompressed texture bytes including mipmaps. Draw calls are material batches before Godot batching/instancing.'}
    def list_materials(self,a):return {'materials':[{'name':m.name,'users':m.users,'use_nodes':m.use_nodes} for m in bpy.data.materials]}
    def create_material(self,a):return self.create_pbr_material(a)
    def create_pbr_material(self,a):
        if a['name'] in bpy.data.materials:raise SafetyError('Material already exists')
        m=bpy.data.materials.new(a['name']);m.use_nodes=True;bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=a.get('base_color',[.5,.5,.5,1]);bs.inputs['Metallic'].default_value=a.get('metallic',0);bs.inputs['Roughness'].default_value=a.get('roughness',.6);bs.inputs['Alpha'].default_value=a.get('opacity',1)
        if 'emission' in a:bs.inputs['Emission Color'].default_value=a['emission'];bs.inputs['Emission Strength'].default_value=a.get('emission_strength',1)
        if a.get('opacity',1)<1:
            if hasattr(m,'surface_render_method'):m.surface_render_method='DITHERED'
            elif hasattr(m,'blend_method'):m.blend_method='BLEND'
        for channel in ['normal','ao']:
            if channel in a:
                t=self.load_texture({'path':a[channel],'colorspace':'Non-Color'})['texture'];self.assign_texture({'material':m.name,'texture':t,'channel':'Normal' if channel=='normal' else 'AO'})
        return {'material':m.name,'nodes':[n.type for n in m.node_tree.nodes]}
    def duplicate_material(self,a):m=self.material(a['material']).copy();m.name=a['name'];return {'material':m.name}
    def assign_material(self,a):
        ob=self.object(a['object']);m=self.material(a['material']);slot=a.get('slot',0)
        if ob.data is None or not hasattr(ob.data,'materials'):raise SafetyError('Object has no material slots')
        if slot>len(ob.data.materials):raise SafetyError('Slot must be existing or the next slot')
        if slot==len(ob.data.materials):ob.data.materials.append(m)
        else:ob.data.materials[slot]=m
        return {'object':ob.name,'material':m.name,'slot':slot}
    def remove_material(self,a):
        m=self.material(a['material'])
        if a.get('object'):
            ob=self.object(a['object'])
            for i in reversed(range(len(ob.data.materials))):
                if ob.data.materials[i]==m:ob.data.materials.pop(index=i)
        else:bpy.data.materials.remove(m,do_unlink=True)
        return {'removed':a['material']}
    def load_texture(self,a):
        p=self.d.paths.resolve(a['path'],extension={'.png','.jpg','.jpeg','.tga','.tif','.tiff','.exr','.hdr','.webp','.bmp'})
        image=bpy.data.images.load(str(p),check_existing=True)
        if a.get('name'):image.name=a['name']
        image.colorspace_settings.name=a.get('colorspace','sRGB');return {'texture':image.name,'size':list(image.size),'path':str(p)}
    def assign_texture(self,a):
        m=self.material(a['material']);image=bpy.data.images.get(a['texture'])
        if image is None:raise SafetyError('Texture not found')
        m.use_nodes=True;nodes=m.node_tree.nodes;links=m.node_tree.links;bs=next((n for n in nodes if n.type=='BSDF_PRINCIPLED'),None)
        if bs is None:raise SafetyError('Material needs a Principled BSDF')
        node=nodes.new('ShaderNodeTexImage');node.image=image;node.label='PRIME '+a['channel']
        channel=a['channel'];image.colorspace_settings.name='sRGB' if channel in ['Base Color','Emission'] else 'Non-Color'
        if channel=='Normal':
            normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=a.get('strength',1);links.new(node.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],bs.inputs['Normal'])
        elif channel=='AO':
            mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[1].default_value=bs.inputs['Base Color'].default_value
            existing=list(bs.inputs['Base Color'].links)
            if existing:links.new(existing[0].from_socket,mix.inputs[1])
            links.new(node.outputs['Color'],mix.inputs[2]);links.new(mix.outputs[0],bs.inputs['Base Color'])
            group=bpy.data.node_groups.get('glTF Material Output')
            if group is None:
                group=bpy.data.node_groups.new('glTF Material Output','ShaderNodeTree')
                if hasattr(group,'interface'):group.interface.new_socket(name='Occlusion',in_out='INPUT',socket_type='NodeSocketFloat')
                else:group.inputs.new('NodeSocketFloat','Occlusion')
            occlusion=nodes.new('ShaderNodeGroup');occlusion.node_tree=group;links.new(node.outputs['Color'],occlusion.inputs['Occlusion'])
        else:
            socket={'Base Color':'Base Color','Roughness':'Roughness','Metallic':'Metallic','Emission':'Emission Color','Opacity':'Alpha'}[channel];links.new(node.outputs['Color'],bs.inputs[socket])
            if channel=='Emission':bs.inputs['Emission Strength'].default_value=a.get('strength',1)
            if channel=='Opacity' and hasattr(m,'surface_render_method'):m.surface_render_method='DITHERED'
        return {'material':m.name,'texture':image.name,'channel':channel}
    def create_pbr_texture_set(self,a):
        result=[]
        for channel,p in a['textures'].items():
            texture=self.load_texture({'path':p,'colorspace':'sRGB' if channel in ['Base Color','Emission'] else 'Non-Color'})['texture'];result.append(self.assign_texture({'material':a['material'],'texture':texture,'channel':channel}))
        return {'textures':result}
    def resize_texture(self,a):
        image=bpy.data.images.get(a['texture'])
        if image is None:raise SafetyError('Texture not found')
        before=list(image.size);image.scale(a['width'],a['height'])
        if a.get('output_path'):
            p=self.d.paths.resolve(a['output_path'],write=True,overwrite=a.get('overwrite',False),extension={'.png'});image.filepath_raw=str(p);image.file_format='PNG';image.save()
        return {'texture':image.name,'before':before,'after':list(image.size)}
    def validate_texture_resolution(self,a):return {'max_size':a.get('max_size',2048),'oversized':[{'texture':i.name,'size':list(i.size)} for i in self.scene_images() if max(i.size)>a.get('max_size',2048)]}
    def find_missing_textures(self,a):return {'missing':[{'texture':i.name,'path':i.filepath} for i in self.scene_images() if i.source=='FILE' and not i.packed_file and not Path(bpy.path.abspath(i.filepath)).is_file()]}
    def pack_textures(self,a):
        self.verify_resources();images=list(self.scene_images())
        for i in images:
            if not i.packed_file:i.pack()
        return {'packed':[i.name for i in images]}
    def _uv(self,a,mode):
        ob=self.object(a['object'],'MESH');self.activate(ob);bpy.ops.object.mode_set(mode='EDIT')
        try:
            bpy.ops.mesh.select_all(action='SELECT')
            if mode=='smart':bpy.ops.uv.smart_project(angle_limit=math.radians(a.get('angle',66)),island_margin=a.get('margin',.02))
            elif mode=='unwrap':bpy.ops.uv.unwrap(method='ANGLE_BASED',margin=a.get('margin',.02))
            else:bpy.ops.uv.pack_islands(margin=a.get('margin',.02),rotate=True)
        finally:bpy.ops.object.mode_set(mode='OBJECT')
        return self.validate_uv({'object':ob.name})
    def smart_uv_project(self,a):return self._uv(a,'smart')
    def unwrap_uv(self,a):return self._uv(a,'unwrap')
    def pack_uv_islands(self,a):return self._uv(a,'pack')
    def validate_uv(self,a):
        ob=self.object(a['object'],'MESH');uv=ob.data.uv_layers.active
        if not uv:return {'valid':False,'uv_layers':0,'issues':['No UV layer']}
        outside=sum(any(c<-.0001 or c>1.0001 for c in loop.uv) for loop in uv.data);ob.data.calc_loop_triangles();zero=0;uv_area=0
        for t in ob.data.loop_triangles:
            p,q,r=[uv.data[i].uv for i in t.loops];area=abs((q.x-p.x)*(r.y-p.y)-(q.y-p.y)*(r.x-p.x))/2;uv_area+=area;zero+=area<1e-10
        return {'valid':not outside and not zero,'uv_layers':len(ob.data.uv_layers),'out_of_bounds_loops':outside,'zero_area_triangles':zero,'total_uv_area':uv_area,'issues':(['UV outside 0–1'] if outside else [])+(['Degenerate UV triangles'] if zero else []),'overlap_check':'Not included; tiled or intentionally overlapping UVs need visual review'}
    def set_texel_density(self,a):
        ob=self.object(a['object'],'MESH');report=self.validate_uv(a)
        if not ob.data.uv_layers.active:raise SafetyError('Create a UV layer first')
        world_area=sum(p.area for p in ob.data.polygons)*sum(abs(v) for v in ob.scale)/3
        if not world_area or not report.get('total_uv_area'):raise SafetyError('UV or mesh area is zero')
        current=a.get('texture_size',1024)*math.sqrt(report['total_uv_area']/world_area);factor=a['density']/current
        for loop in ob.data.uv_layers.active.data:loop.uv=(loop.uv-Vector((.5,.5)))*factor+Vector((.5,.5))
        return {'density_before':current,'density_after':a['density'],'validation':self.validate_uv(a)}
    def list_cameras(self,a):return {'cameras':[self.info(o) for o in bpy.context.scene.objects if o.type=='CAMERA'],'active':bpy.context.scene.camera.name if bpy.context.scene.camera else None}
    def create_camera(self,a):
        data=bpy.data.cameras.new(a.get('name','PRIME_Camera'));ob=bpy.data.objects.new(data.name,data);bpy.context.collection.objects.link(ob);ob.location=a.get('location',[12,-12,12]);ob.rotation_euler=[math.radians(v) for v in a.get('rotation',[54.736,0,45])]
        data.type='ORTHO' if a.get('orthographic',True) else 'PERSP';data.ortho_scale=a.get('ortho_scale',20);return {'camera':ob.name}
    def set_active_camera(self,a):ob=self.object(a['camera'],'CAMERA');bpy.context.scene.camera=ob;return {'camera':ob.name}
    def set_camera_transform(self,a):return self.transform('set_transform',dict(a,object=a['camera']))
    def light(self,n,a):
        data=bpy.data.lights.new(a.get('name','PRIME_'+n),'SUN' if n=='create_sun' else 'AREA' if n=='create_area_light' else 'POINT');ob=bpy.data.objects.new(data.name,data);bpy.context.collection.objects.link(ob);ob.location=a.get('location',[0,0,8]);ob.rotation_euler=[math.radians(v) for v in a.get('rotation',[25,-20,-35])];data.energy=a.get('energy',3 if data.type=='SUN' else 800);data.color=a.get('color',[1,.89,.74])
        if data.type=='AREA':data.shape='DISK';data.size=a.get('size',5)
        return {'light':ob.name,'type':data.type}
    def delete_light(self,a):self.object(a['object'],'LIGHT');return self.delete_object(a)
    def setup_strategy_game_lighting(self,a):
        target=Vector(a.get('target',[0,0,0]));size=a.get('size',20);created=[]
        for name in ['PRIME_Key','PRIME_Fill','PRIME_Rim','PRIME_Strategy_Camera']:
            ob=bpy.data.objects.get(name)
            if ob and ob.get('prime_lighting'):bpy.data.objects.remove(ob,do_unlink=True)
        for n,kwargs in [('create_sun',{'name':'PRIME_Key','energy':3,'color':[1,.85,.65],'rotation':[25,-25,-35]}),('create_area_light',{'name':'PRIME_Fill','energy':size*70,'color':[.65,.78,1],'location':list(target+Vector((-size,-size,size))),'size':size}),('create_area_light',{'name':'PRIME_Rim','energy':size*90,'color':[1,.82,.52],'location':list(target+Vector((size,size,size*1.5))),'size':size*.6})]:
            ob=self.object(self.light(n,kwargs)['light']);ob['prime_lighting']=True
            if ob.data.type!='SUN':ob.rotation_euler=(target-ob.location).to_track_quat('-Z','Y').to_euler()
            created.append(ob.name)
        if a.get('camera','isometric')=='top_down':position=target+Vector((0,-.001,size))
        else:position=target+Vector((size,-size,size*.85))
        camera=self.object(self.create_camera({'name':'PRIME_Strategy_Camera','location':list(position),'ortho_scale':size})['camera']);camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera['prime_lighting']=True;bpy.context.scene.camera=camera
        scene=bpy.context.scene
        if not scene.world:scene.world=bpy.data.worlds.new('PRIME_World')
        scene.world.use_nodes=True;bg=scene.world.node_tree.nodes.get('Background');bg.inputs['Color'].default_value=(.08,.12,.2,1);bg.inputs['Strength'].default_value=.35
        scene.view_settings.view_transform='AgX';return {'lights':created,'camera':camera.name}
    def save_blend(self,a):
        if not bpy.data.filepath:raise SafetyError('Use save_blend_as for an unsaved project')
        return self.save_blend_as(dict(a,path=bpy.data.filepath))
    def save_blend_as(self,a):
        path=self.d.paths.resolve(a['path'],write=True,overwrite=a.get('overwrite',False),extension={'.blend'});bpy.ops.wm.save_as_mainfile(filepath=str(path),check_existing=False);return {'path':str(path),'size':path.stat().st_size}
    def create_snapshot(self,a):
        path=self.d.paths.resolve(a['path'],write=True,overwrite=a.get('overwrite',False),extension={'.blend'});bpy.ops.wm.save_as_mainfile(filepath=str(path),copy=True,check_existing=False);return {'path':str(path),'size':path.stat().st_size}
    def undo(self,a):
        if bpy.app.background or not bpy.ops.ed.undo.poll():raise SafetyError('Undo requires an interactive Blender session with undo history; use snapshots for headless recovery')
        bpy.ops.ed.undo();return {'undone':True}
    def redo(self,a):
        if bpy.app.background or not bpy.ops.ed.redo.poll():raise SafetyError('Redo requires an interactive Blender session with redo history')
        bpy.ops.ed.redo();return {'redone':True}
    def list_actions(self,a):return {'actions':[{'name':x.name,'frame_range':list(x.frame_range),'users':x.users} for x in bpy.data.actions]}
    def list_animations(self,a):return {'animations':[{'object':o.name,'action':o.animation_data.action.name if o.animation_data.action else None,'nla_tracks':[t.name for t in o.animation_data.nla_tracks]} for o in bpy.context.scene.objects if o.animation_data]}
    def play_animation(self,a):
        ob=self.object(a['object']);action=bpy.data.actions.get(a['action'])
        if not action:raise SafetyError('Action not found')
        ob.animation_data_create();ob.animation_data.action=action;bpy.context.scene.frame_set(a.get('frame',int(action.frame_range[0])))
        if a.get('play'):
            if bpy.app.background or not bpy.ops.screen.animation_play.poll():raise SafetyError('Playback requires interactive Blender; action was assigned and the requested frame evaluated')
            bpy.ops.screen.animation_play()
        return {'object':ob.name,'action':action.name,'frame':bpy.context.scene.frame_current}
    def set_animation_range(self,a):
        if a['end']<a['start']:raise SafetyError('Animation end must follow start')
        scene=bpy.context.scene;scene.frame_start=a['start'];scene.frame_end=a['end'];return {'start':scene.frame_start,'end':scene.frame_end}
    def validate_animation(self,a):
        ob=self.object(a['object']);ad=ob.animation_data;issues=[]
        if not ad or not ad.action:issues.append('No active action')
        elif ad.action.frame_range[1]<=ad.action.frame_range[0]:issues.append('Animation needs at least two distinct frames')
        return {'valid':not issues,'issues':issues,'object':ob.name}
    def list_armatures(self,a):return {'armatures':[{'name':o.name,'bones':len(o.data.bones)} for o in bpy.context.scene.objects if o.type=='ARMATURE']}
    def get_bones(self,a):
        ob=self.object(a['object'],'ARMATURE');return {'bones':[{'name':b.name,'parent':b.parent.name if b.parent else None,'head':list(b.head_local),'tail':list(b.tail_local),'deform':b.use_deform} for b in ob.data.bones]}
    def validate_armature(self,a):
        ob=self.object(a['object'],'ARMATURE');issues=[]
        if any(abs(v-1)>1e-4 for v in ob.scale):issues.append('Armature has unapplied scale')
        if len(ob.data.bones)>128:issues.append('More than 128 bones is expensive on Android')
        if any(b.length<1e-5 for b in ob.data.bones):issues.append('Zero length bone')
        return {'valid':not issues,'bone_count':len(ob.data.bones),'issues':issues}
    def apply_pose(self,a):
        ob=self.object(a['object'],'ARMATURE')
        for entry in a['bones']:
            bone=ob.pose.bones.get(entry['bone'])
            if bone is None:raise SafetyError('Pose bone not found: '+entry['bone'])
            bone.rotation_mode='XYZ'
            if 'rotation' in entry:bone.rotation_euler=[math.radians(v) for v in entry['rotation']]
            if 'location' in entry:bone.location=entry['location']
            if 'scale' in entry:bone.scale=entry['scale']
            if a.get('keyframe'):
                for prop in ['location','rotation_euler','scale']:bone.keyframe_insert(prop,frame=a.get('frame',bpy.context.scene.frame_current))
        return {'object':ob.name,'bones_updated':len(a['bones'])}
    def retarget_basic_animation(self,a):
        source=self.object(a['source'],'ARMATURE');target=self.object(a['target'],'ARMATURE');start=a.get('start',1);end=a.get('end',60)
        if end<start or end-start>10000:raise SafetyError('Invalid retarget frame range')
        for entry in a['mapping']:
            if entry['source'] not in source.pose.bones or entry['target'] not in target.pose.bones:raise SafetyError('Retarget mapping contains a missing bone')
        original=bpy.context.scene.frame_current;target.animation_data_create();action=bpy.data.actions.new(target.name+'_Retarget');target.animation_data.action=action
        try:
            for frame in range(start,end+1):
                self.d.checkpoint((frame-start)/max(1,end-start));bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
                for entry in a['mapping']:
                    s=source.pose.bones[entry['source']];t=target.pose.bones[entry['target']];t.rotation_mode='QUATERNION'
                    # Copy local pose delta, respecting each rig's rest orientation.
                    t.matrix_basis=s.matrix_basis.copy();t.keyframe_insert('rotation_quaternion',frame=frame);t.keyframe_insert('location',frame=frame);t.keyframe_insert('scale',frame=frame)
        finally:bpy.context.scene.frame_set(original)
        return {'action':action.name,'frames':end-start+1,'method':'Local pose delta transfer for similar rigs; different proportions require review'}
