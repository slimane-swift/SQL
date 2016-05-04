// Connection.swift
//
// The MIT License (MIT)
//
// Copyright (c) 2015 Formbound
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

@_exported import URI
@_exported import Log

public protocol ConnectionInfoProtocol: StringLiteralConvertible {
    var host: String { get }
    var port: Int { get }
    var databaseName: String { get }
    var username: String? { get }
    var password: String? { get }
    
    init(_ uri: URI) throws
}

public extension ConnectionInfoProtocol {
    public init(stringLiteral value: String) {
        try! self.init(URI(value))
    }
    
    public init(unicodeScalarLiteral value: String) {
        self.init(stringLiteral: value)
    }
    
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(stringLiteral: value)
    }
}

public protocol AsyncConnectionProtocol: class {
    associatedtype InternalStatus
    associatedtype Result: ResultProtocol
    associatedtype Error: ErrorProtocol
    associatedtype ConnectionInfo: ConnectionInfoProtocol
    
    var logger: Logger? { get set }
    
    var connectionInfo: ConnectionInfo { get }

    func open(_ completion: (Void throws -> Void) -> Void)

    func close()

    var internalStatus: InternalStatus { get }

    func execute(_ statement: QueryComponents, completion: (Void throws -> Result) -> Void)

    func begin(_ completion: (Void throws -> Void) -> Void)

    func commit(_ completion: (Void throws -> Void) -> Void)

    func rollback(_ completion: (Void throws -> Void) -> Void)

    func createSavePointNamed(_ name: String) throws

    func releaseSavePointNamed(_ name: String) throws

    func rollbackToSavePointNamed(_ name: String) throws

    init(_ info: ConnectionInfo)
    
    var mostRecentError: Error? { get }
    
    func executeInsertQuery<T: SQLDataConvertible>(query: InsertQuery, returningPrimaryKeyForField primaryKey: DeclaredField, completion: (Void throws -> T) -> Void)
}

public extension AsyncConnectionProtocol {
    
    public init(_ uri: URI) throws {
        try self.init(ConnectionInfo(uri))
    }

    public func transaction(block: (Void throws -> Void) -> Void, completion: (Void throws -> Void) -> Void) {
        begin {
            do {
                try $0()
                block {
                    self.commit {
                        do {
                            try $0()
                            completion {}
                        } catch {
                            self.rollback(completion)
                        }
                    }
                }
            } catch {
                self.rollback(completion)
            }

        }
    }

    public func withSavePointNamed(_ name: String, block: Void throws -> Void) throws {
        try createSavePointNamed(name)

        do {
            try block()
            try releaseSavePointNamed(name)
        }
        catch {
            try rollbackToSavePointNamed(name)
            try releaseSavePointNamed(name)
            throw error
        }
    }
    
//    public func execute(_ statement: QueryComponents) throws -> Result {¥
//        return try execute(statement)
//    }
    
    public func execute(_ statement: String, parameters: [SQLDataConvertible?] = [], completion: (Void throws -> Result) -> Void) {
        execute(QueryComponents(statement, values: parameters.map { $0?.sqlData })) { f in
            completion {
                try f()
            }
        }
    }
    
//    public func execute(_ statement: String, parameters: SQLDataConvertible?..., completion: (Void throws -> Result) -> Void)  {
//        execute(statement, parameters: parameters) { f in
//            completion {
//                try f()
//            }
//        }
//    }

    public func execute(_ convertible: QueryComponentsConvertible, completion: (Void throws -> Result) -> Void) {
        execute(convertible.queryComponents) { f in
            completion {
                try f()
            }
        }
    }

    public func begin(_ completion: (Void throws -> Void) -> Void) {
        execute("BEGIN") { f in
            completion {
                try f()
            }
        }
    }

    public func commit(_ completion: (Void throws -> Void) -> Void) {
        execute("COMMIT") { f in
            completion {
                try f()
            }
        }
    }

    public func rollback(_ completion: (Void throws -> Void) -> Void) {
        execute("ROLLBACK") { f in
            completion {
                try f()
            }
        }
    }
}
