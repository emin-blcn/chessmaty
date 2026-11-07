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
	THREE_CHECK,
	CRAZY_HOUSE,
	ANTI_CHESS,
	ATOMIC,
	HORDE,
	RACING_KINGS
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

enum PieceRole
{
	KING,
	QUEEN,
	ROOK,
	BISHOP,
	KNIGHT,
	PAWN,
	EMPTY
}

enum MoveType
{
	NORMAL,
	EN_PASSANT,
	CASTLING,
	PROMOTION,
	PUT
}

enum MatchFinishedState
{
	NOT_FINISHED,
	WHITE_WON,
	BLACK_WON,
	FINISHED_DRAW
}
