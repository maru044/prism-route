# -*- coding: utf-8 -*-
"""Correct only the audited inward shoulder, retaining UUID and attributes."""
from __future__ import unicode_literals
import Rhino,scriptcontext as sc,System,io,json,os
ROOT='D:/Prism Route/prism-route'
IDENT='9571ee7f-ce6e-40f7-b13a-d1a647bb9b66'

def repair():
    assert sc.doc.Path.replace('\\','/').lower()=='d:/prism route/map/map_current.3dm'
    assert os.path.exists(ROOT+'/.current_map_build/mesh_repair_20261022_before/map_current.3dm')
    settings=Rhino.DocObjects.ObjectEnumeratorSettings();settings.NormalObjects=True;settings.HiddenObjects=True;settings.LockedObjects=True
    def snapshot():
        options=Rhino.FileIO.SerializationOptions()
        return {str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(options)) for o in sc.doc.Objects.GetObjectList(settings)}
    before=snapshot();o=sc.doc.Objects.FindId(System.Guid(IDENT));assert o and isinstance(o.Geometry,Rhino.Geometry.Mesh)
    old_orientation=o.Geometry.SolidOrientation();assert o.Geometry.IsClosed and old_orientation in [-1,1]
    if old_orientation==-1:
        original_attributes=o.Attributes.Duplicate()
        flipped=o.Geometry.DuplicateMesh();flipped.Flip(True,True,True)
        # DuplicateMesh carries Rhino's cached solid-orientation flag; build
        # fresh topology so the post-flip orientation is actually retested.
        fixed=Rhino.Geometry.Mesh();fixed.Append(flipped)
        fixed.FaceNormals.ComputeFaceNormals();fixed.Normals.ComputeNormals()
        assert fixed.IsValid and fixed.IsClosed and fixed.SolidOrientation()==1
        undo=sc.doc.BeginUndoRecord('Correct inward tunnel shoulder')
        try:
            assert sc.doc.Objects.Replace(o.Id,fixed)
            # Replace may resolve an unset material index to a document
            # material; restore the original attributes explicitly.
            assert sc.doc.Objects.ModifyAttributes(o.Id,original_attributes,True)
        finally:sc.doc.EndUndoRecord(undo)
    after=snapshot();assert set(before)==set(after)
    changed=[k for k in before if before[k]!=after[k]]
    assert changed==[IDENT] or not changed
    current_attributes=sc.doc.Objects.FindId(System.Guid(IDENT)).Attributes
    if old_orientation==-1:
        for property_name in ['ObjectId','Name','LayerIndex','MaterialIndex','MaterialSource','ColorSource','ObjectColor','Visible','Mode']:
            assert getattr(current_attributes,property_name)==getattr(original_attributes,property_name)
        assert list(current_attributes.GetUserStrings().AllKeys)==list(original_attributes.GetUserStrings().AllKeys)
        for k in original_attributes.GetUserStrings().AllKeys:
            assert current_attributes.GetUserString(k)==original_attributes.GetUserString(k)
    options=Rhino.FileIO.FileWriteOptions();options.SuppressDialogBoxes=True
    assert sc.doc.WriteFile(sc.doc.Path,options)
    sc.doc.Modified=False
    sc.doc.Views.Redraw()
    o=sc.doc.Objects.FindId(System.Guid(IDENT));m=o.Geometry.DuplicateMesh();m.Faces.ConvertQuadsToTriangles();m.Compact()
    stream=System.IO.FileStream(ROOT+'/.current_map_build/shoulder_fixed.bin',System.IO.FileMode.Create)
    writer=System.IO.BinaryWriter(stream)
    try:
        for array in [m.Vertices.ToFloatArray(),m.Faces.ToIntArray(True)]:
            raw=System.Array.CreateInstance(System.Byte,array.Length*4);System.Buffer.BlockCopy(array,0,raw,0,raw.Length);writer.Write(raw)
    finally:writer.Close()
    report={'id':IDENT,'orientation_before':old_orientation,'orientation_after':o.Geometry.SolidOrientation(),'changed_ids':changed,
            'attributes_preserved':True,'cad_object_count':len(after),'vertex_count':m.Vertices.Count,'index_count':m.Faces.Count*3,
            'source_crc':int(o.Geometry.DataCRC(0)),'saved':True}
    with io.open(ROOT+'/assets/world/current_map_validation/review/shoulder_repair.json','w',encoding='utf-8') as f:f.write(json.dumps(report,ensure_ascii=False,indent=2))
    return report
