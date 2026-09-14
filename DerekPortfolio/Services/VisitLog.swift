//
//  VisitLog.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  앱 방문 기록. Flutter lib/services/visit_log.dart · visit_client.dart 자리.
//
//  누가 언제 들어왔는지를 관리자 화면에서 보기 위한 최소한의 기록이다. 앱은 자기
//  공인 IP 를 모르기 때문에, 방문 시점에 무료 IP 조회 서비스에 한 번 물어 IP 와
//  대략적인 위치를 함께 받아 온다.
//
//  개인정보에 대해: IP 는 개인을 특정할 수 있는 정보다. 기록은 관리자만 읽을 수 있게
//  firestore.rules 로 막아 두었고, 관리자 화면에서 오래된 기록을 지울 수 있다.
//

import Foundation
import UIKit

// MARK: - 방문 한 건에 대해 알 수 있는 값

/// 기기에서 곧바로 읽어낼 수 있는 값들.
struct VisitClientInfo {
    var path = "/"
    var referrer = ""
    var userAgent = ""
    var language = ""
    /// '393x852' 형태의 화면 크기(포인트).
    var screen = ""

    @MainActor
    static func current() -> VisitClientInfo {
        let device = UIDevice.current
        let family = device.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        let bounds = UIScreen.main.bounds
        return VisitClientInfo(
            path: "/",
            referrer: "",
            userAgent: "DerekPortfolio/\(Infomation.version) (\(family); iOS \(device.systemVersion); \(UIDevice.modelName))",
            language: Locale.preferredLanguages.first ?? "",
            screen: "\(Int(bounds.width))x\(Int(bounds.height))"
        )
    }
}

/// IP 로 알아낸 대략적인 위치. 국가는 거의 맞고, 시/도는 회선이 묶여 나가는 지역으로 잡히는 일이 잦다.
struct VisitGeoInfo {
    var ip: String
    var country = ""
    var countryCode = ""
    var region = ""
    var city = ""
    /// 통신사/기관 이름. 'LG POWERCOMM' 같은 값이 들어온다.
    var org = ""
    var timezone = ""
}

/// ipwho.is 와 geojs 두 곳의 응답을 같은 모양으로 읽는다.
///
/// 키 이름이 대부분 겹치고, 갈리는 건 통신사와 시간대뿐이다. ipwho.is 는
/// connection.isp / timezone.id 로 중첩해 넣고, geojs 는 organization_name /
/// timezone 으로 평평하게 넣는다.
struct GeoLookupResponse: Codable {
    struct Connection: Codable { let isp: String? }

    let success: Bool?
    let ip: String?
    let country: String?
    let country_code: String?
    let region: String?
    let city: String?
    let connection: Connection?
    let organization_name: String?
    let timezone: String?

    private enum CodingKeys: String, CodingKey {
        case success, ip, country, country_code, region, city, connection, organization_name, timezone
    }

    private struct TimezoneObject: Codable { let id: String? }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = try? c.decodeIfPresent(Bool.self, forKey: .success)
        ip = try? c.decodeIfPresent(String.self, forKey: .ip)
        country = try? c.decodeIfPresent(String.self, forKey: .country)
        country_code = try? c.decodeIfPresent(String.self, forKey: .country_code)
        region = try? c.decodeIfPresent(String.self, forKey: .region)
        city = try? c.decodeIfPresent(String.self, forKey: .city)
        connection = try? c.decodeIfPresent(Connection.self, forKey: .connection)
        organization_name = try? c.decodeIfPresent(String.self, forKey: .organization_name)
        if let text = try? c.decodeIfPresent(String.self, forKey: .timezone) {
            timezone = text
        } else {
            timezone = (try? c.decodeIfPresent(TimezoneObject.self, forKey: .timezone))?.id
        }
    }

    /// 알아볼 수 없으면 nil. ipwho.is 는 한도 초과도 200 + success:false 로 돌려준다.
    var geoInfo: VisitGeoInfo? {
        if success == false { return nil }
        let ip = clipVisitText(ip)
        guard !ip.isEmpty else { return nil }
        return VisitGeoInfo(
            ip: ip,
            country: clipVisitText(country),
            countryCode: clipVisitText(country_code),
            region: clipVisitText(region),
            city: clipVisitText(city),
            org: clipVisitText(connection?.isp ?? organization_name),
            timezone: clipVisitText(timezone)
        )
    }
}

/// 문서에 넣기 전에 문자열을 다듬는다. firestore.rules 가 512자를 넘는 값을 거절하므로 먼저 줄인다.
func clipVisitText(_ value: String?, max: Int = 300) -> String {
    let text = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return text.count <= max ? text : String(text.prefix(max))
}

// MARK: - 문서 ID (10초 쓰기 제한)

/// 쓰기 제한의 시간 칸 크기. firestore.rules 의 10000 과 반드시 같아야 한다.
let visitSlotMillis: Int64 = 10_000

