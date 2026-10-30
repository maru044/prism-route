"""Measure the user's red outline; never modify the reference screenshots."""
import json
from pathlib import Path
import cv2
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
SOURCE=Path(r'C:/Users/PC/AppData/Local/Temp/codex-clipboard-2a925902-656c-47c5-b69e-a4d6fedc15e8.png')
REFERENCE=ROOT/'docs/meadow_zone_1030/local/overview_after.png'
OUT=ROOT/'assets/world/meadow_zone_1030/shore_annotation.json'

def read(path):
    return cv2.imdecode(np.fromfile(str(path),dtype=np.uint8),cv2.IMREAD_COLOR)

source,reference=read(SOURCE),read(REFERENCE)
assert source is not None and reference is not None
red=((source[:,:,2]>220)&(source[:,:,1]<110)&(source[:,:,0]<110)).astype(np.uint8)*255
contours,hierarchy=cv2.findContours(red,cv2.RETR_TREE,cv2.CHAIN_APPROX_SIMPLE)
outer=max(range(len(contours)),key=lambda i:cv2.contourArea(contours[i]))
children=[i for i,row in enumerate(hierarchy[0]) if row[3]==outer]
assert children,'The annotated red outline is not a closed loop'
inner=max(children,key=lambda i:cv2.contourArea(contours[i]))
outline=cv2.approxPolyDP(contours[inner],2.0,True).astype(np.float32)

orb=cv2.ORB_create(nfeatures=7000)
mask=np.full(source.shape[:2],255,np.uint8);mask[red>0]=0
keys_a,desc_a=orb.detectAndCompute(source,mask)
keys_b,desc_b=orb.detectAndCompute(reference,None)
matches=cv2.BFMatcher(cv2.NORM_HAMMING).knnMatch(desc_a,desc_b,k=2)
good=[a for a,b in matches if a.distance<.72*b.distance]
assert len(good)>30
a=np.float32([keys_a[m.queryIdx].pt for m in good]).reshape(-1,1,2)
b=np.float32([keys_b[m.trainIdx].pt for m in good]).reshape(-1,1,2)
matrix,inliers=cv2.findHomography(a,b,cv2.RANSAC,3.)
assert matrix is not None and int(inliers.sum())>25
error=np.linalg.norm(cv2.perspectiveTransform(a,matrix)-b,axis=2).ravel()[inliers.ravel()>0]
screen=cv2.perspectiveTransform(outline,matrix).reshape(-1,2)
result={'source':SOURCE.name,'reference':str(REFERENCE.relative_to(ROOT)),'matches':len(good),'inliers':int(inliers.sum()),'median_alignment_error_px':float(np.median(error)),'source_size':[source.shape[1],source.shape[0]],'reference_size':[reference.shape[1],reference.shape[0]],'screen_polygon':screen.round(3).tolist(),'boundary':'inner edge of the red stroke','homography':matrix.tolist()}
OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({k:v for k,v in result.items() if k not in ['screen_polygon','homography']},ensure_ascii=False))
