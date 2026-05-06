//
//  LRUCache.swift
//  sd-smart-parking
//
//  Doubly-linked list + hash dictionary LRU cache. O(1) get and put,
//  deterministic least-recently-used eviction when count > capacity.
//
//  This is the canonical implementation taught in data-structures courses;
//  we hand-roll it instead of leaning on NSCache so the rubric defense can
//  point to explicit choices for capacity, eviction policy, and complexity.
//
//  Distinct from the other cache structures in the project:
//    - Core/SpotCacheManager.swift: NSCache (Juanes), implicit memory-pressure
//      eviction, no count guarantee.
//    - FileManagers/ArrayMap.swift: Mateo's parallel sorted arrays + binary
//      search, O(log n) lookups, no eviction at all.
//    - This LRUCache: hand-rolled doubly-linked list + Dictionary,
//      capacity-bounded, O(1) lookups + writes, MRU-on-touch.
//

import Foundation

final class LRUCache<Key: Hashable, Value> {

    private final class Node {
        let key: Key
        var value: Value
        var prev: Node?
        var next: Node?
        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }

    let capacity: Int
    private var nodes: [Key: Node] = [:]
    private var head: Node?  // MRU
    private var tail: Node?  // LRU

    init(capacity: Int) {
        precondition(capacity > 0, "LRUCache capacity must be > 0")
        self.capacity = capacity
    }

    var count: Int { nodes.count }

    func get(_ key: Key) -> Value? {
        guard let node = nodes[key] else { return nil }
        moveToFront(node)
        return node.value
    }

    func put(_ value: Value, for key: Key) {
        if let existing = nodes[key] {
            existing.value = value
            moveToFront(existing)
            return
        }
        let node = Node(key: key, value: value)
        nodes[key] = node
        addToFront(node)
        if nodes.count > capacity, let lru = tail {
            removeNode(lru)
            nodes.removeValue(forKey: lru.key)
        }
    }

    func clear() {
        nodes.removeAll()
        head = nil
        tail = nil
    }

    // MARK: - List operations

    private func addToFront(_ node: Node) {
        node.prev = nil
        node.next = head
        head?.prev = node
        head = node
        if tail == nil { tail = node }
    }

    private func removeNode(_ node: Node) {
        node.prev?.next = node.next
        node.next?.prev = node.prev
        if node === head { head = node.next }
        if node === tail { tail = node.prev }
        node.prev = nil
        node.next = nil
    }

    private func moveToFront(_ node: Node) {
        guard node !== head else { return }
        removeNode(node)
        addToFront(node)
    }
}
