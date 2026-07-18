// HaloSync — Utilities/AsyncStream+Extensions.swift
// Ergonomic helpers for typed async stream pipelines.

import Foundation

extension AsyncStream {
    /// Creates a stream and a continuation in one call.
    /// Convenience wrapper matching AsyncThrowingStream.makeStream pattern.
    static func makeStream(
        of type: Element.Type = Element.self,
        bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy = .unbounded
    ) -> (stream: AsyncStream<Element>, continuation: AsyncStream<Element>.Continuation) {
        var continuation: AsyncStream<Element>.Continuation!
        let stream = AsyncStream(bufferingPolicy: bufferingPolicy) { cont in
            continuation = cont
        }
        return (stream, continuation)
    }
}

// MARK: - Throttle

extension AsyncSequence {
    /// Throttles the sequence to emit at most one element per interval.
    func throttle(for interval: Duration) -> AsyncThrottleSequence<Self> {
        AsyncThrottleSequence(base: self, interval: interval)
    }
}

/// An async sequence that throttles upstream emissions.
struct AsyncThrottleSequence<Base: AsyncSequence>: AsyncSequence {
    typealias Element = Base.Element

    let base: Base
    let interval: Duration

    struct AsyncIterator: AsyncIteratorProtocol {
        var iterator: Base.AsyncIterator
        let interval: Duration
        var lastEmit: ContinuousClock.Instant = .now - .seconds(999)

        mutating func next() async throws -> Element? {
            while let element = try await iterator.next() {
                let now = ContinuousClock.now
                if now - lastEmit >= interval {
                    lastEmit = now
                    return element
                }
            }
            return nil
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: base.makeAsyncIterator(), interval: interval)
    }
}
