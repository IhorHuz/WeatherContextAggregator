import Foundation

enum AppConfig {
    static let backendBaseURL = "https://weathercontextaggregator-production.up.railway.app"
}

// For iOS Simulator: http://localhost:8000
// For a physical device on the same LAN: machine's local IP.
//  static let backendBaseURL: String = {
//        #if DEBUG
//        return "http://localhost:8000"
//        #else
//        return "https://weathercontextaggregator-production.up.railway.app/"
//        #endif
//    }()