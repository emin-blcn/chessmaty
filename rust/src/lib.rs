use godot::init::{gdextension, ExtensionLibrary};


pub mod chess_logic;
pub mod chess_ai;
pub mod lan_host;
pub mod lan_peer;
pub mod lan_protocol;
pub mod enums;


struct Rust;


#[gdextension]
unsafe impl ExtensionLibrary for Rust {}
