//
//  Log.swift
//  lx3
//
//  Created by 구보성 on 4/1/24.
//

import Foundation

public enum LogLevel  {
    case Info
    case Debug
    case System
    case Focus
}

private func LogDebug<T>(_ log: T, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
    
    let filename = file.ns.lastPathComponent.ns.deletingPathExtension
    
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    let nowString = formatter.string(from: Date())
    

    let informationPartS: String = "🧑🏻‍💻⁉️ [\(filename).\(function)]<Line:\(line)>\n⏰[\(nowString)]\n"
    printLogError(informationPartS, log, "🐞🐞🐞🐞")
}


public func Log<T>(_ log: T, _ level: LogLevel = .Info, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
    let filename = file.ns.lastPathComponent.ns.deletingPathExtension
    
    switch level {
    case .System:
        printLog("", log)
        break
    case .Debug:
        LogDebug(log, filename, function, line)
        break
    case .Focus:
        printLog("⚠️ ", log)
    default:
        printLog("", log)
        break
    }
}

private func printLog<T>(_ informationPart: String, _ log: T) {
    print("\(informationPart)\(log)")
}

private func printLogError<T>(_ informationPart: String, _ log: T, _ informationPartE : String) {
    print("\(informationPart)\(log)\n\(informationPartE)")
}


public func apiLog(request: URLRequest){

    let urlString = request.url?.absoluteString ?? ""
    let components = NSURLComponents(string: urlString)
    
    let method = request.httpMethod != nil ? "\(request.httpMethod!)": ""
    let path = "\(components?.path ?? "")"
    let query = "\(components?.query ?? "")"
    let host = "\(components?.host ?? "")"
    
    var requestLog = "\n📶📶📶📶📶 REQ 📶📶📶📶📶\n"
    requestLog += "\(urlString)"
    requestLog += "\n\n"
    requestLog += "\(method) \(path)?\(query) HTTP/1.1\n"
    requestLog += "Host: \(host)\n"
    for (key,value) in request.allHTTPHeaderFields ?? [:] {
        requestLog += "\(key): \(value)\n"
    }
    if let body = request.httpBody{
        let bodyString = NSString(data: body, encoding: String.Encoding.utf8.rawValue) ?? "Can't render body; not utf8 encoded";
        requestLog += "\n\(bodyString)\n"
    }
    let df = DateFormatter()
    df.dateFormat = "MM-dd H:m:ss.SSSS"
    requestLog += "🕰 \(df.string(from: Date())) \n"
#if DEBUG
    requestLog += "\n🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚\n"
    print(requestLog)
#else
#endif
}

public func apiLog(data: Data?, response: HTTPURLResponse?, error: Error?){

    let urlString = response?.url?.absoluteString
    let components = NSURLComponents(string: urlString ?? "")
    
    let path = "\(components?.path ?? "")"
    let query = "\(components?.query ?? "")"
    
    var responseLog = "\n⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️ RESPONSE ⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️\n"
    if let urlString = urlString {
        responseLog += "\(urlString)"
        responseLog += "\n\n"
    }
    
    if let statusCode =  response?.statusCode{
        responseLog += "HTTP \(statusCode) \(path)?\(query)\n"
    }
    if let host = components?.host{
        responseLog += "Host: \(host)\n"
    }
    for (key,value) in response?.allHeaderFields ?? [:] {
        responseLog += "\(key): \(value)\n"
    }
    if let body = data{
        let bodyString = NSString(data: body, encoding: String.Encoding.utf8.rawValue) ?? "Can't render body; not utf8 encoded";
        responseLog += "\n\(bodyString)\n"
    }
    if let error = error{
        responseLog += "\nError: \(error.localizedDescription)\n"
        
    }
    let df = DateFormatter()
    df.dateFormat = "MM-dd H:m:ss.SSSS"
    responseLog += "🕰 \(df.string(from: Date())) \n"
#if DEBUG
    responseLog += "🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚🔚\n";
    print(responseLog)
#else
#endif
}
