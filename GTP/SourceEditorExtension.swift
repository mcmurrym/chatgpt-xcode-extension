//
//  SourceEditorExtension.swift
//  GTP
//
//  Created by Matt McMurry on 3/19/23.
//

import Foundation
import XcodeKit

class SourceEditorExtension: NSObject, XCSourceEditorExtension {
    func extensionDidFinishLaunching() { }
    
    var commandDefinitions: [[XCSourceEditorCommandDefinitionKey: Any]] {
        let namespace = Bundle(for: type(of: self)).bundleIdentifier!
        let createEditorCommand = CreateEditorCommand.className()
        let GPTInstructionCommand = GPTInstructionCommand.className()
        return [
            [
                .identifierKey: namespace + createEditorCommand,
                .classNameKey: createEditorCommand,
                .nameKey: NSLocalizedString("Create From Selected Text", comment: "creates swift code from selection")
            ],
            [
                .identifierKey: namespace + GPTInstructionCommand,
                .classNameKey: GPTInstructionCommand,
                .nameKey: NSLocalizedString("Create From GPT Instruction", comment: "creates swift code from descritption")
            ]
        ]
    }
    
    
}
