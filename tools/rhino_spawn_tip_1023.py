# -*- coding: utf-8 -*-
"""Lift the selected starting-area tip, keeping its footprint and grounded base."""
from __future__ import unicode_literals, division
import Rhino, scriptcontext as sc, System, io, json, math
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
CACHE=ROOT+'/.current_map_build'
ID='577d868b-7597-4058-83f8-4b630606b305'
TAG='spawn_tip_1023'
START_Y=-220.
TIP_Y=-482.50420930602417
LIFT=18.
BASE_TOP=35.

def xyz(p):return [p.X,p.Y,p.Z]
def write(name,data):
    with io.open(CACHE+'/'+name,'w',encoding='utf-8')as f:f.write(json.dumps(data,ensure_ascii=False,indent=2))
def objects():
    e=Rhino.DocObjects.ObjectEnumeratorSettings();e.NormalObjects=True;e.HiddenObjects=True;e.LockedObjects=True
    return list(sc.doc.Objects.GetObjectList(e))
def obj():return sc.doc.Objects.FindId(System.Guid(ID))
def height(y):
    t=max(0.,(START_Y-y)/(START_Y-TIP_Y))
    return BASE_TOP+LIFT*t*t*t

class TipLift(G.SpaceMorph):
    def __init__(self):
        self.Tolerance=.002;self.PreserveStructure=False;self.QuickPreview=False
    def MorphPoint(self,p):
        return G.Point3d(p.X,p.Y,p.Z+(height(p.Y)-BASE_TOP)*(p.Z/BASE_TOP))

def prepare():
    assert sc.doc.Path.replace('\\','/').lower()=='d:/prism route/map/map_current.3dm'
    if TAG not in sc.sticky:
        assert abs(obj().Geometry.GetBoundingBox(True).Max.Z-BASE_TOP)<.005,'Load the original single-object checkpoint before rebuilding an already lifted tip'
        sc.sticky[TAG]={'original':obj().Geometry.DuplicateBrep(),'attributes':obj().Attributes.Duplicate(),
            'before':{str(o.Id):int(o.Geometry.DataCRC(0))for o in objects()},
            'view':Rhino.DocObjects.ViewportInfo(sc.doc.Views.ActiveView.ActiveViewport),'was_modified':sc.doc.Modified}
    d=sc.sticky[TAG]
    if 'attributes_before'not in d:
        options=Rhino.FileIO.SerializationOptions()
        d['attributes_before']={str(o.Id):o.Attributes.ToJSON(options)for o in objects()}
    backup=Rhino.FileIO.File3dm();backup.Objects.Add(d['original'],d['attributes'])
    assert backup.Write(CACHE+'/spawn_tip_1023_before.3dm',8)
    return {'id':ID,'objects':len(d['before']),'existing_unsaved_edits':d['was_modified']}

def build():
    d=sc.sticky[TAG];b=d['original'].DuplicateBrep()
    assert TipLift().Morph(b)and b.IsValid and b.IsSolid
    if b.SolidOrientation==G.BrepSolidOrientation.Inward:b.Flip()
    d['trial']=b
    return {'valid':b.IsValid,'closed':b.IsSolid,'faces':b.Faces.Count}

def mesh(b):
    settings=G.MeshingParameters();settings.Tolerance=.001;settings.MaximumEdgeLength=5.
    settings.RefineGrid=True;settings.SimplePlanes=True
    m=G.Mesh()
    for piece in G.Mesh.CreateFromBrep(b,settings):m.Append(piece)
    return m

