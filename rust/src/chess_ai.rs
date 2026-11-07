use std::process::{Child, ChildStdout, ChildStdin, Command, Stdio};
use std::io::{BufReader, BufRead, Write};
use std::sync::Mutex;
use shakmaty::uci::UciMove;
use godot::prelude::*;
use godot::classes::{Os, FileAccess, file_access::ModeFlags};

use crate::enums::GameMode;

// Engine binary is embedded at compile time and extracted to the user data folder for runtime use.
#[cfg(all(target_os = "linux", target_arch = "x86_64"))]
mod engine_file
{
    pub const NAME: &str = "fairy-stockfish_x86-64-modern";
    pub const BYTES: &[u8] = include_bytes!("../../bin/fairy-stockfish_x86-64-modern");
}

#[cfg(all(target_os = "windows", target_arch = "x86_64"))]
mod engine_file
{
    pub const NAME: &str = "fairy-stockfish_x86-64-modern.exe";
    pub const BYTES: &[u8] = include_bytes!("../../bin/fairy-stockfish_x86-64-modern.exe");
}


pub struct ChessAI
{
    // using Mutex, because godot-rust lib locks object in mutable reference functions, which we want to avoid
    child_process: Mutex<Child>,
    reader: Mutex<BufReader<ChildStdout>>,
    writer: Mutex<ChildStdin>,
    game_mode: GameMode,
    fen_string: String,
    time_per_side: i64,
    time_increment: i64,
    stop_ai_thinking: Mutex<bool>
}


