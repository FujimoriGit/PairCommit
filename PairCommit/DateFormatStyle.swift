//
//  DateFormatStyle.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/06
//

import Foundation

extension Date.FormatStyle {
    static var monthDay: Self { .dateTime.month().day() }
    static var yearMonthDay: Self { .dateTime.year().month().day() }
}
