use godot::prelude::*;

#[derive(GodotConvert, Var, Export, Clone, Copy, PartialEq, Eq, Debug)]
#[godot(via = i32)]
pub enum Opponent
{
    LocalHuman,
    LocalAI
}

#[derive(GodotConvert, Var, Export, Clone, Copy, PartialEq, Eq, Debug)]
#[godot(via = i32)]
pub enum GameMode
{
    Standard,
    Chess960
}


#[derive(GodotConvert, Var, Export, Clone, Copy, PartialEq, Eq, Debug)]
#[godot(via = i32)]
pub enum ChessColor
{
    White,
    Black
}