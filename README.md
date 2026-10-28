<div align="center">

# pro-vii-hip-backend

**Radeon Pro VII (gfx906) 自编译 HIP 后端构建链** · Self-built HIP backend build chain for Radeon Pro VII

编译脚本 / 补丁链 / 日志归档 — scripts, patch notes, build logs

</div>

---

## 这是什么 / What this is

在 **ROCm 5.7.1** 上为 **gfx906**（Radeon VII / Pro VII / MI50 / MI60）自编译了两套 HIP 后端的完整构建链：

- **stable-diffusion.cpp**（`-DGGML_HIP=ON -DAMDGPU_TARGETS=gfx906`），生图走 HIP 而非官方预编译包的 Vulkan
- **llama.cpp**（HIP 版 `llama-bench` / `llama-cli` / `llama-server`），LLM 推理大幅提速（见下方性能表）

**为什么需要自编译 / Why self-compile**：ROCm **6.4 起 gfx906 被移出官方支持矩阵**；官方预编译包只带 Vulkan 后端，而这张卡的 HIP 后端只有自编译一条路。本仓库归档了我们实测跑通的全部脚本、补丁链与日志，国内老卡（gfx906 系）用户可直接复用。

**ROCm 版本选型（实测）**：已先后在 **5.7.1 与 6.1.2** 上编译跑通。**6.1 是全系最快档**——tg128 25.39 t/s（5.7.1 为 24.90，+2%），prefill 236 t/s 显著领先；安装用官方 repo.radeon.com 直连源 + APT pin（见 `bench/ROCM61-EVAL.md`）。社区 mi50 定制 fork（gfx906-llama-cpp）经对照评测**判负**：慢 33%，根因是旧基线（ggml 0.25.1 vs master 0.28.0）。

*环境实测：Ubuntu 26.04 · i5-4590 · Radeon Pro VII 16GB HBM2（Vega20 / gfx906）*

---

## 目录结构 / Layout

```
scripts/   编译全流程编排脚本（取源→解包→configure→编译→等待）
logs/      build-hip / build-hip2 / build-hip3 三轮 configure 与编译日志
configs/   三套 build 目录的 CMakeCache 关键 flag 提取 + 源码包 sha256 + rocm61 flag
patches/   编译补丁链说明（PATCHES.md，四层修复 + 判别顺序）
bench/     性能实测数据（HIP vs Vulkan）+ ROCm 6.1 对照评测 + MTP 参数
```

---

## 编译步骤 / Build steps

完整命令见 `scripts/sd-build-config2.sh`（配置）与 `scripts/sd-build-run.sh`（编译），成功形态见 `logs/build-hip3-config.log`。核心 flag：

```bash
cmake -S . -B build-hip \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=/usr/bin/gcc          # ← CPU 侧必须 gcc/g++
  -DCMAKE_CXX_COMPILER=/usr/bin/g++        # ← clang 编 ggml-cpu 会触发 LLVM 后端死循环
  -DCMAKE_HIP_COMPILER=/opt/rocm-5.7.1/llvm/bin/clang++   # ← HIP 侧用 ROCm 裸 clang++
  -DSD_HIPBLAS=ON \
  -DSD_USE_UPSTREAM_GGML=ON -DCMAKE_C_FLAGS=-DSD_USE_UPSTREAM_GGML -DCMAKE_CXX_FLAGS=-DSD_USE_UPSTREAM_GGML \
  -DSD_GGML_SOURCE_DIR=<your llama.cpp tree>/ggml \
  -DGGML_HIP=ON -DGGML_HIPBLAS=ON -DAMDGPU_TARGETS=gfx906 -DGPU_TARGETS=gfx906 \
  -DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-multiple-definition \
  -DSD_WEBP=OFF -DSD_WEBM=OFF -DSD_BUILD_SHARED_LIBS=OFF \
```

**四层缺一不可的修复**（细节与判别流程见 `patches/PATCHES.md`）：

1. CPU 编译用 **gcc/g++** —— ROCm clang 编 `ggml-cpu` 的 `ops.cpp` 在 -O3 下 `error in backend: Instruction Combining seems stuck`，编到 63% 莫名失败
2. HIP 编译用 **ROCm 裸 clang++**（`/opt/rocm-5.7.1/llvm/bin/clang++`）—— `hipcc` wrapper 被 cmake 直接拒绝
3. **`-DSD_USE_UPSTREAM_GGML` 必须同时注入为编译宏**（`-DCMAKE_C/CXX_FLAGS`）—— 它只是 cmake option，不注入的话照编 SageAttention 段、报未声明标识符
4. **`-Wl,--allow-multiple-definition`** —— 新版 `ggml-cuda` 每个 TU 都带 ROCm 5.7 旧头的 bfloat16 host 强符号（实测 `nm` 计数 146），链接期吞掉同值重复

运行：

