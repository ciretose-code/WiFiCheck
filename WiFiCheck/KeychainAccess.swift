//
//  KeychainAccess.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 10/29/21.
//

import Foundation


class KeychainAccess {
    
    enum KeychainError: Error {
        // Attempted read for an item that does not exist.
        case itemNotFound
        
        // Attempted save to override an existing item.
        // Use update instead of save to update existing items
        case duplicateItem
        
        // A read of an item in any format other than Data
        case invalidItemFormat
        
        // Any operation result status than errSecSuccess
        case unexpectedStatus(OSStatus)
    }

    static func save(password: Data, service: String, account: String) throws {

        let query: [String: AnyObject] = [
            // kSecAttrService,  kSecAttrAccount, and kSecClass
            // uniquely identify the item to save in Keychain
            kSecAttrService as String: service as AnyObject,
            kSecAttrAccount as String: account as AnyObject,
            kSecClass as String: kSecClassGenericPassword,

            // kSecValueData is the item value to save
            kSecValueData as String: password as AnyObject,

            // kSecAttrAccessible controls when the keychain item can be accessed
            // kSecAttrAccessibleWhenUnlockedThisDeviceOnly means:
            // - Only accessible when device is unlocked
            // - Not backed up to iCloud or transferred to other devices
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // SecItemAdd attempts to add the item identified by
        // the query to keychain
        let status = SecItemAdd(
            query as CFDictionary,
            nil
        )

        // errSecDuplicateItem is a special case where the
        // item identified by the query already exists. Throw
        // duplicateItem so the client can determine whether
        // or not to handle this as an error
        if status == errSecDuplicateItem {
            throw KeychainError.duplicateItem
        }

        // Any status other than errSecSuccess indicates the
        // save operation failed.
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func readPassword(service: String, account: String) throws -> Data {
        let query: [String: AnyObject] = [
            // kSecAttrService,  kSecAttrAccount, and kSecClass
            // uniquely identify the item to read in Keychain
            kSecAttrService as String: service as AnyObject,
            kSecAttrAccount as String: account as AnyObject,
            kSecClass as String: kSecClassGenericPassword,
            
            // kSecMatchLimitOne indicates keychain should read
            // only the most recent item matching this query
            kSecMatchLimit as String: kSecMatchLimitOne,

            // kSecReturnData is set to kCFBooleanTrue in order
            // to retrieve the data for the item
            kSecReturnData as String: kCFBooleanTrue
        ]

        // SecItemCopyMatching will attempt to copy the item
        // identified by query to the reference itemCopy
        var itemCopy: AnyObject?
        let status = SecItemCopyMatching(
            query as CFDictionary,
            &itemCopy
        )

        // errSecItemNotFound is a special status indicating the
        // read item does not exist. Throw itemNotFound so the
        // client can determine whether or not to handle
        // this case
        guard status != errSecItemNotFound else {
            throw KeychainError.itemNotFound
        }
        
        // Any status other than errSecSuccess indicates the
        // read operation failed.
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }

        // This implementation of KeychainInterface requires all
        // items to be saved and read as Data. Otherwise,
        // invalidItemFormat is thrown
        guard let password = itemCopy as? Data else {
            throw KeychainError.invalidItemFormat
        }

        return password
    }

    /// Retrieves WiFi password from Keychain using Result type
    /// - Parameter wifiname: The SSID of the WiFi network
    /// - Returns: Result containing password string on success, or error on failure
    static func getPassword(forNetwork wifiname: String) -> Result<String, Error> {
        do {
            let pwd = try KeychainAccess.readPassword(service: Constants.keychainService, account: wifiname)
            let password = String(decoding: pwd, as: UTF8.self)
            return .success(password)
        } catch {
            return .failure(error)
        }
    }

    /// Legacy method for retrieving WiFi password (deprecated)
    /// - Parameter wifiname: The SSID of the WiFi network
    /// - Returns: Tuple of (success: Bool, password/error: String)
    @available(*, deprecated, message: "Use getPassword(forNetwork:) which returns Result<String, Error>")
    static func getWiFiPassword(forNetwork wifiname: String) -> (Bool, String) {
        switch getPassword(forNetwork: wifiname) {
        case .success(let password):
            return (true, password)
        case .failure(let error):
            return (false, "Unable to get password: \(error)")
        }
    }

}
