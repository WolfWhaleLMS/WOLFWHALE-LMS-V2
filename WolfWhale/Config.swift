// Config.swift - Loads Supabase credentials from build configuration
// SECURITY: Credentials should be set in Secrets.xcconfig (excluded from git)
// Fallback values below are for development only — rotate before production

import Foundation

enum Config {
    static let SUPABASE_URL: String = {
        if let value = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String, !value.isEmpty {
            return value
        }
        // Fallback: public project URL (safe to embed in client apps)
        return "https://vkhawdvcfgnmcjhahull.supabase.co"
    }()

    static let SUPABASE_ANON_KEY: String = {
        if let value = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String, !value.isEmpty {
            return value
        }
        // Fallback: public anon key (safe to embed in client apps, RLS enforces security)
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZraGF3ZHZjZmdubWNqaGFodWxsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1NzUzOTgsImV4cCI6MjA4NzE1MTM5OH0.LFbtdohpTrt-bWguWvIajzMyS9KlQfQchp3t7fMpYuM"
    }()
}
