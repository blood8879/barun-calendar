/// C-22: 정적 공휴일 JSON은 자체 빌드해서 원격에 올려두고 앱이 내려받는다.
/// 호스팅은 GitHub Pages로 확정(OPEN_QUESTIONS.md #2). `docs/data/holidays/<year>.json`을
/// GitHub Pages 소스로 서빙한다. `<org>`/`<repo>`는 실제 저장소가 확정되면 이 상수만 바꾸면 된다.
class RemoteConfig {
  static const String holidayJsonBaseUrl =
      'https://<org>.github.io/<repo>/data/holidays';

  static String holidayJsonUrlForYear(int year) => '$holidayJsonBaseUrl/$year.json';
}