def verify():
    d=sc.sticky[TAG];original=d['original'];b=d['trial'];m=mesh(b);old=mesh(original)
    bounds=original.GetBoundingBox(True);new_bounds=b.GetBoundingBox(True)
    largest=0.;root_error=0.;top_count=0;bottom_error=0.;lifted=0
    samples=[]
    for i in range(46):
        x=bounds.Min.X+(bounds.Max.X-bounds.Min.X)*(i+.31)/46
        for j in range(71):
            y=bounds.Min.Y+(bounds.Max.Y-bounds.Min.Y)*(j+.43)/71
            p=G.Point3d(x,y,100);ray=G.Ray3d(p,-G.Vector3d.ZAxis)
            original_t=G.Intersect.Intersection.MeshRay(old,ray)
            if original_t<0:continue
            t=G.Intersect.Intersection.MeshRay(m,ray);assert t>=0,'Footprint hole'
            z=100-t;error=abs(z-height(y));largest=max(largest,error);top_count+=1
            if y>=START_Y:root_error=max(root_error,abs(z-BASE_TOP))
            else:lifted+=1
            bottom=G.Intersect.Intersection.MeshRay(m,G.Ray3d(G.Point3d(x,y,-5),G.Vector3d.ZAxis))
            assert bottom>=0;bottom_error=max(bottom_error,abs(bottom-5))
            if i%7==0 and j%9==0:samples.append({'point':[x,y,z],'expected_z':height(y)})
    assert top_count>400 and lifted>30
    assert largest<.025 and root_error<.005 and bottom_error<.005
    footprint_error=max(abs(new_bounds.Min.X-bounds.Min.X),abs(new_bounds.Max.X-bounds.Max.X),
        abs(new_bounds.Min.Y-bounds.Min.Y),abs(new_bounds.Max.Y-bounds.Max.Y))
    assert footprint_error<.005
    report={'id':ID,'root_y':START_Y,'tip_y':TIP_Y,'lift_m':LIFT,'original_top_m':BASE_TOP,
        'tip_top_m':new_bounds.Max.Z,'transition_length_m':START_Y-TIP_Y,
        'top_samples':top_count,'lifted_samples':lifted,'max_height_field_error_m':largest,
        'unchanged_root_error_m':root_error,'bottom_error_m':bottom_error,'footprint_error_m':footprint_error,
        'valid':b.IsValid,'closed':b.IsSolid,'outward':b.SolidOrientation==G.BrepSolidOrientation.Outward,
        'faces':b.Faces.Count,'cave_opening_created':False,'samples':samples}
    d['verification']=report;write('spawn_tip_1023_verification.json',report)
    return {k:v for k,v in report.items()if k!='samples'}

def publish():
    d=sc.sticky[TAG];assert d.get('verification')
    undo=sc.doc.BeginUndoRecord('出生地尖角_平滑抬升末端%g米'%LIFT)
    try:
        assert sc.doc.Objects.Replace(System.Guid(ID),d['trial'])
        a=d['attributes'].Duplicate();a.Name='出生地_尖角平滑上扬_末端抬升%g米'%LIFT
        a.SetUserString('spawn_tip_lift_m',str(LIFT));a.SetUserString('spawn_tip_transition_start_y',str(START_Y))
        assert sc.doc.Objects.ModifyAttributes(System.Guid(ID),a,True)
    finally:sc.doc.EndUndoRecord(undo)
    after={str(o.Id):int(o.Geometry.DataCRC(0))for o in objects()}
    assert set(after)==set(d['before'])
    changed=[k for k in after if after[k]!=d['before'][k]];assert changed==[ID]
    options=Rhino.FileIO.SerializationOptions()
    assert all(o.Attributes.ToJSON(options)==d['attributes_before'][str(o.Id)]for o in objects()if str(o.Id)!=ID)
    report={'changed_ids':changed,'unchanged_objects':len(after)-1,'objects':len(after),'verification':d['verification']}
    write('spawn_tip_1023_publication.json',report)
    sc.doc.Objects.UnselectAll();obj().Select(True);sc.doc.Views.Redraw()
    return {'changed':changed,'unchanged':len(after)-1,'objects':len(after)}

def capture(name,side=False):
    d=sc.sticky[TAG];view=sc.doc.Views.ActiveView;vp=view.ActiveViewport
    if side:
        target=G.Point3d(595,-240,28);eye=G.Point3d(1080,-360,100)
        vp.SetCameraLocation(eye,False);vp.SetCameraTarget(target,False)
        vp.SetCameraDirection(target-eye,False);vp.Camera35mmLensLength=38
        vp.ZoomBoundingBox(d['trial'].GetBoundingBox(True))
    sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
    c=Rhino.Display.ViewCapture();c.Width=1440;c.Height=900;c.DrawGrid=False;c.DrawAxes=False;c.DrawGridAxes=False
    bitmap=c.CaptureToBitmap(view);assert bitmap
    path=ROOT+'/assets/world/current_map_validation/review/'+name+'.png'
    bitmap.Save(path,System.Drawing.Imaging.ImageFormat.Png);bitmap.Dispose()
    return path

def save():
    d=sc.sticky[TAG];assert obj().Geometry.IsValid and obj().Geometry.IsSolid
    options=Rhino.FileIO.FileWriteOptions();options.SuppressDialogBoxes=True
    assert sc.doc.WriteFile(sc.doc.Path,options);sc.doc.Modified=False
    saved=Rhino.FileIO.File3dm.Read(sc.doc.Path)
    assert saved.Objects.FindId(System.Guid(ID)).Geometry.DataCRC(0)==obj().Geometry.DataCRC(0)
    report={'saved':True,'path':sc.doc.Path,'readback_verified':True}
    write('spawn_tip_1023_saved.json',report);return report
