use std::process::{ChildStdout, Command, Stdio};
use std::io::{BufReader, BufRead, Write};
use godot::global::{godot_print, is_equal_approx};
use shakmaty::uci::UciMove;

use crate::enums as Enums;


pub struct ChessEngine
{
    stdin: std::process::ChildStdin,
    stdout: BufReader<ChildStdout>,
    game_mode: Enums::GameMode,
    fen_string: String,
    minute_per_side: f64,
    increment_second: i64
}



impl ChessEngine
{
    pub fn new(ai_binary_path: String, game_mode: Enums::GameMode, fen_string: String, ai_skill_level: i64, minute_per_side: f64, increment_second: i64) -> Self
    {
        let mut child = Command::new(ai_binary_path)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .spawn()
            .unwrap();
        let mut stdin = child.stdin.take().unwrap();
        let stdout = child.stdout.take().unwrap();
        let mut reader = BufReader::new(stdout);

        writeln!(stdin, "uci").unwrap();
        stdin.flush().unwrap();

        let mut line = String::new();

        loop
        {
            line.clear();
            reader.read_line(&mut line).unwrap();

            if line.trim() == "uciok"
            {
                break;
            }
        }

        if game_mode == Enums::GameMode::Chess960
        {
            writeln!(stdin, "setoption name UCI_Chess960 value true").unwrap();
            stdin.flush().unwrap();
        }

        writeln!(stdin, "setoption name Skill Level value {}", ai_skill_level).unwrap();
        stdin.flush().unwrap();

        writeln!(stdin, "isready").unwrap();
        stdin.flush().unwrap();

        loop
        {
            line.clear();
            reader.read_line(&mut line).unwrap();

            if line.trim() == "readyok"
            {
                break;
            }
        }

        Self
        {
            stdin: stdin,
            stdout: reader,
            game_mode: game_mode,
            fen_string: fen_string,
            minute_per_side: minute_per_side,
            increment_second: increment_second
        }
    }


    pub fn best_move(&mut self, move_history: &Vec<UciMove>, white_time_left: i64, black_time_left: i64) -> String
    {
        godot_print!("Gelen dakika: {}, Esit mi: {}", self.minute_per_side, is_equal_approx(self.minute_per_side, 999.0));
        
        let mut uci_moves_string = String::new();
        
        for uci_move in move_history
        {
            uci_moves_string.push_str(&uci_move.to_string());
            uci_moves_string.push(' ');
        }

        match self.game_mode
        {
            Enums::GameMode::Standard =>
            { // oyun modu standart, AI'dan normal formatta hamle istiyoruz
                if move_history.is_empty()
                { // hamle listesi boş, ilk hamleyi AI yapacak
                    writeln!(self.stdin, "position startpos").unwrap();
                    self.stdin.flush().unwrap();
                }
                else
                { // hamle listesi boş değil, aı sıradaki hamleyi yapacak
                    writeln!(self.stdin, "position startpos moves {}", uci_moves_string.trim_end()).unwrap();
                    self.stdin.flush().unwrap();
                }
            }
            Enums::GameMode::Chess960 =>
            { // oyun modu satranç960, AI'dan fen formatında hamle istiyoruz
                if move_history.is_empty()
                { // hamle listesi boş, ilk hamleyi AI yapacak
                    writeln!(self.stdin, "position fen {}", self.fen_string).unwrap();
                    self.stdin.flush().unwrap();
                }
                else
                { // hamle listesi boş değil, aı sıradaki hamleyi yapacak
                    writeln!(self.stdin, "position fen {} moves {}", self.fen_string, uci_moves_string.trim_end()).unwrap();
                    self.stdin.flush().unwrap();
                }
            }
        }
        
        if is_equal_approx(self.minute_per_side, 999.0)
        {
            writeln!(self.stdin, "go movetime 1000").unwrap();
        }
        else
        {
            godot_print!("go wtime {} btime {} winc {} binc {}", white_time_left * 1000, black_time_left * 1000, self.increment_second * 1000, self.increment_second * 1000);
            writeln!(self.stdin, "go wtime {} btime {} winc {} binc {}", white_time_left * 1000, black_time_left * 1000, self.increment_second * 1000, self.increment_second * 1000).unwrap();
        }
        self.stdin.flush().unwrap();

        let best_move: String;
        let mut line = String::new();

        loop
        {
            line.clear();
            self.stdout.read_line(&mut line).unwrap();

            if line.starts_with("bestmove")
            {
                best_move = line.split_whitespace().nth(1).unwrap().to_string();
                break;
            }
        }

        best_move
    }
}