import Foundation
import Security
import CommonCrypto
import SQLite3

// Chrome cookie decryption on macOS:
// 1. Read encryption key from Keychain ("Chrome Safe Storage")
// 2. Derive AES key via PBKDF2 (salt: "saltysalt", iterations: 1003, keylen: 16)
// 3. Read encrypted cookie from Chrome's SQLite database
// 4. Decrypt AES-128-CBC (IV: 16 spaces)

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write(Data("Usage: cookie-reader <domain> <cookie-name>\n".utf8))
    exit(1)
}

let domain = args[1]
let cookieName = args[2]

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(Data("ERROR: \(msg)\n".utf8))
    exit(1)
}

// Step 1: Read Chrome Safe Storage key from Keychain via `security` CLI
func getChromeKey() -> String {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    process.arguments = ["find-generic-password", "-w", "-s", "Chrome Safe Storage", "-a", "Chrome"]
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        fail("Failed to run 'security' command: \(error.localizedDescription)")
    }

    guard process.terminationStatus == 0 else {
        if process.terminationStatus == 44 {
            fail("Chrome Safe Storage key not found in Keychain. Is Chrome installed?")
        } else if process.terminationStatus == 36 {
            fail("Keychain access denied. macOS should show a permission prompt for 'cookie-reader' — check for it and click Always Allow.")
        } else {
            fail("Keychain error (exit code: \(process.terminationStatus)). Try running again — macOS may prompt for access.")
        }
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard var password = String(data: data, encoding: .utf8) else {
        fail("Could not decode Chrome Safe Storage key.")
    }

    // Remove trailing newline from security output
    password = password.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !password.isEmpty else {
        fail("Chrome Safe Storage key is empty.")
    }

    return password
}

// Step 2: Derive AES key via PBKDF2
func deriveKey(password: String) -> [UInt8] {
    let salt = Array("saltysalt".utf8)
    let iterations: UInt32 = 1003
    let keyLength = 16
    var derivedKey = [UInt8](repeating: 0, count: keyLength)

    let passwordData = Array(password.utf8)
    let status = CCKeyDerivationPBKDF(
        CCPBKDFAlgorithm(kCCPBKDF2),
        passwordData, passwordData.count,
        salt, salt.count,
        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
        iterations,
        &derivedKey, keyLength
    )

    guard status == kCCSuccess else {
        fail("PBKDF2 key derivation failed (status: \(status)).")
    }

    return derivedKey
}

// Step 3: Read encrypted cookie and DB version from Chrome's SQLite database
struct CookieResult {
    let encryptedValue: Data
    let dbVersion: Int
}

func readEncryptedCookie(domain: String, name: String) -> CookieResult? {
    let cookiePaths = [
        NSHomeDirectory() + "/Library/Application Support/Google/Chrome/Default/Cookies",
        NSHomeDirectory() + "/Library/Application Support/Google/Chrome/Profile 1/Cookies"
    ]

    var dbPath: String?
    for path in cookiePaths {
        if FileManager.default.fileExists(atPath: path) {
            dbPath = path
            break
        }
    }

    guard let path = dbPath else {
        fail("Chrome cookie database not found. Is Chrome installed and has it been opened?")
    }

    var db: OpaquePointer?
    guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        fail("Cannot open Chrome cookie database. Make sure Chrome is closed or try again.")
    }
    defer { sqlite3_close(db) }

    // Read database version from meta table
    var dbVersion = 0
    var verStmt: OpaquePointer?
    if sqlite3_prepare_v2(db, "SELECT value FROM meta WHERE key='version'", -1, &verStmt, nil) == SQLITE_OK {
        if sqlite3_step(verStmt) == SQLITE_ROW {
            dbVersion = Int(sqlite3_column_int(verStmt, 0))
        }
        sqlite3_finalize(verStmt)
    }

    let sql = "SELECT encrypted_value FROM cookies WHERE host_key LIKE ? AND name = ? ORDER BY expires_utc DESC LIMIT 1"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
        fail("Failed to query Chrome cookie database.")
    }
    defer { sqlite3_finalize(stmt) }

    let hostPattern = "%\(domain)%"
    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    sqlite3_bind_text(stmt, 1, hostPattern, -1, transient)
    sqlite3_bind_text(stmt, 2, name, -1, transient)

    guard sqlite3_step(stmt) == SQLITE_ROW else {
        return nil
    }

    let blobLength = sqlite3_column_bytes(stmt, 0)
    guard blobLength > 0, let blobPtr = sqlite3_column_blob(stmt, 0) else {
        return nil
    }

    return CookieResult(
        encryptedValue: Data(bytes: blobPtr, count: Int(blobLength)),
        dbVersion: dbVersion
    )
}

// Step 4: Decrypt AES-128-CBC
func decrypt(encryptedData: Data, key: [UInt8], dbVersion: Int) -> String? {
    guard encryptedData.count > 3 else { return nil }

    let allBytes = Array(encryptedData)
    let isV10 = allBytes.count > 3 && allBytes[0] == 0x76 && allBytes[1] == 0x31 && allBytes[2] == 0x30

    guard isV10 else {
        return String(data: encryptedData, encoding: .utf8)
    }

    let ciphertext = Array(encryptedData.dropFirst(3))
    let iv = [UInt8](repeating: 0x20, count: 16)

    // Decrypt without PKCS7 (we strip padding manually for compatibility)
    let outputSize = ciphertext.count + 16
    var decrypted = [UInt8](repeating: 0, count: outputSize)
    var decryptedLength: Int = 0

    let status = CCCrypt(
        CCOperation(1),   // kCCDecrypt
        CCAlgorithm(0),   // kCCAlgorithmAES
        CCOptions(0),     // No padding — strip manually
        key, key.count,
        iv,
        ciphertext, ciphertext.count,
        &decrypted, outputSize,
        &decryptedLength
    )

    guard status == 0, decryptedLength > 0 else { return nil }

    var plaintext = Array(decrypted.prefix(decryptedLength))

    // Chrome DB version >= 24: first 32 bytes are a SHA256 domain hash
    if dbVersion >= 24 && plaintext.count > 32 {
        plaintext = Array(plaintext.dropFirst(32))
    }

    // Strip PKCS7 padding
    if let lastByte = plaintext.last, lastByte > 0, lastByte <= 16 {
        let padLen = Int(lastByte)
        if plaintext.count >= padLen {
            plaintext = Array(plaintext.dropLast(padLen))
        }
    }

    return String(bytes: plaintext, encoding: .utf8)
}

// Main
let password = getChromeKey()
let key = deriveKey(password: password)

guard let result = readEncryptedCookie(domain: domain, name: cookieName) else {
    fail("\(cookieName) cookie not found for domain '\(domain)' in Chrome.")
}

guard let token = decrypt(encryptedData: result.encryptedValue, key: key, dbVersion: result.dbVersion) else {
    fail("Failed to decrypt \(cookieName) cookie. Chrome format may have changed.")
}

guard !token.isEmpty else {
    fail("Decrypted cookie is empty.")
}

print(token, terminator: "")
