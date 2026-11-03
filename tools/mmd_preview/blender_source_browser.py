"""Prism Route source-motion picker. Run as a Blender --python script.

Only native VMD key import and live constraint evaluation; no NLA visual bake,
animation export, source writes, global orphan purge, or external service.
"""
bl_info={'name':'Prism Route MMD Source Picker','author':'Prism Route','version':(1,0,0),'blender':(5,1,0),'category':'Animation'}

import datetime
import hashlib
import importlib
import json
import os
from pathlib import Path
import textwrap
import time
import sys

import addon_utils
import bpy
from bpy.app.handlers import persistent
from mathutils import Matrix, Quaternion, Vector

HERE=Path(__file__).resolve().parent
CONFIG=json.loads((HERE/'preview_config.json').read_text(encoding='utf-8'))
CATALOG={};FILES={};FOLDERS={};ENUM_CACHE={}
SCENE_NAME='MMD 源动作选片'
ROLE_COLORS={'A':(.16,.65,.82,1),'B':(.96,.48,.18,1),'C':(.62,.36,.89,1)}
DECISIONS={'KEEP':'保留','MAYBE':'待定','SKIP':'跳过'}
_UPDATING=False
_DECISION_CACHE=None
_DECISION_STAMP=None


def reload_catalog():
    global CATALOG,FILES,FOLDERS,ENUM_CACHE
    CATALOG=json.loads(Path(CONFIG['catalog']).read_text(encoding='utf-8'))
    FILES={r['id']:r for r in CATALOG['files']};FOLDERS={r['id']:r for r in CATALOG['folders']};ENUM_CACHE={}
    for group in CATALOG['folders']:
        # Keep Python strings alive for Blender dynamic EnumProperty callbacks.
        ENUM_CACHE[group['id']]=[('NONE','— 不加载 —','不加载此角色位')]+[(i,FILES[i]['label']+(' [特殊]' if FILES[i]['special_ik'] else ''),FILES[i]['family']+' / '+str(FILES[i]['bone_end'])+' 帧') for i in group['files']]


def state(scene):return scene.pr_mmd_source


def group_for(scene):
    s=state(scene)
    return FOLDERS.get(s.groups[s.group_index].key) if 0<=s.group_index<len(s.groups) else None


def role_items(self,context):
    group=group_for(context.scene) if context and hasattr(context.scene,'pr_mmd_source') else None
    return ENUM_CACHE[group['id']] if group else [('NONE','— 不加载 —','')]


def selection_ids(scene):
    s=state(scene)
    return [(role,getattr(s,'role_'+role.lower())) for role in ['A','B','C'] if getattr(s,'role_'+role.lower()) in FILES]


def read_decisions():
    global _DECISION_CACHE,_DECISION_STAMP
    path=Path(CONFIG['selection_file'])
    if not path.exists():return {'schema':1,'source_root':CATALOG.get('source_root',''),'takes':{}}
    info=path.stat();stamp=(str(path),info.st_mtime_ns,info.st_size)
    if stamp==_DECISION_STAMP and _DECISION_CACHE is not None:return _DECISION_CACHE
    data=json.loads(path.read_text(encoding='utf-8'))
    if data.get('schema')!=1 or not isinstance(data.get('takes'),dict):raise ValueError('选片清单格式不兼容，未覆盖原文件')
    _DECISION_CACHE=data;_DECISION_STAMP=stamp
    return data


def write_decisions(data):
    path=Path(CONFIG['selection_file']);path.parent.mkdir(parents=True,exist_ok=True)
    temporary=path.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    os.replace(temporary,path)


def fingerprint(ids):return hashlib.sha256(json.dumps(ids,ensure_ascii=False).encode('utf-8')).hexdigest()[:20]


def take_key(source_key,start,end):return fingerprint([source_key,int(start),int(end)])


def saved_for_source(source_key):
    matches=[v for k,v in read_decisions()['takes'].items() if v.get('source_key',k)==source_key]
    return max(matches,key=lambda v:v.get('updated_at',''),default={})


