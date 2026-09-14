//
//  ProjectData.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  포트폴리오 콘텐츠 모델. Flutter lib/data/project_data.dart 와 같은 구조다.
//
//  모든 값은 Firestore 에서 내려받아 채워지고, 네트워크 오류 등으로 읽기에 실패하면
//  DefaultContent 의 defaultProfile / defaultProjects 로 폴백한다.
//

import Foundation

enum ProjectCategory: String, CaseIterable, Codable, Hashable {
    case mobile
    case ai
    case web
    case backend
    case other

    var label: String {
        switch self {
        case .mobile: return "모바일"
        case .ai: return "AI / ML"
        case .web: return "웹"
        case .backend: return "백엔드 / 데이터"
        case .other: return "기타"
        }
    }

    /// 저장된 문자열을 되돌린다. 알 수 없는 값은 other 로 흡수한다.
    static func from(_ value: FirestoreValue?) -> ProjectCategory {
        ProjectCategory(rawValue: value.str()) ?? .other
    }
}

struct ProjectData: Identifiable, Hashable {
    /// Firestore 문서 ID. 관리자 화면에서 수정/삭제 대상을 지목할 때만 쓰이고,
    /// 문서 본문에는 저장하지 않는다. 폴백 상수 데이터에서는 nil 이다.
    var id: String?
    var title: String
    var company: String
    var description: String
    var period: String
    var techStack: [String]
    var role: String
    var achievements: [String]
    var imageUrl: String?
    var githubUrl: String?
    var liveUrl: String?
    var appStoreUrl: String?
    var playStoreUrl: String?
    var category: ProjectCategory
    /// 목록 정렬 순서. 값이 작을수록 위에 노출된다.
    var order: Int = 0

    init(
        id: String? = nil,
        title: String,
        company: String,
        description: String,
        period: String,
        techStack: [String],
        role: String,
        achievements: [String],
        imageUrl: String? = nil,
        githubUrl: String? = nil,
        liveUrl: String? = nil,
        appStoreUrl: String? = nil,
        playStoreUrl: String? = nil,
        category: ProjectCategory,
        order: Int = 0
    ) {
        self.id = id
        self.title = title
        self.company = company
        self.description = description
        self.period = period
        self.techStack = techStack
        self.role = role
        self.achievements = achievements
        self.imageUrl = imageUrl
        self.githubUrl = githubUrl
        self.liveUrl = liveUrl
        self.appStoreUrl = appStoreUrl
        self.playStoreUrl = playStoreUrl
        self.category = category
        self.order = order
    }

    init(id: String, fields f: FirestoreFields) {
        self.init(
            id: id,
            title: f["title"].str(),
            company: f["company"].str(),
            description: f["description"].str(),
            period: f["period"].str(),
            techStack: f["techStack"].strList,
            role: f["role"].str(),
            achievements: f["achievements"].strList,
            imageUrl: f["imageUrl"].strOrNil,
            githubUrl: f["githubUrl"].strOrNil,
            liveUrl: f["liveUrl"].strOrNil,
            appStoreUrl: f["appStoreUrl"].strOrNil,
            playStoreUrl: f["playStoreUrl"].strOrNil,
            category: .from(f["category"]),
            order: f["order"].intValue ?? 0
        )
    }

    var fields: FirestoreFields {
        [
            "title": .string(title),
            "company": .string(company),
            "description": .string(description),
            "period": .string(period),
            "techStack": .strings(techStack),
            "role": .string(role),
            "achievements": .strings(achievements),
            "imageUrl": .optionalString(imageUrl),
            "githubUrl": .optionalString(githubUrl),
            "liveUrl": .optionalString(liveUrl),
            "appStoreUrl": .optionalString(appStoreUrl),
            "playStoreUrl": .optionalString(playStoreUrl),
            "category": .string(category.rawValue),
            "order": .integer(Int64(order)),
        ]
    }

