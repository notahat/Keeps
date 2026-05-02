import Foundation
@testable import Keeps
import Testing

struct SelectionTests {
    @Test func selectItemSetsSelectionAndCollapsesPreviousRange() throws {
        let library = try makeLibrary(photoCount: 5)

        library.selectItem(at: 2)

        #expect(library.selectedIndex == 2)
        #expect(library.selectionRange == 2 ... 2)
    }

    @Test func extendSelectionForwardFromAnchor() throws {
        let library = try makeLibrary(photoCount: 5)

        library.selectItem(at: 1)
        library.extendSelection(to: 3)

        #expect(library.selectedIndex == 3)
        #expect(library.selectionRange == 1 ... 3)
    }

    @Test func extendSelectionBackwardFromAnchor() throws {
        let library = try makeLibrary(photoCount: 5)

        library.selectItem(at: 3)
        library.extendSelection(to: 1)

        #expect(library.selectedIndex == 1)
        #expect(library.selectionRange == 1 ... 3)
    }

    @Test func extendSelectionUsesCurrentSelectionAsAnchorWhenNoneSet() throws {
        let library = try makeLibrary(photoCount: 5)
        library.selectedIndex = 2

        library.extendSelection(to: 4)

        #expect(library.selectionRange == 2 ... 4)
    }

    @Test func selectItemClearsExistingRange() throws {
        let library = try makeLibrary(photoCount: 5)

        library.selectItem(at: 1)
        library.extendSelection(to: 4)
        library.selectItem(at: 2)

        #expect(library.selectionRange == 2 ... 2)
    }

    @Test func selectionRangeIsNilWithNoSelection() throws {
        let library = try makeLibrary(photoCount: 5)
        library.selectedIndex = nil

        #expect(library.selectionRange == nil)
    }

    @Test func selectionRangeIsNilBeforeAnySelectItemCall() throws {
        let library = try makeLibrary(photoCount: 5)
        library.selectedIndex = 2

        #expect(library.selectionRange == nil)
    }

    @Test func applyMarkAndAdvanceClearsRange() throws {
        let library = try makeLibrary(photoCount: 5)

        library.selectItem(at: 1)
        library.extendSelection(to: 3)
        library.applyMarkAndAdvance(.pick)

        #expect(library.selectionRange == library.selectedIndex.map { $0 ... $0 })
    }

    @Test func applyFilterClearsRange() throws {
        let library = try makeLibrary(photoCount: 5)

        library.selectItem(at: 1)
        library.extendSelection(to: 3)
        library.applyFilter(.all)

        #expect(library.selectionRange == nil)
    }
}
