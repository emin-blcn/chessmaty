mod chess_logic;
mod chess_engine;
mod lan_host;
mod lan_peer;
mod lan_protocol;
mod enums;

use godot::prelude::*;

struct Rust;

#[gdextension]
unsafe impl ExtensionLibrary for Rust {}