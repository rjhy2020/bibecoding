요약: 네, 제시한 전략으로 “대부분” 해결됩니다. 다만 핵심은 **CanvasKit 전환만이 아니라 ‘한글 폰트 번들 + 사전 로드(웜업)’**입니다. HTML/CanvasKit 모두에서 한글 입력 중 잠깐 □(tofu)가 뜨는 이슈가 보고되어 있어서(엔진/폰트 로딩 타이밍) 폰트 로딩을 확실히 잡아줘야 재현이 사라집니다. 
GitHub
+1

아래처럼 I1~I5로 진행하면 안정화됩니다.

I1. 현상 재현 & 기준선 잡기

목표: 어떤 조합에서 □가 뜨는지 명확히 측정.

체크 매트릭스:

렌더러: HTML vs CanvasKit

폰트: 시스템 기본/GoogleFonts 런타임 로드/자체 번들

브라우저: Chrome/Edge/Firefox

Acceptance Criteria (AC)

재현 영상 1개/조합, 30초 급타 입력 시 □ 발생 횟수 기록(0이면 PASS 기준 후보).

Flutter, 브라우저 버전과 빌드 플래그 기록.

참고: CanvasKit에서도 “첫 타자 구간에 □가 보인 뒤 정상 글리프로 바뀌는” 보고가 있습니다(폰트가 처음 서브셋 로드될 때). HTML 렌더러에서도 유사 리포트가 존재합니다. 
GitHub
+1

I2. 폰트 번들 + 사전 로드(가장 중요)

한글 폰트(예: Noto Sans KR) 를 assets로 번들하고 테마의 기본 폰트로 지정
pubspec.yaml

flutter:
  uses-material-design: true
  assets:
    - assets/fonts/
  fonts:
    - family: NotoSansKR
      fonts:
        - asset: assets/fonts/NotoSansKR-Regular.ttf
        - asset: assets/fonts/NotoSansKR-Medium.ttf
          weight: 500


theme: ThemeData(fontFamily: 'NotoSansKR', ...)
(공식 문서: 커스텀 폰트 추가) 
docs.flutter.dev

앱 시작 전에 폰트 로딩을 await
main.dart

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/services.dart' show FontLoader;

Future<void> _preloadFonts() async {
  final loader = FontLoader('NotoSansKR')
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Medium.ttf'));
  await loader.load();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _preloadFonts();        // 폰트 로딩을 보장
  runApp(const EnglishPlease());
}


(FontLoader API) 
api.flutter.dev

만약 google_fonts를 쓰고 있다면: 런타임 패치형은 로딩 중 시각적 스왑이 발생할 수 있으니, 가능하면 자체 번들 + pendingFonts로 대기 또는 allowRuntimeFetching=false 구성을 권장합니다. (패키지 가이드/체인지로그) 
Dart packages
+1

웜업(초기 그리프 캐시 유도)
앱 첫 빌드에 화면 밖에 한 번 그려 폰트를 따뜻하게 만듭니다:

