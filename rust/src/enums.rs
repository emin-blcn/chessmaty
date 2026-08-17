use godot::prelude::*;

#[derive(GodotConvert, Var, Export, Clone, Copy, PartialEq, Eq, Debug)]
#[godot(via = i32)]
pub enum Opponent
{
    LocalHuman,
    LocalAI,
    LanHuman
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

#[derive(GodotConvert, Var, Export, Clone, Copy, PartialEq, Eq, Debug)]
#[godot(via = i32)]
pub enum Piece
{
	King,
	Queen,
	Bishop,
	Knight,
	Rook,
	Pawn,
    Empty
}

#[derive(GodotConvert, Var, Export, Clone, Copy, PartialEq, Eq, Debug)]
#[godot(via = i32)]
pub enum MoveType
{
    Normal,
    EnPassant,
    Castling,
    Promotion,
    PromotionRequestByHuman,
    PromotionRequestByAI,
    Undo
}

#[derive(GodotConvert, Var, Export, Clone, Copy, PartialEq, Eq, Debug)]
#[godot(via = i32)]
pub enum MatchFinishedState
{
    NotFinished,
    WhiteWon,
    BlackWon,
    FinishedDraw
}