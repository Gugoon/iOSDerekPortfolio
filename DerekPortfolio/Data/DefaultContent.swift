//
//  DefaultContent.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  샘플 프로필 및 프로젝트 데이터.
//  "초기 시드 데이터 + 최후의 폴백" 두 가지 역할을 한다.
//
//  공개 저장소에 올라가는 파일이라 실제 인물 · 연락처 · 회사가 아닌 가상의 값만 넣는다.
//  이메일은 example.com, 전화번호는 010-0000-0000, 링크는 example.com 을 쓴다.
//  실제 콘텐츠는 Firestore 에만 두고 관리자 화면에서 고친다.
//
//  경력의 회사명과 프로젝트의 회사명을 맞춰 두어, 경력 항목을 누르면 프로젝트
//  시트가 열리는 흐름(projectsForCareer)도 샘플만으로 확인할 수 있다.
//

import Foundation

enum DefaultContent {
    static let profile = ProfileData(
        name: "홍길동",
        title: "Sample Mobile & Full-Stack Developer",
        experience: "5년 이상",
        bio: "이 문구는 샘플 데이터입니다. Firestore 에 콘텐츠가 없거나\n읽기에 실패했을 때 대신 표시됩니다.\n\n"
            + "iOS · Android 네이티브 앱과 크로스 플랫폼 앱을 만들어 온\n가상의 개발자 프로필입니다. "
            + "관리자 화면에서 '기본 데이터 가져오기'를 누르면\n이 샘플이 Firestore 에 들어갑니다.",
        email: "developer@example.com",
        phone: "010-0000-0000",
        github: "https://github.com/example",
        notion: "https://example.com/resume",
        certificate: "샘플 자격증 1급 (2020.01)",
        directSkillGroups: [
            SkillGroup(category: "iOS 개발", skills: [
                "SwiftUI", "UIKit", "Combine", "Swift Concurrency", "MVVM",
            ]),
            SkillGroup(category: "Android 개발", skills: [
                "Kotlin", "Jetpack Compose", "Coroutine", "Hilt (DI)", "MVVM",
            ]),
            SkillGroup(category: "크로스 플랫폼 (Cross-Platform)", skills: [
                "Flutter", "Dart",
            ]),
            SkillGroup(category: "협업 & 도구", skills: [
                "Git / GitHub", "Jira", "Figma", "Firebase",
            ]),
        ],
        aiSkillGroups: [
            SkillGroup(category: "LLM 서비스 연동 (샘플)", skills: [
                "LLM API 연동", "프롬프트 엔지니어링", "Function Calling",
            ]),
            SkillGroup(category: "백엔드 & 데이터 (샘플)", skills: [
                "FastAPI (Python)", "PostgreSQL", "Docker Compose", "Terraform (IaC)",
            ]),
        ],
        skills: [
            "SwiftUI", "Combine", "Kotlin", "Jetpack Compose", "Flutter",
            "LLM API", "FastAPI", "PostgreSQL", "Docker",
        ],
        careers: [
            CareerHistory(company: "샘플테크 (Sample Tech)", period: "2023.01 - 2025.12", duration: "3년",
                          role: "정규직 / Mobile Developer"),
            CareerHistory(company: "예시소프트", period: "2021.03 - 2022.12", duration: "1년 10개월",
                          role: "정규직 / iOS Developer"),
            CareerHistory(company: "데모랩스", period: "2020.01 - 2021.02", duration: "1년 2개월",
                          role: "계약직 / Android Developer"),
        ]
    )

