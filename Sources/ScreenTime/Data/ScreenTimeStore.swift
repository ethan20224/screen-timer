import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum ScreenTimeStoreError: Error {
    case openFailed(String)
    case executeFailed(String)
}

final class ScreenTimeStore {
    private var db: OpaquePointer?

    init(path: String) throws {
        if sqlite3_open(path, &db) != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(db))
            throw ScreenTimeStoreError.openFailed(message)
        }
        try execute("""
            CREATE TABLE IF NOT EXISTS screen_time (
                day TEXT PRIMARY KEY,
                seconds INTEGER NOT NULL
            );
            """)
    }

    deinit {
        sqlite3_close(db)
    }

    static func defaultPath() -> String {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScreenTime", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        return supportDir.appendingPathComponent("screentime.sqlite3").path
    }

    func save(day: String, seconds: Int) {
        let sql = "INSERT INTO screen_time (day, seconds) VALUES (?, ?) ON CONFLICT(day) DO UPDATE SET seconds = excluded.seconds;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, day, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(statement, 2, Int64(seconds))
        sqlite3_step(statement)
    }

    func secondsForDay(_ day: String) -> Int {
        let sql = "SELECT seconds FROM screen_time WHERE day = ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, day, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    func allDays() -> [String: Int] {
        let sql = "SELECT day, seconds FROM screen_time;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(statement) }
        var result: [String: Int] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            let day = String(cString: sqlite3_column_text(statement, 0))
            let seconds = Int(sqlite3_column_int64(statement, 1))
            result[day] = seconds
        }
        return result
    }

    private func execute(_ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &errorPointer) != SQLITE_OK {
            let message = errorPointer.map { String(cString: $0) } ?? "unknown error"
            sqlite3_free(errorPointer)
            throw ScreenTimeStoreError.executeFailed(message)
        }
    }
}
