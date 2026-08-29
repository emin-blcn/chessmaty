use shakmaty::{Position, Color, Move, Role, Square, EnPassantMode, CastlingMode};
use shakmaty::variant::{VariantPosition, Chess, KingOfTheHill, ThreeCheck};
use shakmaty::uci::UciMove;
use shakmaty::fen::Fen;
use shakmaty::zobrist::Zobrist64;
use godot::prelude::*;
use godot::global::randi_range;
use godot::classes::{RefCounted, IRefCounted};

use crate::chess_engine::ChessEngine;
use crate::enums as Enums;


static ALL_FENS_STR: &str = include_str!("fens.txt");


#[derive(GodotClass)]
#[class(base=RefCounted)]
struct ChessLogic
{
    base: Base<RefCounted>,
    player_color: Enums::ChessColor,
    game_mode: Enums::GameMode,
    position: VariantPosition,
    position_history: Vec<VariantPosition>,
    repeated_position_hash_history: Vec<u64>,
    move_history: Vec<UciMove>,
    local_chess_engine: Option<ChessEngine>
}


#[godot_api]
impl IRefCounted for ChessLogic
{
    fn init(base: Base<RefCounted>) -> Self
    {
        Self
        {
            base,
            player_color: Enums::ChessColor::White,
            game_mode: Enums::GameMode::Standard,
            position: VariantPosition::default(),
            position_history: Vec::<VariantPosition>::new(),
            repeated_position_hash_history: Vec::<u64>::new(),
            move_history: Vec::<UciMove>::new(),
            local_chess_engine: None
        }
    }
}


#[godot_api]
impl ChessLogic
{
    #[signal]
    fn move_applied(move_type: GString, from: GString, to: GString, ai_selected_new_promotion_role: Enums::Piece);


    #[func]
    fn config(&mut self, config_data: Dictionary<GString, Variant>)
    {
        let player_color = config_data.get("player_color").unwrap().to::<Enums::ChessColor>();
        let game_mode = config_data.get("game_mode").unwrap().to::<Enums::GameMode>();
        let fen_string = config_data.get("fen_string").unwrap().to::<String>();
        let connection_type = config_data.get("connection_type").unwrap().to::<Enums::ConnectionType>();

        self.player_color = player_color;
        self.game_mode = game_mode;

        match connection_type
        {
            Enums::ConnectionType::Local =>
            {
                match game_mode
                {
                    Enums::GameMode::Standard =>
                    {
                        self.position = VariantPosition::Chess(Chess::default());
                    }
                    Enums::GameMode::Chess960 =>
                    {
                        let fen: Fen = fen_string.parse().unwrap();
                        self.position = VariantPosition::Chess(fen.into_position(CastlingMode::Chess960).unwrap());
                    }
                    Enums::GameMode::KingOfTheHill =>
                    {
                        self.position = VariantPosition::KingOfTheHill(KingOfTheHill::default())
                    }
                    Enums::GameMode::ThreeCheck =>
                    {
                        self.position = VariantPosition::ThreeCheck(ThreeCheck::default())
                    }
                }

                let local_opponent = config_data.get("local_opponent").unwrap().to::<Enums::LocalOpponent>();

                if local_opponent == Enums::LocalOpponent::AI
                {
                    let time_per_side = config_data.get("time_per_side").unwrap().to::<i64>();
                    let time_increment = config_data.get("time_increment").unwrap().to::<i64>();
                    let ai_skill_level = config_data.get("ai_skill_level").unwrap().to::<i64>();

                    self.local_chess_engine = Some(ChessEngine::new(game_mode, fen_string, ai_skill_level, time_per_side, time_increment));
                }
            }
            Enums::ConnectionType::Lan =>
            {
                match game_mode
                {
                    Enums::GameMode::Standard =>
                    {
                        self.position = VariantPosition::Chess(Chess::default());
                    }
                    Enums::GameMode::Chess960 =>
                    {
                        let fen: Fen = fen_string.parse().unwrap();
                        self.position = VariantPosition::Chess(fen.into_position(CastlingMode::Chess960).unwrap());
                    }
                    Enums::GameMode::KingOfTheHill =>
                    {
                        self.position = VariantPosition::KingOfTheHill(KingOfTheHill::default())
                    }
                    Enums::GameMode::ThreeCheck =>
                    {
                        self.position = VariantPosition::ThreeCheck(ThreeCheck::default())
                    }
                }
            }
        }

        self.update_repeated_position_hash_history();
    }


