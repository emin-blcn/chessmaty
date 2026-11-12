use shakmaty::{Position, Color, Move, Role, Square, EnPassantMode, CastlingMode};
use shakmaty::variant::{VariantPosition, Chess, KingOfTheHill, ThreeCheck, Crazyhouse, Antichess, Atomic, Horde, RacingKings};
use shakmaty::uci::UciMove;
use shakmaty::fen::Fen;
use shakmaty::zobrist::Zobrist64;
use godot::prelude::*;
use godot::global::randi_range;
use godot::classes::{RefCounted, IRefCounted};

use crate::enums;
use crate::chess_ai::ChessAI;


const ALL_FENS_STR: &str = include_str!("chess960_fens.txt");


#[derive(GodotClass)]
#[class(base=RefCounted)]
struct ChessLogic
{
    base: Base<RefCounted>,
    player_color: enums::ChessColor,
    game_mode: enums::GameMode,
    position: VariantPosition,
    position_history: Vec<VariantPosition>,
    repeated_position_hash_history: Vec<u64>,
    move_history: Vec<UciMove>,
    chess_ai: Option<ChessAI>
}


#[godot_api]
impl IRefCounted for ChessLogic
{
    fn init(base: Base<RefCounted>) -> Self
    {
        Self
        {
            base,
            player_color: enums::ChessColor::White,
            game_mode: enums::GameMode::Standard,
            position: VariantPosition::default(),
            position_history: Vec::<VariantPosition>::new(),
            repeated_position_hash_history: Vec::<u64>::new(),
            move_history: Vec::<UciMove>::new(),
            chess_ai: None
        }
    }
}


#[godot_api]
impl ChessLogic
{
    #[signal]
    fn move_applied(move_type: GString, from: GString, to: GString);
    #[signal]
    fn promotion_piece_updated(from: GString, to: GString, role: enums::PieceRole);
    #[signal]
    fn promotion_move_played_by_ai(from: GString, to: GString, role: enums::PieceRole);
    #[signal]
    fn put_move_applied(role: enums::PieceRole, to: GString);
    #[signal]
    fn undo_last_move_applied(double_undo: bool);


    #[func]
    fn setup(&mut self, data: Dictionary<GString, Variant>)
    {
        let player_color = data.get("player_color").unwrap().to::<enums::ChessColor>();
        let game_mode = data.get("game_mode").unwrap().to::<enums::GameMode>();
        let fen_string = data.get("fen_string").unwrap().to::<String>() + " w KQkq - 0 1";
        let connection_type = data.get("connection_type").unwrap().to::<enums::ConnectionType>();

        self.player_color = player_color;
        self.game_mode = game_mode;

        match connection_type
        {
            enums::ConnectionType::Local =>
            {
                match game_mode
                {
                    enums::GameMode::Standard => {
                        self.position = VariantPosition::Chess(Chess::default());
                    }
                    enums::GameMode::Chess960 => {
                        let fen = Fen::from_ascii(fen_string.as_bytes()).unwrap();
                        self.position = VariantPosition::Chess(fen.into_position(CastlingMode::Chess960).unwrap());
                    }
                    enums::GameMode::KingOfTheHill => {
                        self.position = VariantPosition::KingOfTheHill(KingOfTheHill::default())
                    }
                    enums::GameMode::ThreeCheck => {
                        self.position = VariantPosition::ThreeCheck(ThreeCheck::default())
                    }
                    enums::GameMode::CrazyHouse => {
                        self.position = VariantPosition::Crazyhouse(Crazyhouse::default())
                    }
                    enums::GameMode::AntiChess => {
                        self.position = VariantPosition::Antichess(Antichess::default())
                    }
                    enums::GameMode::Atomic => {
                        self.position = VariantPosition::Atomic(Atomic::default())
                    }
                    enums::GameMode::Horde => {
                        self.position = VariantPosition::Horde(Horde::default())
                    }
                    enums::GameMode::RacingKings => {
                        self.position = VariantPosition::RacingKings(RacingKings::default())
                    }
                }

                let local_opponent = data.get("local_opponent").unwrap().to::<enums::LocalOpponent>();

                if local_opponent == enums::LocalOpponent::AI
                {
                    let time_per_side = data.get("time_per_side").unwrap().to::<i64>();
                    let time_increment = data.get("time_increment").unwrap().to::<i64>();
                    let ai_skill_level = data.get("ai_skill_level").unwrap().to::<i64>();

                    self.chess_ai = Some(ChessAI::new(game_mode, fen_string, ai_skill_level, time_per_side, time_increment));
                }
            }
            enums::ConnectionType::Lan =>
            {
                self.position = match game_mode
                {
                    enums::GameMode::Standard => VariantPosition::Chess(Chess::default()),
                    enums::GameMode::Chess960 => {
                        let fen = Fen::from_ascii(fen_string.as_bytes()).unwrap();
                        VariantPosition::Chess(fen.into_position(CastlingMode::Chess960).unwrap())
                    }
                    enums::GameMode::KingOfTheHill => VariantPosition::KingOfTheHill(KingOfTheHill::default()),
                    enums::GameMode::ThreeCheck => VariantPosition::ThreeCheck(ThreeCheck::default()),
                    enums::GameMode::CrazyHouse => VariantPosition::Crazyhouse(Crazyhouse::default()),
                    enums::GameMode::AntiChess => VariantPosition::Antichess(Antichess::default()),
                    enums::GameMode::Atomic => VariantPosition::Atomic(Atomic::default()),
                    enums::GameMode::Horde => VariantPosition::Horde(Horde::default()),
                    enums::GameMode::RacingKings => VariantPosition::RacingKings(RacingKings::default()),
                }
            }
        }

        self.update_repeated_position_hash_history();
    }


