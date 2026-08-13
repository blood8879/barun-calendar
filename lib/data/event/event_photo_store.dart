import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 기념일/생신 등 일정에 첨부하는 사진을 앱 전용 저장소에 복사·삭제하는 유틸.
/// 경쟁 앱("만능달력") 리뷰 중 가장 많은 공감(553)을 받은
/// "기념일에 사진넣기 기능" 요청에 대응해 추가되었다.
class EventPhotoStore {
  EventPhotoStore._();

  static final _picker = ImagePicker();

  /// 갤러리에서 사진 한 장을 골라 앱 전용 디렉터리(`event_photos/`)에 복사하고
  /// 새 파일의 절대 경로를 반환한다. 사용자가 선택을 취소하면 null.
  static Future<String?> pickAndStore() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return null;
    final dir = await _photoDir();
    final ext = picked.path.contains('.') ? picked.path.split('.').last : 'jpg';
    final destPath =
        '${dir.path}/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await File(picked.path).copy(destPath);
    return destPath;
  }

  /// 더 이상 참조되지 않는 사진 파일을 삭제한다. 파일이 없어도 조용히 무시.
  static Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<Directory> _photoDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/event_photos');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
