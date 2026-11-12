use std::fs;
use std::path::Path;
use std::process::{Child, ChildStdout, ChildStdin, Command, Stdio};
use std::io::{BufReader, BufRead, Write};
use std::sync::Mutex;
use shakmaty::uci::UciMove;
use godot::prelude::*;
use godot::classes::Os;

use crate::enums::GameMode;

// Engine binary is embedded at compile time and extracted to the user data folder for runtime use.
#[cfg(all(target_os = "linux", target_arch = "x86_64"))]
mod engine_file
{
    pub const BMI2_NAME: &str = "fairy-stockfish_x86-64-bmi2";
    pub const BMI2_BYTES: &[u8] = include_bytes!("../../bin/fairy-stockfish_x86-64-bmi2");

    pub const MODERN_NAME: &str = "fairy-stockfish_x86-64-modern";
    pub const MODERN_BYTES: &[u8] = include_bytes!("../../bin/fairy-stockfish_x86-64-modern");

    pub const X86_64_NAME: &str = "fairy-stockfish_x86-64";
    pub const X86_64_BYTES: &[u8] = include_bytes!("../../bin/fairy-stockfish_x86-64");
}

#[cfg(all(target_os = "windows", target_arch = "x86_64"))]
mod engine_file
{
    pub const BMI2_NAME: &str = "fairy-stockfish_x86-64-bmi2.exe";
    pub const BMI2_BYTES: &[u8] = include_bytes!("../../bin/fairy-stockfish_x86-64-bmi2.exe");

    pub const MODERN_NAME: &str = "fairy-stockfish_x86-64-modern.exe";
    pub const MODERN_BYTES: &[u8] = include_bytes!("../../bin/fairy-stockfish_x86-64-modern.exe");

    pub const X86_64_NAME: &str = "fairy-stockfish_x86-64.exe";
    pub const X86_64_BYTES: &[u8] = include_bytes!("../../bin/fairy-stockfish_x86-64.exe");
}


pub struct ChessAI
{
    // using Mutex, because godot-rust lib locks object in mutable reference functions, which we want to avoid
    process_mutex: Mutex<Child>,
    reader_mutex: Mutex<BufReader<ChildStdout>>,
    writer_mutex: Mutex<ChildStdin>,
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
        let (engine_file_name, engine_file_bytes) = {
            if is_x86_feature_detected!("bmi2") && is_x86_feature_detected!("avx2") && is_x86_feature_detected!("sse4.1") && is_x86_feature_detected!("popcnt"){
                (engine_file::BMI2_NAME, engine_file::BMI2_BYTES) // see also https://github.com/fairy-stockfish/Fairy-Stockfish/blob/4e3d0147d5b8da1b780a29f0b3e1d24311d028fa/src/Makefile#L202
            }
            else if is_x86_feature_detected!("sse4.1") && is_x86_feature_detected!("popcnt") {
                (engine_file::MODERN_NAME, engine_file::MODERN_BYTES) // see also https://github.com/fairy-stockfish/Fairy-Stockfish/blob/4e3d0147d5b8da1b780a29f0b3e1d24311d028fa/src/Makefile#L185
            }
            else {
                (engine_file::X86_64_NAME, engine_file::X86_64_BYTES)
            }
        };
        let exist_engine_file_path_string = Os::singleton().get_user_data_dir().path_join(&engine_file_name.to_gstring()).to_string();
        let exist_engine_file_path = Path::new(&exist_engine_file_path_string);
        let is_engine_file_exist: bool;

        if !exist_engine_file_path.exists()
        {
            is_engine_file_exist = false;
        }
        else
        {
            match fs::read(exist_engine_file_path)
            {
                Err(_) =>
                {
                    is_engine_file_exist = false;
                    godot_error!("[{}:{}] Chess engine file is founded, but could not be readed.", file!(), line!());
                }
                Ok(exist_engine_file_bytes) =>
                {
                    // skip xxh3 hash verification and make false "is_engine_file_exist" variable if file sizes don't match
                    if engine_file_bytes.len() != exist_engine_file_bytes.len()
                    {
                        is_engine_file_exist = false;
                    }
                    else
                    {
                        use xxhash_rust::xxh3::xxh3_64;
                        
                        let engine_file_hash = xxh3_64(engine_file_bytes);
                        let exist_engine_file_hash = xxh3_64(exist_engine_file_bytes.as_slice());

                        is_engine_file_exist = engine_file_hash == exist_engine_file_hash;
                    }
                }
            }
        }

        if !is_engine_file_exist
        {
            if let Err(_) = fs::write(exist_engine_file_path, engine_file_bytes)
            {
                godot_error!("[{}:{}] Chess engine file could not be written to user data directory.", file!(), line!());
            }
        }

        // Execute permission required in Unix systems (linux, Mac)
        #[cfg(target_family = "unix")]
        {
            use std::os::unix::fs::PermissionsExt;

            if let Ok(file_metadata) = fs::metadata(&exist_engine_file_path_string)
            {
                let mut file_permissions = file_metadata.permissions();
                if file_permissions.mode() != 0o555
                {
                    file_permissions.set_mode(0o555);
                    if let Err(error) = fs::set_permissions(&exist_engine_file_path_string, file_permissions)
                    {
                        godot_error!("[{}:{}] {}.", file!(), line!(), error);
                    }
                }
            }
        }

