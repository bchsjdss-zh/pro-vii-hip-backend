# BENCH.md — HIP vs Vulkan 实测

全部数据在 **Radeon Pro VII 16GB HBM2（Vega20 / gfx906）· i5-4590 4C4T · 16GB DDR3 · Ubuntu 26.04** 本机实测，2026-10-26~28。

- 生图基线 = 官方 sd.cpp Vulkan 预编译包；HIP = 本仓库脚本自编译（ROCm 5.7.1，four-layer patch 链）
- LLM 基线 = 官方 llama.cpp Vulkan 预编译包（b11900）；HIP = 容器自编译 master 快照
- **口径统一：`快 X%` = (Vulkan ÷ HIP − 1)，正值一律表示 HIP 更快**，全部行同向可比
- `sd-cli` 用时不含 VAE 解码（纯采样）；LLM 用 `llama-bench` 口径，另有真实对话口径注明

## 图像生成（stable-diffusion.cpp，Anima 2B bf16）

| 分辨率 | HIP | Vulkan | HIP 提速 |
|---|---:|---:|---:|
| 1024² · 6 步 | 21.04 s | 20.53 s | ≈持平 |
| 1448² · 6 步 | 31.71 s | 49.98 s | **快 58%** |
| 2048² · 6 步 | 77.87 s | 128.7 s | **快 65%** |

**结论**：HIP 收益随画幅上升才显现——小画布（1024² 级）两后端同速，1448² 起快 58% 以上。低分辨率小图不要指望换后端提速；大图批量明显受益。

## 图像生成（Qwen-Image 2.1 Turbo，AD-Q4_K · 8 步）

| 口径 | HIP | Vulkan | HIP 提速 |
|---|---:|---:|---:|
| 端到端（含 VAE 解码） | 61.5 s | 78 s | **快 27%** |

## LLM 推理（llama.cpp，Qwen3.8-27B Q3_K_S 12.2GiB 全驻）

| 口径 | HIP | Vulkan | HIP 提速 |
|---|---:|---:|---:|
| tg128（llama-bench） | 24.90 t/s | 12.65 t/s | **快 97%** |
| 真实对话（不含 bench 1.7× 折扣） | 24.7 t/s | 7.4 t/s | **快 234%** |
| pp512 | 213 t/s | 190 t/s | 快 12% |

- 加 MTP 推测解码（`--spec-type draft-mtp --spec-draft-n-max 2`，`mtp-Qwen3.8-27B-Q4_0.gguf` 1.37G）：HIP 真实对话从 24.7 提到 **30±1 t/s**（快 23%）。n-max=2 是峰值，3/4/5 反而掉到 22–27。
- HIP 是这张卡 LLM 推理的正解；订制 GEMV kernel（社区 MI50 线实测 28.79 t/s）还能再快 16%，属后续研究。

## 值得注意的观测

- 带宽口径：tg128 24.90 t/s × 11.77GB ≈ 293 GB/s 有效（标称 1024 GB/s 的 ~29%）；Vulkan 同模型仅约 149 GB/s。瓶颈在码本解量化算子，不是 HBM2 带宽。
- 换后端零迁移：sd.cpp/llama.cpp 都吃 GGUF，模型文件直接复用，只换快慢。

## ROCm 6.1 升级（2026-10-29 对照评测）

完整矩阵、编译 flag 与 MTP 参数坑见 **[`ROCM61-EVAL.md`](./ROCM61-EVAL.md)**（本目录）。要点：

- tg128 24.90 → **25.39**（6.1 master vs 5.7.1 master，+2%）；pp512 236.57
- 社区 mi50 fork（gfx906-llama-cpp）**判负**：17.02 t/s（-33%），根因旧基线 ggml 0.25.1
- MTP 推测解码（`--model-draft … --spec-draft-n-max 2`）：真对话 **28.42 t/s（+17%）**；默认 n=3 反而 -17%，必须显式锁 2