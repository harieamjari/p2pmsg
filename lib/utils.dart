import 'dart:typed_data';
import 'dart:async';
import 'dart:io';

class P2PUtils {
  // reads 32 bit length prefixed field then seeks it.
  static Uint8List read32Field(List <int> l) {
    int fieldLen = list2Uint32(l);
    l.removeRange(0, 4);
    Uint8List field = Uint8List(fieldLen);
    List.copyRange<int>(field, 0, l, 0, fieldLen);
    l.removeRange(0, fieldLen);
    return field;
  }

  // reads uint32 field
  static int readU32Int(List <int> l) {
    int ret = list2Uint32(l);
    l.removeRange(0, 4);
    return ret;
  } 

  // reads uint64 field
  static int readU64Int(List <int> l) {
    int ret = list2Uint64(l);
    l.removeRange(0, 8);
    return ret;
  } 

  static String List2String(Uint8List list){
    return String.fromCharCodes(list);
  }

  static Uint8List String2List(String str){
    return  Uint8List.fromList(str.codeUnits);
  }

  static String fingerprintToHex(String str) {
    String builder = '';
    List<String> list = str.split(':');
    for (var i = 0; i < list.length; i++) {
      if (i > 1 && (i%2) == 0)
        builder += ' ';
      builder += int.parse(list[i]).toRadixString(16).padLeft(2, '0');
    }
    return builder;
  }

  static int unixEpoch() {
    return (DateTime.now().millisecondsSinceEpoch / 1000).toInt();
  }
  
  // Big endian
  static int list2Uint64(List<int> l) {
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
  
  static int list2Uint32(List<int> l) {
    assert(l.length >= 4);
    return (l[0] << 24) + (l[1] << 16) + (l[2] << 8) + l[3];
  }
  
  static Uint8List uint32ToList(int i) {
    Uint8List l = Uint8List(4);
    l[0] = (i >> 24) & 255;
    l[1] = (i >> 16) & 255;
    l[2] = (i >> 8) & 255;
    l[3] = i & 255;
    return l;
  }
  
  static Uint8List uint64ToList(int i) {
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
