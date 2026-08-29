use std::net::{Ipv4Addr, Shutdown, TcpListener, TcpStream, UdpSocket};
use std::io::{BufRead, BufReader, Write};
use std::sync::Mutex;
use godot::prelude::*;
use godot::classes::{IRefCounted, RefCounted};

use crate::enums as Enums;


const PORT: u16 = 8791;
const MULTICAST_IP: Ipv4Addr = Ipv4Addr::new(239, 125, 99, 201);
const DISCOVERY_PING_MSG: &str = "CHESSMATY_LAN_PING";
const DISCOVERY_PONG_MSG: &str = "CHESSMATY_LAN_PONG";
const JOIN_PING_MSG: &str = "CHESSMATY_LAN_JOIN_PING";
const JOIN_PONG_MSG: &str = "CHESSMATY_LAN_JOIN_PONG";
const CANCEL_WAIT_FOR_PEER_MSG: &str = "CANCEL_WAIT_FOR_PEER";
const MOVE_MSG: &str = "CHESSMATY_MOVE";


#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct LanHost
{
    base: Base<RefCounted>,
    tcp_stream: Mutex<Option<TcpStream>>,
    tcp_bufreader: Mutex<Option<BufReader<TcpStream>>>,
}


#[godot_api]
impl IRefCounted for LanHost
{
    fn init(base: Base<RefCounted>) -> Self
    {
        Self { base, tcp_stream: Mutex::new(None), tcp_bufreader: Mutex::new(None) }
    }
}


#[godot_api]
impl LanHost
{
    #[func]
    fn wait_for_peer(&self, config_data: Dictionary<GString, Variant>) -> bool
    {
        let host_name = config_data.get("host_name").unwrap().to::<GString>();
        let player_color = config_data.get("player_color").unwrap().to::<i32>();
        let game_mode = config_data.get("game_mode").unwrap().to::<i32>();
        let fen_string = config_data.get("fen_string").unwrap().to::<String>();
        let time_per_side = config_data.get("time_per_side").unwrap().to::<i64>();
        let time_increment = config_data.get("time_increment").unwrap().to::<i64>();

        let socket = UdpSocket::bind(("0.0.0.0", PORT)).unwrap();
        socket.join_multicast_v4(&MULTICAST_IP, &Ipv4Addr::new(0, 0, 0, 0)).unwrap();
        
        let mut buffer = [0u8; 512];

        loop
        {
            match socket.recv_from(&mut buffer)
            {
                Ok((size, addr)) =>
                {
                    let received_msg = String::from_utf8_lossy(&buffer[..size]).trim().to_string();
                    
                    if received_msg.starts_with(DISCOVERY_PING_MSG)
                    {
                        let game_info_msg = format!("{}|{}|{}|{}|{}|{}|{}", DISCOVERY_PONG_MSG, host_name, player_color, game_mode, fen_string, time_per_side, time_increment);
                        socket.send_to(game_info_msg.as_bytes(), addr).unwrap();
                    }
                    else if received_msg.as_str() == JOIN_PING_MSG
                    {
                        let listener = TcpListener::bind(("0.0.0.0", PORT)).unwrap();

                        socket.send_to(JOIN_PONG_MSG.as_bytes(), addr).unwrap();

                        let stream = listener.accept().unwrap().0;

                        {
                            let mut tcp_bufreader_guard = self.tcp_bufreader.lock().unwrap();
                            *tcp_bufreader_guard = Some(BufReader::new(stream.try_clone().unwrap()));

                            let mut tcp_stream_guard = self.tcp_stream.lock().unwrap();
                            *tcp_stream_guard = Some(stream);
                        }

                        return true;
                    }
                    else if received_msg.as_str() == CANCEL_WAIT_FOR_PEER_MSG
                    {
                        return false;
                    }
                }
                Err(_) => return false
            }
        }
    }


    #[func]
    fn cancel_waiting_for_peer(&self)
    {
        let dummy_socket = UdpSocket::bind(("0.0.0.0", 0)).unwrap();
        dummy_socket.send_to(CANCEL_WAIT_FOR_PEER_MSG.as_bytes(), ("127.0.0.1", PORT)).unwrap();
    }


    #[func]
    fn wait_for_opponent_msg(&self) -> GString
    {
        let mut reader_guard = self.tcp_bufreader.lock().unwrap();
        let reader = reader_guard.as_mut().unwrap();
        let mut buffer = String::new();

        loop
        {
            buffer.clear();

            match reader.read_line(&mut buffer)
            {
                Ok(0) => return GString::new(),
                Ok(_) =>
                {
                    let received_msg = buffer.trim();

                    if received_msg.starts_with(MOVE_MSG)
                    {
                        return received_msg.to_gstring();
                    }
                }
                Err(_) => return GString::new()
            }
        }
    }


    #[func]
    fn send_move_msg_to_opponent(&self, move_type: Enums::MoveType, from_square: GString, to_square: GString, promotion_piece: Enums::Piece)
    {
        let mut stream_guard = self.tcp_stream.lock().unwrap();
        let stream = stream_guard.as_mut().unwrap();
        let msg = format!("{}|{}|{}|{}|{}\n", MOVE_MSG, move_type as i32, from_square.to_string(), to_square.to_string(), promotion_piece as i32);

        stream.write_all(msg.as_bytes()).unwrap();
    }


    #[func]
    fn send_leave_match_msg_to_opponent(&self)
    {
        let mut stream_guard = self.tcp_stream.lock().unwrap();
        let stream = stream_guard.as_mut().unwrap();

        let _ = stream.shutdown(Shutdown::Both);
    }
}