    /// 목록/모달에서 쓰는 안정적인 식별자. 폴백 데이터는 id 가 없어 제목으로 대신한다.
    var listKey: String { id ?? "\(title)|\(company)|\(period)" }
}

struct CareerHistory: Hashable {
    var company: String
    var period: String
    var duration: String
    var role: String

    init(company: String, period: String, duration: String, role: String) {
        self.company = company
        self.period = period
        self.duration = duration
        self.role = role
    }

    init(fields f: FirestoreFields) {
        self.init(
            company: f["company"].str(),
            period: f["period"].str(),
            duration: f["duration"].str(),
            role: f["role"].str()
        )
    }

    var value: FirestoreValue {
        .map([
            "company": .string(company),
            "period": .string(period),
            "duration": .string(duration),
            "role": .string(role),
        ])
    }
}

struct SkillGroup: Hashable {
    var category: String
    var skills: [String]

    init(category: String, skills: [String]) {
        self.category = category
        self.skills = skills
    }

    init(fields f: FirestoreFields) {
        self.init(category: f["category"].str(), skills: f["skills"].strList)
    }

    var value: FirestoreValue {
        .map(["category": .string(category), "skills": .strings(skills)])
    }
}

struct ProfileData: Hashable {
    var name: String
    var title: String
    var experience: String
    var bio: String
    var email: String
    var phone: String
    var github: String?
    var notion: String?
    var certificate: String
    var directSkillGroups: [SkillGroup]
    var aiSkillGroups: [SkillGroup]
    var skills: [String]
    var careers: [CareerHistory]

    init(
        name: String,
        title: String,
        experience: String,
        bio: String,
        email: String,
        phone: String,
        github: String? = nil,
        notion: String? = nil,
        certificate: String,
        directSkillGroups: [SkillGroup],
        aiSkillGroups: [SkillGroup],
        skills: [String],
        careers: [CareerHistory]
    ) {
        self.name = name
        self.title = title
        self.experience = experience
        self.bio = bio
        self.email = email
        self.phone = phone
        self.github = github
        self.notion = notion
        self.certificate = certificate
        self.directSkillGroups = directSkillGroups
        self.aiSkillGroups = aiSkillGroups
        self.skills = skills
        self.careers = careers
    }

    init(fields f: FirestoreFields) {
        self.init(
            name: f["name"].str(),
            title: f["title"].str(),
            experience: f["experience"].str(),
            bio: f["bio"].str(),
            email: f["email"].str(),
            phone: f["phone"].str(),
            github: f["github"].strOrNil,
            notion: f["notion"].strOrNil,
            certificate: f["certificate"].str(),
            directSkillGroups: f["directSkillGroups"].mapList.map(SkillGroup.init(fields:)),
            aiSkillGroups: f["aiSkillGroups"].mapList.map(SkillGroup.init(fields:)),
            skills: f["skills"].strList,
            careers: f["careers"].mapList.map(CareerHistory.init(fields:))
        )
    }

    var fields: FirestoreFields {
        [
            "name": .string(name),
            "title": .string(title),
            "experience": .string(experience),
            "bio": .string(bio),
            "email": .string(email),
            "phone": .string(phone),
            "github": .optionalString(github),
            "notion": .optionalString(notion),
            "certificate": .string(certificate),
            "directSkillGroups": .array(directSkillGroups.map(\.value)),
            "aiSkillGroups": .array(aiSkillGroups.map(\.value)),
            "skills": .strings(skills),
            "careers": .array(careers.map(\.value)),
        ]
    }
}

/// 화면 한 벌을 그리는 데 필요한 콘텐츠 묶음.
struct SiteContent: Hashable {
    var profile: ProfileData
    var projects: [ProjectData]

    /// Firestore 에서 실제로 읽어온 값이면 true, 폴백 상수면 false.
    var fromFirestore: Bool

    /// 네트워크 실패나 최초 시드 이전 상태에서 쓰는 하드코딩 폴백.
    static let fallback = SiteContent(
        profile: DefaultContent.profile,
        projects: DefaultContent.projects,
        fromFirestore: false
    )
}
