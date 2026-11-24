# polyplayer-projectm

The builds of [projectM](https://github.com/projectM-visualizer/projectm) that Polyplayer's
Visualizer runs: the WebAssembly module the browser runs, with the thin wrapper around projectM's
C API it is built with, and the shared library the Android app runs. projectM plays MilkDrop
presets; Polyplayer feeds it the audio being played and draws it full screen.

projectM is licensed under the GNU Lesser General Public License, version 2.1 (LGPL-2.1).
Polyplayer ships projectM as its own WebAssembly module, holding only projectM and this wrapper,
loaded by the page at run time, and on Android as its own shared library, `libprojectM-4.so`,
holding only projectM, which the app loads; none of Polyplayer's own code is compiled into
either. This repository holds what you need to rebuild them, with your changes to projectM or to
the wrapper, and to replace the module a Polyplayer deployment serves or the library in the app.

## What is here

| File | What it is |
| --- | --- |
| `wrapper.cpp` | The wrapper: one projectM instance on the WebGL 2 context the page made current, with `pm_create`, `pm_pcm`, `pm_render`, `pm_load`, `pm_failed`, `pm_resize` and `pm_destroy` |
| `build.sh` | The web build: clones projectM at the pinned release, builds it as a static library with Emscripten, and links it with the wrapper into `projectm.mjs` and `projectm.wasm` |
| `CMakeLists.txt` | The Android build: clones projectM at the same pinned release and builds it with the Android NDK as `libprojectM-4.so`, for one ABI |
| `LICENSE` | The GNU Lesser General Public License, version 2.1, which covers the wrapper and the build scripts as it covers projectM |

## The pinned versions

- **projectM** [v4.1.8](https://github.com/projectM-visualizer/projectm/releases/tag/v4.1.8), commit
  `4967dc003e5206d7df3ff447287f7609c47d2343`, the same in `build.sh` and `CMakeLists.txt` (each
  stops if the tag moved). projectM's source, upstream:
  <https://github.com/projectM-visualizer/projectm>.
- **Emscripten**, the Docker image
  `emscripten/emsdk:7.0.1@sha256:73aece2e0ab748487945ad117b79fc4d277e9f656e54fc800a9b1a0a6562715b`.
- **Android**: NDK 28.2.13676358 and CMake 3.31.6 (the Android SDK's `ndk;28.2.13676358` and
  `cmake;3.31.6`), for `arm64-v8a`, `armeabi-v7a` and `x86_64`, Android 7.0 (API 24) and up.

## Building

With Docker, from this folder:

```bash
docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$PWD:/src:ro" -v "$PWD/out:/out" \
  emscripten/emsdk:7.0.1@sha256:73aece2e0ab748487945ad117b79fc4d277e9f656e54fc800a9b1a0a6562715b \
  bash /src/build.sh /out
```

`out/` then holds `projectm.mjs` and `projectm.wasm` (about 1 MB together, 0.34 MB gzipped). Any
machine with the same emsdk on its path builds the same with `./build.sh out`.

## Building for Android

With the Android SDK's NDK and CMake above installed (`sdkmanager --install
"ndk;28.2.13676358" "cmake;3.31.6"`), git, and `ANDROID_HOME` pointing at the SDK, from this
folder, for each ABI you want:

```bash
for abi in arm64-v8a armeabi-v7a x86_64; do
  "$ANDROID_HOME/cmake/3.31.6/bin/cmake" -S . -B "out/$abi" -G Ninja \
    -DCMAKE_MAKE_PROGRAM="$ANDROID_HOME/cmake/3.31.6/bin/ninja" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_HOME/ndk/28.2.13676358/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$abi" -DANDROID_PLATFORM=android-24
  "$ANDROID_HOME/cmake/3.31.6/bin/cmake" --build "out/$abi"
  "$ANDROID_HOME/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" \
    "out/$abi/projectm/src/libprojectM/libprojectM-4.so"
done
```

`out/<abi>/projectm/src/libprojectM/libprojectM-4.so` is then the library for that ABI (about
2 MB for `arm64-v8a`). Polyplayer's own APK build includes this same `CMakeLists.txt`.

## Replacing the library in the Android app

The app (`io.github.acastaner.polyplayer`) loads `lib/<abi>/libprojectM-4.so` from its APK, beside
Polyplayer's own `libpolyplayer_visualizer.so`, which calls projectM's C API (`projectM-4/*.h`)
and nothing else; a library that keeps that API works. Android installs only signed APKs, so put
your build in the APK and sign it with a key of your own (build-tools 36.0.0 here):

```bash
cp polyplayer.apk mine.apk
mkdir -p lib/arm64-v8a && cp out/arm64-v8a/projectm/src/libprojectM/libprojectM-4.so lib/arm64-v8a/
zip -0 mine.apk lib/arm64-v8a/libprojectM-4.so     # stored, not compressed, as the APK holds it
"$ANDROID_HOME/build-tools/36.0.0/zipalign" -f -P 16 4 mine.apk mine-aligned.apk
"$ANDROID_HOME/build-tools/36.0.0/apksigner" sign --ks my.keystore mine-aligned.apk
adb uninstall io.github.acastaner.polyplayer   # an APK signed with another key can't update it
adb install mine-aligned.apk
```

Do the same for each ABI the APK holds. The app's settings and sign-in on the phone go with the
uninstall; it asks for its Polyplayer's address again.

## Replacing the module in a deployment

A Polyplayer deployment serves the module at `/projectm/projectm.mjs` and
`/projectm/projectm.wasm`, beside its web build, and the page fetches them the first time a
Visualizer opens. Serve your own build at those two paths instead (for example by mounting it
over `/app/wwwroot/projectm` in Polyplayer's image). The page calls only the wrapper's functions
above, the module's `default` export (`createProjectM`) and Emscripten's `GL`, `HEAPF32`,
`stringToNewUTF8`, `_malloc` and `_free`, so a module that keeps them works.

## Where it comes from

This repository is refreshed from `player-engine/projectm/` of Polyplayer's own repository at
each Polyplayer release; the two hold the same files.
