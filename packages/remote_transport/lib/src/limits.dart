/// The largest message taken from a relay: a Noise message. A bigger one
/// ends the connection; neither WebSocket can refuse it before it is read,
/// so the check comes once it has arrived.
const maxMessage = 65535;

/// How often dart:io's socket pings; a ping unanswered by the next ends
/// it. A browser's WebSocket can't ping: there the app's own calls keep
/// the connection alive (the relay ends one silent 90 s).
const keepAlive = Duration(seconds: 25);
