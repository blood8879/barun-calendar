import 'dart:typed_data';

/// 명세 §4-2 `lunar_1899_2050.bin` 포맷 디코더.
///
/// 헤더 16바이트(magic "BLUN", version, startYear, count, crc32(본문)) +
/// count × u32(LE) 본문. 무결성 검증(§4-5)은 magic/version/crc32 순으로 수행하며,
/// 실패 시 조용한 폴백 없이 [BinaryLunarTableException]을 던진다.
class LunarYearEntry {
  final int year;
  final int monthBits; // bit i = i번째 달, 1=대월(30일)
  final int leapMonthIndex; // 0=없음, 1~12=그 번호가 윤달
  final int newYearOffsetDays; // JDN(음력1/1) - JDN(양력 같은 해 1/1)

  const LunarYearEntry({
    required this.year,
    required this.monthBits,
    required this.leapMonthIndex,
    required this.newYearOffsetDays,
  });

  bool get hasLeapMonth => leapMonthIndex != 0;

  int monthLength(int monthOrdinal) =>
      ((monthBits >> monthOrdinal) & 1) == 1 ? 30 : 29;
}

class BinaryLunarTableException implements Exception {
  final String message;
  BinaryLunarTableException(this.message);
  @override
  String toString() => 'BinaryLunarTableException: $message';
}

class BinaryLunarTable {
  final int startYear;
  final int count;
  final List<LunarYearEntry> _entries;

  BinaryLunarTable._(this.startYear, this.count, this._entries);

  static BinaryLunarTable decode(Uint8List bytes) {
    if (bytes.length < 16) {
      throw BinaryLunarTableException('too short: ${bytes.length} bytes');
    }
    final magic = String.fromCharCodes(bytes.sublist(0, 4));
    if (magic != 'BLUN') {
      throw BinaryLunarTableException('bad magic: $magic');
    }
    final version = bytes[4];
    if (version != 1) {
      throw BinaryLunarTableException('unsupported version: $version');
    }
    final bd = ByteData.sublistView(bytes);
    final startYear = bd.getUint16(6, Endian.little);
    final count = bd.getUint16(8, Endian.little);
    final expectedCrc = bd.getUint32(10, Endian.little);

    final bodyStart = 16;
    final bodyLen = count * 4;
    if (bytes.length < bodyStart + bodyLen) {
      throw BinaryLunarTableException('body truncated');
    }
    final body = bytes.sublist(bodyStart, bodyStart + bodyLen);
    final actualCrc = _crc32(body);
    if (actualCrc != expectedCrc) {
      throw BinaryLunarTableException(
          'crc32 mismatch: expected $expectedCrc, got $actualCrc');
    }

    final bodyBd = ByteData.sublistView(body);
    final entries = <LunarYearEntry>[];
    for (var i = 0; i < count; i++) {
      final value = bodyBd.getUint32(i * 4, Endian.little);
      final monthBits = value & 0x1FFF;
      final leapIndex = (value >> 13) & 0xF;
      final offset = (value >> 17) & 0x3F;
      entries.add(LunarYearEntry(
        year: startYear + i,
        monthBits: monthBits,
        leapMonthIndex: leapIndex,
        newYearOffsetDays: offset,
      ));
    }
    final table = BinaryLunarTable._(startYear, count, entries);
    // §4-5 스팟 체크: 지원 범위 첫 해·끝 해가 예외 없이 조회되는지.
    table.forYear(startYear);
    table.forYear(startYear + count - 1);
    return table;
  }

  LunarYearEntry forYear(int year) {
    final idx = year - startYear;
    if (idx < 0 || idx >= count) {
      throw BinaryLunarTableException('year $year out of range');
    }
    return _entries[idx];
  }

  static int _crc32(List<int> data) {
    final table = _crcTable;
    var crc = 0xFFFFFFFF;
    for (final byte in data) {
      crc = table[(crc ^ byte) & 0xFF] ^ (crc >> 8);
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  static final List<int> _crcTable = _buildCrcTable();

  static List<int> _buildCrcTable() {
    final table = List<int>.filled(256, 0);
    for (var n = 0; n < 256; n++) {
      var c = n;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
      }
      table[n] = c;
    }
    return table;
  }
}
