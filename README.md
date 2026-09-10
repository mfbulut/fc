# File Compressor

A simple file compressor

> [!WARNING]
> Do not run on untrusted input. The author assume no responsibility for any data loss or corruption.

## Overview

Algorithm: BWT + Adaptive Context-Mixing Range Coder

```bash
# Usage:
fc.exe file_to_compress
fc.exe file_to_decompress.fc
```

Compilile into a self-extracting executable:

```bash
odin run . -define:SFX=shakespeare.txt
```

## Self-Extracting Comparison (`shakespeare.txt`)

| Archive / SFX | Size (bytes)  |
| ------------- | ------------- |
| `fc SFX`      | 1,362,944     |
| `WinRAR SFX`  | 2,160,111     |
| `Original`    | 5,436,475     |

## Benchmark Results on enwik8 (100 MB)

| Algorithm / Level   | Compressed Size (bytes) | Compression Time (s) | Decompression Time (s) |
| ------------------- | ----------------------- | -------------------- | ---------------------- |
| `fc (ours)`         |              20,789,655 |             20.192 s |               15.089 s |
| `xz / LZMA2 (-9)`   |              24,865,244 |             79.018 s |                1.067 s |
| `xz / LZMA2 (-6)`   |              26,375,764 |             55.579 s |                1.140 s |
| `zstd (-19)`        |              26,936,936 |             53.059 s |                0.148 s |
| `brotli (-q11)`     |              27,045,057 |            172.364 s |                0.243 s |
| `bzip2 (-9)`        |              29,008,758 |              5.415 s |                2.489 s |
| `zstd (-15)`        |              29,430,901 |             23.089 s |                0.135 s |
| `brotli (-q9)`      |              29,473,899 |             10.515 s |                0.238 s |
| `brotli (-q5)`      |              31,792,290 |              1.852 s |                0.243 s |
| `zstd (-7)`         |              31,981,436 |              1.518 s |                0.140 s |
| `bzip2 (-1)`        |              33,259,568 |              5.488 s |                2.178 s |
| `xz / LZMA2 (-1)`   |              33,276,380 |              4.921 s |                1.366 s |
| `zstd (-3)`         |              35,419,425 |              0.580 s |                0.138 s |
| `zlib (Deflate -9)` |              36,493,234 |              3.005 s |                0.181 s |
| `gzip (-9)`         |              36,493,246 |              3.133 s |                0.192 s |
| `zlib (Deflate -6)` |              36,877,083 |              1.481 s |                0.193 s |
| `gzip (-6)`         |              36,877,095 |              1.587 s |                0.199 s |
| `brotli (-q1)`      |              39,123,256 |              0.451 s |                0.330 s |
| `zstd (-1)`         |              40,662,735 |              0.350 s |                0.115 s |
| `lz4 (HC -12)`      |              41,927,831 |              5.316 s |                0.059 s |
| `zlib (Deflate -1)` |              52,705,901 |              0.459 s |                0.222 s |
| `gzip (-1)`         |              52,705,913 |              0.487 s |                0.235 s |
| `lz4 (default)`     |              57,277,262 |              0.214 s |                0.057 s |

## Resources

- [Large Text Compression Benchmark (LTCB)](https://mattmahoney.net/dc/text.html)
- [Data Compression Explained](https://mattmahoney.net/dc/dce.html)
- [Understanding the New Entropy Coder Family: Asymmetric Numeral Systems](https://kedartatwawadi.github.io/post--ANS/)
- [Burrows–Wheeler Transform (Wikipedia)](https://en.wikipedia.org/wiki/Burrows%E2%80%93Wheeler_transform)
- [Suffix Array Construction (CP-Algorithms)](https://cp-algorithms.com/string/suffix-array.html)
- [3Blue1Brown: "But what is cross-entropy? | Compression is Intelligence Part 2"](https://www.youtube.com/watch?v=GlYgs6v2YfU)
- [libsais (GitHub)](https://github.com/IlyaGrebnov/libsais)
- [bzip3 (GitHub)](https://github.com/iczelia/bzip3)
