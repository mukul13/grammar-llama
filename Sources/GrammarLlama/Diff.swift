import Foundation
import SwiftUI

enum DiffOp: Equatable {
    case equal(String)
    case insert(String)
    case delete(String)
}

enum WordDiff {
    private static let maxTokens = 1500

    static func tokens(_ s: String) -> [String] {
        var out: [String] = []
        var current = ""
        var currentIsSpace: Bool?
        for ch in s {
            let isSpace = ch.isWhitespace
            if let cis = currentIsSpace, cis != isSpace {
                out.append(current); current = ""
            }
            current.append(ch)
            currentIsSpace = isSpace
        }
        if !current.isEmpty { out.append(current) }
        return out
    }

    static func diff(_ a: String, _ b: String) -> [DiffOp] {
        let x = tokens(a), y = tokens(b)
        guard x.count <= maxTokens, y.count <= maxTokens else { return [.insert(b)] }
        let n = x.count, m = y.count
        var table = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                table[i][j] = x[i] == y[j] ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
            }
        }
        var ops: [DiffOp] = []
        var i = 0, j = 0
        while i < n, j < m {
            if x[i] == y[j] { ops.append(.equal(x[i])); i += 1; j += 1 }
            else if table[i + 1][j] >= table[i][j + 1] { ops.append(.delete(x[i])); i += 1 }
            else { ops.append(.insert(y[j])); j += 1 }
        }
        while i < n { ops.append(.delete(x[i])); i += 1 }
        while j < m { ops.append(.insert(y[j])); j += 1 }
        return merge(ops)
    }

    private static func merge(_ ops: [DiffOp]) -> [DiffOp] {
        var out: [DiffOp] = []
        for op in ops {
            switch (out.last, op) {
            case (.equal(let a)?, .equal(let b)): out[out.count - 1] = .equal(a + b)
            case (.insert(let a)?, .insert(let b)): out[out.count - 1] = .insert(a + b)
            case (.delete(let a)?, .delete(let b)): out[out.count - 1] = .delete(a + b)
            default: out.append(op)
            }
        }
        return out
    }

    static func attributed(_ a: String, _ b: String) -> AttributedString {
        var result = AttributedString()
        for op in diff(a, b) {
            switch op {
            case .equal(let s):
                result += AttributedString(s)
            case .insert(let s):
                var part = AttributedString(s)
                part.backgroundColor = Color.green.opacity(0.22)
                result += part
            case .delete(let s):
                var part = AttributedString(s)
                part.foregroundColor = .secondary
                part.strikethroughStyle = .single
                part.backgroundColor = Color.red.opacity(0.14)
                result += part
            }
        }
        return result
    }
}
