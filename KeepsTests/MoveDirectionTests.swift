@testable import Keeps
import SwiftUI
import Testing

struct MoveDirectionTests {
    @Test("Arrow keys move in their direction")
    func arrowKeys() {
        #expect(MoveDirection(key: .leftArrow, characters: "") == .left)
        #expect(MoveDirection(key: .rightArrow, characters: "") == .right)
        #expect(MoveDirection(key: .upArrow, characters: "") == .up)
        #expect(MoveDirection(key: .downArrow, characters: "") == .down)
    }

    @Test("h, l, k, and j move left, right, up, and down")
    func viKeys() {
        #expect(MoveDirection(key: "h", characters: "h") == .left)
        #expect(MoveDirection(key: "l", characters: "l") == .right)
        #expect(MoveDirection(key: "k", characters: "k") == .up)
        #expect(MoveDirection(key: "j", characters: "j") == .down)
    }

    @Test("h, l, k, and j still move with Caps Lock on")
    func viKeysWithCapsLock() {
        #expect(MoveDirection(key: "j", characters: "J") == .down)
    }

    @Test("Other keys don't move")
    func otherKeys() {
        #expect(MoveDirection(key: "c", characters: "c") == nil)
    }

    @Test("Stepping through photos in order, left and up go back one, and right and down go forward one")
    func linearSteps() {
        #expect(MoveDirection.left.linearStep == -1)
        #expect(MoveDirection.up.linearStep == -1)
        #expect(MoveDirection.right.linearStep == 1)
        #expect(MoveDirection.down.linearStep == 1)
    }

    @Test("A letter with no modifiers is plain")
    func plainLetter() {
        #expect(isPlainLetter("c", characters: "c", modifiers: []))
    }

    @Test("A letter with Shift or Caps Lock is still plain")
    func letterWithShift() {
        #expect(isPlainLetter("c", characters: "C", modifiers: [.shift]))
        #expect(isPlainLetter("c", characters: "C", modifiers: [.capsLock]))
    }

    @Test("A letter with Command, Control, or Option isn't plain")
    func letterWithCommand() {
        #expect(!isPlainLetter("c", characters: "c", modifiers: [.command]))
        #expect(!isPlainLetter("c", characters: "c", modifiers: [.control]))
        #expect(!isPlainLetter("c", characters: "c", modifiers: [.option]))
    }

    @Test("A different letter isn't plain")
    func differentLetter() {
        #expect(!isPlainLetter("c", characters: "f", modifiers: []))
    }
}