    #[func]
    fn random_fen() -> GString
    {
        let all_fens_vector: Vec<&str> = ALL_FENS_STR.lines().collect();
        let random_number = randi_range(0, 960 - 1) as usize;

        format!("{}/pppppppp/8/8/8/8/PPPPPPPP/{}", all_fens_vector[random_number], all_fens_vector[random_number].to_uppercase()).to_gstring()
    }


    #[func]
    fn active_board_fen(&self) -> GString
    {
        self.position.board().board_fen().to_string().to_gstring()
    }


    #[func]
    fn piece_role_from_square(&self, square: String) -> enums::PieceRole
    {
        let square = Square::from_ascii(square.as_bytes()).unwrap();

        match self.position.board().piece_at(square)
        {
            Some(piece) =>
            {
                match piece.role
                {
                    Role::King => enums::PieceRole::King,
                    Role::Queen => enums::PieceRole::Queen,
                    Role::Rook => enums::PieceRole::Rook,
                    Role::Bishop => enums::PieceRole::Bishop,
                    Role::Knight => enums::PieceRole::Knight,
                    Role::Pawn => enums::PieceRole::Pawn
                }
            }
            None => enums::PieceRole::Empty
        }
    }


    #[func]
    fn piece_role_from_square_in_put_move(&self, square: String) -> enums::PieceRole
    {
        let square = Square::from_ascii(square.as_bytes()).unwrap();

        match self.position.board().piece_at(square)
        {
            Some(piece) =>
            {
                if self.position.promoted().contains(square)
                {
                    enums::PieceRole::Pawn
                }
                else
                {
                    match piece.role
                    {
                        Role::King => enums::PieceRole::King,
                        Role::Queen => enums::PieceRole::Queen,
                        Role::Rook => enums::PieceRole::Rook,
                        Role::Bishop => enums::PieceRole::Bishop,
                        Role::Knight => enums::PieceRole::Knight,
                        Role::Pawn => enums::PieceRole::Pawn
                    }
                }
            }
            None => enums::PieceRole::Empty
        }
    }


    #[func]
    fn piece_color_from_square(&self, square: String) -> enums::ChessColor
    {
        let square = Square::from_ascii(square.as_bytes()).unwrap();

        match self.position.board().piece_at(square)
        {
            Some(piece) =>
            {
                match piece.color
                {
                    Color::White => enums::ChessColor::White,
                    Color::Black => enums::ChessColor::Black
                }
            }
            _ => panic!()
        }
    }


    #[func]
    fn active_turn(&self) -> enums::ChessColor
    {
        match self.position.turn()
        {
            Color::White => enums::ChessColor::White,
            Color::Black => enums::ChessColor::Black
        }
    }


    #[func]
    fn crazyhouse_pockets(&self) -> Array<Vector3i> // x = color, y = role, z = value
    {
        let pockets = self.position.pockets().unwrap();
        let mut pockets_for_godot = Array::<Vector3i>::new();

        for color in [enums::ChessColor::White, enums::ChessColor::Black]
        {
            for role in [enums::PieceRole::Queen, enums::PieceRole::Rook, enums::PieceRole::Bishop, enums::PieceRole::Knight, enums::PieceRole::Pawn]
            {
                let shakmaty_color = match color
                {
                    enums::ChessColor::White => Color::White,
                    enums::ChessColor::Black => Color::Black
                };
                
                let shakmaty_role = match role
                {
                    enums::PieceRole::Queen
                    | enums::PieceRole::Empty
                    | enums::PieceRole::King => Role::Queen,
                    enums::PieceRole::Rook => Role::Rook,
                    enums::PieceRole::Bishop => Role::Bishop,
                    enums::PieceRole::Knight => Role::Knight,
                    enums::PieceRole::Pawn => Role::Pawn
                };

                pockets_for_godot.push(
                    Vector3i::new(
                        color as i32,
                        role as i32,
                        pockets[shakmaty_color][shakmaty_role] as i32
                    )
                );
            }
        }

        pockets_for_godot
    }