def refresh_decision_badges(scene):
    takes=read_decisions()['takes']
    for item in state(scene).groups:
        values=[v['decision'] for v in takes.values() if v.get('folder_id')==item.key]
        item.decision='KEEP' if 'KEEP' in values else ('MAYBE' if 'MAYBE' in values else ('SKIP' if values else 'NONE'))


def on_group(self,context):
    global _UPDATING
    if _UPDATING or not context:return
    group=group_for(context.scene)
    if not group:return
    for role,value in zip(['A','B','C'],group['suggested_roles']):setattr(self,'role_'+role.lower(),value)
    self.message='已选择目录；确认角色轨道后点击“加载预览”'


def on_range(self,context):
    global _UPDATING
    if _UPDATING or not context:return
    scene=context.scene
    maximum=self.loaded_max_frame if self.loaded_key else scene.frame_end
    a=min(self.trim_start,self.trim_end,maximum);b=min(max(self.trim_start,self.trim_end),maximum)
    _UPDATING=True;self.trim_start=a;self.trim_end=b;_UPDATING=False
    scene.use_preview_range=True;scene.frame_preview_start=a;scene.frame_preview_end=max(a,b)


def on_start(self,context):
    global _UPDATING
    if _UPDATING or not context:return
    maximum=self.loaded_max_frame if self.loaded_key else context.scene.frame_end
    a=min(self.trim_start,maximum);b=min(max(a,self.trim_end),maximum)
    _UPDATING=True;self.trim_start=a;self.trim_end=b;_UPDATING=False
    on_range(self,context)


def on_end(self,context):
    global _UPDATING
    if _UPDATING or not context:return
    maximum=self.loaded_max_frame if self.loaded_key else context.scene.frame_end
    b=min(self.trim_end,maximum);a=min(self.trim_start,b)
    _UPDATING=True;self.trim_start=a;self.trim_end=b;_UPDATING=False
    on_range(self,context)


class PRMMDSourceGroup(bpy.types.PropertyGroup):
    key:bpy.props.StringProperty()
    decision:bpy.props.StringProperty(default='NONE')


class PRMMDSourceState(bpy.types.PropertyGroup):
    groups:bpy.props.CollectionProperty(type=PRMMDSourceGroup)
    group_index:bpy.props.IntProperty(default=0,update=on_group)
    search:bpy.props.StringProperty(name='搜索目录')
    decision_filter:bpy.props.EnumProperty(name='筛选',items=[('ALL','全部',''),('NONE','未标记',''),('KEEP','已保留',''),('MAYBE','待定',''),('SKIP','已跳过','')],default='ALL')
    role_a:bpy.props.EnumProperty(name='角色 A',items=role_items)
    role_b:bpy.props.EnumProperty(name='角色 B',items=role_items)
    role_c:bpy.props.EnumProperty(name='角色 C',items=role_items)
    allow_special:bpy.props.BoolProperty(name='允许粗略预览特殊骨架',description='缺少控制骨时效果可能错误，不能据此批准正式转换',default=False)
    message:bpy.props.StringProperty(default='选择目录并加载预览')
    loaded_key:bpy.props.StringProperty()
    loaded_group:bpy.props.StringProperty()
    loaded_roles:bpy.props.StringProperty(default='[]')
    loaded_label:bpy.props.StringProperty()
    loaded_max_frame:bpy.props.IntProperty(default=1)
    trim_start:bpy.props.IntProperty(name='开始帧',default=0,min=0,update=on_start)
    trim_end:bpy.props.IntProperty(name='结束帧',default=1,min=0,update=on_end)
    note:bpy.props.StringProperty(name='备注')
    last_load_seconds:bpy.props.FloatProperty()