/// 기기를 구분하는 16자리 16진수. firestore.rules 가 이 모양을 검사한다.
func newVisitorId() -> String {
    var generator = SystemRandomNumberGenerator()
    return (0..<8).map { _ in UInt8.random(in: 0...255, using: &generator).stringToHexStr() }.joined()
}

/// 방문 문서의 ID. '기기ID_시간칸' 모양이다.
///
/// 같은 기기가 같은 10초 안에 두 번 쓰려고 하면 ID 가 똑같이 나오고, 두 번째 쓰기는
/// create 가 아니라 update 가 되어 규칙에 거절된다. 이것 하나가 제한의 전부다.
func visitDocId(visitorId: String, now: Date) -> String {
    return "\(visitorId)_\(Int64(now.millisecondsSince1970Int) / visitSlotMillis)"
}

/// 저장된 기기 ID. 모양이 어긋나면(누가 손댔거나 옛 형식) 새로 만든다.
func readVisitorId() -> String {
    let saved = CommonUserDefault.visitorId
    if saved.range(of: "^[0-9a-f]{16}$", options: .regularExpression) != nil { return saved }
    let id = newVisitorId()
    CommonUserDefault.visitorId = id
    return id
}

// MARK: - 기록 한 건

/// Firestore visits/{기기ID_시간칸} 문서 한 건.
struct VisitRecord: Identifiable, Hashable {
    let id: String
    /// 서버 시각.
    let at: Date?
    let ip: String
    let country: String
    let countryCode: String
    let region: String
    let city: String
    let org: String
    let timezone: String
    let path: String
    let referrer: String
    let userAgent: String
    let language: String
    let screen: String

    init(document: FirestoreDocument) {
        let f = document.fields ?? [:]
        id = document.id
        at = f["createdAt"].dateValue
        ip = clipVisitText(f["ip"].str())
        country = clipVisitText(f["country"].str())
        countryCode = clipVisitText(f["countryCode"].str())
        region = clipVisitText(f["region"].str())
        city = clipVisitText(f["city"].str())
        org = clipVisitText(f["org"].str())
        timezone = clipVisitText(f["timezone"].str())
        path = clipVisitText(f["path"].str())
        referrer = clipVisitText(f["referrer"].str())
        userAgent = clipVisitText(f["userAgent"].str())
        language = clipVisitText(f["language"].str())
        screen = clipVisitText(f["screen"].str())
    }

    /// 'South Korea · Seoul · Seo-gu' 처럼 아는 만큼만 잇는다. 같은 이름이 겹치면 하나만 남긴다.
    var location: String {
        var parts: [String] = []
        for part in [country, region, city] where !part.isEmpty && !parts.contains(part) {
            parts.append(part)
        }
        return parts.joined(separator: " · ")
    }

    /// 유입 경로를 도메인만 남겨 짧게 보여 준다.
    var source: String {
        if referrer.isEmpty { return "직접 방문" }
        let host = URL(string: referrer)?.host ?? ""
        return host.isEmpty ? referrer : host
    }
}

// MARK: - Firestore

extension NetworkViewModel {
    private static let visitsCollection = "visits"

    /// 방문 한 건을 쓴다.
    ///
    /// 시각은 서버가 채운다(REQUEST_TIME). firestore.rules 가 createdAt == request.time 만
    /// 받기 때문이다. exists:false 전제를 걸어 두어 같은 ID 에 두 번 쓰면 실패한다.
    func addVisit(visitorId: String, client: VisitClientInfo, geo: VisitGeoInfo?) async throws {
        let fields: FirestoreFields = [
            "ip": .string(geo?.ip ?? ""),
            "country": .string(geo?.country ?? ""),
            "countryCode": .string(geo?.countryCode ?? ""),
            "region": .string(geo?.region ?? ""),
            "city": .string(geo?.city ?? ""),
            "org": .string(geo?.org ?? ""),
            "timezone": .string(geo?.timezone ?? ""),
            "path": .string(clipVisitText(client.path)),
            "referrer": .string(clipVisitText(client.referrer)),
            "userAgent": .string(clipVisitText(client.userAgent)),
            "language": .string(clipVisitText(client.language)),
            "screen": .string(clipVisitText(client.screen)),
        ]
        let path = "\(Self.visitsCollection)/\(visitDocId(visitorId: visitorId, now: Date()))"
        try await commit([.create(path, fields: fields, serverTimestampField: "createdAt")])
    }

    /// 최근 방문부터 limit 건. 관리자만 읽을 수 있다.
    func loadRecentVisits(limit: Int = 300) async throws -> [VisitRecord] {
        let query = StructuredQuery(
            collection: Self.visitsCollection,
            orderBy: "createdAt",
            descending: true,
            limit: limit
        )
        return try await runQuery(query).map(VisitRecord.init(document:))
    }

