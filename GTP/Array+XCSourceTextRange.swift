import XcodeKit

extension Array where Element == String {
    
    /// Given an Array of Strings and an XCSourceTextRange
    /// The range in terms of string indices is returned
    func getRanges(textRange: XCSourceTextRange) -> [Range<String.Index>] {
        
        // Case 1: Single line
        if textRange.start.line == textRange.end.line {
            let line = self[textRange.start.line]
            let range = line.index(line.startIndex, offsetBy: textRange.start.column)..<line.index(line.startIndex, offsetBy: textRange.end.column)
            return [range]
            
        // Case 2: Multiple Lines
        } else {
            
            let lines = self[(textRange.start.line)...(textRange.end.line)]
            let first = lines.first
            let firstRange = (first?.index(first!.startIndex, offsetBy: textRange.start.column))!..<first!.endIndex
            var ranges = [firstRange]
            
            // Case 2b: More than 2 lines
            if lines.count > 2 {
                let middle = lines.dropFirst().dropLast()
                for line in middle {
                    ranges.append(line.startIndex..<line.endIndex)
                }
            }
            
            let last = lines.last
            let lastRange = (last?.startIndex)!..<(last?.index(last!.startIndex, offsetBy: textRange.end.column))!
            ranges.append(lastRange)
            
            return ranges
        }
    }
}
