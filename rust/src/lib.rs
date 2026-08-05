mod chess_logic;
mod chess_engine;
mod enums;


use godot::prelude::*;


struct Rust;


#[gdextension]
unsafe impl ExtensionLibrary for Rust {}
