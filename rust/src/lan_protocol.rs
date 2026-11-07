use std::net::Ipv4Addr;

pub const PORT: u16 = 8791;
pub const MULTICAST_IP: Ipv4Addr = Ipv4Addr::new(239, 125, 99, 201);

pub mod msg
{
    pub const DISCOVERY_PING: &str = "CHESSMATY_LAN_PING";
    pub const DISCOVERY_PONG: &str = "CHESSMATY_LAN_PONG";
    pub const JOIN_PING: &str = "CHESSMATY_LAN_JOIN_PING";
    pub const JOIN_PONG: &str = "CHESSMATY_LAN_JOIN_PONG";
    pub const MOVE: &str = "CHESSMATY_MOVE";
    pub const UNDO_REQUEST: &str = "CHESSMATY_UNDO_REQUEST";
    pub const UNDO_RESPONSE: &str = "CHESSMATY_UNDO_RESPONSE";
}