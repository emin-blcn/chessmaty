use godot::prelude::*;
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
    board_hash_history: Vec<u64>,
    move_history: Vec<UciMove>
}



#[godot_api]
impl IRefCounted for ChessLogic
{
    fn init(base: Base<RefCounted>) -> Self
    {
        let mut new = Self
        {
            base: base,
            opponent: Enums::Opponent::LocalHuman,
            game_mode: Enums::GameMode::Standard,
            player_color: Enums::ChessColor::White,
            chess: Chess::new(),
            chess_engine: None,
            board_hash_history: Vec::<u64>::new(),
            move_history: Vec::<UciMove>::new()
        };

        new.update_board_hash_history();
        new
    }
}



#[godot_api]
impl ChessLogic
{
    #[signal]
    fn move_applied(move_type: GString, from: GString, to: GString, ai_selected_new_promotion_role: GString);


    #[func]
    fn configure_from_godot_and_get_board_fen(&mut self, opponent: Enums::Opponent, game_mode: Enums::GameMode, player_color: Enums::ChessColor, _chess960_random_number: i64, ai_binary_path: GString) -> GString
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
                let fen_string = String::from("nbnrbqkr/pppppppp/8/8/8/8/PPPPPPPP/NBNRBQKR w KQkq - 0 1");
                let fen: Fen = fen_string.parse().unwrap();

