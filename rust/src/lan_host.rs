use std::net::{SocketAddr, IpAddr, Ipv4Addr, UdpSocket, TcpListener, TcpStream, Shutdown};
use std::io::{BufReader, BufRead, Write, ErrorKind};
use std::time::Duration;
use std::sync::Mutex;
use serde_json::{Map, Value};
use godot::prelude::*;
use godot::classes::{RefCounted, IRefCounted};

use crate::enums;
use crate::lan_protocol;


#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct LanHost
{
    base: Base<RefCounted>,
    // using Mutex, because godot-rust lib locks object in mutable reference functions, which we want to avoid
    tcp_stream_mutex: Mutex<Option<TcpStream>>,
    tcp_bufreader_mutex: Mutex<Option<BufReader<TcpStream>>>,
    cancel_waiting_for_peer_mutex: Mutex<bool>
}


#[godot_api]
impl IRefCounted for LanHost
{
    fn init(base: Base<RefCounted>) -> Self
    {
        Self
        {
            base,
            tcp_stream_mutex: Mutex::new(None),
            tcp_bufreader_mutex: Mutex::new(None),
            cancel_waiting_for_peer_mutex: Mutex::new(false)
        }
    }
}


#[godot_api]
impl LanHost
{
    #[func]
    fn wait_for_peer(&self, config_data: Dictionary<GString, Variant>) -> bool
    {
        let mut outgoing_msg = lan_protocol::msg::DISCOVERY_PONG;
        let mut outgoing_params = Map::<String, Value>::new();
        outgoing_params.insert(String::from("host_name"), Value::String(config_data.get("host_name").unwrap().to::<String>()));
        outgoing_params.insert(String::from("player_color"), Value::Number(config_data.get("player_color").unwrap().to::<i32>().into()));
        outgoing_params.insert(String::from("game_mode"), Value::Number(config_data.get("game_mode").unwrap().to::<i32>().into()));
        outgoing_params.insert(String::from("connection_type"), Value::Number(config_data.get("connection_type").unwrap().to::<i32>().into()));
        outgoing_params.insert(String::from("fen_string"), Value::String(config_data.get("fen_string").unwrap().to::<String>()));
        outgoing_params.insert(String::from("time_per_side"), Value::Number(config_data.get("time_per_side").unwrap().to::<i64>().into()));
        outgoing_params.insert(String::from("time_increment"), Value::Number(config_data.get("time_increment").unwrap().to::<i64>().into()));
        let mut outgoing_text = Self::build_outgoing_text(outgoing_msg, Some(outgoing_params));

        let udp_socket = UdpSocket::bind(
            SocketAddr::new(
                IpAddr::V4(Ipv4Addr::new(0, 0, 0, 0)),
                lan_protocol::PORT
            )
        ).unwrap();
        udp_socket.join_multicast_v4(&lan_protocol::MULTICAST_IP, &Ipv4Addr::new(0, 0, 0, 0)).unwrap();
        udp_socket.set_read_timeout(Some(Duration::from_secs(1))).unwrap();

        let mut buffer = [0u8; 512];
        loop
        {
            match udp_socket.recv_from(&mut buffer)
            {
                Err(error) =>
                {
                    match error.kind()
                    {
                        ErrorKind::TimedOut | ErrorKind::WouldBlock =>
                        {
                            let mut cancel_waiting_for_peer_mutex_guard = self.cancel_waiting_for_peer_mutex.lock().unwrap();
                            if *cancel_waiting_for_peer_mutex_guard
                            {
                                *cancel_waiting_for_peer_mutex_guard = false;
                                return false;
                            }
                        }
                        _ => continue
                    }
                }
                Ok((received_bytes_len, received_socket_addr)) =>
                {
                    let received_text = String::from_utf8_lossy(buffer.get(..received_bytes_len).unwrap()).to_string();
                    let received_json = match serde_json::from_str::<Map<String, Value>>(received_text.as_str())
                    {
                        Err(_) => continue,
                        Ok(str_as_json_object) => str_as_json_object
                    };
                    let received_msg = match received_json.get("msg")
                    {
                        None => continue,
                        Some(msg_as_json_value) =>
                        {
                            match msg_as_json_value.as_str()
                            {
                                None => continue,
                                Some(msg_as_str) => msg_as_str
                            }
                        }
                    };
                    let _received_params = match received_json.get("params")
                    {
                        None => continue,
                        Some(params_as_json_value) =>
                        {
                            match params_as_json_value.as_object()
                            {
                                None => continue,
                                Some(params_as_json_object) => params_as_json_object
                            }
                        }
                    };

                    match received_msg
                    {
                        lan_protocol::msg::DISCOVERY_PING =>
                        {
                            udp_socket.send_to(outgoing_text.as_bytes(), received_socket_addr).unwrap();
                        }
                        lan_protocol::msg::JOIN_PING =>
                        {
                            outgoing_msg = lan_protocol::msg::JOIN_PONG;
                            outgoing_text = Self::build_outgoing_text(outgoing_msg, None);
                            udp_socket.send_to(outgoing_text.as_bytes(), received_socket_addr).unwrap();

                            let tcp_listener = TcpListener::bind(("0.0.0.0", lan_protocol::PORT)).unwrap();
                            let tcp_stream = tcp_listener.accept().unwrap().0;

                            let mut tcp_bufreader_mutex_guard = self.tcp_bufreader_mutex.lock().unwrap();
                            *tcp_bufreader_mutex_guard = Some(BufReader::with_capacity(512, tcp_stream.try_clone().unwrap()));

                            let mut tcp_stream_mutex_guard = self.tcp_stream_mutex.lock().unwrap();
                            *tcp_stream_mutex_guard = Some(tcp_stream);

                            return true;
                        }
                        _ => continue
                    }
                }
            }
        }
    }


