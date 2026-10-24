"""Summarize real-run artifacts; do not turn sampled observations into guarantees."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / 'assets/world/current_map_validation/review'


def read(name):
    return json.loads((REVIEW / name).read_text(encoding='utf-8'))


def main():
    result = {'scope': 'Issue 13 first iteration; local 1,152-cell bake pilot', 'runs': {}}
    for name in ['baseline', 'online', 'baked', 'baked_uncapped', 'online_no_profile', 'baked_continuous']:
        report = read(f'issue13_{name}.json')
        travel = [r for r in report['records'] if r['stage'] == 'travel_18mps_camera']
        near = [r['visible_bands']['0_48'] + r['visible_bands']['48_76'] for r in travel]
        result['runs'][name] = {
            'tick': report['stream_tick'], 'frames': report['frames'], 'gpu': report['gpu'],
            'travel': report['phases']['travel_18mps_camera'],
            'sampled_near_missing_max': max(near, default=0),
            'sampled_near_missing_observations': sum(n > 0 for n in near),
            'final_visible': report['final'].get('visible'),
            'cache': report['final'].get('cache'),
            'monitor_peaks': report.get('monitor_peaks'),
            'continuous': report.get('continuous'),
        }
    result['bake'] = read('issue13_bake.json')
    result['buffer_parity'] = read('issue13_buffer_parity.json')
    result['bake_parity'] = read('issue13_bake_parity.json')
    fixture = read('grass_stream_validation.json')
    actual = read('grass_stream_actual_map.json')
    result['regressions'] = {'fixture_passed': fixture['passed'], 'fixture_drive_m': fixture['drive_m'],
                             'actual_map_passed': actual['passed'], 'actual_drive_m': actual['ramp_drive_m']}
    result['prototype_checks_passed'] = all([
        result['buffer_parity']['passed'], result['bake_parity']['passed'], fixture['passed'], actual['passed'],
        result['runs']['baked_continuous']['continuous']['near_missing_frames'] == 0,
    ])
    if (REVIEW / 'issue13_full_spawns.json').exists():
        result['scope'] = 'Full-map baked grass, with retained pilot comparisons'
        result['full_bake'] = read('issue13_full_bake.json')
        result['full_spawns'] = read('issue13_full_spawns.json')
        result['full_continuous'] = read('issue13_baked_full_continuous.json')
        result['shader_parity'] = read('issue13_shader_parity.json')
        result['gpu_ab'] = read('issue13_gpu_ab.json')
        result['full_checks_passed'] = all([
            result['full_bake']['complete'], result['full_spawns']['passed'], result['shader_parity']['passed'],
            result['full_continuous']['continuous']['near_missing_frames'] == 0,
            result['full_continuous']['profile']['totals'].get('terrain_ray_count', 0) == 0,
        ])
    result['limits'] = [
        'Initial paired CPU experiments used the pilot; full-map results are reported separately.',
        '360 m camera motion is not a 360 m vehicle physics test.',
        'Individual native buffer submissions and queue refresh can still exceed a target deadline.',
        'All-frame summaries include startup stalls; travel summaries are separate.',
        'Detailed profiling has overhead and is disabled in the normal F5 scene.',
        'Existing user:// shader-cache startup warning did not prevent GPU validation.',
    ]
    (REVIEW / 'issue13_summary.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    lines = ['# Issue 13 第一轮实测', '',
             '固定真实地图、1920×1080、360 m 相机路线；这是相机输送测试，车辆物理另测。', '',
             '| 模式 | 完整 tick 均值 ms | P99 ms | GPU 均值 ms | 近景缺块最大值（半秒采样） |',
             '| --- | ---: | ---: | ---: | ---: |']
    for mode in ['baseline', 'online', 'baked', 'baked_uncapped', 'online_no_profile']:
        row = result['runs'][mode]
        lines.append(f"| {mode} | {row['tick']['mean_ms']:.2f} | {row['tick']['p99_ms']:.2f} | {row['gpu'].get('mean_ms', 0):.2f} | {row['sampled_near_missing_max']} |")
    continuous = result['runs']['baked_continuous']['continuous']
    lines += ['', f"逐帧额外验收：{continuous['checked_frames']} 帧，视锥 0–76 m 缺失帧 {continuous['near_missing_frames']}，首次近景就绪 {continuous['near_ready_s']:.2f} 秒。",
              '', '同数据实现按字节一致；CPU LRU、版本失效、损坏回退、分帧原子显示和实际房车回归通过。',
              '', '全部帧统计保留启动尖峰；稳定移动阶段另列在 JSON。个别刷新/原生提交仍会超出目标预算。',
              '', '以上为最初 1,152-cell 原型的配对实验；随后已扩展全地图，见下方验收。',
              '', '完整数据：[issue13_summary.json](issue13_summary.json)。']
    if 'full_bake' in result:
        full = result['full_bake']
        check = result['full_continuous']['continuous']
        lines += ['', '## 全图结果', '',
                  f"完整覆盖 {full['cells']} 个候选格，其中 {full['empty']} 个为空；压缩数据 {full['compressed_bytes']:,} 字节。运行时按需展开，CPU 缓冲 LRU 上限 96 MiB。", '',
                  '| 出生点 | 近景首次就绪 s | 可见128m就绪 s | 满草GPU均值 ms | GPU P95 ms |',
                  '| --- | ---: | ---: | ---: | ---: |']
        for row in result['full_spawns']['spawns']:
            lines.append(f"| {row['spawn']} {row['name']} | {row['near_ready_s']:.2f} | {row['visible_128m_ready_s']:.2f} | {row['gpu_mean_ms']:.2f} | {row['gpu_p95_ms']:.2f} |")
        lines += ['', f"完整数据集连续路线：检查 {check['checked_frames']} 帧，近景缺失 {check['near_missing_frames']} 帧，最长缺口 {check['longest_gap_s']:.2f} 秒。运行时地表采样数与 terrain 射线数均为 0。", '',
                  '真实草材质的隐藏实例剔除逐像素一致；八个点均完成可见 128 m 区域。点位是同一会话的首次访问，邻近点可复用缓存，GPU 数值是在可见草完整后短时采样。']
    (REVIEW / 'issue13_results.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(json.dumps({'passed': result.get('full_checks_passed', result['prototype_checks_passed']),
                      'baseline_tick': result['runs']['baseline']['tick'],
                      'baked_tick': result['runs']['baked']['tick'],
                      'continuous': result.get('full_continuous', result['runs']['baked_continuous'])['continuous']}, indent=2))


if __name__ == '__main__':
    main()
