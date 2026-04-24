package com.pianomisspass.pianomisspass_fe

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.sqrt

class ExpectedChordVerifier(
    private val groupingWindowMs: Long = 130L,
    private val minimumGroupedFrames: Int = 2,
    private val rmsGate: Double = 0.007,
    private val absoluteScoreThreshold: Double = 0.12,
    private val relativeScoreThreshold: Double = 0.58,
    private val peakRatioThreshold: Double = 1.16,
) {
    data class DetectionResult(
        val detectedMidis: Set<Int>,
        val rms: Double,
        val expectedMidis: Set<Int>,
        val scoresByMidi: Map<Int, Double>,
        val maxScore: Double,
    )

    private data class FrameEvidence(
        val midis: Set<Int>,
        val timestampMs: Long,
    )

    private val recentEvidence = ArrayDeque<FrameEvidence>()
    private var expectedMidis: Set<Int> = emptySet()

    fun updateExpectedMidis(midis: Collection<Int>) {
        expectedMidis = midis.toSet()
        recentEvidence.removeAll { frame ->
            frame.midis.none { midi -> midi in expectedMidis }
        }
    }

    fun reset() {
        recentEvidence.clear()
    }

    fun acceptFrame(
        floatBuffer: FloatArray,
        sampleRate: Int,
        timestampMs: Long,
    ): DetectionResult {
        prune(timestampMs)

        if (expectedMidis.isEmpty() || floatBuffer.isEmpty()) {
            return DetectionResult(
                detectedMidis = emptySet(),
                rms = 0.0,
                expectedMidis = expectedMidis,
                scoresByMidi = emptyMap(),
                maxScore = 0.0,
            )
        }

        val isChord = expectedMidis.size > 1
        val resolvedRmsGate = if (isChord) 0.0085 else rmsGate
        val resolvedAbsoluteThreshold = if (isChord) 0.135 else absoluteScoreThreshold
        val resolvedRelativeThreshold = if (isChord) 0.68 else relativeScoreThreshold
        val resolvedPeakRatioThreshold = if (isChord) 1.20 else peakRatioThreshold
        val requiredFrames = if (isChord) 3 else minimumGroupedFrames

        val rms = calculateRms(floatBuffer)
        if (rms < resolvedRmsGate) {
            return DetectionResult(
                detectedMidis = emptySet(),
                rms = rms,
                expectedMidis = expectedMidis,
                scoresByMidi = emptyMap(),
                maxScore = 0.0,
            )
        }

        val scoredMidis = expectedMidis.associateWith { midi ->
            scoreExpectedMidi(
                floatBuffer = floatBuffer,
                sampleRate = sampleRate,
                expectedMidi = midi,
                rms = rms,
                peakRatioThreshold = resolvedPeakRatioThreshold,
                isChord = isChord,
            )
        }
        val maxScore = scoredMidis.values.maxOrNull() ?: 0.0
        if (maxScore < resolvedAbsoluteThreshold) {
            return DetectionResult(
                detectedMidis = emptySet(),
                rms = rms,
                expectedMidis = expectedMidis,
                scoresByMidi = scoredMidis,
                maxScore = maxScore,
            )
        }

        val frameMidis = scoredMidis
            .filter { (_, score) ->
                score >= resolvedAbsoluteThreshold &&
                    score >= maxScore * resolvedRelativeThreshold
            }
            .keys
            .toSet()

        if (frameMidis.isNotEmpty()) {
            recentEvidence.addLast(FrameEvidence(frameMidis, timestampMs))
            prune(timestampMs)
        }

        return DetectionResult(
            detectedMidis = if (frameMidis.isEmpty()) emptySet() else groupedMidis(requiredFrames),
            rms = rms,
            expectedMidis = expectedMidis,
            scoresByMidi = scoredMidis,
            maxScore = maxScore,
        )
    }

    private fun groupedMidis(requiredFrames: Int): Set<Int> {
        if (recentEvidence.size < requiredFrames) {
            return emptySet()
        }

        val counts = mutableMapOf<Int, Int>()
        for (frame in recentEvidence) {
            for (midi in frame.midis) {
                counts[midi] = (counts[midi] ?: 0) + 1
            }
        }

        return counts
            .filter { (_, count) -> count >= requiredFrames }
            .keys
            .toSet()
    }

    private fun scoreExpectedMidi(
        floatBuffer: FloatArray,
        sampleRate: Int,
        expectedMidi: Int,
        rms: Double,
        peakRatioThreshold: Double,
        isChord: Boolean,
    ): Double {
        val octaveCandidates = buildPitchClassOctaveCandidates(expectedMidi)
        var score = 0.0
        var bestBaseScore = 0.0

        for ((candidateMidi, weight) in octaveCandidates) {
            val baseFrequency = midiToFrequency(candidateMidi)
            if (baseFrequency >= sampleRate / 2.0) {
                continue
            }

            val fundamentalScore = peakedScore(
                floatBuffer = floatBuffer,
                sampleRate = sampleRate,
                frequencyHz = baseFrequency,
                rms = rms,
                peakRatioThreshold = peakRatioThreshold,
            )
            val harmonic2 = peakedScore(
                floatBuffer = floatBuffer,
                sampleRate = sampleRate,
                frequencyHz = baseFrequency * 2.0,
                rms = rms,
                peakRatioThreshold = peakRatioThreshold * 0.96,
            ) * if (isChord) 0.34 else 0.24
            val harmonic3 = peakedScore(
                floatBuffer = floatBuffer,
                sampleRate = sampleRate,
                frequencyHz = baseFrequency * 3.0,
                rms = rms,
                peakRatioThreshold = peakRatioThreshold * 0.93,
            ) * if (isChord) 0.18 else 0.12

            val candidateScore = max(
                fundamentalScore,
                fundamentalScore * if (isChord) 0.72 else 0.82 +
                    harmonic2 +
                    harmonic3,
            )
            bestBaseScore = max(bestBaseScore, fundamentalScore)
            score += candidateScore * weight
        }

        if (bestBaseScore <= 0.0) {
            return 0.0
        }

        return score
    }

    private fun buildPitchClassOctaveCandidates(expectedMidi: Int): List<Pair<Int, Double>> {
        val candidates = mutableListOf<Pair<Int, Double>>()
        val octaveOffsets = listOf(0 to 1.0, -12 to 0.32, 12 to 0.32, -24 to 0.10, 24 to 0.10)
        for ((offset, weight) in octaveOffsets) {
            val midi = expectedMidi + offset
            if (midi in MIN_PIANO_MIDI..MAX_PIANO_MIDI) {
                candidates += midi to weight
            }
        }
        return candidates
    }

    private fun peakedScore(
        floatBuffer: FloatArray,
        sampleRate: Int,
        frequencyHz: Double,
        rms: Double,
        peakRatioThreshold: Double,
    ): Double {
        if (frequencyHz <= 0.0 || frequencyHz >= sampleRate / 2.0) {
            return 0.0
        }

        val center = normalizedGoertzel(floatBuffer, sampleRate, frequencyHz, rms)
        val lowerSide = normalizedGoertzel(
            floatBuffer,
            sampleRate,
            frequencyHz / SEMITONE_RATIO,
            rms,
        )
        val upperSide = normalizedGoertzel(
            floatBuffer,
            sampleRate,
            frequencyHz * SEMITONE_RATIO,
            rms,
        )
        val sideAverage = (lowerSide + upperSide) / 2.0
        if (center < sideAverage * peakRatioThreshold) {
            return 0.0
        }
        return center - sideAverage * 0.45
    }

    private fun normalizedGoertzel(
        floatBuffer: FloatArray,
        sampleRate: Int,
        frequencyHz: Double,
        rms: Double,
    ): Double {
        val omega = 2.0 * PI * frequencyHz / sampleRate
        val coefficient = 2.0 * cos(omega)
        var q0: Double
        var q1 = 0.0
        var q2 = 0.0

        for (sample in floatBuffer) {
            q0 = coefficient * q1 - q2 + sample
            q2 = q1
            q1 = q0
        }

        val power = q1 * q1 + q2 * q2 - coefficient * q1 * q2
        val magnitude = sqrt(max(0.0, power)) / floatBuffer.size
        return magnitude / (rms + 1.0e-9)
    }

    private fun calculateRms(floatBuffer: FloatArray): Double {
        var sum = 0.0
        for (sample in floatBuffer) {
            sum += sample * sample
        }
        return sqrt(sum / floatBuffer.size)
    }

    private fun prune(timestampMs: Long) {
        while (
            recentEvidence.isNotEmpty() &&
                timestampMs - recentEvidence.first().timestampMs > groupingWindowMs
        ) {
            recentEvidence.removeFirst()
        }
    }

    private fun midiToFrequency(midi: Int): Double {
        return 440.0 * 2.0.pow((midi - 69) / 12.0)
    }

    private companion object {
        const val MIN_PIANO_MIDI: Int = 21
        const val MAX_PIANO_MIDI: Int = 108
        val SEMITONE_RATIO: Double = 2.0.pow(1.0 / 12.0)
    }
}
