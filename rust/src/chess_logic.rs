use godot::prelude::*;
use godot::global::randi_range;
use godot::classes::{IRefCounted, RefCounted};
use shakmaty::uci::UciMove;
use shakmaty::{Chess, Color, EnPassantMode, CastlingMode, Move, Position, Role, Square};
use shakmaty::fen::Fen;
use shakmaty::zobrist::Zobrist64;

use crate::chess_engine::ChessEngine;
use crate::enums as Enums;


#[derive(GodotClass)]
#[class(base=RefCounted)]
struct ChessLogic
{
    base: Base<RefCounted>,
    opponent: Enums::Opponent,
    game_mode: Enums::GameMode,
    player_color: Enums::ChessColor,
    chess: Chess,
    chess_engine: Option<ChessEngine>,
    chess_history: Vec<Chess>,
    repeated_board_hash_history: Vec<u64>,
    move_history: Vec<UciMove>
}


#[godot_api]
impl IRefCounted for ChessLogic
{
    fn init(base: Base<RefCounted>) -> Self
    {
        Self
        {
            base: base,
            opponent: Enums::Opponent::LocalHuman,
            game_mode: Enums::GameMode::Standard,
            player_color: Enums::ChessColor::White,
            chess: Chess::new(),
            chess_engine: None,
            chess_history: Vec::<Chess>::new(),
            repeated_board_hash_history: Vec::<u64>::new(),
            move_history: Vec::<UciMove>::new()
        }
    }
}


#[godot_api]
impl ChessLogic
{
    #[signal]
    fn move_applied(move_type: GString, from: GString, to: GString, ai_selected_new_promotion_role: Enums::Piece);


    #[func]
    fn configure_from_godot(&mut self, opponent: Enums::Opponent, game_mode: Enums::GameMode, player_color: Enums::ChessColor, minute_per_side: f64, increment_second: i64, ai_binary_path: GString, ai_skill_level: i64)
    {
        self.opponent = opponent;
        self.game_mode = game_mode;
        self.player_color = player_color;

        match (opponent, game_mode)
        {
            (Enums::Opponent::LocalHuman, Enums::GameMode::Standard) =>
            { // rakip yerel insan ve oyun modu klasik
                self.chess = Chess::default();
            }
            (Enums::Opponent::LocalHuman, Enums::GameMode::Chess960) =>
            { // rakip yerel insan ve oyun modu Chess960
                let fen_string = self.get_random_fen();
                let fen: Fen = fen_string.parse().unwrap();

                self.chess = fen.into_position(CastlingMode::Chess960).unwrap();
            }
            (Enums::Opponent::LocalAI, Enums::GameMode::Standard) =>
            { // rakip yerel AI ve oyun modu klasik
                self.chess = Chess::default();
                self.chess_engine = Some(ChessEngine::new(ai_binary_path.to_string(), game_mode, String::new(), ai_skill_level, minute_per_side, increment_second));
            }
            (Enums::Opponent::LocalAI, Enums::GameMode::Chess960) =>
            { // rakip yerel AI ve oyun modu satranç960
                let fen_string = self.get_random_fen();
                let fen: Fen = fen_string.parse().unwrap();

                self.chess = fen.into_position(CastlingMode::Chess960).unwrap();
                self.chess_engine = Some(ChessEngine::new(ai_binary_path.to_string(), game_mode, fen_string, ai_skill_level, minute_per_side, increment_second));
            }
            (Enums::Opponent::LanHuman, Enums::GameMode::Standard) =>
            { // rakip LAN insan ve oyun modu klasik
                self.chess = Chess::default();
            }
            (Enums::Opponent::LanHuman, Enums::GameMode::Chess960) =>
            { // rakip LAN insan ve oyun modu Chess960
                let fen_string = self.get_random_fen();
                let fen: Fen = fen_string.parse().unwrap();

                self.chess = fen.into_position(CastlingMode::Chess960).unwrap();
            }
        }

        self.update_repeated_board_hash_history();
    }


    fn get_random_fen(&self) -> String
    {
        let all_fens: Vec<&str> = include_str!("fens.txt").lines().collect();
        let random_number = randi_range(0, 960 - 1) as usize;

        format!("{}/pppppppp/8/8/8/8/PPPPPPPP/{} w KQkq - 0 1", all_fens[random_number], all_fens[random_number].to_uppercase())
    }


    #[func]
    fn get_move_count(&self) -> i64
    {
        self.chess_history.len() as i64
    }


