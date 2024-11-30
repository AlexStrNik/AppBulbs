//
//  main.swift
//  HappyNY2025
//
//  Created by Aleksandr Strizhnev on 30.11.2024.
//

import Foundation
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate
app.setActivationPolicy(.accessory)

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