class PR_UL_MMDSourceFolders(bpy.types.UIList):
    def draw_item(self,context,layout,data,item,icon,active_data,active_propname,index):
        label=FOLDERS.get(item.key,{}).get('label',item.name)
        prefix={'KEEP':'✓ ','MAYBE':'? ','SKIP':'× ','NONE':''}.get(item.decision,'')
        layout.label(text=prefix+label)
    def filter_items(self,context,data,propname):
        s=state(context.scene);flags=[]
        for item in getattr(data,propname):
            group=FOLDERS.get(item.key,{})
            visible=s.search.casefold() in group.get('label','').casefold() and (s.decision_filter=='ALL' or s.decision_filter==item.decision)
            flags.append(self.bitflag_filter_item if visible else 0)
        return flags,[]


def role_objects(scene,role):return [o for o in scene.objects if o.get('pr_source_role')==role]


def role_armature(scene,role):return next((o for o in role_objects(scene,role) if o.type=='ARMATURE'),None)


def ensure_mmd():
    candidates=[m.__name__ for m in addon_utils.modules() if m.__name__.endswith('mmd_tools')]
    module=next((m for m in candidates if m in bpy.context.preferences.addons),None)
    if not module:
        if not candidates:raise RuntimeError('未找到已安装的 MMD Tools')
        addon_utils.enable(candidates[0],default_set=False,persistent=True)
    props=bpy.ops.mmd_tools.import_model.get_rna_type().properties
    assert {'MESH','ARMATURE'}<={i.identifier for i in props['types'].enum_items}


def ensure_role(context,role):
    scene=context.scene
    existing=role_armature(scene,role)
    if existing:return existing
    ensure_mmd()
    path=Path(CONFIG['reference_models'].get(role,CONFIG['reference_models']['A']))
    if not path.exists():raise FileNotFoundError(str(path))
    before=set(bpy.data.objects)
    result=bpy.ops.mmd_tools.import_model(filepath=str(path),scale=CONFIG['reference_scale'],types={'MESH','ARMATURE'},save_log=False,log_level='ERROR')
    if 'FINISHED' not in result:raise RuntimeError('参考模型导入失败：'+role)
    objects=set(bpy.data.objects)-before
    arm=next(o for o in objects if o.type=='ARMATURE');arm.name='PR_SourcePreview_'+role
    for obj in objects:
        # Some importers use the active scene collection; make ownership explicit.
        if obj.name not in scene.objects:scene.collection.objects.link(obj)
        obj['pr_source_role']=role
        obj['pr_source_bind_matrix']=[v for row in obj.matrix_basis for v in row]
        obj.color=ROLE_COLORS[role]
        if obj.type=='MESH':
            for modifier in obj.modifiers:
                if modifier.type!='ARMATURE':modifier.show_viewport=False
    arm['pr_source_ik_defaults']=json.dumps({b.name:bool(b.mmd_ik_toggle) for b in arm.pose.bones if hasattr(b,'mmd_ik_toggle')})
    return arm


def reset_role(scene,role):
    for obj in role_objects(scene,role):
        # Preserve MMD constraint drivers! animation_data_clear() would remove them.
        if obj.animation_data:
            obj.animation_data.action=None
            for track in list(obj.animation_data.nla_tracks):obj.animation_data.nla_tracks.remove(track)
        if obj.type=='MESH' and obj.data.shape_keys:
            keys=obj.data.shape_keys
            if keys.animation_data:keys.animation_data.action=None
            for key in keys.key_blocks:key.value=0.0
        values=obj.get('pr_source_bind_matrix')
        if values:obj.matrix_basis=Matrix([values[i:i+4] for i in range(0,16,4)])
        if obj.type=='ARMATURE':
            defaults=json.loads(obj.get('pr_source_ik_defaults','{}'))
            for bone in obj.pose.bones:
                bone.matrix_basis=Matrix.Identity(4)
                if bone.name in defaults and bone.mmd_ik_toggle!=defaults[bone.name]:bone.mmd_ik_toggle=defaults[bone.name]
        obj.hide_set(True)
        obj.select_set(False)


def purge_preview_actions():
    for action in list(bpy.data.actions):
        if action.get('pr_source_preview_action') and action.users==0:bpy.data.actions.remove(action)


