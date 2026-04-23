package com.pianomisspass.pianomisspass_fe

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sqrt

class ExpectedChordVerifier(
    private val groupingWindowMs: Long = 120L,
    private val minimumGroupedFrames: Int = 3,
    private val rmsGate: Double = 0.012,
    private val absoluteScoreThreshold: Double = 0.16,
    private val relativeScoreThreshold: Double = 0.78,
    private val peakRatioThreshold: Double = 1.55,
) {
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

    fun matchSinglePitch(pitchHz: Float): Set<Int> {
        if (expectedMidis.isEmpty() || pitchHz <= 0f) {
            return emptySet()
        }

        val detectedMidi = frequencyToMidi(pitchHz)
        return if (detectedMidi in expectedMidis) {
            setOf(detectedMidi)
        } else {
            emptySet()
        }
    }

    fun acceptFrame(
        floatBuffer: FloatArray,
        sampleRate: Int,
        timestampMs: Long,
    ): Set<Int> {
        prune(timestampMs)

        if (expectedMidis.isEmpty() || floatBuffer.isEmpty()) {
            return emptySet()
        }

        val isChord = expectedMidis.size > 1
        val resolvedRmsGate = if (isChord) 0.008 else rmsGate
        val resolvedAbsoluteThreshold = if (isChord) 0.11 else absoluteScoreThreshold
        val resolvedRelativeThreshold = if (isChord) 0.60 else relativeScoreThreshold
        val resolvedPeakRatioThreshold = if (isChord) 1.22 else peakRatioThreshold
        val requiredFrames = if (isChord) 2 else minimumGroupedFrames

        val rms = calculateRms(floatBuffer)
        if (rms < resolvedRmsGate) {
            return emptySet()
        }

        val scoredMidis = expectedMidis.associateWith { midi ->
            scoreMidi(
                floatBuffer = floatBuffer,
                sampleRate = sampleRate,
                midi = midi,
                rms = rms,
                absoluteThreshold = resolvedAbsoluteThreshold,
                peakRatioThreshold = resolvedPeakRatioThreshold,
                isChord = isChord,
            )
        }
        val maxScore = scoredMidis.values.maxOrNull() ?: 0.0
        if (maxScore < resolvedAbsoluteThreshold) {
            return groupedMidis(requiredFrames)
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

        return groupedMidis(requiredFrames)
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

    private fun scoreMidi(
        floatBuffer: FloatArray,
        sampleRate: Int,
        midi: Int,
        rms: Double,
        absoluteThreshold: Double,
        peakRatioThreshold: Double,
        isChord: Boolean,
    ): Double {
        val fundamental = midiToFrequency(midi)
        if (fundamental <= 0.0 || fundamental >= sampleRate / 2.0) {
            return 0.0
        }

        val fundamentalScore = peakedScore(
            floatBuffer = floatBuffer,
            sampleRate = sampleRate,
            frequencyHz = fundamental,
            rms = rms,
            peakRatioThreshold = peakRatioThreshold,
        )
        val minimumFundamental = if (isChord) absoluteThreshold * 0.65 else absoluteThreshold
        if (fundamentalScore < minimumFundamental) {
            return 0.0
        }

        val secondHarmonicScore = harmonicScore(
            floatBuffer,
            sampleRate,
            fundamental * 2.0,
            rms,
            peakRatioThreshold = if (isChord) peakRatioThreshold * 0.92 else peakRatioThreshold,
        ) * if (isChord) 0.28 else 0.18
        val thirdHarmonicScore = harmonicScore(
            floatBuffer,
            sampleRate,
            fundamental * 3.0,
            rms,
            peakRatioThreshold = if (isChord) peakRatioThreshold * 0.90 else peakRatioThreshold,
        ) * if (isChord) 0.16 else 0.10
        val fourthHarmonicScore = harmonicScore(
            floatBuffer,
            sampleRate,
            fundamental * 4.0,
            rms,
            peakRatioThreshold = if (isChord) peakRatioThreshold * 0.88 else peakRatioThreshold,
        ) * if (isChord) 0.09 else 0.06

        return max(
            fundamentalScore,
            fundamentalScore * if (isChord) 0.82 else 0.90 +
                secondHarmonicScore +
                thirdHarmonicScore +
                fourthHarmonicScore,
        )
    }

    private fun harmonicScore(
        floatBuffer: FloatArray,
        sampleRate: Int,
        frequencyHz: Double,
        rms: Double,
        peakRatioThreshold: Double,
    ): Double {
        if (frequencyHz >= sampleRate / 2.0) {
            return 0.0
        }
        return peakedScore(
            floatBuffer = floatBuffer,
            sampleRate = sampleRate,
            frequencyHz = frequencyHz,
            rms = rms,
            peakRatioThreshold = peakRatioThreshold,
        )
    }

    private fun peakedScore(
        floatBuffer: FloatArray,
        sampleRate: Int,
        frequencyHz: Double,
        rms: Double,
        peakRatioThreshold: Double,
    ): Double {
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
        return center - sideAverage * 0.65
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
    }

    @Suppress("unused")
    private fun frequencyToMidi(frequencyHz: Float): Int {
        val semitonesFromA4 = 12.0 * ln(frequencyHz / 440.0) / ln(2.0)
        return (69.0 + semitonesFromA4).roundToInt()
    }
}
