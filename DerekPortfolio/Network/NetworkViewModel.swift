//
//  NetworkViewModel.swift
//
//
//  Created by 구보성 on 4/9/24.
//

import Foundation
import Combine
import UIKit

@MainActor
class NetworkViewModel: BaseObservableObject {
    let nvBaseURL =  Constants.BASE_URL
    
    func commonHeader(url : URL , method : RequestType, inModel : Encodable? = nil) -> URLRequest{
        var request = URLRequest(url: url)
        request.timeoutInterval = TimeInterval(30)
        request.httpMethod = method.rawValue
        
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue(CommonUserDefault.localeStr == "system" ? Locale.current.language.languageCode?.identifier : CommonUserDefault.localeStr, forHTTPHeaderField: "Accept-Language")
        request.setValue(Infomation.version, forHTTPHeaderField: "App-Version")
        request.setValue("IOS", forHTTPHeaderField: "App-OS")
        request.setValue(CommonUserDefault.DeviceID, forHTTPHeaderField: "Device-Id") //: UUID
        request.setValue("Apple", forHTTPHeaderField: "Device-Brand")
        request.setValue("\(UIDevice.modelName)", forHTTPHeaderField: "Device-Model")
        request.setValue("\(UIDevice.current.systemVersion)", forHTTPHeaderField: "OS-Version")
        request.setValue("\(CommonUserDefault.shopByToken)", forHTTPHeaderField: "SB-Token")
        request.setValue("\(CommonUserDefault.fcmToken)", forHTTPHeaderField: "X-Token")
        request.setValue("\(CommonUserDefault.googleAnalyticsId)", forHTTPHeaderField: "GA-ID")
        
        if !CommonUserDefault.jwtToken.isEmpty{
            request.setValue("\(CommonUserDefault.tokenGrantType) \(CommonUserDefault.jwtToken)", forHTTPHeaderField: "Authorization")
        }
        
        if let jsonData = inModel?.toJSONData{
            request.httpBody = jsonData()
        }
        
        apiLog(request: request)
        return request
    }
    
    func commonUploadHeader(url : URL , method : RequestType, data : Data) -> URLRequest{
        var request = URLRequest(url: url)
        request.timeoutInterval = TimeInterval(30)
        request.httpMethod = method.rawValue
        
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue(Infomation.version, forHTTPHeaderField: "App-Version")
        request.setValue(CommonUserDefault.localeStr == "system" ? Locale.current.language.languageCode?.identifier : CommonUserDefault.localeStr, forHTTPHeaderField: "Accept-Language")
        request.setValue("IOS", forHTTPHeaderField: "App-OS")
        request.setValue(CommonUserDefault.DeviceID, forHTTPHeaderField: "Device-Id") //: UUID
        request.setValue("Apple", forHTTPHeaderField: "Device-Brand")
        request.setValue("\(UIDevice.modelName)", forHTTPHeaderField: "Device-Model")
        request.setValue("\(UIDevice.current.systemVersion)", forHTTPHeaderField: "OS-Version")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("\(CommonUserDefault.shopByToken)", forHTTPHeaderField: "SB-Token")
        request.setValue("\(CommonUserDefault.fcmToken)", forHTTPHeaderField: "X-Token")
        request.setValue("\(CommonUserDefault.googleAnalyticsId)", forHTTPHeaderField: "GA-ID")
        
        request.httpBody = data
        
        if !CommonUserDefault.jwtToken.isEmpty{
            request.setValue("\(CommonUserDefault.tokenGrantType) \(CommonUserDefault.jwtToken)", forHTTPHeaderField: "Authorization")
        }
        
        apiLog(request: request)
        return request
    }
    
