//
//  NetworkSupport.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  NetworkViewModel.swift 가 기대하는 공통 타입들.
//
//  NetworkViewModel 은 원래 { data: ... } 로 감싼 사내 API 응답을 전제로 짜여 있다.
//  Firestore / Firebase Auth REST 는 본문 자체가 결과이고, 실패는 HTTP 상태 코드와
//  { error: { code, message, status } } 로 내려온다. 그 차이를 이 파일에서 흡수해
//  NetworkViewModel 은 손대지 않고 그대로 쓴다.
//

import Foundation
import Combine
import UIKit

// MARK: - 요청 방식

enum RequestType: String {
    case GET
    case POST
    case PUT
    case PATCH
    case DELETE
}

// MARK: - 결과 상태

/// API 호출 결과. NetworkViewModel 은 실패를 `error as? APICallbackStatus` 로 받아
/// `error.localizedDescription` 을 메시지로 쓰므로, 서버가 준 문구를 여기에 싣는다.
enum APICallbackStatus: Error, Equatable, LocalizedError {
    case SUCCESS
    case ERROR
    /// 제한 시간 안에 응답이 오지 않았다.
    case TIMEOUT
    /// 응답은 왔지만 기대한 모양이 아니다.
    case DECODE_ERROR(message: String)
    /// 서버가 2xx 가 아닌 상태로 답했다. message 는 서버가 준 원문이다.
    case SERVER(code: Int, status: String, message: String)

    var errorDescription: String? {
        switch self {
        case .SUCCESS: return nil
        case .ERROR: return "요청을 처리하지 못했습니다."
        case .TIMEOUT: return "서버 응답이 제때 오지 않았습니다."
        case .DECODE_ERROR(let message): return message
        case .SERVER(_, _, let message): return message
        }
    }

    /// HTTP 상태 코드. 서버 응답이 아니면 nil.
    var httpCode: Int? {
        if case .SERVER(let code, _, _) = self { return code }
        return nil
    }
}

struct APICallbackDataModel<T> {
    var statusCode: APICallbackStatus
    var message: String?
    var data: T?

    init(statusCode: APICallbackStatus, message: String?, data: T? = nil) {
        self.statusCode = statusCode
        self.message = message
        self.data = data
    }
}

// MARK: - 응답 봉투

/// Google REST 응답을 NetworkViewModel 의 BaseModel<U> 모양으로 맞춘다.
///
/// 본문 전체를 `data` 로 읽는다. 본문이 오류 봉투면 디코딩 자체를 실패시켜,
/// NoReply 계열 함수가 오류 응답을 성공으로 착각하지 않게 한다.
struct BaseModel<T: Codable>: Codable {
    let data: T?

    init(data: T?) {
        self.data = data
    }

    init(from decoder: Decoder) throws {
        if let envelope = try? GoogleErrorEnvelope(from: decoder), envelope.error != nil {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: envelope.error?.message ?? "error response")
            )
        }
        data = try T(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try data?.encode(to: encoder)
    }
}

/// 본문이 필요 없는 응답. 어떤 JSON 이 와도 받아들인다.
struct NoReply: Codable {
    init() {}
    init(from decoder: Decoder) throws {}
    func encode(to encoder: Encoder) throws {}
}

/// Google API 공통 오류 모양.
struct GoogleErrorEnvelope: Codable {
    struct Body: Codable {
        let code: Int?
        let message: String?
        let status: String?
    }
    let error: Body?
}

func decodeData<U: Codable>(from data: Data, decoder: JSONDecoder) -> APICallbackDataModel<BaseModel<U>> {
    do {
        let model = try decoder.decode(BaseModel<U>.self, from: data)
        return APICallbackDataModel(statusCode: .SUCCESS, message: nil, data: model)
    } catch {
        Log("Decode error (\(U.self)): \(error)")
        let status = APICallbackStatus.DECODE_ERROR(message: "응답을 해석하지 못했습니다.")
        return APICallbackDataModel(statusCode: status, message: status.localizedDescription)
    }
}

