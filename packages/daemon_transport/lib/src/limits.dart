// A relay's message is a Noise message: one over noise's maxMessage ends
// the socket. Neither WebSocket can refuse it before it is read, so the
// check comes once it has arrived.
export 'package:noise/noise.dart' show maxMessage;

/// How often dart:io's socket pings; a ping unanswered by the next ends
/// it. A browser's WebSocket can't ping: there the app's own calls keep
/// the connection alive (the relay ends one silent 90 s).
const keepAlive = Duration(seconds: 25);
