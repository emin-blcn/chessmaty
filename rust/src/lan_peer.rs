use std::io::{BufReader, BufRead, Write};
use std::net::{Ipv4Addr, UdpSocket, TcpStream, Shutdown};
use std::sync::Mutex;
use std::time::Duration;
use godot::prelude::*;
use godot::classes::{RefCounted, IRefCounted};
use serde_json::{Map, Value};

use crate::enums;
use crate::lan_protocol;


#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct LanPeer
{
    base: Base<RefCounted>,
    // using Mutex, because godot-rust lib locks object in mutable reference functions, which we want to avoid
    udp_socket: Mutex<Option<UdpSocket>>,
    tcp_stream: Mutex<Option<TcpStream>>,
    tcp_bufreader: Mutex<Option<BufReader<TcpStream>>>,
}


#[godot_api]
impl IRefCounted for LanPeer
{
    fn init(base: Base<RefCounted>) -> Self
    {
        let udp_socket = UdpSocket::bind(("0.0.0.0", 0)).unwrap();
        udp_socket.join_multicast_v4(&lan_protocol::MULTICAST_IP, &Ipv4Addr::new(0, 0, 0, 0)).unwrap();
        udp_socket.set_read_timeout(Some(Duration::from_millis(200))).unwrap();

        Self
        {
            base,
            udp_socket: Mutex::new(Some(udp_socket)),
            tcp_stream: Mutex::new(None),
            tcp_bufreader: Mutex::new(None)
        }
    }
}


#[godot_api]
impl LanPeer
{
    #[func]
    fn discover_all_hosts(&self) -> Dictionary<GString, GString>
    {
        let udp_socket_mutex_guard = self.udp_socket.lock().unwrap();
        let udp_socket = udp_socket_mutex_guard.as_ref().unwrap();

        let outgoing_text = Self::build_msg(lan_protocol::msg::DISCOVERY_PING, None);
        udp_socket.send_to(outgoing_text.as_bytes(), (lan_protocol::MULTICAST_IP, lan_protocol::PORT)).unwrap();

        let mut buffer = [0u8; 512];
        let mut discovered_hosts_for_godot = Dictionary::<GString, GString>::new();

        while let Ok((received_bytes_len, received_addr)) = udp_socket.recv_from(&mut buffer)
        {
            let received_text = String::from_utf8_lossy(&buffer[..received_bytes_len]).trim().to_string();
            let received_json_data = match serde_json::from_str::<Map<String, Value>>(received_text.as_str())
            {
                Err(_) => continue,
                Ok(json_data_map) => json_data_map
            };

            let received_msg_type = match received_json_data.get("msg_type")
            {
                None => continue,
                Some(msg_type_value) =>
                {
                    match msg_type_value.as_str()
                    {
                        None => continue,
                        Some(msg_type_str) => msg_type_str
                    }
                }
            };

            let received_params = match received_json_data.get("params")
            {
                None => continue,
                Some(params_value) =>
                {
                    match params_value.as_object()
                    {
                        None => continue,
                        Some(params_map) => params_map
                    }
                }
            };

            if received_msg_type == lan_protocol::msg::DISCOVERY_PONG
            {
                match serde_json::to_string(received_params)
                {
                    Ok(json_data_values_string) => discovered_hosts_for_godot.set(
                        &received_addr.ip().to_string().to_gstring(),
                        &json_data_values_string.to_gstring()
                    ),
                    Err(_) => continue
                }
            }
        }

        discovered_hosts_for_godot
    }


