/* settings.dart - contains hardcoded P2P default settings. */

class P2PSettings {
  static const int port = 6573;

  // In this protocol, both server and client can't communicate with
  // how much bytes they have consumed at the application layer, so when we exceeded windowSize
  // at the receiving buffer (before we have parsed all of it), we just kill the connection,
  // BUUT!!! that should rarely happen. If something breaks,  maybe
  // check this out.

  // Nevertheless this suffices as a proof of concept.
  static const int maxWindowSize = 8*1024*1024; // 8 MB

  // Usually, a machine should be able to handle polling greater than 1024 fds, but
  // I've set this to 64 to prevent users from spamming (or atleast).
  static const int maxActiveEndpoints = 64;

  // How many bytes an endpoint is limited to sending every day
  // before we start killing the session.
  // This should prevent storage exhaustion from a malicious endpoint.
  // This includes application/text and other files
  static const int maxDataPerDay = 16*1024*1024; // 16 MB 
}
