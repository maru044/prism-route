import * as THREE from 'three';
import { MarchingCubes } from 'three/addons/objects/MarchingCubes.js';
import { mergeVertices } from 'three/addons/utils/BufferGeometryUtils.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

// All architectural solids are generated here in browser JavaScript.
// Coordinates: metres, Y up. No Rhino/Blender or source mesh is used.
const V=THREE.Vector3;
const mix=(a,b,t)=>a+(b-a)*t;
const clamp=(x,a=0,b=1)=>Math.max(a,Math.min(b,x));
const smoothMin=(a,b,k)=>{const h=clamp(.5+.5*(b-a)/k);return mix(b,a,h)-k*h*(1-h);};
function rng(seed=1847){return ()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};}
let random=rng();
export const config={resolution:144,fan:1,belly:1,seed:1847};
export const design=[
  {name:'Upper_landscape',points:[[-177,-103,12,34],[-171,-34,32,59],[-127,41,54,76],[-51,87,64,86],[39,88,57,75],[114,47,39,64],[170,-15,9,38]],roots:[.18,.40,.62,.83],base:10,bulge:6},
  {name:'Middle_landscape',points:[[-143,-117,5,26],[-126,-53,12,36],[-94,2,25,48],[-35,34,36,57],[42,35,31,52],[106,6,17,42],[147,-40,4,28]],roots:[.20,.45,.73],base:7,bulge:4},
  {name:'Lower_coastal_wing',points:[[-139,-106,3,20],[-95,-65,6,30],[-43,-37,13,36],[17,-31,16,38],[75,-43,10,33],[127,-76,2.5,20]],roots:[.28,.60,.82],base:5,bulge:2.8},
  {name:'Diagonal_road_bridge',points:[[-161,-115,6,16],[-141,-54,22,16],[-109,10,42,17],[-59,68,59,18],[2,125,35,18],[28,157,29,18]],roots:[.25,.54,.80],base:5.5,bulge:.4,road:true}
];
function makeRibbon(spec){
  const curve=new THREE.CatmullRomCurve3(spec.points.map(p=>new V(p[0],p[2],p[1])),false,'catmullrom',.35);
  const samples=[];const steps=140;
  for(let i=0;i<=steps;i++){
    const t=i/steps;const p=curve.getPoint(t),tan=curve.getTangent(t);tan.y=0;tan.normalize();
    const f=t*(spec.points.length-1),k=Math.min(Math.floor(f),spec.points.length-2),q=f-k;
    samples.push({x:p.x,z:p.z,y:p.y,w:mix(spec.points[k][3],spec.points[k+1][3],q)*(1+.035*Math.sin(t*19)),t,nx:-tan.z,nz:tan.x});
  }
  function at(t,cross=0){const f=clamp(t)*steps,k=Math.min(Math.floor(f),steps-1),q=f-k,a=samples[k],b=samples[k+1];const p={};for(const key of ['x','z','y','w','nx','nz'])p[key]=mix(a[key],b[key],q);p.x+=p.nx*p.w*.5*cross;p.z+=p.nz*p.w*.5*cross;return p;}
  function nearest(x,z){let best=Infinity,result;
    for(let i=0;i<samples.length-1;i++){
      const a=samples[i],b=samples[i+1],dx=b.x-a.x,dz=b.z-a.z;
      const t=clamp(((x-a.x)*dx+(z-a.z)*dz)/(dx*dx+dz*dz));
      const px=mix(a.x,b.x,t),pz=mix(a.z,b.z,t),vx=x-px,vz=z-pz,dd=vx*vx+vz*vz;
      if(dd<best){best=dd;const nx=mix(a.nx,b.nx,t),nz=mix(a.nz,b.nz,t);result={dist:Math.sqrt(dd),cross:vx*nx+vz*nz,y:mix(a.y,b.y,t),w:mix(a.w,b.w,t),t:mix(a.t,b.t,t)};}
    }return result;
  }
  function top(q){const cross=q.cross/(q.w*.5);return q.y+spec.bulge*(1-cross*cross)+1.1*Math.sin(q.t*9+cross*.8)*(!spec.road?1:.15);}
  function position(t,cross){const p=at(t,cross),q=nearest(p.x,p.z),thickness=bellyThickness(spec,q),ratio=clamp(q.dist/(q.w*.5));
    const crown=top(q)-thickness*.5*(1-Math.sqrt(1-ratio**4));return new V(p.x,crown,p.z);}
  return {...spec,curve,samples,at,nearest,top,position};
}

