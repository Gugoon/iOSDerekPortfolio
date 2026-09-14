//
//  NetworkViewModel+Firestore.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  NetworkViewModel 의 performAPIRequest 계열을 async throws 로 감싸고,
//  그 위에 Firestore REST 의 읽기/쓰기를 얹는다.
//

import Foundation

/// performAPIRequest 가 돌려준 실패를 예외로 올린다.
struct APIFailure: LocalizedError {
    let status: APICallbackStatus
    let message: String

    var errorDescription: String? { message }

    /// 서버가 준 HTTP 상태 코드. 네트워크 단절·타임아웃이면 nil.
    var httpCode: Int? { status.httpCode }
    var isTimeout: Bool { status == .TIMEOUT }
    var isNotFound: Bool { httpCode == 404 }

    init(status: APICallbackStatus, message: String?) {
        self.status = status
        let text = (message?.isEmpty == false ? message : status.localizedDescription) ?? ""
        self.message = text
    }
}

// MARK: - NetworkViewModel 호출 래퍼

extension NetworkViewModel {
    func request<U: Codable>(_ endpoint: String, method: RequestType) async throws -> U {
        var output: U?
        let result: APICallbackDataModel<U> = await performAPIRequest(
            endpoint: endpoint,
            method: method,
            onSuccess: { output = $0 }
        )
        guard result.statusCode == .SUCCESS, let output else {
            throw APIFailure(status: result.statusCode, message: result.message)
        }
        return output
    }

    func request<T: Codable, U: Codable>(_ endpoint: String, method: RequestType, body: T) async throws -> U {
        var output: U?
        let result: APICallbackDataModel<U> = await performAPIRequest(
            endpoint: endpoint,
            method: method,
            requestData: body,
            onSuccess: { output = $0 }
        )
        guard result.statusCode == .SUCCESS, let output else {
            throw APIFailure(status: result.statusCode, message: result.message)
        }
        return output
    }

    func requestNoReply(_ endpoint: String, method: RequestType) async throws {
        let result = await performAPIRequestNoReply(endpoint: endpoint, method: method)
        guard result.statusCode == .SUCCESS else {
            throw APIFailure(status: result.statusCode, message: result.message)
        }
    }

    func requestNoReply<T: Codable>(_ endpoint: String, method: RequestType, body: T) async throws {
        let result = await performAPIRequestNoReply(endpoint: endpoint, method: method, requestData: body)
        guard result.statusCode == .SUCCESS else {
            throw APIFailure(status: result.statusCode, message: result.message)
        }
    }
}

// MARK: - Firestore

extension NetworkViewModel {
    /// 문서 하나. 없으면 nil.
    func getDocument(_ path: String) async throws -> FirestoreDocument? {
        await AuthSession.shared.prepareAuthorization()
        do {
            let document: FirestoreDocument = try await request(APIEndpoint.document(path), method: .GET)
            return document
        } catch let failure as APIFailure where failure.isNotFound {
            return nil
        }
    }

    /// 구조화 쿼리. 결과가 없으면 빈 배열.
    func runQuery(_ query: StructuredQuery) async throws -> [FirestoreDocument] {
        await AuthSession.shared.prepareAuthorization()
        let items: [RunQueryResponseItem] = try await request(
            APIEndpoint.runQuery,
            method: .POST,
            body: RunQueryRequest(structuredQuery: query)
        )
        return items.compactMap(\.document)
    }

    /// set() — 문서를 통째로 덮어쓴다. 없으면 만든다.
    func setDocument(_ path: String, fields: FirestoreFields) async throws {
        await AuthSession.shared.prepareAuthorization()
        let _: FirestoreDocument = try await request(
            APIEndpoint.document(path),
            method: .PATCH,
            body: FirestoreDocumentBody(fields: fields)
        )
    }

    /// add() — 자동 ID 로 새 문서를 만들고 그 ID 를 돌려준다.
    func addDocument(collection: String, fields: FirestoreFields) async throws -> String {
        await AuthSession.shared.prepareAuthorization()
        let document: FirestoreDocument = try await request(
            APIEndpoint.document(collection),
            method: .POST,
            body: FirestoreDocumentBody(fields: fields)
        )
        return document.id
    }

    func deleteDocument(_ path: String) async throws {
        await AuthSession.shared.prepareAuthorization()
        try await requestNoReply(APIEndpoint.document(path), method: .DELETE)
    }

    /// batch.commit(). 한 번에 최대 500건.
    func commit(_ writes: [FirestoreWrite]) async throws {
        guard !writes.isEmpty else { return }
        await AuthSession.shared.prepareAuthorization()
        try await requestNoReply(APIEndpoint.commit, method: .POST, body: CommitRequest(writes: writes))
    }
}
