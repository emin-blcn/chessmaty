class_name Enums

enum Opponent
{
	LOCAL_HUMAN,
	LOCAL_AI
}

enum GameMode
{
	STANDARD,
	CHESS960
}

enum ChessColor
{
	WHITE,
	BLACK
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
	PROMOTION_REQUEST,
	PROMOTION_BY_AI,
	UNDO
}

enum MatchFinishedState
{
	NOT_FINISHED,
	WHITE_WON,
	BLACK_WON,
	FINISHED_DRAW
}