    #[func]
    fn legal_moves_from_square(&self, from: GString) -> Dictionary<GString, enums::MoveType>
    {
        let mut legal_moves_for_godot = Dictionary::<GString, enums::MoveType>::new();
        let from = Square::from_ascii(from.to_string().as_bytes()).unwrap();

        for legal_move in self.position.legal_moves()
        {
            if legal_move.is_put()
            {
                continue;
            }
            else if legal_move.from().unwrap() == from
            {// shakmaty legal move square == selected square from Godot, add move to Godot legal move list
                let to = legal_move.to();
                let to_as_gstring = to.to_string().to_gstring();
                if !legal_moves_for_godot.contains_key(&to_as_gstring)
                {
                    match legal_move
                    {
                        Move::Normal {..} =>
                        {
                            if legal_move.is_promotion()
                            {
                                legal_moves_for_godot.set(&to_as_gstring, enums::MoveType::Promotion);
                            }
                            else
                            {
                                legal_moves_for_godot.set(&to_as_gstring, enums::MoveType::Normal);
                            }
                        }
                        Move::EnPassant {..} =>
                        {
                            legal_moves_for_godot.set(&to_as_gstring, enums::MoveType::EnPassant);
                        }
                        Move::Castle{..} =>
                        {
                            legal_moves_for_godot.set(&to_as_gstring, enums::MoveType::Castling);
                        }
                        _ => {}
                    };
                }
            }
        }

        legal_moves_for_godot
    }



    #[func]
    fn legal_put_moves_from_role(&self, piece_role: enums::PieceRole) -> PackedStringArray
    {
        let mut legal_put_moves_for_godot = PackedStringArray::new();

        for legal_move in self.position.legal_moves()
        {
            if let Move::Put { role, to } = legal_move
            {
                let target_role = match piece_role
                {
                    enums::PieceRole::Queen => Role::Queen,
                    enums::PieceRole::Rook => Role::Rook,
                    enums::PieceRole::Bishop => Role::Bishop,
                    enums::PieceRole::Knight => Role::Knight,
                    enums::PieceRole::Pawn => Role::Pawn,
                    _ => Role::Pawn
                };

                if role == target_role
                {
                    legal_put_moves_for_godot.push(&to.to_string().to_gstring());
                }
            }
        }
        legal_put_moves_for_godot
    }


    #[func]
    fn apply_normal_move(&mut self, from: String, to: String)
    {
        let from_square = Square::from_ascii(from.as_bytes()).unwrap();
        let to_square = Square::from_ascii(to.as_bytes()).unwrap();
        let mut play_move_option: Option<Move> = None;

        for legal_move in self.position.legal_moves()
        {
            // check if Godot move from-to square match Shakmaty legal move from-to square to find the Move object
            if legal_move.from().unwrap() == from_square && legal_move.to() == to_square
            {
                play_move_option = Some(legal_move);
                break;
            }
        }

        self.update_position_history();

        let play_move = play_move_option.unwrap();
        self.position = self.position.clone().play(play_move).unwrap();
        self.update_move_history(play_move);
        self.update_repeated_position_hash_history();

        self.base_mut().emit_signal("move_applied", &[enums::MoveType::Normal.to_variant(), from.to_variant(), to.to_variant()]);
    }


    #[func]
    fn apply_en_passant_move(&mut self, from: String, to: String)
    {

        let from_square = Square::from_ascii(from.as_bytes()).unwrap();
        let to_square = Square::from_ascii(to.as_bytes()).unwrap();
        let mut play_move_option: Option<Move> = None;

        for legal_move in self.position.legal_moves()
        {
            // check if Godot move from-to square match Shakmaty legal move from-to square to find the Move object
            if legal_move.from().unwrap() == from_square && legal_move.to() == to_square
            {
                play_move_option = Some(legal_move);
                break;
            }
        }

        self.update_position_history();

        let play_move = play_move_option.unwrap();
        self.position = self.position.clone().play(play_move).unwrap();
        self.update_move_history(play_move);
        self.update_repeated_position_hash_history();

        self.base_mut().emit_signal("move_applied", &[enums::MoveType::EnPassant.to_variant(), from.to_variant(), to.to_variant()]);
    }


