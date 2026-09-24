# Source Dependencies & Prebuilt Wheel Guide

This document provides the complete technical specifications and build commands for all dependencies in **TripoSF**, **TripoSG**, **TripoSR**, and **ardy** that require **source compilation (C++/CUDA extensions)** under the target environment:

- **OS / Architecture**: Linux x86_64
- **Python**: **3.10** (`cp310-cp310-linux_x86_64`)
- **PyTorch**: **2.6.0** (`torch==2.6.0+cu124`)
- **CUDA**: **12.4** (`cu124`)
- **Virtualenv**: Active `.venv` (inherits pre-installed PyTorch & CUDA)

All prebuilt wheels are stored in the root `wheels/` directory and tracked via Git LFS.

---

## 1. Summary of Dependencies Requiring Source Compilation

| Package | Used By | Type | Source Repository | Reason for Compilation | Target Wheel Name |
|---|---|---|---|---|---|
| **`torch-scatter`** | `TripoSF` | PyTorch C++/CUDA | [rusty1s/pytorch_scatter](https://github.com/rusty1s/pytorch_scatter) | Strictly bound to PyTorch C++ ABI (`libtorch.so`). PyG wheel repo only publishes up to PyTorch 2.4/2.5; no official PyTorch 2.6.0+cu124 wheel exists. | `torch_scatter-2.1.2+pt26cu124-cp310-cp310-linux_x86_64.whl` |
| **`torchmcubes`** | `TripoSR` | CUDA Kernel | [tatsy/torchmcubes](https://github.com/tatsy/torchmcubes) | Marching Cubes CUDA kernel (`mcubes_cuda`). No PyPI wheels exist. Without CUDA at build time, it defaults to a broken CPU stub. | `torchmcubes-0.1.0-cp310-cp310-linux_x86_64.whl` |
| **`diso`** | `TripoSG` | CUDA / C++ | [SarahWeiii/diso](https://github.com/SarahWeiii/diso) | Differentiable Iso-Surface / DMC. Needs compilation against PyTorch 2.6 CUDA runtime. *(Existing wheel in `wheels/`)* | `diso-0.1.4-cp310-cp310-linux_x86_64.whl` |
| **`ardy` (`motion_correction`)** | `ardy` | C++17 / CMake / pybind11 | `AI_Studio-ThirdParty/ardy` | Vendors `motion_correction._motion_correction` (InverseKinematics, TrajectoryCorrector) using Eigen3. Prebuilding avoids CMake/C++ toolchain requirement on deployment machines. | `ardy-0.2.0-cp310-cp310-linux_x86_64.whl` |
| **`flash-attn`** | `TripoSF` | Custom CUDA Kernels | [Dao-AILab/flash-attention](https://github.com/Dao-AILab/flash-attention) | CUDA FlashAttention kernels. TripoSF original pinned 2.5.9 which is incompatible with PyTorch 2.6. Requires >=2.7.3/2.7.4. *(Existing wheel in `wheels/`)* | `flash_attn-2.7.4.post1+cu12torch2.6cxx11abiFALSE-cp310-cp310-linux_x86_64.whl` |
| **`spconv-cu124`** | `TripoSF` | CUDA Spatially Sparse Conv | [FindDefinition/spconv](https://github.com/FindDefinition/spconv) | 3D sparse convolution for voxel grids. Must match CUDA 12.4 runtime. (Available as binary on PyPI or can be cached into `wheels/`). | `spconv_cu124-2.3.6-cp310-cp310-linux_x86_64.whl` |
| **`torch-cluster`** *(Optional)* | `TripoSG` (VAE encoder) | PyTorch C++/CUDA | [rusty1s/pytorch_cluster](https://github.com/rusty1s/pytorch_cluster) | k-NN / cluster operations for point clouds. Bound to PyTorch 2.6 C++ ABI. | `torch_cluster-1.6.3+pt26cu124-cp310-cp310-linux_x86_64.whl` |

---

## 2. Build Environment Setup

Before running wheel builds, ensure your machine has:
1. Python 3.10 active (`python3 --version` -> `3.10.x`)
2. PyTorch 2.6.0 with CUDA 12.4 active (`torch.__version__` -> `2.6.0+cu124`)
3. CUDA 12.4 toolkit installed (for `nvcc` and CUDA headers)
4. CMake >= 3.18 and Ninja installed (`pip install cmake ninja setuptools wheel packaging`)

Set environment variables:
```bash
export CUDA_HOME=/usr/local/cuda-12.4
export PATH="${CUDA_HOME}/bin:${PATH}"
export LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH:-}"
export TORCH_CUDA_ARCH_LIST="7.5;8.0;8.6;8.9;9.0+PTX"
export FORCE_CUDA=1
export PIP_NO_BUILD_ISOLATION=1
export MAX_JOBS=4
```

---

## 3. Step-by-Step Wheel Build Commands

### 1) Build `torch-scatter`
```bash
git clone --depth 1 https://github.com/rusty1s/pytorch_scatter.git /tmp/build_scatter
cd /tmp/build_scatter
python3 setup.py bdist_wheel -d /teamspace/studios/this_studio/AI_Studio-ThirdParty/wheels/
rm -rf /tmp/build_scatter
```

### 2) Build `torchmcubes`
```bash
git clone --depth 1 https://github.com/tatsy/torchmcubes.git /tmp/build_torchmcubes
cd /tmp/build_torchmcubes
python3 setup.py bdist_wheel -d /teamspace/studios/this_studio/AI_Studio-ThirdParty/wheels/
rm -rf /tmp/build_torchmcubes
```

### 3) Build `diso` (if rebuilding)
```bash
git clone --depth 1 https://github.com/SarahWeiii/diso.git /tmp/build_diso
cd /tmp/build_diso
python3 setup.py bdist_wheel -d /teamspace/studios/this_studio/AI_Studio-ThirdParty/wheels/
rm -rf /tmp/build_diso
```

### 4) Build `ardy` (with bundled `motion_correction` binary)
```bash
cd /teamspace/studios/this_studio/AI_Studio-ThirdParty/ardy
python3 setup.py bdist_wheel -d /teamspace/studios/this_studio/AI_Studio-ThirdParty/wheels/
```

### 5) Build `flash-attn` (if rebuilding)
```bash
FLASH_ATTENTION_FORCE_BUILD=TRUE pip wheel flash-attn>=2.7.4.post1 \
    --no-build-isolation \
    -w /teamspace/studios/this_studio/AI_Studio-ThirdParty/wheels/
```

### 6) Cache `spconv-cu124`
```bash
pip wheel spconv-cu124>=2.3.6 \
    -w /teamspace/studios/this_studio/AI_Studio-ThirdParty/wheels/ \
    --no-deps
```

---

## 4. Automated Build Script

An automated script is provided at:
```bash
bash scripts/build_wheels_cu124_pt26.sh
```
This checks existing wheels in `wheels/`, builds any missing components using the active Python 3.10 / PyTorch 2.6.0 environment, and outputs all `.whl` files into `wheels/`.

---

## 5. Installing the 4 Models from the Local Wheelhouse

When deploying or installing in an active `.venv` (with PyTorch 2.6.0+cu124):

```bash
# 1. TripoSF
pip install --find-links ./wheels -r TripoSF/requirements.txt

# 2. TripoSG
pip install --find-links ./wheels -r TripoSG/requirements.txt

# 3. TripoSR
pip install --find-links ./wheels -r TripoSR/requirements.txt

# 4. ARDY
pip install --find-links ./wheels -r ardy/requirements.txt
pip install -e ardy --no-build-isolation
```
