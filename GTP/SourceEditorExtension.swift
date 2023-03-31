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
        let marker = CreateEditorCommand.className()
        return [[.identifierKey: namespace + marker,
                 .classNameKey: marker,
                 .nameKey: NSLocalizedString("Create From Selected Text",
                                             comment: "creates swift code from descritption")]]
    }
    
    
}
