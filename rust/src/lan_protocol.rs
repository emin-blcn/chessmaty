use std::net::Ipv4Addr;

pub const PORT: u16 = 8791;
pub const MULTICAST_IP: Ipv4Addr = Ipv4Addr::new(239, 125, 99, 201);
pub const CANCEL_WAITING_FOR_PEER_MSG: &str = "CANCEL_WAIT_FOR_PEER";
pub const DISCOVERY_PING_MSG: &str = "CHESSMATY_LAN_PING";
pub const DISCOVERY_PONG_MSG: &str = "CHESSMATY_LAN_PONG";
pub const JOIN_PING_MSG: &str = "CHESSMATY_LAN_JOIN_PING";
pub const JOIN_PONG_MSG: &str = "CHESSMATY_LAN_JOIN_PONG";
pub const MOVE_MSG: &str = "CHESSMATY_MOVE";
pub const UNDO_REQUEST_MSG: &str = "CHESSMATY_UNDO_REQUEST";
pub const UNDO_RESPONSE_MSG: &str = "CHESSMATY_UNDO_RESPONSE";