# The Android build of projectM: libprojectM-4.so, projectM's own shared library, for one Android
# ABI, built with the Android NDK from projectM's source at the release build.sh pins. Nothing
# else is compiled into it: Polyplayer's own code calls it from a library of its own.
#
# On its own, from this folder, for one ABI (README.md, Building for Android):
#
#   cmake -S . -B out/arm64-v8a -G Ninja -DCMAKE_BUILD_TYPE=Release \
#     -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK/build/cmake/android.toolchain.cmake" \
#     -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-24
#   cmake --build out/arm64-v8a
#
# out/arm64-v8a/projectm/src/libprojectM/libprojectM-4.so is then the library. Polyplayer's APK
# build includes this file (add_subdirectory) and packs the same library under lib/<abi>/.
#
# projectM is pinned by tag and commit below, the same as build.sh's; a tag that moved stops the
# build. The clone is kept in PROJECTM_SOURCE_CACHE (one per commit, shared by every ABI's build,
# taken under a lock), so a machine fetches it once.
cmake_minimum_required(VERSION 3.22)

if(NOT DEFINED PROJECT_NAME)
  project(polyplayer_projectm LANGUAGES C CXX)
endif()

set(PROJECTM_TAG "v4.1.8")
set(PROJECTM_COMMIT "4967dc003e5206d7df3ff447287f7609c47d2343")
set(PROJECTM_REPO "https://github.com/projectM-visualizer/projectm.git")

if(NOT CMAKE_SYSTEM_NAME STREQUAL "Android")
  message(FATAL_ERROR "This builds projectM for Android: give it the NDK's toolchain file "
                      "(CMAKE_TOOLCHAIN_FILE, ANDROID_ABI). The web build is build.sh.")
endif()

set(PROJECTM_SOURCE_CACHE "${CMAKE_BINARY_DIR}/projectm-source" CACHE PATH
    "Where projectM's source is cloned, one folder per commit")
set(projectm_source "${PROJECTM_SOURCE_CACHE}/${PROJECTM_COMMIT}")

find_package(Git REQUIRED)
file(MAKE_DIRECTORY "${PROJECTM_SOURCE_CACHE}")
file(LOCK "${PROJECTM_SOURCE_CACHE}/${PROJECTM_COMMIT}.lock" GUARD FILE TIMEOUT 1200)
if(NOT EXISTS "${projectm_source}/.cloned")
  message(STATUS "Cloning projectM ${PROJECTM_TAG} (${PROJECTM_COMMIT})")
  file(REMOVE_RECURSE "${projectm_source}")
  execute_process(
    COMMAND "${GIT_EXECUTABLE}" clone --quiet --depth 1 --branch "${PROJECTM_TAG}"
            --recurse-submodules --shallow-submodules "${PROJECTM_REPO}" "${projectm_source}"
    RESULT_VARIABLE cloned)
  if(NOT cloned EQUAL 0)
    message(FATAL_ERROR "Could not clone projectM ${PROJECTM_TAG} from ${PROJECTM_REPO}.")
  endif()
  file(TOUCH "${projectm_source}/.cloned")
endif()
execute_process(
  COMMAND "${GIT_EXECUTABLE}" -C "${projectm_source}" rev-parse HEAD
  OUTPUT_VARIABLE actual OUTPUT_STRIP_TRAILING_WHITESPACE)
file(LOCK "${PROJECTM_SOURCE_CACHE}/${PROJECTM_COMMIT}.lock" RELEASE)
if(NOT actual STREQUAL PROJECTM_COMMIT)
  message(FATAL_ERROR "projectM ${PROJECTM_TAG} is ${actual}, not the pinned ${PROJECTM_COMMIT}.")
endif()

# projectM's own options: a shared library on OpenGL ES 3 (its default on Android), with its
# vendored projectm-eval and GLM, no playlist library, no test UI, no tests, and the same file name
# in every build type (no "d" for Debug).
set(BUILD_SHARED_LIBS ON CACHE BOOL "" FORCE)
set(ENABLE_SYSTEM_GLM OFF CACHE BOOL "" FORCE)
set(ENABLE_SYSTEM_PROJECTM_EVAL OFF CACHE BOOL "" FORCE)
set(ENABLE_PLAYLIST OFF CACHE BOOL "" FORCE)
set(ENABLE_DEBUG_POSTFIX OFF CACHE BOOL "" FORCE)
set(ENABLE_SDL_UI OFF CACHE BOOL "" FORCE)
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
set(BUILD_DOCS OFF CACHE BOOL "" FORCE)

add_subdirectory("${projectm_source}" projectm)
