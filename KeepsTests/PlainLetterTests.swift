@testable import Keeps
import SwiftUI
import Testing

struct PlainLetterTests {
    @Test("A letter with no modifiers is plain")
    func plainLetter() {
        #expect(isPlainLetter("c", characters: "c", modifiers: []))
    }

    @Test("A letter with Shift or Caps Lock is still plain", arguments: [EventModifiers.shift, .capsLock])
    func letterWithShift(modifier: EventModifiers) {
        #expect(isPlainLetter("c", characters: "C", modifiers: modifier))
    }

    @Test("A letter with Command, Control, or Option isn't plain", arguments: [EventModifiers.command, .control, .option])
    func letterWithCommand(modifier: EventModifiers) {
        #expect(!isPlainLetter("c", characters: "c", modifiers: modifier))
    }

    @Test("A different letter isn't plain")
    func differentLetter() {
        #expect(!isPlainLetter("c", characters: "f", modifiers: []))
    }
}
