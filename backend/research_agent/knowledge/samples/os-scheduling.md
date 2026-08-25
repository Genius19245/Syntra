---
source: SYNTRA seed notes
authority: educational_sample
source_tier: 2
topic: operating system scheduling algorithms
subject: computer science
education_level: undergraduate
exam_board:
publication_date: "2024-01-01"
last_checked: "2026-08-22"
content_type: textbook
url: https://syntra.local/knowledge/os-scheduling
title: Operating system scheduling algorithms
---

CPU scheduling decides which ready process runs on the processor.

Undergraduate classroom algorithms:
- First-Come, First-Served (FCFS): non-preemptive; simple; convoy effect.
- Shortest Job First (SJF) / Shortest Remaining Time First: minimises average waiting time if burst lengths are known.
- Round Robin: time slice (quantum); preemptive; good for interactive systems.
- Priority scheduling: may be preemptive or not; can starve low-priority processes unless ageing is used.

Key metrics: waiting time, turnaround time, response time, throughput,
and CPU utilisation.

This material is university operating-systems depth. It is not a GCSE
computing topic and should not be substituted with GCSE-level descriptions
of "what an operating system is".
