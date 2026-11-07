use godot::init::{ExtensionLibrary, gdextension};

mod chess_logic;
mod chess_ai;
mod lan_host;
mod lan_peer;
mod lan_protocol;
mod enums;

struct Rust;

#[gdextension]
unsafe impl ExtensionLibrary for Rust{}