# -*- coding: utf-8 -*-
"""Read-only incremental export of the authored ruin; run through the Rhino bridge."""
from __future__ import unicode_literals, division
import Rhino,scriptcontext as sc,System,io,json,os,hashlib
ROOT='D:/Prism Route/prism-route'
CACHE=ROOT+'/.current_map_build'
CAD='D:/Prism Route/plans/architecture_concepts_1028/rhino_model_1029'
TAG='initial_ruin_export_1029'
G=Rhino.Geometry

def fingerprint():
    options=Rhino.FileIO.SerializationOptions()
    return dict((str(o.Id),(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(options))) for o in sc.doc.Objects)

def prepare():
    with io.open(CAD+'/build_state.json','r',encoding='utf-8') as f:state=json.load(f)
    with io.open(CAD+'/placement_plan.json','r',encoding='utf-8') as f:plan=json.load(f)
    for row in state['objects']:assert sc.doc.Objects.FindId(System.Guid(row['id']))
    stream=System.IO.FileStream(CACHE+'/initial_ruin_1029.bin',System.IO.FileMode.Create);stream.Close()
    sc.sticky[TAG]={'before':fingerprint(),'state':state,'plan':plan,'records':[],'probes':[]}
    return {'objects':len(state['objects']),'source':sc.doc.Path}

