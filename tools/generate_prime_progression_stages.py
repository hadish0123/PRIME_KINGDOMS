from __future__ import annotations
import sys, json, math, traceback
from pathlib import Path
import bpy, bmesh

REPO = Path(sys.argv[-1]).resolve()
sys.path.insert(0, str(REPO / "tools/prime_vendor"))
from prime_blender_bridge.dispatcher import Dispatcher

OUT_MODELS = REPO / "client/assets/models/environment"
OUT_IMAGES = REPO / "docs/evidence/graphics"
OUT_MODELS.mkdir(parents=True, exist_ok=True)
OUT_IMAGES.mkdir(parents=True, exist_ok=True)

STYLE = (
    "PRIME KINGDOMS premium semi-realistic medieval strategy art; realistic stone, timber and metal; "
    "dark slate roofs; royal blue heraldic cloth; restrained gold accents; strong readable isometric "
    "silhouettes; dense but ordered settlement; premium mobile strategy quality; Android-friendly."
)

STAGES = {
    "City": dict(slug="prime_city_stage3", prefix="PK_City", scale=1.00, camera=78, distance=85, seed=5000),
    "Country": dict(slug="prime_country_stage4", prefix="PK_Country", scale=1.14, camera=90, distance=100, seed=6000),
    "Kingdom": dict(slug="prime_kingdom_stage5", prefix="PK_Kingdom", scale=1.28, camera=102, distance=115, seed=7000),
    "Empire": dict(slug="prime_empire_stage6", prefix="PK_Empire", scale=1.42, camera=116, distance=130, seed=8000),
}

def args(name, stage, location, dimensions, seed, extra=None, notes=""):
    data = {
        "name": name, "stage": stage, "location": location, "dimensions": dimensions,
        "seed": seed, "detail_level": "high",
        "reference": {"title": f"PRIME KINGDOMS {stage} production stage", "style_notes": STYLE + " " + notes},
    }
    if extra: data.update(extra)
    return data

def cleanup_mesh(ob):
    if ob.type != "MESH": return
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.0001)
    bad = [f for f in bm.faces if f.calc_area() < 1e-10]
    if bad: bmesh.ops.delete(bm, geom=bad, context="FACES")
    if bm.faces: bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(ob.data); bm.free(); ob.data.update()

def merge_asset(d, root_name):
    root = bpy.data.objects.get(root_name)
    if root is None: raise RuntimeError(f"Missing root {root_name}")
    meshes = [o for o in root.children_recursive if o.type == "MESH" and o.get("prime_lod_level") is None]
    if not meshes:
        if root.type == "MESH": return root.name
        raise RuntimeError(f"No meshes for {root_name}")
    if len(meshes) == 1:
        ob = meshes[0]
        ob.name = root_name + "_Merged"
    else:
        result = d.ops.join_objects({"objects":[o.name for o in meshes], "name":root_name+"_Merged"})
        ob = bpy.data.objects[result["object"]["name"]]
    cleanup_mesh(ob)
    return ob.name

def atlas_if_hero(d, object_name, stage_slug, hero):
    if not hero: return object_name
    path = OUT_IMAGES / f"{stage_slug}-{object_name.lower().replace('pk_','')}-atlas.png"
    result = d.pipeline.bake("bake_texture_atlas", {
        "object": object_name, "source_objects":[object_name], "width":1024, "height":1024,
        "path":str(path), "overwrite":True, "samples":4, "margin":10, "cage_extrusion":0.01
    })
    d.ops.hide_object({"object":object_name})
    cleanup_mesh(bpy.data.objects[result["object"]])
    return result["object"]

def make_lods(d, source):
    result = d.pipeline.create_lods({"object":source, "preset":"android_medium"})
    for item in result["lods"]:
        cleanup_mesh(bpy.data.objects[item["name"]])
    return [item["name"] for item in result["lods"]]

