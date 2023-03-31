//
//  ContentView.swift
//  GPTComplete
//
//  Created by Matt McMurry on 3/19/23.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject var keyController = KeyController()
    
    var body: some View {
        VStack {
            TextField("API Key", text: $keyController.apiKey)
            TextField("Organization", text: $keyController.organization)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
