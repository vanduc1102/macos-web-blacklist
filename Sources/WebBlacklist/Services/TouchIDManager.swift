import Foundation
import LocalAuthentication

public final class TouchIDManager {
    public static let shared = TouchIDManager()
    
    private init() {}
    
    /// Checks if Touch ID (biometric authentication) is available on this Mac
    public var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Performs biometric authentication with fallback to Mac passcode
    public func authenticate(
        reason: String = "Authenticate with Touch ID to unlock Web Blacklist",
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        
        var authError: NSError?
        
        // Prefer biometric authentication
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(.success(()))
                    } else {
                        let err = error ?? NSError(domain: "TouchID", code: -1, userInfo: [NSLocalizedDescriptionKey: "Authentication failed"])
                        completion(.failure(err))
                    }
                }
            }
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) {
            // Fallback to device passcode/password
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(.success(()))
                    } else {
                        let err = error ?? NSError(domain: "TouchID", code: -1, userInfo: [NSLocalizedDescriptionKey: "Authentication failed"])
                        completion(.failure(err))
                    }
                }
            }
        } else {
            let err = authError ?? NSError(domain: "TouchID", code: -2, userInfo: [NSLocalizedDescriptionKey: "Authentication not supported on this device"])
            completion(.failure(err))
        }
    }
}
