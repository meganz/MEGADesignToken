import MEGADesignToken
import Testing

struct MEGADesignTokenTests {
    @Test func testTokens() {
        #expect(TokenSpacing._1 == 2)
        #expect(TokenRadius.large == 16)
    }
}
