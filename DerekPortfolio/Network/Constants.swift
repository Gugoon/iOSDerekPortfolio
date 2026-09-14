//
//  Constants.swift
//
//
//  Created by 구보성 on 14/9/26.
//

import Foundation
import UIKit

enum Constants {
    /// NetworkViewModel 은 `BASE_URL + endpoint` 로 주소를 만든다.
    /// 이 앱은 Firestore · Firebase Auth · IP 조회처 등 호스트가 여러 곳이라
    /// 공통 접두사를 두지 않고, 엔드포인트가 전체 주소를 들고 다닌다(APIEndpoint).
    static let BASE_URL = ""
}

/// Firebase 프로젝트 설정.
///
/// 키가 저장소에 올라가지 않도록 코드에 적지 않고, 앱 번들의 `FirebaseConfig.plist` 에서 읽는다.
/// 이 파일은 .gitignore 에 들어 있다. 새로 받은 저장소에서는 루트의
/// `FirebaseConfig.example.plist` 를 `DerekPortfolio/Resources/FirebaseConfig.plist` 로 복사해
/// 값을 채운다.
///
/// 파일이 없으면 isConfigured 가 false 이고, 앱은 네트워크 없이 내장 샘플 데이터로 뜬다.
/// 관리자 화면과 방문 기록도 꺼진다(Flutter main.dart 의 firebaseReady 와 같다).
enum FirebaseConfig {
    private static let values: [String: String] = {
        guard
            let url = Bundle.main.url(forResource: "FirebaseConfig", withExtension: "plist"),
            let dictionary = NSDictionary(contentsOf: url) as? [String: Any]
        else { return [:] }
        return dictionary.compactMapValues { $0 as? String }
    }()

    static let apiKey = values["API_KEY"] ?? ""
    static let projectId = values["PROJECT_ID"] ?? ""

    /// 예시 파일을 그대로 복사해 값을 안 채운 경우도 설정 전으로 본다.
    static var isConfigured: Bool {
        !apiKey.isEmpty && !projectId.isEmpty && !apiKey.hasPrefix("YOUR_") && !projectId.hasPrefix("YOUR_")
    }
}

enum APIEndpoint {
    static let firestoreHost = "firestore.googleapis.com"

    /// `projects/{id}/databases/(default)/documents`
    static let documentsName = "projects/\(FirebaseConfig.projectId)/databases/(default)/documents"
    static let documentsRoot = "https://\(firestoreHost)/v1/\(documentsName)"

    /// 문서 하나(또는 컬렉션)의 REST 주소. path 는 'site/profile' 모양.
    static func document(_ path: String) -> String { "\(documentsRoot)/\(path)" }

    /// commit/runQuery 요청 본문에 넣는 문서의 전체 이름.
    static func documentName(_ path: String) -> String { "\(documentsName)/\(path)" }

    static let runQuery = "\(documentsRoot):runQuery"
    static let commit = "\(documentsRoot):commit"

    static let signIn = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(FirebaseConfig.apiKey)"
    static let sendOobCode = "https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=\(FirebaseConfig.apiKey)"
    static let refreshToken = "https://securetoken.googleapis.com/v1/token?key=\(FirebaseConfig.apiKey)"

    /// IP 와 위치를 알려 주는 무료 조회처. 앞에서부터 하나가 답할 때까지 시도한다.
    static let geoLookups = [
        "https://ipwho.is/",
        "https://get.geojs.io/v1/ip/geo.json",
    ]
}

enum Infomation {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}

extension UIDevice {
    /// 'iPhone16,1' 같은 기기 식별자.
    static var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce(into: "") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            identifier += String(UnicodeScalar(UInt8(value)))
        }
    }
}
