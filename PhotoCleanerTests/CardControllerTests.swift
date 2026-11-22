import Foundation
import Testing
@testable import PhotoCleaner

@Suite("CardController commit rule")
struct CardDecisionRuleTests {
    private let card = CGSize(width: 340, height: 560)

    private func decide(_ t: CGSize, _ predicted: CGSize) -> DecisionAction? {
        CardController.decision(translation: t, predictedEnd: predicted, cardSize: card)
    }

    @Test func commitsAtTheHorizontalThreshold() {
        #expect(decide(CGSize(width: 110, height: 0), CGSize(width: 110, height: 0)) == .keep)
        #expect(decide(CGSize(width: -110, height: 0), CGSize(width: -110, height: 0)) == .trash)
        #expect(decide(CGSize(width: 109, height: 0), CGSize(width: 109, height: 0)) == nil)
    }

    @Test func commitsOnPredictedEndPastThirtyFivePercentOfTheWidth() {
        #expect(decide(CGSize(width: 40, height: 0), CGSize(width: 118, height: 0)) == nil)      // 0.35 * 340 = 119
        #expect(decide(CGSize(width: 40, height: 0), CGSize(width: 119.5, height: 0)) == .keep)   // just past
        #expect(decide(CGSize(width: -40, height: 0), CGSize(width: -200, height: 0)) == .trash)
    }

    @Test func upCommitsAtOneTwentyOrWhenThePredictedEndPassesThirtyPercentOfTheHeight() {
        #expect(decide(CGSize(width: 0, height: -120), CGSize(width: 0, height: -120)) == .favorite)
        #expect(decide(CGSize(width: 0, height: -60), CGSize(width: 0, height: -167)) == nil)     // 0.30 * 560 = 168
        #expect(decide(CGSize(width: 0, height: -60), CGSize(width: 0, height: -169)) == .favorite)
    }

    @Test func downwardDragNeverCommits() {
        #expect(decide(CGSize(width: 0, height: 80), CGSize(width: 0, height: 400)) == nil)
    }

    /// Finding 5: the card is on the right (KEEP stamp showing) and is flicked back to the left.
    /// The stamp on screen must win: past the threshold it is still KEEP, below it the flick
    /// that opposes the card's side cancels instead of committing the other way.
    @Test func aFlickOpposingTheCardsSideNeverCommitsTheOtherWay() {
        #expect(decide(CGSize(width: 130, height: 0), CGSize(width: -200, height: 0)) == .keep)
        #expect(decide(CGSize(width: -130, height: 0), CGSize(width: 200, height: 0)) == .trash)
        #expect(decide(CGSize(width: 60, height: 0), CGSize(width: -200, height: 0)) == nil)
        #expect(decide(CGSize(width: -60, height: 0), CGSize(width: 200, height: 0)) == nil)
    }

    @Test func aDragWithNoHorizontalTravelFollowsThePredictedSide() {
        #expect(decide(CGSize(width: 0, height: 10), CGSize(width: 200, height: 0)) == .keep)
        #expect(decide(CGSize(width: 0, height: 10), CGSize(width: -200, height: 0)) == .trash)
        #expect(decide(CGSize(width: 0, height: 10), CGSize(width: 0, height: 0)) == nil)
    }
}

@Suite("CardController interruptions")
@MainActor
struct CardControllerInterruptionTests {
    private func make(count: Int = 6) async -> (CardController, SwipeSession) {
        let f = await Fixture.make(count: count)
        let controller = CardController(session: f.session)
        controller.cardSize = CGSize(width: 340, height: 560)
        return (controller, f.session)
    }

    /// Three taps issued back to back, with no time for any head start to run out, advance three cards.
    @Test func rapidPerformsAreNeverDropped() async {
        let (c, session) = await make()
        c.perform(.keep)
        c.perform(.keep)
        c.perform(.keep)
        // The third is still in its head start; it has not been applied yet.
        #expect(session.remainingCount == 4)
        try? await Task.sleep(for: .milliseconds(200))
        #expect(session.remainingCount == 3)
        #expect(session.history.count == 3)
        #expect(!c.isBusy)
    }

    @Test func undoDuringTheHeadStartLaunchesAndThenRestoresTheSameCard() async {
        let (c, session) = await make()
        let first = session.current?.id
        c.perform(.keep)
        #expect(session.current?.id == first)         // not applied yet
        c.undo()                                      // launches, then undoes it
        #expect(session.current?.id == first)
        #expect(session.remainingCount == 6)
        #expect(session.history.isEmpty)
        #expect(c.leavers.isEmpty)
        try? await Task.sleep(for: .milliseconds(200))
        #expect(session.remainingCount == 6)          // the cancelled head-start task did nothing late
    }

    @Test func undoDuringFlyOffRestoresTheFlyingCardAndLeavesNoGhost() async {
        let (c, session) = await make()
        let first = session.current?.id
        c.perform(.keep)
        try? await Task.sleep(for: .milliseconds(120))   // head start over: the card is flying
        #expect(session.current?.id != first)
        c.undo()
        #expect(c.leavers.isEmpty)
        #expect(session.current?.id == first)
        #expect(session.remainingCount == 6)
    }

    @Test func aNewDecisionDuringFlyOffIsAppliedAtOnce() async {
        let (c, session) = await make()
        c.perform(.keep)
        try? await Task.sleep(for: .milliseconds(120))
        c.perform(.trash)
        try? await Task.sleep(for: .milliseconds(120))
        #expect(session.remainingCount == 4)
        #expect(session.pendingTrash.count == 1)
    }

    @Test func theLastCardLeavesAsALeaverAndNeverCrashes() async {
        let (c, session) = await make(count: 1)
        c.perform(.keep)
        try? await Task.sleep(for: .milliseconds(120))
        #expect(session.current == nil)
        c.perform(.keep)                                  // nothing to decide: ignored
        c.undo()
        #expect(session.current != nil)
        #expect(c.leavers.isEmpty)
    }

    @Test func buttonsAreIgnoredWhileTheFingerIsDragging() async {
        let (c, session) = await make()
        c.dragChanged(CGSize(width: 50, height: 0))
        c.perform(.keep)
        #expect(session.remainingCount == 6)
        c.cancelDragIfNeeded()
        #expect(!c.isDragging)
    }
}

@Suite("Celebration hero line")
struct CelebrationHeroTests {
    /// The number, its unit and the "!" can never be split by a line break.
    @Test func theHeroLineHasNoBreakingSpaceAndKeepsTheBangGlued() {
        for bytes: Int64 in [33_500_000, 1_240_000_000, 1_000_000] {
            let parts = CelebrationView.heroParts(bytes: bytes)
            #expect(!parts.hero.contains(" "), "hero must not contain a breaking space: \(parts.hero)")
            #expect(parts.hero.contains("\u{2060}!"), "the word joiner must sit before the bang: \(parts.hero)")
            #expect(!parts.lead.isEmpty)
            #expect(!parts.lead.contains("!"))
        }
    }
}
