# -*- coding: utf-8 -*-
import Rhino,scriptcontext as sc,System,json,os
import System.Drawing.Imaging as Imaging
HERE=r'D:\Prism Route\plans\architecture_concepts_1028\rhino_model_1029'
PR_RUIN_PHASE=''
exec(compile(open(os.path.join(HERE,'build_initial_ruin.py'),'rb').read().decode('utf-8'),'build_initial_ruin.py','exec'))
VIEWS={
 'exterior':{'name':'PR_Ruin_01_Exterior','camera':world(-78,-72,116.),'target':world(0,24,66.),'lens':50.},
 'interior':{'name':'PR_Ruin_02_Interior','camera':world(0,3,62.15),'target':world(0,26,65.),'lens':20.},
 'foundation':{'name':'PR_Ruin_03_Foundation','camera':world(55,-24,87.),'target':world(4,20,63.),'lens':35.},
 'approach':{'name':'PR_Ruin_04_Approach','camera':Rhino.Geometry.Point3d(578,-279,65),'target':world(0,-6,61.),'lens':35.},
 'connection':{'name':'PR_Ruin_05_CaveConnection','camera':Rhino.Geometry.Point3d(566,-281,45),'target':Rhino.Geometry.Point3d(573,-270,35.2),'lens':35.},
}
def review_view(key,save=True):
    config=VIEWS[key];vp=D.Views.ActiveView.ActiveViewport
    vp.ChangeToPerspectiveProjection(True,config['lens'])
    vp.SetCameraLocations(config['target'],config['camera'])
    # The previous map overview carried a 70m near plane; reset clipping for close inspection.
    vp.SetClippingPlanes(Rhino.Geometry.BoundingBox(Rhino.Geometry.Point3d(180,-420,-20),Rhino.Geometry.Point3d(760,240,160)))
    D.Objects.UnselectAll();D.Views.Redraw()
    D.NamedViews.Add(config['name'],vp.Id)
    if save:
        capture=Rhino.Display.ViewCapture()
        capture.Width=1600;capture.Height=1000;capture.DrawAxes=False;capture.DrawGrid=False;capture.DrawGridAxes=False
        bitmap=capture.CaptureToBitmap(D.Views.ActiveView)
        if bitmap is None:raise Exception('Viewport capture failed')
        path=os.path.join(HERE,'rhino_'+key+'.png')
        bitmap.Save(path,Imaging.ImageFormat.Png);bitmap.Dispose()
        print(json.dumps({'view':config['name'],'screenshot':path}))
    return config

key=globals().get('PR_REVIEW_VIEW','')
if key:review_view(key)