    #[func]
    fn cancel_waiting_for_peer(&self)
    {
        let mut cancel_waiting_for_peer_mutex_guard = self.cancel_waiting_for_peer_mutex.lock().unwrap();
        *cancel_waiting_for_peer_mutex_guard = true;
    }


    #[func]
    fn wait_for_opponent_msg(&self) -> GString
    {
        let mut tcp_bufreader_mutex_guard = self.tcp_bufreader_mutex.lock().unwrap();
        let tcp_bufreader = tcp_bufreader_mutex_guard.as_mut().unwrap();

        let mut buffer = String::new();
        match tcp_bufreader.read_line(&mut buffer)
        {
            Err(_) => GString::new(),
            Ok(_) => buffer.to_gstring()
        }
    }


    #[func]
    fn send_move_msg_to_opponent(&self, move_type: enums::MoveType, from: GString, to: GString, promotion_or_put_role: enums::PieceRole)
    {
        let outgoing_msg = lan_protocol::msg::MOVE;
        let mut outgoing_params = Map::<String, Value>::new();
        outgoing_params.insert(String::from("move_type"), Value::Number((move_type as u8).into()));
        outgoing_params.insert(String::from("from"), Value::String(from.to_string()));
        outgoing_params.insert(String::from("to"), Value::String(to.to_string()));
        outgoing_params.insert(String::from("promotion_or_put_role"), Value::Number((promotion_or_put_role as i32).into()));
        let outgoing_text = Self::build_outgoing_text(outgoing_msg, Some(outgoing_params));

        let mut tcp_stream_mutex_guard = self.tcp_stream_mutex.lock().unwrap();
        let tcp_stream = tcp_stream_mutex_guard.as_mut().unwrap();

        tcp_stream.write_all(outgoing_text.as_bytes()).unwrap();
    }


    #[func]
    fn send_undo_request_msg_to_opponent(&self)
    {
        let outgoing_msg = lan_protocol::msg::UNDO_REQUEST;
        let outgoing_text = Self::build_outgoing_text(outgoing_msg, None);
        
        let mut tcp_stream_mutex_guard = self.tcp_stream_mutex.lock().unwrap();
        let tcp_stream = tcp_stream_mutex_guard.as_mut().unwrap();

        tcp_stream.write_all(outgoing_text.as_bytes()).unwrap();
    }


    #[func]
    fn send_undo_response_msg_to_opponent(&self, accept: bool)
    {
        let outgoing_msg = lan_protocol::msg::UNDO_RESPONSE;
        let mut outgoing_params = Map::<String, Value>::new();
        outgoing_params.insert(String::from("response"), Value::Bool(accept));
        let outgoing_text = Self::build_outgoing_text(outgoing_msg, Some(outgoing_params));

        let mut tcp_stream_mutex_guard = self.tcp_stream_mutex.lock().unwrap();
        let tcp_stream = tcp_stream_mutex_guard.as_mut().unwrap();

        tcp_stream.write_all(outgoing_text.as_bytes()).unwrap();
    }


    fn build_outgoing_text(msg: &str, params: Option<Map<String, Value>>) -> String
    {
        let mut json_object = Map::<String, Value>::new();
        json_object.insert(
            "msg".into(),
            Value::String(msg.to_string())
        );
        json_object.insert(
            "params".into(),
            Value::Object(params.unwrap_or_default())
        );

        let mut outgoing_text = serde_json::to_string(&json_object).unwrap();
        outgoing_text.push('\n');
        outgoing_text
    }


    #[func]
    fn leave_stream(&self)
    {
        let mut tcp_stream_mutex_guard = self.tcp_stream_mutex.lock().unwrap();
        let tcp_stream = tcp_stream_mutex_guard.as_mut().unwrap();

        let _ = tcp_stream.shutdown(Shutdown::Both);
    }
}