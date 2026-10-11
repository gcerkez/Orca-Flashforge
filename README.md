# Orca-Flashforge
Orca-Flashforge is an open source slicer for FDM printers.

- Linux 64-bit (Ubuntu 24.04 / Podman / Distrobox / Native)  
  - Detailed Step-by-Step Guide: [BUILD_README.md](BUILD_README.md)
  - Foolproof One-Command Builder: [`./build_easy.sh`](build_easy.sh)
  - Advanced Build Script: [`./build_linux.sh`](build_linux.sh)

  **Quick Start on Ubuntu 24.04 (or inside Distrobox/Podman container):**
  ```bash
  # 1. Install all system & development dependencies:
  ./build_linux.sh -u

  # 2. Run one-command build (auto-detects FlashNetwork and dependencies):
  ./build_easy.sh
  ```
  *See [BUILD_README.md](BUILD_README.md) for full instructions on setting up an isolated build container, extracting `libFlashNetwork.so`, and build flags.*

- Windows 64-bit  
  - Tools needed: Visual Studio 2022, CMake, Git, Strawberry Perl.
  - Run `build_release.bat` in `x64 Native Tools Command Prompt for VS 2022`

- Mac 64-bit  
  - Tools needed: Xcode, CMake, Git, gettext, Automake, Perl
  - run `build_release_macos.sh`

# Linux Enhancements & Bug Fixes (Flash Studio / Orca-Flashforge 1.7.15)
This release incorporates critical stability fixes for modern Linux systems:
- **Crash Prevention on Wayland & X11**: Retains OpenGL dlopen handle in the GLAD loader, preventing null pointer crashes in `glad_glViewport` when navigating between Prepare, Preview, and Device tabs.
- **Prepare Tab GL Canvas Restoration**: Fixed the blank 3D pane issue on Linux by restoring `enable_render(true)` and dirty flags during delayed window mapping in Wayland/GTK.
- **FlashNetwork 3.4.0 Integration**: Accepts FlashNetwork 3.4.0 ([PR #69](https://github.com/FlashForge/Orca-Flashforge/pull/69)) so network printing, WAN/LAN printer discovery, and G-code upload work on Linux.
- **LAN Camera Streaming**: Implemented LAN stream control ([PR #39](https://github.com/FlashForge/Orca-Flashforge/pull/39)) directly to printer `/control` endpoints with port 8080 MJPEG fallback.
- **Model Filename Casing**: Fixed case-sensitive `.stl` vs `.STL` model filename mismatches for Adventurer 5M/Pro, AD5X, and Guider 3 Ultra profiles ([PR #74](https://github.com/FlashForge/Orca-Flashforge/pull/74)).
- **Packaging in Containers**: Added container detection for Distrobox/Podman to build standalone AppImages without host FUSE requirements.

# License
Orca-Flashforge is licensed under the GNU Affero General Public License, version 3. Orca-Flashforge is based on Orca Slicer by SoftFever.

Orca Slicer is licensed under the GNU Affero General Public License, version 3. Orca Slicer is based on Bambu Studio by BambuLab.

Bambu Studio is licensed under the GNU Affero General Public License, version 3. Bambu Studio is based on PrusaSlicer by PrusaResearch.

PrusaSlicer is licensed under the GNU Affero General Public License, version 3. PrusaSlicer is owned by Prusa Research. PrusaSlicer is originally based on Slic3r by Alessandro Ranellucci.

Slic3r is licensed under the GNU Affero General Public License, version 3. Slic3r was created by Alessandro Ranellucci with the help of many other contributors.

The GNU Affero General Public License, version 3 ensures that if you use any part of this software in any way (even behind a web server), your software must be released under the same license.

Orca-Flashforge includes a pressure advance calibration pattern test adapted from Andrew Ellis' generator, which is licensed under GNU General Public License, version 3. Ellis' generator is itself adapted from a generator developed by Sineos for Marlin, which is licensed under GNU General Public License, version 3.

The flashforge networking plugin is based on non-free libraries from FlashForge. It is optional to the Orca-Flashforge and provides extended functionalities for FlashForge printer users.
