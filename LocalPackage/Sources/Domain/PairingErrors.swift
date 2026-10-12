//
//  PairingErrors.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/12
//

import Foundation

public enum PairingEstablishmentError: Error, Equatable {
    case alreadyPaired
}

public enum NamingError: Error, Equatable {
    case notPaired
    case blankName
}
