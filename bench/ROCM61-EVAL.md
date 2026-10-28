# ROCM61-EVAL.md — ROCm 6.1 对照评测（gfx906 最快档实测）

**日期**：2026-10-29 · **平台**：Radeon Pro VII 16GB HBM2（gfx906）· i5-4590 4C4T · 16GB DDR3 · Ubuntu 26.04

评测容器：`ubuntu:22.04-core`（canonical rootfs `docker import` 生成，绕开国内镜像墙）+ **ROCm 6.1.2**（官方 repo.radeon.com 直连源 + APT pin 1001 压过 jammy 自带 rocminfo 5.0）。

## 动机

[Level1Techs 论坛](https://forum.level1techs.com/t/glm-and-i-created-a-llama-cpp-fork-optimized-for-amd-gfx906-mi50-mi60-radeon-vii-gcn-hip/254257) 大量实测声称 **6.1 是 gfx906 最快档**，且社区有 mi50 专用的 llama.cpp fork（`gfx906-llama-cpp`）。本评测验证两件事：ROCm 6.1 是否真快于 5.7.1，以及该 fork 是否值得采用。

## 对照矩阵（Qwen3.8-27B Q3_K_S，ngl 99，t 4，`llama-bench -p 512 -n 128`）

| 环境 | pp512 t/s | tg128 t/s | 真对话 t/s |
|---|---|---|---|
| 5.7.1 master（基线，引用） | — | 24.90 | 24.7 |
| **6.1 master** | 236.57 | **25.39** | 24.31 |
| 6.1 fork（gfx906-llama-cpp） | 190.10 | 17.02 | 16.69 |
| 6.1 master + `-ctk q8_0 -ctv q8_0` | 235.01 | 24.85 | — |
| 6.1 fork + q8_0 KV | 190.03 | 16.92 | — |
| 6.1 master + MTP n=2（`--spec-draft-n-max 2`） | — | — | **28.42** |
| 6.1 master + MTP 默认 n=3 | — | — | 20.26 |
| 6.1 fork + MTP n=2 | — | — | 17.86 |

## 结论

1. **ROCm 6.1 升级成立**：tg128 24.90 → 25.39（+2%），pp512 236.57 显著领先。milp「6.1 是 gfx906 最快档」在本机如实复现。
2. **fork 判负，勿采用**：tg128 17.02，比 6.1 master 慢 **33%**。根因：**fork 基于 ggml 0.25.1 旧基线，master 已 0.28.0**——上游三个 minor 版本的累积优化远超 fork 的 gfx906 特化补丁。其宣称卖点逐项实测无收益：mmq-config-vega tile（pp 仍差 20%）、fattn q8_0-native / mixed F16-K/q8_0-V（`-fa on` 17.08 无差、KV 量化 16.92 无差）。
3. **MTP 机制保留，必须显式锁 n=2**：真对话 28.42 = **+17%**（无 MTP 24.31），与 5.7.1 时代「n-max=2 28.1」一致；**默认 n=3 有害**（20.26，-17%）。注意新版 llama-server 参数已改名：`--model-draft <mtp.gguf> --spec-draft-n-max 2`（`-md-n` / `-mtp` 已废弃，会报 invalid argument）。
4. **KV 量化 q8_0 无杠杆**：master 25.39→24.85、fork 17.02→16.92，维持 f16。

## 复现

6.1 编译 flag（两树同参，`CMAKE_HIP_COMPILER=/opt/rocm-6.1.2/llvm/bin/clang++`，C/CXX=系统 gcc/g++）：

```bash
cmake -DGGML_HIP=ON -DAMDGPU_TARGETS=gfx906 -DGPU_TARGETS=gfx906 \
  -DGGML_HIP_GRAPHS=ON -DGGML_HIP_NO_VMM=ON \
  -DGGML_CUDA_FORCE_MMQ=ON -DGGML_CUDA_FA_ALL_QUANTS=ON \
  -DGGML_LTO=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_SERVER=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_HIP_COMPILER=/opt/rocm-6.1.2/llvm/bin/clang++
```

- 运行时：`LD_LIBRARY_PATH=/opt/rocm-6.1.2/lib:<build>/bin`
- 等 llama-server 就绪：轮询 `/health` 直到 `"ok"`（模型加载 20–45s），固定 sleep 一次请求会吃 503
- ROCm apt：官方 repo.radeon.com 直连 2.7s 快于代理 11s，无需代理；清华无 rocm 路径