def _screen_override(context):
    window=context.window or (bpy.context.window_manager.windows[0] if bpy.context.window_manager.windows else None)
    if not window:return None
    area=next((a for a in window.screen.areas if a.type=='VIEW_3D'),None)
    if not area:return None
    region=next(r for r in area.regions if r.type=='WINDOW')
    return {'window':window,'area':area,'region':region}


def stop_playback(context):
    override=_screen_override(context)
    if override and override['window'].screen.is_animation_playing:
        with bpy.context.temp_override(**override):bpy.ops.screen.animation_cancel(restore_frame=False)


def load_selected(context):
    global _UPDATING
    scene=context.scene;s=state(scene);group=group_for(scene);ids=selection_ids(scene)
    if not ids:raise ValueError('至少选择一条人体轨道')
    if len({i for _,i in ids})!=len(ids):raise ValueError('同一轨道不能同时放入两个角色位')
    if scene.name!=SCENE_NAME:raise ValueError('请先打开独立选片场景')
    paths=[]
    for role,key in ids:
        row=FILES[key];path=(Path(CATALOG['source_root'])/row['file']).resolve()
        if not path.is_relative_to(Path(CATALOG['source_root']).resolve()):raise ValueError('源路径越界')
        if not path.is_file():raise FileNotFoundError(str(path))
        if hashlib.sha256(path.read_bytes()).hexdigest()!=row['sha256']:raise ValueError('源文件已变化，请重新生成目录：'+row['file'])
        if row['special_ik'] and not s.allow_special:raise ValueError('缺少特殊控制骨；建议选普通版本，或显式允许粗略预览')
        paths.append((role,key,path))
    stop_playback(context);started=time.perf_counter()
    s.loaded_key='';s.message='正在载入源轨道…'
    for role in ['A','B','C']:reset_role(scene,role)
    purge_preview_actions()
    # MMD Tools offsets keys by the current playhead even with margin=0.
    # Every role must import at source frame zero, including after random seeks.
    scene.frame_set(0);context.view_layer.update()
    before=set(bpy.data.actions)
    try:
        for role,key,path in paths:
            arm=ensure_role(context,role)
            for obj in context.view_layer.objects:obj.select_set(False)
            arm.hide_set(False);arm.select_set(True);context.view_layer.objects.active=arm
            result=bpy.ops.mmd_tools.import_vmd(filepath=str(path),scale=CONFIG['reference_scale'],margin=0,bone_mapper='PMX',
                use_pose_mode=False,use_mirror=False,update_scene_settings=False,create_new_action=True,use_nla=False,save_log=False,log_level='ERROR')
            if 'FINISHED' not in result:raise RuntimeError('VMD 导入失败：'+FILES[key]['file'])
            if arm.animation_data and arm.animation_data.action:arm.animation_data.action.name='PR_Preview_'+role+'_'+FILES[key]['label']
            for obj in role_objects(scene,role):obj.hide_set(obj.type!='MESH')
            arm.select_set(False)
        for action in set(bpy.data.actions)-before:
            action['pr_source_preview_action']=True;action.use_fake_user=False
        scene.render.fps=CATALOG['fps'];scene.render.fps_base=1.0
        end=max(FILES[i]['bone_end'] for _,i in ids)
        scene.frame_start=0;scene.frame_end=max(1,end)
        s.loaded_group=group['id'];s.loaded_roles=json.dumps(ids,ensure_ascii=False);s.loaded_key=fingerprint(ids)
        s.loaded_label=group['label'];s.loaded_max_frame=end
        saved=saved_for_source(s.loaded_key)
        _UPDATING=True
        s.trim_start=min(int(saved.get('frame_start',0)),max(0,end))
        s.trim_end=min(int(saved.get('frame_end',end)),max(0,end))
        s.note=saved.get('note','')
        _UPDATING=False
        on_range(s,context)
        scene.frame_set(s.trim_start);context.view_layer.update()
        s.last_load_seconds=time.perf_counter()-started
        s.message='已加载 '+str(len(ids))+' 个角色位；未烘焙。可播放或标记片段。'
        frame_view(context)
        return ids
    except Exception:
        for role in ['A','B','C']:reset_role(scene,role)
        for action in set(bpy.data.actions)-before:action['pr_source_preview_action']=True
        purge_preview_actions();s.loaded_key='';s.message='载入未完成，已清空预览；请检查轨道与错误信息'
        raise
    finally:_UPDATING=False