function tube(points,radii,flatten=1){
  const curve=new THREE.CatmullRomCurve3(points.map(p=>new V(...p)),false,'catmullrom',.25),segments=[];
  for(let i=0;i<9;i++){
    const a=curve.getPoint(i/9),b=curve.getPoint((i+1)/9);
    const rAt=t=>{let f=t*(radii.length-1),k=Math.min(Math.floor(f),radii.length-2);return mix(radii[k],radii[k+1],f-k);};
    const ra=rAt(i/9),rb=rAt((i+1)/9);segments.push({a,b,ra,rb,dx:b.x-a.x,dy:b.y-a.y,dz:b.z-a.z,flatten});
  }return segments;
}
function supports(ribbon){
  const segments=[],feet=[];
  for(let i=0;i<ribbon.roots.length;i++){
    const t=ribbon.roots[i],p=ribbon.at(t),h=p.y,scale=ribbon.road?.63:1;
    const tangent=new V(p.nz,0,-p.nx),normal=new V(p.nx,0,p.nz);
    const side=(i%2===0?1:-1),foot=new V(p.x,1,p.z).addScaledVector(normal,side*p.w*.20).addScaledVector(tangent,(i%2===0?-1:1)*10);
    const neck=new V(p.x,h*.43,p.z).addScaledVector(normal,side*p.w*.12);
    const radius=(ribbon.base>8?5.4:ribbon.base>6?4.1:3.0)*scale;
    feet.push({x:foot.x,z:foot.z,r:radius,t});
    segments.push(...tube([[foot.x,-4,foot.z],[foot.x+normal.x*2,h*.16,foot.z+normal.z*2],[neck.x,neck.y,neck.z]],[radius*1.15,radius,radius*1.65],.85));
    for(const sign of [-1,1]){
      const q=ribbon.at(clamp(t+sign*.065));
      const head=new V(q.x,q.y-ribbon.base*.45,q.z).addScaledVector(normal,-side*p.w*.13);
      const shoulder=neck.clone().lerp(head,.60).addScaledVector(normal,sign*3);
      segments.push(...tube([[neck.x,neck.y-2,neck.z],[shoulder.x,shoulder.y,shoulder.z],[head.x,head.y,head.z]],[radius*1.55,radius*2.15,Math.min(p.w*.30,h*.42)*config.fan*scale],.78));
    }
  }
  // Continuous solid abutments at both ends, rather than an arcade everywhere.
  for(const t of [.012,.986]){
    const p=ribbon.at(t);const r=p.w*.39;
    segments.push(...tube([[p.x,-5,p.z],[p.x+5,p.y*.35,p.z],[p.x,p.y-r*.38,p.z]],[r*.82,r*.92,r],1));
  }
  return {segments,feet};
}
function tubeDistance(x,y,z,s){
  const dx=x-s.a.x,dy=y-s.a.y,dz=(z-s.a.z)/s.flatten;
  const ez=s.dz/s.flatten,den=s.dx*s.dx+s.dy*s.dy+ez*ez;
  const t=clamp((dx*s.dx+dy*s.dy+dz*ez)/den);
  const r=mix(s.ra,s.rb,t);const px=dx-s.dx*t,py=dy-s.dy*t,pz=dz-ez*t;
  return Math.sqrt(px*px+py*py+pz*pz)-r;
}
function roundedSection(a,b,r){const x=a+r,y=b+r;return Math.hypot(Math.max(x,0),Math.max(y,0))+Math.min(Math.max(x,y),0)-r;}
function bellyThickness(ribbon,q){return (ribbon.base+4*Math.pow(Math.sin(Math.PI*q.t),2)+2.5*Math.cos(q.t*17))*config.belly;}
function smoothGeometry(geometry){
  geometry.deleteAttribute('normal');const g=mergeVertices(geometry,.0005),index=g.index.array;let p=g.attributes.position.array;
  // Quantized welding can put almost identical marching-cube edge vertices
  // in adjacent hash buckets. Repair those seam vertices before smoothing;
  // otherwise independent neighborhoods pull a microscopic crack apart.
  const edgeCounts=new Map(),nv=p.length/3;
  for(let i=0;i<index.length;i+=3)for(const [a,b] of [[index[i],index[i+1]],[index[i+1],index[i+2]],[index[i+2],index[i]]]){
    const key=Math.min(a,b)*nv+Math.max(a,b);edgeCounts.set(key,(edgeCounts.get(key)||0)+1);
  }
  const border=new Set();for(const [key,count] of edgeCounts)if(count===1){border.add(Math.floor(key/nv));border.add(key%nv);}
  const ids=[...border],remap=new Map();
  for(let i=0;i<ids.length;i++)for(let j=i+1;j<ids.length;j++){
    const a=ids[i],b=ids[j];if(remap.has(b))continue;
    const dx=p[a*3]-p[b*3],dy=p[a*3+1]-p[b*3+1],dz=p[a*3+2]-p[b*3+2];
    if(dx*dx+dy*dy+dz*dz<.0001)remap.set(b,remap.get(a)??a);
  }
  const cleaned=[];
  for(let i=0;i<index.length;i+=3){const a=remap.get(index[i])??index[i],b=remap.get(index[i+1])??index[i+1],c=remap.get(index[i+2])??index[i+2];if(a!==b&&b!==c&&a!==c)cleaned.push(a,b,c);}
  // Close small residual marching-cube boundary circuits explicitly.
  const directed=new Map(),countVertices=p.length/3;
  for(let i=0;i<cleaned.length;i+=3)for(const [a,b] of [[cleaned[i],cleaned[i+1]],[cleaned[i+1],cleaned[i+2]],[cleaned[i+2],cleaned[i]]]){
    const key=Math.min(a,b)*countVertices+Math.max(a,b),e=directed.get(key);
    if(e)e.count++;else directed.set(key,{a,b,count:1});
  }
  const outgoing=new Map();for(const e of directed.values())if(e.count===1){if(!outgoing.has(e.a))outgoing.set(e.a,[]);outgoing.get(e.a).push(e.b);}
  const visited=new Set(),extra=[],loops=[];
  for(const e of directed.values()){
    if(e.count!==1||visited.has(e.a+','+e.b))continue;
    const loop=[e.a];let a=e.a,b=e.b,closed=false;
    for(let j=0;j<512;j++){
      visited.add(a+','+b);if(b===loop[0]){closed=true;break;}loop.push(b);
      const next=(outgoing.get(b)||[]).find(c=>!visited.has(b+','+c));if(next===undefined)break;a=b;b=next;
    }
    if(!closed||loop.length<3)continue;
    let x=0,y=0,z=0,perimeter=0;
    for(let j=0;j<loop.length;j++){const a=loop[j],b=loop[(j+1)%loop.length];x+=p[a*3];y+=p[a*3+1];z+=p[a*3+2];perimeter+=Math.hypot(p[a*3]-p[b*3],p[a*3+1]-p[b*3+1],p[a*3+2]-p[b*3+2]);}
    if(perimeter>30)continue;
    const center=countVertices+extra.length/3;extra.push(x/loop.length,y/loop.length,z/loop.length);
    for(let j=0;j<loop.length;j++)cleaned.push(loop[(j+1)%loop.length],loop[j],center);
    loops.push({edges:loop.length,perimeter});
  }
  if(extra.length){const expanded=new Float32Array(p.length+extra.length);expanded.set(p);expanded.set(extra,p.length);p=expanded;g.setAttribute('position',new THREE.BufferAttribute(p,3));}
  g.setIndex(cleaned);g.userData.boundaryRepairs=loops;const repaired=g.index.array;
  const neighbors=Array.from({length:p.length/3},()=>new Set());
  for(let i=0;i<repaired.length;i+=3){const a=repaired[i],b=repaired[i+1],c=repaired[i+2];neighbors[a].add(b).add(c);neighbors[b].add(a).add(c);neighbors[c].add(a).add(b);}
  const next=new Float32Array(p.length);
  for(const amount of Array.from({length:32},(_,i)=>i%2?-.53:.50)){
    for(let i=0;i<neighbors.length;i++){
      let x=0,y=0,z=0;const ns=neighbors[i];if(!ns.size){next[i*3]=p[i*3];next[i*3+1]=p[i*3+1];next[i*3+2]=p[i*3+2];continue;}
      for(const j of ns){x+=p[j*3];y+=p[j*3+1];z+=p[j*3+2];}
      const k=i*3,n=ns.size||1;next[k]=p[k]+amount*(x/n-p[k]);next[k+1]=p[k+1]+amount*(y/n-p[k+1]);next[k+2]=p[k+2]+amount*(z/n-p[k+2]);
    }p.set(next);
  }
  // The implicit pavilion can leave tiny detached remnants between overlapping
  // window cutters. Retain the intended connected solid, not those fragments.
  const components=new Int32Array(neighbors.length).fill(-1),sizes=[];
  for(let start=0;start<neighbors.length;start++){
    if(components[start]>=0||!neighbors[start].size)continue;
    const number=sizes.length,stack=[start];components[start]=number;let size=0;
    while(stack.length){const i=stack.pop();size++;for(const j of neighbors[i])if(components[j]<0){components[j]=number;stack.push(j);}}
    sizes.push(size);
  }
  const largest=sizes.indexOf(Math.max(...sizes)),connected=[];
  for(let i=0;i<repaired.length;i+=3)if(components[repaired[i]]===largest)connected.push(repaired[i],repaired[i+1],repaired[i+2]);
  g.setIndex(connected);g.computeVertexNormals();
  // The anisotropic marching grid creates skinny triangles. Smooth shading
  // normals separately from positions so specular light does not emphasize
  // their sampling direction. This is shading, not a continuity guarantee.
  const normals=g.attributes.normal.array,normalNext=new Float32Array(normals.length);
  for(let pass=0;pass<8;pass++){
    for(let i=0;i<neighbors.length;i++){
      const k=i*3;let x=normals[k],y=normals[k+1],z=normals[k+2];
      const ns=neighbors[i],weight=.5/(ns.size||1);
      x*=.5;y*=.5;z*=.5;
      for(const j of ns){x+=normals[j*3]*weight;y+=normals[j*3+1]*weight;z+=normals[j*3+2]*weight;}
      const length=Math.hypot(x,y,z)||1;normalNext[k]=x/length;normalNext[k+1]=y/length;normalNext[k+2]=z/length;
    }normals.set(normalNext);
  }
  const compact=mergeVertices(g,.0001);
  g.dispose();geometry.dispose();return compact;
}
function geometryFromField(bounds,resolution,field,material){
  const mc=new MarchingCubes(resolution,material,false,false,260000);mc.isolation=0;
  const dx=(bounds.max.x-bounds.min.x)/resolution,dy=(bounds.max.y-bounds.min.y)/resolution,dz=(bounds.max.z-bounds.min.z)/resolution;
  field(mc,dx,dy,dz);mc.update();
  const count=mc.geometry.drawRange.count;
  if(count<=0||count>=260000*3)throw new Error('Implicit mesh empty or capacity exceeded');
  const g=new THREE.BufferGeometry();
  for(const key of ['position','normal'])g.setAttribute(key,new THREE.BufferAttribute(mc.geometry.attributes[key].array.slice(0,count*3),3));
  const transform=new THREE.Matrix4().compose(bounds.getCenter(new V()),new THREE.Quaternion(),bounds.getSize(new V()).multiplyScalar(.5));
  g.applyMatrix4(transform);mc.geometry.dispose();const result=smoothGeometry(g);result.computeBoundingBox();result.computeBoundingSphere();return result;
}
async function architecturalRibbon(ribbon,material,progress){
  const support=supports(ribbon),box=new THREE.Box3();
  for(const p of ribbon.samples){box.expandByPoint(new V(p.x-p.w*.65,-40,p.z-p.w*.65));box.expandByPoint(new V(p.x+p.w*.65,p.y+15,p.z+p.w*.65));}
  // Marching cubes leaves exterior grid cells unused. Keep the flared end roots
  // well inside the sampled field instead of cutting them at its boundary.
  box.expandByVector(new V(15,0,15));
  const n=config.resolution;
  const cached=new Array(n*n);const span=box.getSize(new V());
  for(let iz=0;iz<n;iz++)for(let ix=0;ix<n;ix++){
    const x=box.min.x+span.x*ix/n,z=box.min.z+span.z*iz/n,q=ribbon.nearest(x,z),top=ribbon.top(q);
    const candidates=support.segments.filter(s=>x>=Math.min(s.a.x,s.b.x)-Math.max(s.ra,s.rb)-10&&x<=Math.max(s.a.x,s.b.x)+Math.max(s.ra,s.rb)+10&&z>=Math.min(s.a.z,s.b.z)-Math.max(s.ra,s.rb)-10&&z<=Math.max(s.a.z,s.b.z)+Math.max(s.ra,s.rb)+10);
    const thickness=bellyThickness(ribbon,q);
    const reserves=[];
    for(const road of roadGuides){const rq=road.nearest(x,z);if(rq.dist<7.5)reserves.push({distance:rq.dist,base:road.top(rq)+.38});}
    cached[iz*n+ix]={...q,top,thickness,candidates,reserves};
  }
  await new Promise(requestAnimationFrame);
  const geometry=geometryFromField(box,n,(mc,dx,dy,dz)=>{
    for(let iz=0;iz<n;iz++)for(let iy=0;iy<n;iy++)for(let ix=0;ix<n;ix++){
      const x=box.min.x+ix*dx,y=box.min.y+iy*dy,z=box.min.z+iz*dz,q=cached[iz*n+ix];
      // A broad superelliptic section rolls the crown continuously into the
      // side and belly. It avoids a vertical extrusion wall around a slab.
      const cross=q.dist/(q.w*.5),vertical=(y-(q.top-q.thickness*.5))/(q.thickness*.5);
      let d=(Math.hypot(cross*cross,vertical)-1)*q.thickness*.5;
      let root=1000;
      for(const s of q.candidates){if(y<Math.min(s.a.y,s.b.y)-Math.max(s.ra,s.rb)-8||y>Math.max(s.a.y,s.b.y)+Math.max(s.ra,s.rb)+8)continue;root=smoothMin(root,tubeDistance(x,y,z,s),3.2);}
      const envelope=q.top-q.thickness*.5*(1-Math.sqrt(Math.max(0,1-Math.min(cross,1)**4)));
      root=Math.max(root,y-envelope+.35);
      d=smoothMin(d,root,ribbon.road?4.4:7.0);
      // Keep the crown below a shared envelope: shoulder blends cannot grow
      // arbitrary spheres above the traversable roof.
      d=Math.max(d,y-envelope-.18);
      for(const reserve of q.reserves){
        const ceiling=reserve.base+4.0+2.8*Math.sqrt(Math.max(0,1-(reserve.distance/6.5)**2));
        const tunnel=Math.max(reserve.distance-6.5,y-ceiling,reserve.base+.15-y);
        d=Math.max(d,-tunnel);
      }
      mc.field[iz*n*n+iy*n+ix]=-d;
    }
  },material);
  const mesh=new THREE.Mesh(geometry,material);mesh.name=ribbon.name;mesh.castShadow=true;mesh.receiveShadow=true;
  mesh.userData={role:'continuous_architecture',method:'smooth implicit union of variable belly and branching flared supports',seed:config.seed};
  return {mesh,feet:support.feet,ribbon};
}

