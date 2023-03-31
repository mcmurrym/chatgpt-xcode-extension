import XcodeKit

/// Convienence to internally refer to this tuple as TextData
typealias TextData = (line: Int, range: Range<String.Index>, text: String)

/// Segment of data used to represent a multi-line selection of text
typealias Selection = [TextData]

enum ReplaceSelected {
    /// # Replace Selected Text
    ///
    /// This function should be used only when formatting selected text. It will not format
    /// anything but the selected text.
    ///
    /// Works with multiple selections simultaneously or single selections.
    ///
    /// - Parameters:
    ///   - buffer: The `XCSourceTextBuffer` provided by the `XCSourceEditorCommandInvocation`.
    ///   - formatter: A function that uses the components of `Selection` to transform the original selected text into a new format.
    ///
    /// - Requires:
    ///    The `getRanges` Array method.
    ///
    /// - Important: Tested and works with `CSVToArray` and `verticalCSVToArray`
    ///
    /// - Note: At Step 2. I would like to make an adjustment that allows for both the simultaneuous formatting of selections or
    ///         the individual formatting of selections. Currently only performs the latter.
    ///
    ///
    static func replaceSelected(buffer: XCSourceTextBuffer, formatter: @escaping (Selection) -> [String?]) {
        
        // 1. Get all lines and selected text from buffer
        guard let lines = buffer.lines as? [String] else { return }
        guard let selections = buffer.selections as? [XCSourceTextRange] else { return }
        // if an addition operation occurs the number of added lines will be recorded.
        var documentOffset = 0
        // contains all replacement data for the selection plus the difference between the number of unformatted lines and formatted lines.
        var replacements = [(diff: Int, selected: Selection)]()
        
        // 2. For every selection create arrays of replacement data.
        // This loop implies that all selections should be treated individually when performing replacements.
        for selection in selections {
            // The selected text data prior to formatting.
            var unformatted = Selection()
            
            // A. Creating the unformatted selection array.
            for (index, r) in lines.getRanges(textRange: selection).enumerated() {
                let line = lines[selection.start.line+index]
                let selected = line[r]
                unformatted.append((selection.start.line+index, r, String(selected)))
            }
            
            // Empty formatted array, and 0 current value.
            var formatted = Selection()
            var current = 0
            let startLine = unformatted.first?.line
            
            // B. Format and append textData to formatted
            // if the current line count is greater than or equal the number of unformatted lines
            // then append new data for the line number and range.
            formatter(unformatted).forEach { (new: String?) in
                current < unformatted.count ?
                formatted.append((unformatted[current].line, unformatted[current].range, new!)):
                formatted.append((current+startLine!, new!.startIndex..<new!.endIndex , new!))
                current += 1
            }
            // append the selection replacement data to replacements.
            replacements.append((formatted.count - unformatted.count, formatted))
        }
        
        // 3. Update the buffer with the replacement data.
        //    Makes adjustments by adding or removing lines at
        //    required indices.
        replacements.forEach { (diff: Int, selected: Selection) in
            let lastSelection = selected.last!.line + documentOffset
            // A. Add or Subtract Lines.
            if diff > 0 {
                // insert additional blank lines to be overridden by the added lines.
                for _ in 0..<diff { buffer.lines.insert("", at: lastSelection-diff+1)}
            } else if diff < 0 {
                // removes lines at the given index.
                for _ in diff..<0 { buffer.lines.removeObject(at: lastSelection)}
            }
            var lastLine = 0
            // B. Perform Replacement of Lines.
            selected.forEach {
                lastLine = $0.line + documentOffset
                let oldLine = lines[lastLine]
                // use the segment from the start of the old line to the selection point
                // then add the new text to this segment.
                let newLine = oldLine[..<$0.range.lowerBound] + $0.text
                buffer.lines[lastLine] = newLine
            }
            // update the offset to account for changes.
            documentOffset += diff
        }
        
    }
}
