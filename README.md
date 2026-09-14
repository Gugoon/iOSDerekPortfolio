# iOS Derek Portfolio

개인 포트폴리오를 보여 주는 iOS 네이티브 앱입니다.
콘텐츠(프로필 · 경력 · 기술 · 프로젝트)는 **Cloud Firestore** 에 두고, 앱은 **Firebase SDK 없이
REST API 로 직접** 읽고 씁니다. 같은 Firestore 를 쓰는 Flutter 웹 포트폴리오와 기능이 같습니다.

| | |
| --- | --- |
| UI | SwiftUI |
| 비동기 · 상태 | Combine, Swift Concurrency (async/await) |
| 백엔드 | Cloud Firestore REST, Firebase Auth REST |
| 최소 버전 | iOS 17.0 · iPhone |
| 개발 환경 | Xcode 26 |
| 외부 의존성 | 없음 (SPM · CocoaPods 사용 안 함) |

---

## 목차

- [주요 기능](#주요-기능)
- [빠르게 시작하기](#빠르게-시작하기)
- [프로젝트 구조](#프로젝트-구조)
- [아키텍처](#아키텍처)
- [네트워크 레이어](#네트워크-레이어)
- [Firestore 데이터 모델](#firestore-데이터-모델)
- [관리자 기능 설정](#관리자-기능-설정)
- [개발 가이드](#개발-가이드)
- [알려진 제약](#알려진-제약)

---

## 주요 기능

**방문자 화면**
- 히어로 · 보유 기술(탭 필터) · 경력 요약 · 프로젝트 아카이브(카테고리 필터) · 연락처
- 경력 항목을 누르면 해당 회사의 프로젝트를 시트로 표시
- 이력서 PDF 자동 조판 → PDFKit 미리보기 · 공유(저장) · 인쇄
- Firestore 읽기에 실패하거나 설정이 없으면 내장 샘플 데이터로 표시 (빈 화면이 뜨지 않음)

**관리자 화면** (푸터의 `관리자` 버튼)
- 이메일/비밀번호 로그인, 비밀번호 재설정 메일
- 프로필 · 연락처 · 기술 그룹 · 경력 편집
- 프로젝트 추가 · 수정 · 삭제 · 순서 변경
- 샘플 데이터 시드(`기본 데이터 가져오기` / `초기화`)
- 방문 기록 조회 · 통계(오늘 / 고유 IP / 국가) · 오래된 기록 정리

---

## 빠르게 시작하기

### 1. 저장소 받기

```bash
git clone https://github.com/Gugoon/iOSDerekPortfolio.git
cd iOSDerekPortfolio
```

### 2. Firebase 설정 파일 만들기

```bash
cp FirebaseConfig.example.plist DerekPortfolio/Resources/FirebaseConfig.plist
```

`DerekPortfolio/Resources/FirebaseConfig.plist` 에 값을 채웁니다.

| 키 | 값 |
| --- | --- |
| `API_KEY` | Firebase 콘솔 → 프로젝트 설정 → 웹 API 키 |
| `PROJECT_ID` | Firebase 프로젝트 ID |

> 이 파일은 `.gitignore` 에 포함되어 커밋되지 않습니다.
> 파일이 없어도 앱은 실행되며, 이때는 네트워크 없이 샘플 데이터로 동작하고 관리자 버튼과 방문 기록이 비활성화됩니다.

### 3. 실행

```bash
open DerekPortfolio.xcodeproj
```

1. `Signing & Capabilities` 에서 Team 과 Bundle Identifier 를 본인 것으로 변경
2. 시뮬레이터 또는 기기를 선택하고 `⌘R`

커맨드라인 빌드:

```bash
xcodebuild -project DerekPortfolio.xcodeproj -scheme DerekPortfolio \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

---

## 프로젝트 구조

Xcode 16 이상의 **폴더 동기화 그룹**을 사용합니다. `DerekPortfolio/` 아래에 파일을 추가하면
`project.pbxproj` 수정 없이 자동으로 타깃에 포함됩니다.

```
DerekPortfolio/
├── App/            앱 진입점
├── Network/        NetworkViewModel, 요청 공통 타입, 엔드포인트, Firebase 설정 로드
├── Firestore/      Firestore REST 값 타입 · 요청 본문 · CRUD 확장
├── Auth/           로그인 · 토큰 갱신(AuthSession), 키체인
├── Data/           도메인 모델(ProfileData, ProjectData …), 샘플 데이터(DefaultContent)
├── Services/       콘텐츠 저장소, 방문 기록, 이력서 PDF 조판
├── Portfolio/      방문자 화면 (View + ViewModel)
├── Admin/          관리자 화면 (View + ViewModel)
├── Common/         공용 뷰 · 레이아웃 · 토스트 · 로딩 표시
├── Theme/          색상 · 폰트
├── Util/           Foundation 타입 확장, 로그
├── Resources/      번들 폰트, 이미지, FirebaseConfig.plist(로컬 전용)
└── Assets.xcassets 앱 아이콘
```

---

## 아키텍처

MVVM 구조입니다. 모든 ViewModel 은 `NetworkViewModel` 을 상속해 네트워크 함수를 그대로 씁니다.

```
View (SwiftUI)
  │  @StateObject / @ObservedObject
  ▼
ViewModel : NetworkViewModel : BaseObservableObject
  │  extension 으로 정의된 도메인 함수 (loadSiteContent, saveProject …)
  ▼
NetworkViewModel+Firestore  ── getDocument / runQuery / setDocument / commit …
  │
  ▼
NetworkViewModel.performAPIRequest(…)  ──  CombineAPI.fetch (URLSession + Combine)
  │
  ▼
Firestore REST · Firebase Auth REST · IP 조회 API
```

| 구성 요소 | 역할 |
| --- | --- |
| `BaseObservableObject` | `subscriptions` 보관, `setToastMessage` 로 공용 토스트 표시 |
| `AuthSession` (싱글턴) | 로그인 상태를 `@Published user` 로 발행. ID 토큰 만료 전 자동 갱신 |
| `ToastCenter` (싱글턴) | 화면 하단 한 줄 알림. `.toastOverlay()` 로 붙임 |
| `ResumePDFService` (actor) | 콘텐츠 단위로 PDF 조판 결과 캐시 |
| `VisitLogger` (싱글턴) | 앱 실행당 방문 기록 1건 |

**Combine 사용처**
- 스크롤 오프셋 → `맨 위로` 버튼 표시 (`PortfolioViewModel.scrollOffset`)
- 로그인 상태 구독 (`AuthSession.shared.$user`)
- 토스트 자동 닫힘, "응답이 느립니다" 안내 타이머
- 모든 HTTP 요청 파이프라인 (`CombineAPI.fetch`)

---

## 네트워크 레이어

### 요청 흐름

`NetworkViewModel` 의 함수는 결과를 `APICallbackDataModel` 로 돌려줍니다.
실제 코드에서는 이를 `async throws` 로 감싼 래퍼를 씁니다
(`Firestore/NetworkViewModel+Firestore.swift`).

```swift
// 응답 본문을 디코딩해야 하는 요청
let document: FirestoreDocument = try await request(APIEndpoint.document("site/profile"), method: .GET)

// 요청 본문이 있는 요청
let items: [RunQueryResponseItem] = try await request(APIEndpoint.runQuery, method: .POST, body: queryBody)

// 응답 본문이 필요 없는 요청
try await requestNoReply(APIEndpoint.document("projects/\(id)"), method: .DELETE)
```

실패는 `APIFailure` 로 던져집니다.

```swift
do {
    try await saveProfile(profile)
} catch let failure as APIFailure {
    failure.httpCode    // 403, 404 … (네트워크 오류 · 타임아웃이면 nil)
    failure.isTimeout
    failure.message     // 서버 문구 (PERMISSION_DENIED, EMAIL_NOT_FOUND …)
}
```

### Google REST 응답 처리

`NetworkViewModel` 은 `{ "data": … }` 형태의 응답을 전제로 작성된 공용 코드입니다.
Google API 에 맞추기 위해 `Network/NetworkSupport.swift` 에서 다음을 처리합니다.

- `BaseModel<T>` 는 응답 본문 **전체**를 `data` 로 디코딩합니다.
- 2xx 가 아닌 응답은 `{ "error": { code, message, status } }` 를 파싱해
  `APICallbackStatus.SERVER(code:status:message:)` 로 전달합니다.
- 호스트가 여러 곳이라 `Constants.BASE_URL` 은 빈 문자열이고, `APIEndpoint` 가 전체 URL 을 만듭니다.
- 전체 제한 시간: Firestore 읽기(GET · runQuery) 8초, IP 조회 5초, 그 외 30초.

### 인증

- 로그인: `identitytoolkit.googleapis.com/v1/accounts:signInWithPassword`
- 토큰 갱신: `securetoken.googleapis.com/v1/token`
- ID 토큰은 `CommonUserDefault.jwtToken` 에 저장되고 `NetworkViewModel` 이 `Authorization: Bearer` 헤더로 붙입니다.
- refresh token 은 키체인에 저장됩니다. Firestore 요청 전 `AuthSession.prepareAuthorization()` 이 만료를 확인해 갱신합니다.

### 새 API 추가 예시

```swift
// 1) 엔드포인트
extension APIEndpoint {
    static let notices = document("notices")
}

// 2) 도메인 함수 (NetworkViewModel 확장)
extension NetworkViewModel {
    func loadNotices() async throws -> [Notice] {
        try await runQuery(StructuredQuery(collection: "notices", orderBy: "createdAt", descending: true))
            .map { Notice(id: $0.id, fields: $0.fields ?? [:]) }
    }
}

// 3) ViewModel
@MainActor
final class NoticeViewModel: NetworkViewModel {
    @Published private(set) var notices: [Notice] = []

    func load() async {
        do {
            notices = try await loadNotices()
        } catch {
            await setToastMessage(error.localizedDescription, type: .error)
        }
    }
}
```

---

## Firestore 데이터 모델

| 경로 | 모델 | 읽기 | 쓰기 |
| --- | --- | --- | --- |
| `site/profile` | `ProfileData` | 공개 | 관리자 |
| `projects/{autoId}` | `ProjectData` (`order` 오름차순 정렬) | 공개 | 관리자 |
| `admins/{uid}` | 문서 존재 여부만 사용 | 본인만 | 불가 (콘솔에서만) |
| `visits/{visitorId}_{slot}` | `VisitRecord` | 관리자 | 누구나 생성만 |

- Firestore 타입 값은 `FirestoreValue` enum 으로 인코딩/디코딩합니다
  (`stringValue`, `integerValue`, `arrayValue`, `mapValue` …).
- 모델 파싱은 필드가 비거나 타입이 달라도 기본값으로 흡수합니다.
- 방문 기록의 `createdAt` 은 `documents:commit` 의 `REQUEST_TIME` 서버 변환으로 기록합니다.
  문서 ID 의 `slot` 은 `epoch ms / 10000` 이며, 보안 규칙과 함께 10초 쓰기 제한 역할을 합니다.

### 보안 규칙 요약

```
site/*, projects/*   read: true              write: admins/{auth.uid} 존재
visits/*             create: 필드 형식 · ID 형식 검사   read, delete: 관리자   update: 불가
admins/{uid}         get: 본인                list, write: 불가
```

---

## 관리자 기능 설정

1. Firebase 콘솔 → **Authentication** → 이메일/비밀번호 로그인 사용 설정
2. **Users** 에서 관리자 계정 생성 후 UID 복사
3. **Firestore** 에 `admins/{UID}` 문서 생성 (필드는 비워도 됨)
4. 앱에서 `관리자` → 로그인 → `기본 데이터 가져오기` 로 샘플 콘텐츠 시드

---

## 개발 가이드

### 코드 컨벤션

- 파일 머리 주석

  ```swift
  //
  //  FileName.swift
  //
  //
  //  Created by 작성자 on d/M/yy.
  //
  ```

- 화면 로직은 `NetworkViewModel` 을 상속한 `@MainActor final class` ViewModel 에 둡니다.
- 사용자 알림은 `setToastMessage(_:type:)` 을 사용합니다.
- 반응형 분기는 `@Environment(\.layoutWidth)` 와 `LayoutMetrics` 를 사용합니다.
- Foundation 타입 확장은 `Util/` 에 추가합니다.

### 로그

`Util/Log.swift`

```swift
Log("메시지")              // 일반
Log("메시지", .Debug)      // 파일 · 함수 · 라인 · 시각 포함
```

HTTP 요청과 응답은 `apiLog` 가 DEBUG 빌드에서 헤더와 본문까지 출력합니다.
로그인 요청 본문과 `Authorization` 헤더가 콘솔에 표시되므로 로그를 외부에 공유할 때 주의하세요.

### 폰트

`Resources/Fonts` 의 Noto Sans KR · Noto Serif KR · Fira Code 서브셋을 시스템에 등록하지 않고
파일에서 직접 로드합니다(`Theme/AppFonts.swift`).

```swift
Text("제목").font(AppFonts.serif(26, weight: .bold))
Text("본문").font(AppFonts.sans(14))
Text("CODE").font(AppFonts.mono(11, weight: .semibold))
```

- 굵기마다 파일이 따로 있으며, PDF 임베딩 충돌을 막기 위해 PostScript 이름이 굵기별로 고유해야 합니다.
- 서브셋에 없는 글자는 Apple SD Gothic Neo 로 대체됩니다.

### 샘플 데이터

`Data/DefaultContent.swift` 는 공개 저장소용 가상 데이터입니다. 실제 콘텐츠는 Firestore 에만 저장합니다.
경력의 회사명과 프로젝트의 회사명을 맞춰 두어야 경력 → 프로젝트 시트가 열립니다
(괄호 부연 · 공백은 무시하고 비교).

---

## 알려진 제약

- **App Check 미지원**: REST 요청에 App Check 토큰을 보내지 않습니다. Firestore 에 App Check
  적용(enforce)을 켜면 앱의 모든 요청이 거부됩니다. App Attest 연동이 필요합니다.
- **API 키 제한**: 웹 API 키에 HTTP 리퍼러 제한을 걸면 로그인이 403 으로 실패합니다.
  iOS 용 키를 별도로 발급해 `FirebaseConfig.plist` 에 넣으세요.
- **자동 테스트 없음**: 현재 테스트 타깃이 없습니다.
