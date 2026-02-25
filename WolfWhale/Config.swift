// Config.swift - Loads Supabase credentials from build configuration
// SECURITY: Credentials should be set in Secrets.xcconfig (excluded from git)
// Fallback values below are for development only — rotate before production

import Foundation

enum Config {
    static let SUPABASE_URL: String = {
        guard let value = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String, !value.isEmpty else {
            fatalError("Missing SUPABASE_URL in Info.plist — configure via .xcconfig")
        }
        return value
    }()

    static let SUPABASE_ANON_KEY: String = {
        guard let value = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String, !value.isEmpty else {
            fatalError("Missing SUPABASE_ANON_KEY in Info.plist — configure via .xcconfig")
        }
        return value
    }()
}
