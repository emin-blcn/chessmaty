use std::net::{Ipv4Addr, Shutdown, TcpListener, TcpStream, UdpSocket};
use std::io::{BufRead, BufReader, Write};
use std::sync::Mutex;
use godot::prelude::*;
use godot::classes::{IRefCounted, Json, RefCounted};

use crate::enums as Enums;
use crate::lan_protocol as LanProtocol;


#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct LanHost
{
    base: Base<RefCounted>,
    // using Mutex, because godot-rust lib locks object in mutable reference functions, which we want to avoid
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
        let socket = UdpSocket::bind(("0.0.0.0", LanProtocol::PORT)).unwrap();
        socket.join_multicast_v4(&LanProtocol::MULTICAST_IP, &Ipv4Addr::new(0, 0, 0, 0)).unwrap();
        
        let mut buffer = [0u8; 512];

        loop
        {
            match socket.recv_from(&mut buffer)
            {
                Ok((size, addr)) =>
                {
                    let received_msg = String::from_utf8_lossy(&buffer[..size]).trim().to_string();
                    
                    if received_msg.starts_with(LanProtocol::DISCOVERY_PING_MSG)
                    {
                        let mut data_to_sent = config_data.duplicate_deep();
                        data_to_sent.remove("connection_type").unwrap();

                        let data_to_sent_json = Json::stringify(&data_to_sent.to_variant()).to_string();
                        let msg = format!("{}{}", LanProtocol::DISCOVERY_PONG_MSG, data_to_sent_json);

                        socket.send_to(msg.as_bytes(), addr).unwrap();
                    }
                    else if received_msg.as_str() == LanProtocol::JOIN_PING_MSG
                    {
                        let listener = TcpListener::bind(("0.0.0.0", LanProtocol::PORT)).unwrap();

                        socket.send_to(LanProtocol::JOIN_PONG_MSG.as_bytes(), addr).unwrap();

                        let stream = listener.accept().unwrap().0;

                        {
                            let mut tcp_bufreader_guard = self.tcp_bufreader.lock().unwrap();
                            *tcp_bufreader_guard = Some(BufReader::new(stream.try_clone().unwrap()));

                            let mut tcp_stream_guard = self.tcp_stream.lock().unwrap();
                            *tcp_stream_guard = Some(stream);
                        }

                        return true;
                    }
                    else if received_msg.as_str() == LanProtocol::CANCEL_WAITING_FOR_PEER_MSG
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
        dummy_socket.send_to(LanProtocol::CANCEL_WAITING_FOR_PEER_MSG.as_bytes(), ("127.0.0.1", LanProtocol::PORT)).unwrap();
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
                    return received_msg.to_gstring();
                }
                Err(_) => return GString::new()
            }
        }
    }


    #[func]
    fn send_move_msg_to_opponent(&self, move_type: Enums::MoveType, from_square: GString, to_square: GString, promotion_or_put_piece: Enums::Piece)
    {
        let mut stream_guard = self.tcp_stream.lock().unwrap();
        let stream = stream_guard.as_mut().unwrap();
        let msg = format!("{}|{}|{}|{}|{}\n", LanProtocol::MOVE_MSG, move_type as i32, from_square.to_string(), to_square.to_string(), promotion_or_put_piece as i32);

        stream.write_all(msg.as_bytes()).unwrap();
    }


    #[func]
    fn send_undo_request_msg_to_opponent(&self)
    {
        let mut stream_guard = self.tcp_stream.lock().unwrap();
        let stream = stream_guard.as_mut().unwrap();
        let msg = format!("{}\n", LanProtocol::UNDO_REQUEST_MSG);

        stream.write_all(msg.as_bytes()).unwrap();
    }


    #[func]
    fn send_undo_response_msg_to_opponent(&self, accept: bool)
    {
        let mut stream_guard = self.tcp_stream.lock().unwrap();
        let stream = stream_guard.as_mut().unwrap();
        let msg = format!("{}|{}\n", LanProtocol::UNDO_RESPONSE_MSG, if accept {"true"} else {"false"});

        stream.write_all(msg.as_bytes()).unwrap();
    }


    #[func]
    fn leave_stream(&self)
    {
        let mut stream_guard = self.tcp_stream.lock().unwrap();
        let stream = stream_guard.as_mut().unwrap();

        let _ = stream.shutdown(Shutdown::Both);
    }
}