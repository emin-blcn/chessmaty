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
    PromotionRequest,
    PromotionByAI,
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