def export_batch(start,end):
    w=sc.sticky[TAG];assert start==len(w['records'])
    param=G.MeshingParameters();param.SimplePlanes=True;param.RefineGrid=True;param.JaggedSeams=False
    param.GridMinCount=0;param.GridMaxCount=32;param.MaximumEdgeLength=8.;param.MinimumEdgeLength=.035
    param.Tolerance=.025;param.RelativeTolerance=0.;param.RefineAngle=.12
    stream=System.IO.FileStream(CACHE+'/initial_ruin_1029.bin',System.IO.FileMode.Append)
    writer=System.IO.BinaryWriter(stream)
    try:
        for row in w['state']['objects'][start:end]:
            obj=sc.doc.Objects.FindId(System.Guid(row['id']));mesh=G.Mesh()
            for part in G.Mesh.CreateFromBrep(obj.Geometry,param):mesh.Append(part)
            mesh.Faces.ConvertQuadsToTriangles();mesh.Normals.ComputeNormals();mesh.Compact()
            assert mesh.IsValid and mesh.Faces.Count>0
            offset=int(stream.Position)
            for array in [mesh.Vertices.ToFloatArray(),mesh.Faces.ToIntArray(True)]:
                raw=System.Array.CreateInstance(System.Byte,array.Length*4)
                System.Buffer.BlockCopy(array,0,raw,0,raw.Length);writer.Write(raw)
            box=mesh.GetBoundingBox(True);xyz=lambda p:[float(p.X),float(p.Y),float(p.Z)]
            material=sc.doc.Materials[obj.Attributes.MaterialIndex]
            key=material.Name.replace('PR_Ruin1029_','')
            record=dict(row,layer=sc.doc.Layers[obj.Attributes.LayerIndex].FullPath,kind='Structure',
                material_key=key,collision=key!='cyan',offset=offset,
                vertex_count=mesh.Vertices.Count,index_count=mesh.Faces.Count*3,bounds=[xyz(box.Min),xyz(box.Max)])
            w['records'].append(record)
            # Independent source mesh samples for imported collision verification.
            samples=[]
            for i in range(0,mesh.Faces.Count,max(1,mesh.Faces.Count//12)):
                f=mesh.Faces[i];a=G.Point3d(mesh.Vertices[f.A]);b=G.Point3d(mesh.Vertices[f.B]);c=G.Point3d(mesh.Vertices[f.C])
                n=G.Vector3d.CrossProduct(b-a,c-a)
                if not n.Unitize() or n.Z<.72:continue
                center=(a+b+c)/3.;samples.append(xyz(center))
            if samples and key!='cyan':w['probes'].append({'id':row['id'],'name':row['name'],'samples':samples})
    finally:writer.Close()
    return {'done':len(w['records']),'triangles':sum(r['index_count']//3 for r in w['records'])}

def finish():
    w=sc.sticky[TAG];assert len(w['records'])==len(w['state']['objects'])
    assert fingerprint()==w['before'],'CAD changed during read-only export'
    result={'source':sc.doc.Path,'native_center':[1450,1150,0],
        'cad_unchanged':True,'cad_object_count':len(w['before']),
        'objects':w['records'],'probes':w['probes'],'placement':w['plan'],
        'interactions':read_interactions(w['state'])}
    with io.open(CACHE+'/initial_ruin_1029.json','w',encoding='utf-8') as f:f.write(json.dumps(result,ensure_ascii=False,indent=2))
    return {'objects':len(w['records']),'triangles':sum(r['index_count']//3 for r in w['records']),'cad_unchanged':True}

def write_json(path,value):
    with io.open(path,'w',encoding='utf-8') as f:f.write(json.dumps(value,ensure_ascii=False,indent=2)+'\n')

def read_interactions(state):
    """Export actual CAD points as semantic data, never as visible GLB meshes."""
    layout=json.loads(json.dumps(state.get('interactions',{})))
    for item in layout.get('furniture',[])+[layout.get('npc_idle',{})]:
        anchors=item.get('anchors',[])
        if anchors and 'root_position_cad' in item:
            first_obj=sc.doc.Objects.FindId(System.Guid(anchors[0]['source_id']))
            if first_obj is not None and isinstance(first_obj.Geometry,G.Point):
                dp=first_obj.Geometry.Location;old_pos=anchors[0].get('position_cad',[dp.X,dp.Y,dp.Z])
                dx=dp.X-old_pos[0];dy=dp.Y-old_pos[1];dz=dp.Z-old_pos[2]
                item['root_position_cad']=[item['root_position_cad'][0]+dx,item['root_position_cad'][1]+dy,item['root_position_cad'][2]+dz]
        for anchor in anchors:
            obj=sc.doc.Objects.FindId(System.Guid(anchor['source_id']))
            assert obj is not None and isinstance(obj.Geometry,G.Point)
            p=obj.Geometry.Location;anchor['position_cad']=[p.X,p.Y,p.Z]
            anchor['forward_cad']=json.loads(obj.Attributes.GetUserString('interaction_forward_cad'))
    return layout

def replace_summon_with_furniture():
    """Bounded, repeatable revision: six stone solids and eight semantic points."""
    assert sc.doc.Path.lower().replace('\\','/').endswith('/map/map_current.3dm')
    state=json.load(io.open(CAD+'/build_state.json',encoding='utf-8-sig'))
    p=state['placement'];front=p['front_center'];right=p['right_axis'];long_axis=p['long_axis']
    def site(u,v,z):return G.Point3d(front[0]+right[0]*u+long_axis[0]*v,front[1]+right[1]*u+long_axis[1]*v,z)
    def xyz(p):return [p.X,p.Y,p.Z]
    stage=[];layout={'version':1,'furniture':[],'npc_idle':{'id':'initial_temple_npc_01','anchors':[]}}
    def furniture(ident,kind,u,v,forward_uv,polygon,base_polygon,height,anchors,usable):
        origin=site(u,v,61.05)
        fx=right[0]*forward_uv[0]+long_axis[0]*forward_uv[1];fy=right[1]*forward_uv[0]+long_axis[1]*forward_uv[1]
        x_axis=G.Vector3d(fy,-fx,0);z_axis=G.Vector3d(fx,fy,0)
        def point(x,y,z):return origin+x_axis*x+G.Vector3d(0,0,y)+z_axis*z
        item={'id':ident,'type':kind,'root_position_cad':xyz(origin),'forward_cad':[fx,fy,0],
              'surface_height':height,'usable_surface':usable,'anchors':[],'geometry_ids':[],
              'interaction_status':'anchors_ready','motion_profiles':[]}
        for label,poly,bottom,top,mat in [('Base',base_polygon,0,height-.12,'base'),('Surface',polygon,height-.12,height,'cap')]:
            curve=G.PolylineCurve([point(x,bottom,z) for x,z in poly]+[point(poly[0][0],bottom,poly[0][1])])
            if curve.ClosedCurveOrientation(G.Plane.WorldXY)==G.CurveOrientation.Clockwise:curve.Reverse()
            geom=G.Extrusion.Create(curve,top-bottom,True).ToBrep()
            assert geom.IsValid and geom.IsSolid
            assert abs(geom.GetBoundingBox(True).Max.Z-(61.05+top))<.001
            stage.append((geom,'PR_Temple_'+ident+'_'+label,mat,item))
        for name,pos in anchors:
            item['anchors'].append({'name':name,'local_position':pos,'position_cad':xyz(point(*pos)),
                                    'forward_cad':[fx,fy,0] if name!='Anchor_Front' else [-fx,-fy,0]})
        layout['furniture'].append(item)
    furniture('seat_01','seat',9.,16.,[-1,0],
              [[-.95,.45],[.95,.45],[0,-1.15]],[[-.70,.25],[.70,.25],[0,-.85]],.42,
              [('Anchor_Seat',[0,.42,.10]),('Anchor_Front',[0,0,1.05])],
              {'center':[0,.10],'width':1.20,'depth':.45})
    furniture('table_01','desk',5.8,30.,[-1,0],
              [[-1.05,.50],[1.05,.50],[0,-1.25]],[[-.65,.12],[.65,.12],[0,-.95]],.838,
              [('Anchor_Desk_Surface',[0,.838,.32]),('Anchor_Front',[0,0,1.10])],
              {'center':[0,.28],'width':1.20,'depth':.35})
    furniture('rest_01','bed',2.,42.,[0,-1],
              [[-1.,-1.5],[1.,-1.5],[1.,1.30],[.30,1.60],[-1.,1.30]],
              [[-.80,-1.30],[.80,-1.30],[.80,1.15],[-.80,1.15]],.46,
              [('Anchor_Bed_Center',[0,.46,0]),('Anchor_BedEdge_Front',[0,.46,1.25]),('Anchor_Front',[0,0,2.10])],
              {'center':[0,0],'width':1.85,'depth':2.45})
    npc=layout['npc_idle'];npc_origin=site(0,25.,61.05)
    npc['root_position_cad']=xyz(npc_origin);npc['forward_cad']=[-long_axis[0],-long_axis[1],0]
    npc['anchors']=[{'name':'NPC_Idle','position_cad':xyz(npc_origin),'forward_cad':npc['forward_cad']}]
    retired=set(r['id'] for r in state['objects'] if r.get('category') in ['dais','furniture'])
    for item in state.get('interactions',{}).get('furniture',[])+[state.get('interactions',{}).get('npc_idle',{})]:
        retired.update(a['source_id'] for a in item.get('anchors',[]))
    walk_state=json.load(io.open(CAD+'/walk_collision_state.json',encoding='utf-8-sig'))
    retired.update(r['id'] for r in walk_state['objects'] if r['role']=='dais')
    before=fingerprint();unchanged=dict((k,v) for k,v in before.items() if k not in retired)
    sc.sticky[TAG+'_unaffected']=unchanged
    layer=sc.doc.Layers.FindByFullPath(u'建筑::初始三角遗迹::08_召唤台与遗物',-1)
    if layer>=0:
        lyr=sc.doc.Layers[layer];lyr.Name=u'08_NPC与三角家具';lyr.CommitChanges()
    else:layer=sc.doc.Layers.FindByFullPath(u'建筑::初始三角遗迹::08_NPC与三角家具',-1)
    assert layer>=0
    marker_layer=sc.doc.Layers.FindByFullPath(u'建筑::初始三角遗迹::10_交互定位',-1)
    if marker_layer<0:marker_layer=sc.doc.Layers.AddPath(u'建筑::初始三角遗迹::10_交互定位')
    lyr=sc.doc.Layers[marker_layer];lyr.IsLocked=False;lyr.CommitChanges()
    walk_layer=sc.doc.Layers.FindByFullPath(walk_state['layer'],-1);was_locked=sc.doc.Layers[walk_layer].IsLocked
    sc.doc.Layers[walk_layer].IsLocked=False;sc.doc.Layers[walk_layer].CommitChanges()
    undo=sc.doc.BeginUndoRecord('Initial temple NPC and triangular furniture')
    try:
        for sid in retired:
            obj=sc.doc.Objects.FindId(System.Guid(sid))
            if obj:assert sc.doc.Objects.Delete(obj,True),'Cannot remove '+obj.Name
        kept=[r for r in state['objects'] if r['id'] not in retired and sc.doc.Objects.FindId(System.Guid(r['id'])) is not None]
        for geom,name,mat,item in stage:
            a=Rhino.DocObjects.ObjectAttributes();a.Name=name;a.LayerIndex=layer
            material=next(m for m in sc.doc.Materials if m.Name=='PR_Ruin1029_'+mat)
            a.MaterialIndex=material.MaterialIndex;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
            a.SetUserString('pr_ruin_build',state['tag']);a.SetUserString('pr_ruin_phase','04_npc_furniture');a.SetUserString('interaction_id',item['id'])
            sid=sc.doc.Objects.AddBrep(geom,a);assert sid!=System.Guid.Empty
            if 'add_object_metadata' in globals():add_object_metadata(sid,name,'Initial temple stone '+item['type'])
            item['geometry_ids'].append(str(sid));kept.append({'id':str(sid),'name':name,'category':'furniture','phase':'04_npc_furniture'})
        for item in layout['furniture']+[npc]:
            for anchor in item['anchors']:
                a=Rhino.DocObjects.ObjectAttributes();a.Name='PR_Temple_'+item['id']+'_'+anchor['name'];a.LayerIndex=marker_layer
                a.SetUserString('interaction_id',item['id']);a.SetUserString('anchor_name',anchor['name'])
                a.SetUserString('interaction_forward_cad',json.dumps(anchor['forward_cad']))
                sid=sc.doc.Objects.AddPoint(G.Point3d(*anchor['position_cad']),a);assert sid!=System.Guid.Empty
                anchor['source_id']=str(sid)
                if 'add_object_metadata' in globals():add_object_metadata(sid,a.Name,'Interaction anchor; exported as manifest data')
        state['objects']=kept;state['interactions']=layout;state['checks'].pop('summon_anchor',None)
        state['checks']['npc_idle']=npc['root_position_cad']
        state['phases']=sorted(set(state['phases']+[r['phase'] for r in kept]+['04_npc_furniture']))
        write_json(CAD+'/build_state.json',state)
        walk_state['objects']=[r for r in walk_state['objects'] if r['role']!='dais'];walk_state['revision']='npc_furniture_20261108'
        walk_state['original_fingerprints']=fingerprint();write_json(CAD+'/walk_collision_state.json',walk_state)
        recipe=json.load(io.open(CAD+'/walk_collision_recipe.json',encoding='utf-8-sig'))
        recipe['models']=[r for r in recipe['models'] if r['role']!='dais']
        recipe['replaced_objects']=[r for r in recipe['replaced_objects'] if not r['name'].startswith('PR_SummonStep_')]
        recipe['math'].pop('dais_rings',None);recipe['revision']='npc_furniture_20261108'
        recipe['source_state_sha256']=hashlib.sha256(open(CAD+'/build_state.json','rb').read()).hexdigest()
        write_json(CAD+'/walk_collision_recipe.json',recipe)
        after=fingerprint();assert all(after.get(k)==v for k,v in unchanged.items()),'Unrelated Rhino objects changed'
    finally:
        sc.doc.EndUndoRecord(undo);sc.doc.Layers[walk_layer].IsLocked=was_locked;sc.doc.Layers[walk_layer].CommitChanges()
        lyr=sc.doc.Layers[marker_layer];lyr.IsVisible=False;lyr.IsLocked=True;lyr.CommitChanges();sc.doc.Views.Redraw()
    return {'geometry_objects':len(state['objects']),'added_solids':len(stage),'anchors':sum(len(i['anchors']) for i in layout['furniture']+[npc]),'retired':len(retired),'unrelated_preserved':True}

def save_main():
    settings=Rhino.ApplicationSettings.FileSettings;old=settings.CreateBackupFiles
    try:
        settings.CreateBackupFiles=False
        o=Rhino.FileIO.FileWriteOptions();o.SuppressDialogBoxes=True;o.SuppressAllInput=True;o.UpdateDocumentPath=True
        assert sc.doc.WriteFile('D:/Prism Route/map/map_current.3dm',o)
    finally:settings.CreateBackupFiles=old
    return {'saved':sc.doc.Path,'extra_full_model_copy':False}