```bash
LD_LIBRARY_PATH=/opt/rocm/lib:/opt/rocm/hip/lib ./sd-cli ...
# 或 llama.cpp HIP 版：cd build-hip && LD_LIBRARY_PATH=./bin ./bin/llama-bench ...
./sd-cli --list-devices   # 应报 ROCm0 AMD Radeon (TM) Pro VII, gfx906
```

---

## 性能 / Benchmarks（实测，Pro VII 16GB · i5-4590）

| 负载 | HIP | Vulkan（官方预编译） | HIP 提速 |
|---|---|---|---|
| Anima 2B · 1024² · 6 步 | 21.04 s | 20.53 s | ≈持平 |
| Anima 2B · 1448² · 6 步 | 31.71 s | 49.98 s | **快 58%** |
| Anima 2B · 2048² · 6 步 | 77.87 s | 128.7 s | **快 65%** |
| Qwen-Image 2.1 · 8 步 | 61.5 s | 78 s | **快 27%** |
| llama.cpp · 27B Q3_K_S · tg128 | 24.90 t/s | 12.65 t/s | **快 97%** |
| llama.cpp · 27B · 真实对话 | 24.7 t/s | 7.4 t/s | **快 234%** |
| llama.cpp · 27B · tg128（ROCm 6.1） | 25.39 t/s | — | — |
| llama.cpp · 27B · MTP n=2（ROCm 6.1 真对话） | 28.42 t/s | — | — |

> 口径：`快 X%` = (Vulkan 耗时 ÷ HIP 耗时 − 1)，正值一律表示 HIP 更快，所有行同向可比。
> HIP 收益随分辨率上升才显现（1024² 持平、1448² 起快 58%）——低分辨率小图别指望换后端提速。
> 表格左侧 `sd-cli` 用时 = 采样时间（不含 VAE 解码），LLM 口径带备注见 `bench/BENCH.md`。
> ROCm 6.1 起升级为最快档：tg128 25.39、MTP n=2 真对话 28.42（`--spec-draft-n-max 2`，默认 n=3 反而 -17%）——详见 `bench/ROCM61-EVAL.md`。

---

## 源码基线 / Source baselines

- `stable-diffusion.cpp` master tarball 校验和：见 `configs/sd-cpp.tar.gz.sha256`（官方地址：`https://github.com/leejet/stable-diffusion.cpp/archive/refs/heads/master.tar.gz`）
- `llama.cpp` master @ 2026-10-28 快照（编译于 ROCm 5.7.1 容器，`rocm/dev-ubuntu-22.04:5.7.1-complete`）
- 本仓库不含二进制与源码包，全部自编译；GitHub 断流时用 `scripts/sd-mirror.sh`（gh-proxy.com 镜像）取源

---

## 许可 / License

本仓库（脚本、文档）以 **MIT** 发布。上游依赖：stable-diffusion.cpp (MIT) · llama.cpp (MIT) · ggml (MIT)。第三方商标归各自所有者。

## English

This repository archives the self-built **HIP backend build chain for Radeon Pro VII (gfx906)** — the last supported cards before ROCm dropped gfx906 from its support matrix (ROCm 6.4+). All assets here were measured on Ubuntu 26.04 / i5-4590 / Radeon Pro VII 16GB HBM2.

- **Why**: official binary releases ship only the Vulkan backend; the HIP backend for this EOL GPU must be self-compiled (ROCm 5.7.1 / 6.3 are the last usable releases).
- **What's inside**: build orchestration scripts (`scripts/`), three generations of configure/build logs (`logs/`), CMakeCache flags (`configs/`), the four-layer patch chain that makes gfx906 compilation succeed (`patches/PATCHES.md`), and measured benchmarks vs Vulkan (`bench/BENCH.md`).
- **Key fixes**: gcc/g++ for the CPU backend (ROCm clang hangs the LLVM backend), bare ROCm clang++ for HIP (hipcc wrapper is rejected by CMake), `-DSD_USE_UPSTREAM_GGML` must be injected as a real compile macro, and `-Wl,--allow-multiple-definition` for duplicate bfloat16 symbols.
- **Results**: HIP is up to **65% faster** than Vulkan on larger canvases for image generation, and ~**2× faster** for llama.cpp inference (24.9 vs 12.65 t/s, 27B Q3_K_S). All deltas are reported as "HIP faster by X%" with Vulkan as the baseline; see `bench/BENCH.md`.
- **2026-10-29 update**: **ROCm 6.1.2** verified as the fastest release for gfx906 (tg128 25.39 t/s, +2% over 5.7.1; prefill 236 t/s); MTP speculative decoding at `--spec-draft-n-max 2` reaches **28.42 t/s** real chat. The community `gfx906-llama-cpp` fork was benchmarked and **rejected** (33% slower — stale ggml 0.25.1 baseline vs master 0.28.0). Full matrix in `bench/ROCM61-EVAL.md`.
- **License**: MIT (scripts/docs); upstream projects remain MIT.