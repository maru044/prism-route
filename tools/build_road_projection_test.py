"""Bake the named Rhino road layer into a world-XZ mask and road-height field.

Uses only NumPy/Pillow. Source UVs, auxiliary lines and material assignments do
not participate. The generated data is a test fixture, not a terrain rewrite.
"""
from pathlib import Path
import argparse
import base64
import hashlib
import json
import shutil

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/world/road_projection_test"
CACHE = ROOT / ".road_projection_build"


def accessor(gltf, index):
    item = gltf["accessors"][index]
    if "sparse" in item:
        raise ValueError("Sparse accessors are not supported by this fixture builder")
    view = gltf["bufferViews"][item["bufferView"]]
    uri = gltf["buffers"][view["buffer"]]["uri"]
    if not uri.startswith("data:"):
        raise ValueError("This builder expects embedded glTF buffers")
    raw = base64.b64decode(uri.split(",", 1)[1])
    dtype = {5120:"i1",5121:"u1",5122:"<i2",5123:"<u2",5125:"<u4",5126:"<f4"}[item["componentType"]]
    width = {"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4}[item["type"]]
    offset = view.get("byteOffset", 0) + item.get("byteOffset", 0)
    size = np.dtype(dtype).itemsize
    return np.ndarray((item["count"], width), dtype=dtype, buffer=raw,
        offset=offset, strides=(view.get("byteStride", size*width), size)).copy()


def transform(node):
    if "matrix" in node:
        return np.array(node["matrix"], dtype=float).reshape(4,4).T
    x,y,z,w = node.get("rotation", [0,0,0,1])
    rotation = np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
        [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
        [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
    result = np.eye(4)
    result[:3,:3] = rotation @ np.diag(node.get("scale", [1,1,1]))
    result[:3,3] = node.get("translation", [0,0,0])
    return result


def layers(gltf):
    groups = {"地形":[], "路面":[]}
    def visit(index, parent, layer=None):
        node = gltf["nodes"][index]
        layer = node.get("name") if node.get("name") in groups else layer
        matrix = parent @ transform(node)
        if layer and "mesh" in node:
            for primitive in gltf["meshes"][node["mesh"]]["primitives"]:
                if primitive.get("mode", 4) != 4:
                    continue
                positions = accessor(gltf, primitive["attributes"]["POSITION"])
                positions = np.c_[positions, np.ones(len(positions))] @ matrix.T
                indices = accessor(gltf, primitive["indices"]).reshape(-1) if "indices" in primitive else np.arange(len(positions))
                groups[layer].append(positions[indices.reshape(-1,3), :3])
        for child in node.get("children", []):
            visit(child, matrix, layer)
    for index in gltf["scenes"][gltf.get("scene", 0)]["nodes"]:
        visit(index, np.eye(4))
    return {name:np.concatenate(parts).astype(np.float32) for name,parts in groups.items()}


def raster(triangles, origin, extent, resolution):
    """Topmost projected Y at each pixel center, with -inf for absent surfaces."""
    result = np.full((resolution,resolution), -np.inf, dtype=np.float32)
    skipped = 0
    for triangle in triangles:
        projected = (triangle[:,[0,2]] - origin) / extent * resolution - .5
        a,b,c = projected
        denominator = (b[1]-c[1])*(a[0]-c[0]) + (c[0]-b[0])*(a[1]-c[1])
        if abs(denominator) < 1e-7:
            skipped += 1
            continue
        low = np.maximum(np.ceil(projected.min(axis=0)).astype(int), 0)
        high = np.minimum(np.floor(projected.max(axis=0)).astype(int), resolution-1)
        if np.any(high < low):
            continue
        x = np.arange(low[0], high[0]+1, dtype=np.float32)[None,:]
        y = np.arange(low[1], high[1]+1, dtype=np.float32)[:,None]
        wa = ((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(y-c[1]))/denominator
        wb = ((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(y-c[1]))/denominator
        wc = 1-wa-wb
        inside = (wa >= -1e-6) & (wb >= -1e-6) & (wc >= -1e-6)
        heights = wa*triangle[0,1] + wb*triangle[1,1] + wc*triangle[2,1]
        window = result[low[1]:high[1]+1, low[0]:high[0]+1]
        np.maximum(window, np.where(inside, heights, -np.inf), out=window)
    return result, skipped


def sample_top(points, field, origin, extent):
    resolution = field.shape[0]
    pixels = np.floor((points[:,[0,2]]-origin)/extent*resolution).astype(int)
    # Conservative 3x3 search prevents edge pixels of narrow CAD surfaces from
    # being labelled unsupported merely because a pixel center fell outside.
    result = np.full(len(points), -np.inf, dtype=np.float32)
    for dx in [-1,0,1]:
        for dy in [-1,0,1]:
            x = np.clip(pixels[:,0]+dx,0,resolution-1)
            y = np.clip(pixels[:,1]+dy,0,resolution-1)
            result = np.maximum(result,field[y,x])
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=Path(r"D:\Prism Route\map\model_1006.gltf"))
    parser.add_argument("--resolution", type=int, default=4096)
    parser.add_argument("--edge-samples", type=int, default=2,
        help="Samples per axis before averaging coverage/height into the atlas")
    parser.add_argument("--height-tolerance", type=float, default=2.0)
    args = parser.parse_args()
    if args.resolution < 32 or args.edge_samples < 1:
        parser.error("resolution must be >=32 and edge-samples >=1")
    OUT.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    gltf = json.loads(args.source.read_text(encoding="utf-8-sig"))
    groups = layers(gltf)
    terrain, road = groups["地形"], groups["路面"]
    all_points = np.concatenate([terrain.reshape(-1,3), road.reshape(-1,3)])
    center = (all_points.min(axis=0)+all_points.max(axis=0))*.5
    translation = np.array([-center[0],0,-center[2]],dtype=np.float32)
    terrain += translation
    road += translation
    points = np.concatenate([terrain.reshape(-1,3),road.reshape(-1,3)])
    origin = points[:,[0,2]].min(axis=0)-4
    extent = points[:,[0,2]].max(axis=0)+4-origin
    print("ROAD_BAKE geometry", len(terrain), len(road), "triangles", flush=True)
    top, terrain_skipped = raster(terrain, origin, extent, args.resolution)
    road_height, road_skipped = raster(road, origin, extent, args.resolution)
    mask = np.isfinite(road_height)
    terrain_present = np.isfinite(top)
    gap = road_height[mask & terrain_present]-top[mask & terrain_present]
    close = mask & terrain_present & (np.abs(np.where(mask,road_height,0)-np.where(terrain_present,top,0)) <= args.height_tolerance)
    # RG16F: R=coverage, G=road height * coverage. Linear/mip filtering remains
    # coverage-weighted; the shader reconstructs Y as G/R without edge bleed.
    packed = np.zeros((args.resolution,args.resolution,2),dtype="<f2")
    if args.edge_samples > 1:
        high, _ = raster(road, origin, extent, args.resolution * args.edge_samples)
        shape = (args.resolution,args.edge_samples,args.resolution,args.edge_samples)
        covered = np.isfinite(high)
        packed[:,:,0] = covered.reshape(shape).mean(axis=(1,3),dtype=np.float32)
        packed[:,:,1] = np.where(covered,high,0).reshape(shape).mean(axis=(1,3),dtype=np.float32)
        del high, covered
    else:
        packed[:,:,0] = mask
        packed[:,:,1] = np.where(mask,road_height,0)
    packed.tofile(CACHE / "road_projection.rg16f")
    Image.fromarray((packed[:,:,0].astype(np.float32)*255).astype(np.uint8)).save(OUT / "road_footprint.png")
    Image.new("RGB",(4,4),(102,145,76)).save(OUT / "grass_placeholder.png")
    Image.new("RGB",(4,4),(47,51,56)).save(OUT / "road_placeholder.png")
    centroids = road.mean(axis=1)
    top_at_center = sample_top(centroids,top,origin,extent)
    center_gap = centroids[:,1]-top_at_center
    vertices = road.reshape(-1,3)
    top_at_vertex = sample_top(vertices,top,origin,extent).reshape(-1,3)
    vertex_gap = road[:,:,1]-top_at_vertex
    # Retain whole triangles conservatively when a center or >=2 corners need
    # support. This is a diagnostic extraction, not an authored bridge asset.
    need_mesh = (~np.isfinite(top_at_center)) | (np.abs(center_gap)>args.height_tolerance)
    need_mesh |= ((~np.isfinite(top_at_vertex)) | (np.abs(vertex_gap)>args.height_tolerance)).sum(axis=1)>=2
    unsupported = road[need_mesh]
    (OUT / "unsupported_road_triangles.json").write_text(json.dumps(unsupported.reshape(-1,3).round(5).tolist()),encoding="utf-8")
    supported_ids = np.flatnonzero(~need_mesh)
    near_id = supported_ids[np.argmin(np.linalg.norm(centroids[supported_ids][:,[0,2]],axis=1))] if len(supported_ids) else 0
    normals = np.cross(road[:,1]-road[:,0],road[:,2]-road[:,0])
    normals /= np.maximum(np.linalg.norm(normals,axis=1)[:,None],1e-8)
    slope_id = supported_ids[np.argmin(np.abs(normals[supported_ids,1]))] if len(supported_ids) else near_id
    unsupported_ids = np.flatnonzero(need_mesh)
    bridge_id = unsupported_ids[np.argmax(np.where(np.isfinite(center_gap[unsupported_ids]),center_gap[unsupported_ids],1000))] if len(unsupported_ids) else near_id
    metadata = {"source_file":args.source.name,"source_sha256":hashlib.sha256(args.source.read_bytes()).hexdigest(),
        "resolution":args.resolution,"edge_samples_per_axis":args.edge_samples,
        "model_translation":translation.tolist(),"mask_origin_xz":origin.tolist(),
        "mask_extent_xz":extent.tolist(),"meters_per_texel_xz":(extent/args.resolution).tolist(),
        "terrain_triangles":len(terrain),"road_triangles":len(road),"height_tolerance_m":args.height_tolerance,
        "road_mask_pixels":int(mask.sum()),"near_terrain_pixels":int(close.sum()),
        "no_terrain_pixels":int((mask & ~terrain_present).sum()),
        "height_mismatch_pixels":int((mask & terrain_present & ~close).sum()),
        "signed_gap_percentiles_m":np.percentile(gap,[0,5,50,95,100]).tolist(),
        "terrain_xz_degenerate_triangles":terrain_skipped,"road_xz_degenerate_triangles":road_skipped,
        "retained_hybrid_triangles":len(unsupported),"removed_ground_triangles":int((~need_mesh).sum()),
        "views":{"near":centroids[near_id].tolist(),"slope":centroids[slope_id].tolist(),"unsupported":centroids[bridge_id].tolist()},
        "unsupported_center_gap_m":float(center_gap[bridge_id]) if np.isfinite(center_gap[bridge_id]) else None}
    (OUT / "bake_metadata.json").write_text(json.dumps(metadata,indent=2),encoding="utf-8")
    if args.source.resolve() != (OUT / "model_1006.gltf").resolve():
        shutil.copy2(args.source,OUT / "model_1006.gltf")
    print(json.dumps(metadata,indent=2),flush=True)


if __name__ == "__main__":
    main()