    func uploadData(uploadData: Data, method : RequestType, urlString: String) async throws -> Bool {
        guard let requestURL = URL(string: "\(urlString)") else{
            Log("URL Error")
            return false
        }
        
        let request = commonUploadHeader(url: requestURL, method: method, data: uploadData)
        
        return try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let errorMsg = error {
                    Task{
                        let _ = await self.setToastMessage(errorMsg.localizedDescription, type: .error)
                    }//: TASK
                    continuation.resume(throwing: errorMsg)
                } else {
                    Task{
                        let _ = await self.setToastMessage("파일 업로드 성공")
                    }//: TASK
                    continuation.resume(returning: true)
                }
            }.resume()
        }
    }
    
    //:  공통 API 요청 처리 함수 (데이터 응답 - 요청 데이터 있음)
    func performAPIRequest<T: Codable, U: Codable>(
        endpoint: String,
        method: RequestType,
        requestData: T,
        onSuccess: @escaping (U) -> Void = { _ in }
    ) async -> APICallbackDataModel<U> {
        await withCheckedContinuation { continuation in
            if let url = URL(string: self.nvBaseURL + endpoint) {
                let request = self.commonHeader(url: url, method: method, inModel: requestData)
                
                CombineAPI.fetch(request: request)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            let errorStatus = error as? APICallbackStatus ?? .ERROR
                            continuation.resume(returning: APICallbackDataModel(statusCode: errorStatus, message: error.localizedDescription))
                        }
                    }, receiveValue: { data in
                        let result: APICallbackDataModel<BaseModel<U>> = decodeData(from: data, decoder: JSONDecoder())
                        switch result.statusCode {
                        case .SUCCESS:
                            if let resData = result.data?.data {
                                onSuccess(resData)
                            }
                            continuation.resume(returning: APICallbackDataModel(statusCode: .SUCCESS, message: ""))
                        default:
                            continuation.resume(returning: APICallbackDataModel(statusCode: result.statusCode, message: "\(result.message ?? "")"))
                        }
                    })
                    .store(in: &subscriptions)
            }
        }
    }
    
    //: 공통 API 요청 처리 함수 (데이터 응답 - 요청 데이터 없음)
    func performAPIRequest<U: Codable>(
        endpoint: String,
        method: RequestType,
        onSuccess: @escaping (U) -> Void = { _ in }
    ) async -> APICallbackDataModel<U> {
        await withCheckedContinuation { continuation in
            if let url = URL(string: self.nvBaseURL + endpoint) {
                let request = self.commonHeader(url: url, method: method)
                
                CombineAPI.fetch(request: request)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            let errorStatus = error as? APICallbackStatus ?? .ERROR
                            continuation.resume(returning: APICallbackDataModel(statusCode: errorStatus, message: error.localizedDescription))
                        }
                    }, receiveValue: { data in
                        let result: APICallbackDataModel<BaseModel<U>> = decodeData(from: data, decoder: JSONDecoder())
                        switch result.statusCode {
                        case .SUCCESS:
                            if let resData = result.data?.data {
                                onSuccess(resData)
                            }
                            continuation.resume(returning: APICallbackDataModel(statusCode: .SUCCESS, message: ""))
                        default:
                            continuation.resume(returning: APICallbackDataModel(statusCode: result.statusCode, message: "\(result.message ?? "")"))
                        }
                    })
                    .store(in: &subscriptions)
            }
        }
    }
    
    //:  공통 API 요청 처리 함수 (NoReply 응답 - 요청 데이터 있음)
    func performAPIRequestNoReply<T: Codable>(
        endpoint: String,
        method: RequestType,
        requestData: T,
        onSuccess: @escaping () -> Void = {}
    ) async -> APICallbackDataModel<NoReply> {
        await withCheckedContinuation { continuation in
            if let url = URL(string: self.nvBaseURL + endpoint) {
                let request = self.commonHeader(url: url, method: method, inModel: requestData)
                
                CombineAPI.fetch(request: request)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            let errorStatus = error as? APICallbackStatus ?? .ERROR
                            continuation.resume(returning: APICallbackDataModel(statusCode: errorStatus, message: error.localizedDescription))
                        }
                    }, receiveValue: { data in
                        if let _ = try? JSONDecoder().decode(BaseModel<NoReply>.self, from: data) {
                            onSuccess()
                            continuation.resume(returning: APICallbackDataModel(statusCode: .SUCCESS, message: ""))
                        } else {
                            continuation.resume(returning: APICallbackDataModel(statusCode: .ERROR, message: "Failed to decode response"))
                        }
                    })
                    .store(in: &subscriptions)
            }
        }
    }
    
    //:  공통 API 요청 처리 함수 (NoReply 응답 - 요청 데이터 없음)
    func performAPIRequestNoReply(
        endpoint: String,
        method: RequestType,
        onSuccess: @escaping () -> Void = {}
    ) async -> APICallbackDataModel<NoReply> {
        await withCheckedContinuation { continuation in
            if let url = URL(string: self.nvBaseURL + endpoint) {
                let request = self.commonHeader(url: url, method: method)
                
                CombineAPI.fetch(request: request)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            let errorStatus = error as? APICallbackStatus ?? .ERROR
                            continuation.resume(returning: APICallbackDataModel(statusCode: errorStatus, message: error.localizedDescription))
                        }
                    }, receiveValue: { data in
                        if let _ = try? JSONDecoder().decode(BaseModel<NoReply>.self, from: data) {
                            onSuccess()
                            continuation.resume(returning: APICallbackDataModel(statusCode: .SUCCESS, message: ""))
                        } else {
                            continuation.resume(returning: APICallbackDataModel(statusCode: .ERROR, message: "Failed to decode response"))
                        }
                    })
                    .store(in: &subscriptions)
            }
        }
    }
}
