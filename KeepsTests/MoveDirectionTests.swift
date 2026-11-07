@testable import Keeps
import SwiftUI
import Testing

struct MoveDirectionTests {
    @Test(
        "Arrow keys move in their direction",
        arguments: [
            (key: KeyEquivalent.leftArrow, direction: MoveDirection.left),
            (key: .rightArrow, direction: .right),
            (key: .upArrow, direction: .up),
            (key: .downArrow, direction: .down),
        ]
    )
    func arrowKeys(key: KeyEquivalent, direction: MoveDirection) {
        #expect(MoveDirection(key: key, characters: "") == direction)
    }

    @Test(
        "h, l, k, and j move left, right, up, and down",
        arguments: [
            (letter: Character("h"), direction: MoveDirection.left),
            (letter: "l", direction: .right),
            (letter: "k", direction: .up),
            (letter: "j", direction: .down),
        ]
    )
    func viKeys(letter: Character, direction: MoveDirection) {
        #expect(MoveDirection(key: KeyEquivalent(letter), characters: String(letter)) == direction)
    }

    @Test("h, l, k, and j still move with Caps Lock on")
    func viKeysWithCapsLock() {
        #expect(MoveDirection(key: "j", characters: "J") == .down)
    }

    @Test("Other keys don't move")
    func otherKeys() {
        #expect(MoveDirection(key: "c", characters: "c") == nil)
    }

    @Test(
        "Stepping through photos in order, left and up go back one, and right and down go forward one",
        arguments: [
            (direction: MoveDirection.left, step: -1),
            (direction: .up, step: -1),
            (direction: .right, step: 1),
            (direction: .down, step: 1),
        ]
    )
    func linearSteps(direction: MoveDirection, step: Int) {
        #expect(direction.linearStep == step)
    }

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