impl ChessAI
{
    pub fn new(game_mode: GameMode, fen_string: String, ai_skill_level: i64, time_per_side: i64, time_increment: i64) -> Self
    {
        let engine_file_path: GString = Os::singleton().get_user_data_dir().path_join(engine_file::NAME);
        let engine_file_path_string: String = engine_file_path.to_string();

        let file_exist: bool;

        if !FileAccess::file_exists(&engine_file_path)
        {
            file_exist = false;
        }
        else
        {
            match FileAccess::open(&engine_file_path, ModeFlags::READ)
            {
                None =>
                {
                    file_exist = false;
                    godot_error!("[{}:{}] Chess engine file is founded, but could not be opened.", file!(), line!());
                }
                Some(mut file_access) =>
                {
                    let exist_engine_file_size = file_access.get_length();

                    // skip SHA-256 hash verification and make false "file_exist" variable if file sizes don't match
                    if exist_engine_file_size != engine_file::BYTES.len() as u64
                    {
                        file_exist = false;
                    }
                    else
                    {
                        use sha2::{Sha256, Digest};
                        
                        let engine_file_sha256 = Sha256::digest(engine_file::BYTES);
                        let exist_engine_file_sha256 = Sha256::digest(file_access.get_buffer(exist_engine_file_size as i64).as_slice());

                        file_exist = engine_file_sha256 == exist_engine_file_sha256;
                    }
                }
            }
        }

        if !file_exist
        {
            if let Some(mut file) = FileAccess::open(&engine_file_path, ModeFlags::WRITE)
            {
                file.store_buffer(&PackedByteArray::from(engine_file::BYTES));
                file.close();
            }
            else
            {
                godot_error!("[{}:{}] Chess engine file could not be written to user data directory.", file!(), line!());
            }
        }

        // Execute permission required in Unix systems (linux, Mac)
        #[cfg(target_family = "unix")]
        {
            use std::fs;
            use std::os::unix::fs::PermissionsExt;

            if let Ok(file_metadata) = fs::metadata(&engine_file_path_string)
            {
                let mut file_permissions = file_metadata.permissions();
                if file_permissions.mode() != 0o555
                {
                    file_permissions.set_mode(0o555);
                    if let Err(error) = fs::set_permissions(&engine_file_path_string, file_permissions)
                    {
                        godot_error!("[{}:{}] {}.", file!(), line!(), error);
                    }
                }
            }
        }

        #[cfg(target_os = "windows")]
        {
            use std::fs;

            if let Ok(file_metadata) = fs::metadata(&engine_file_path_string)
            {
                let mut file_permissions = file_metadata.permissions();
                if !file_permissions.readonly()
                {
                    file_permissions.set_readonly(true);

                    if let Err(error) = fs::set_permissions(&engine_file_path_string, file_permissions)
                    {
                        godot_error!("[{}:{}] {}.", file!(), line!(), error);
                    }
                }
            }
        }

        let mut child_process = Command::new(engine_file_path_string)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .spawn()
            .unwrap();
        let mut stdin = child_process.stdin.take().unwrap();
        let stdout = child_process.stdout.take().unwrap();
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
            GameMode::Standard
            | GameMode::Chess960 =>    writeln!(stdin, "setoption name UCI_Variant value chess").unwrap(),
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
            child_process: Mutex::<Child>::new(child_process),
            reader: Mutex::<BufReader<ChildStdout>>::new(reader),
            writer: Mutex::<ChildStdin>::new(stdin),
            game_mode,
            fen_string,
            time_per_side,
            time_increment,
            stop_ai_thinking: Mutex::<bool>::new(false)
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
            let mut writer = self.writer.lock().unwrap();

            // give begin board fen to AI if game mode is Chess960, else give standard start position
            if self.game_mode == GameMode::Chess960
            {
                if move_history.is_empty()
                {// move list is empty, AI will make first move
                    writeln!(writer, "position fen {}", self.fen_string).unwrap();
                    writer.flush().unwrap();
                }
                else
                {// move list is not empty, AI will make next move
                    writeln!(writer, "position fen {} moves {}", self.fen_string, uci_moves_string.trim_end()).unwrap();
                    writer.flush().unwrap();
                }
            }
            else
            {
                if move_history.is_empty()
                {// move list is empty, AI will make first move
                    writeln!(writer, "position startpos").unwrap();
                    writer.flush().unwrap();
                }
                else
                {// move list is not empty, AI will make next move
                    writeln!(writer, "position startpos moves {}", uci_moves_string.trim_end()).unwrap();
                    writer.flush().unwrap();
                }
            }
            
            //no time limit if time limit value == -1 minute (-60000 ms)
            if self.time_per_side == -60_000
            {
                writeln!(writer, "go movetime 1000").unwrap();
            }
            else
            {
                writeln!(writer, "go wtime {} btime {} winc {} binc {}", white_time_left_ms, black_time_left_ms, self.time_increment, self.time_increment).unwrap();
            }
            writer.flush().unwrap();
        }

        let mut reader_mutex_guard = self.reader.lock().unwrap();
        let mut best_move = String::new();
        let mut line = String::new();

        loop
        {
            line.clear();

            match reader_mutex_guard.read_line(&mut line)
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
                            let mut stop_ai_thinking_mutex_guard = self.stop_ai_thinking.lock().unwrap();
                            if *stop_ai_thinking_mutex_guard
                            {
                                *stop_ai_thinking_mutex_guard = false;
                            }
                            else
                            {
                                best_move = line.split_whitespace().nth(1).unwrap().to_string();
                            }

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
        let mut stop_ai_thinking_mutex_guard = self.stop_ai_thinking.lock().unwrap();
        *stop_ai_thinking_mutex_guard = true;

        let mut writer = self.writer.lock().unwrap();
        let _ = writeln!(writer, "stop");
        let _ = writer.flush();
    }
}


impl Drop for ChessAI
{
    fn drop(&mut self)
    {
        if let Ok(mut writer) = self.writer.lock()
        {
            let _ = writeln!(writer, "quit");
            let _ = writer.flush();
        }
        if let Ok(mut child_process) = self.child_process.lock()
        {
            let _ = child_process.kill();
            let _ = child_process.wait();
        }
    }
}