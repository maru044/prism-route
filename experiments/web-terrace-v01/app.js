import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { Sky } from 'three/addons/objects/Sky.js';
import { GLTFExporter } from 'three/addons/exporters/GLTFExporter.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { buildModel,config,design } from './model.js';

const started=performance.now(),scene=new THREE.Scene();
const renderer=new THREE.WebGLRenderer({antialias:true,preserveDrawingBuffer:true});
renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));renderer.setSize(innerWidth,innerHeight);
renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=.80;
renderer.outputColorSpace=THREE.SRGBColorSpace;document.body.prepend(renderer.domElement);
const camera=new THREE.PerspectiveCamera(46,innerWidth/innerHeight,.25,16000);
const controls=new OrbitControls(camera,renderer.domElement);controls.enableDamping=true;controls.dampingFactor=.08;
controls.maxDistance=900;controls.minDistance=5;controls.maxPolarAngle=Math.PI*.95;
const sky=new Sky();sky.scale.setScalar(3000);scene.add(sky);
const sunVector=new THREE.Vector3().setFromSphericalCoords(1,THREE.MathUtils.degToRad(42),THREE.MathUtils.degToRad(218));
Object.assign(sky.material.uniforms.turbidity,{value:3.3});sky.material.uniforms.rayleigh.value=1.4;sky.material.uniforms.mieCoefficient.value=.006;sky.material.uniforms.mieDirectionalG.value=.82;sky.material.uniforms.sunPosition.value.copy(sunVector);
scene.environment=new THREE.PMREMGenerator(renderer).fromScene(new RoomEnvironment(),.04).texture;
scene.environmentIntensity=.60;
const sun=new THREE.DirectionalLight('#fff1dc',3.6);sun.position.set(-150,260,-160);sun.castShadow=true;
sun.shadow.mapSize.set(4096,4096);Object.assign(sun.shadow.camera,{left:-270,right:270,top:270,bottom:-270,near:1,far:850});sun.shadow.bias=-.00018;sun.shadow.normalBias=.20;sun.shadow.radius=2;scene.add(sun);sun.target.position.set(0,15,35);scene.add(sun.target);
scene.add(new THREE.HemisphereLight('#a9d2e3','#756b54',.65));
const white=new THREE.MeshPhysicalMaterial({color:'#ece9dd',roughness:.30,metalness:.015,clearcoat:.28,clearcoatRoughness:.30,envMapIntensity:.75});
const materials={white,sand:new THREE.MeshStandardMaterial({vertexColors:true,roughness:.97}),soil:new THREE.MeshStandardMaterial({vertexColors:true,roughness:1,side:THREE.DoubleSide}),asphalt:new THREE.MeshStandardMaterial({color:'#373b3b',roughness:.91,polygonOffset:true,polygonOffsetFactor:-2}),line:new THREE.MeshStandardMaterial({color:'#ece4d0',roughness:.8,polygonOffset:true,polygonOffsetFactor:-4}),metal:new THREE.MeshStandardMaterial({color:'#89938f',metalness:.7,roughness:.32})};
function waterTexture(){const n=256,canvas=document.createElement('canvas');canvas.width=canvas.height=n;const ctx=canvas.getContext('2d'),data=ctx.createImageData(n,n);
for(let y=0;y<n;y++)for(let x=0;x<n;x++){const u=x/n*Math.PI*2,v=y/n*Math.PI*2,p=(y*n+x)*4;data.data[p]=128+18*Math.sin(u*11+v*6)+12*Math.cos(v*17-u*9);data.data[p+1]=128+18*Math.cos(v*11+u*7)+12*Math.sin(u*15-v*8);data.data[p+2]=250;data.data[p+3]=255;}ctx.putImageData(data,0,0);const t=new THREE.CanvasTexture(canvas);t.wrapS=t.wrapT=THREE.RepeatWrapping;t.repeat.set(60,60);return t;}
const waterMat=new THREE.MeshPhysicalMaterial({color:'#278fac',roughness:.32,metalness:.05,transparent:true,opacity:.80,normalMap:waterTexture(),normalScale:new THREE.Vector2(.22,.22),envMapIntensity:.45});
const water=new THREE.Mesh(new THREE.PlaneGeometry(12000,12000),waterMat);water.rotation.x=-Math.PI/2;water.position.y=.25;water.name='Sea';scene.add(water);
const deepSea=new THREE.Mesh(new THREE.PlaneGeometry(13000,13000),new THREE.MeshStandardMaterial({color:'#258da7',roughness:.60}));deepSea.rotation.x=-Math.PI/2;deepSea.position.y=-8;deepSea.name='Deep_seabed';scene.add(deepSea);
let model,whiteMode=false,vegetationVisible=true;
const status=document.getElementById('status'),progress=document.getElementById('progress'),loading=document.getElementById('loading');
window.terraceLab={scene,camera,controls,renderer,ready:false,errors:[],config};
const views={overview:{camera:[265,222,-298],target:[0,28,65]},road:{camera:[-133,9,-73],target:[-73,18,12]},under:{camera:[95,8,138],target:[20,40,80]},structure:{camera:[180,85,-217],target:[-25,27,37]}};
function setView(name){const v=views[name];camera.position.set(...v.camera);controls.target.set(...v.target);
if(name==='road'&&model){camera.position.copy(model.lower.position(.34,0)).add(new THREE.Vector3(0,3.0,0));controls.target.copy(model.lower.position(.69,0)).add(new THREE.Vector3(0,10,0));}
camera.lookAt(controls.target);controls.update();document.querySelectorAll('[data-view]').forEach(b=>b.classList.toggle('active',b.dataset.view===name));window.terraceLab.view=name;}
async function rebuild(){
  loading.style.display='grid';progress.textContent='准备连续体积场';await new Promise(requestAnimationFrame);
  const buildStart=performance.now();
  if(model)for(const name of ['architecture','nature','roads','land']){scene.remove(model[name]);model[name].traverse(o=>{if(o.geometry)o.geometry.dispose();});}
  model=await buildModel(materials,text=>{progress.textContent=text;});
  for(const name of ['architecture','nature','roads','land'])scene.add(model[name]);
  window.terraceLab.model=model;window.terraceLab.buildMs=performance.now()-buildStart;
  window.terraceLab.ready=true;window.terraceLab.firstReadyMs=performance.now()-started;
  window.terraceLab.report={createdAt:new Date().toISOString(),architectureTriangles:model.triangles,trees:model.trees,buildSeconds:window.terraceLab.buildMs/1000,resolution:config.resolution,config:{...config},design,method:'Pure browser JS smooth implicit solids; four branching landscapes and one pavilion',bounds:{},measurement:'Scene generation including support fields, marching cubes, welded Taubin smoothing, roads and context; excludes developer time and frame rendering.'};
  for(const result of model.results){const b=result.mesh.geometry.boundingBox;window.terraceLab.report.bounds[result.mesh.name]={min:b.min.toArray(),max:b.max.toArray()};}
  model.nature.visible=vegetationVisible&&!whiteMode;loading.style.display='none';
  status.textContent=`实体生成 ${(window.terraceLab.buildMs/1000).toFixed(1)} 秒 · ${(model.triangles/10000).toFixed(1)} 万面 · ${model.trees} 棵树`;
}
function refreshMode(){
  model.nature.visible=vegetationVisible&&!whiteMode;model.land.visible=!whiteMode;water.visible=!whiteMode;deepSea.visible=!whiteMode;
  if(whiteMode){scene.remove(sky);scene.background=new THREE.Color('#dee4e4');materials.white.color.set('#e5e1d6');}
  else{scene.add(sky);scene.background=null;materials.white.color.set('#ece9dd');}
}
async function exportGLB(architectureOnly=false){
  const group=new THREE.Group();group.name='Web_curved_archipelago_v01';group.add(model.architecture.clone(true));
  if(!architectureOnly){group.add(model.roads.clone(true),model.land.clone(true),model.nature.clone(true));}
  return await new GLTFExporter().parseAsync(group,{binary:true,onlyVisible:false,trs:true});
}
window.terraceLab.exportGLB=exportGLB;window.terraceLab.setView=setView;
window.terraceLab.capture=()=>renderer.domElement.toDataURL('image/png');
function download(data,name,mime){const url=URL.createObjectURL(new Blob([data],{type:mime})),a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),10000);}
document.querySelectorAll('[data-view]').forEach(button=>button.addEventListener('click',()=>setView(button.dataset.view)));
document.getElementById('white').addEventListener('click',event=>{whiteMode=!whiteMode;event.target.classList.toggle('active',whiteMode);refreshMode();});
document.getElementById('plants').addEventListener('click',event=>{vegetationVisible=!vegetationVisible;event.target.classList.toggle('active',!vegetationVisible);refreshMode();});
for(const key of ['fan','belly'])document.getElementById(key).addEventListener('input',e=>{config[key]=Number(e.target.value);document.getElementById(key+'Value').value=config[key].toFixed(2);});
document.getElementById('rebuild').addEventListener('click',()=>rebuild().then(refreshMode).catch(fail));
document.getElementById('export').addEventListener('click',async event=>{event.target.disabled=true;event.target.textContent='导出中…';try{const binary=await exportGLB();const url=URL.createObjectURL(new Blob([binary],{type:'model/gltf-binary'}));const a=document.createElement('a');a.href=url;a.download='web-curved-archipelago-v01.glb';a.click();setTimeout(()=>URL.revokeObjectURL(url),10000);}catch(e){fail(e);}finally{event.target.disabled=false;event.target.textContent='导出 GLB';}});
document.getElementById('exportStructure').addEventListener('click',async event=>{event.target.disabled=true;try{download(await exportGLB(true),'web-curved-architecture-v01.glb','model/gltf-binary');}catch(e){fail(e);}finally{event.target.disabled=false;}});
document.getElementById('report').addEventListener('click',()=>download(JSON.stringify(window.terraceLab.report,null,2),'web-model-build-report.json','application/json'));
document.getElementById('save').addEventListener('click',async event=>{
  event.target.disabled=true;event.target.textContent='保存中…';
  try{
    for(const [name,data] of [['web-curved-architecture-v01.glb',await exportGLB(true)],['web-curved-archipelago-v01.glb',await exportGLB(false)],['build-report.json',JSON.stringify(window.terraceLab.report,null,2)]]){
      const response=await fetch('/save/'+name,{method:'POST',headers:{'Content-Type':'application/octet-stream'},body:data});
      if(!response.ok)throw new Error('Local project save failed: '+name);
    }event.target.textContent='已保存';
  }catch(e){fail(e);event.target.textContent='保存失败';}finally{event.target.disabled=false;}
});
function fail(error){window.terraceLab.errors.push(String(error.stack||error));loading.style.display='grid';document.getElementById('failure').textContent=String(error.stack||error);console.error(error);}
window.addEventListener('resize',()=>{camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();renderer.setSize(innerWidth,innerHeight);});
function animate(){requestAnimationFrame(animate);controls.update();waterMat.normalMap.offset.x=performance.now()*.0000012;renderer.render(scene,camera);}animate();setView('overview');
rebuild().catch(fail);
