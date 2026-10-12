# -*- coding: utf-8 -*-
"""Independent v04 spatial-surface prototype, retaining v03 as comparison."""
from __future__ import division, unicode_literals
import io,os,json
import Rhino,System,scriptcontext as sc

ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
path=os.path.join(ROOT,'tools','rhino_cliff_b_shell_v03.py')
source='\n'.join(io.open(path,encoding='utf-8').read().splitlines()[1:])
source=source.replace('v03','v04').replace('V03','V04')
N={'__file__':path,'__name__':'cliff_b_v04_helpers'}
exec(compile(source,path,'exec'),N)
H=N['H']


def spatial_preview(state):
    G=Rhino.Geometry
    helpers=H['recipe']();perimeter,road=helpers['curves']();point=helpers['point']
    view=next(v for v in sc.doc.Views if v.ActiveViewport.IsPerspectiveProjection)
    vp=view.ActiveViewport
    # Oblique views expose depth, folded flanks and the varied root bodies.
    cameras=[('空间侧面',point(.32,75,18,perimeter,road),point(.49,2,28,perimeter,road),32),
             ('支承曲面',point(.39,42,13,perimeter,road),point(.43,0,27,perimeter,road),27)]
    keep=set(r['id'] for r in state['objects']);keep.add(helpers['read_config']()['shallow_bed_id'])
    hidden=[];capture=Rhino.Display.ViewCapture();capture.Width=1600;capture.Height=1000
    capture.DrawGrid=False;capture.DrawAxes=False;capture.DrawGridAxes=False
    try:
        for obj in sc.doc.Objects:
            if not obj.IsDeleted and not obj.IsHidden and str(obj.Id) not in keep:
                if sc.doc.Objects.Hide(obj,True):hidden.append(obj.Id)
        for i,(name,location,target,lens) in enumerate(cameras):
            vp.Camera35mmLensLength=lens;vp.SetCameraLocations(target,location)
            sc.doc.NamedViews.Add('B曲面v04_'+name,vp.Id);view.Redraw()
            bitmap=capture.CaptureToBitmap(view)
            file_name='spatial_side.png' if i==0 else 'support_surface.png'
            bitmap.Save(os.path.join(ROOT,'docs','cliff_b_shell_v04',file_name),System.Drawing.Imaging.ImageFormat.Png)
            bitmap.Dispose()
    finally:
        for oid in hidden:sc.doc.Objects.Show(oid,True)
        vp.Camera35mmLensLength=32
        vp.SetCameraLocations(G.Point3d(1220,340,28),G.Point3d(1260,1120,430));sc.doc.Views.Redraw()
    H['save']()


def run(stage):
    if stage!='spatial_views':N['run'](stage)
    state=H['read'](H['STATE'])
    if stage=='shell':
        mesh=H['read'](os.path.join(H['WORK'],'cliff_b_shell_v04_mesh.json'))
        state['spatial_warp']=mesh['spatial_warp']
        state['spatial_anchor_fields']=mesh['spatial_anchor_fields']
    if stage=='pedestrian':
        previous=sc.doc.Layers.FindByFullPath('崖壁B_自由开口与架空底层_v03',-1)
        if previous>=0:
            layer=sc.doc.Layers[previous];layer.IsVisible=False;layer.CommitChanges()
    if stage=='spatial_views':
        if stage in state['stages']:raise RuntimeError('Already completed '+stage)
        spatial_preview(state);state['stages'].append(stage)
    H['write'](H['STATE'],state)
    H['write'](os.path.join(ROOT,'docs','CLIFF_B_SHELL_V04_REPORT.json'),state)