class FontWarmUp extends StatelessWidget {
  const FontWarmUp({super.key});
  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: true,
      child: Text(
        '가나다라마바사아자차카타파하',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}


앱 루트 위젯 트리에 const FontWarmUp()을 넣어주세요. (엔진 이슈 특성상 실무에서 많이 쓰는 우회법)

AC

콜드스타트 후 30초 급타 입력에서 □ 미발생(0회).

새로고침 후에도 동일.

google_fonts 사용 시, 첫 화면 진입 전에 await GoogleFonts.pendingFonts() 또는 FontLoader로 대기. 
Dart packages

I3. CanvasKit 렌더러 전환(+빌드 플래그 고정)

개발시:
flutter run -d chrome --web-renderer canvaskit

배포 빌드:
flutter build web --web-renderer canvaskit --release

이유: HTML 렌더러의 IME/컨텐츠에디터 경계 이슈를 피하고, Skia 경로로 텍스트를 일관되게 그리기 위함(웹 렌더러 차이 및 CanvasKit 설명). 단, CanvasKit도 “첫 로딩 시” 폰트 서브셋 로드 타이밍에 □가 보인 사례가 있어 I2가 선행돼야 효과적입니다. 
Medium
Skia

AC

CanvasKit + I2 적용 상태에서 □ 0회.

HTML 대비 입력 지연/커서 끊김 감소를 체감(주관 평가지표 포함).

I4. 입력 위젯 안정화(재빌드/포커스 손실 차단)

전용 Stateful 위젯으로 분리하고, 상위 setState가 입력 위젯을 재빌드하지 않게 구조화(메시지 리스트/로딩 상태는 Provider/ChangeNotifier 등으로 분리).

FocusNode/ValueKey/RepaintBoundary 부여:

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({super.key});
  @override State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with AutomaticKeepAliveClientMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode(debugLabel: 'chat_input');
  @override bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(
      child: TextField(
        key: const ValueKey('chat-input'),
        focusNode: _focusNode,
        controller: _controller,
        // Web에선 효과 제한적이지만 모바일 간섭 차단용:
        autocorrect: false,
        enableSuggestions: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
        textInputAction: TextInputAction.newline,
        maxLines: null,
        decoration: const InputDecoration(
          hintText: 'Type Korean fast…',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}


주의: SpellCheckConfiguration은 Android/iOS에서만 동작합니다. Web에선 기본적으로 스펠체크 서비스가 없어 실효가 제한적입니다(비활성 지정 자체는 무해). 
api.flutter.dev
+1

AC

상위 리스트가 setState되어도 입력 중 커서/조합 영역(밑줄) 유지.

포커스/조합 영역 깜빡임 없음.

레이아웃 오버플로우 없는지 확인(필요시 Expanded/SizedBox로 제약). 
Stack Overflow
+1

I5. 최신 환경 & 교차 검증

Flutter 최신 안정 채널로 업그레이드 후 다시 I1 측정(엔진/웹 텍스트 경로는 지속 개선 중).

브라우저 교차 테스트: Chrome/Edge/Firefox. 일부 브라우저의 IME 구성(Composition) 동작 차로 인해 잔여 이슈가 존재할 수 있습니다.

AC

세 브라우저 모두에서 콜드스타트/새로고침 후 30초 급타 입력 시 □=0회.

왜 이 조합이 먹히는가?

□ 현상은 입력 중(IME composition) + 폰트 로딩/서브셋 교체 타이밍이 겹치며 생기는 경우가 많습니다. 이건 HTML/CanvasKit 모두에서 보고가 있습니다. 정답은 “렌더러만 바꾸기”가 아니라 폰트 로딩을 확정하는 것입니다. 
GitHub
+1

Web에선 SpellCheckConfiguration이 실질적으로 영향이 적고(안드/iOS 중심), 대신 재빌드/포커스 손실이 조합 영역을 깨트릴 수 있어 입력 위젯 격리가 중요합니다. 
api.flutter.dev

google_fonts 런타임 패치형은 로딩 완료 전 시각적 스왑이 생길 수 있어, 자체 번들 + pendingFonts/FontLoader로 시작 단계에서 대기하면 스왑/□가 줄어듭니다. 
Dart packages
+1

남을 수 있는 잔여 리스크 & 우회책

아주 저속 네트워크의 최초 접속 첫 프레임에서 드물게 폰트 프리로드 전에 타자 시작하면 □가 보일 수 있습니다(그래서 스플래시 동안 대기/웜업을 권장).

만약 드물게라도 남는다면, 웹 한정 네이티브 <textarea> 오버레이(PlatformView)로 입력만 DOM에 위임하고 Flutter는 결과만 반영하는 하이브리드 구조가 최종 우회책입니다(구현 비용은 큼).

결론

질문에 적어준 전략 **+ “폰트 번들 & 사전 로드(웜업)”**까지 합치면, 재현 케이스 대부분에서 □ 깨짐이 사라집니다.

위 I1~I5 순서로 적용하고, 각 AC 기준 충족 여부를 체크하면 됩니다.

특히 I2가 결정타입니다: 번들 폰트, 시작 전 로드 대기, 간단 웜업 문자열.