# -*- coding: utf-8 -*-
"""Read-only live-Rhino audit overlays. No document objects/layers are added."""
from __future__ import unicode_literals
import json
import os
import Rhino
import scriptcontext as sc
from System import Guid
from System.Drawing import Color
from System.Drawing.Imaging import ImageFormat

ROOT = r'D:\Prism Route\prism-route\docs\concepts\cliff_terraces_2026-10-14'
TARGET = 'e6c5ceda-103d-48b7-af81-db0bcd3f4e41'

def point(values):
    return Rhino.Geometry.Point3d(*values)

class AuditOverlay(Rhino.Display.DisplayConduit):
    def __init__(self, wall, crossings):
        self.wall = wall
        self.crossings = crossings
        self.markers = [
            (point([420.866,837.593,42.852]), 'S1 west rising shell', Color.Gold),
            (point([1197.164,628.701,60]), 'S2 interwoven crown / max 60m', Color.Gold),
            (point([1609.161,1089.94,35]), 'S3 descending open shell', Color.Gold),
        ]
        self.boxes = []
        for index, row in enumerate(crossings):
            p = point(row['point'])
            t = Rhino.Geometry.Vector3d(*row['tangent'])
            t.Unitize()
            side = Rhino.Geometry.Vector3d(-t.Y,t.X,0)
            side.Unitize()
            # Planning reserve only: 28m road-normal width, 10m clear height,
            # 90m longitudinal extent. Actual portal/length not designed yet.
            bottom = [p+t*along+side*across for along,across in [(-45,-14),(45,-14),(45,14),(-45,14)]]
            top = [q+Rhino.Geometry.Vector3d(0,0,10) for q in bottom]
            self.boxes.append((bottom,top))
            self.markers.append((p, 'T%d road Z=%.2fm' % (index+1,p.Z), Color.DeepSkyBlue))

    def DrawForeground(self,e):
        e.Display.DrawBrepWires(self.wall, Color.OrangeRed, 4)
        for bottom,top in self.boxes:
            for row in [bottom,top]:
                for i in range(4):
                    e.Display.DrawLine(row[i],row[(i+1)%4],Color.DeepSkyBlue,3)
            for i in range(4):
                e.Display.DrawLine(bottom[i],top[i],Color.DeepSkyBlue,2)
        for p,label,color in self.markers:
            e.Display.DrawDot(p,label,color,Color.Black)
        e.Display.Draw2dText('LIVE RHINO AUDIT | orange: marked wall | blue: tunnel reserve | gold: proposed shell sectors',Color.Black,Rhino.Geometry.Point2d(20,30),False,18)

def run():
    doc = sc.doc
    before = {'modified':bool(doc.Modified),'objects':doc.Objects.Count,'layers':doc.Layers.Count}
    obj = doc.Objects.FindId(Guid(TARGET))
    if obj is None or not (obj.Attributes.Name or '').startswith('1014'):
        raise RuntimeError('Marked target identity changed; doc='+str(doc.Path)+' name='+str(obj.Attributes.Name if obj else None))
    with open(os.path.join(ROOT,'rhino_site_audit.json'),'r') as handle:
        audit = json.load(handle)
    crossings = [road['hits'][0] for road in audit['road_center_sections']['roads']]
    conduit = AuditOverlay(obj.Geometry,crossings)
    view = doc.Views.ActiveView
    vp = view.ActiveViewport
    vp.PushViewProjection()
    captures = []
    try:
        conduit.Enabled = True
        bounds = Rhino.Geometry.BoundingBox(point([240,490,0]),point([1770,1610,80]))
        vp.ZoomBoundingBox(bounds)
        doc.Views.Redraw()
        for name,top_view in [('rhino_audit_perspective.png',False),('rhino_audit_top.png',True)]:
            if top_view:
                vp.SetToPlanView(Rhino.Geometry.Point3d.Origin,Rhino.Geometry.Vector3d.XAxis,Rhino.Geometry.Vector3d.YAxis,False)
                vp.ZoomBoundingBox(bounds)
                doc.Views.Redraw()
            capture = Rhino.Display.ViewCapture()
            capture.Width = 1920
            capture.Height = 1080
            capture.ScaleScreenItems = True
            capture.DrawAxes = False
            capture.DrawGrid = False
            capture.DrawGridAxes = False
            bitmap = capture.CaptureToBitmap(view)
            if bitmap is None:
                raise RuntimeError('Rhino viewport capture failed')
            path = os.path.join(ROOT,name)
            bitmap.Save(path,ImageFormat.Png)
            bitmap.Dispose()
            captures.append(path)
    finally:
        conduit.Enabled = False
        vp.PopViewProjection()
        doc.Views.Redraw()
    after = {'modified':bool(doc.Modified),'objects':doc.Objects.Count,'layers':doc.Layers.Count}
    if before != after:
        raise RuntimeError('Unexpected document state change: '+str(after))
    result = {'before':before,'after':after,'captures':captures,'geometry_changes':0,'camera_restored':True,
        'reserve_note':'Blue boxes are diagnostic planning envelopes only, not modeled tunnels.'}
    with open(os.path.join(ROOT,'rhino_capture_audit.json'),'w') as handle:
        json.dump(result,handle,indent=2)
    print(json.dumps(result))

if __name__ == '__main__':
    run()