function pavilion(material){
  const box=new THREE.Box3(new V(-49,-9,120),new V(98,68,208));
  return new THREE.Mesh(geometryFromField(box,92,(mc,dx,dy,dz)=>{
    for(let iz=0;iz<92;iz++)for(let iy=0;iy<92;iy++)for(let ix=0;ix<92;ix++){
      const x=box.min.x+ix*dx,y=box.min.y+iy*dy,z=box.min.z+iz*dz;
      const xx=x-23,zz=z-163,theta=Math.atan2(zz/29,xx/64);
      const radius=Math.hypot(xx/64,zz/29),outer=(radius-(1+.035*Math.sin(theta*3)))*29;
      const crown=53+2.8*(1-radius*radius)+.8*Math.sin(theta*2);
      const roof=roundedSection(outer,Math.abs(y-(crown-2.3))-2.3,1.6);
      let wall=Math.max(Math.abs(outer+4.3)-4.2,Math.abs(y-26)-25);
      for(let i=0;i<14;i++){
        const a=i*Math.PI*2/14,px=23+61*Math.cos(a),pz=163+27*Math.sin(a);
        const vx=x-px,vz=z-pz,along=-Math.sin(a)*vx+Math.cos(a)*vz,radial=Math.cos(a)*vx+Math.sin(a)*vz;
        const opening=(Math.sqrt((along/8)**2+((y-17)/18)**2)-1)*7;
        const cutter=Math.max(opening,Math.abs(radial)-15);
        wall=Math.max(wall,-cutter);
      }
      mc.field[iz*92*92+iy*92+ix]=-smoothMin(roof,wall,2.8);
    }
  },material),material);
}