    #[func]
    fn apply_castling_move(&mut self, from: String, to: String)
    {
        let from_square = Square::from_ascii(from.as_bytes()).unwrap();
        let to_square = Square::from_ascii(to.as_bytes()).unwrap();
        let mut play_move_option: Option<Move> = None;

        for legal_move in self.position.legal_moves()
        {
            // check if Godot move from-to square match Shakmaty legal move from-to square to find the Move object
            if legal_move.from().unwrap() == from_square && legal_move.to() == to_square
            {
                play_move_option = Some(legal_move);
                break;
            }
        }

        self.update_position_history();

        let play_move = play_move_option.unwrap();
        self.position = self.position.clone().play(play_move).unwrap();
        self.update_move_history(play_move);
        self.update_repeated_position_hash_history();

        self.base_mut().emit_signal("move_applied", &[enums::MoveType::Castling.to_variant(), from.to_variant(), to.to_variant()]);
    }


    #[func]
    fn apply_promotion_move(&mut self, from: String, to: String, new_role: enums::PieceRole)
    {
        let from_square = Square::from_ascii(from.as_bytes()).unwrap();
        let to_square = Square::from_ascii(to.as_bytes()).unwrap();
        let mut play_move_option: Option<Move> = None;
        let role = match new_role
        {
            enums::PieceRole::Queen => Role::Queen,
            enums::PieceRole::Bishop => Role::Bishop,
            enums::PieceRole::Knight => Role::Knight,
            enums::PieceRole::Rook => Role::Rook,
            _ => panic!()
        };

        for legal_move in self.position.legal_moves()
        {
            // check if Godot move from-to square match Shakmaty legal move from-to square to find the Move object
            if legal_move.from().unwrap() == from_square && legal_move.to() == to_square && legal_move.promotion().unwrap() == role
            {
                play_move_option = Some(legal_move);
                break;
            }
        }

        self.update_position_history();

        let play_move = play_move_option.unwrap();
        self.position = self.position.clone().play(play_move).unwrap();
        self.update_move_history(play_move);
        self.update_repeated_position_hash_history();

        self.base_mut().emit_signal("promotion_piece_updated", &[from.to_variant(), to.to_variant(), new_role.to_variant()]);
    }


    #[func]
    fn apply_put_move(&mut self, role: enums::PieceRole, to: String)
    {
        let role_object = match role
        {
            enums::PieceRole::Queen => Role::Queen,
            enums::PieceRole::Rook => Role::Rook,
            enums::PieceRole::Bishop => Role::Bishop,
            enums::PieceRole::Knight => Role::Knight,
            enums::PieceRole::Pawn => Role::Pawn,
            _ => Role::Queen
        };
        let to_square = Square::from_ascii(to.as_bytes()).unwrap();
        let mut play_move_option = None::<Move>;

        for legal_move in self.position.legal_moves()
        {
            if let Move::Put{role: r, to: t} = legal_move && r == role_object && t == to_square
            {
                play_move_option = Some(legal_move);
                break;
            }
        }

        self.update_position_history();

        let play_move = play_move_option.unwrap();
        self.position = self.position.clone().play(play_move).unwrap();
        self.update_move_history(play_move);
        self.update_repeated_position_hash_history();

        self.base_mut().emit_signal("put_move_applied", &[role.to_variant(), to.to_variant()]);
    }


    fn update_move_history(&mut self, new_move: Move)
    {
        self.move_history.push(UciMove::from_move(new_move, CastlingMode::Chess960));
    }


    #[func]
    fn position_history_count(&self) -> i64
    {
        self.position_history.len() as i64
    }

    
    fn update_position_history(&mut self)
    {
        self.position_history.push(self.position.clone());
    }


    fn update_repeated_position_hash_history(&mut self)
    {
        if self.position.halfmoves() == 0
        {
            self.repeated_position_hash_history.clear();
        }

        let new_board_hash = self.position.zobrist_hash::<Zobrist64>(EnPassantMode::Legal).0;
        self.repeated_position_hash_history.push(new_board_hash);
    }


    #[func]
    fn undo_last_move(&mut self, double_undo: bool)
    {
        // undo full move if double_undo, undo half move if not double_undo
        for _ in 0..2
        {
            if self.position_history.is_empty()
            {
                break;
            }

            let _ = self.move_history.pop();
            let _ = self.repeated_position_hash_history.pop();
            self.position = self.position_history.pop().unwrap();

            if !double_undo
            {
                break;
            }
        }
        
        self.base_mut().emit_signal("undo_last_move_applied", &[double_undo.to_variant()]);
    }


