# -*- coding: utf-8 -*-
"""Repair the unintended crescent gap between western main and low bodies."""
from __future__ import unicode_literals,division
import Rhino,scriptcontext as sc,System,io,os,json
from System.Drawing.Imaging import ImageFormat
G=Rhino.Geometry
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'docs','concepts','cliff_terraces_2026-10-15','west_seam_v06')
TAG='prism_west_seam_v06'
IDS=['69bc8221-501f-4ef6-a4d7-d84906607fa5','f81baad1-a64c-48e0-a17f-f3a3c620659a']

def write(name,data):
    if not os.path.isdir(OUT):os.makedirs(OUT)
    with io.open(os.path.join(OUT,name),'w',encoding='utf-8') as f:f.write(json.dumps(data,ensure_ascii=False,indent=2,default=str))

def prepare():
    ns=sc.sticky['portal_recipe_namespace'];doc=sc.doc;site=sc.sticky[ns['TAG']]['site']
    objects=[ns['obj'](oid) for oid in IDS];main=objects[0].Geometry.Faces[0];low=objects[1].Geometry.Faces[6]
    span=G.Interval(site.rail.Domain.ParameterAt(.060),site.rail.Domain.ParameterAt(.194))
    low_anchor=.92;main_anchor=.025
    a=low.Trim(span,G.Interval(low.Domain(1).T0,low.Domain(1).ParameterAt(low_anchor))).ToBrep()
    b=main.Trim(span,G.Interval(main.Domain(1).ParameterAt(main_anchor),main.Domain(1).T1)).ToBrep()
    pa=low.PointAt(span.Mid,low.Domain(1).ParameterAt(low_anchor));pb=main.PointAt(span.Mid,main.Domain(1).ParameterAt(main_anchor))
    def edge_at(brep,p):
        def distance(edge):
            ok,t=edge.ClosestPoint(p);return edge.PointAt(t).DistanceTo(p)
        return min(list(brep.Edges),key=distance)
    ea=edge_at(a,pa);eb=edge_at(b,pb)
    reverse=ea.PointAtStart.DistanceTo(eb.PointAtEnd)<ea.PointAtStart.DistanceTo(eb.PointAtStart)
    blends=G.Brep.CreateBlendSurface(a.Faces[0],ea,ea.Domain,False,G.BlendContinuity.Tangency,
                                   b.Faces[0],eb,eb.Domain,reverse,G.BlendContinuity.Tangency)
    if not blends or len(blends)!=1 or not blends[0].IsValid:raise RuntimeError('Local tangent blend failed')
    roof=blends[0];patch=ns['body_from_roof'](roof)
    sc.sticky[TAG+'_candidate']={'roof':roof,'patch':patch,'reverse':reverse,'a':a,'b':b}
    # Extend the main body only; retain the separate lower tier. Global union
    # of both long tiers is unreliable at unrelated coincident contacts.
    union=G.Brep.CreateBooleanUnion([objects[0].Geometry,patch],.01)
    sc.sticky[TAG+'_candidate']['union']=union
    if not union or len(union)!=1 or not union[0].IsValid or not union[0].IsSolid:raise RuntimeError('Main body and transition did not form one valid solid')
    geometry=ns['oriented'](union[0]);bbox=geometry.GetBoundingBox(True)
    original_bbox=objects[0].Geometry.GetBoundingBox(True)
    if bbox.Max.Z<original_bbox.Max.Z-.001 or G.VolumeMassProperties.Compute(geometry).Volume<G.VolumeMassProperties.Compute(objects[0].Geometry).Volume:
        raise RuntimeError('Repair must preserve original main body')
    if bbox.Max.Z>60.918:raise RuntimeError('Original maximum height exceeded')
    state={'recipe':TAG,'sources':IDS,'source_crc':{str(o.Id):int(o.Geometry.DataCRC(0)) for o in objects},
           'span':[.060,.194],'low_anchor_fraction':low_anchor,'main_anchor_fraction':main_anchor,
           'method':'Native tangent blend between inset roof edges; filled to existing -2m base; Boolean union with main body. Lower tier remains a separate unchanged body.',
           'maximum_height_m':bbox.Max.Z,'patch_bbox':{'min':ns['xyz'](patch.GetBoundingBox(True).Min),'max':ns['xyz'](patch.GetBoundingBox(True).Max)},
           'objects':[]}
    sc.sticky[TAG]={'geometry':geometry,'patch':patch,'roof':roof,'state':state,'camera':(doc.Views.ActiveView.ActiveViewport.CameraLocation,doc.Views.ActiveView.ActiveViewport.CameraTarget)}
    write('prepare_report.json',state);print(json.dumps({'prepared':True,'closed_union':True,'patch_bbox':state['patch_bbox'],'maximum_height_m':bbox.Max.Z}))

def capture(name):
    v=sc.doc.Views.ActiveView;cap=Rhino.Display.ViewCapture();cap.Width=1832;cap.Height=1172
    cap.DrawGrid=False;cap.DrawAxes=False;cap.DrawGridAxes=False
    bmp=cap.CaptureToBitmap(v);bmp.Save(os.path.join(OUT,name),ImageFormat.Png);bmp.Dispose()