function strip(ribbon,width,offset,material,steps=200){
  const positions=[],uvs=[],indices=[];
  for(let i=0;i<=steps;i++){
    const t=i/steps,p=ribbon.at(t,offset),c=ribbon.position(t,offset),normal=new V(p.nx,0,p.nz);
    for(const side of [-1,1]){const v=c.clone().addScaledVector(normal,side*width*.5);v.y+=.38;positions.push(...v);uvs.push((side+1)*.5,t*25);}
    if(i<steps){const a=2*i;indices.push(a,a+1,a+2,a+1,a+3,a+2);}
  }
  const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));g.setAttribute('uv',new THREE.Float32BufferAttribute(uvs,2));g.setIndex(indices);g.computeVertexNormals();
  const m=new THREE.Mesh(g,material);m.receiveShadow=true;return m;
}
function plantingSurface(ribbon,material){
  const positions=[],colors=[],indices=[],color=new THREE.Color();const n=140,k=16;
  for(let i=0;i<=n;i++){
    const t=.025+.95*i/n;
    for(let j=0;j<=k;j++){
      const cross=(j/k*2-1)*(.62+.08*Math.sin(t*17)+.025*Math.cos(t*33));
      const p=ribbon.position(t,cross);p.y+=.85+(.4+.18*Math.sin(p.x*.32))*Math.sin(Math.PI*j/k);
      positions.push(...p);const noise=Math.sin(p.x*.18+p.z*.26)*Math.cos(p.z*.39-p.x*.11);
      color.setHSL(.14+.045*noise,.26+.04*noise,.35+.09*noise);colors.push(color.r,color.g,color.b);
      if(i<n&&j<k){const a=i*(k+1)+j;indices.push(a,a+1,a+k+1,a+1,a+k+2,a+k+1);}
    }
  }
  const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));g.setAttribute('color',new THREE.Float32BufferAttribute(colors,3));g.setIndex(indices);g.computeVertexNormals();
  const m=new THREE.Mesh(g,material);m.name=ribbon.name+'_landscape_surface';m.receiveShadow=true;return m;
}