// MARK: - Combine 요청

enum CombineAPI {
    /// 읽기 하나에 허용하는 시간. Flutter 의 ContentRepository._readTimeout 과 같다.
    /// 기다리다 멈춰 있지 않는 것이 목적이라 넉넉하지 않게 잡는다.
    static let readTimeout: TimeInterval = 8
    /// IP 위치 조회는 더 짧게. 방문 기록 때문에 무언가를 기다릴 이유는 없다.
    static let geoTimeout: TimeInterval = 5

    static func fetch(request: URLRequest) -> AnyPublisher<Data, Error> {
        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output -> Data in
                let code = (output.response as? HTTPURLResponse)?.statusCode ?? 0
                apiLog(data: output.data, response: output.response as? HTTPURLResponse, error: nil)
                guard (200..<300).contains(code) else {
                    throw serverError(code: code, data: output.data)
                }
                return output.data
            }
            .timeout(
                .seconds(timeout(for: request)),
                scheduler: DispatchQueue.global(),
                customError: { APICallbackStatus.TIMEOUT }
            )
            .mapError { error -> Error in
                if let status = error as? APICallbackStatus { return status }
                // 서버 응답은 위에서 이미 남겼다. 응답 없이 끝난 실패(연결 끊김 등)만 기록한다.
                apiLog(data: nil, response: nil, error: error)
                if let urlError = error as? URLError, urlError.code == .timedOut {
                    return APICallbackStatus.TIMEOUT
                }
                return error
            }
            .eraseToAnyPublisher()
    }

    /// 요청 성격에 따라 전체 제한 시간을 고른다.
    ///
    /// URLRequest.timeoutInterval 은 '응답 사이의 공백' 기준이라 느리게 흘러오는
    /// 응답은 끊지 못한다. 여기서 Combine timeout 으로 총 시간을 끊는다.
    static func timeout(for request: URLRequest) -> TimeInterval {
        guard let url = request.url else { return request.timeoutInterval }
        if APIEndpoint.geoLookups.contains(where: { url.absoluteString.hasPrefix($0) }) {
            return geoTimeout
        }
        let isFirestore = url.host == APIEndpoint.firestoreHost
        let isRead = request.httpMethod == RequestType.GET.rawValue
            || url.absoluteString.hasSuffix(":runQuery")
        return isFirestore && isRead ? readTimeout : request.timeoutInterval
    }

    /// 오류 본문에서 서버 문구를 꺼낸다. runQuery 는 배열로 감싸 보내므로 둘 다 본다.
    private static func serverError(code: Int, data: Data) -> APICallbackStatus {
        let decoder = JSONDecoder()
        let body = (try? decoder.decode(GoogleErrorEnvelope.self, from: data))?.error
            ?? (try? decoder.decode([GoogleErrorEnvelope].self, from: data))?.first?.error
        return .SERVER(
            code: code,
            status: body?.status ?? "",
            message: body?.message ?? HTTPURLResponse.localizedString(forStatusCode: code)
        )
    }
}

// MARK: - 기반 ViewModel

enum ToastType {
    case normal
    case error
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: ToastType
}

@MainActor
class BaseObservableObject: ObservableObject {
    var subscriptions = Set<AnyCancellable>()

    /// 화면 하단에 한 줄 알림을 띄운다. 모든 ViewModel 이 같은 자리(ToastCenter)를 쓴다.
    @discardableResult
    func setToastMessage(_ message: String, type: ToastType = .normal) async -> Bool {
        ToastCenter.shared.show(message, type: type)
        return true
    }
}

// 인코딩(toJSONData)과 로그(Log · apiLog)는 Util 의 공용 확장을 쓴다.
//   Util/Encodable + Extension.swift, Util/Log.swift
