use godot::prelude::*;


#[derive(GodotConvert, Var, Export, Clone, Copy, PartialEq, Eq, Debug)]
#[godot(via = i32)]
pub enum ConnectionType
{
    Local,
    Lan
}

#[derive(GodotConvert, Var, Export, Clone, Copy, PartialEq, Eq, Debug)]
#[godot(via = i32)]
pub enum LocalOpponent
{
    Human,
    AI
}

#[derive(GodotConvert, Var, Export, Clone, Copy, PartialEq, Eq, Debug)]
#[godot(via = i32)]
pub enum GameMode
{
    Standard,
    Chess960,
    KingOfTheHill,
    ThreeCheck,
    CrazyHouse,
    AntiChess,
    Atomic,
    Horde,
    RacingKings
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
pub enum PieceRole
{
	King,
	Queen,
    Rook,
	Bishop,
	Knight,
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
    Put
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