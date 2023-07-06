//
//  SingleRecord.swift
//  Bumblebee
//
//  Created by sugarbaron on 23.04.2023.
//

import Foundation
import Combine
import Bumblebee

// MARK: constructor
@available(iOS 15.0, *)
@dynamicMemberLookup
public final class SingleRecord<CoreDataRecordFields:CoreDataRecord>
where CoreDataRecordFields.DataClass : SingleRecordFields {
    
    private let storage: CoreDataStorage.Engine
    private var cache: RecordFields
    private let cacheAccess: NSRecursiveLock
    private let downstream: CurrentValueSubject<RecordFields, Never>
    
    public init?(xcdatamodel fileName: String) async {
        guard let storage: CoreDataStorage.Engine = .init(xcdatamodel: fileName) else { return nil }
        
        self.storage = storage
        self.cache = await storage.load(single: CoreDataRecordFields.self)
        self.cacheAccess = NSRecursiveLock()
        self.downstream = CurrentValueSubject<RecordFields, Never>(cache)
        downstream.send(cache)
    }
    
}

@available(iOS 15.0, *)
public protocol SingleRecordFields {
    
    static var empty: Self { get }
    
}

// MARK: interface
@available(iOS 15.0, *)
public extension SingleRecord {
    
    subscript<T>(dynamicMember field: KeyPath<RecordFields, T>) -> T { readCache(field) }
    
    subscript<T>(dynamicMember field: WritableKeyPath<RecordFields, T>) -> T {
        get { readCache(field) }
        set { update(field, with: newValue) }
    }
    
    func keepInformed<T:Equatable>(about field: KeyPath<RecordFields, T>) -> AnyPublisher<T, Never> {
        downstream
            .compactMap { $0[keyPath: field] }
            .removeDuplicates { new, old in new == old }
            .anyPublisher
    }
    
    func keepInformed<T>(about field: KeyPath<RecordFields, T>, skip: @escaping (T, T) -> Bool)
    -> AnyPublisher<T, Never> {
        downstream.compactMap { $0[keyPath: field] }
            .removeDuplicates { skip($0, $1) }
            .anyPublisher
    }
    
    func erase() {
        cacheAccess.lock()
        cache = .empty
        cacheAccess.unlock()
        downstream.send(.empty)
        storage.background.update(single: CoreDataRecordFields.self, with: .empty)
    }
    
    typealias RecordFields = CoreDataRecordFields.DataClass
    
}

// MARK: tools
@available(iOS 15.0, *)
private extension SingleRecord {
    
    func readCache<T>(_ fieldKey: KeyPath<RecordFields, T>) -> T {
        cacheAccess.lock()
        let field: T = cache[keyPath: fieldKey]
        cacheAccess.unlock()
        return field
    }
    
    func update<T>(_ field: WritableKeyPath<RecordFields, T>, with new: T) {
        let updated: RecordFields = updateCache(field, with: new)
        downstream.send(updated)
        storage.background.update(single: CoreDataRecordFields.self, with: updated)
    }
    
    func updateCache<T>(_ field: WritableKeyPath<RecordFields, T>, with new: T) -> RecordFields {
        cacheAccess.lock()
        cache[keyPath: field] = new
        let updated: RecordFields = cache
        cacheAccess.unlock()
        return updated
    }
    
}

@available(iOS 15.0, *)
private extension CoreDataStorage.Engine {
    
    func load<R:CoreDataRecord>(single recordType: R.Type) async -> R.DataClass where R.DataClass : SingleRecordFields {
        await read { $0.loadAll(R.self).first } ?? .empty
    }
    
}

@available(iOS 15.0, *)
private extension CoreDataStorage.BackgroundEngine {
    
    func update<R:CoreDataRecord>(single record: R.Type, with original: R.DataClass) {
        write {
            $0.delete(all: R.self)
            $0.create(new: original, as: R.self)
        } catch: {
            log(error: "[SingleRecord] update(single:) error: \($0)")
        }
    }
    
}