def generate(stage, cfg):
    print(f"::group::Generate {stage}")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.name = f"PRIME_{stage}_Production"
    d = Dispatcher([str(REPO)])
    p, s, base = cfg["prefix"], cfg["scale"], cfg["seed"]
    defs = [
        ("castle", f"{p}_Citadel", [0, 12*s, 0], [15*s, 13*s, 11*s], True),
        ("town_hall", f"{p}_CivicHall", [0, -5*s, 0], [9*s, 7*s, 8*s], True),
        ("academy", f"{p}_Academy", [18*s, 11*s, 0], [8*s, 7*s, 7*s], True),
        ("market", f"{p}_Market", [17*s, -7*s, 0], [8*s, 7*s, 5*s], True),
        ("barracks", f"{p}_Barracks", [-19*s, 9*s, 0], [8*s, 7*s, 6*s], False),
        ("archery_range", f"{p}_Archery", [-21*s, -4*s, 0], [9*s, 7*s, 5*s], False),
        ("stable", f"{p}_Stable", [-19*s, -16*s, 0], [9*s, 7*s, 5*s], False),
        ("blacksmith", f"{p}_Blacksmith", [18*s, -18*s, 0], [7*s, 6*s, 6*s], False),
        ("warehouse", f"{p}_Warehouse", [22*s, 19*s, 0], [8*s, 7*s, 6*s], False),
        ("house", f"{p}_HouseA", [-10*s, -22*s, 0], [6*s, 5*s, 6*s], True),
        ("house", f"{p}_HouseB", [2*s, -23*s, 0], [6*s, 5*s, 6*s], False),
        ("house", f"{p}_HouseC", [12*s, -21*s, 0], [6*s, 5*s, 6*s], False),
        ("house", f"{p}_HouseD", [-29*s, 4*s, 0], [6*s, 5*s, 6*s], False),
        ("farm", f"{p}_Farm", [28*s, -20*s, 0], [9*s, 7*s, 4*s], False),
        ("windmill", f"{p}_Windmill", [29*s, 19*s, 0], [5*s, 5*s, 8*s], False),
        ("terrain", f"{p}_Terrain", [0,0,-0.45], [68*s, 64*s, 4*s], False),
        ("road", f"{p}_RoadMain", [0,-9*s,0], [5*s,34*s,0.2], False),
        ("road", f"{p}_RoadCross", [0,-3*s,0], [30*s,5*s,0.2], False),
        ("stone_wall", f"{p}_WallN", [0,33*s,0], [50*s,2*s,5*s], False),
        ("stone_wall", f"{p}_WallS", [0,-33*s,0], [50*s,2*s,5*s], False),
        ("stone_wall", f"{p}_WallE", [33*s,0,0], [50*s,2*s,5*s], False),
        ("stone_wall", f"{p}_WallW", [-33*s,0,0], [50*s,2*s,5*s], False),
        ("gate", f"{p}_Gate", [0,-33*s,0], [9*s,4*s,8*s], True),
        ("watchtower", f"{p}_TowerNW", [-32*s,32*s,0], [5*s,5*s,10*s], False),
        ("watchtower", f"{p}_TowerNE", [32*s,32*s,0], [5*s,5*s,10*s], False),
        ("bridge", f"{p}_Bridge", [0,-40*s,0], [10*s,14*s,3*s], False),
    ]
    roots=[]
    for idx,(kind,name,loc,dim,hero) in enumerate(defs):
        extra={}
        if kind in {"road","stone_wall","bridge"}:
            extra["length"] = (34*s if "RoadMain" in name else 30*s if "RoadCross" in name else 50*s if "Wall" in name else 14*s)
            extra["segments"] = 16
        result=d.prime.create(kind,args(name,stage,loc,dim,base+idx,extra,
            "Architecture must visibly communicate progression beyond the previous settlement tier."))
        roots.append((result["object"],hero))
        print(stage, kind, name, result.get("triangle_count"))
    # Environment packs.
    for k,loc,count in [("tree",[-35*s,20*s,0],4),("rock",[35*s,-25*s,0],5),("grass",[31*s,27*s,0],5)]:
        name=f"{p}_{k.title()}Pack"
        result=d.prime.variants(k,{"name":name,"location":loc,"count":count,"seed":base+100+len(roots),
            "reference":{"title":f"{stage} environment","style_notes":STYLE}})
        roots.append((result["object"],False))
    merged=[]
    for root,hero in roots:
        source=merge_asset(d,root)
        source=atlas_if_hero(d,source,cfg["slug"],hero)
        lods=make_lods(d,source)
        merged.append((root,lods,hero))
    # Show LOD0 only for render, all other levels hidden.
    for _,lods,_ in merged:
        for level,name in enumerate(lods):
            ob=bpy.data.objects[name]
            ob.hide_set(level!=0); ob.hide_render=(level!=0)
    d.ops.setup_strategy_game_lighting({"target":[0,0,4*s],"size":cfg["camera"],"warmth":0.66})
    render_path=OUT_IMAGES/f"{cfg['slug']}.png"
    render=d.pipeline.render_preview({"camera":"PRIME_Strategy_Camera","width":1280,"height":800,"samples":16,
        "engine":"Cycles","transparent_background":False,"path":str(render_path),"overwrite":True})
    # Export all four LODs so the generated Godot wrapper switches visibility ranges.
    export_names=[name for _,lods,_ in merged for name in lods]
    for name in export_names:
        cleanup_mesh(bpy.data.objects[name])
    exported=d.pipeline.prime_export_to_godot({
        "project_root":str(REPO),"asset_name":cfg["slug"],"asset_type":"environment",
        "objects":export_names,"overwrite":True,"quality_tier":"android_medium",
        "recommended_distance":cfg["distance"]
    })
    review=d.pipeline.prime_scene_review({})
    report={
        "stage":stage,"asset":cfg["slug"],"render":str(render_path.relative_to(REPO)),
        "export_path":exported["path"],"file_size":exported["file_size"],
        "validation":exported["validation"],"scene_review":review,
        "roots":[{"root":root,"lods":lods,"hero_atlas":hero} for root,lods,hero in merged],
    }
    (OUT_IMAGES/f"{cfg['slug']}.json").write_text(json.dumps(report,indent=2,default=str)+"\n")
    print(json.dumps({"stage":stage,"file_size":exported["file_size"],
        "triangles":exported["validation"]["triangle_count"],
        "draw_calls":review["performance"]["estimated_draw_calls"],
        "valid":exported["validation"]["valid"]}))
    print("::endgroup::")

def main():
    failures=[]
    for stage,cfg in STAGES.items():
        try: generate(stage,cfg)
        except Exception as exc:
            traceback.print_exc(); failures.append((stage,str(exc)))
    if failures:
        raise SystemExit("Generation failures: "+json.dumps(failures))
    print("All PRIME progression stages generated successfully.")

if __name__=="__main__": main()
