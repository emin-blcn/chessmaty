mod chess_logic;
mod chess_engine;
mod lan_stream;
mod lan_client;
mod enums;


use godot::prelude::*;


struct Rust;


#[gdextension]
unsafe impl ExtensionLibrary for Rust {}
