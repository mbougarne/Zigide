#!/usr/bin/env python3
"""Summarize raw observations using nearest-rank p95; standard library only."""
import csv
import math
import statistics
import sys
from collections import defaultdict


def summarize(path):
    groups = defaultdict(list)
    with open(path, newline="", encoding="utf-8") as source:
        for row in csv.DictReader(source):
            groups[(row["fixture"], row["bytes"], row["model"], row["operation"])].append(row)
    writer = csv.writer(sys.stdout, lineterminator="\n")
    writer.writerow(("fixture", "bytes", "model", "operation", "samples", "median_ns", "p95_ns", "max_ns", "final_requested_bytes", "peak_requested_bytes"))
    for key, rows in groups.items():
        times = sorted(int(row["ns"]) for row in rows)
        writer.writerow((*key, len(rows), statistics.median(times), times[math.ceil(len(times) * .95) - 1], times[-1], rows[-1]["current_requested_bytes"], max(int(row["peak_requested_bytes"]) for row in rows)))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: summarize_text_benchmark.py raw.csv")
    summarize(sys.argv[1])