    #[func]
    fn get_piece_from_square(&self, square: String) -> Enums::Piece
    {
        let square = Square::from_ascii(&square.as_bytes()).unwrap();

        match self.chess.board().piece_at(square)
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
    fn get_piece_color_from_square(&self, square: String) -> Enums::ChessColor
    {
        let square = Square::from_ascii(&square.as_bytes()).unwrap();

        match self.chess.board().piece_at(square)
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
    fn get_turn(&self) -> Enums::ChessColor
    {
        match self.chess.turn()
        {
            Color::White => Enums::ChessColor::White,
            Color::Black => Enums::ChessColor::Black
        }
    }


    #[func]
    fn get_legal_moves_from_square(&mut self, square: String) -> Dictionary<GString, Enums::MoveType>
    {
        let mut legal_moves_for_godot = Dictionary::<GString, Enums::MoveType>::new();

        for legal_move in self.chess.legal_moves()
        {
            if legal_move.from().unwrap().to_string() == square
            {
                // yasal hamlenin başlangıç karesi ve bizim parametre olarak verdiğimiz kare aynı, bu hamleyi godot yasal hamle listemize ekliyoruz
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

        for legal_move in self.chess.legal_moves()
        {
            // doğru hamleyi bulmak için godot'tan gelen başlangıç-bitiş karelerini yasal hamle listesinin elemanlarıyla karşılaştırıyruz
            if legal_move.from().unwrap() == from_square && legal_move.to() == to_square
            {
                // godot'tan gelen başlangıç-bitiş karesi, yasal hamleler listesindeki bu elemana uyuyor, aradığımız hamle bu
                play_move_option = Some(legal_move);
                break;
            }
        }

        self.update_chess_history();

        let play_move = play_move_option.unwrap();
        self.chess = self.chess.clone().play(play_move).unwrap();
        self.update_move_history(play_move);
        self.update_repeated_board_hash_history();

        // godot sinyalini tetikliyoruz
        self.base_mut().emit_signal("move_applied", &[Enums::MoveType::Normal.to_variant(), from.to_variant(), to.to_variant(), Enums::Piece::Empty.to_variant()]);
    }


    #[func]
    fn apply_en_passant_move(&mut self, from: String, to: String)
    {

        let from_square = Square::from_ascii(from.as_bytes()).unwrap();
        let to_square = Square::from_ascii(to.as_bytes()).unwrap();
        let mut play_move_option: Option<Move> = None;

        for legal_move in self.chess.legal_moves()
        {
            // doğru hamleyi bulmak için godot'tan gelen başlangıç-bitiş karelerini yasal hamle listesinin elemanlarıyla karşılaştırıyruz
            if legal_move.from().unwrap() == from_square && legal_move.to() == to_square
            {
                // godot'tan gelen başlangıç-bitiş karesi, bu elemana uyuyor, aradığımız hamle bu
                play_move_option = Some(legal_move);
                break;
            }
        }

        self.update_chess_history();

        let play_move = play_move_option.unwrap();
        self.chess = self.chess.clone().play(play_move).unwrap();
        self.update_move_history(play_move);
        self.update_repeated_board_hash_history();

        // godot sinyalini tetikliyoruz
        self.base_mut().emit_signal("move_applied", &[Enums::MoveType::EnPassant.to_variant(), from.to_variant(), to.to_variant(), Enums::Piece::Empty.to_variant()]);
    }


    #[func]
    fn apply_castling_move(&mut self, from: String, to: String)
    {
        let from_square = Square::from_ascii(from.as_bytes()).unwrap();
        let to_square = Square::from_ascii(to.as_bytes()).unwrap();
        let mut play_move_option: Option<Move> = None;

        for legal_move in self.chess.legal_moves()
        {
            // doğru hamleyi bulmak için godot'tan gelen başlangıç-bitiş karelerini yasal hamle listesinin elemanlarıyla karşılaştırıyruz
            if legal_move.from().unwrap() == from_square && legal_move.to() == to_square
            {
                // godot'tan gelen başlangıç-bitiş karesi, bu elemana uyuyor, aradığımız hamle bu
                play_move_option = Some(legal_move);
                break;
            }
        }

        self.update_chess_history();

        let play_move = play_move_option.unwrap();
        self.chess = self.chess.clone().play(play_move).unwrap();
        self.update_move_history(play_move);
        self.update_repeated_board_hash_history();

        // godot sinyalini tetikliyoruz
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

        for legal_move in self.chess.legal_moves()
        {
            // doğru hamleyi bulmak için godot'tan gelen başlangıç-bitiş karelerini ve yeni rolü yasal hamle listesinin elemanlarıyla karşılaştırıyruz
            if legal_move.from().unwrap() == from_square && legal_move.to() == to_square && legal_move.promotion().unwrap() == role
            {
                // godot'tan gelen başlangıç-bitiş karesi ve yeni rol, bu elemana uyuyor, aradığımız hamle bu
                play_move_option = Some(legal_move);
                break;
            }
        }

        self.update_chess_history();

        let play_move = play_move_option.unwrap();
        self.chess = self.chess.clone().play(play_move).unwrap();
        self.update_move_history(play_move);
        self.update_repeated_board_hash_history();

        self.base_mut().emit_signal("move_applied", &[Enums::MoveType::Promotion.to_variant(), from.to_variant(), to.to_variant(), Enums::Piece::Empty.to_variant()]);
    }


    fn update_move_history(&mut self, new_move: Move)
    {
        match self.game_mode
        {
            Enums::GameMode::Standard =>
            {
                self.move_history.push(UciMove::from_move(new_move, CastlingMode::Standard));
            }
            Enums::GameMode::Chess960 =>
            {
                self.move_history.push(UciMove::from_move(new_move, CastlingMode::Chess960));
            }
        }
    }


    fn update_chess_history(&mut self)
    {
        self.chess_history.push(self.chess.clone());
    }


    fn update_repeated_board_hash_history(&mut self)
    {
        if self.chess.halfmoves() == 0
        {
            self.repeated_board_hash_history.clear();
        }

        let new_board_hash = self.chess.zobrist_hash::<Zobrist64>(EnPassantMode::Legal).0;
        self.repeated_board_hash_history.push(new_board_hash);
    }


    #[func]
    fn is_undoable(&self) -> bool
    {
        if self.chess_history.is_empty()
        {
            return false;
        }

        true
    }


    #[func]
    fn undo_last_move(&mut self)
    {
        self.move_history.pop().unwrap();
        self.chess = self.chess_history.pop().unwrap();
        self.base_mut().emit_signal("move_applied", &[Enums::MoveType::Undo.to_variant(), "".to_variant(), "".to_variant(), Enums::Piece::Empty.to_variant()]);

    }


    #[func]
    fn get_best_ai_move(&self, white_time_left: i64, black_time_left: i64) -> GString
    {
        let best_move = match &self.chess_engine
        {
            Some(engine) => engine.best_move(&self.move_history, white_time_left, black_time_left),
            None => panic!()
        };

        GString::from(&best_move)
    }


    #[func]
    fn stop_ai_thinking(&self)
    {
        match &self.chess_engine
        {
            Some(engine) => engine.stop_ai_thinking(),
            None => panic!()
        };
    }


    #[func]
    fn play_ai_move(&mut self, best_ai_move: String)
    {
        let play_move = UciMove::from_ascii(best_ai_move.as_bytes()).unwrap().to_move(&self.chess).unwrap();
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
                    // AI, promosyon hamlesi yaptı, apply_promotion_move() fonksiyonunu çağırmıyoruz, godot sinyalini tetikliyoruz, apply_promotion_move() fonksiyonunu godot çağıracak
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
    fn get_king_in_dangered_square(&self) -> GString
    {
        if self.chess.is_check()
        {
            // krallardan biri tehlike altında
            GString::from(&self.chess.board().king_of(self.chess.turn()).unwrap().to_string())
        }
        else
        {
            // tehlike altında kral yok
            GString::new()
        }
    }


    #[func]
    fn get_match_finished_state(&self) -> Enums::MatchFinishedState
    {
        let mut repeated_board_count: u8 = 0;

        for board_hash in &self.repeated_board_hash_history
        {
            // 3 dizilim tekrarı kontrolü için, hash geçmişini kontol ediyoruz
            if !self.repeated_board_hash_history.is_empty() && board_hash == self.repeated_board_hash_history.last().unwrap()
            {
                repeated_board_count += 1;
            };
        };

        if self.chess.is_checkmate()
        {
            // biri mat yaptı
            return match self.chess.turn()
            {
                // mat hamlesinden sonra sıra karşıya geçti, bu yüzden kazanan, aktif sırası olanın zıttı renk
                Color::White => Enums::MatchFinishedState::BlackWon,
                Color::Black => Enums::MatchFinishedState::WhiteWon
            };
        }

        if self.chess.is_stalemate() || self.chess.is_insufficient_material() || self.chess.halfmoves() >= 100 || repeated_board_count >= 3
        {
            // maç berabere bitti
            return Enums::MatchFinishedState::FinishedDraw;
        }

        Enums::MatchFinishedState::NotFinished
    }
}