    #[func]
    fn best_ai_move(&self, white_time_left: i64, black_time_left: i64) -> GString
    {
        let best_move = self.chess_ai.as_ref().unwrap().best_move(&self.move_history, white_time_left, black_time_left);
        GString::from(&best_move)
    }


    #[func]
    fn stop_ai_thinking(&self)
    {
        self.chess_ai.as_ref().unwrap().stop_ai_thinking();
    }


    #[func]
    fn play_ai_move(&mut self, best_ai_move: String)
    {
        let play_move = UciMove::from_ascii(best_ai_move.as_bytes()).unwrap().to_move(&self.position).unwrap();
        let from = match play_move.from()
        {
            Some(square) => square.to_string(),
            None => String::new()
        };
        let to = play_move.to().to_string();

        match play_move
        {
            Move::Normal {..} =>
            {
                if play_move.is_promotion()
                {
                    let role = match play_move.promotion().unwrap()
                    {
                        Role::Queen => enums::PieceRole::Queen,
                        Role::Rook => enums::PieceRole::Rook,
                        Role::Bishop => enums::PieceRole::Bishop,
                        Role::Knight => enums::PieceRole::Knight,
                        _ => enums::PieceRole::Queen
                    };
                    // AI made promotion move, don't call apply_promotion_move(), emit Godot signal, Godot will call apply_promotion_move() function
                    self.base_mut().emit_signal("promotion_move_played_by_ai", &[from.to_variant(), to.to_variant(), role.to_variant()]);
                }
                else
                {
                    self.apply_normal_move(from, to);
                }
            }
            Move::EnPassant {..} => self.apply_en_passant_move(from, to),
            Move::Castle {..} => self.apply_castling_move(from, to),
            Move::Put { role, .. } =>
            {
                let role = match role
                {
                    Role::Queen => enums::PieceRole::Queen,
                    Role::Rook => enums::PieceRole::Rook,
                    Role::Bishop => enums::PieceRole::Bishop,
                    Role::Knight => enums::PieceRole::Knight,
                    Role::Pawn => enums::PieceRole::Pawn,
                    _ => panic!()
                };
                self.apply_put_move(role, to);
            }
        }
    }


    #[func]
    fn white_checks(&self) -> i64
    {
        if let Some(remaining_checks) = self.position.remaining_checks()
        {
            3 - i64::from(remaining_checks.white)
        }
        else
        {
            0
        }
    }


    #[func]
    fn black_checks(&self) -> i64
    {
        if let Some(remaining_checks) = self.position.remaining_checks()
        {
            3 - i64::from(remaining_checks.black)
        }
        else
        {
            0
        }
    }


    #[func]
    fn king_in_danger_square(&self) -> GString
    {
        if self.position.is_check()
        {// any king is in danger
            GString::from(&self.position.board().king_of(self.position.turn()).unwrap().to_string())
        }
        else
        {// no king is in danger
            GString::new()
        }
    }


    #[func]
    fn match_finished_state(&self) -> enums::MatchFinishedState
    {
        if self.position.is_game_over()
        {
            match self.position.outcome()
            {
                shakmaty::Outcome::Known(known_outcome) =>
                {
                    match known_outcome
                    {
                        shakmaty::KnownOutcome::Decisive {winner} =>
                        {
                            match winner
                            {
                                Color::White => return enums::MatchFinishedState::WhiteWon,
                                Color::Black => return enums::MatchFinishedState::BlackWon
                            }
                        }
                        shakmaty::KnownOutcome::Draw => return  enums::MatchFinishedState::FinishedDraw
                    }
                }
                shakmaty::Outcome::Unknown =>
                {
                    godot_error!("[{}:{}] Unknown Outcome", file!(), line!());
                }
            }
        }

        // check 3 repeated positions
        let repeated_board_count: u8 = match self.repeated_position_hash_history.last()
        {
            None => 0,
            Some(last_board_hash) =>
            {
                let mut value = 0u8;

                for board_hash in &self.repeated_position_hash_history
                {
                    if last_board_hash == board_hash
                    {
                        value += 1;
                    }
                }
                value
            }
        };

        // check halfmoves over 100
        if repeated_board_count >= 3 || self.position.halfmoves() >= 100
        {
            return enums::MatchFinishedState::FinishedDraw;
        }

        enums::MatchFinishedState::NotFinished
    }
}