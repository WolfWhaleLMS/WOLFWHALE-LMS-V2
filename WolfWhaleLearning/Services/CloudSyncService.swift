import Foundation
import CloudKit

// MARK: - Lightweight Codable types for iCloud key-value sync

private struct CloudUserPreferences: Codable {
    var userId: String
    var firstName: String
    var lastName: String
    var email: String
    var role: String
    var avatarSystemName: String
    var colorSchemePreference: String?
    var biometricEnabled: Bool
    var calendarSyncEnabled: Bool
}

// MARK: - CloudSyncService

@Observable
@MainActor
final class CloudSyncService {

    // MARK: - State

    var isSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.syncEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.syncEnabledKey) }
    }

    var isSyncing = false
    var syncError: String?

    var lastCloudSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: Self.lastSyncDateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastSyncDateKey) }
    }

    var iCloudAvailable = false

    // MARK: - Constants

    private static let syncEnabledKey = "wolfwhale_icloud_sync_enabled"
    private static let lastSyncDateKey = "wolfwhale_icloud_last_sync"
    private static let preferencesRecordType = "UserPreferences"
    private static let preferencesRecordName = "currentUserPrefs"

    // MARK: - CloudKit

    private var container: CKContainer { CKContainer.default() }
    private var privateDB: CKDatabase { container.privateCloudDatabase }

    // MARK: - Init

    init() {
        // Guard: if no iCloud identity token, iCloud is not available.
        // This avoids calling CKContainer.accountStatus() which can crash
        // when the iCloud/CloudKit capability is not enabled.
        guard FileManager.default.ubiquityIdentityToken != nil else {
            iCloudAvailable = false
            return
        }
        Task {
            iCloudAvailable = await checkiCloudAvailability()
        }
    }

    // MARK: - Check Availability

    func checkiCloudAvailability() async -> Bool {
        do {
            let status = try await container.accountStatus()
            let available = status == .available
            iCloudAvailable = available
            return available
        } catch {
            #if DEBUG
            print("[CloudSync] iCloud availability check failed: \(error)")
            #endif
            iCloudAvailable = false
            return false
        }
    }

    // MARK: - Sync To Cloud

    /// Saves lightweight user preferences to iCloud private database.
    func syncToCloud(user: User) async {
        guard isSyncEnabled, iCloudAvailable else { return }
        isSyncing = true
        syncError = nil

        do {
            let recordID = CKRecord.ID(recordName: Self.preferencesRecordName)

            // Try to fetch existing record first to avoid duplicates
            let record: CKRecord
            do {
                record = try await privateDB.record(for: recordID)
            } catch {
                // Record doesn't exist yet, create new
                record = CKRecord(recordType: Self.preferencesRecordType, recordID: recordID)
            }

            let prefs = CloudUserPreferences(
                userId: user.id.uuidString,
                firstName: user.firstName,
                lastName: user.lastName,
                email: user.email,
                role: user.role.rawValue,
                avatarSystemName: user.avatarSystemName,
                colorSchemePreference: UserDefaults.standard.string(forKey: UserDefaultsKeys.colorSchemePreference),
                biometricEnabled: UserDefaults.standard.bool(forKey: UserDefaultsKeys.biometricEnabled),
                calendarSyncEnabled: UserDefaults.standard.bool(forKey: UserDefaultsKeys.calendarSyncEnabled)
            )

            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(prefs)
            record["preferencesJSON"] = String(data: jsonData, encoding: .utf8) as CKRecordValue?
            record["lastModified"] = Date() as CKRecordValue

            try await privateDB.save(record)
            lastCloudSyncDate = Date()

            #if DEBUG
            print("[CloudSync] Successfully synced preferences to iCloud")
            #endif
        } catch {
            syncError = "Failed to sync to iCloud: \(error.localizedDescription)"
            #if DEBUG
            print("[CloudSync] Sync to cloud failed: \(error)")
            #endif
        }

        isSyncing = false
    }

    // MARK: - Fetch From Cloud

    /// Pulls lightweight user preferences from iCloud. Returns the preferences if found.
    func fetchFromCloud() async -> CloudFetchResult? {
        guard isSyncEnabled, iCloudAvailable else { return nil }
        isSyncing = true
        syncError = nil

        defer { isSyncing = false }

        do {
            let recordID = CKRecord.ID(recordName: Self.preferencesRecordName)
            let record = try await privateDB.record(for: recordID)

            guard let jsonString = record["preferencesJSON"] as? String,
                  let jsonData = jsonString.data(using: .utf8) else {
                return nil
            }

            let decoder = JSONDecoder()
            let prefs = try decoder.decode(CloudUserPreferences.self, from: jsonData)
            lastCloudSyncDate = Date()

            return CloudFetchResult(
                colorSchemePreference: prefs.colorSchemePreference,
                biometricEnabled: prefs.biometricEnabled,
                calendarSyncEnabled: prefs.calendarSyncEnabled
            )
        } catch {
            // CKError.unknownItem means no record exists yet, which is fine
            let ckError = error as? CKError
            if ckError?.code != .unknownItem {
                syncError = "Failed to fetch from iCloud: \(error.localizedDescription)"
                #if DEBUG
                print("[CloudSync] Fetch from cloud failed: \(error)")
                #endif
            }
            return nil
        }
    }
}

// MARK: - Fetch Result

/// Lightweight result containing preferences fetched from iCloud.
struct CloudFetchResult {
    var colorSchemePreference: String?
    var biometricEnabled: Bool
    var calendarSyncEnabled: Bool
}
