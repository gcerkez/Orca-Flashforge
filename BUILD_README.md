# Building Orca-Flashforge (Flash Studio) AppImage on Ubuntu 24.04 with Distrobox

This guide describes how to replicate the build of **Flash Studio / Orca-Flashforge 1.7.15** into a standalone Linux AppImage with **FlashNetwork 3.4.0** support using **Podman**, **Distrobox**, and an **Ubuntu 24.04** container.

---

## 1. Overview of Fixes & PRs Incorporated

The checked-out branch `linux-fixes-1.7.15` and our build incorporates the following bug fixes and enhancements:

### 1.1 Upstream PRs Incorporated
1. **FlashNetwork 3.4.0 Support ([PR #69](https://github.com/FlashForge/Orca-Flashforge/pull/69))**:
   - Upstream 1.7.15 expected FlashNetwork library version `3.4.3`, which Flashforge never published for Linux (the last official Linux release was `3.4.0` in 1.7.9).
   - Dynamically checks and accepts FlashNetwork `3.4.0` by marking cloud-preset sync and feedback-log functions as optional, and guards against trailing `fnet_dev_detail_t` fields.
   - LAN printer discovery, device status, G-code upload, and network printing work properly.

2. **GTK3 Bitmap Toggles & AD5M Texture ([PR #69](https://github.com/FlashForge/Orca-Flashforge/pull/69))**:
   - Removes button borders from Flashforge 16px toggles (`FFCheckBox`, `FFBitmapToggleButton`, `RadioButton`) on GTK3/wxWidgets 3.3.2, fixing blank checkboxes and toggle icons.
   - Points Adventurer 5M series `bed_texture` to the bundled `.svg` instead of missing `.png`.

3. **Machine Profile Model Filename Case Sensitivity ([PR #74](https://github.com/FlashForge/Orca-Flashforge/pull/74))**:
   - Fixes lowercase/uppercase extension mismatches (`.stl` vs `.STL`) on Linux for `AD5X`, `Adventurer 5M`, `Adventurer 5M Pro`, `Adventurer A5`, and `Guider 3 Ultra` buildplate/hotend models.

4. **ADMesh Stack Buffer Overflow Prevention ([PR #47](https://github.com/FlashForge/Orca-Flashforge/pull/47))**:
   - Bounds `fscanf` and `sscanf` format buffers in `deps_src/admesh/stlinit.cpp` (`%255[^\n]`, `%15s %127s %15s`) to prevent buffer overflows during STL parsing.

5. **LAN Device Camera Stream Control ([PR #39](https://github.com/FlashForge/Orca-Flashforge/pull/39))**:
   - Implements LAN `streamCtrl_cmd` ("open"/"close") via HTTP POST directly to the printer's `/control` endpoint so video streaming starts on local connections.
   - Adds fallback to local port `8080` MJPEG stream (`http://<ip>:8080/?action=stream`) for LAN connections.
   - Adds LAN product/detail querying in `ComGetDevProductDetail`.

### 1.2 Runtime Crash Fixes (Prepare / Preview / Device Navigation)
6. **GLAD OpenGL Loader dlopen Retention (`src/glad/src/gl.c`)**:
   - In GLAD's generated `gladLoaderLoadGL()`, the library handle was immediately closed via `gladLoaderUnloadGL()` after reading functions. On Wayland / EGL setups where nothing holds `libGL.so` open, the dynamic linker unmapped `libGL.so`, turning all OpenGL function pointers into dangling/null pointers.
   - Fixed by keeping the dlopen handle loaded across the lifetime of the application and adding `libOpenGL.so.0` / `libOpenGL.so` to library search candidates.

7. **Wayland & X11 Backend Detection (`src/slic3r/GUI/LinuxDisplayBackend.cpp`)**:
   - `LinuxDisplayBackend.cpp` was guarding Wayland detection with `wxHAVE_GDK_WAYLAND`, which is an internal wxWidgets compile macro not exported in public wx headers.
   - Fixed to inspect GTK3's `GDK_WINDOWING_WAYLAND` and `GDK_WINDOWING_X11` alongside runtime environment checks (`XDG_SESSION_TYPE`, `WAYLAND_DISPLAY`), ensuring Wayland sessions correctly activate EGL.

8. **OpenGL Initialization Fallback (`src/slic3r/GUI/OpenGLManager.cpp`)**:
   - Added automatic fallback to `gladLoaderLoadGL()` if `gladLoadGL((GLADloadfunc)eglGetProcAddress)` returns version 0.

9. **Early Thumbnail Rendering & Context Guards (`src/slic3r/GUI/GLCanvas3D.cpp`, `src/slic3r/GUI/Camera.cpp`)**:
   - When switching tabs (Prepare <-> Preview <-> Device) or receiving focus, `on_set_focus` triggered `update_all_plate_thumbnails()` -> `render_thumbnail()` before the canvas context was current or OpenGL was initialized, calling address `0x0` in `Camera::apply_viewport` (`glad_glViewport`).
   - Added guards to `GLCanvas3D::render_thumbnail(...)` overloads:
     ```cpp
     if (!_set_current() || !wxGetApp().init_opengl()) return;
     if (!is_initialized() && !init()) return;
     ```
   - Added null-checks to `glad_glViewport` in `Camera::apply_viewport()` and `render_thumbnail_internal()`.

10. **Linux Platform Macros & FlashNetwork Discovery (`CMakeLists.txt`, `GUI_App.cpp`)**:
    - Defined `-D__LINUX__` in `CMakeLists.txt` for Linux builds so that `#if defined(__LINUX__)` blocks across the codebase (such as `ReLoginDialog`, `wxMediaCtrl2` camera video, and headers) are compiled.
    - Updated `GUI_App::init_flashnetwork()` to check multiple candidate paths on Linux (`bin/libFlashNetwork.so`, `data_dir()/plugins/libFlashNetwork.so`, and `resources/libFlashNetwork.so`).

11. **Container Packaging Compatibility (`build_appimage.sh.in`)**:
    - Added container detection for `/run/.containerenv` (Podman / Distrobox) and `$container` in addition to `/.dockerenv`.
    - Patches `appimagetool` magic bytes and runs with `--appimage-extract-and-run` inside containers without requiring host FUSE permissions.

12. **Prepare Tab 3D Canvas Rendering Restoration (`src/slic3r/GUI/GUI_App.cpp`, `src/slic3r/GUI/GLCanvas3D.cpp`)**:
    - During startup in `GUI_App::post_init()`, `plater_->canvas3D()->enable_render(false)` was called to suppress rendering during early initialization.
    - On Linux/Wayland, `IsShownOnScreen()` evaluated to `false` during the initial idle cycle before the window was realized and mapped by GTK, taking the `Found glcontext not ready, postpone the init` branch. In that branch, `enable_render(true)` was never called, leaving `m_enable_render == false` for the entire lifetime of the process.
    - Consequently, `GLCanvas3D::render()` for `view3D` (Prepare tab) exited immediately on line `if (!m_enable_render) return;`, rendering nothing in the 3D GL pane.
    - Fixed by restoring `enable_render(true)` and calling `set_as_dirty()` in the postponed branch and after tab selection in `post_init()`.
    - Added auto-recovery in `GLCanvas3D::render()` so that whenever `_is_shown_on_screen()` is true, `m_enable_render` is automatically restored to `true`.
    - Updated `SwapBuffers()` to guard with `_is_shown_on_screen()` consistently.

---

## 2. Prerequisites

On your host machine:
- **Podman** installed.
- **Distrobox** installed (`which distrobox`).
- Ubuntu 24.04 image pulled:
  ```bash
  podman pull docker.io/library/ubuntu:24.04
  ```

---

## 3. Step-by-Step Reproduction Guide

### Step 3.1: Create and Initialize the Distrobox Container

Create an isolated build environment using the Ubuntu 24.04 image:

```bash
distrobox create --name orca-build --image docker.io/library/ubuntu:24.04 --yes
```

Enter the container once to initialize user integration:

```bash
distrobox enter orca-build --no-tty -- cat /etc/os-release
```

### Step 3.2: Install Build Dependencies inside Container

Install all build dependencies, including the optional development libraries:

```bash
distrobox enter orca-build --no-tty -- sudo apt update
distrobox enter orca-build --no-tty -- sudo apt install -y \
    autoconf \
    build-essential \
    cmake \
    eglexternalplatform-dev \
    extra-cmake-modules \
    file \
    g++ \
    gettext \
    git \
    gstreamer1.0-gtk3 \
    libcurl4-openssl-dev \
    libdbus-1-dev \
    libglew-dev \
    libgstreamerd-3-dev \
    libgtk-3-dev \
    libmspack-dev \
    libsecret-1-dev \
    libspnav-dev \
    libssl-dev \
    libtool \
    libudev-dev \
    clang \
    lld \
    nasm \
    ninja-build \
    texinfo \
    wget \
    libwebkit2gtk-4.1-dev \
    ccache \
    curl \
    m4 \
    locales \
    libnotify-dev \
    libjemalloc-dev \
    libmpfr-dev \
    libgmp-dev

# Generate UTF-8 locale
distrobox enter orca-build --no-tty -- sudo locale-gen en_US.UTF-8
```

### Step 3.3: Extract FlashNetwork 3.4.0 (`libFlashNetwork.so`)

Extract `libFlashNetwork.so` from the official Flashforge 1.7.9 Linux release:

```bash
mkdir -p ~/orca-flashforge/flashnetwork
cd ~/orca-flashforge/flashnetwork

curl -L -O https://github.com/FlashForge/Orca-Flashforge/releases/download/1.7.9/Flash.Studio_ubuntu24.04_V1.7.9.AppImage
chmod +x Flash.Studio_ubuntu24.04_V1.7.9.AppImage

./Flash.Studio_ubuntu24.04_V1.7.9.AppImage --appimage-extract "bin/*FlashNetwork*"

cp squashfs-root/bin/libFlashNetwork.so ~/orca-flashforge/libFlashNetwork.so

cd ~/orca-flashforge
rm -rf flashnetwork
```

### Step 3.4: Clone Repository & Checkout Branch

```bash
cd ~/orca-flashforge
git clone -b linux-fixes-1.7.15 https://github.com/THEBMOREJOKER/Orca-Flashforge.git source
cd source
```

### Step 3.5: Build Vendored Dependencies

Inside the container, build the bundled dependencies using Clang and `ld.lld`:

```bash
distrobox enter orca-build --no-tty -- bash -c "
  cd ~/orca-flashforge/source && \
  ./build_linux.sh -drlL
"
```

### Step 3.6: Compile Orca-Flashforge & Bundle AppImage

Build the slicer and package the AppImage, passing the path to `libFlashNetwork.so` with `-N`:

```bash
distrobox enter orca-build --no-tty -- bash -c "
  cd ~/orca-flashforge/source && \
  ./build_linux.sh -sirlL -N ~/orca-flashforge/libFlashNetwork.so
"
```

---

## 4. Output Artifacts

The final compiled AppImage is located at:

```
source/build/Flash Studio_ubuntu24.04_V1.7.15.AppImage
```

You can run it directly on the host machine:

```bash
chmod +x "source/build/Flash Studio_ubuntu24.04_V1.7.15.AppImage"
./"source/build/Flash Studio_ubuntu24.04_V1.7.15.AppImage"
```

---

## 5. Summary of Build Script Options

| Flag | Description |
|---|---|
| `-d` | Download and build dependencies in `./deps/` |
| `-s` | Compile the Orca-Flashforge slicer and tools |
| `-i` | Package into a standalone AppImage |
| `-r` | Skip RAM and disk checks (low memory compilation) |
| `-l` | Use Clang compiler |
| `-L` | Use `ld.lld` linker |
| `-N <file>` | Bundle the specified FlashNetwork library into `bin/` inside the AppImage |
