# -*- coding: utf-8 -*-
"""Read-only export of the exact reviewed saddle revision; no terrain edits."""
from __future__ import unicode_literals, division
import Rhino, scriptcontext as sc, System, io, json
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
CACHE=ROOT+'/.current_map_build'
TAG='island_saddle_1030'

def export():
    with io.open(ROOT+'/docs/island_saddle_1030/model_report.json','r',encoding='utf-8') as f:review=json.load(f)
    settings=Rhino.DocObjects.ObjectEnumeratorSettings()
    settings.NormalObjects=True;settings.HiddenObjects=True;settings.LockedObjects=True
    fingerprint=lambda:dict((str(o.Id),int(o.Geometry.DataCRC(0))) for o in sc.doc.Objects.GetObjectList(settings))
    before=fingerprint();modified=sc.doc.Modified;records=[];materials={}
    stream=System.IO.FileStream(CACHE+'/island_saddle_1031.bin',System.IO.FileMode.Create)
    writer=System.IO.BinaryWriter(stream)
    param=G.MeshingParameters.FastRenderMesh
    try:
        for sid in review['object_ids']:
            obj=sc.doc.Objects.FindId(System.Guid(sid))
            assert obj and not obj.IsDeleted and obj.Attributes.GetUserString('feature')==TAG
            category=obj.Attributes.GetUserString('category')
            if category.startswith('00_'):continue
            if isinstance(obj.Geometry,G.Mesh):mesh=obj.Geometry.DuplicateMesh()
            else:
                mesh=G.Mesh()
                for part in G.Mesh.CreateFromBrep(obj.Geometry,param):mesh.Append(part)
            mesh.Faces.ConvertQuadsToTriangles();mesh.Normals.ComputeNormals();mesh.Compact()
            assert mesh.IsValid and mesh.Faces.Count>0
            material=sc.doc.Materials[obj.Attributes.MaterialIndex];key=material.Name.replace('PR_Saddle_','')
            color=material.DiffuseColor
            materials[key]={'color':[color.R/255.,color.G/255.,color.B/255.],
                'roughness':float(material.PhysicallyBased.Roughness),'metallic':float(material.PhysicallyBased.Metallic),
                'opacity':float(material.PhysicallyBased.Opacity)}
            offset=int(stream.Position)
            for array in [mesh.Vertices.ToFloatArray(),mesh.Faces.ToIntArray(True)]:
                raw=System.Array.CreateInstance(System.Byte,array.Length*4)
                System.Buffer.BlockCopy(array,0,raw,0,raw.Length);writer.Write(raw)
            visual_only=obj.Attributes.GetUserString('visual_only')
            collision_only=obj.Attributes.GetUserString('collision_only')
            visual_only=bool(visual_only and visual_only.lower()=='true')
            collision_only=bool(collision_only and collision_only.lower()=='true')
            decorative=obj.Name.endswith('FlushPanelSeams') or category.startswith('03_') or visual_only
            box=mesh.GetBoundingBox(True);xyz=lambda p:[float(p.X),float(p.Y),float(p.Z)]
            records.append({'id':sid,'name':obj.Name,'category':category,'kind':'Structure','material_key':key,
                'offset':offset,'vertex_count':mesh.Vertices.Count,'index_count':mesh.Faces.Count*3,
                'bounds':[xyz(box.Min),xyz(box.Max)],'collision':not decorative,'watertight':mesh.IsClosed,
                'visible':not collision_only,'collision_only':collision_only,'visual_only':visual_only})
    finally:writer.Close()
    assert fingerprint()==before and sc.doc.Modified==modified,'Read-only CAD export changed the document'
    with io.open(ROOT+'/docs/island_saddle_1030/save_report.json','r',encoding='utf-8') as f:saved=json.load(f)
    result={'source':sc.doc.Path,'feature':TAG,'review_revision':saved['standalone'].replace('\\','/').split('/')[-1],
        'cad_unchanged':True,'native_center':[1450.,1150.,0.],'objects':records,'materials':materials,
        'preserve_planting':True,'walking_surface_name':'PR_Saddle_ContactSkin_Continuous'}
    if sc.sticky.get(TAG,{}).get('partial_glass'):result['partial_glass']=sc.sticky[TAG]['partial_glass']
    with io.open(CACHE+'/island_saddle_1031.json','w',encoding='utf-8') as f:f.write(json.dumps(result,ensure_ascii=False,indent=2))
    return {'objects':len(records),'triangles':sum(r['index_count']//3 for r in records),'cad_unchanged':True}
