/// The largest message taken from a relay: a Noise message. A bigger one
/// ends the connection before it is read (dart:io's WebSocket has no such
/// limit, and would hold whatever a hostile relay sends).
const maxMessage = 65535;

/// How often the socket pings; three times as long without a byte from the
/// relay ends it. A browser's WebSocket can't ping: there the app's own
/// calls keep the connection alive (the relay ends one silent 90 s).
Duration keepAlive = const Duration(seconds: 25);
