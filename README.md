# polyplayer-projectm

The WebAssembly build of [projectM](https://github.com/projectM-visualizer/projectm) that
Polyplayer's Visualizer runs in the browser, and the thin wrapper
around projectM's C API it is built with. projectM plays MilkDrop presets; Polyplayer feeds it the
audio being played and draws it full screen.

projectM is licensed under the GNU Lesser General Public License, version 2.1 (LGPL-2.1).
Polyplayer ships projectM as its own WebAssembly module, holding only projectM and this wrapper,
loaded by the page at run time; none of Polyplayer's own code is compiled into it. This
repository holds what you need to rebuild that module, with your changes to projectM or to the
wrapper, and to replace the one a Polyplayer deployment serves.

## What is here

| File | What it is |
| --- | --- |
| `wrapper.cpp` | The wrapper: one projectM instance on the WebGL 2 context the page made current, with `pm_create`, `pm_pcm`, `pm_render`, `pm_load`, `pm_failed`, `pm_resize` and `pm_destroy` |
| `build.sh` | The build: clones projectM at the pinned release, builds it as a static library with Emscripten, and links it with the wrapper into `projectm.mjs` and `projectm.wasm` |
| `LICENSE` | The GNU Lesser General Public License, version 2.1, which covers the wrapper and the build script as it covers projectM |

## The pinned versions

- **projectM** [v4.1.8](https://github.com/projectM-visualizer/projectm/releases/tag/v4.1.8), commit
  `4967dc003e5206d7df3ff447287f7609c47d2343` (`build.sh` stops if the tag moved). projectM's
  source, upstream: <https://github.com/projectM-visualizer/projectm>.
- **Emscripten**, the Docker image
  `emscripten/emsdk:7.0.1@sha256:73aece2e0ab748487945ad117b79fc4d277e9f656e54fc800a9b1a0a6562715b`.

## Building

With Docker, from this folder:

```bash
docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$PWD:/src:ro" -v "$PWD/out:/out" \
  emscripten/emsdk:7.0.1@sha256:73aece2e0ab748487945ad117b79fc4d277e9f656e54fc800a9b1a0a6562715b \
  /src/build.sh /out
```

`out/` then holds `projectm.mjs` and `projectm.wasm` (about 1 MB together, 0.34 MB gzipped). Any
machine with the same emsdk on its path builds the same with `./build.sh out`.

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