export function groundHeight(x,z,ribbons){
  let distance=1000;
  for(const r of ribbons.slice(0,3)){const q=r.nearest(x,z);distance=Math.min(distance,q.dist-q.w*.42);}
  const building=Math.hypot((x-23)/68,(z-163)/38);distance=Math.min(distance,(building-1)*38);
  for(const [a,b,rx,rz] of [[42,-110,26,14],[94,-141,29,14],[-16,-151,13,8],[126,164,19,13],[-34,174,15,13]])distance=Math.min(distance,(Math.hypot((x-a)/rx,(z-b)/rz)-1)*Math.min(rx,rz));
  const shore=clamp(-distance/13),hill=Math.max(0,Math.sin(x*.034+z*.015)*Math.cos(z*.051-x*.024));
  return -7+9.0*shore+3.8*hill*shore+.5*Math.sin(x*.35)*Math.cos(z*.38)*shore;
}
function groundMesh(ribbons,material){
  const nx=180,nz=145,positions=[],colors=[],indices=[],color=new THREE.Color();
  for(let j=0;j<=nz;j++)for(let i=0;i<=nx;i++){
    const x=-227+i/nx*444,z=-181+j/nz*421,h=groundHeight(x,z,ribbons);positions.push(x,h,z);
    const q=Math.sin(x*.48)*Math.cos(z*.57),t=clamp((h-1.1)/4.7);
    color.set('#d9ccac').lerp(new THREE.Color('#8b9169'),t*.8);
    if(h<.5)color.lerp(new THREE.Color('#258da7'),clamp((.5-h)/7.5));
    color.multiplyScalar(1+q*.07);colors.push(color.r,color.g,color.b);
    if(i<nx&&j<nz){const a=j*(nx+1)+i;indices.push(a,a+nx+1,a+1,a+1,a+nx+1,a+nx+2);}
  }
  const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));g.setAttribute('color',new THREE.Float32BufferAttribute(colors,3));g.setIndex(indices);g.computeVertexNormals();
  const m=new THREE.Mesh(g,material);m.receiveShadow=true;m.name='Sculpted_shoreline_and_islets';return m;
}
function railing(ribbon,width,group,material,offset=0){
  const curvePoints=[[],[]];
  for(let i=0;i<=110;i++){
    const t=i/110,p=ribbon.at(t,offset),c=ribbon.position(t,offset);
    for(let side=0;side<2;side++){
      const sign=side===0?-1:1,x=c.x+p.nx*width*.5*sign,z=c.z+p.nz*width*.5*sign;
      curvePoints[side].push(new V(x,c.y+1.6,z));
      if(i%3===0){const post=new THREE.Mesh(new THREE.CylinderGeometry(.10,.10,1.2,5),material);post.position.set(x,c.y+1,z);group.add(post);}
    }
  }
  for(const points of curvePoints){const m=new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(points),150,.11,5,false),material);group.add(m);}
}
async function vegetation(ribbons,group){
  const points=[];
  for(const r of ribbons.filter(r=>!r.road))for(let i=0;i<100;i++){
    const t=.055+random()*.89,cross=(random()*2-1)*.50,p=r.position(t,cross);p.y+=.1;
    points.push({p,scale:.7+random()*.75});
  }
  for(let i=0;i<260;i++){
    const x=-210+random()*420,z=-167+random()*370,y=groundHeight(x,z,ribbons);
    if(y>1.5&&y<7)points.push({p:new V(x,y-.2,z),scale:.65+random()*.75});
  }
  const trunkMaterial=new THREE.MeshStandardMaterial({color:'#756b4e',roughness:.97}),leafMaterial=new THREE.MeshStandardMaterial({color:'#637b4d',roughness:.92});
  const trunks=new THREE.InstancedMesh(new THREE.CylinderGeometry(.18,.38,3.6,6),trunkMaterial,points.length);
  const leafGeo=new THREE.IcosahedronGeometry(1,2),crowns=new THREE.InstancedMesh(leafGeo,leafMaterial,points.length*5);
  trunks.name='Tree_trunks';crowns.name='Olive_sage_canopies';const o=new THREE.Object3D(),color=new THREE.Color();
  points.forEach(({p,scale},i)=>{
    o.position.copy(p);o.position.y+=1.8*scale;o.scale.setScalar(scale);o.rotation.set(0,random()*6,.12*(random()-.5));o.updateMatrix();trunks.setMatrixAt(i,o.matrix);
    for(let j=0;j<5;j++){
      o.position.copy(p);const a=j*Math.PI*2/5+random()*.5;const r=j===0?.2:1.65*scale;
      o.position.x+=Math.cos(a)*r;o.position.z+=Math.sin(a)*r;o.position.y+=(3.4+random())*scale;
      o.rotation.set(random(),random()*5,random());o.scale.set((2.1+random()*.8)*scale,(1.5+random()*.7)*scale,(2.0+random()*.5)*scale);o.updateMatrix();crowns.setMatrixAt(i*5+j,o.matrix);
      color.setHSL(.22+random()*.05,.22+random()*.15,.23+random()*.16);crowns.setColorAt(i*5+j,color);
    }
  });trunks.castShadow=true;crowns.castShadow=true;crowns.receiveShadow=true;
  const treeSource=await new GLTFLoader().loadAsync('./assets/tree_small_broad_canopy.glb');
  treeSource.scene.updateMatrixWorld(true);const sourceBox=new THREE.Box3().setFromObject(treeSource.scene),treeHeight=sourceBox.getSize(new V()).y;
  treeSource.scene.traverse(source=>{
    if(!source.isMesh)return;
    const instances=new THREE.InstancedMesh(source.geometry,source.material,points.length);instances.name='Project_tree_'+source.name;
    points.forEach(({p,scale},i)=>{
      o.position.copy(p);o.position.y+=.8;o.rotation.set(0,(i*2.399),0);o.scale.setScalar(5.4/treeHeight*scale);o.updateMatrix();
      const matrix=o.matrix.clone().multiply(new THREE.Matrix4().makeTranslation(0,-sourceBox.min.y,0)).multiply(source.matrixWorld);
      instances.setMatrixAt(i,matrix);
    });instances.castShadow=true;instances.receiveShadow=true;group.add(instances);
  });
  const rockGeo=new THREE.IcosahedronGeometry(1,1),rockMat=new THREE.MeshStandardMaterial({color:'#bab8a2',roughness:1}),rocks=new THREE.InstancedMesh(rockGeo,rockMat,420);
  for(let i=0;i<420;i++){
    const r=ribbons[i%3],p=r.position(.025+random()*.95,(random()*2-1)*.56);
    if(i%3===0){const x=-200+random()*390,z=-160+random()*350,h=groundHeight(x,z,ribbons);p.set(x,h,z);}
    o.position.copy(p);o.position.y+=.25;o.rotation.set(random()*3,random()*6,random()*3);o.scale.set(.4+random()*1.8,.3+random()*.85,.5+random()*1.5);o.updateMatrix();rocks.setMatrixAt(i,o.matrix);
  }rocks.castShadow=true;rocks.receiveShadow=true;rocks.name='Coastal_limestone_rocks';group.add(rocks);
  const tuft=new THREE.BufferGeometry();tuft.setAttribute('position',new THREE.Float32BufferAttribute([-.42,0,0,.42,0,0,0,1.1,0,0,0,-.42,0,0,.42,0,1.1,0],3));tuft.computeVertexNormals();
  const grasses=new THREE.InstancedMesh(tuft,new THREE.MeshStandardMaterial({color:'#b7ab78',roughness:1,side:THREE.DoubleSide}),4200);
  for(let i=0;i<4200;i++){
    const r=ribbons[i%3],p=r.position(.025+random()*.95,(random()*2-1)*.6);o.position.copy(p);o.position.y+=.15;o.scale.setScalar(.35+random()*.75);o.rotation.set(0,random()*6,0);o.updateMatrix();grasses.setMatrixAt(i,o.matrix);color.setHSL(.12+random()*.12,.20+random()*.15,.38+random()*.18);grasses.setColorAt(i,color);
  }grasses.name='Dry_meadow_tufts';group.add(grasses);
  return points.length;
}
function camper(group,position,angle){
  const white=new THREE.MeshStandardMaterial({color:'#f5eee0',roughness:.38}),dark=new THREE.MeshStandardMaterial({color:'#20323c',roughness:.23});
  const van=new THREE.Group();van.name='Scale_reference_camper';
  const body=new THREE.Mesh(new THREE.BoxGeometry(2.15,2.35,5.1),white);body.position.y=1.65;body.castShadow=true;van.add(body);
  const window=new THREE.Mesh(new THREE.BoxGeometry(2.17,.8,1.1),dark);window.position.set(0,2.2,-1.35);van.add(window);
  const windshield=new THREE.Mesh(new THREE.BoxGeometry(1.8,.75,.035),dark);windshield.position.set(0,2.2,-2.57);van.add(windshield);
  for(const x of [-1.1,1.1])for(const z of [-1.5,1.5]){const wheel=new THREE.Mesh(new THREE.CylinderGeometry(.48,.48,.24,12),dark);wheel.rotation.z=Math.PI/2;wheel.position.set(x,.5,z);van.add(wheel);}
  van.position.copy(position);van.rotation.y=angle;group.add(van);
}
const lowerRoadSpec={name:'Lower_road',points:[[-166,-125,4.4,13],[-135,-82,5.5,13],[-110,-28,5.8,13],[-75,6,6,13],[-29,18,5,13],[26,7,3.8,13],[64,-11,3.5,13]],base:2,bulge:0,roots:[],road:true};
const roadGuides=[makeRibbon(design[3]),makeRibbon(lowerRoadSpec)];
export async function buildModel(materials,progress){
  random=rng(config.seed);
  const architecture=new THREE.Group(),nature=new THREE.Group(),roads=new THREE.Group(),land=new THREE.Group();
  architecture.name='Continuous_architectural_solids';nature.name='Landscape_and_vegetation';roads.name='Roads_and_walkways';land.name='Coastal_ground';
  const ribbons=design.map(makeRibbon),results=[];
  for(let i=0;i<ribbons.length;i++){progress(`连续实体 ${i+1}/${ribbons.length+1} · ${ribbons[i].name}`);await new Promise(requestAnimationFrame);const result=await architecturalRibbon(ribbons[i],materials.white,progress);architecture.add(result.mesh);results.push(result);}
  progress('生成中央建筑与海岸');await new Promise(requestAnimationFrame);
  const building=pavilion(materials.white);building.name='Central_organic_pavilion';building.castShadow=true;building.receiveShadow=true;architecture.add(building);
  const skylight=new THREE.Mesh(new THREE.SphereGeometry(1,64,20),materials.white);skylight.name='Roof_skylight_primitive';skylight.scale.set(17,1.2,9);skylight.position.set(43,57.0,164);architecture.add(skylight);
  land.add(groundMesh(ribbons,materials.sand));
  for(const r of ribbons.filter(r=>!r.road))nature.add(plantingSurface(r,materials.soil));
  const bridge=ribbons[3];roads.add(strip(bridge,8,0,materials.asphalt));roads.add(strip(bridge,.14,-.10,materials.line));
  for(const side of [-1,1])roads.add(strip(bridge,.13,side*.38,materials.line));
  railing(bridge,12,roads,materials.metal);
  // A lower road runs through the coastal openings rather than being painted
  // on the top of the high landscape. Its supports are the ground/island mass.
  const lower=makeRibbon(lowerRoadSpec);
  roads.add(strip(lower,7,0,materials.asphalt));roads.add(strip(lower,.13,0,materials.line));
  for(const side of [-1,1]){roads.add(strip(lower,1.8,side*.72,materials.white));railing(lower,11.5,roads,materials.metal);}
  camper(roads,lower.position(.29,0).add(new V(0,.45,0)),.35);
  camper(roads,bridge.position(.29,0).add(new V(0,.5,0)),.4);
  progress('生成植被与材质');await new Promise(requestAnimationFrame);const trees=await vegetation(ribbons,nature);
  let triangles=0;for(const r of results)triangles+=r.mesh.geometry.index.count/3;triangles+=building.geometry.index.count/3;
  return {architecture,nature,roads,land,ribbons,lower,results,trees,triangles,config:{...config}};
}
