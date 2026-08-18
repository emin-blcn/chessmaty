use std::process::{ChildStdout, Command, Stdio};
use std::io::{BufReader, BufRead, Write};
use std::sync::Mutex;
use godot::global::{is_equal_approx};
use shakmaty::uci::UciMove;

use crate::enums as Enums;


pub struct ChessEngine
{
    child: Mutex<std::process::Child>,
    stdin: Mutex<std::process::ChildStdin>,
    reader: Mutex<BufReader<ChildStdout>>,
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
            child: Mutex::new(child),
            stdin: Mutex::new(stdin),
            reader: Mutex::new(reader),
            game_mode: game_mode,
            fen_string: fen_string,
            minute_per_side: minute_per_side,
            increment_second: increment_second
        }
    }


    pub fn best_move(&self, move_history: &Vec<UciMove>, white_time_left: i64, black_time_left: i64) -> String
    {   
        let mut uci_moves_string = String::new();
        
        for uci_move in move_history
        {
            uci_moves_string.push_str(&uci_move.to_string());
            uci_moves_string.push(' ');
        }

        {
            let mut stdin = self.stdin.lock().unwrap();

            match self.game_mode
            {
                Enums::GameMode::Standard =>
                { // oyun modu standart, AI'dan normal formatta hamle istiyoruz
                    if move_history.is_empty()
                    { // hamle listesi boş, ilk hamleyi AI yapacak
                        writeln!(stdin, "position startpos").unwrap();
                        stdin.flush().unwrap();
                    }
                    else
                    { // hamle listesi boş değil, aı sıradaki hamleyi yapacak
                        writeln!(stdin, "position startpos moves {}", uci_moves_string.trim_end()).unwrap();
                        stdin.flush().unwrap();
                    }
                }
                Enums::GameMode::Chess960 =>
                { // oyun modu satranç960, AI'dan fen formatında hamle istiyoruz
                    if move_history.is_empty()
                    { // hamle listesi boş, ilk hamleyi AI yapacak
                        writeln!(stdin, "position fen {}", self.fen_string).unwrap();
                        stdin.flush().unwrap();
                    }
                    else
                    { // hamle listesi boş değil, aı sıradaki hamleyi yapacak
                        writeln!(stdin, "position fen {} moves {}", self.fen_string, uci_moves_string.trim_end()).unwrap();
                        stdin.flush().unwrap();
                    }
                }
            }
            
            if is_equal_approx(self.minute_per_side, 999.0)
            {
                writeln!(stdin, "go movetime 1000").unwrap();
            }
            else
            {
                writeln!(stdin, "go wtime {} btime {} winc {} binc {}", white_time_left * 1000, black_time_left * 1000, self.increment_second * 1000, self.increment_second * 1000).unwrap();
            }
            stdin.flush().unwrap();
        }

        let mut reader = self.reader.lock().unwrap();
        let mut best_move = String::new();
        let mut line = String::new();

        loop
        {
            line.clear();

            match reader.read_line(&mut line)
            {
                Ok(read_size) =>
                {
                    if read_size == 0
                    {
                        break;
                    }
                    else
                    {
                        if line.starts_with("bestmove")
                        {
                            best_move = line.split_whitespace().nth(1).unwrap().to_string();
                            break;
                        }
                    }
                }
                Err(_) =>
                {
                    break;
                }
            }
        }

        best_move
    }


    pub fn stop_ai_thinking(&self)
    {
        let mut stdin = self.stdin.lock().unwrap();
        let _ = writeln!(stdin, "stop").unwrap();
        let _ = stdin.flush().unwrap();
    }
}


impl Drop for ChessEngine
{
    fn drop(&mut self)
    {
        if let Ok(mut stdin) = self.stdin.lock()
        {
            let _ = writeln!(stdin, "quit");
            let _ = stdin.flush().unwrap();
        }
        if let Ok(mut child) = self.child.lock()
        {
            let _ = child.kill();
            let _ = child.wait();
        }
    }
}