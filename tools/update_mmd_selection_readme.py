"""Refresh only the marked README summary from user-authored source selections."""
import argparse
from collections import Counter
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
BEGIN='<!-- BEGIN MMD_SELECTION_SUMMARY -->'
END='<!-- END MMD_SELECTION_SUMMARY -->'
LABELS={'KEEP':'保留','MAYBE':'待定','SKIP':'跳过'}


def cell(value):
    return str(value or '').replace('&','&amp;').replace('<','&lt;').replace('>','&gt;').replace('|','&#124;').replace('\r','').replace('\n','<br>')


def summary(data):
    if data.get('schema')!=1 or not isinstance(data.get('takes'),dict):raise ValueError('Unsupported selection schema; README not changed.')
    items=list(data['takes'].values())
    unknown={r.get('decision') for r in items}-set(LABELS)
    if unknown:raise ValueError('Unknown decisions; README not changed: '+repr(unknown))
    counts=Counter(r['decision'] for r in items)
    lines=['从正式 JSON 读取的具体片段：**保留 '+str(counts['KEEP'])+'，待定 '+str(counts['MAYBE'])+'，跳过 '+str(counts['SKIP'])+'**。',
           '同组不同范围分别计数；此处不是目录数，也不是全库通过率。','']
    if not items:
        lines+=['目前没有具体片段登记到正式清单。用户正在预览；以上优先级不代替具体选片，不自动登记任何目录为保留。']
    for decision,label in LABELS.items():
        selected=sorted((r for r in items if r['decision']==decision),key=lambda r:(r.get('source_folder',''),int(r.get('frame_start',0)),r.get('id','')))
        if not selected:continue
        lines += ['### '+label+'片段','','| 来源目录 | 角色源文件 | 源范围 | 备注 | 特殊依赖 |','| --- | --- | --- | --- | --- |']
        for row in selected:
            roles='<br>'.join(cell(role.get('slot','?'))+': '+cell(role.get('file','')) for role in row.get('roles',[]))
            duration=str(row.get('frame_start',0))+'–'+str(row.get('frame_end',0))+' 帧 / '+str(row.get('fps',30))+' FPS'
            warning='粗略特殊骨架，需另审' if row.get('rough_special_preview') else '未标记特殊骨架；仍待制作验收'
            lines.append('| '+cell(row.get('source_folder',''))+' | '+roles+' | '+cell(duration)+' | '+cell(row.get('note',''))+' | '+warning+' |')
        lines.append('')
    return '\n'.join(lines).strip()


def replace_summary(text,data):
    if text.count(BEGIN)!=1 or text.count(END)!=1:raise ValueError('Expected one summary marker pair; README not changed.')
    first=text.index(BEGIN);last=text.index(END)
    if last<first:raise ValueError('Summary markers reversed; README not changed.')
    return text[:first]+BEGIN+'\n\n'+summary(data)+'\n\n'+text[last:]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--selection',type=Path,default=ROOT/'docs/motion_selection/mmd_source_selection.json')
    parser.add_argument('--readme',type=Path,default=ROOT/'docs/motion_selection/README.md')
    args=parser.parse_args()
    data=json.loads(args.selection.read_text(encoding='utf-8'))
    before=args.readme.read_text(encoding='utf-8')
    after=replace_summary(before,data)
    if before!=after:args.readme.write_text(after,encoding='utf-8')
    print(json.dumps({'readme_updated':before!=after,'decisions':dict(Counter(r['decision'] for r in data['takes'].values())),'selection_modified':False}))


if __name__=='__main__':main()
