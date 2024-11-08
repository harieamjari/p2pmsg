class P2PSettings {
  static const int port = 6573;

  // max Window size, in this hurriedly written protocol, both server and client can't communicate with
  // how much bytes they have consumed at the application layer, so when we exceeded windowSize
  // at the receiving buffer (before we have parsed all of it), we just kill the connection,
  // BUT!!! that should rarely happen.

  // Nevertheless this suffices as a proof of concept.
  static const int windowSize = 8*1024*1024; // 8 Mebibyte
}
