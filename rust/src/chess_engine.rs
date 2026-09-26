use std::process::{ChildStdout, Command, Stdio};
use std::io::{BufReader, BufRead, Write};
use std::sync::Mutex;
use shakmaty::uci::UciMove;
use sha2::{Sha256, Digest};
use godot::prelude::*;
use godot::classes::{Os, FileAccess};
use godot::classes::file_access::ModeFlags;

use crate::enums::GameMode;

// Engine binary is embedded at compile time and extracted to the user data folder for runtime use.
#[cfg(target_os = "linux")]
static ENGINE_FILE_BYTES: &[u8] = include_bytes!("../../bin/fairy-stockfish_x86-64-modern");

#[cfg(target_os = "windows")]
static ENGINE_FILE_BYTES: &[u8] = include_bytes!("../../bin/fairy-stockfish_x86-64-modern.exe");


pub struct ChessEngine
{
    child: Mutex<std::process::Child>,
    stdin: Mutex<std::process::ChildStdin>,
    reader: Mutex<BufReader<ChildStdout>>,
    game_mode: GameMode,
    fen_string: String,
    time_per_side: i64,
    time_increment: i64
}

impl ChessEngine
{
    pub fn new(game_mode: GameMode, fen_string: String, ai_skill_level: i64, time_per_side: i64, time_increment: i64) -> Self
    {
        #[cfg(target_os = "linux")]
        let engine_file_name = "fairy-stockfish_x86-64-modern";

        #[cfg(target_os = "windows")]
        let engine_file_name = "fairy-stockfish_x86-64-modern.exe";

        let engine_file_path = Os::singleton().get_user_data_dir().path_join(engine_file_name);
        let file_exist = if FileAccess::file_exists(&engine_file_path)
        {
            if let Some(mut file) = FileAccess::open(&engine_file_path, ModeFlags::READ)
            {
                let exist_engine_file_lenght = file.get_length();

                // skip SHA-256 hash verification and return false if file sizes don't match
                if exist_engine_file_lenght != ENGINE_FILE_BYTES.len() as u64
                {
                    false
                }
                else
                {
                    let engine_file_sha256_array = Sha256::digest(ENGINE_FILE_BYTES);
                    let engine_file_sha256 = engine_file_sha256_array.as_slice();

                    let exist_engine_file_bytes_packed_byte_array = file.get_buffer(exist_engine_file_lenght as i64);
                    let exist_engine_file_bytes = exist_engine_file_bytes_packed_byte_array.as_slice();
                    let exist_engine_file_sha256_array = Sha256::digest(exist_engine_file_bytes);
                    let exist_engine_file_sha256 = exist_engine_file_sha256_array.as_slice();

                    engine_file_sha256 == exist_engine_file_sha256
                }
            }
            else
            {
                godot_error!("[{}:{}] chess engine could not be read from user data directory.", file!(), line!());
                false
            }
        }
        else
        {
            false
        };

        if !file_exist
        {
            if let Some(mut file) = FileAccess::open(&engine_file_path, ModeFlags::WRITE)
            {
                file.store_buffer(&PackedByteArray::from(ENGINE_FILE_BYTES));
                file.close();
            }
            else
            {
                godot_error!("[{}:{}] chess engine could not be written to user data directory.", file!(), line!())
            }
        }

        let engine_file_path_string = engine_file_path.to_string();
        #[cfg(target_os = "linux")]
        {
            use std::fs;
            use std::os::unix::fs::PermissionsExt;

            if let Ok(metadata) = fs::metadata(&engine_file_path_string)
            {
                let mut permissions = metadata.permissions();
                permissions.set_mode(0o755);
                let _ = fs::set_permissions(&engine_file_path_string, permissions);
            }
        }

        let mut child = Command::new(engine_file_path_string)
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

        match game_mode
        {
            GameMode::Standard |
            GameMode::Chess960 =>      writeln!(stdin, "setoption name UCI_Variant value chess").unwrap(),
            GameMode::KingOfTheHill => writeln!(stdin, "setoption name UCI_Variant value kingofthehill").unwrap(),
            GameMode::ThreeCheck =>    writeln!(stdin, "setoption name UCI_Variant value 3check").unwrap(),
            GameMode::CrazyHouse =>    writeln!(stdin, "setoption name UCI_Variant value crazyhouse").unwrap(),
            GameMode::AntiChess =>     writeln!(stdin, "setoption name UCI_Variant value antichess").unwrap(),
            GameMode::Atomic =>        writeln!(stdin, "setoption name UCI_Variant value atomic").unwrap(),
            GameMode::Horde =>         writeln!(stdin, "setoption name UCI_Variant value horde").unwrap(),
            GameMode::RacingKings =>   writeln!(stdin, "setoption name UCI_Variant value racingkings").unwrap()
        }
        stdin.flush().unwrap();

        writeln!(stdin, "setoption name UCI_Chess960 value true").unwrap();
        stdin.flush().unwrap();

        writeln!(stdin, "setoption name Skill Level value {}", ai_skill_level).unwrap();
        stdin.flush().unwrap();

        writeln!(stdin, "ucinewgame").unwrap();
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
            game_mode,
            fen_string,
            time_per_side,
            time_increment
        }
    }


    pub fn best_move(&self, move_history: &Vec<UciMove>, white_time_left_ms: i64, black_time_left_ms: i64) -> String
    {   
        let mut uci_moves_string = String::new();
        
        for uci_move in move_history
        {
            uci_moves_string.push_str(&uci_move.to_string());
            uci_moves_string.push(' ');
        }

        {
            let mut stdin = self.stdin.lock().unwrap();

            // give begin board fen to AI if game mode is Chess960, else give standard start position
            if self.game_mode == GameMode::Chess960
            {
                if move_history.is_empty()
                {// move list is empty, AI will make first move
                    writeln!(stdin, "position fen {}", self.fen_string).unwrap();
                    stdin.flush().unwrap();
                }
                else
                {// move list is not empty, AI will make next move
                    writeln!(stdin, "position fen {} moves {}", self.fen_string, uci_moves_string.trim_end()).unwrap();
                    stdin.flush().unwrap();
                }
            }
            else
            {
                if move_history.is_empty()
                {// move list is empty, AI will make first move
                    writeln!(stdin, "position startpos").unwrap();
                    stdin.flush().unwrap();
                }
                else
                {// move list is not empty, AI will make next move
                    writeln!(stdin, "position startpos moves {}", uci_moves_string.trim_end()).unwrap();
                    stdin.flush().unwrap();
                }
            }
            
            //no time limit if time limit value == -1 minute (-60000 ms)
            if self.time_per_side == -60_000
            {
                writeln!(stdin, "go movetime 1000").unwrap();
            }
            else
            {
                writeln!(stdin, "go wtime {} btime {} winc {} binc {}", white_time_left_ms, black_time_left_ms, self.time_increment, self.time_increment).unwrap();
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
        let _ = writeln!(stdin, "stop");
        let _ = stdin.flush();
    }
}


impl Drop for ChessEngine
{
    fn drop(&mut self)
    {
        if let Ok(mut stdin) = self.stdin.lock()
        {
            let _ = writeln!(stdin, "quit");
            let _ = stdin.flush();
        }
        if let Ok(mut child) = self.child.lock()
        {
            let _ = child.kill();
            let _ = child.wait();
        }
    }
}