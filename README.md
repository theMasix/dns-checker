# DNS Benchmark Tool

Tests multiple domains against multiple DNS servers, ranks them by speed and reliability, and saves a full report.

## Requirements

- `dig` (part of `bind-utils` / `dnsutils`)
- `bc` (for score calculation)

```bash
# macOS
brew install bind

# Debian/Ubuntu
apt-get install dnsutils bc
```

## Usage

```bash
chmod +x dns_benchmark.sh
./dns_benchmark.sh -d domains.txt -s dns_servers.txt
```

### Options

| Flag                  | Default    | Description                              |
| --------------------- | ---------- | ---------------------------------------- |
| `-d`, `--domains`     | required   | File with domains to test (one per line) |
| `-s`, `--servers`     | required   | File with DNS server IPs (one per line)  |
| `-t`, `--timeout`     | `2`        | Query timeout in seconds                 |
| `-i`, `--iterations`  | `2`        | Test iterations per domain per server    |
| `-c`, `--concurrency` | `10`       | Max parallel DNS server tests            |
| `-o`, `--output`      | auto-named | Output report file path                  |

### Example

```bash
./dns_benchmark.sh -d domains.txt -s dns_servers.txt -i 3 -t 5 -c 20
```

## Input Files

`domains.txt` — one domain per line:

```
digikala.com
app.snapp.taxi
```

`dns_servers.txt` — one DNS server IP per line:

```
8.8.8.8
1.1.1.1
87.107.110.109
```

Blank lines and `#` comments are ignored in both files.

## Output

Report saved to `dns_benchmark_report_YYYYMMDD_HHMMSS.txt`.

### Report Sections

1. **DNS Server Rankings** — all servers ranked by score (`success_rate × 1000 / avg_ms`), with success rate, avg/min/max response times
2. **Detailed Results by Domain** — per-domain table showing each server's status, resolved IP, and query time
3. **Performance Summary** — top-ranked server's key stats
4. **Recommendation** — best DNS server with suggested network config

---

## Sample Report

```
    ██████╗  █████╗ ████████╗ █████╗
    ██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗
    ██║  ██║███████║   ██║   ███████║
    ██║  ██║██╔══██║   ██║   ██╔══██║
    ██████╔╝██║  ██║   ██║   ██║  ██║
    ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝

    DNS Benchmark Tool v1.0

═══════════════════════════════════════════════════════════════════════════════
                           BENCHMARK REPORT
═══════════════════════════════════════════════════════════════════════════════

Generated: 2026-05-04 13:55:31
Domains tested: 10
DNS servers tested: 36
Iterations per domain: 2
Timeout per query: 2s
Concurrency: 10

───────────────────────────────────────────────────────────────────────────────
                           DNS SERVER RANKINGS
───────────────────────────────────────────────────────────────────────────────

DNS Server           Success Rate   Avg (ms)   Min (ms)   Max (ms)      Score
──────────           ────────────   ────────   ────────   ────────      ─────
87.107.110.109              100%         32         18        111    3125.00
217.218.155.155              60%         25         21         37    2400.00
217.218.127.127              60%         25         22         37    2400.00
78.157.42.101                65%         29         22         49    2241.20
5.202.100.101                45%         26         21         39    1730.70
5.202.100.100                40%         38         28         57    1052.40
194.225.152.10               85%         85         20        381     999.60
...

───────────────────────────────────────────────────────────────────────────────
                          DETAILED RESULTS BY DOMAIN
───────────────────────────────────────────────────────────────────────────────

Domain: digikala.com
DNS Server             Status         IP Address      Query Time
──────────             ──────         ──────────      ──────────
87.107.110.109           OK      185.188.104.10          22 ms
217.218.155.155          OK      185.188.104.10          22 ms
217.218.127.127          OK      185.188.104.10          23 ms
78.157.42.100            OK      185.188.104.10          25 ms
193.186.32.32            OK      185.188.104.10          39 ms
178.22.122.100         FAIL                 N/A            N/A
...

───────────────────────────────────────────────────────────────────────────────
                            PERFORMANCE SUMMARY
───────────────────────────────────────────────────────────────────────────────

Best DNS Server: 87.107.110.109
Average Response Time: 32 ms
Success Rate: 100%

───────────────────────────────────────────────────────────────────────────────
                              RECOMMENDATION
───────────────────────────────────────────────────────────────────────────────

Based on this benchmark, 87.107.110.109 is recommended for:
  - Fastest average response time: 32ms
  - Highest reliability: 100% success rate

To use this DNS server, add the following to your network settings:
  Primary DNS:   87.107.110.109

═══════════════════════════════════════════════════════════════════════════════
                            END OF REPORT
═══════════════════════════════════════════════════════════════════════════════
```
