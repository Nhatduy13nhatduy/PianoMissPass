package com.pianomisspass.pianomisspass_fe

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import be.tarsos.dsp.AudioEvent
import be.tarsos.dsp.AudioProcessor
import be.tarsos.dsp.io.TarsosDSPAudioFormat
import be.tarsos.dsp.pitch.PitchDetectionHandler
import be.tarsos.dsp.pitch.PitchDetectionResult
import be.tarsos.dsp.pitch.PitchProcessor
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.ln
import kotlin.math.roundToInt

class NativeMicrophonePitchPlugin private constructor(
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL_NAME)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL_NAME)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val verifier = ExpectedChordVerifier()
    private val isRunning = AtomicBoolean(false)
    private val sinkLock = Any()
    private val verifierLock = Any()

    @Volatile
    private var eventSink: EventChannel.EventSink? = null
    private var audioRecord: AudioRecord? = null
    private var audioThread: Thread? = null
    private var lastEmittedDetectedMidis: Set<Int> = emptySet()
    private var lastEmittedActiveMidis: Set<Int> = emptySet()

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> {
                result.success(true)
            }
            "start" -> {
                start()
                result.success(null)
            }
            "stop" -> {
                stop()
                result.success(null)
            }
            "updateExpectedMidis" -> {
                val midis = call.argument<List<Int>>("midis") ?: emptyList()
                synchronized(verifierLock) {
                    verifier.updateExpectedMidis(midis)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        synchronized(sinkLock) {
            eventSink = events
        }
    }

    override fun onCancel(arguments: Any?) {
        synchronized(sinkLock) {
            eventSink = null
        }
        stop()
    }

    private fun start() {
        if (!isRunning.compareAndSet(false, true)) {
            return
        }

        synchronized(verifierLock) {
            verifier.reset()
        }
        lastEmittedDetectedMidis = emptySet()
        lastEmittedActiveMidis = emptySet()
        audioThread = Thread({ runMicrophoneDispatcher() }, "TarsosDSP Microphone Thread").also { thread ->
            thread.start()
        }
    }

    private fun runMicrophoneDispatcher() {
        val pitchHandler = PitchDetectionHandler { result, audioEvent ->
            handlePitch(result, audioEvent)
        }
        try {
            val processor: AudioProcessor = PitchProcessor(
                PitchProcessor.PitchEstimationAlgorithm.FFT_YIN,
                SAMPLE_RATE.toFloat(),
                BUFFER_SIZE,
                pitchHandler,
            )
            val minBufferBytes = AudioRecord.getMinBufferSize(
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
            )
            if (minBufferBytes == AudioRecord.ERROR ||
                minBufferBytes == AudioRecord.ERROR_BAD_VALUE
            ) {
                throw IllegalStateException("Invalid AudioRecord buffer size: $minBufferBytes")
            }

            val recordBufferBytes = maxOf(minBufferBytes, BUFFER_SIZE * 2)
            val nextAudioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                recordBufferBytes,
            )
            if (nextAudioRecord.state != AudioRecord.STATE_INITIALIZED) {
                nextAudioRecord.release()
                throw IllegalStateException("AudioRecord failed to initialize.")
            }
            audioRecord = nextAudioRecord

            val pcmBuffer = ShortArray(HOP_SIZE)
            val analysisBuffer = FloatArray(BUFFER_SIZE)
            val audioFormat = TarsosDSPAudioFormat(
                SAMPLE_RATE.toFloat(),
                16,
                1,
                true,
                false,
            )
            val audioEvent = AudioEvent(audioFormat)
            var writeIndex = 0
            var filledSamples = 0
            var processedSamples = 0L

            nextAudioRecord.startRecording()
            if (!isRunning.get()) {
                nextAudioRecord.stop()
                nextAudioRecord.release()
                return
            }

            while (isRunning.get()) {
                val readSamples = nextAudioRecord.read(pcmBuffer, 0, pcmBuffer.size)
                if (readSamples <= 0) {
                    continue
                }

                for (i in 0 until readSamples) {
                    analysisBuffer[writeIndex] = pcmBuffer[i] / 32768.0f
                    writeIndex = (writeIndex + 1) % BUFFER_SIZE
                    if (filledSamples < BUFFER_SIZE) {
                        filledSamples++
                    }
                }

                if (filledSamples == BUFFER_SIZE) {
                    val orderedBuffer = FloatArray(BUFFER_SIZE)
                    for (i in 0 until BUFFER_SIZE) {
                        orderedBuffer[i] = analysisBuffer[(writeIndex + i) % BUFFER_SIZE]
                    }
                    audioEvent.floatBuffer = orderedBuffer
                    audioEvent.setBytesProcessed(processedSamples * 2)
                    audioEvent.setBytesProcessing(BUFFER_SIZE * 2)
                    processor.process(audioEvent)
                    processedSamples += readSamples.toLong()
                }
            }
        } catch (error: Throwable) {
            isRunning.set(false)
            emitError("microphone_start_failed", error.message ?: error.toString())
        } finally {
            val record = audioRecord
            audioRecord = null
            try {
                if (record?.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                    record.stop()
                }
            } catch (_: Throwable) {
                // Ignore teardown errors from AudioRecord.
            }
            record?.release()
        }
    }

    private fun stop() {
        if (!isRunning.getAndSet(false)) {
            return
        }

        try {
            audioRecord?.stop()
        } catch (_: Throwable) {
            // Ignore teardown errors from AudioRecord.
        }
        audioThread = null
        synchronized(verifierLock) {
            verifier.reset()
        }
    }

    private fun emitError(
        code: String,
        message: String,
    ) {
        val sink = synchronized(sinkLock) {
            eventSink
        } ?: return
        mainHandler.post {
            if (eventSink === sink) {
                sink.error(code, message, null)
            }
        }
    }

    private fun handlePitch(
        pitchResult: PitchDetectionResult,
        audioEvent: AudioEvent,
    ) {
        if (!isRunning.get()) {
            return
        }

        val nowMs = (audioEvent.timeStamp * 1000.0).toLong()
        val activeMidis = if (pitchResult.isPitched && pitchResult.pitch > 0f) {
            setOf(frequencyToMidi(pitchResult.pitch))
        } else {
            emptySet()
        }
        val detectionResult = synchronized(verifierLock) {
            verifier.acceptFrame(
                floatBuffer = audioEvent.floatBuffer,
                sampleRate = SAMPLE_RATE,
                timestampMs = nowMs,
            )
        }
        emitPitchEvent(
            detectedMidis = detectionResult.detectedMidis,
            activeMidis = activeMidis.ifEmpty { detectionResult.detectedMidis },
            debugPayload = mapOf(
                "rms" to detectionResult.rms,
                "maxScore" to detectionResult.maxScore,
                "expectedMidis" to detectionResult.expectedMidis.sorted(),
                "detectedMidis" to detectionResult.detectedMidis.sorted(),
                "scoresByMidi" to detectionResult.scoresByMidi
                    .toSortedMap()
                    .mapValues { (_, score) -> score },
            ),
        )
    }

    private fun emitPitchEvent(
        detectedMidis: Set<Int>,
        activeMidis: Set<Int>,
        debugPayload: Map<String, Any>,
    ) {
        if (
            detectedMidis == lastEmittedDetectedMidis &&
                activeMidis == lastEmittedActiveMidis
        ) {
            return
        }
        val sink = synchronized(sinkLock) {
            eventSink
        } ?: return
        lastEmittedDetectedMidis = detectedMidis
        lastEmittedActiveMidis = activeMidis
        val payload = mapOf(
            "detectedMidis" to detectedMidis.sorted(),
            "activeMidis" to activeMidis.sorted(),
            "debug" to debugPayload,
        )
        mainHandler.post {
            if (eventSink === sink && isRunning.get()) {
                sink.success(payload)
            }
        }
    }

    private fun frequencyToMidi(frequencyHz: Float): Int {
        val semitonesFromA4 = 12.0 * ln(frequencyHz / 440.0) / ln(2.0)
        return (69.0 + semitonesFromA4).roundToInt()
    }

    companion object {
        private const val METHOD_CHANNEL_NAME = "pianomisspass/native_microphone_pitch"
        private const val EVENT_CHANNEL_NAME = "pianomisspass/native_microphone_pitch/events"
        private const val SAMPLE_RATE = 44100
        private const val BUFFER_SIZE = 2048
        private const val HOP_SIZE = 1024

        fun register(messenger: BinaryMessenger): NativeMicrophonePitchPlugin {
            return NativeMicrophonePitchPlugin(messenger)
        }
    }
}
