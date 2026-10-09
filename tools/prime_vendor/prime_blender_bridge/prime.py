"""Deterministic modular medieval meshes, not stock placeholders or remote images."""
from __future__ import annotations
import json
import math
import random
import uuid
import bpy
from mathutils import Vector
from .safety import SafetyError

STAGES=['Village','Town','City','Country','Kingdom','Empire']
BUILDINGS='house keep castle town_hall palisade stone_wall gate watchtower barracks archery_range stable blacksmith academy warehouse farm windmill lumber_yard quarry market road bridge fence cart well'.split()
PALETTE={'Stone':([.31,.34,.35,1],.0,.75),'Limestone':([.67,.60,.45,1],.0,.67),'Timber':([.16,.075,.029,1],.0,.68),'Plaster':([.70,.64,.48,1],.0,.78),'Roof':([.15,.20,.22,1],.18,.52),'Iron':([.085,.10,.12,1],.82,.32),'Gold':([.62,.37,.07,1],.8,.29),'Dark':([.027,.021,.017,1],0,.8),'Cloth':([.28,.055,.042,1],0,.8),'Leaves':([.065,.16,.06,1],0,.9),'Ground':([.22,.16,.085,1],0,.92),'Grass':([.14,.23,.065,1],0,.93),'Water':([.04,.17,.19,1],.05,.2)}

