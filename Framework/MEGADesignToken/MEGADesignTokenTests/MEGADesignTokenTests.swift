//
//  MEGADesignTokenTests.swift
//  MEGADesignTokenTests
//
//  Created by Mega-bl on 25/11/25.
//

import Testing
import MEGADesignToken
import CoreFoundation
import UIKit

struct MEGADesignTokenTests {

    @Test func testTokens() async throws {
        #expect(TokenSpacing._1 == 2)
        #expect(TokenRadius.large == 16)
    }

}
