#!/usr/bin/env python3
"""Record host counters once per second; summarize only the k6 time window."""
import json
import re
import sys
import time
from pathlib import Path


def snapshot():
    cpu = list(map(int, Path('/proc/stat').read_text().splitlines()[0].split()[1:9]))
    memory = {}
    for line in Path('/proc/meminfo').read_text().splitlines():
        key, value, *_ = line.split()
        memory[key.rstrip(':')] = int(value)
    disks = {}
    for line in Path('/proc/diskstats').read_text().splitlines():
        fields = line.split()
        name = fields[2]
        device = Path('/sys/block') / name
        if device.exists() and not name.startswith(('loop', 'ram', 'dm-', 'md')):
            disks[name] = [int(fields[5]), int(fields[9])]
    return time.time(), cpu, memory, disks


if sys.argv[1] == 'collect':
    previous = snapshot()
    while True:
        time.sleep(1)
        current = snapshot()
        start, old_cpu, _, old_disks = previous
        end, cpu, memory, disks = current
        delta = [b - a for a, b in zip(old_cpu, cpu)]
        total = sum(delta)
        if total <= 0:
            previous = current
            continue
        available_ticks = total - delta[7]
        busy_ticks = total - delta[3] - delta[4] - delta[7]
        record = {'start': start, 'end': end,
                  'cpu_busy_pct': 100 * busy_ticks / available_ticks if available_ticks > 0 else 0,
                  'cpu_iowait_pct': 100 * delta[4] / total,
                  'cpu_steal_pct': 100 * delta[7] / total,
                  'memory_available_mib': memory['MemAvailable'] / 1024,
                  'disks': {}}
        for name, values in disks.items():
            if name in old_disks:
                record['disks'][name] = {
                    'read_kib_s': (values[0] - old_disks[name][0]) / 2 / (end - start),
                    'write_kib_s': (values[1] - old_disks[name][1]) / 2 / (end - start)}
        print(json.dumps(record), flush=True)
        previous = current
else:
    log = Path(sys.argv[2]).read_text()
    starts = re.findall(r'RESOURCE_START=(\d+)', log)
    ends = re.findall(r'RESOURCE_END=(\d+)', log)
    if not starts or not ends:
        print('resource_summary: 計測区間を確定できません。元ログを確認してください。')
        sys.exit(0)
    start, end = int(starts[0]) / 1000, int(ends[-1]) / 1000
    rows = [json.loads(line) for line in Path(sys.argv[3]).read_text().splitlines()]
    rows = [r for r in rows if r['start'] >= start and r['end'] <= end]
    if not rows:
        print('resource_summary: 負荷実行区間のサンプルがありません。')
        sys.exit(0)
    def avg(key):
        return sum(r[key] * (r['end'] - r['start']) for r in rows) / sum(r['end'] - r['start'] for r in rows)
    print(f'resource_summary: 負荷中（終了待ちを含む） {len(rows)}サンプル | '
          f'CPU使用 平均={avg("cpu_busy_pct"):.1f}% 最大={max(r["cpu_busy_pct"] for r in rows):.1f}% | '
          f'I/O待ち平均={avg("cpu_iowait_pct"):.1f}% 仮想CPU待ち平均={avg("cpu_steal_pct"):.1f}% | '
          f'メモリ利用可能 平均={avg("memory_available_mib"):.0f} MiB 最小={min(r["memory_available_mib"] for r in rows):.0f} MiB')
    for device in sorted(set.intersection(*(set(r['disks']) for r in rows))):
        values = {key: sum(r['disks'][device][key] * (r['end'] - r['start']) for r in rows) / sum(r['end'] - r['start'] for r in rows)
                  for key in ('read_kib_s', 'write_kib_s')}
        print(f'resource_summary: ディスク {device} 平均 読込={values["read_kib_s"]:.1f} KiB/s 書込={values["write_kib_s"]:.1f} KiB/s')