        #[cfg(target_os = "windows")]
        {
            if let Ok(file_metadata) = fs::metadata(&exist_engine_file_path_string)
            {
                let mut file_permissions = file_metadata.permissions();
                if !file_permissions.readonly()
                {
                    file_permissions.set_readonly(true);

                    if let Err(error) = fs::set_permissions(&exist_engine_file_path_string, file_permissions)
                    {
                        godot_error!("[{}:{}] {}.", file!(), line!(), error);
                    }
                }
            }
        }

        let mut child_process = Command::new(exist_engine_file_path_string).stdin(Stdio::piped()).stdout(Stdio::piped()).spawn().unwrap();
        let mut writer = child_process.stdin.take().unwrap();
        let mut reader = BufReader::new(child_process.stdout.take().unwrap());

        writer.write_all("uci\n".as_bytes()).unwrap();
        let _ = writer.flush();

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

        match game_mode {
            GameMode::Standard
            | GameMode::Chess960 =>    writer.write_all("setoption name UCI_Variant value chess\n".as_bytes()),
            GameMode::KingOfTheHill => writer.write_all("setoption name UCI_Variant value kingofthehill\n".as_bytes()),
            GameMode::ThreeCheck =>    writer.write_all("setoption name UCI_Variant value 3check\n".as_bytes()),
            GameMode::CrazyHouse =>    writer.write_all("setoption name UCI_Variant value crazyhouse\n".as_bytes()),
            GameMode::AntiChess =>     writer.write_all("setoption name UCI_Variant value antichess\n".as_bytes()),
            GameMode::Atomic =>        writer.write_all("setoption name UCI_Variant value atomic\n".as_bytes()),
            GameMode::Horde =>         writer.write_all("setoption name UCI_Variant value horde\n".as_bytes()),
            GameMode::RacingKings =>   writer.write_all("setoption name UCI_Variant value racingkings\n".as_bytes())
        }.unwrap();

        writer.write_all("setoption name UCI_Chess960 value true\n".as_bytes()).unwrap();
        writer.write_all(format!("setoption name Skill Level value {}\n", ai_skill_level).as_bytes()).unwrap();
        writer.write_all("ucinewgame\n".as_bytes()).unwrap();
        writer.write_all("isready\n".as_bytes()).unwrap();
        let _ = writer.flush();

        loop
        {
            line.clear();
            reader.read_line(&mut line).unwrap();

            if line.trim() == "readyok"
            {
                break;
            }
        }

        Self {
            process_mutex: Mutex::<Child>::new(child_process),
            reader_mutex: Mutex::<BufReader<ChildStdout>>::new(reader),
            writer_mutex: Mutex::<ChildStdin>::new(writer),
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
            uci_moves_string.push_str(&uci_move.to_string().as_str());
            uci_moves_string.push(' ');
        }

        {
            let mut writer_mutex_guard = self.writer_mutex.lock().unwrap();

            // give begin board fen to AI if game mode is Chess960, else give standard start position
            if self.game_mode == GameMode::Chess960
            {
                if move_history.is_empty()
                {// move list is empty, AI will make first move
                    writer_mutex_guard.write_all(format!("position fen {}\n", self.fen_string).as_bytes()).unwrap();
                }
                else
                {// move list is not empty, AI will make next move
                    writer_mutex_guard.write_all(
                        format!(
                            "position fen {} moves {}\n",
                            self.fen_string,
                            uci_moves_string
                        ).as_bytes()
                    ).unwrap();
                }
            }
            else
            {
                if move_history.is_empty()
                {// move list is empty, AI will make first move
                    writer_mutex_guard.write_all("position startpos\n".as_bytes()).unwrap();
                    
                }
                else
                {// move list is not empty, AI will make next move
                    writer_mutex_guard.write_all(format!("position startpos moves {}\n", uci_moves_string).as_bytes()).unwrap();
                }
            }
            let _ = writer_mutex_guard.flush();
            
            //no time limit if time limit value == -1 minute (-60000 ms)
            if self.time_per_side == -60_000
            {
                writer_mutex_guard.write_all("go movetime 1000\n".as_bytes()).unwrap();
            }
            else
            {
                writer_mutex_guard.write_all(
                    format!(
                        "go wtime {} btime {} winc {} binc {}\n",
                        white_time_left_ms,
                        black_time_left_ms,
                        self.time_increment,
                        self.time_increment
                    ).as_bytes()
                ).unwrap();
            }
            let _ = writer_mutex_guard.flush();
        }

        let mut reader_mutex_guard = self.reader_mutex.lock().unwrap();
        let mut best_move = String::new();
        let mut line = String::new();
        loop
        {
            line.clear();
            match reader_mutex_guard.read_line(&mut line)
            {
                Ok(0) => break,
                Ok(_) =>
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

        let mut writer_mutex_guard = self.writer_mutex.lock().unwrap();
        writer_mutex_guard.write_all("stop\n".as_bytes()).unwrap();
        let _ = writer_mutex_guard.flush();
    }
}


impl Drop for ChessAI
{
    fn drop(&mut self)
    {
        if let Ok(mut writer_mutex_guard) = self.writer_mutex.lock()
        {
            writer_mutex_guard.write_all("quit\n".as_bytes()).unwrap();
            let _ = writer_mutex_guard.flush();
        }
        if let Ok(mut process_mutex_guard) = self.process_mutex.lock()
        {
            let _ = process_mutex_guard.kill();
            let _ = process_mutex_guard.wait();
        }
    }
}