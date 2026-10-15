import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root=path.dirname(fileURLToPath(import.meta.url));
const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript','.mjs':'text/javascript','.json':'application/json','.png':'image/png','.glb':'model/gltf-binary'};
http.createServer((req,res)=>{
  const relative=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
  if(req.method==='POST'&&relative.startsWith('/save/')){
    const name=relative.slice(6),allowed=['web-curved-architecture-v01.glb','web-curved-archipelago-v01.glb','build-report.json'];
    if(!allowed.includes(name)||req.headers.origin!=='http://127.0.0.1:8088'){res.writeHead(403);res.end();return;}
    const chunks=[];let size=0;
    req.on('data',chunk=>{size+=chunk.length;if(size>80*1024*1024){req.destroy();return;}chunks.push(chunk);});
    req.on('end',()=>{fs.writeFile(path.join(root,'exports',name),Buffer.concat(chunks),error=>{res.writeHead(error?500:200,{'Content-Type':'application/json'});res.end(JSON.stringify({saved:!error,name,bytes:size}));});});
    return;
  }
  const target=path.resolve(root,'.'+(relative==='/'?'/index.html':relative));
  if(!target.startsWith(root+path.sep)){res.writeHead(403);res.end();return;}
  fs.readFile(target,(error,data)=>{if(error){res.writeHead(404);res.end('Not found');return;}res.writeHead(200,{'Content-Type':mime[path.extname(target)]||'application/octet-stream','Cache-Control':'no-store'});res.end(data);});
}).listen(8088,'127.0.0.1',()=>console.log('Web terrace trial: http://127.0.0.1:8088'));
