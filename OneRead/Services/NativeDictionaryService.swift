import Foundation
import SQLite3

struct NativeDictionaryEntry {
    let word: String
    let phonetic: String
    let translation: String
}

final class NativeDictionaryService {
    static let shared = NativeDictionaryService()

    private let lock = NSLock()
    private var database: OpaquePointer?
    private var lookupStatement: OpaquePointer?

    private init() {
        openDatabaseIfNeeded()
    }

    deinit {
        if let lookupStatement {
            sqlite3_finalize(lookupStatement)
        }

        if let database {
            sqlite3_close(database)
        }
    }

    func lookup(candidates: [String]) -> NativeDictionaryEntry? {
        let filtered = candidates.filter { !$0.isEmpty }
        guard !filtered.isEmpty else {
            return nil
        }

        lock.lock()
        defer { lock.unlock() }

        guard openDatabaseIfNeeded(), prepareLookupStatementIfNeeded(), let lookupStatement else {
            return nil
        }

        for candidate in filtered {
            sqlite3_reset(lookupStatement)
            sqlite3_clear_bindings(lookupStatement)
            sqlite3_bind_text(lookupStatement, 1, candidate, -1, sqliteTransientDestructor)

            guard sqlite3_step(lookupStatement) == SQLITE_ROW else {
                continue
            }

            let word = string(at: 0, in: lookupStatement)
            let phonetic = string(at: 1, in: lookupStatement)
            let translation = string(at: 2, in: lookupStatement)
            guard !translation.isEmpty else {
                continue
            }

            return NativeDictionaryEntry(word: word, phonetic: phonetic, translation: translation)
        }

        return nil
    }

    @discardableResult
    private func openDatabaseIfNeeded() -> Bool {
        if database != nil {
            return true
        }

        guard let url = Bundle.main.url(forResource: "ecdict", withExtension: "sqlite") else {
            return false
        }

        var db: OpaquePointer?
        let result = sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil)
        guard result == SQLITE_OK, let db else {
            if db != nil {
                sqlite3_close(db)
            }
            return false
        }

        database = db
        return true
    }

    @discardableResult
    private func prepareLookupStatementIfNeeded() -> Bool {
        if lookupStatement != nil {
            return true
        }

        guard let database else {
            return false
        }

        let sql = "SELECT display_word, phonetic, translation FROM entries WHERE word = ? LIMIT 1;"
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
        guard result == SQLITE_OK, let statement else {
            if statement != nil {
                sqlite3_finalize(statement)
            }
            return false
        }

        lookupStatement = statement
        return true
    }

    private func string(at column: Int32, in statement: OpaquePointer) -> String {
        guard let cString = sqlite3_column_text(statement, column) else {
            return ""
        }
        return String(cString: cString)
    }
}

private let sqliteTransientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
