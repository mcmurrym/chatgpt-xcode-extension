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

class GPTInstructionCommand: NSObject, XCSourceEditorCommand {

    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void) {
        let gptInstructions = Array(extractGPTInstructions(from: invocation).reversed())
        
        Task {
            do {
                let processed = try await processGPTInstructions(gptInstructions)
                let responses = try await chatGPTRequests(requests: processed)
                insertResponses(into: invocation, responses: responses)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
    
    struct GPTInstruction {
        let lines: [String]
        let lastIndex: Int
        let referenceDocURL: URL?
    }

    @available(iOS 15.0, macOS 12.0, *)
    func extractGPTInstructions(from invocation: XCSourceEditorCommandInvocation) -> [GPTInstruction] {
        var instructions: [GPTInstruction] = []
        var currentInstructionLines: [String] = []
        var insideInstruction = false
        var referenceDocURL: URL? = nil

        for lineIndex in 0..<invocation.buffer.lines.count {
            let line = invocation.buffer.lines[lineIndex] as! String

            if line.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("///GPT") {
                insideInstruction = true
                currentInstructionLines.append(line)
            } else if insideInstruction && line.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("///") {
                currentInstructionLines.append(line)
                
                if let match = line.range(of: "- Reference Doc:", options: .caseInsensitive) {
                    let urlStartIndex = match.upperBound
                    let urlString = line[urlStartIndex...].trimmingCharacters(in: .whitespaces)
                    referenceDocURL = URL(string: urlString)
                }
            } else {
                if insideInstruction {
                    instructions.append(GPTInstruction(
                        lines: currentInstructionLines,
                        lastIndex: lineIndex,
                        referenceDocURL: referenceDocURL
                    ))
                    currentInstructionLines.removeAll()
                    referenceDocURL = nil
                    insideInstruction = false
                }
            }
        }

        // Add the last instruction, if it exists
        if insideInstruction {
            instructions.append(GPTInstruction(
                lines: currentInstructionLines,
                lastIndex: invocation.buffer.lines.count - 1,
                referenceDocURL: referenceDocURL
            ))
        }

        return instructions
    }

    struct GPTRequest {
        let text: String
        let lastIndex: Int
    }

    @available(iOS 15.0, macOS 12.0, *)
    func processGPTInstructions(_ instructions: [GPTInstruction]) async throws -> [GPTRequest] {
        var processedRequests: [GPTRequest] = []

        for instruction in instructions {
            var instructionText = instruction.lines.joined(separator: "\n")

            if let referenceDocURL = instruction.referenceDocURL {
                do {
                    let contents = try await downloadAndCleanHTML(from: referenceDocURL)
                    instructionText += "\nThis is the contents of the Reference Doc URL: \(contents)"
                } catch {
                    print("Error downloading and cleaning HTML: \(error)")
                }
            }

            let request = GPTRequest(text: instructionText, lastIndex: instruction.lastIndex)
            processedRequests.append(request)
        }

        return processedRequests
    }

    

    enum DownloadAndCleanHTMLError: Error {
        case decodingError
    }

    @available(iOS 15.0, macOS 12.0, *)
    func downloadAndCleanHTML(from url: URL) async throws -> String {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let rawHTML = String(data: data, encoding: .utf8) else {
            throw DownloadAndCleanHTMLError.decodingError
        }
        
        let scriptTagPattern = "<script[^>]*>.*?</script>"
        let htmlTagPattern = "<[^>]+>"
        
        let regexOptions: NSRegularExpression.Options = [.dotMatchesLineSeparators, .caseInsensitive]
        let scriptTagRegex = try NSRegularExpression(pattern: scriptTagPattern, options: regexOptions)
        let htmlTagRegex = try NSRegularExpression(pattern: htmlTagPattern, options: .caseInsensitive)
        
        let withoutScriptTags = scriptTagRegex.stringByReplacingMatches(in: rawHTML, options: [], range: NSRange(location: 0, length: rawHTML.count), withTemplate: "")
        let withoutHTMLTags = htmlTagRegex.stringByReplacingMatches(in: withoutScriptTags, options: [], range: NSRange(location: 0, length: withoutScriptTags.count), withTemplate: "")
        
        return withoutHTMLTags
    }



    struct GPTResponse {
        let responseLines: [String]
        let insertIndex: Int
    }
    
    enum ChatGPTResponseError: Error {
        case missingChat
        case missingAssistantMessage
    }
    
    func chatGPTRequests(requests: [GPTRequest]) async throws -> [GPTResponse] {
        var responses: [GPTResponse] = []
        
        for request in requests {
            let response = try await chatGPTRequest(request: request)
            responses.append(response)
        }
        
        return responses
    }
    
    func chatGPTRequest(request: GPTRequest) async throws -> GPTResponse {
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
        
        do {
            let completion = try await openAIClient.chats.create(
                model: Model.GPT3.gpt3_5Turbo0301,
                messages: [.user(content: "This is a swift documentation: \(request.text). Use it to generate the appropriate swift code implementation. Only return the code itself, do not return it in a code block, do not provide an explanation, do not include an opening and closing ```, do not provide an implementation detail, only provide the code requested")]
            )
            try await httpClient.shutdown()
            
            if let choice = completion.choices.first {
                switch choice.message {
                case .assistant(content: let result):
                    print(result)
                    let lines = result.split(separator: "\n").map { String($0) }
                    return GPTResponse(responseLines: lines, insertIndex: request.lastIndex)
                default:
                    throw ChatGPTResponseError.missingAssistantMessage
                }
                
            } else {
                throw ChatGPTResponseError.missingChat
            }
        } catch {
            try await httpClient.shutdown()
            throw error
        }
    }
    
    func insertResponses(into invocation: XCSourceEditorCommandInvocation, responses: [GPTResponse]) {
        let array = invocation.buffer.lines
        for response in responses {
            let insertIndex = response.insertIndex
            for (index, line) in response.responseLines.enumerated() {
                array.insert(line, at: insertIndex + index + 1)
            }
        }
    }
    
}
