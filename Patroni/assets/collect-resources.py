#!/usr/bin/env python3
"""Record host counters once per second; summarize only the k6 time window."""
import json
import re
import sys
import time
import os
from pathlib import Path

CPU_TICKS_PER_SECOND = os.sysconf('SC_CLK_TCK')


def snapshot():
    cpu = {}
    for line in Path('/proc/stat').read_text().splitlines():
        fields = line.split()
        if fields[0] == 'cpu' or re.fullmatch(r'cpu\d+', fields[0]):
            cpu[fields[0]] = list(map(int, fields[1:9]))
        elif cpu:
            break
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
    processes = {}
    for entry in Path('/proc').iterdir():
        if not entry.name.isdigit():
            continue
        try:
            stat = (entry / 'stat').read_text()
            command = stat[stat.find('(') + 1:stat.rfind(')')]
            rest = stat[stat.rfind(')') + 2:].split()
            # The remaining fields start at proc stat field 3; utime/stime are 14/15.
            ticks = int(rest[11]) + int(rest[12])
            processes[entry.name] = (command, ticks)
        except (OSError, ValueError, IndexError):
            continue
    return time.time(), cpu, memory, disks, processes


if sys.argv[1] == 'collect':
    previous = snapshot()
    while True:
        time.sleep(1)
        current = snapshot()
        start, old_cpu, _, old_disks, old_processes = previous
        end, cpu, memory, disks, processes = current
        delta = [b - a for a, b in zip(old_cpu['cpu'], cpu['cpu'])]
        total = sum(delta)
        if total <= 0:
            previous = current
            continue
        available_ticks = total - delta[7]
        busy_ticks = total - delta[3] - delta[4] - delta[7]
        per_cpu = {}
        for name, values in cpu.items():
            if name == 'cpu' or name not in old_cpu:
                continue
            core_delta = [b - a for a, b in zip(old_cpu[name], values)]
            core_total = sum(core_delta)
            core_available = core_total - core_delta[7]
            core_busy = core_total - core_delta[3] - core_delta[4] - core_delta[7]
            per_cpu[name] = 100 * core_busy / core_available if core_available > 0 else 0
        elapsed = end - start
        process_cpu = []
        for pid, (command, ticks) in processes.items():
            old = old_processes.get(pid)
            if old and old[0] == command:
                used_ticks = ticks - old[1]
                if used_ticks > 0:
                    process_cpu.append({
                        'pid': int(pid), 'command': command,
                        'cpu_pct_one_core': 100 * used_ticks / CPU_TICKS_PER_SECOND / elapsed})
        process_cpu.sort(key=lambda item: item['cpu_pct_one_core'], reverse=True)
        record = {'start': start, 'end': end,
                  'cpu_busy_pct': 100 * busy_ticks / available_ticks if available_ticks > 0 else 0,
                  'cpu_per_core_pct': per_cpu,
                  'top_processes': process_cpu[:5],
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
    core_names = sorted(set.intersection(*(set(r['cpu_per_core_pct']) for r in rows)),
                        key=lambda name: int(name[3:]))
    if core_names:
        core_summary = []
        for name in core_names:
            core_avg = sum(r['cpu_per_core_pct'][name] for r in rows) / len(rows)
            core_max = max(r['cpu_per_core_pct'][name] for r in rows)
            core_summary.append(f'{name} 平均={core_avg:.1f}% 最大={core_max:.1f}%')
        print('resource_summary: CPU各コア ' + ' / '.join(core_summary))
    process_totals = {}
    for row in rows:
        for process in row['top_processes']:
            key = (process['pid'], process['command'])
            process_totals[key] = process_totals.get(key, 0) + process['cpu_pct_one_core']
    top_processes = sorted(process_totals.items(), key=lambda item: item[1], reverse=True)[:5]
    if top_processes:
        summary = ' / '.join(f'{name}[pid={pid}] 区間平均={value / len(rows):.1f}% of 1 CPU'
                             for (pid, name), value in top_processes)
        print('resource_summary: CPU使用上位プロセス ' + summary)
    for device in sorted(set.intersection(*(set(r['disks']) for r in rows))):
        values = {key: sum(r['disks'][device][key] * (r['end'] - r['start']) for r in rows) / sum(r['end'] - r['start'] for r in rows)
                  for key in ('read_kib_s', 'write_kib_s')}
        print(f'resource_summary: ディスク {device} 平均 読込={values["read_kib_s"]:.1f} KiB/s 書込={values["write_kib_s"]:.1f} KiB/s')