    static let projects: [ProjectData] = [
        // 1. 샘플테크 - 모바일
        ProjectData(
            title: "샘플 커머스 앱 - 상품 탐색 & 간편 결제",
            company: "샘플테크",
            description: "가상의 쇼핑 서비스를 위한 샘플 프로젝트입니다. "
                + "상품 목록 · 상세 · 장바구니 · 결제 흐름을 네이티브로 구현한 예시입니다.",
            period: "2024.06 - 2025.12",
            techStack: ["SwiftUI", "Combine", "Kotlin", "Jetpack Compose", "MVVM"],
            role: "iOS & Android 개발",
            achievements: [
                "SwiftUI 와 Combine 기반의 반응형 화면 구성 (샘플 문구)",
                "Jetpack Compose 로 Android 화면을 같은 구조로 구현 (샘플 문구)",
                "결제 모듈 연동 및 오류 처리 흐름 정리 (샘플 문구)",
            ],
            liveUrl: "https://example.com/commerce",
            appStoreUrl: "https://example.com/app-store",
            playStoreUrl: "https://example.com/google-play",
            category: .mobile
        ),

        // 2. 샘플테크 - AI
        ProjectData(
            title: "샘플 AI 챗봇 - LLM 기반 고객 상담",
            company: "샘플테크",
            description: "LLM API 를 연동해 자주 묻는 질문에 답하는 가상의 상담 챗봇입니다.",
            period: "2023.03 - 2024.05",
            techStack: ["SwiftUI", "LLM API", "Function Calling", "FastAPI"],
            role: "iOS & AI 연동 개발",
            achievements: [
                "대화 화면과 스트리밍 응답 표시 구현 (샘플 문구)",
                "도구 호출(Function Calling)로 주문 조회 연결 (샘플 문구)",
            ],
            category: .ai
        ),

        // 3. 예시소프트 - 모바일
        ProjectData(
            title: "예시 일정 관리 앱 - 위젯 & 알림",
            company: "예시소프트",
            description: "홈 화면 위젯과 로컬 알림으로 일정을 확인하는 가상의 생산성 앱입니다.",
            period: "2021.03 - 2022.12",
            techStack: ["Swift", "UIKit", "WidgetKit", "Core Data"],
            role: "iOS 앱 개발",
            achievements: [
                "WidgetKit 으로 오늘 일정 위젯 제공 (샘플 문구)",
                "오프라인에서도 동작하는 로컬 저장소 구성 (샘플 문구)",
            ],
            appStoreUrl: "https://example.com/app-store",
            category: .mobile
        ),

        // 4. 데모랩스 - 웹
        ProjectData(
            title: "데모 대시보드 - 반응형 관리자 웹",
            company: "데모랩스",
            description: "데이터를 표와 차트로 보여 주는 가상의 관리자 웹 서비스입니다.",
            period: "2020.01 - 2021.02",
            techStack: ["Flutter Web", "Dart", "Firebase Hosting"],
            role: "웹 프론트엔드 개발",
            achievements: [
                "모바일 · 데스크톱에 대응하는 반응형 레이아웃 구성 (샘플 문구)",
            ],
            liveUrl: "https://example.com/dashboard",
            category: .web
        ),

        // 5. 개인 프로젝트 - 백엔드
        ProjectData(
            title: "샘플 데이터 수집 API - 배치 & 적재",
            company: "개인 프로젝트",
            description: "외부 데이터를 주기적으로 받아 저장하고 API 로 제공하는 가상의 백엔드 프로젝트입니다.",
            period: "2024 - 진행 중",
            techStack: ["FastAPI (Python)", "PostgreSQL", "Docker Compose", "Terraform"],
            role: "백엔드 & 인프라",
            achievements: [
                "FastAPI 기반 조회 API 설계 (샘플 문구)",
                "Docker Compose 로 로컬 개발 환경 구성 (샘플 문구)",
            ],
            githubUrl: "https://github.com/example/sample-api",
            category: .backend
        ),

        // 6. 개인 프로젝트 - 기타
        ProjectData(
            title: "샘플 토이 프로젝트 - 기타 분류 예시",
            company: "개인 프로젝트",
            description: "카테고리 필터의 '기타' 탭을 확인하기 위한 샘플 항목입니다.",
            period: "2019",
            techStack: ["Kotlin", "Retrofit"],
            role: "1인 개발",
            achievements: [
                "링크가 없는 카드의 모양을 확인하는 샘플 (샘플 문구)",
            ],
            category: .other
        ),
    ]
}