    /// age 보다 오래된 기록을 지운다. age 가 0 이면 전부 지운다.
    ///
    /// 한 번에 다 지우지 않고 묶음으로 끊어 돈다. 상한에 걸려 아직 남은 게 있으면
    /// hasMore 로 알린다 — 지운 건수만 돌려주면 정리가 끝난 줄 알게 된다.
    func deleteVisits(olderThan age: TimeInterval) async throws -> (deleted: Int, hasMore: Bool) {
        let batchSize = 400
        let maxRounds = 20
        let cutoff = Date().addingTimeInterval(-age)
        var deleted = 0
        var hasMore = true

        for _ in 0..<maxRounds where hasMore {
            let query = StructuredQuery(
                collection: Self.visitsCollection,
                select: ["__name__"],
                where: .init(
                    field: .init(fieldPath: "createdAt"),
                    op: "LESS_THAN",
                    value: .timestamp(cutoff)
                ),
                limit: batchSize
            )
            let documents = try await runQuery(query)

            // 묶음이 꽉 차서 왔으면 뒤에 더 있을 수 있다.
            hasMore = documents.count == batchSize
            if documents.isEmpty { break }

            try await commit(documents.compactMap { $0.name.map(FirestoreWrite.delete(name:)) })
            deleted += documents.count
        }
        return (deleted, hasMore)
    }

    /// 조회처를 앞에서부터 시도해 처음 답한 곳의 위치를 돌려준다.
    func lookUpGeo() async -> VisitGeoInfo? {
        for endpoint in APIEndpoint.geoLookups {
            if let response: GeoLookupResponse = try? await request(endpoint, method: .GET),
               let geo = response.geoInfo {
                return geo
            }
        }
        return nil
    }
}

// MARK: - 기록 남기기

@MainActor
final class VisitLogger: NetworkViewModel {
    static let shared = VisitLogger()

    /// 앱을 켠 뒤 이미 기록을 남겼는지. Flutter 의 sessionStorage 표식 자리다.
    private var claimed = false
    private var inFlight = false

    private override init() {
        super.init()
    }

    /// 방문 한 건을 남긴다. 어떤 이유로 실패하든 조용히 넘어간다.
    func recordVisit() async {
        guard FirebaseConfig.isConfigured, !claimed, !inFlight else { return }

        // 관리자 본인의 접속은 남기지 않는다. 콘텐츠를 고치러 드나들 때마다 한 줄씩
        // 쌓이면 정작 보고 싶은 방문자 기록이 묻힌다. 로그인하는 사람은 관리자뿐이다.
        guard AuthSession.shared.user == nil else { return }

        inFlight = true
        defer { inFlight = false }

        let geo = await lookUpGeo()
        do {
            try await addVisit(visitorId: readVisitorId(), client: .current(), geo: geo)
            // 표식은 쓰기가 실제로 끝난 뒤에 찍는다. 먼저 찍으면 실패했을 때 이번 실행
            // 내내 기록을 남기지 못한다.
            claimed = true
        } catch {
            Log("방문 기록 실패: \(error.localizedDescription)")
        }
    }
}

// MARK: - userAgent 요약

/// 크롤러를 가려내는 표식. 'bot' 만 보면 CUBOT 같은 기기가 봇으로 찍혀 구분자까지 함께 본다.
private let botMarkers = [
    "bot/", "bot;", "bot-", "crawler", "spider", "slurp", "facebookexternalhit",
    "headlesschrome", "python-requests", "curl/", "wget/",
]

/// userAgent 에서 브라우저(또는 앱)와 OS 만 뽑아 한 줄로 줄인다.
func describeUserAgent(_ userAgent: String) -> String {
    if userAgent.isEmpty { return "" }

    let lower = userAgent.lowercased()
    if botMarkers.contains(where: lower.contains) { return "봇/크롤러" }

    // 순서가 중요하다. 엣지와 오페라는 Chrome 도, 크롬은 Safari 도 달고 다닌다.
    let browsers: [(String, String)] = [
        ("DerekPortfolio/", "iOS 앱"),
        ("Edg/", "Edge"),
        ("OPR/", "Opera"),
        ("SamsungBrowser", "Samsung Internet"),
        ("Whale", "Whale"),
        ("Firefox", "Firefox"),
        ("Chrome", "Chrome"),
        ("Safari", "Safari"),
    ]
    let systems: [(String, String)] = [
        ("iPhone", "iPhone"),
        ("iPad", "iPad"),
        ("Android", "Android"),
        ("Windows", "Windows"),
        ("Mac OS X", "macOS"),
        ("Linux", "Linux"),
    ]

    var parts: [String] = []
    if let browser = browsers.first(where: { userAgent.contains($0.0) }) { parts.append(browser.1) }
    if let system = systems.first(where: { userAgent.contains($0.0) }) { parts.append(system.1) }
    return parts.isEmpty ? "알 수 없는 브라우저" : parts.joined(separator: " · ")
}
