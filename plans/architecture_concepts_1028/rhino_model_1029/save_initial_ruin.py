# -*- coding: utf-8 -*-
import Rhino,scriptcontext as sc,System,json,os
HERE=r'D:\Prism Route\plans\architecture_concepts_1028\rhino_model_1029'
PR_REVIEW_VIEW=''
exec(compile(open(os.path.join(HERE,'review_views.py'),'rb').read().decode('utf-8'),'review_views.py','exec'))
with open(os.path.join(HERE,'build_state.json')) as f:state=json.load(f)
# Remove only the empty diagnostic layer created during this task.
idx=D.Layers.FindByFullPath(u'建筑::PR_InitialRuin_1029',-1)
if idx>=0:
    contents=D.Objects.FindByLayer(D.Layers[idx])
    if contents is None or len(contents)==0:D.Layers.Delete(idx,True)
# Restore the original ocean visibility before saving the real map.
D.Objects.Show(System.Guid('8540c7bb-0104-46f5-b3e2-24fa8d22424b'),True)
review_view('exterior')
root_index=D.Layers.FindByFullPath(ROOT,-1)
if root_index>=0:D.Layers.SetCurrentLayerIndex(root_index,True)
w=Rhino.FileIO.FileWriteOptions();w.SuppressDialogBoxes=True;w.SuppressAllInput=True;w.UpdateDocumentPath=True
main=r'D:\Prism Route\map\map_current.3dm'
if not D.WriteFile(main,w):raise Exception('Main map save failed')
# Smaller inspection file: the same building plus the real local terrain/cave walkway, no enormous ocean sheet.
ids=[System.Guid(row['id']) for row in state['objects']]
ids += [System.Guid(x) for x in [
 '577d868b-7597-4058-83f8-4b630606b305','0e79433e-80e9-48f1-ab77-3786fdc3819f',
 '9713e301-b5a7-4acb-821d-d98484bc52de','66bd60fa-4f5b-458a-aa30-ad164b0f5d70',
 '4b6d5fc4-59f9-490c-9eaf-ecc252b3de46','27172e67-243a-4398-9933-89de8ecae12d',
 '012ab31c-3bd7-4f32-8676-9592c584ca4c']]
D.Objects.UnselectAll()
for ident in ids:
    if not D.Objects.Select(ident):raise Exception('Export selection missing '+str(ident))
opts=Rhino.FileIO.FileWriteOptions();opts.UpdateDocumentPath=False;opts.SuppressDialogBoxes=True;opts.SuppressAllInput=True;opts.WriteSelectedObjectsOnly=True
review_path=os.path.join(HERE,'initial_triangle_ruin_review.3dm')
try:
    if not D.WriteFile(review_path,opts):raise Exception('Review file save failed')
finally:D.Objects.UnselectAll();D.Views.Redraw()
review=Rhino.FileIO.File3dm.Read(review_path)
if review is None or review.Objects.Count!=len(ids):raise Exception('Review file object count mismatch')
report={'main_saved':main,'review_file':review_path,'review_objects':review.Objects.Count,
        'building_objects':len(state['objects']),'terrain_context_objects':7,
        'active_document':D.Path,'ocean_visible':not D.Objects.FindId(System.Guid('8540c7bb-0104-46f5-b3e2-24fa8d22424b')).IsHidden,
        'backup':r'D:\Prism Route\map\backups\map_before_initial_ruin_1029.3dm'}
with open(os.path.join(HERE,'saved_files.json'),'w') as f:json.dump(report,f,indent=2)
print(json.dumps(report))
