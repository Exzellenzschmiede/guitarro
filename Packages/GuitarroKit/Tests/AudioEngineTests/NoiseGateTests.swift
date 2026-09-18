import Testing
@testable import AudioEngine

@Suite struct NoiseGateTests {
    @Test func quietNoteAboveTheFloorOpensTheGate() {
        var gate = NoiseGate()
        for _ in 0..<50 { _ = gate.process(rms: 0.0004) }
        let quiet = gate.process(rms: 0.0004)
        let note = gate.process(rms: 0.002)
        #expect(!quiet)
        #expect(note)
    }

    @Test func floorFollowsALouderRoom() {
        var gate = NoiseGate()
        for _ in 0..<1500 { _ = gate.process(rms: 0.01) }
        #expect(gate.floor > 0.005)
        let slightlyLouder = gate.process(rms: 0.012)
        let note = gate.process(rms: 0.05)
        #expect(!slightlyLouder)
        #expect(note)
        for _ in 0..<50 { _ = gate.process(rms: 0.0003) }
        #expect(gate.floor < 0.001)
    }

    @Test func aHeldNoteStaysOpenForSeconds() {
        var gate = NoiseGate()
        for _ in 0..<50 { _ = gate.process(rms: 0.0005) }
        var openFrames = 0
        for _ in 0..<235 where gate.process(rms: 0.02) { openFrames += 1 }
        #expect(openFrames == 235)
    }
}
