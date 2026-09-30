import Foundation

/// Fast line-number lookup over UTF-16 offsets (matches NSTextView character indices).
final class LineIndex {
    private(set) var starts: [Int] = [0]

    var count: Int { starts.count }

    func rebuild(_ text: NSString) {
        var result = [0]
        let n = text.length
        var buffer = [unichar](repeating: 0, count: 4096)
        var pos = 0
        var pendingCR = false
        while pos < n {
            let len = min(4096, n - pos)
            text.getCharacters(&buffer, range: NSRange(location: pos, length: len))
            for i in 0..<len {
                let c = buffer[i]
                let idx = pos + i
                if pendingCR {
                    pendingCR = false
                    if c == 10 {
                        result.append(idx + 1) // CRLF: next line starts after the LF
                        continue
                    } else {
                        result.append(idx) // lone CR ended the previous line
                    }
                }
                if c == 10 {
                    result.append(idx + 1)
                } else if c == 13 {
                    pendingCR = true
                }
            }
            pos += len
        }
        if pendingCR { result.append(n) }
        starts = result
    }

    /// 1-based line number containing the UTF-16 offset.
    func lineNumber(at location: Int) -> Int {
        var lo = 0
        var hi = starts.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if starts[mid] <= location { lo = mid } else { hi = mid - 1 }
        }
        return lo + 1
    }

    /// UTF-16 offset where the given 1-based line begins.
    func lineStart(ofLine line: Int) -> Int {
        starts[max(0, min(line - 1, starts.count - 1))]
    }

    func isLineStart(_ location: Int) -> Bool {
        var lo = 0
        var hi = starts.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            if starts[mid] == location { return true }
            if starts[mid] < location { lo = mid + 1 } else { hi = mid - 1 }
        }
        return false
    }
}
