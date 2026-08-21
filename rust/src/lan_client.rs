use std::collections::HashMap;
use std::net::{UdpSocket, IpAddr, Ipv4Addr};
use std::time::Duration;
use godot::prelude::*;
use godot::classes::{IRefCounted, RefCounted};


const TARGET_PORT: u16 = 8791;
const PING_DISCOVERY_MSG: &str = "CHESSMATY_LAN_PING";
const PONG_DISCOVERY_MSG: &str = "CHESSMATY_LAN_PONG";
const PING_JOIN_MSG: &str = "CHESSMATY_LAN_JOIN_PING";
const PONG_JOIN_MSG: &str = "CHESSMATY_LAN_JOIN_PONG";


#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct LanClient
{
    base: Base<RefCounted>,
    discovered_streams: HashMap<String, String>
}


#[godot_api]
impl IRefCounted for LanClient
{
    fn init(base: Base<RefCounted>) -> Self
    {
        Self
        {
            base,
            discovered_streams: HashMap::<String, String>::new()
        }
    }
}


#[godot_api]
impl LanClient
{
    #[func]
    fn scan_all_streams(&mut self) -> Dictionary<GString, GString>
    {
        let socket = UdpSocket::bind(("0.0.0.0", 0)).unwrap();
        socket.set_read_timeout(Some(Duration::from_millis(200))).unwrap();

        let user_ip = Self::get_user_ip();
        let mut octets = user_ip.octets();

        for i in 1..255
        {
            octets[3] = i as u8;
            let new_ip = Ipv4Addr::from_octets(octets);

            //if new_ip == user_ip
            //{
            //    continue;
            //}

            let _ = socket.send_to(PING_DISCOVERY_MSG.as_bytes(), (new_ip, TARGET_PORT));
        }

        self.discovered_streams.clear();

        let mut buffer = [0u8; 128];
        let mut discovered_streams_for_godot = Dictionary::<GString, GString>::new();

        loop
        {
            match socket.recv_from(&mut buffer)
            {
                Ok((size, addr)) =>
                {
                    let received_msg = String::from_utf8_lossy(&buffer[..size]).to_string();
                    let received_ip = addr.ip().to_string();

                    if received_msg.starts_with(PONG_DISCOVERY_MSG)
                    {
                        let _ = discovered_streams_for_godot.insert(&received_ip.to_gstring(),  &received_msg.to_gstring());
                        let _ = self.discovered_streams.insert(received_ip, received_msg);
                    }
                }
                Err(_) => break
            }
        }
        discovered_streams_for_godot
    }


    fn get_user_ip() -> Ipv4Addr
    {
        let dummy_socket = UdpSocket::bind(("0.0.0.0", 0)).unwrap();
        dummy_socket.connect(("1.1.1.1", 80)).unwrap();
        match dummy_socket.local_addr().unwrap().ip()
        {
            IpAddr::V4(ipv4_addr) => ipv4_addr,
            IpAddr::V6(_) => panic!("IPv6 address found but IPv4 address expected")
        }
    }
}