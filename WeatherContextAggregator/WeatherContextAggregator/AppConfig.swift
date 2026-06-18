import Foundation

enum AppConfig {
    // Update the production URL to your deployed backend after running M6.
    // For the iOS Simulator use http://localhost:8000 (default below).
    // For a physical device on the same LAN, replace with your machine's local IP.
    static let backendBaseURL: String = {
        #if DEBUG
        return "http://192.168.1.183:8000"
        #else
        return "https://your-backend.up.railway.app"
        #endif
    }()
}