    #[func]
    fn join_host(&self, host_ip: GString) -> bool
    {
        let mut udp_socket_mutex_guard = self.udp_socket.lock().unwrap();
        let udp_socket = udp_socket_mutex_guard.as_ref().unwrap();

        let outgoing_text = Self::build_msg(lan_protocol::msg::JOIN_PING, None);
        udp_socket.send_to(outgoing_text.as_bytes(), (host_ip.to_string().as_str(), lan_protocol::PORT)).unwrap();

        let mut buffer = [0u8; 512];

        loop
        {
            match udp_socket.recv_from(&mut buffer)
            {
                Ok((received_bytes_len, received_addr)) =>
                {
                    let received_text = String::from_utf8_lossy(&buffer[..received_bytes_len]).trim().to_string();
                    let received_json_data = match serde_json::from_str::<Map<String, Value>>(received_text.as_str())
                    {
                        Err(_) => continue,
                        Ok(json_data_map) => json_data_map
                    };

                    let received_msg_type = match received_json_data.get("msg_type")
                    {
                        None => continue,
                        Some(msg_type_value) =>
                        {
                            match msg_type_value.as_str()
                            {
                                None => continue,
                                Some(msg_type_str) => msg_type_str
                            }
                        }
                    };

                    if received_msg_type == lan_protocol::msg::JOIN_PONG
                    {
                        let new_tcp_stream = TcpStream::connect(received_addr).unwrap();

                        {
                            let mut tcp_bufreader_mutex_guard = self.tcp_bufreader.lock().unwrap();
                            let mut tcp_stream_mutex_guard = self.tcp_stream.lock().unwrap();

                            *tcp_bufreader_mutex_guard = Some(BufReader::new(new_tcp_stream.try_clone().unwrap()));
                            *tcp_stream_mutex_guard = Some(new_tcp_stream);
                        }

                        *udp_socket_mutex_guard = None;
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
        let mut tcp_bufreader_mutex_guard = self.tcp_bufreader.lock().unwrap();
        let tcp_bufreader = tcp_bufreader_mutex_guard.as_mut().unwrap();
        let mut buffer = String::new();

        match tcp_bufreader.read_line(&mut buffer)
        {
            Ok(0) => GString::new(),
            Ok(_) =>
            {
                let received_msg = buffer.trim();
                received_msg.to_gstring()
            }
            Err(_) => GString::new()
        }
    }


    #[func]
    fn send_move_msg_to_opponent(&self, move_type: enums::MoveType, from: GString, to: GString, promotion_or_put_role: enums::PieceRole)
    {
        let outgoing_msg_type = lan_protocol::msg::MOVE;
        let mut outgoing_params = Map::<String, Value>::new();
        outgoing_params.insert(String::from("move_type"), Value::Number((move_type as u8).into()));
        outgoing_params.insert(String::from("from"), Value::String(from.to_string()));
        outgoing_params.insert(String::from("to"), Value::String(to.to_string()));
        outgoing_params.insert(String::from("promotion_or_put_role"), Value::Number((promotion_or_put_role as i32).into()));

        let outgoing_text = Self::build_msg(outgoing_msg_type, Some(outgoing_params));

        let mut tcp_stream_mutex_guard = self.tcp_stream.lock().unwrap();
        let tcp_stream = tcp_stream_mutex_guard.as_mut().unwrap();

        tcp_stream.write_all(outgoing_text.as_bytes()).unwrap();
    }


    #[func]
    fn send_undo_request_msg_to_opponent(&self)
    {
        let outgoing_msg_type = lan_protocol::msg::UNDO_REQUEST;

        let outgoing_text = Self::build_msg(outgoing_msg_type, None);

        let mut tcp_stream_mutex_guard = self.tcp_stream.lock().unwrap();
        let tcp_stream = tcp_stream_mutex_guard.as_mut().unwrap();

        tcp_stream.write_all(outgoing_text.as_bytes()).unwrap();
    }


    #[func]
    fn send_undo_response_msg_to_opponent(&self, accept: bool)
    {
        let outgoing_msg_type = lan_protocol::msg::UNDO_RESPONSE;
        let mut outgoing_params = Map::<String, Value>::new();
        outgoing_params.insert(String::from("response"), Value::Bool(accept));

        let outgoing_text = Self::build_msg(outgoing_msg_type, Some(outgoing_params));

        let mut tcp_stream_mutex_guard = self.tcp_stream.lock().unwrap();
        let tcp_stream = tcp_stream_mutex_guard.as_mut().unwrap();

        tcp_stream.write_all(outgoing_text.as_bytes()).unwrap();
    }


    fn build_msg(msg_type: &str, params: Option<Map<String, Value>>) -> String
    {
        let mut json_data = Map::<String, Value>::new();
        json_data.insert(
            "msg_type".into(),
            Value::String(msg_type.to_string())
        );
        json_data.insert(
            "params".into(),
            Value::Object(params.unwrap_or_default())
        );

        let mut msg = serde_json::to_string(&json_data).unwrap();
        msg.push('\n');
        msg
    }


    #[func]
    fn leave_stream(&self)
    {
        let mut tcp_stream_mutex_guard = self.tcp_stream.lock().unwrap();
        let tcp_stream = tcp_stream_mutex_guard.as_mut().unwrap();

        let _ = tcp_stream.shutdown(Shutdown::Both);
    }
}