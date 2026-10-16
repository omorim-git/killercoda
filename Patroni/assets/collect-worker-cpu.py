#!/usr/bin/env python3
"""Summarize node01 /proc/stat samples in a benchmark window and write an SVG."""
import re
import sys
from pathlib import Path


def samples_from(path):
    result = []
    timestamp = None
    for line in Path(path).read_text(errors="replace").splitlines():
        if line.startswith("TIME "):
            try:
                timestamp = float(line.split()[1])
            except (ValueError, IndexError):
                timestamp = None
        elif timestamp is not None:
            fields = line.split()
            if fields and fields[0] == "cpu":
                try:
                    result.append((timestamp, list(map(int, fields[1:9]))))
                except ValueError:
                    pass
    return result


def write_svg(rows, path, hostname):
    width, height = 960, 460
    left, right, top, bottom = 72, 24, 58, 76
    plot_width, plot_height = width - left - right, height - top - bottom
    x = lambda i: left + plot_width * i / max(1, len(rows) - 1)
    y = lambda v: top + plot_height * (1 - max(0, min(100, v)) / 100)
    series = [("busy", "CPU total", "#1769aa"), ("user", "User", "#d97706"),
              ("system", "System", "#16804a"), ("irq", "IRQ", "#a23b72"),
              ("softirq", "SoftIRQ", "#795548")]
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="#fff"/>',
        '<style>text{font-family:Arial,sans-serif;fill:#263238}.grid{stroke:#d9e0e5;stroke-width:1}.axis{stroke:#59666f;stroke-width:1.5}</style>',
        f'<text x="72" y="28" font-size="19" font-weight="bold">{hostname} CPU utilization during load</text>',
        '<text x="72" y="46" font-size="12">All logical CPUs; busy, user, system, IRQ and SoftIRQ</text>',
    ]
    for level in range(0, 101, 20):
        yy = y(level)
        parts.append(f'<line class="grid" x1="{left}" y1="{yy:.1f}" x2="{width-right}" y2="{yy:.1f}"/>')
        parts.append(f'<text x="{left-12}" y="{yy+4:.1f}" font-size="12" text-anchor="end">{level}%</text>')
    parts.extend([
        f'<line class="axis" x1="{left}" y1="{top}" x2="{left}" y2="{height-bottom}"/>',
        f'<line class="axis" x1="{left}" y1="{height-bottom}" x2="{width-right}" y2="{height-bottom}"/>',
        f'<text x="{left + plot_width/2:.1f}" y="{height-14}" font-size="13" text-anchor="middle">Elapsed time (seconds)</text>',
    ])
    stride = max(1, len(rows) // 5)
    for i in list(range(0, len(rows), stride)) + ([len(rows)-1] if len(rows) > 1 and (len(rows)-1) % stride else []):
        parts.append(f'<text x="{x(i):.1f}" y="{height-bottom+20}" font-size="11" text-anchor="middle">{rows[i]["elapsed"]:.0f}</text>')
    for offset, (key, label, color) in enumerate(series):
        points = " ".join(f'{x(i):.1f},{y(row[key]):.1f}' for i, row in enumerate(rows))
        parts.append(f'<polyline fill="none" stroke="{color}" stroke-width="2.5" points="{points}"/>')
        lx, ly = left + (offset % 3) * 180, height - 38 + (offset // 3) * 18
        parts.append(f'<line x1="{lx}" y1="{ly}" x2="{lx+24}" y2="{ly}" stroke="{color}" stroke-width="3"/>')
        parts.append(f'<text x="{lx+31}" y="{ly+4}" font-size="12">{label}</text>')
    parts.append("</svg>")
    Path(path).write_text("\n".join(parts), encoding="utf-8")


sample_path, benchmark_path, graph_path, expected_host = sys.argv[1:5]
sample_text = Path(sample_path).read_text(errors="replace")
hostnames = re.findall(r"^HOSTNAME (.+)$", sample_text, re.MULTILINE)
if not hostnames:
    sys.exit("No remote HOSTNAME marker in worker CPU log")
if any(host != expected_host for host in hostnames):
    sys.exit(f"SSH target mismatch: expected {expected_host}, observed {', '.join(sorted(set(hostnames)))}")
benchmark = Path(benchmark_path).read_text(errors="replace")
starts = re.findall(r"RESOURCE_START=(\d+)", benchmark)
ends = re.findall(r"RESOURCE_END=(\d+)", benchmark)
if not starts or not ends:
    sys.exit("No RESOURCE_START/RESOURCE_END markers in benchmark log")
start, end = int(starts[0]) / 1000, int(ends[-1]) / 1000
samples = [(ts, ticks) for ts, ticks in samples_from(sample_path) if start - 2 <= ts <= end + 2]
rows = []
for (old_ts, old), (ts, current) in zip(samples, samples[1:]):
    delta = [b - a for a, b in zip(old, current)]
    total = sum(delta)
    if total <= 0 or ts < start or old_ts > end:
        continue
    interval = max(0.001, ts - old_ts)
    available = max(1, total - delta[7])
    rows.append({
        "elapsed": ts - start,
        "busy": 100 * (total - delta[3] - delta[4] - delta[7]) / available,
        "user": 100 * (delta[0] + delta[1]) / total,
        "system": 100 * delta[2] / total,
        "irq": 100 * delta[5] / total,
        "softirq": 100 * delta[6] / total,
        "interval": interval,
    })
if not rows:
    sys.exit("No node01 CPU samples overlap the benchmark window")
write_svg(rows, graph_path, expected_host)
weight = sum(row["interval"] for row in rows)
for key, name in (("busy", "CPU total"), ("user", "user"), ("system", "system"), ("irq", "irq"), ("softirq", "softirq")):
    mean = sum(row[key] * row["interval"] for row in rows) / weight
    print(f"node01 resource_summary: {name} average={mean:.1f}% max={max(row[key] for row in rows):.1f}%")
print(f"worker resource_summary: host={expected_host} samples={len(rows)} graph={graph_path}")
