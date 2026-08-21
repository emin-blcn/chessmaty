use std::net::{UdpSocket};
use godot::prelude::*;
use godot::classes::{IRefCounted, RefCounted};

use crate::enums as Enums;


const PORT: u16 = 8791;
const PING_DISCOVERY_MSG: &str = "CHESSMATY_LAN_PING";
const PONG_DISCOVERY_MSG: &str = "CHESSMATY_LAN_PONG";
const PING_JOIN_MSG: &str = "CHESSMATY_LAN_JOIN_PING";
const PONG_JOIN_MSG: &str = "CHESSMATY_LAN_JOIN_PONG";


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
        Self{base}
    }
}


#[godot_api]
impl LanStream
{
    #[func]
    fn wait_a_client(&self, config_data: Dictionary<GString, Variant>) -> GString
    {
        let player_name = config_data.get("player_name").unwrap().to::<GString>();
        let player_color = config_data.get("player_color").unwrap().to::<i32>();
        let game_mode = config_data.get("game_mode").unwrap().to::<i32>();
        let time_per_side = config_data.get("time_per_side").unwrap().to::<i64>();
        let time_increment = config_data.get("time_increment").unwrap().to::<i64>();

        let socket = UdpSocket::bind(("0.0.0.0", PORT)).unwrap();
        let mut buffer = [0u8; 128];

        loop
        {
            match socket.recv_from(&mut buffer)
            {
                Ok((msg_size, client_addr)) =>
                {
                    let msg = String::from_utf8_lossy(&buffer[..msg_size]);
                    
                    if msg.starts_with(PING_DISCOVERY_MSG)
                    {
                        let game_info_msg = format!("{}|{}|{}|{}|{}|{}", PONG_DISCOVERY_MSG, player_name, player_color, game_mode, time_per_side, time_increment);

                        socket.send_to(game_info_msg.as_bytes(), client_addr).unwrap();
                    }
                    else if msg.starts_with(PING_JOIN_MSG)
                    {
                        return msg.to_gstring();
                    }
                    else if  msg == "CANCEL_WAIT"
                    {
                        return GString::new();
                    }
                }
                Err(_) => return GString::new()
            }
        }
    }


    #[func]
    fn cancel_wait(&self)
    {
        let dummy_socket = UdpSocket::bind(("0.0.0.0", 0)).unwrap();
        dummy_socket.send_to("CANCEL_WAIT".as_bytes(), ("127.0.0.1", PORT)).unwrap();
    }

}