def publish():
    data=sc.sticky[TAG];state=data['state'];ns=sc.sticky['portal_recipe_namespace'];doc=sc.doc
    if state['objects']:raise RuntimeError('Already published')
    for oid,crc in state['source_crc'].items():
        if int(ns['obj'](oid).Geometry.DataCRC(0))!=crc:raise RuntimeError('Source changed')
    backup=os.path.join(os.path.dirname(ROOT),'map','map_before_west_seam_v06.3dm')
    if os.path.exists(backup):raise RuntimeError('Do not overwrite original backup')
    ns['save_doc'](backup);state['backup']=backup;capture('01_before.png')
    undo=doc.BeginUndoRecord('西侧曲面缺口衔接 v06')
    try:
        l=Rhino.DocObjects.Layer();l.Name='崖岸_西侧曲面衔接_v06';li=doc.Layers.Add(l)
        a=ns['obj'](IDS[0]).Attributes.Duplicate();a.LayerIndex=li;a.Name='西侧主台低台_连续衔接实体';a.SetUserString('recipe',TAG)
        oid=doc.Objects.AddBrep(data['geometry'],a)
        if oid==System.Guid.Empty:raise RuntimeError('Add failed')
        state['objects']=[{'id':str(oid),'name':a.Name}]
        doc.Objects.Hide(System.Guid(IDS[0]),True)
    finally:doc.EndUndoRecord(undo);doc.Views.Redraw()
    state['draft_path']=os.path.join(os.path.dirname(ROOT),'map','map_west_seam_v06.3dm')
    ns['save_doc'](state['draft_path']);write('generation_state.json',state);capture('02_after.png')
    print(json.dumps({'published':True,'id':str(oid),'draft':state['draft_path']},ensure_ascii=False))

def verify():
    ns=sc.sticky['portal_recipe_namespace'];data=sc.sticky[TAG];state=data['state'];doc=sc.doc
    main,low=sc.sticky['gap_top_faces'];site=sc.sticky[ns['TAG']]['site'];fixed=ns['obj'](state['objects'][0]['id'])
    mp=G.MeshingParameters();mp.Tolerance=.01;mp.RelativeTolerance=0;mp.MaximumEdgeLength=3;mp.RefineGrid=True
    def mesh_for(parts):
        result=G.Mesh()
        for g in parts:
            for m in G.Mesh.CreateFromBrep(g,mp) or []:result.Append(m)
        return result
    before=mesh_for([ns['obj'](i).Geometry for i in IDS])
    after=mesh_for([fixed.Geometry,ns['obj'](IDS[1]).Geometry])
    samples=0;before_missing=0;after_missing=[];heights=[]
    for i in range(51):
        s=.073+(.178-.073)*i/50;u=site.rail.Domain.ParameterAt(s)
        a=main.PointAt(u,main.Domain(1).T0);b=low.PointAt(u,low.Domain(1).T1)
        for f in [.1,.3,.5,.7,.9]:
            p=a+(b-a)*f;origin=G.Point3d(p.X,p.Y,100);ray=G.Ray3d(origin,-G.Vector3d.ZAxis)
            t0=G.Intersect.Intersection.MeshRay(before,ray);t1=G.Intersect.Intersection.MeshRay(after,ray);samples+=1
            if t0<0:before_missing+=1
            if t1<0:after_missing.append(ns['xyz'](p))
            else:heights.append(100-t1)
    failures=[]
    if after_missing:failures.append('Unfilled sampled gap points')
    if not fixed.Geometry.IsValid or not fixed.Geometry.IsSolid:failures.append('Invalid or open repaired main body')
    for oid,crc in state['source_crc'].items():
        if int(ns['obj'](oid).Geometry.DataCRC(0))!=crc:failures.append('Source geometry changed '+oid)
    saved=Rhino.FileIO.File3dm.Read(state['draft_path']);saved_fixed=saved.Objects.FindId(fixed.Id)
    if saved_fixed is None or not saved_fixed.Geometry.IsValid or not saved_fixed.Geometry.IsSolid:failures.append('Saved replacement invalid')
    for oid,crc in state['source_crc'].items():
        o=saved.Objects.FindId(System.Guid(oid))
        if o is None or int(o.Geometry.DataCRC(0))!=crc:failures.append('Saved source changed '+oid)
    # Objects outside the local replacement are retained, including both
    # already verified tunnel portal structures and all actual road objects.
    unchanged=0
    prior=Rhino.FileIO.File3dm.Read(state['backup'])
    for o in prior.Objects:
        current=saved.Objects.FindId(o.Id)
        if current is None or int(current.Geometry.DataCRC(0))!=int(o.Geometry.DataCRC(0)):
            failures.append('Unrelated saved geometry changed '+str(o.Id))
        else:unchanged+=1
    report={'failures':failures,'gap_samples':samples,'before_missing':before_missing,'after_missing':len(after_missing),
            'sampled_surface_height_m':[min(heights),max(heights)],'repaired_main_valid':fixed.Geometry.IsValid,
            'repaired_main_closed':fixed.Geometry.IsSolid,'maximum_height_m':fixed.Geometry.GetBoundingBox(True).Max.Z,
            'unchanged_prior_objects':unchanged,'actual_roads_and_portal_geometry_unchanged':not any('Unrelated' in f for f in failures),
            'limitations':'Local gap and native solid checks only; no global curvature, self-intersection or game collision certification.'}
    write('verification_report.json',report);print(json.dumps(report,ensure_ascii=False))
    if failures:raise RuntimeError('Seam verification failed')
    return report
