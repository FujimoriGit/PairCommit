//
//  NoteWritingError.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/12
//

import Foundation

public enum NoteWritingError: Error, Equatable {
    case blankBody
    case subjectNotFound
    case subjectClosed
}
