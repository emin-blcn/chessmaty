class_name Enums

enum ChessColor
{
	WHITE,
	BLACK
}

enum GameMode
{
	STANDARD,
	CHESS960,
	KING_OF_THE_HILL,
	THREE_CHECK
}

enum ConnectionType
{
	LOCAL,
	LAN
}

enum LocalOpponent
{
	HUMAN,
	AI
}

enum Piece
{
	KING,
	QUEEN,
	BISHOP,
	KNIGHT,
	ROOK,
	PAWN,
	EMPTY
}

enum MoveType
{
	NORMAL,
	EN_PASSANT,
	CASTLING,
	PROMOTION,
	PROMOTION_REQUEST_BY_HUMAN,
	PROMOTION_REQUEST_BY_AI,
	UNDO
}

enum MatchFinishedState
{
	NOT_FINISHED,
	WHITE_WON,
	BLACK_WON,
	FINISHED_DRAW
}
