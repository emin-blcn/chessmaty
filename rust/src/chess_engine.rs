use std::process::{ChildStdout, Command, Stdio};
use std::io::{BufReader, BufRead, Write};
use shakmaty::uci::UciMove;

use crate::enums as Enums;


pub struct ChessEngine
{
    stdin: std::process::ChildStdin,
    stdout: BufReader<ChildStdout>,
    game_mode: Enums::GameMode,
    fen_string: String
}



impl ChessEngine
{
    pub fn new(ai_binary_path: String, game_mode: Enums::GameMode, fen_string: String, ai_skill_level: i64) -> Self
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
            fen_string: fen_string
        }
    }


    pub fn best_move(&mut self, move_history: &Vec<UciMove>) -> String
    {
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


        writeln!(self.stdin, "go movetime 1000").unwrap();
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