    #[func]
    fn random_fen() -> String
    {
        let all_fens_vector: Vec<&str> = ALL_FENS_STR.lines().collect();
        let random_number = randi_range(0, 960 - 1) as usize;

        format!("{}/pppppppp/8/8/8/8/PPPPPPPP/{} w KQkq - 0 1", all_fens_vector[random_number], all_fens_vector[random_number].to_uppercase())
    }


    #[func]
    fn piece_from_square(&self, square: String) -> Enums::Piece
    {
        let square = Square::from_ascii(square.as_bytes()).unwrap();

        match self.position.board().piece_at(square)
        {
            Some(piece) =>
            {
                match piece.role
                {
                    Role::King => Enums::Piece::King,
                    Role::Queen => Enums::Piece::Queen,
                    Role::Bishop => Enums::Piece::Bishop,
                    Role::Knight => Enums::Piece::Knight,
                    Role::Rook => Enums::Piece::Rook,
                    Role::Pawn => Enums::Piece::Pawn
                }
            }
            None => Enums::Piece::Empty
        }
    }


    #[func]
    fn piece_color_from_square(&self, square: String) -> Enums::ChessColor
    {
        let square = Square::from_ascii(square.as_bytes()).unwrap();

        match self.position.board().piece_at(square)
        {
            Some(piece) =>
            {
                match piece.color
                {
                    Color::White => Enums::ChessColor::White,
                    Color::Black => Enums::ChessColor::Black
                }
            }
            _ => panic!()
        }
    }


    #[func]
    fn turn(&self) -> Enums::ChessColor
    {
        match self.position.turn()
        {
            Color::White => Enums::ChessColor::White,
            Color::Black => Enums::ChessColor::Black
        }
    }


    #[func]
    fn legal_moves_from_square(&mut self, square: String) -> Dictionary<GString, Enums::MoveType>
    {
        let mut legal_moves_for_godot = Dictionary::<GString, Enums::MoveType>::new();

        for legal_move in self.position.legal_moves()
        {
            if legal_move.from().unwrap().to_string() == square
            {// shakmaty legal move square == selected square from Godot, add move to Godot legal move list
                let to_square = legal_move.to().to_string().to_gstring();

                if !legal_moves_for_godot.contains_key(&to_square)
                {
                    match legal_move
                    {
                        Move::Normal {..} =>
                        {
                            if legal_move.is_promotion()
                            {
                                let _ = legal_moves_for_godot.insert(&to_square,Enums::MoveType::Promotion);
                            }
                            else
                            {
                                let _ = legal_moves_for_godot.insert(&to_square,Enums::MoveType::Normal);
                            }
                        }
                        Move::EnPassant {..} =>
                        {
                            let _ = legal_moves_for_godot.insert(&to_square,Enums::MoveType::EnPassant);
                        }
                        Move::Castle{..} =>
                        {
                            let _ = legal_moves_for_godot.insert(&to_square,Enums::MoveType::Castling);
                        }
                        _ => {}
                    };
                }
            }
        }

        legal_moves_for_godot
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

        self.base_mut().emit_signal("move_applied", &[Enums::MoveType::Normal.to_variant(), from.to_variant(), to.to_variant(), Enums::Piece::Empty.to_variant()]);
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

        self.base_mut().emit_signal("move_applied", &[Enums::MoveType::EnPassant.to_variant(), from.to_variant(), to.to_variant(), Enums::Piece::Empty.to_variant()]);
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

        self.base_mut().emit_signal("move_applied", &[Enums::MoveType::Castling.to_variant(), from.to_variant(), to.to_variant(), Enums::Piece::Empty.to_variant()]);
    }


