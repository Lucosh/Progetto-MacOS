import CommonCrypto
import FeniceCore
import Foundation

/// PBKDF2-SHA256, il salt è diverso per ogni utente
struct PBKDF2Hasher: PasswordHasher {
    var rounds: UInt32 = 120_000

    func hash(password: String, salt: String) -> String {
        let saltBytes = Array(salt.utf8)
        var derived = [UInt8](repeating: 0, count: 32)
        let status = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            password,
            password.utf8.count,
            saltBytes,
            saltBytes.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            rounds,
            &derived,
            derived.count
        )
        precondition(status == Int32(kCCSuccess), "PBKDF2 non riuscito")
        return derived.map { String(format: "%02x", $0) }.joined()
    }
}
