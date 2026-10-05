//
//  DateFormatStyle.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/06
//

import Foundation

extension Date.FormatStyle {
    static var monthDayTime: Self { .dateTime.month().day().hour().minute() }
    static var yearMonthDay: Self { .dateTime.year().month().day() }
    static var yearMonthDayTime: Self { .dateTime.year().month().day().hour().minute() }
}
