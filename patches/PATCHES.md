# PATCHES.md — gfx906 HIP 编译补丁链

在 ROCm 5.7.1 上让 `gfx906`（Radeon VII / Pro VII / MI50）编译 stable-diffusion.cpp / llama.cpp 的 HIP 后端，必须处理的全部修复点。按「必须同时在场 / 判别顺序 / 为什么」组织。

三轮演化证据：`../logs/build-hip.log`（全 clang 失败的 build-hip）→ `../logs/build-hip2-config*.log`（混合尝试）→ `../logs/build-hip3-config.log`（成功形态：GNU 11.4 编 CPU + Clang 17 编 HIP）。对应三套 flag 快照：`../configs/build-hip-cache-keys.txt` / `-hip2-` / `-hip3-`。

---

## 四层必须同时在场的修复（缺一层就编不过或产物不可用）

### 1. CPU 编译必须 gcc/g++，只有 HIP 侧用 ROCm clang

- **现象**：`CMAKE_C/CXX_COMPILER` 指到 `/opt/rocm-5.7.1/llvm/bin/clang(++)` 时，`ggml-cpu` 的 `ops.cpp`/`repack.cpp` 在 -O3 下触发 LLVM 后端死循环：`fatal error: error in backend: Instruction Combining seems stuck in an infinite loop after 1000 iterations`，frontend exit 70。表现是「编到 63% 莫名失败」——ggml-hip 早已 `Built target`，很容易误判成 HIP 侧或内存问题。
- **修法**：`-DCMAKE_C_COMPILER=/usr/bin/gcc -DCMAKE_CXX_COMPILER=/usr/bin/g++`；HIP 编译器单独给 `-DCMAKE_HIP_COMPILER=/opt/rocm-5.7.1/llvm/bin/clang++`。
- **判别**：configure 后 `CMakeCache.txt` 必须同时满足 `CMAKE_C_COMPILER=gcc`、`CMAKE_CXX_COMPILER=g++`、`CMAKE_HIP_COMPILER=.../clang++`。`g++: CLANGRT compiler options not supported` 只是 g++ 编 CPU 时的无害告警。

### 2. HIP 编译器只能是裸 clang++，不接受 hipcc wrapper

- **现象**：`CMAKE_HIP_COMPILER=/opt/rocm-5.7.1/bin/hipcc` 报 `CMAKE_HIP_COMPILER is set to the hipcc wrapper … This is not supported. Use Clang directly, or let CMake pick a default` + `Generate step failed`。
- **修法**：指裸 `clang++`。验证过的组合即 llama.cpp 成功构建里 `grep -E "^(CMAKE_HIP_COMPILER:|CMAKE_CXX_COMPILER:|GGML_HIP)" build-hip/CMakeCache.txt` 的形态：`HIP=.../llvm/bin/clang++` + `CXX=/usr/bin/c++`。

### 3. `-DSD_USE_UPSTREAM_GGML` 是 cmake option 但不是编译宏，必须双管齐下

- **机制**：sd.cpp 源码把 `ggml_sage_attn`/`GGML_SAGE_ATTN_AUTO` 调用包在 `#ifndef SD_USE_UPSTREAM_GGML` 里，但 CMakeLists 只 `option(...)` 没有 `add_compile_definitions`——传了 option 照样编那段，报未声明标识符（SageAttention 需要 CUDA 12 + SM80，AMD 卡本来就该跳过）。
- **修法**：`-DSD_USE_UPSTREAM_GGML=ON` **并且** `-DCMAKE_C_FLAGS=-DSD_USE_UPSTREAM_GGML -DCMAKE_CXX_FLAGS=-DSD_USE_UPSTREAM_GGML` 注入为真宏。

### 4. 链接期 `-Wl,--allow-multiple-definition`（bfloat16 重复符号）

- **机制**：新版 `ggml-cuda` 编出 `fattn-tile-instance-dkq*/dv*` 一堆实例文件，每个 TU 都带一份 ROCm 5.7 旧头里的 bfloat16 host 强符号（实测 `nm libggml-hip.a | grep -c __double2bfloat16` = **146**）；旧版树编的 llama.cpp 产物 `grep -c fattn-tile-instance` = 0，所以不炸。不是编译器或 flags 的锅，是 ggml 源码版本演进。
- **修法**：`-DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-multiple-definition`（只影响可执行文件链接，不触发对象重编）。
- **判别顺序**：先 `nm <失败 build>/ggml/src/ggml-hip/libggml-hip.a | grep <符号>` 与已知好构建对拍，再比两个 `flags.make` 的 `HIP_FLAGS`——一致就说明差异在源码/对象集合，别再往编译器上猜、也别升 ROCm。

---

## 其他必踩的坑（按出现顺序）

### 5. 每轮改编译器/宏都开新 build 目录，别原地重配

改 `CMAKE_C/CXX/HIP_COMPILER` 会让 cmake 报 `You have changed variables that require your cache to be deleted`；中途失败留下残缺 cache，下一轮读到混合状态。做法：`build-hip2` / `build-hip3` 并列，每次全新目录 + 日志外置（`build-hipN-config.log`），成功后清旧目录。

### 6. 容器内 git clone GitHub 必断，改用镜像 tar 包

`git clone` 反复断在 `index-pack ... sideband`（HTTP/2、postBuffer 都调过），codeload tarball 也截断（残留 1.8–2.1MB）。正解（见 `scripts/sd-clone4.sh` / `sd-mirror2.sh`）：

```bash
curl -L --http1.1 -o sd-cpp.tar.gz \
  https://gh-proxy.com/https://github.com/leejet/stable-diffusion.cpp/archive/refs/heads/master.tar.gz
gzip -t sd-cpp.tar.gz    # 主仓完整包约 129MB；2MB 级 = 截断
```

判成功看 `gzip -t` 与字节数量级，不看 curl exit code（截断时 curl 也正常退出）。镜像认 `github.com/<org>/<repo>/archive/...`，不认 codeload 域。

### 7. llama.cpp 侧的两个补丁点（LLM 推理线）

- **ROCm ≥ 6.1 版本门**：sd.cpp master 的 `ggml-hip` 硬检 `At least ROCM/HIP V6.1 is required`（`ggml/src/ggml-hip/CMakeLists.txt`），ROCm 5.7.1 直接死在 configure。两个选择：降检，或借 llama.cpp 的 ggml 源码树（它已验证能在 5.7.1 编 HIP）——本项目采用后者（`-DSD_GGML_SOURCE_DIR=<llama.cpp tree>/ggml`），不动上游源码。
- **hipStreamWaitEvent 双形态**：llama.cpp 编译链里出现过三参/两参混用导致的符号问题——保持整棵树同一 ggml 来源即可规避。
- llama.cpp 侧不修改源码、不锁提交：本项目用当日 master 快照直接编（详见 README「源码基线」）。

### 8. 验证三环（缺一不可）

`rocminfo` 列出 `gfx906` → `cmake -DGGML_HIP=ON -DAMDGPU_TARGETS=gfx906` 编过 → `./sd-cli --list-devices` 报 **`ROCm0 AMD Radeon (TM) Pro VII, gfx906`**（llama 侧 `llama-bench --list-devices` 报 `HIP0`，不是 `Vulkan0`）。缺任一环先修环境，不要先跑分。

---

*本文件与 `../scripts/`、`../logs/`、`../configs/` 配套使用；全部坑点均为本机 2026-10-27/28 实测得出。*