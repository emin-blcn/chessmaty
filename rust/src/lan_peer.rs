use std::io::{BufRead, BufReader, Write};
use std::net::{UdpSocket, Ipv4Addr, TcpStream};
use std::time::Duration;
use godot::prelude::*;
use godot::classes::{IRefCounted, RefCounted};

use crate::enums as Enums;


const TARGET_PORT: u16 = 8791;
const MULTICAST_IP: Ipv4Addr = Ipv4Addr::new(239, 125, 99, 201);
const DISCOVERY_PING_MSG: &str = "CHESSMATY_LAN_PING";
const DISCOVERY_PONG_MSG: &str = "CHESSMATY_LAN_PONG";
const JOIN_PING_MSG: &str = "CHESSMATY_LAN_JOIN_PING";
const JOIN_PONG_MSG: &str = "CHESSMATY_LAN_JOIN_PONG";
const MOVE_MSG: &str = "CHESSMATY_MOVE";


#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct LanPeer
{
    base: Base<RefCounted>,
    discover_socket: Option<UdpSocket>,
    tcp_stream: Option<TcpStream>,
    tcp_bufreader: Option<BufReader<TcpStream>>,
}


#[godot_api]
impl IRefCounted for LanPeer
{
    fn init(base: Base<RefCounted>) -> Self
    {
        let socket = UdpSocket::bind(("0.0.0.0", 0)).unwrap();
        socket.set_read_timeout(Some(Duration::from_millis(200))).unwrap();
        socket.join_multicast_v4(&MULTICAST_IP, &Ipv4Addr::new(0, 0, 0, 0)).unwrap();

        Self { base, discover_socket: Some(socket), tcp_stream: None, tcp_bufreader: None }
    }
}


#[godot_api]
impl LanPeer
{
    #[func]
    fn discover_all_hosts(&mut self) -> Dictionary<GString, GString>
    {
        let socket = self.discover_socket.as_ref().unwrap();
        socket.send_to(DISCOVERY_PING_MSG.as_bytes(), (MULTICAST_IP, TARGET_PORT)).unwrap();

        let mut buffer = [0u8; 128];
        let mut discovered_hosts_for_godot = Dictionary::<GString, GString>::new();

        loop
        {
            match socket.recv_from(&mut buffer)
            {
                Ok((msg_size, addr)) =>
                {
                    let received_msg = String::from_utf8_lossy(&buffer[..msg_size]).to_string();
                    let received_ip = addr.ip().to_string();

                    if received_msg.starts_with(DISCOVERY_PONG_MSG)
                    {
                        let _ = discovered_hosts_for_godot.insert(&received_ip.to_gstring(), &received_msg.to_gstring());
                    }
                }
                Err(_) => break
            }
        }
        discovered_hosts_for_godot
    }


    #[func]
    fn join_host(&mut self, host_ip: GString) -> bool
    {
        let socket = self.discover_socket.take().unwrap();
        let host_ip_string = host_ip.to_string();

        socket.send_to(JOIN_PING_MSG.as_bytes(), (host_ip_string.as_str(), TARGET_PORT)).unwrap();

        let mut buffer = [0u8; 128];

        loop
        {
            match socket.recv_from(&mut buffer)
            {
                Ok((msg_size, addr)) =>
                {
                    let received_msg = String::from_utf8_lossy(&buffer[..msg_size]).trim().to_string();

                    if received_msg.starts_with(JOIN_PONG_MSG)
                    {
                        let stream = TcpStream::connect(addr).unwrap();

                        self.tcp_bufreader = Some(BufReader::new(stream.try_clone().unwrap()));
                        self.tcp_stream = Some(stream);
                        return true;
                    }
                }
                Err(_) => return false
            }
        }
    }


    #[func]
    fn wait_for_opponent_msg(&mut self) -> GString
    {
        let reader = self.tcp_bufreader.as_mut().unwrap();
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
    fn send_move_to_opponent(&mut self, move_type: Enums::MoveType, from_square: GString, to_square: GString, promotion_piece: Enums::Piece)
    {
        let stream = self.tcp_stream.as_mut().unwrap();
        let msg = format!("{}|{}|{}|{}|{}\n", MOVE_MSG, move_type as i32, from_square.to_string(), to_square.to_string(), promotion_piece as i32);

        stream.write_all(msg.as_bytes()).unwrap();
    }
}