import 'dart:typed_data';
import 'dart:async';
import 'dart:io';

class P2PUtils {
  static int UnixEpoch() {
    return (DateTime.now().millisecondsSinceEpoch / 1000).toInt();
  }
  
  // Big endian
  static int List2Uint64(List<int> l) {
    assert(l.length >= 8);
    return (l[0] << 56) +
        (l[1] << 48) +
        (l[2] << 40) +
        (l[3] << 32) +
        (l[4] << 24) +
        (l[5] << 16) +
        (l[6] << 8) +
        l[7];
  }
  
  static int List2Uint32(List<int> l) {
    assert(l.length >= 4);
    return (l[0] << 24) + (l[1] << 16) + (l[2] << 8) + l[3];
  }
  
  static Uint8List Uint32ToList(int i) {
    Uint8List l = Uint8List(4);
    l[0] = (i >> 24) & 255;
    l[1] = (i >> 16) & 255;
    l[2] = (i >> 8) & 255;
    l[3] = i & 255;
    return l;
  }
  
  static Uint8List Uint64ToList(int i) {
    Uint8List l = Uint8List(8);
    l[0] = (i >> 56) & 255;
    l[1] = (i >> 48) & 255;
    l[2] = (i >> 40) & 255;
    l[3] = (i >> 32) & 255;
    l[4] = (i >> 24) & 255;
    l[5] = (i >> 16) & 255;
    l[6] = (i >> 8) & 255;
    l[7] = i & 255;
    return l;
  }

}
