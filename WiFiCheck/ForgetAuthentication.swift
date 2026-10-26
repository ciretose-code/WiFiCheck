//
//  ForgetAuthentication.swift
//  WiFiCheck
//

import Foundation
import LocalAuthentication

/// Optional LocalAuthentication gate before destructive Forget Network.
enum ForgetAuthentication {

    /// UserDefaults / AppStorage key. Default is `true` (require auth).
    static let preferenceKey = "requireAuthToForget"

    static var isRequired: Bool {
        if UserDefaults.standard.object(forKey: preferenceKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: preferenceKey)
    }

    enum AuthError: LocalizedError {
        case unavailable(String)
        case failed(String)
        case cancelled

        var errorDescription: String? {
            switch self {
            case .unavailable(let detail):
                return "This Mac could not offer authentication. \(detail)"
            case .failed(let detail):
                return detail
            case .cancelled:
                return "Authentication was cancelled."
            }
        }
    }

    /// Runs device-owner auth (Touch ID / password) when the preference is on.
    /// When the preference is off, completes successfully without prompting.
    static func authorizeIfRequired(
        reason: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard isRequired else {
            completion(.success(()))
            return
        }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var laError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &laError) else {
            let detail = laError?.localizedDescription ?? "Authentication is not available."
            completion(.failure(AuthError.unavailable(detail)))
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(()))
                    return
                }
                let nsError = error as NSError?
                let cancelCodes: Set<Int> = [
                    LAError.userCancel.rawValue,
                    LAError.appCancel.rawValue,
                    LAError.systemCancel.rawValue,
                ]
                if let code = nsError?.code, cancelCodes.contains(code) {
                    completion(.failure(AuthError.cancelled))
                    return
                }
                completion(.failure(AuthError.failed(error?.localizedDescription ?? "Authentication failed.")))
            }
        }
    }
}
