//
//  FirestoreModels.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  Firestore REST 요청/응답 본문.
//  https://firebase.google.com/docs/firestore/reference/rest
//

import Foundation

typealias FirestoreFields = [String: FirestoreValue]

struct FirestoreDocument: Codable {
    /// 'projects/{project}/databases/(default)/documents/projects/{id}'
    var name: String?
    var fields: FirestoreFields?
    var createTime: String?
    var updateTime: String?

    /// 문서 ID(이름의 마지막 조각).
    var id: String {
        name?.split(separator: "/").last.map(String.init) ?? ""
    }
}

/// PATCH / POST 로 문서를 쓸 때의 본문.
struct FirestoreDocumentBody: Codable {
    let fields: FirestoreFields
}

// MARK: - runQuery

struct RunQueryRequest: Codable {
    let structuredQuery: StructuredQuery
}

struct StructuredQuery: Codable {
    struct CollectionSelector: Codable {
        let collectionId: String
    }

    struct FieldReference: Codable {
        let fieldPath: String
    }

    struct Projection: Codable {
        let fields: [FieldReference]
    }

    struct FieldFilter: Codable {
        let field: FieldReference
        /// LESS_THAN, EQUAL ...
        let op: String
        let value: FirestoreValue
    }

    struct Filter: Codable {
        let fieldFilter: FieldFilter
    }

    struct Order: Codable {
        let field: FieldReference
        /// ASCENDING / DESCENDING
        let direction: String
    }

    var select: Projection?
    var from: [CollectionSelector]
    var `where`: Filter?
    var orderBy: [Order]?
    var limit: Int?

    init(
        collection: String,
        select: [String]? = nil,
        where filter: FieldFilter? = nil,
        orderBy: String? = nil,
        descending: Bool = false,
        limit: Int? = nil
    ) {
        self.select = select.map { Projection(fields: $0.map(FieldReference.init)) }
        self.from = [CollectionSelector(collectionId: collection)]
        self.where = filter.map(Filter.init)
        self.orderBy = orderBy.map {
            [Order(field: FieldReference(fieldPath: $0), direction: descending ? "DESCENDING" : "ASCENDING")]
        }
        self.limit = limit
    }
}

/// runQuery 응답 배열의 한 칸. 결과가 없으면 document 없이 readTime 만 온다.
struct RunQueryResponseItem: Codable {
    let document: FirestoreDocument?
    let readTime: String?
}

// MARK: - commit (일괄 쓰기)

struct CommitRequest: Codable {
    let writes: [FirestoreWrite]
}

struct CommitResponse: Codable {
    let commitTime: String?
}

struct FirestoreWrite: Codable {
    struct DocumentMask: Codable {
        let fieldPaths: [String]
    }

    struct Precondition: Codable {
        let exists: Bool
    }

    struct FieldTransform: Codable {
        let fieldPath: String
        let setToServerValue: String
    }

    var update: FirestoreDocument?
    var delete: String?
    var updateMask: DocumentMask?
    var updateTransforms: [FieldTransform]?
    var currentDocument: Precondition?

    /// batch.set — 문서를 통째로 덮어쓴다.
    static func set(_ path: String, fields: FirestoreFields) -> FirestoreWrite {
        FirestoreWrite(update: FirestoreDocument(name: APIEndpoint.documentName(path), fields: fields))
    }

    /// batch.update — 있는 문서의 일부 필드만 고친다. 문서가 없으면 실패한다.
    static func update(_ path: String, fields: FirestoreFields) -> FirestoreWrite {
        FirestoreWrite(
            update: FirestoreDocument(name: APIEndpoint.documentName(path), fields: fields),
            updateMask: DocumentMask(fieldPaths: Array(fields.keys)),
            currentDocument: Precondition(exists: true)
        )
    }

    /// batch.delete — 전체 문서 이름을 받는다.
    static func delete(name: String) -> FirestoreWrite {
        FirestoreWrite(delete: name)
    }

    /// 새 문서 만들기 + 서버 시각 필드. 같은 ID 가 이미 있으면 실패한다.
    static func create(_ path: String, fields: FirestoreFields, serverTimestampField: String) -> FirestoreWrite {
        FirestoreWrite(
            update: FirestoreDocument(name: APIEndpoint.documentName(path), fields: fields),
            updateTransforms: [FieldTransform(fieldPath: serverTimestampField, setToServerValue: "REQUEST_TIME")],
            currentDocument: Precondition(exists: false)
        )
    }
}

enum FirestoreAutoID {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")

    /// Firestore SDK 의 doc() 이 만드는 것과 같은 20자 자동 ID.
    static func make() -> String {
        var generator = SystemRandomNumberGenerator()
        return String((0..<20).map { _ in alphabet.randomElement(using: &generator)! })
    }
}
