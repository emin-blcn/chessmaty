use std::io::{BufRead, BufReader, Write};
use std::net::{Ipv4Addr, Shutdown, TcpStream, UdpSocket};
use std::sync::Mutex;
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
    discover_udp_socket: Mutex<Option<UdpSocket>>,
    tcp_stream: Mutex<Option<TcpStream>>,
    tcp_bufreader: Mutex<Option<BufReader<TcpStream>>>,
}


#[godot_api]
impl IRefCounted for LanPeer
{
    fn init(base: Base<RefCounted>) -> Self
    {
        let socket = UdpSocket::bind(("0.0.0.0", 0)).unwrap();
        socket.set_read_timeout(Some(Duration::from_millis(200))).unwrap();
        socket.join_multicast_v4(&MULTICAST_IP, &Ipv4Addr::new(0, 0, 0, 0)).unwrap();

        Self { base, discover_udp_socket: Mutex::new(Some(socket)), tcp_stream: Mutex::new(None), tcp_bufreader: Mutex::new(None) }
    }
}


#[godot_api]
impl LanPeer
{
    #[func]
    fn discover_all_hosts(&self) -> Dictionary<GString, GString>
    {
        let socket_guard = self.discover_udp_socket.lock().unwrap();
        let socket = socket_guard.as_ref().unwrap();
        socket.send_to(DISCOVERY_PING_MSG.as_bytes(), (MULTICAST_IP, TARGET_PORT)).unwrap();

        let mut buffer = [0u8; 512];
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
    fn join_host(&self, host_ip: GString) -> bool
    {
        let socket_guard = self.discover_udp_socket.lock().unwrap();
        let socket = socket_guard.as_ref().unwrap();
        let host_ip_string = host_ip.to_string();

        socket.send_to(JOIN_PING_MSG.as_bytes(), (host_ip_string.as_str(), TARGET_PORT)).unwrap();

        let mut buffer = [0u8; 128];

        loop
        {
            match socket.recv_from(&mut buffer)
            {
                Ok((size, addr)) =>
                {
                    let received_msg = String::from_utf8_lossy(&buffer[..size]).trim().to_string();

                    if received_msg.starts_with(JOIN_PONG_MSG)
                    {
                        let stream = TcpStream::connect(addr).unwrap();

                        {
                            let mut tcp_bufreader_guard = self.tcp_bufreader.lock().unwrap();
                            let mut tcp_stream_guard = self.tcp_stream.lock().unwrap();

                            *tcp_bufreader_guard = Some(BufReader::new(stream.try_clone().unwrap()));
                            *tcp_stream_guard = Some(stream);
                        }
                        
                        return true;
                    }
                }
                Err(_) => return false
            }
        }
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