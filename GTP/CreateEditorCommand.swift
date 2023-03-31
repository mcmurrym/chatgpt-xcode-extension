//
//  SourceEditorCommand.swift
//  GTP
//
//  Created by Matt McMurry on 3/19/23.
//

import Foundation
import XcodeKit
import AsyncHTTPClient
import OpenAIKit
import Rearrange

class CreateEditorCommand: NSObject, XCSourceEditorCommand {
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        let allLines = invocation.buffer.lines as! [String]
        let selections = invocation.buffer.selections as! [XCSourceTextRange]
        let singleSelection = selections[0]
        
        let lines = allLines[singleSelection.start.line...singleSelection.end.line]
        
        let firstLine = lines.first!
        let endPosition = min(firstLine.count, singleSelection.start.column + singleSelection.end.column - 1)
        let newFirstLine = firstLine[singleSelection.start.column..<endPosition]!

        doJob(request: String(newFirstLine), invocation: invocation, insertAt: singleSelection.end.line, completionHandler: completionHandler)
    }
    
    
    func doJob(request: String, invocation: XCSourceEditorCommandInvocation, insertAt: Int, completionHandler: @escaping (Error?) -> Void) {
        let keyController = KeyController()
        
        let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
        let configuration = Configuration(
            apiKey: keyController.apiKey,
            organization: keyController.organization
        )
        let openAIClient = OpenAIKit.Client(
            httpClient: httpClient,
            configuration: configuration
        )
        
        Task {
            do {
                let completion = try await openAIClient.chats.create(
                    model: Model.GPT3.gpt3_5Turbo0301,
                    messages: [.user(content: "in swift: \(request). Only return the code itself, do not return it in a code block, do not provide an explanation, do not provide an implementation detail, only provide the code requested")]
                )
                try await httpClient.shutdown()
                
                if let choice = completion.choices.first {
                    switch choice.message {
                    case .assistant(content: let result):
                        let lines = result.split(separator: "\n").map { String($0) }
                        let orginalLines = invocation.buffer.lines
                        
                        for (index, line) in lines.enumerated() {
                            orginalLines.insert(line, at: insertAt + 1 + index)
                        }
                        
                    default:
                        break
                    }
                    
                }
                
                completionHandler(nil)
            } catch {
                try? await httpClient.shutdown()
                print(error)
                completionHandler(nil)
            }
            
        }
    }
    
}