class PrimeAssets:
    def __init__(self,d):self.d=d;self.o=d.ops;self.root=None;self.rng=random.Random(42);self.level=0;self.detail='medium'
    def handlers(self):
        h={}
        for kind in BUILDINGS+['terrain','riverside_props','market_props','castle_props']:h['prime_create_'+kind]=lambda a,kind=kind:self.create(kind,a)
        for kind in ['tree','rock','grass']:h['prime_create_'+kind+'_variants']=lambda a,kind=kind:self.variants(kind,a)
        h['prime_upgrade_building_visual']=self.prime_upgrade_building_visual;return h
    def material(self,kind):
        name='PRIME_'+kind;m=bpy.data.materials.get(name)
        if m:return m
        color,metal,rough=PALETTE[kind];self.o.create_pbr_material({'name':name,'base_color':color,'metallic':metal,'roughness':rough});m=bpy.data.materials[name]
        if kind not in {'Gold','Iron','Dark','Water','Cloth'}:
            nodes=m.node_tree.nodes;links=m.node_tree.links;bs=nodes.get('Principled BSDF');coords=nodes.new('ShaderNodeTexCoord');noise=nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=8 if kind in {'Timber','Roof'} else 18;noise.inputs['Detail'].default_value=2;links.new(coords.outputs['Object'],noise.inputs['Vector']);ramp=nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.25;ramp.color_ramp.elements[0].color=tuple(c*.75 if i<3 else 1 for i,c in enumerate(color));ramp.color_ramp.elements[1].position=.8;ramp.color_ramp.elements[1].color=color;links.new(noise.outputs['Fac'],ramp.inputs['Fac']);links.new(ramp.outputs['Color'],bs.inputs['Base Color']);bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.13;bump.inputs['Distance'].default_value=.025;links.new(noise.outputs['Fac'],bump.inputs['Height']);links.new(bump.outputs['Normal'],bs.inputs['Normal'])
        return m
    def attach(self,ob,label,material,location=None):
        ob.name=self.root.name+'_'+label;ob.parent=self.root
        if location is not None:ob.location=location
        if hasattr(ob.data,'materials'):ob.data.materials.append(self.material(material))
        ob['prime_component']=label;return ob
    def box(self,label,location,size,material='Stone',rotation=0):
        bpy.ops.mesh.primitive_cube_add(size=1);ob=bpy.context.object;ob.dimensions=size;self.o.activate(ob);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);self.attach(ob,label,material,location);ob.rotation_euler.z=rotation;return ob
    def cylinder(self,label,location,radius,depth,material='Stone',vertices=16,radius2=None):
        if radius2 is None:bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth)
        else:bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=radius,radius2=radius2,depth=depth)
        ob=bpy.context.object;return self.attach(ob,label,material,location)
    def mesh(self,label,vertices,faces,material):
        data=bpy.data.meshes.new(self.root.name+'_'+label);data.from_pydata(vertices,[],faces);data.update();ob=bpy.data.objects.new(data.name,data);bpy.context.collection.objects.link(ob);return self.attach(ob,label,material,[0,0,0])
    def beam(self,label,start,end,width=.12,material='Timber'):
        start,end=Vector(start),Vector(end);ob=self.box(label,list((start+end)/2),[width,width,(end-start).length],material);ob.rotation_euler=(end-start).to_track_quat('Z','Y').to_euler();return ob
    def gable(self,label,x,y,z,w,depth,height,material='Roof'):
        verts=[(x-w/2,y-depth/2,z),(x+w/2,y-depth/2,z),(x,y-depth/2,z+height),(x-w/2,y+depth/2,z),(x+w/2,y+depth/2,z),(x,y+depth/2,z+height)]
        return self.mesh(label,verts,[(0,2,1),(3,4,5),(0,1,4,3),(0,3,5,2),(1,2,5,4)],material)
    def roof(self,x,y,z,w,depth,height):
        self.gable('Roof',x,y,z,w,depth,height);self.beam('Ridge',(x,y-depth/2-.05,z+height),(x,y+depth/2+.05,z+height),.12,'Iron' if self.level>2 else 'Timber')
        for side in [-1,1]:
            self.beam('Roof_Eave',(x+side*w/2,y-depth/2,z),(x+side*w/2,y+depth/2,z),.14)
            for end in [-1,1]:self.beam('Roof_Trim',(x+side*w/2,y+end*depth/2,z),(x,y+end*depth/2,z+height),.12,'Gold' if self.level>3 else 'Timber')
        if self.detail!='low':
            courses=3 if self.detail=='medium' else 6
            for i in range(1,courses):
                t=i/courses
                for side in [-1,1]:self.beam('Tile_Course',(x+side*w/2*(1-t),y-depth/2,z+height*t+.015),(x+side*w/2*(1-t),y+depth/2,z+height*t+.015),.035,'Roof')
    def window(self,x,y,z,w=.55,h=.8):
        self.box('Window_Recess',[x,y,z],[w,.07,h],'Dark');self.box('Window_Sill',[x,y-.04,z-h/2],[w+.17,.20,.09],'Limestone')
        for side in [-1,1]:self.box('Window_Frame',[x+side*w/2,y-.055,z],[.06,.07,h+.05],'Gold' if self.level>3 else 'Timber')
        self.box('Window_Mullion',[x,y-.10,z],[.04,.06,h],'Iron');self.box('Window_Crossbar',[x,y-.10,z],[w,.06,.045],'Iron')
    def door(self,x,y,z,w=.9,h=1.5):
        self.box('Door',[x,y,z+h/2],[w,.1,h],'Timber')
        for side in [-1,1]:self.box('Door_Frame',[x+side*(w+.12)/2,y-.01,z+h/2],[.15,.2,h+.2],'Limestone')
        self.box('Door_Lintel',[x,y-.02,z+h],[w+.4,.2,.18],'Limestone')
        for height in [.25,.75]:self.box('Door_Iron',[x,y-.075,z+h*height],[w,.08,.06],'Iron')
    def banner(self,x,y,z,h=1.5):
        self.beam('Banner_Pole',(x,y,z),(x,y,z+h),.055,'Iron');w=h*.4;self.mesh('Royal_Banner',[(x,y,z+h),(x+w,y,z+h),(x+w,y,z+h*.4),(x+w*.5,y,z+h*.3),(x,y,z+h*.4)],[(0,1,2,3,4)],'Cloth')
        if self.level>=3:self.box('Banner_Gold',[x+w*.5,y-.015,z+h*.7],[w*.14,.025,h*.25],'Gold')
    def house(self,w=4,depth=3,h=2.8,x=0,y=0):
        self.box('Foundation',[x,y,.2],[w+.3,depth+.3,.4],'Stone');self.box('Walls',[x,y,.4+h/2],[w,depth,h],'Plaster' if self.level<2 else 'Limestone');self.roof(x,y,.4+h,w+.5,depth+.5,1.35+self.level*.1)
        for xx in [-w/2,w/2]:
            for yy in [-depth/2,depth/2]:self.box('Corner_Timber',[x+xx,y+yy,.4+h/2],[.18,.18,h+.1],'Timber')
        self.box('Timber_Belt',[x,y-depth/2-.03,.4+h*.65],[w,.12,.13],'Timber');self.door(x,y-depth/2-.10,.4,w=.8,h=1.5)
        for xx in [-w*.3,w*.3]:self.window(x+xx,y-depth/2-.065,.4+h*.67,w=.48,h=.72)
        self.box('Chimney',[x+w*.25,y+depth*.2,h+1.25],[.45,.5,1.6],'Stone');self.box('Chimney_Cap',[x+w*.25,y+depth*.2,h+2.08],[.60,.64,.14],'Limestone')
        if self.level>=1:
            self.box('Doorstep',[x,y-depth/2-.6,.2],[1.45,1,.3],'Stone');self.banner(x+w*.48,y-depth/2-.1,h*.85,1+self.level*.2)
        if self.level>=2:
            self.house_annex(x+w*.65,y,.4,w*.4,depth*.85,h*.75)
        if self.level>=4:self.tower(x-w*.65,y+depth*.2,r=.7,h=h+2)
    def house_annex(self,x,y,z,w,depth,h):
        self.box('Annex',[x,y,z+h/2],[w,depth,h],'Limestone');self.roof(x,y,z+h,w+.25,depth+.25,.7)
    def crenels(self,x,y,z,length,axis='X',material='Limestone'):
        count=max(2,int(length/.65));step=length/count
        for i in range(count):
            offset=-length/2+(i+.5)*step;location=[x+offset if axis=='X' else x,y+offset if axis=='Y' else y,z+.20];self.box('Battlement',location,[.4,.55,.4] if axis=='X' else [.55,.4,.4],material)
    def wall(self,x,y,length,h=2.7,axis='X',wood=False):
        if wood:
            for i in range(max(2,int(length/.38))):
                offset=-length/2+i*.38;self.cylinder('Palisade_Log',[x+offset if axis=='X' else x,y+offset if axis=='Y' else y,h/2],.17,h,'Timber',8);self.cylinder('Palisade_Tip',[x+offset if axis=='X' else x,y+offset if axis=='Y' else y,h+.18],.17,.36,'Timber',8,0)
            self.box('Palisade_Brace',[x,y,h*.3],[length,.16,.14] if axis=='X' else [.16,length,.14],'Timber')
        else:
            self.box('Rampart',[x,y,h/2],[length,.6,h] if axis=='X' else [.6,length,h],'Stone');self.box('Wall_Cap',[x,y,h],[length+.1,.75,.14] if axis=='X' else [.75,length+.1,.14],'Limestone');self.crenels(x,y,h,length,axis)
            if self.level>1:
                for i in range(max(2,int(length/2))):
                    offset=-length/2+(i+.5)*length/max(2,int(length/2));self.box('Wall_Buttress',[x+offset if axis=='X' else x,y+offset if axis=='Y' else y,h*.36],[.45,.95,h*.72] if axis=='X' else [.95,.45,h*.72],'Limestone')
    def tower(self,x,y,r=1,h=5):
        self.cylinder('Tower_Base',[x,y,.2],r*1.15,.4,'Stone',16);self.cylinder('Tower',[x,y,h/2],r,h,'Stone',16);self.cylinder('Tower_Belt',[x,y,h*.55],r*1.05,.2,'Limestone',16);self.cylinder('Tower_Parapet',[x,y,h],r*1.13,.30,'Limestone',16)
        for i in range(8):
            angle=i*math.pi/4;self.box('Tower_Crenel',[x+math.cos(angle)*r,y+math.sin(angle)*r,h+.42],[.4,.45,.55],'Limestone',angle)
        self.window(x,y-r-.02,h*.6,w=.28,h=1.05)
        if self.level>=2:self.cylinder('Tower_Roof',[x,y,h+.9],r*.85,1.6,'Roof',16,0)
        if self.level>=3:self.banner(x,y,h+1.7,1.25)
    def keep(self,w=5,depth=4,h=6,x=0,y=0):
        self.box('Keep_Foundation',[x,y,.25],[w+.6,depth+.6,.5],'Stone');self.box('Keep_Walls',[x,y,h/2],[w,depth,h],'Limestone');self.box('Keep_Cornice',[x,y,h*.8],[w+.28,depth+.28,.22],'Limestone');self.roof(x,y,h,w+.4,depth+.4,1.5+self.level*.2)
        for z in [h*.32,h*.68]:
            for xx in [-w*.28,w*.28]:self.window(x+xx,y-depth/2-.04,z,w=.7,h=1.15)
        self.door(x,y-depth/2-.09,.3,w=1.35,h=2.1)
        for xx in [-w*.43,w*.43]:
            self.box('Keep_Buttress',[x+xx,y-depth/2-.2,h*.42],[.5,.5,h*.84],'Stone')
        if self.level>=1:
            for xx,yy in [(-w/2,-depth/2),(w/2,-depth/2)]:self.tower(x+xx,y+yy,r=.65,h=h*.9)
        if self.level>=3:
            self.box('Royal_Tier',[x,y,h+1],[w*.6,depth*.65,2],'Limestone');self.roof(x,y,h+2,w*.65,depth*.7,1.5);self.banner(x,y,h+3.5,1.7)
    def arch_gate(self,x,y,w=2,h=3,depth=.8):
        self.box('Gate_Left',[x-w*.75,y,h/2],[w*.5,depth,h],'Stone');self.box('Gate_Right',[x+w*.75,y,h/2],[w*.5,depth,h],'Stone')
        archbase=h*.65;inner=w*.5;outer=inner+.45
        for i in range(10):
            a=i*math.pi/10;b=(i+1)*math.pi/10;verts=[]
            for yy in [y-depth/2,y+depth/2]:
                verts.extend([(x+math.cos(a)*inner,yy,archbase+math.sin(a)*inner),(x+math.cos(b)*inner,yy,archbase+math.sin(b)*inner),(x+math.cos(b)*outer,yy,archbase+math.sin(b)*outer),(x+math.cos(a)*outer,yy,archbase+math.sin(a)*outer)])
            self.mesh('Arch_Voussoir',verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'Limestone')
        for i in range(7):self.box('Portcullis',[x-w*.42+i*w*.14,y+.04,archbase*.5],[.055,.06,archbase],'Iron')
        for z in [.6,1.2,1.8]:self.box('Portcullis_Rail',[x,y,z],[w,.08,.05],'Iron')
    def castle(self,w=13,depth=11,h=5):
        self.box('Castle_Platform',[0,0,.12],[w+1.6,depth+1.6,.25],'Stone');self.keep(w=5+self.level*.3,depth=4+self.level*.25,h=h+2,x=0,y=depth*.10)
        for xx in [-w/2,w/2]:self.wall(xx,0,depth,h*.62,axis='Y')
        self.wall(0,depth/2,w,h*.62)
        for side in [-1,1]:self.wall(side*(w/4+1),-depth/2,w/2-2,h*.62)
        self.arch_gate(0,-depth/2,w=2.4,h=h*.66,depth=1);self.box('Gate_Crown',[0,-depth/2,h*.66+1.4],[4.0,1,.4],'Limestone');self.crenels(0,-depth/2,h*.66+1.6,4)
        for xx in [-w/2,w/2]:
            for yy in [-depth/2,depth/2]:self.tower(xx,yy,r=1.15+self.level*.06,h=h+1)
        for side in [-1,1]:self.house_annex(side*w*.27,depth*.28,.25,w*.24,depth*.35,h*.52)
        self.box('Courtyard_Path',[0,-depth*.25,.28],[2,depth*.55,.08],'Limestone')
        if self.level>=3:
            for side in [-1,1]:self.tower(side*2,-depth*.50,r=.85,h=h+2);self.banner(side*2,-depth*.50,h+3.8,1.5)
        if self.level>=4:
            for side in [-1,1]:self.wall(side*(w/2+2),0,depth+3,h*.4,'Y');self.tower(side*(w/2+2),depth/2+1.5,r=1,h=h*.9)
    def cart(self,x=0,y=0):
        self.box('Cart_Bed',[x,y,.85],[1.3,2,.12],'Timber')
        for side in [-1,1]:
            for height in [1,1.25,1.5]:self.box('Cart_Rail',[x+side*.64,y,height],[.07,2,.12],'Timber')
            self.box('Cart_End',[x,y+side*.95,1.2],[1.3,.08,.65],'Timber')
        for yy in [-.65,.65]:
            self.beam('Axle',(x-.85,y+yy,.55),(x+.85,y+yy,.55),.08,'Iron')
            for side in [-1,1]:
                bpy.ops.mesh.primitive_torus_add(major_segments=16,minor_segments=6,major_radius=.43,minor_radius=.055);ob=bpy.context.object;self.attach(ob,'Cart_Wheel','Timber',[x+side*.77,y+yy,.55]);ob.rotation_euler.y=math.pi/2
                for angle in [0,math.pi/4,math.pi/2,math.pi*.75]:self.beam('Wheel_Spoke',(x+side*.77,y+yy-math.cos(angle)*.40,.55-math.sin(angle)*.40),(x+side*.77,y+yy+math.cos(angle)*.40,.55+math.sin(angle)*.40),.035,'Timber')
        for side in [-1,1]:self.beam('Cart_Handle',(x+side*.5,y-.8,.75),(x+side*.5,y-2.7,.55),.10)
    def well(self,x=0,y=0):
        # Hollow well masonry is a ring of individual stones, not a solid cylinder.
        for layer in range(3):
            for i in range(12):
                angle=2*math.pi*(i+layer*.5)/12;self.box('Well_Stone',[x+math.cos(angle)*.65,y+math.sin(angle)*.65,.18+layer*.25],[.33,.25,.23],'Stone',angle+math.pi/2)
        self.cylinder('Well_Water',[x,y,.16],.5,.025,'Water',16)
        for side in [-1,1]:self.box('Well_Post',[x+side*.8,y,1.45],[.15,.18,2.3],'Timber')
        self.roof(x,y,2.5,2,1.3,.65);self.beam('Well_Spindle',(x-.75,y,1.65),(x+.75,y,1.65),.07,'Iron');self.beam('Well_Rope',(x,y,1.65),(x,y,.5),.025,'Timber')
    def market_stall(self,x=0,y=0):
        for xx in [-1.2,1.2]:
            for yy in [-.8,.8]:self.box('Market_Post',[x+xx,y+yy,1.3],[.08,.08,2.6],'Timber')
        self.mesh('Market_Canopy',[(x-1.4,y-.95,2.6),(x,y-.95,2.9),(x+1.4,y-.95,2.6),(x-1.4,y+.95,2.6),(x,y+.95,2.9),(x+1.4,y+.95,2.6)],[(0,1,4,3),(1,2,5,4)],'Cloth');self.box('Market_Counter',[x,y-.45,.85],[2.5,.8,.12],'Timber')
        for i in range(4):self.box('Produce_Crate',[x-1+i*.65,y-.5,1.05],[.5,.5,.3],'Timber')
    def create(self,kind,a):
        self.level=STAGES.index(a.get('stage','Village'));self.detail=a.get('detail_level','medium');self.rng=random.Random(a.get('seed',42));name=a.get('name','PRIME_'+kind.title().replace('_','')+'_'+a.get('stage','Village'))
        if name in bpy.data.objects:raise SafetyError('Asset name already exists; use an explicit unique name or upgrade the existing asset')
        root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root);root.empty_display_type='CUBE';root.empty_display_size=.3;root.location=a.get('location',[0,0,0]);self.root=root
        root['prime_asset_type']=kind;root['prime_stage']=a.get('stage','Village');root['prime_style']='Medieval semi-realistic premium mobile strategy';root['prime_args']=json.dumps({k:v for k,v in a.items() if k not in {'confirm','device_id'}},sort_keys=True);root['prime_reference']=json.dumps(a.get('reference',{}));root['prime_quality']='android_medium'
        dims=a.get('dimensions',[4+self.level*.5,3+self.level*.4,3+self.level*.5])
        if any(v<=0 for v in dims):bpy.data.objects.remove(root,do_unlink=True);raise SafetyError('Asset dimensions must be positive')
        w,depth,h=dims
        try:
            if kind=='castle':self.castle(w=max(12,w*2.5),depth=max(10,depth*2.5),h=max(4,h))
            elif kind=='keep':self.keep(w,depth,h+2)
            elif kind=='house':self.house(w,depth,h)
            elif kind=='town_hall':
                self.house(w*1.6,depth*1.4,h*1.3);self.tower(0,depth*.25,r=.85,h=h*2.2);self.banner(0,depth*.25,h*2.2+1.8,1.6)
            elif kind in {'palisade','stone_wall','fence'}:self.wall(0,0,a.get('length',8),h if kind!='fence' else 1.2,wood=kind!='stone_wall')
            elif kind=='gate':self.arch_gate(0,0,w=max(1.8,w*.6),h=h+1,depth=1)
            elif kind=='watchtower':self.tower(0,0,r=max(.8,w*.25),h=h+3)
            elif kind=='windmill':
                self.cylinder('Mill_Tower',[0,0,h*.8],w*.33,h*1.6,'Limestone',16,w*.24);self.cylinder('Mill_Cap',[0,0,h*1.8],w*.35,h*.6,'Roof',16,0);self.door(0,-w*.33,.1)
                for i in range(4):
                    angle=i*math.pi/2+.35;start=(math.cos(angle)*.2,-w*.33-.16,h*1.4+math.sin(angle)*.2);end=(math.cos(angle)*h*.9,-w*.33-.16,h*1.4+math.sin(angle)*h*.9);self.beam('Windmill_Sail',start,end,.3,'Timber');self.beam('Sail_Frame',start,end,.055,'Iron')
            elif kind=='farm':
                self.house(w*.6,depth*.6,h*.7,x=-w*.5,y=0)
                self.box('Field',[w*.5,0,.04],[w*1.2,depth*1.8,.08],'Ground')
                for i in range(10):
                    x=w*.5-w*.55+i*w*1.1/9;self.box('Crop_Row',[x,0,.16],[.1,depth*1.6,.25],'Grass')
                self.wall(w*.5,-depth*.9,w*1.2,h=1,wood=True)
            elif kind=='market':
                for x,y in [(-1.7,0),(1.7,0),(0,3.5)]:self.market_stall(x,y)
                self.well(0,-2.7)
            elif kind=='well':self.well()
            elif kind=='cart':self.cart()
            elif kind=='road':
                length=a.get('length',8);self.box('Road',[0,0,.03],[w*.6,length,.06],'Ground')
                for side in [-1,1]:self.box('Road_Edge',[side*w*.31,0,.055],[.1,length,.07],'Stone')
            elif kind=='bridge':
                length=a.get('length',8);segments=a.get('segments',12)
                for i in range(segments):
                    t=(i+.5)/segments;y=(t-.5)*length;z=math.sin(t*math.pi)*1.1+.25;self.box('Bridge_Deck',[0,y,z],[w,length/segments*.98,.22],'Stone' if self.level>0 else 'Timber')
                    for side in [-1,1]:self.box('Bridge_Rail',[side*w*.52,y,z+.8],[.14,length/segments,.18],'Timber');self.box('Bridge_Post',[side*w*.52,y,z+.4],[.12,.12,.85],'Stone')
                for yy in [-length*.35,length*.35]:self.box('Bridge_Pier',[0,yy,-.2],[w*.8,.6,1.7],'Stone')
            elif kind=='terrain':self.terrain(a)
            elif kind in {'riverside_props','market_props','castle_props'}:
                for i in range(a.get('count',8)):
                    x=self.rng.uniform(-w,w);y=self.rng.uniform(-depth,depth)
                    if kind=='market_props':self.market_stall(x,y) if i%3==0 else self.cart(x,y)
                    elif kind=='castle_props':self.banner(x,y,0,2.2) if i%2 else self.box('Supply_Crate',[x,y,.45],[.8,.8,.9],'Timber')
                    else:self.rock(x,y,0,.6) if i%2 else self.grass(x,y,0,.7)
            else:
                self.house(w*1.3,depth,h)
                if kind=='barracks':self.box('Drill_Yard',[0,-depth-1,.02],[w*1.3,depth,.04],'Ground');self.banner(-w*.6,-depth-1,0,2.6)
                elif kind=='archery_range':
                    for i in range(3):
                        x=-w*.4+i*w*.4;self.cylinder('Archery_Target',[x,-depth,1.1],.55,.12,'Timber',16).rotation_euler.x=math.pi/2;self.cylinder('Target_Bullseye',[x,-depth-.08,1.1],.16,.03,'Cloth',16).rotation_euler.x=math.pi/2;self.box('Target_Post',[x,-depth,.6],[.08,.08,1.2],'Timber')
                elif kind=='stable':
                    for i in range(4):self.box('Stable_Partition',[-w*.5+i*w/3,-depth*.8,.7],[.1,depth*.7,1.4],'Timber')
                    self.box('Feeding_Trough',[0,-depth*1.1,.4],[w,.45,.6],'Timber')
                elif kind=='blacksmith':
                    self.box('Forge',[w*.75,-depth*.2,.7],[1.2,1.0,1.4],'Stone');self.box('Forge_Fire',[w*.75,-depth*.72,.65],[.7,.06,.55],'Dark');self.box('Anvil_Base',[w*.7,-depth,1],[.5,.5,.7],'Timber');self.box('Anvil',[w*.7,-depth,1.4],[.9,.3,.18],'Iron');self.cylinder('Anvil_Horn',[w*.7+.6,-depth,1.4],.15,.55,'Iron',8,0).rotation_euler.y=math.pi/2
                elif kind=='academy':self.tower(w*.7,depth*.2,r=.7,h=h*1.8);self.banner(0,-depth*.6,h+1.2,1.8)
                elif kind=='warehouse':
                    for i in range(6):self.box('Warehouse_Crate',[-w*.5+(i%3)*w*.4,-depth*.8,(i//3)*.7+.35],[.65,.6,.65],'Timber')
                elif kind=='lumber_yard':
                    for i in range(7):self.cylinder('Stacked_Log',[-w*.6+(i%4)*.38,-depth*.9,(i//4)*.35+.2],.17,2.2,'Timber',10).rotation_euler.x=math.pi/2
                elif kind=='quarry':
                    for i in range(7):self.rock(w*.9+self.rng.uniform(-.8,.8),self.rng.uniform(-depth,depth),0,self.rng.uniform(.5,1.1))
                    self.cart(-w*.7,-depth)
            meshes=[o for o in root.children_recursive if o.type=='MESH']
            for i,ob in enumerate(meshes):
                self.d.checkpoint(i/max(1,len(meshes)))
                self.o.smart_uv_project({'object':ob.name})
                if self.detail!='low' and len(ob.data.polygons)<=100 and min(ob.dimensions)>.08:
                    self.o.add_modifier({'object':ob.name,'type':'Bevel','width':min(.025,min(ob.dimensions)*.08),'segments':1})
            self.o.activate(root);bounds=self.o.bounds(meshes)
            return {'object':root.name,'asset_type':kind,'stage':root['prime_stage'],'components':len(meshes),'triangle_count':sum(self.o.triangles(o) for o in meshes),'bounding_box':bounds,'reference_metadata':a.get('reference',{}),'style':root['prime_style']}
        except Exception:
            for ob in reversed(list(root.children_recursive)):bpy.data.objects.remove(ob,do_unlink=True)
            bpy.data.objects.remove(root,do_unlink=True);raise
    def tree(self,x,y,z,height):
        self.cylinder('Tree_Trunk',[x,y,z+height*.35],height*.075,height*.7,'Timber',10,height*.035)
        for i in range(7):
            angle=i*2.39996;radius=height*.20*(.8 if i>3 else 1);cx=x+math.cos(angle)*radius;cy=y+math.sin(angle)*radius;cz=z+height*(.55+i*.055);self.beam('Tree_Branch',(x,y,z+height*.48),(cx,cy,cz),height*.025,'Timber');bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=height*self.rng.uniform(.18,.26));ob=bpy.context.object;self.attach(ob,'Tree_Crown','Leaves',[cx,cy,cz]);ob.scale=(1,.85,1.1)
    def rock(self,x,y,z,size):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1);ob=bpy.context.object
        for v in ob.data.vertices:v.co*=self.rng.uniform(.83,1.17)
        self.attach(ob,'Natural_Rock','Stone',[x,y,z+size*.35]);ob.scale=(size,size*self.rng.uniform(.65,1.2),size*.7);ob.rotation_euler.z=self.rng.uniform(0,math.pi)
    def grass(self,x,y,z,size):
        verts=[];faces=[]
        for i in range(14):
            angle=self.rng.uniform(0,math.pi*2);xx=x+self.rng.uniform(-size*.3,size*.3);yy=y+self.rng.uniform(-size*.3,size*.3);h=size*self.rng.uniform(.4,1);w=size*.035;idx=len(verts);verts.extend([(xx-w,yy,z),(xx+w,yy,z),(xx+math.cos(angle)*size*.12,yy+math.sin(angle)*size*.12,z+h)]);faces.append((idx,idx+1,idx+2))
        self.mesh('Grass_Tuft',verts,faces,'Grass')
    def terrain(self,a):
        w,depth,h=a.get('dimensions',[20,20,1]);count=min(64,a.get('segments',24));verts=[];faces=[]
        for j in range(count+1):
            for i in range(count+1):
                x=(i/count-.5)*w;y=(j/count-.5)*depth;z=(math.sin(x*.25)*math.cos(y*.31)*.5+self.rng.uniform(-.08,.08))*min(h,3);verts.append((x,y,z))
        for j in range(count):
            for i in range(count):idx=j*(count+1)+i;faces.append((idx,idx+1,idx+count+2,idx+count+1))
        self.mesh('Terrain_Surface',verts,faces,'Ground')
        for i in range(a.get('count',8)):
            x=self.rng.uniform(-w*.48,w*.48);y=self.rng.uniform(-depth*.48,depth*.48)
            if i%3==0:self.rock(x,y,.05,.8)
            else:self.grass(x,y,.05,.5)
    def variants(self,kind,a):
        name=a.get('name','PRIME_'+kind.title()+'Variants');self.rng=random.Random(a.get('seed',42));self.level=0;self.detail='medium'
        if name in bpy.data.objects:raise SafetyError('Variant asset name exists')
        root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root);root.location=a.get('location',[0,0,0]);root['prime_asset_type']=kind;root['prime_style']='Medieval semi-realistic premium mobile strategy';root['prime_reference']=json.dumps(a.get('reference',{}));self.root=root
        for i in range(a.get('count',3)):
            self.d.checkpoint(i/a.get('count',3));size=self.rng.uniform(2.8,4.5) if kind=='tree' else self.rng.uniform(.6,1.4)
            getattr(self,kind)(i*(5 if kind=='tree' else 2),0,0,size)
        for ob in root.children_recursive:
            if ob.type=='MESH':self.o.smart_uv_project({'object':ob.name})
        self.o.activate(root);return {'object':root.name,'variants':a.get('count',3),'triangle_count':sum(self.o.triangles(o) for o in root.children_recursive),'reference_metadata':a.get('reference',{})}
    def prime_upgrade_building_visual(self,a):
        old=self.o.object(a['object']);kind=old.get('prime_asset_type');from_stage=old.get('prime_stage')
        if kind not in BUILDINGS:raise SafetyError('Visual stage upgrades require a PRIME-generated building with retained construction metadata')
        if a.get('from_stage') and a['from_stage']!=from_stage:raise SafetyError('from_stage does not match the asset')
        if a['to_stage']==from_stage:raise SafetyError('Asset is already at that stage')
        original_name=old.name;matrix=old.matrix_world.copy();args=json.loads(old.get('prime_args','{}'));args.update(name=original_name,stage=a['to_stage']);args.pop('location',None)
        if 'reference' in a:args['reference']=a['reference']
        old.name=original_name+'_UpgradeSource_'+uuid.uuid4().hex[:6]
        try:result=self.create(kind,args);new=self.o.object(result['object']);new.matrix_world=matrix
        except Exception:old.name=original_name;raise
        for ob in reversed(list(old.children_recursive)):bpy.data.objects.remove(ob,do_unlink=True)
        bpy.data.objects.remove(old,do_unlink=True);result['from_stage']=from_stage;result['to_stage']=a['to_stage'];result['geometry_rebuilt']=True;return result
