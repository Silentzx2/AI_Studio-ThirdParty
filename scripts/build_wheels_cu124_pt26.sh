#!/bin/bash
# ==============================================================================
# Script to build precompiled wheels (.whl) for dependencies requiring source 
# compilation with Python 3.10 + PyTorch 2.6.0 + CUDA 12.4.
#
# Target platform: Linux x86_64
# Target environment: Active .venv (Python 3.10, PyTorch 2.6.0+cu124)
# Output directory: ./wheels/
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WHEELS_DIR="$REPO_ROOT/wheels"

mkdir -p "$WHEELS_DIR"

echo "=========================================================="
echo " Building Precompiled Wheels for AI Studio ThirdParty"
echo " Baseline: Python 3.10 | PyTorch 2.6.0 | CUDA 12.4"
echo " Output: $WHEELS_DIR"
echo "=========================================================="

# Build environment configuration
export CUDA_HOME="${CUDA_HOME:-/usr/local/cuda-12.4}"
export PATH="${CUDA_HOME}/bin:${PATH}"
export LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH:-}"
export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-7.5;8.0;8.6;8.9;9.0+PTX}"
export FORCE_CUDA=1
export PIP_NO_BUILD_ISOLATION=1
export MAX_JOBS="${MAX_JOBS:-4}"

# Verify active Python is 3.10
PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
if [ "$PY_VER" != "3.10" ]; then
    echo "[WARN] Active Python version is $PY_VER (expected 3.10)."
fi

# Verify active PyTorch
python3 -c "import torch; print(f'[INFO] Detected PyTorch {torch.__version__}, CUDA available: {torch.cuda.is_available()}')"

# ------------------------------------------------------------------------------
# 1. torch-scatter (Used by TripoSF)
# ------------------------------------------------------------------------------
echo ""
echo "[1/6] Building torch-scatter..."
if ls "$WHEELS_DIR"/torch_scatter*.whl 1> /dev/null 2>&1; then
    echo "[SKIP] torch-scatter wheel already exists in $WHEELS_DIR"
else
    BUILD_DIR=$(mktemp -d)
    git clone --depth 1 https://github.com/rusty1s/pytorch_scatter.git "$BUILD_DIR/pytorch_scatter"
    (
        cd "$BUILD_DIR/pytorch_scatter"
        python3 setup.py bdist_wheel -d "$WHEELS_DIR"
    )
    rm -rf "$BUILD_DIR"
    echo "[SUCCESS] torch-scatter wheel built successfully."
fi

# ------------------------------------------------------------------------------
# 2. torchmcubes (Used by TripoSR)
# ------------------------------------------------------------------------------
echo ""
echo "[2/6] Building torchmcubes..."
if ls "$WHEELS_DIR"/torchmcubes*.whl 1> /dev/null 2>&1; then
    echo "[SKIP] torchmcubes wheel already exists in $WHEELS_DIR"
else
    BUILD_DIR=$(mktemp -d)
    git clone --depth 1 https://github.com/tatsy/torchmcubes.git "$BUILD_DIR/torchmcubes"
    (
        cd "$BUILD_DIR/torchmcubes"
        python3 setup.py bdist_wheel -d "$WHEELS_DIR"
    )
    rm -rf "$BUILD_DIR"
    echo "[SUCCESS] torchmcubes wheel built successfully."
fi

# ------------------------------------------------------------------------------
# 3. diso (Used by TripoSG)
# ------------------------------------------------------------------------------
echo ""
echo "[3/6] Checking diso..."
if ls "$WHEELS_DIR"/diso*.whl 1> /dev/null 2>&1; then
    echo "[SKIP] diso wheel already exists in $WHEELS_DIR"
else
    BUILD_DIR=$(mktemp -d)
    git clone --depth 1 https://github.com/SarahWeiii/diso.git "$BUILD_DIR/diso"
    (
        cd "$BUILD_DIR/diso"
        python3 setup.py bdist_wheel -d "$WHEELS_DIR"
    )
    rm -rf "$BUILD_DIR"
    echo "[SUCCESS] diso wheel built successfully."
fi

# ------------------------------------------------------------------------------
# 4. ardy / motion_correction (Used by ardy)
# ------------------------------------------------------------------------------
echo ""
echo "[4/6] Building ardy (with bundled motion_correction C++ extension)..."
if ls "$WHEELS_DIR"/ardy*.whl 1> /dev/null 2>&1; then
    echo "[SKIP] ardy wheel already exists in $WHEELS_DIR"
else
    (
        cd "$REPO_ROOT/ardy"
        python3 setup.py bdist_wheel -d "$WHEELS_DIR"
    )
    echo "[SUCCESS] ardy wheel built successfully."
fi

# ------------------------------------------------------------------------------
# 5. flash-attn (Used by TripoSF, UniRig, TRELLIS.2)
# ------------------------------------------------------------------------------
echo ""
echo "[5/6] Checking flash-attn..."
if ls "$WHEELS_DIR"/flash_attn*.whl 1> /dev/null 2>&1; then
    echo "[SKIP] flash-attn wheel already exists in $WHEELS_DIR"
else
    echo "[BUILD] Building flash-attn (this may take 15-30 minutes)..."
    FLASH_ATTENTION_FORCE_BUILD=TRUE pip wheel flash-attn>=2.7.4.post1 --no-build-isolation -w "$WHEELS_DIR"
    echo "[SUCCESS] flash-attn wheel built successfully."
fi

# ------------------------------------------------------------------------------
# 6. spconv-cu124 (Used by TripoSF, XPart)
# ------------------------------------------------------------------------------
echo ""
echo "[6/6] Downloading spconv-cu124 wheel..."
if ls "$WHEELS_DIR"/spconv_cu124*.whl 1> /dev/null 2>&1; then
    echo "[SKIP] spconv-cu124 wheel already exists in $WHEELS_DIR"
else
    pip wheel spconv-cu124>=2.3.6 -w "$WHEELS_DIR" --no-deps || true
    echo "[SUCCESS] spconv-cu124 wheel cached."
fi

echo ""
echo "=========================================================="
echo " All wheels in $WHEELS_DIR:"
ls -lh "$WHEELS_DIR"/*.whl
echo "=========================================================="
