"""Read-only Rhino export, then bake a height-qualified coastal colour field.

Rhino: export_source(). Python: --bake. No model or planting data is modified.
"""
import json, math, hashlib, os, io

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT,'.current_map_build','mid_platform_palette_1110')
OUT = os.path.join(ROOT,'assets','world','meadow_zone_1030')
PLATFORM = 'bbea2185-f5e3-4821-a363-63f19f463bc4'
ROAD = '47800a9c-ca72-4dc5-8203-d6d5d91d29a9'
# User's annotation in the displayed 2048px reference. It limits the north end;
# actual trimmed CAD surface and road meshes provide the precise final boundary.
SCREEN = [[580,650],[588,690],[615,720],[650,800],[680,880],[700,920],
          [800,950],[850,962],[900,947],[950,915],[1000,860],[1040,800],
          [1060,720],[1057,665],[1047,627],[1033,610],[1000,619],[970,628],
          [930,641],[900,652],[875,659],[850,675],[825,691],[790,709],
          [755,721],[720,728],[690,730],[665,721],[630,704],[600,685]]

def export_source():
    import Rhino, Rhino.Geometry as G, scriptcontext as sc, System
    import System.Drawing as Drawing
    vp = sc.doc.Views.ActiveView.ActiveViewport
    expected = G.Point3d(1832.8589903594952,215.12179804884408,1769.988643185319)
    assert vp.CameraLocation.DistanceTo(expected)<.02, 'Restore the supplied MasterPreviousView before tracing'
    params=G.MeshingParameters();params.MaximumEdgeLength=5.;params.MinimumEdgeLength=.3
    params.GridMinCount=24;params.RefineGrid=True
    def mesh_row(sid, face=None):
        obj=sc.doc.Objects.FindId(System.Guid(sid))
        brep=obj.Geometry if face is None else obj.Geometry.Faces[face].DuplicateFace(False)
        mesh=G.Mesh()
        for part in G.Mesh.CreateFromBrep(brep,params):mesh.Append(part)
        mesh.Faces.ConvertQuadsToTriangles();mesh.UnifyNormals();mesh.Normals.ComputeNormals()
        return dict(id=sid,face=face,geometry_crc=int(obj.Geometry.DataCRC(0)),
                    vertices=[[float(v.X)-1450.,float(v.Z),1150.-float(v.Y)] for v in mesh.Vertices],
                    triangles=[[f.A,f.B,f.C] for f in mesh.Faces])
    polygon=[]
    for x,y in SCREEN:
        line=vp.ClientToWorld(Drawing.Point(int(round((x-98)*1832./1467.)),int(round((y-135)*1172./939.))))
        t=(35.-line.From.Z)/(line.To.Z-line.From.Z)
        p=line.PointAt(t);polygon.append([p.X-1450.,1150.-p.Y])
    data=dict(platform=mesh_row(PLATFORM,2),road=mesh_row(ROAD),polygon=polygon,
              reference_image='codex-clipboard-f396e4a8-6d21-4695-afcb-3e0231ca5df3.png',
              screen_polygon=SCREEN,viewport=[1832,1172],height=35.,rhino_read_only=True)
    if not os.path.isdir(CACHE):os.makedirs(CACHE)
    with io.open(os.path.join(CACHE,'source.json'),'w',encoding='utf-8') as stream:stream.write(json.dumps(data,ensure_ascii=False,separators=(',',':')))
    return dict(platform=PLATFORM,face=2,height=35.,triangles=len(data['platform']['triangles']),road_triangles=len(data['road']['triangles']),rhino_modified=sc.doc.Modified)

def bake():
    from pathlib import Path
    import numpy as np
    from PIL import Image,ImageDraw
    from scipy.ndimage import distance_transform_edt
    cache=Path(CACHE);out=Path(OUT)
    source=json.loads((cache/'source.json').read_text(encoding='utf-8'))
    polygon=np.asarray(source['polygon']);step=.5
    low=np.floor(polygon.min(0)-5);high=np.ceil(polygon.max(0)+5)
    size=tuple(int(n) for n in np.ceil((high-low)/step))
    def coordinates(points):return [tuple((np.asarray(p)[[0,2]]-low)/step) for p in points]
    actual=Image.new('L',size);draw=ImageDraw.Draw(actual)
    vertices=np.asarray(source['platform']['vertices'])
    for indices in source['platform']['triangles']:
        tri=vertices[indices]
        if np.max(np.abs(tri[:,1]-35))<.01:draw.polygon(coordinates(tri),fill=255)
    annotation=Image.new('L',size);ImageDraw.Draw(annotation).polygon([tuple((p-low)/step) for p in polygon],fill=255)
    road=Image.new('L',size);draw=ImageDraw.Draw(road)
    vertices=np.asarray(source['road']['vertices'])
    for indices in source['road']['triangles']:
        tri=vertices[indices];normal=np.cross(tri[1]-tri[0],tri[2]-tri[0])
        if abs(normal[1])<.72*np.linalg.norm(normal) or np.min(tri[:,1])>36 or np.max(tri[:,1])<34:continue
        draw.polygon(coordinates(tri),fill=255)
    # Colour is independent of planting/white-curb exclusions. Cutting this field
    # at asphalt plus a verge left a green band in otherwise blue roadside grass.
    # The road's own material and existing grass/curb masks still exclude asphalt.
    road_distance=distance_transform_edt(np.asarray(road)==0)*step
    surface=(np.asarray(actual)>0)&(np.asarray(annotation)>0)
    inside=surface
    distance=(distance_transform_edt(inside)-distance_transform_edt(~inside))*step
    roadside=inside&(road_distance>0)&(road_distance<=4.5)&(distance>3.)
    samples=np.argwhere(roadside)
    assert len(samples)>100, 'Missing roadside colour regression samples'
    samples=samples[np.linspace(0,len(samples)-1,40,dtype=int)]
    roadside_samples=[[float(low[0]+(x+.5)*step),35.,float(low[1]+(z+.5)*step)] for z,x in samples]
    field=np.stack([np.clip(distance,-1000,1000),np.full(distance.shape,35.)],axis=-1).astype('<f2')
    field.tofile(cache/'coast_field.rgh')
    report=dict(origin=low.tolist(),extent=(np.asarray(size)*step).tolist(),size=list(size),pixel_size=step,
                height=35.,height_inner_tolerance=.2,height_outer_tolerance=.6,feather_inside_m=3.,road_verge_m=0.,
                roadside_area_m2=float(roadside.sum()*step*step),roadside_samples=roadside_samples,
                area_m2=float(inside.sum()*step*step),source_id=PLATFORM,source_face=2,
                native_geometry_crc=source['platform']['geometry_crc'],reference_image=source['reference_image'],
                polygon=source['polygon'],field_sha256=hashlib.sha256(field.tobytes()).hexdigest(),
                semantics='R=positive-inside signed metres, G=actual CAD height; feather only at region perimeter; colour includes verge; asphalt/curb exclusion remains independent')
    out.mkdir(parents=True,exist_ok=True)
    (out/'coast_region.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    Image.fromarray((inside*255).astype('uint8')).save(cache/'mask.png')
    print(json.dumps({k:report[k] for k in ['origin','extent','size','area_m2','height','field_sha256']}))

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--bake',action='store_true')
    if parser.parse_args().bake:bake()
