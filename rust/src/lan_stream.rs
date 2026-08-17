use std::net::{UdpSocket, IpAddr, Ipv4Addr};
use std::sync::Arc;
use godot::prelude::*;
use godot::classes::{IRefCounted, RefCounted};
use godot::global::godot_print;

use crate::enums as Enums;


const PORT: u16 = 8791;
const DISCOVERY_MSG: &str = "CHESSMATY_LAN_SCAN";
const DISCOVERY_RESPONSE_MSG: &str = "CHESSMATY_LAN_STREAM_HERE";


#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct LanStream
{
    base: Base<RefCounted>
}


#[godot_api]
impl IRefCounted for LanStream
{
   fn init(base: Base<RefCounted>) -> Self
    {
        Self{base: base}
    }
}


#[godot_api]
impl LanStream
{


    #[func]
    fn create_game(&self, player_name: GString, player_color: Enums::ChessColor, game_mode: Enums::GameMode, minute_per_side: f64, increment_second: i64)
    {
        let socket = Arc::new(UdpSocket::bind(("0.0.0.0", PORT)).unwrap());
        let mut buffer = [0u8; 128];

        loop
        {
            match socket.recv_from(&mut buffer)
            {
                Ok((msg_size, client_addr)) =>
                {
                    let msg = String::from_utf8_lossy(&buffer[..msg_size]);
                    
                    if msg == DISCOVERY_MSG
                    {
                        godot_print!("İstemci bulundu: {}", client_addr);
                        socket.send_to(DISCOVERY_RESPONSE_MSG.as_bytes(), client_addr).unwrap();
                        break;
                    }
                }
                Err(err) =>
                {
                    godot_print!("[UDP HATA] Veri alınamadı {}", err);
                    break;
                }
            }
        }
    }
}