    #[func]
    fn apply_promotion_move(&mut self, from: String, to: String, new_role: Enums::Piece)
    {
        let from_square = Square::from_ascii(from.as_bytes()).unwrap();
        let to_square = Square::from_ascii(to.as_bytes()).unwrap();
        let mut play_move_option: Option<Move> = None;
        let role = match new_role
        {
            Enums::Piece::Queen => Role::Queen,
            Enums::Piece::Bishop => Role::Bishop,
            Enums::Piece::Knight => Role::Knight,
            Enums::Piece::Rook => Role::Rook,
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

        self.base_mut().emit_signal("move_applied", &[Enums::MoveType::Promotion.to_variant(), from.to_variant(), to.to_variant(), new_role.to_variant()]);
    }


    fn update_move_history(&mut self, new_move: Move)
    {
        if self.game_mode == Enums::GameMode::Chess960
        {
            self.move_history.push(UciMove::from_move(new_move, CastlingMode::Chess960));
        }
        else
        {
            self.move_history.push(UciMove::from_move(new_move, CastlingMode::Standard));
        }
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
    fn is_undoable(&self) -> bool
    {
        if self.position_history.is_empty()
        {
            return false;
        }

        true
    }


    #[func]
    fn undo_last_move(&mut self)
    {
        let _ = self.move_history.pop();
        let _ = self.repeated_position_hash_history.pop();
        self.position = self.position_history.pop().unwrap();
        
        self.base_mut().emit_signal("move_applied", &[Enums::MoveType::Undo.to_variant(), "".to_variant(), "".to_variant(), Enums::Piece::Empty.to_variant()]);

    }


    #[func]
    fn best_ai_move(&self, white_time_left: i64, black_time_left: i64) -> GString
    {
        let best_move = self.local_chess_engine.as_ref().unwrap().best_move(&self.move_history, white_time_left, black_time_left);
        GString::from(&best_move)
    }


    #[func]
    fn stop_ai_thinking(&self)
    {
        match &self.local_chess_engine
        {
            Some(engine) => engine.stop_ai_thinking(),
            None => panic!()
        };
    }


    #[func]
    fn play_ai_move(&mut self, best_ai_move: String)
    {
        let play_move = UciMove::from_ascii(best_ai_move.as_bytes()).unwrap().to_move(&self.position).unwrap();
        let from = play_move.from().unwrap().to_string();
        let to = play_move.to().to_string();

        match play_move
        {
            Move::Normal {..} =>
            {
                if play_move.is_promotion()
                {
                    let new_role = match play_move.promotion().unwrap()
                    {
                        Role::Queen => Enums::Piece::Queen,
                        Role::Rook => Enums::Piece::Rook,
                        Role::Bishop => Enums::Piece::Bishop,
                        Role::Knight => Enums::Piece::Knight,
                        _ => Enums::Piece::Queen
                    };
                    // AI made promotion move, don't call apply_promotion_move(), emit Godot signal, Godot will call apply_promotion_move() function
                    self.base_mut().emit_signal("move_applied", &[Enums::MoveType::PromotionRequestByAI.to_variant(), from.to_variant(), to.to_variant(), new_role.to_variant()]);
                }
                else
                {
                    self.apply_normal_move(from, to);
                }
            }
            Move::EnPassant {..} => self.apply_en_passant_move(from, to),
            Move::Castle {..} => self.apply_castling_move(from, to),
            _ => panic!()
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
    fn match_finished_state(&self) -> Enums::MatchFinishedState
    {
        let mut repeated_board_count: u8 = 0;

        // check 3 repeated positions
        if !self.repeated_position_hash_history.is_empty()
        {
            for board_hash in &self.repeated_position_hash_history
            {
                if board_hash == self.repeated_position_hash_history.last().unwrap()
                {
                    repeated_board_count += 1;
                };
            };
        }

        // check someone won
        if self.position.is_checkmate() || self.position.is_variant_end()
        {
            // turn is changed after last move, the winner is opposite color
            return match self.position.turn()
            {
                Color::White => Enums::MatchFinishedState::BlackWon,
                Color::Black => Enums::MatchFinishedState::WhiteWon
            };
        }

        // check finished draw
        if self.position.is_stalemate() || self.position.is_insufficient_material() || self.position.halfmoves() >= 100 || repeated_board_count >= 3
        {
            return Enums::MatchFinishedState::FinishedDraw;
        }

        Enums::MatchFinishedState::NotFinished
    }
}