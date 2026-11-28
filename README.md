[![Release](https://img.shields.io/badge/Release-v1.0.3-blue)](https://github.com/emin-blcn/chessmaty/releases/tag/v1.0.3)
[![License](https://img.shields.io/badge/License-GPL--3.0-green)](https://opensource.org/license/gpl-3.0)


<p align="center">
  <img src="preview.gif" alt="Chessmaty Game Variants" width="640" height="360">
</p>

<img src="godot/assets/graphics/icon.png" alt="Godot Engine" width="64"/>

<br>

♟️ **Chessmaty** is a pixel art chess game, created with Godot Engine and Rust's Shakmaty crate.

<br>

## Table of Contents

[Architecture](#architecture) • [Supported Play Modes](#supported-play-modes) • [Game Variants](#game-variants) • [Used Tools](#used-tools) • [Credits & Assets](#credits--assets) • [Building from Source](#building-from-source)

<br>

## Architecture

Rust and shakmaty power the core chess logic, move generation, and rule evaluation, while Godot handles the user interface, input processing and board rendering.

Asynchronous processing and background tasks are managed by Godot threads rather than an async Rust runtime.

The Rust crate is compiled into a dynamic C library (.dll and .so) and Godot uses this library as a GDExtension via the C ABI.

<br>

## Supported Play Modes
- **Local Multiplayer:** Same-device Human vs. Human play.
- **Local AI:** Single-player mode against Fairy-Stockfish (supporting chess variants).
- **LAN Multiplayer:** Play over a Local Area Network.

<br>

## Game Variants

Chessmaty supports 9 different chess variants (inspired by Lichess):

- **Standard:** Classic chess rules and setup.
- **Chess960:** Starting piece positions are randomized.
- **King of the Hill:** Bring your King to the center of the board to win.
- **Three-Check:** Check your opponent's King three times to win.
- **Crazyhouse:** Captured pieces join your pocket and can be dropped back onto the board.
- **Antichess:** Lose all your pieces or get stalemated to win.
- **Atomic:** Captures cause explosions that destroy surrounding non-pawn pieces.
- **Horde:** One side plays with a massive army of Pawns against standard pieces.
- **Racing Kings:** Race your King to the 8th rank before your opponent does.

<br>

## Used Tools

<table align="center">
  <tr>
    <td align="center" width="160">
      <a href="https://godotengine.org/" target="_blank">
        <img src="https://raw.githubusercontent.com/godotengine/godot/73ca6be2cebd5192d8b279979d04f29ea45c266e/misc/logo/icon.svg" width="100" alt="Godot Engine"/><br><br>
        <b>Godot Engine</b>
      </a>
    </td>
    <td align="center" width="160">
      <a href="https://godot-rust.github.io/" target="_blank">
        <img src="https://raw.githubusercontent.com/godot-rust/assets/762d100e6aefc96c9e2797de72a7461d103cf6ed/gdext/ferris.svg" width="100" alt="godot-rust"/><br><br>
        <b>godot-rust</b>
      </a>
    </td>
    <td align="center" width="160">
      <a href="https://crates.io/crates/shakmaty" target="_blank">
        <img src="https://github.com/rust-lang/crates.io/blob/0e7349bf438cc9d541312a131a82cca6005d0201/svelte/src/lib/assets/cargo.png?raw=true" width="100" alt="Shakmaty"/><br><br>
        <b>Shakmaty</b>
      </a>
    </td>
    <td align="center" width="160">
      <a href="https://fairy-stockfish.github.io/" target="_blank">
        <img src="https://github.com/fairy-stockfish/fairy-stockfish.github.io/blob/6c726ec48bbff68b09574082e432de78873c4bd1/assets/images/fairyfish2-192x192.png?raw=true" width="100" alt="Fairy-Stockfish"/><br><br>
        <b>Fairy-Stockfish</b>
      </a>
    </td>
  </tr>
</table>

<br>

## Credits & Assets
- [Pixel Chess](https://nulltale.itch.io/chess) - sprites by [Nulltale](https://nulltale.itch.io/)
- [Monogram ](https://datagoblin.itch.io/monogram) - font by [Datagoblin](https://datagoblin.itch.io/)
- [Bold Pixels](https://yukipixels.itch.io/boldpixels) - font by [Yūki](https://linktr.ee/yukipixels)
- [Sound effects](https://github.com/lichess-org/lila/tree/63ce12333414a2762f2f042e18e3dd528845adda/public/sound) - sourced from Lichess

<br>

## Building From Source
To ensure GDExtension bindings and library paths match correctly, please follow the build instructions for your operating system.

**Prerequisites**
- **Godot Engine** (v4.x)
- **Rust Toolchain** (`cargo`, `rustc`)
- `cargo-xwin` for targeting Windows binaries *(Cross-Compilation from Linux only)*
- **Fairy-Stockfish** binary (executable) file.

<br>

**To play against the AI,** you need to provide the **Fairy-Stockfish** engine binary files. For download links and instructions please check the [bin/README.md](bin/README.md) file.

<br>

**If cross-compiling,** add the required targets via **rustup**: `rustup target add x86_64-pc-windows-msvc x86_64-unknown-linux-gnu`

<br>

*See also the [rust_build_scripts_from_linux folder](rust_build_scripts_from_linux) and the [GDExtension file](godot/gdextensions/rust.gdextension)*

<br>

**For Linux x86-64**

- **Debug Build:**
  - **Source:** `PROJECT_ROOT/rust/target/x86_64-unknown-linux-gnu/debug/libchessmaty_rust.so`

  - **Move to:** `PROJECT_ROOT/godot/lib/libchessmaty_rust_linux_x86_64_debug.so`



- **Release Build:**
  - **Source:** `PROJECT_ROOT/rust/target/x86_64-unknown-linux-gnu/release/libchessmaty_rust.so`

  - **Move to:** `PROJECT_ROOT/godot/lib/libchessmaty_rust_linux_x86_64_release.so`

<br>

**For Windows x86-64**

- **Debug Build:**
  - **Source:** `PROJECT_ROOT/rust/target/x86_64-pc-windows-msvc/debug/chessmaty_rust.dll`

  - **Move to:** `PROJECT_ROOT/godot/lib/libchessmaty_rust_windows_x86_64_debug.dll`

<br>

- **Release Build:**
  - **Source:** `PROJECT_ROOT/rust/target/x86_64-pc-windows-msvc/release/chessmaty_rust.dll`

  - **Move to:** `PROJECT_ROOT/godot/lib/libchessmaty_rust_windows_x86_64_release.dll`

<br>

> **Note on Default Build Paths:**
>
> If you compile without specifying a target platform (e.g. standard `cargo build`), the output binary location will omit the target platform directory:
> - Linux Debug: `PROJECT_ROOT/rust/target/debug/libchessmaty_rust.so`
> - Linux Release: `PROJECT_ROOT/rust/target/release/libchessmaty_rust.so`
> - Windows Debug: `PROJECT_ROOT/rust/target/debug/chessmaty_rust.dll`
> - Windows Release: `PROJECT_ROOT/rust/target/release/chessmaty_rust.dll`

<br>

> **Important (Godot Export)**
>
> When exporting the project from Godot, the compiled library binary (.dll / .so) must be located in the same directory as the game executable file.

<br>

## A Note on UI & Design
Most of my effort went into the backend engine rather than a pixel-perfect UI layout—mostly because I'm not very good at creating visual interfaces.
The interface is currently very simple and basic.
