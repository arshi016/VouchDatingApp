import XCTest
@testable import Persistence

final class PersistenceTests: XCTestCase {
    func testCachePolicyPrefersCacheWhenConfigured() {
        XCTAssertTrue(CachePolicy.cacheFirst.shouldReadCacheFirst)
        XCTAssertTrue(CachePolicy.cacheOnly.shouldReadCacheFirst)
        XCTAssertFalse(CachePolicy.networkOnly.shouldReadCacheFirst)
    }
}
