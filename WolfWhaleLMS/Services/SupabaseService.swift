import Foundation
import Supabase

nonisolated(unsafe) let supabaseClient = SupabaseClient(
    supabaseURL: URL(string: Config.SUPABASE_URL.isEmpty ? "https://placeholder.supabase.co" : Config.SUPABASE_URL)!,
    supabaseKey: Config.SUPABASE_ANON_KEY
)
