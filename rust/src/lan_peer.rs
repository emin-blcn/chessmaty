use std::net::{SocketAddr, IpAddr, Ipv4Addr, UdpSocket, TcpStream, Shutdown};
use std::io::{BufReader, BufRead, Write};
use std::time::Duration;
use std::sync::Mutex;
use serde_json::{Map, Value};
use godot::prelude::*;
use godot::classes::{RefCounted, IRefCounted};

use crate::enums;
use crate::lan_protocol;


#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct LanPeer
{
    base: Base<RefCounted>,
    // using Mutex, because godot-rust lib locks object in mutable reference functions, which we want to avoid
    udp_socket_mutex: Mutex<Option<UdpSocket>>,
    tcp_stream_mutex: Mutex<Option<TcpStream>>,
    tcp_bufreader_mutex: Mutex<Option<BufReader<TcpStream>>>,
}


#[godot_api]
impl IRefCounted for LanPeer
{
    fn init(base: Base<RefCounted>) -> Self
    {
        let udp_socket = UdpSocket::bind(
            SocketAddr::new(
                IpAddr::V4(Ipv4Addr::new(0, 0, 0, 0)),
                0
            )
        ).unwrap();
        udp_socket.set_read_timeout(Some(Duration::from_millis(200))).unwrap();

        Self
        {
            base,
            udp_socket_mutex: Mutex::new(Some(udp_socket)),
            tcp_stream_mutex: Mutex::new(None),
            tcp_bufreader_mutex: Mutex::new(None)
        }
    }
}


#[godot_api]
impl LanPeer
{
    #[func]
    fn discover_all_hosts(&self) -> Dictionary<GString, GString>
    {
        let mut discovered_hosts = Dictionary::<GString, GString>::new();

        let outgoing_msg = lan_protocol::msg::DISCOVERY_PING;
        let outgoing_text = Self::build_outgoing_text(outgoing_msg, None);

        let udp_socket_mutex_guard = self.udp_socket_mutex.lock().unwrap();
        let udp_socket = udp_socket_mutex_guard.as_ref().unwrap();
        udp_socket.send_to(
            outgoing_text.as_bytes(),
            SocketAddr::new(
                IpAddr::V4(lan_protocol::MULTICAST_IP),
                lan_protocol::PORT
            )
        ).unwrap();
        
        let mut buffer = [0u8; 512];
        while let Ok((received_bytes_len, received_socket_addr)) = udp_socket.recv_from(&mut buffer)
        {
            let received_text = String::from_utf8_lossy(&buffer.get(0..received_bytes_len).unwrap()).to_string();
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
            let received_params = match received_json.get("params")
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

            if received_msg == lan_protocol::msg::DISCOVERY_PONG
            {
                match serde_json::to_string(received_params)
                {
                    Ok(json_params_to_string) => discovered_hosts.set(
                        &received_socket_addr.ip().to_string().to_gstring(),
                        &json_params_to_string.to_gstring()
                    ),
                    Err(_) => continue
                }
            }
        }

        discovered_hosts
    }


    #[func]
    fn join_host(&self, host_ip: GString) -> bool
    {
        let outgoing_msg = lan_protocol::msg::JOIN_PING;
        let outgoing_text = Self::build_outgoing_text(outgoing_msg, None);
        
        let mut udp_socket_mutex_guard = self.udp_socket_mutex.lock().unwrap();
        let udp_socket = udp_socket_mutex_guard.as_ref().unwrap();
        udp_socket.send_to(
            outgoing_text.as_bytes(),
            SocketAddr::new(
                IpAddr::V4(host_ip.to_string().parse::<Ipv4Addr>().unwrap()),
                lan_protocol::PORT
            )
        ).unwrap();

        let mut buffer = [0u8; 512];
        loop
        {
            match udp_socket.recv_from(&mut buffer)
            {
                Err(_) => return false,
                Ok((received_bytes_len, received_socket_addr)) =>
                {
                    let received_text = String::from_utf8_lossy(buffer.get(0..received_bytes_len).unwrap()).to_string();
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
                                Some(msg_str) => msg_str
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

                    if received_msg == lan_protocol::msg::JOIN_PONG
                    {
                        let new_tcp_stream = TcpStream::connect(received_socket_addr).unwrap();

                        {
                            let mut tcp_bufreader_mutex_guard = self.tcp_bufreader_mutex.lock().unwrap();
                            let mut tcp_stream_mutex_guard = self.tcp_stream_mutex.lock().unwrap();

                            *tcp_bufreader_mutex_guard = Some(BufReader::new(new_tcp_stream.try_clone().unwrap()));
                            *tcp_stream_mutex_guard = Some(new_tcp_stream);
                        }

                        *udp_socket_mutex_guard = None;
                        return true;
                    }
                }
            }
        }
    }


    #[func]
    fn wait_for_opponent_msg(&self) -> GString
    {
        let mut tcp_bufreader_mutex_guard = self.tcp_bufreader_mutex.lock().unwrap();
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