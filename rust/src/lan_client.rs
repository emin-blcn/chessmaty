use std::net::{UdpSocket, IpAddr, Ipv4Addr};
use std::time::Duration;
use godot::prelude::*;
use godot::classes::{IRefCounted, RefCounted};
use godot::global::godot_print;


const TARGET_PORT: u16 = 8791;
const DISCOVERY_MSG: &str = "CHESSMATY_LAN_SCAN";
const DISCOVERY_RESPONSE_MSG: &str = "CHESSMATY_LAN_STREAM_HERE";


#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct LanClient
{
    base: Base<RefCounted>
}


#[godot_api]
impl IRefCounted for LanClient
{
    fn init(base: Base<RefCounted>) -> Self
    {
        Self{base: base}
    }
}


#[godot_api]
impl LanClient
{
    #[func]
    fn scan_all_streams(&self) -> GString
    {
        let socket = UdpSocket::bind(("0.0.0.0", 0)).unwrap();
        socket.set_read_timeout(Some(Duration::from_millis(1500))).unwrap();

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

            let _ = socket.send_to(DISCOVERY_MSG.as_bytes(), (new_ip, TARGET_PORT));
        }

        let mut buffer = [0u8; 128];
        let mut active_streams_vec = Vec::<String>::new();

        loop
        {
            match socket.recv_from(&mut buffer)
            {
                Ok((size, addr)) =>
                {
                    let response = String::from_utf8_lossy(&buffer[..size]);
                    godot_print!("Gelen mesaj: {}", response);
                    if response == DISCOVERY_RESPONSE_MSG
                    {
                        active_streams_vec.push(addr.to_string());
                    }
                }
                Err(_) =>
                {
                    break;
                }
            }
        }

        GString::from(active_streams_vec.join(",").as_str())

    }


 //   async fn send_searh_message(addr: String) -> Option<String>
 //   {

 //   }


    fn get_user_ip() -> Ipv4Addr
    {
        let dummy_socket = UdpSocket::bind("0.0.0.0:0").unwrap();

        dummy_socket.connect(("1.1.1.1", 80)).unwrap();

        match dummy_socket.local_addr().unwrap().ip()
        {
            IpAddr::V4(ipv4_addr) => ipv4_addr,
            IpAddr::V6(_) => panic!("IPv6 address found but IPv4 address expected")
        }
    }
}