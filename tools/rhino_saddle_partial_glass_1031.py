# -*- coding: utf-8 -*-
"""Separate render skins along exact diagrid lines; retain the original collider."""
from __future__ import unicode_literals, division
import Rhino, scriptcontext as sc, System, math, json, io, time
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
GLASS_CELLS=set([(-34,82),(-34,83),(-34,84),(-33,83),(-33,84),
                 (-33,85),(-33,86),(-32,85),(-32,86),(-32,87)])

def clip(poly,axis,bound,greater):
    out=[];a=poly[-1];av=(a[axis]-bound)*(1 if greater else -1)
    for b in poly:
        bv=(b[axis]-bound)*(1 if greater else -1)
        if (av>=0)!=(bv>=0):
            t=av/(av-bv);out.append(tuple(a[k]+(b[k]-a[k])*t for k in range(5)))
        if bv>=0:out.append(b)
        a=b;av=bv
    return out

def apply():
    ns=sc.sticky['saddle_builder_ns_1030'];d=ns['state']()
    obj=sc.doc.Objects.FindId(System.Guid(d['contact_skin_id']));original=obj.Geometry
    assert obj.Name=='PR_Saddle_ContactSkin_Continuous'
    assert not obj.Attributes.GetUserString('collision_only'),'Partial glass already applied'
    before=int(original.DataCRC(0));ids_before=list(d['objects'])
    options=Rhino.FileIO.FileWriteOptions();options.SuppressDialogBoxes=True
    backup=ROOT+'/.current_map_build/before_saddle_glass_'+time.strftime('%Y%m%d_%H%M%S')+'.3dm'
    assert sc.doc.Write3dmFile(backup,options)
    uv=[q for row in d['contact_skin_rows'] for q in row];count=len(uv)
    assert original.Vertices.Count==count*2,'Unexpected continuous skin topology'
    mesh=original.DuplicateMesh();mesh.Faces.ConvertQuadsToTriangles()
    render={'panel':G.Mesh(),'contact_glass':G.Mesh()};areas={'panel':0.,'contact_glass':0.}
    def vertex(i):
        u,v=uv[i%count];x=1100.+420.*u;y=270.+340.*v;p=mesh.Vertices[i]
        return (y-x,y+x,float(p.X),float(p.Y),float(p.Z))
    def append(target,poly):
        for i in range(1,len(poly)-1):
            pp=[G.Point3d(*r[2:]) for r in [poly[0],poly[i],poly[i+1]]]
            area=G.Vector3d.CrossProduct(pp[1]-pp[0],pp[2]-pp[0]).Length*.5
            if area<.00002:continue
            k=target.Vertices.Count
            for p in pp:target.Vertices.Add(p)
            target.Faces.AddFace(k,k+1,k+2)
    for face in mesh.Faces:
        indices=[face.A,face.B,face.C];top=all(i<count for i in indices)
        triangle=[vertex(i) for i in indices]
        for ia in range(int(math.floor(min(q[0] for q in triangle)/20.)),int(math.floor(max(q[0] for q in triangle)/20.))+1):
            for ib in range(int(math.floor(min(q[1] for q in triangle)/20.)),int(math.floor(max(q[1] for q in triangle)/20.))+1):
                poly=triangle
                for axis,bound,greater in [(0,ia*20.,True),(0,(ia+1)*20.,False),(1,ib*20.,True),(1,(ib+1)*20.,False)]:
                    if len(poly)<3:break
                    poly=clip(poly,axis,bound,greater)
                if len(poly)<3:continue
                key='contact_glass' if (ia,ib) in GLASS_CELLS else 'panel'
                # Thin glass has a single optical interface, avoiding stacked
                # alpha layers that make a transparent slab look opaque.
                if key=='contact_glass' and not top:continue
                append(render[key],poly)
                if top:
                    origin=G.Point3d(*poly[0][2:])
                    for j in range(1,len(poly)-1):
                        areas[key]+=G.Vector3d.CrossProduct(G.Point3d(*poly[j][2:])-origin,G.Point3d(*poly[j+1][2:])-origin).Length*.5
    d['materials']['contact_glass']=ns['material']('contact_glass',(148,186,190),.17,0.,.30)
    for key,part in render.items():
        part.Vertices.CombineIdentical(True,True);part.Faces.CullDegenerateFaces();part.Vertices.CullUnused()
        part.Normals.ComputeNormals();part.Compact();assert part.IsValid and part.Faces.Count>0
        ns['add'](part,'ContactSkin_'+('GlassPanes' if key=='contact_glass' else 'OpaquePanes'),
            '05_\u4e0b\u5782\u89d2\u90e8\u6b8b\u5b58\u9762\u677f',key,
            {'visual_only':True,'role':'Exact diagrid-clipped render skin; original continuous collider retained'})
    attr=obj.Attributes.Duplicate();old_category=attr.GetUserString('category')
    category='07_\u8fde\u7eed\u901a\u884c\u78b0\u649e'
    attr.LayerIndex=ns['layer'](ns['LAYER']+'::'+category)
    attr.SetUserString('category',category);attr.SetUserString('collision_only','true')
    attr.SetUserString('role','Original complete watertight collision. Hidden, geometry unchanged.')
    assert sc.doc.Objects.ModifyAttributes(obj.Id,attr,True)
    d['categories'][old_category]-=1;d['categories'][category]=1
    layer=sc.doc.Layers[attr.LayerIndex];layer.IsVisible=False;layer.IsLocked=True;layer.CommitChanges()
    assert int(sc.doc.Objects.FindId(obj.Id).Geometry.DataCRC(0))==before
    ratio=areas['contact_glass']/sum(areas.values())
    assert .25<ratio<.45,'Glass should remain a minority of the infill'
    report={'source':sc.doc.Path,'backup':backup,'glass_cells':sorted(list(GLASS_CELLS)),
        'area_m2':areas,'glass_fraction':ratio,'continuous_collision_id':str(obj.Id),
        'collision_crc_before':before,'collision_crc_after':int(original.DataCRC(0)),
        'new_render_object_ids':d['objects'][len(ids_before):],
        'native_objects':len(d['objects']),'preserve_planting':True}
    d['partial_glass']=report
    ns['write']('partial_glass_1031.json',report);sc.doc.Views.Redraw()
    return report
