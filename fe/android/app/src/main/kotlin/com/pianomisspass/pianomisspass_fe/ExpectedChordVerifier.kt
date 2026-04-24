package com.pianomisspass.pianomisspass_fe

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.sqrt

class ExpectedChordVerifier(
    private val groupingWindowMs: Long = 130L,
    private val minimumGroupedFrames: Int = 2,
    private val rmsGate: Double = 0.02,
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
        val resolvedRmsGate = max(rmsGate, if (isChord) 0.0085 else rmsGate)
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

        val rawScoredMidis = expectedMidis.associateWith { midi ->
            scoreExpectedMidi(
                floatBuffer = floatBuffer,
                sampleRate = sampleRate,
                expectedMidi = midi,
                rms = rms,
                peakRatioThreshold = resolvedPeakRatioThreshold,
                isChord = isChord,
            )
        }
        val scoredMidis = suppressUpperOctaveShadows(rawScoredMidis)
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
        val baseFrequency = midiToFrequency(expectedMidi)
        if (baseFrequency >= sampleRate / 2.0) {
            return 0.0
        }

        val fundamentalScore = peakedScore(
            floatBuffer = floatBuffer,
            sampleRate = sampleRate,
            frequencyHz = baseFrequency,
            rms = rms,
            peakRatioThreshold = peakRatioThreshold,
        )
        if (fundamentalScore <= 0.0) {
            return 0.0
        }

        // Nếu đang kiểm tra C4/D4/E4..., nhưng trong buffer có C3/D3/E3 mạnh,
        // thì năng lượng ở octave trên rất có thể chỉ là harmonic bậc 2 của octave dưới.
        // Rule này chặn lỗi: C3 -> C3 + C4, D3 -> D3 + D4, E3 -> E3 + E4...
        val lowerOctaveScore = if (baseFrequency / 2.0 > 20.0) {
            peakedScore(
                floatBuffer = floatBuffer,
                sampleRate = sampleRate,
                frequencyHz = baseFrequency / 2.0,
                rms = rms,
                peakRatioThreshold = peakRatioThreshold * 0.90,
            )
        } else {
            0.0
        }
        if (lowerOctaveScore >= fundamentalScore * LOWER_OCTAVE_SUPPRESSION_RATIO) {
            return 0.0
        }

        val harmonic2 = peakedScore(
            floatBuffer = floatBuffer,
            sampleRate = sampleRate,
            frequencyHz = baseFrequency * 2.0,
            rms = rms,
            peakRatioThreshold = peakRatioThreshold * 0.96,
        ) * if (isChord) 0.30 else 0.18
        val harmonic3 = peakedScore(
            floatBuffer = floatBuffer,
            sampleRate = sampleRate,
            frequencyHz = baseFrequency * 3.0,
            rms = rms,
            peakRatioThreshold = peakRatioThreshold * 0.93,
        ) * if (isChord) 0.14 else 0.08

        return max(
            fundamentalScore,
            fundamentalScore * if (isChord) 0.76 else 0.86 + harmonic2 + harmonic3,
        )
    }

    private fun suppressUpperOctaveShadows(scoresByMidi: Map<Int, Double>): Map<Int, Double> {
        if (scoresByMidi.size < 2) {
            return scoresByMidi
        }

        val mutableScores = scoresByMidi.toMutableMap()
        for ((midi, score) in scoresByMidi) {
            if (score <= 0.0) continue

            val upperMidi = midi + 12
            val upperScore = mutableScores[upperMidi] ?: continue

            if (upperScore <= score * UPPER_OCTAVE_SHADOW_RATIO) {
                mutableScores[upperMidi] = 0.0
            }
        }
        return mutableScores
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
        val SEMITONE_RATIO: Double = 2.0.pow(1.0 / 12.0)
        const val LOWER_OCTAVE_SUPPRESSION_RATIO: Double = 0.58
        const val UPPER_OCTAVE_SHADOW_RATIO: Double = 0.92
    }
}