                self.chess = fen.into_position(CastlingMode::Chess960).unwrap();
            }
            (Enums::Opponent::LocalAI, Enums::GameMode::Standard) =>
            { // rakip yerel AI ve oyun modu klasik
                self.chess = Chess::default();
                self.chess_engine = Some(ChessEngine::new(ai_binary_path.to_string(), game_mode, String::new()));
            }
            (Enums::Opponent::LocalAI, Enums::GameMode::Chess960) =>
            { // rakip yerel AI ve oyun modu satranç960
                let fen_string = String::from("nbnrbqkr/pppppppp/8/8/8/8/PPPPPPPP/NBNRBQKR w KQkq - 0 1");
                let fen: Fen = fen_string.parse().unwrap();

                self.chess = fen.into_position(CastlingMode::Chess960).unwrap();
                self.chess_engine = Some(ChessEngine::new(ai_binary_path.to_string(), game_mode, fen_string));
            }
        }

        self.chess.board().board_fen().to_string().to_gstring()
    }


    #[func]
    fn get_piece_from_square(&self, square: String) -> GString // return "empty" or "King_black", "Castle_black", "Queen_white"...
    {
        let square = Square::from_ascii(&square.as_bytes()).unwrap();

        match self.chess.board().piece_at(square)
        {
            Some(piece) => GString::from(&format!("{:?}_{}", piece.role, piece.color)),
            None => GString::from("empty")
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
    fn get_legal_moves_from_square(&mut self, square: String) -> Array<GString>
    {
        let mut legal_moves_from_square_for_godot = Array::<GString>::new();

        for legal_move in self.chess.legal_moves()
        {
            if legal_move.from().unwrap().to_string() == square
            {
                // yasal hamlenin başlangıç karesi ve bizim parametre olarak verdiğimiz kare aynı, bu hamleyi godot yasal hamle listemize ekliyoruz
                let mut to_square = String::new();

                match legal_move
                {
                    Move::Normal {..} =>
                    {
                        if legal_move.is_promotion()
                        {
                            // yasal hamle promosyon, string "p_" ile başlayacak
                            to_square = format!("p_{}", legal_move.to().to_string());
                        }
                        else
                        {
                            // yasal hamle normal, string "n_" ile başlayacak
                            to_square = format!("n_{}", legal_move.to().to_string());
                        }
                    }
                    Move::EnPassant {..} =>
                    {
                        // yasal hamle, en passant, string "e_" ile başlayacak
                        to_square = format!("e_{}", legal_move.to().to_string());
                    }
                    Move::Castle{..} =>
                    {
                        // yasal hamle rok, string "r_" ile başlayacak
                        to_square = format!("r_{}", legal_move.to().to_string());
                    }
                    _ => {}
                };

                let to_square_gstring = GString::from(&to_square);

                if !legal_moves_from_square_for_godot.contains(&to_square_gstring)
                {
                    legal_moves_from_square_for_godot.push(&to_square_gstring);
                }
            }
        }
        
        legal_moves_from_square_for_godot
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

        let play_move = play_move_option.unwrap();
        
        self.chess = self.chess.clone().play(play_move).unwrap();
        self.update_board_hash_history();
        self.update_move_history(play_move);

        // godot sinyalini tetikliyoruz
        self.base_mut().emit_signal("move_applied", &["normal".to_variant(), from.to_variant(), to.to_variant(), GString::new().to_variant()]);
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

        let play_move = play_move_option.unwrap();

        self.chess = self.chess.clone().play(play_move).unwrap();
        self.update_board_hash_history();
        self.update_move_history(play_move);

        // godot sinyalini tetikliyoruz
        self.base_mut().emit_signal("move_applied", &["en_passant".to_variant(), from.to_variant(), to.to_variant(), GString::new().to_variant()]);
    }


    #[func]
    fn apply_rook_move(&mut self, from: String, to: String)
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
        
        let play_move = play_move_option.unwrap();

        self.chess = self.chess.clone().play(play_move).unwrap();
        self.update_board_hash_history();
        self.update_move_history(play_move);

        // godot sinyalini tetikliyoruz
        self.base_mut().emit_signal("move_applied", &["rook".to_variant(), from.to_variant(), to.to_variant(), GString::new().to_variant()]);
    }


    #[func]
    fn apply_promotion_move(&mut self, from: String, to: String, new_role: String)
    {
        let from_square = Square::from_ascii(from.as_bytes()).unwrap();
        let to_square = Square::from_ascii(to.as_bytes()).unwrap();
        let mut play_move_option: Option<Move> = None;
        let role = match new_role.as_str()
        {
            "Queen" => Role::Queen,
            "Bishop" => Role::Bishop,
            "Knight" => Role::Knight,
            "Rook" => Role::Rook,
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

        let play_move = play_move_option.unwrap();
        self.chess = self.chess.clone().play(play_move).unwrap();
        self.update_board_hash_history();
        self.update_move_history(play_move);

        // burada godot sinyalini tetiklemiyoruz çünkü sinyali oyuncu, godot'tan tetikledi ya da AI, play_ai_move() fonksiyonu içinde tetikledi
        // godot hamle animasyonunu oynattıktan sonra bu fonsksiyonu çağırdı, hamleyi shakmaty'de güncelliyoruz
    }


    fn update_board_hash_history(&mut self)
    {
        if self.chess.halfmoves() == 0
        {
            self.board_hash_history.clear();
        }

        let new_board_hash = self.chess.zobrist_hash::<Zobrist64>(EnPassantMode::Legal).0;
        self.board_hash_history.push(new_board_hash);
    }


    fn update_move_history(&mut self, new_move: Move)
    {
        self.move_history.push(UciMove::from_move(new_move, CastlingMode::Chess960));
    }


    #[func]
    fn get_best_ai_move(&mut self) -> GString
    {
        let best_move = match &mut self.chess_engine
        {
            Some(engine) => engine.best_move(&self.move_history),
            None => panic!()
        };

        godot_print!("AI best move: {}", best_move);
        GString::from(&best_move)
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
                        Role::Queen => GString::from("Queen"),
                        Role::Rook => GString::from("Rook"),
                        Role::Bishop => GString::from("Bishop"),
                        Role::Knight => GString::from("Knight"),
                        _ => GString::from("Queen")
                    };

                    // AI, promosyon hamlesi yaptı, apply_promotion_move() fonksiyonunu çağırmıyoruz, godot sinyalini tetikliyoruz, apply_promotion_move() fonksiyonunu godot çağıracak
                    self.base_mut().emit_signal("move_applied", &["promotion_by_ai".to_variant(), from.to_variant(), to.to_variant(), new_role.to_variant()]);
                }
                else
                {
                    self.apply_normal_move(from, to);
                }
            }
            Move::EnPassant {..} => self.apply_en_passant_move(from, to),
            Move::Castle {..} => self.apply_rook_move(from, to),
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
    fn get_match_finished_state(&self) -> GString
    {
        let mut repeated_board_count: u8 = 0;

        for board_hash in &self.board_hash_history
        {
            // 3 dizilim tekrarı kontrolü için, hash geçmişini kontol ediyoruz
            if !self.board_hash_history.is_empty() && board_hash == self.board_hash_history.last().unwrap()
            {
                repeated_board_count += 1;
            };
        };

        if self.chess.is_checkmate()
        {
            // biri mat yaptı
            return GString::from(match self.chess.turn()
            {
                // mat yapılınca hamle sırası kaybeden tarafa geçti, bu yüzden kazanan, aktif sırası olanın zıttı renk
                Color::White => "finished_black",
                Color::Black => "finished_white"
            });
        }

        if self.chess.is_stalemate() || self.chess.is_insufficient_material() || self.chess.halfmoves() >= 100 || repeated_board_count >= 3
        {
            // maç berabere bitti
            return GString::from("finished_draw");
        }

        GString::from("not_finished")
    }
}