def frame_view(context):
    scene=context.scene;s=state(scene)
    frames=sorted({s.trim_start,(s.trim_start+s.trim_end)//2,s.trim_end}) if s.loaded_key else [0]
    previous=scene.frame_current;points=[]
    depsgraph=context.evaluated_depsgraph_get()
    for frame in frames:
        scene.frame_set(frame)
        for role in ['A','B','C']:
            arm=role_armature(scene,role)
            if not arm:continue
            if s.loaded_key and role not in [r for r,_ in json.loads(s.loaded_roles)]:continue
            evaluated=arm.evaluated_get(depsgraph)
            for bone in evaluated.pose.bones:
                name=bone.bone.get('name_j',bone.name)
                if any(x in bone.name for x in ['スカート','发','髪','帯','袖','捩','裙','流苏']):continue
                points.append(evaluated.matrix_world@bone.head)
    scene.frame_set(previous)
    if not points:return
    low=Vector(tuple(min(p[a] for p in points) for a in range(3)));high=Vector(tuple(max(p[a] for p in points) for a in range(3)))
    center=(low+high)*.5;extent=max(1.0,(high-low).length)
    for window in bpy.context.window_manager.windows:
        if window.scene!=scene:continue
        for area in window.screen.areas:
            if area.type=='VIEW_3D':
                region=area.spaces.active.region_3d
                region.view_location=center;region.view_distance=max(2.5,extent*1.45)
                region.view_rotation=Quaternion((1,0,0),1.33)
                area.tag_redraw()


def mark_take(scene,decision):
    s=state(scene)
    if not s.loaded_key or fingerprint(selection_ids(scene))!=s.loaded_key:raise ValueError('请先加载当前选择，避免标记了另一个动作')
    ids=json.loads(s.loaded_roles);group=FOLDERS[s.loaded_group]
    data=read_decisions()
    key=take_key(s.loaded_key,min(s.trim_start,s.trim_end),max(s.trim_start,s.trim_end))
    data['takes'][key]={'id':key,'source_key':s.loaded_key,'folder_id':group['id'],'source_folder':group['folder'],
        'decision':decision,'roles':[{'slot':role,'file':FILES[key]['file'],'sha256':FILES[key]['sha256']} for role,key in ids],
        'fps':CATALOG['fps'],'frame_start':min(s.trim_start,s.trim_end),'frame_end':max(s.trim_start,s.trim_end),
        'note':s.note,'rough_special_preview':any(FILES[key]['special_ik'] for _,key in ids),
        'reference_models':CONFIG['reference_models'],'updated_at':datetime.datetime.now(datetime.timezone.utc).isoformat()}
    write_decisions(data);refresh_decision_badges(scene)
    s.message='已保存：'+DECISIONS[decision]+'，'+str(s.trim_start)+'–'+str(s.trim_end)+' 帧'


class PR_OT_SourceLoad(bpy.types.Operator):
    bl_idname='pr_mmd_source.load';bl_label='加载预览';bl_description='直接载入 VMD，在参考模型上实时求解，不做正式烘焙'
    def execute(self,context):
        try:load_selected(context)
        except Exception as error:self.report({'ERROR'},str(error));return {'CANCELLED'}
        return {'FINISHED'}


class PR_OT_SourceMark(bpy.types.Operator):
    bl_idname='pr_mmd_source.mark';bl_label='记录选片'
    decision:bpy.props.EnumProperty(items=[('KEEP','保留',''),('MAYBE','待定',''),('SKIP','跳过','')])
    def execute(self,context):
        try:mark_take(context.scene,self.decision)
        except Exception as error:self.report({'ERROR'},str(error));return {'CANCELLED'}
        return {'FINISHED'}


class PR_OT_SourcePlay(bpy.types.Operator):
    bl_idname='pr_mmd_source.play';bl_label='播放 / 暂停'
    def execute(self,context):
        override=_screen_override(context)
        if not override or not state(context.scene).loaded_key:return {'CANCELLED'}
        with bpy.context.temp_override(**override):bpy.ops.screen.animation_play()
        return {'FINISHED'}


class PR_OT_SourceRange(bpy.types.Operator):
    bl_idname='pr_mmd_source.range';bl_label='以当前帧设置片段'
    endpoint:bpy.props.EnumProperty(items=[('START','开始',''),('END','结束',''),('FULL','全段','')])
    def execute(self,context):
        s=state(context.scene);frame=min(max(0,context.scene.frame_current),s.loaded_max_frame)
        if self.endpoint=='FULL':s.trim_start=0;s.trim_end=s.loaded_max_frame
        elif self.endpoint=='START':s.trim_start=frame;s.trim_end=max(frame,s.trim_end)
        else:s.trim_end=frame;s.trim_start=min(frame,s.trim_start)
        return {'FINISHED'}


class PR_OT_SourceFrame(bpy.types.Operator):
    bl_idname='pr_mmd_source.frame';bl_label='适配视图'
    def execute(self,context):frame_view(context);return {'FINISHED'}


class PR_OT_SourceRefresh(bpy.types.Operator):
    bl_idname='pr_mmd_source.refresh';bl_label='刷新目录与记录'
    def execute(self,context):
        try:reload_catalog();populate(context.scene)
        except Exception as error:self.report({'ERROR'},str(error));return {'CANCELLED'}
        return {'FINISHED'}


class PR_OT_SourceRecall(bpy.types.Operator):
    bl_idname='pr_mmd_source.recall';bl_label='打开已记录片段'
    take_id:bpy.props.StringProperty()
    def execute(self,context):
        try:
            record=read_decisions()['takes'][self.take_id];s=state(context.scene)
            s.group_index=next(i for i,item in enumerate(s.groups) if item.key==record['folder_id'])
            by_path={v['file']:k for k,v in FILES.items()}
            for role in ['A','B','C']:setattr(s,'role_'+role.lower(),'NONE')
            for item in record['roles']:setattr(s,'role_'+item['slot'].lower(),by_path[item['file']])
            load_selected(context)
            s.trim_start=record['frame_start'];s.trim_end=record['frame_end'];s.note=record.get('note','')
            context.scene.frame_set(s.trim_start);frame_view(context)
        except Exception as error:self.report({'ERROR'},str(error));return {'CANCELLED'}
        return {'FINISHED'}


def wrapped(layout,text,width=44):
    # Mixed CJK / Latin labels need shorter lines than Blender's raw byte count.
    for line in textwrap.wrap(text,width=width,break_long_words=True):layout.label(text=line)


class PR_PT_SourcePicker(bpy.types.Panel):
    bl_label='MMD 源动作选片';bl_idname='PR_PT_SourcePicker';bl_space_type='VIEW_3D';bl_region_type='UI';bl_category='动作选片'
    @classmethod
    def poll(cls,context):return context.scene.name==SCENE_NAME
    def draw(self,context):
        layout=self.layout;s=state(context.scene);group=group_for(context.scene)
        layout.label(text=str(CATALOG.get('folder_count',0))+' 个目录候选 / '+str(CATALOG.get('body_files',0))+' 条人体轨道')
        layout.prop(s,'search',text='搜索');layout.prop(s,'decision_filter',text='记录筛选')
        layout.template_list('PR_UL_MMDSourceFolders','',s,'groups',s,'group_index',rows=7)
        if group:
            wrapped(layout,group['label'],36)
            if 'variants_or_multiple_clips' in group['flags']:layout.label(text='多条轨道可能是替代版本或不同片段')
            if 'three_role_candidate' in group['flags']:layout.label(text='三人配套候选，请检查第三角色')
            if 'static_third_role_candidate' in group['flags']:layout.label(text='另有固定姿态，需确认是否第三角色')
            if 'requires_prop_preview_omits' in group['flags']:layout.label(text='含道具轨道；本预览不加载道具与支撑物')
            if 'author_external_parent' in group['flags']:layout.label(text='作者有跨角色绑定说明，优先选择普通版')
            for role in ['A','B','C']:layout.prop(s,'role_'+role.lower(),text='角色 '+role)
            ids=selection_ids(context.scene)
            if any(FILES[key]['special_ik'] for _,key in ids):
                layout.label(text='所选轨道含特殊控制器，效果可能不完整')
                layout.prop(s,'allow_special')
            if len({FILES[key]['bone_end'] for _,key in ids})>1:layout.label(text='轨长不同：短轨末姿态保持，不独立伸缩')
        row=layout.row();row.scale_y=1.3;row.operator('pr_mmd_source.load')
        wrapped(layout,s.message,36)
        if s.loaded_key:
            box=layout.box();wrapped(box,'画面当前加载：'+s.loaded_label,34)
            box.label(text='源 0–'+str(s.loaded_max_frame)+' 帧 / 30 FPS')
            box.label(text='直接载入用时 '+format(s.last_load_seconds,'.2f')+' 秒')
            box.operator('pr_mmd_source.play')
            row=box.row(align=True);row.prop(s,'trim_start',text='开始');row.prop(s,'trim_end',text='结束')
            row=box.row(align=True)
            row.operator('pr_mmd_source.range',text='当前帧→开始').endpoint='START'
            row.operator('pr_mmd_source.range',text='当前帧→结束').endpoint='END'
            box.operator('pr_mmd_source.range',text='恢复全段').endpoint='FULL'
            box.prop(s,'note')
            row=box.row(align=True);row.enabled=fingerprint(selection_ids(context.scene))==s.loaded_key
            for key,label in DECISIONS.items():row.operator('pr_mmd_source.mark',text=label).decision=key
            record=read_decisions()['takes'].get(take_key(s.loaded_key,s.trim_start,s.trim_end),{})
            box.label(text='记录：'+DECISIONS.get(record.get('decision'),'尚未标记'))
        if group:
            records=[r for r in read_decisions()['takes'].values() if r.get('folder_id')==group['id']]
            if records:
                box=layout.box();box.label(text='本目录已记录片段（'+str(len(records))+'）')
                for record in sorted(records,key=lambda r:r.get('updated_at',''),reverse=True)[:5]:
                    label=DECISIONS.get(record['decision'],'')+' '+str(record['frame_start'])+'–'+str(record['frame_end'])+' 帧'
                    box.operator('pr_mmd_source.recall',text=label).take_id=record['id']
        row=layout.row(align=True);row.operator('pr_mmd_source.frame');row.operator('pr_mmd_source.refresh')
        layout.separator();layout.label(text='蓝 A / 橙 B / 紫 C；参考体型，衣发物理关闭')
        layout.label(text='只看身体动作；表情、原相机与道具不加载')
        layout.label(text='先选片；入选后再转换与检查最终角色接触')


CLASSES=[PRMMDSourceGroup,PRMMDSourceState,PR_UL_MMDSourceFolders,PR_OT_SourceLoad,PR_OT_SourceMark,PR_OT_SourcePlay,PR_OT_SourceRange,PR_OT_SourceFrame,PR_OT_SourceRefresh,PR_OT_SourceRecall,PR_PT_SourcePicker]


def populate(scene):
    global _UPDATING
    s=state(scene);previous=group_for(scene);key=previous['id'] if previous else None
    choices=selection_ids(scene) if previous else []
    _UPDATING=True;s.groups.clear()
    for group in CATALOG['folders']:
        item=s.groups.add();item.key=group['id'];item.name=group['label']
    s.group_index=next((i for i,g in enumerate(CATALOG['folders']) if g['id']==key),0)
    _UPDATING=False;on_group(s,bpy.context)
    if choices and all(i in FOLDERS[s.groups[s.group_index].key]['files'] for _,i in choices):
        for role in ['A','B','C']:setattr(s,'role_'+role.lower(),'NONE')
        for role,i in choices:setattr(s,'role_'+role.lower(),i)
    refresh_decision_badges(scene)


@persistent
def on_file_load(_):
    if SCENE_NAME in bpy.data.scenes:
        scene=bpy.data.scenes[SCENE_NAME]
        if not state(scene).groups:populate(scene)
        configure_viewports(scene)


def register():
    reload_catalog()
    if hasattr(bpy.types.Scene,'pr_mmd_source'):del bpy.types.Scene.pr_mmd_source
    for cls in CLASSES:
        old=getattr(bpy.types,cls.__name__,None)
        if old:
            try:bpy.utils.unregister_class(old)
            except RuntimeError:pass
        bpy.utils.register_class(cls)
    bpy.types.Scene.pr_mmd_source=bpy.props.PointerProperty(type=PRMMDSourceState)
    for handler in list(bpy.app.handlers.load_post):
        if getattr(handler,'__module__','')==__name__:bpy.app.handlers.load_post.remove(handler)
    bpy.app.handlers.load_post.append(on_file_load)


def configure_viewports(scene):
    for window in bpy.context.window_manager.windows:
        if window.scene!=scene:continue
        for area in window.screen.areas:
            if area.type=='VIEW_3D':
                space=area.spaces.active;space.show_region_ui=True
                shading=space.shading
                for prop,value in [('type','SOLID'),('color_type','OBJECT'),('light','STUDIO')]:
                    if value in {i.identifier for i in shading.bl_rna.properties[prop].enum_items}:setattr(shading,prop,value)
                space.overlay.show_relationship_lines=False
                space.overlay.show_extras=False
                for region in area.regions:
                    if region.type=='UI' and hasattr(region,'active_panel_category'):
                        try:region.active_panel_category='动作选片'
                        except (AttributeError,TypeError):pass
            elif area.type=='DOPESHEET_EDITOR':
                if 'TIMELINE' in {i.identifier for i in area.bl_rna.properties['ui_type'].enum_items}:
                    area.ui_type='TIMELINE'


def ensure_scene():
    if SCENE_NAME in bpy.data.scenes:
        scene=bpy.data.scenes[SCENE_NAME]
    else:
        scene=bpy.data.scenes.new(SCENE_NAME)
        scene.render.fps=30;scene.frame_start=0;scene.frame_end=480
        scene['pr_source_picker']=1
    bpy.context.window.scene=scene
    populate(scene);configure_viewports(scene)
    for role in ['A','B']:
        ensure_role(bpy.context,role)
        for obj in role_objects(scene,role):obj.hide_set(obj.type!='MESH' or (not state(scene).loaded_key and role!='A'))
    frame_view(bpy.context)
    return scene


def save_checkpoint(scene):
    path=Path(CONFIG['preview_blend']);path.parent.mkdir(parents=True,exist_ok=True)
    # Write only this scene and its dependencies; current project path is untouched.
    bpy.data.libraries.write(str(path),{scene},fake_user=True,compress=True)
    return str(path)


if __name__=='__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    register();scene=ensure_scene()
    preview_path=Path(CONFIG['preview_blend']);preview_path.parent.mkdir(parents=True,exist_ok=True)
    if bpy.data.filepath!=str(preview_path):
        bpy.ops.wm.save_as_mainfile(filepath=str(preview_path),compress=True)
    print('PR_MMD_SOURCE_PICKER '+json.dumps({'scene':scene.name,'folders':len(CATALOG['folders']),'body_files':len(FILES),'formal_bakes':0},ensure_ascii=False))
