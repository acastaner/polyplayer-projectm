#!/usr/bin/env bash
# Builds projectM and Polyplayer's wrapper (wrapper.cpp) into one WebAssembly module:
#
#   <out>/projectm.mjs    the ES module the page imports (createProjectM)
#   <out>/projectm.wasm   projectM, its vendored projectm-eval and hlslparser, and the wrapper
#
# Run it inside the pinned emsdk image (README.md, Building), which has emcc, CMake and git:
#
#   ./build.sh /out
#
# projectM is pinned by tag and commit below; a tag that moved stops the build.
set -euo pipefail

PROJECTM_TAG="v4.1.8"
PROJECTM_COMMIT="4967dc003e5206d7df3ff447287f7609c47d2343"
PROJECTM_REPO="https://github.com/projectM-visualizer/projectm.git"

out="${1:?usage: build.sh <output folder>}"
here="$(cd "$(dirname "$0")" && pwd)"
work="${PROJECTM_WORK:-$(mktemp -d)}"
jobs="${PROJECTM_JOBS:-$(nproc)}"

echo "--- projectM ${PROJECTM_TAG} (${PROJECTM_COMMIT}) ---"
if [[ ! -d "${work}/projectm/.git" ]]; then
  git clone --quiet --depth 1 --branch "${PROJECTM_TAG}" --recurse-submodules --shallow-submodules \
    "${PROJECTM_REPO}" "${work}/projectm"
fi
actual="$(git -C "${work}/projectm" rev-parse HEAD)"
if [[ "${actual}" != "${PROJECTM_COMMIT}" ]]; then
  echo "ERROR: ${PROJECTM_TAG} is ${actual}, not the pinned ${PROJECTM_COMMIT}." >&2
  exit 1
fi

echo "--- Configure (static, GLES 3 / WebGL 2, no playlist, no tests) ---"
emcmake cmake -S "${work}/projectm" -B "${work}/build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${work}/install" \
  -DENABLE_SYSTEM_GLM=OFF \
  -DENABLE_SYSTEM_PROJECTM_EVAL=OFF \
  -DENABLE_PLAYLIST=OFF \
  -DENABLE_DEBUG_POSTFIX=OFF \
  -DENABLE_SDL_UI=OFF \
  -DBUILD_TESTING=OFF \
  -DBUILD_DOCS=OFF

echo "--- Build libprojectM ---"
cmake --build "${work}/build" --parallel "${jobs}"
cmake --install "${work}/build" >/dev/null

# Linked as projectM links its own Emscripten builds (its CMakeLists.txt): C++, exceptions caught,
# WebGL 2 with the full OpenGL ES 2 and 3 emulation. No SDL: the page makes the WebGL 2 context.
echo "--- Link the module ---"
mkdir -p "${out}"
libs=("${work}"/install/lib/*.a)
em++ -O3 \
  -I"${work}/install/include" \
  "${here}/wrapper.cpp" "${libs[@]}" \
  -sMODULARIZE=1 -sEXPORT_ES6=1 -sEXPORT_NAME=createProjectM \
  -sENVIRONMENT=web \
  -sMIN_WEBGL_VERSION=2 -sMAX_WEBGL_VERSION=2 -sFULL_ES2=1 -sFULL_ES3=1 \
  -sNO_DISABLE_EXCEPTION_CATCHING \
  -sALLOW_MEMORY_GROWTH=1 \
  -sEXPORTED_FUNCTIONS=_malloc,_free \
  -sEXPORTED_RUNTIME_METHODS=GL,HEAPF32,HEAPU8,stringToNewUTF8 \
  -sFILESYSTEM=0 \
  -o "${out}/projectm.mjs"

ls -l "${out}"
