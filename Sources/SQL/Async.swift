//
//  Async.swift
//  SQL
//
//  Created by Yuki Takei on 5/4/16.
//
//

typealias AsyncSeriesCallback = ((Void throws -> Void) -> Void) -> Void

struct Async {
    static func series(tasksFor tasks: [AsyncSeriesCallback], completion: (Void throws -> Void) -> Void) {
        var index = 0
        func _series(_ current: AsyncSeriesCallback) {
            current {
                do {
                    try $0()
                    index += 1
                    index < tasks.count ? _series(tasks[index]) : completion {}
                } catch {
                    completion {
                        throw error
                    }
                }
            }
        }
        _series(tasks[index])
    }
}
