import 'dart:math' as math;

import 'microphone_note_detector.dart';

class ExpectedNotePitchDetector {
  ExpectedNotePitchDetector({
    this.sampleRate = defaultSampleRate,
    this.fftSize = defaultFftSize,
    this.hopSize = defaultHopSize,
    this.maxDetectedNotes = 6,
  }) : assert(fftSize > 0 && (fftSize & (fftSize - 1)) == 0);

  static const int defaultSampleRate = 16000;
  static const int defaultFftSize = 2048;
  static const int defaultHopSize = 512;

  final int sampleRate;
  final int fftSize;
  final int hopSize;
  final int maxDetectedNotes;
  final List<double> _sampleBuffer = <double>[];

  void reset() {
    _sampleBuffer.clear();
  }

  PitchDetectionFrame? addSamples(
    List<double> samples, {
    required Set<int> candidateMidis,
    required MicrophoneCalibration calibration,
  }) {
    if (samples.isEmpty) {
      return null;
    }

    _sampleBuffer.addAll(samples);
    if (_sampleBuffer.length < fftSize) {
      return null;
    }

    final frame = _sampleBuffer.sublist(_sampleBuffer.length - fftSize);
    final keepFrom = _sampleBuffer.length - (fftSize - hopSize);
    if (keepFrom > 0) {
      _sampleBuffer.removeRange(0, keepFrom);
    }

    return _analyzeFrame(
      frame,
      candidateMidis: candidateMidis,
      calibration: calibration,
    );
  }

  PitchDetectionFrame _analyzeFrame(
    List<double> frame, {
    required Set<int> candidateMidis,
    required MicrophoneCalibration calibration,
  }) {
    final rms = _computeRms(frame);
    if (rms < calibration.rmsGate || candidateMidis.isEmpty) {
      return PitchDetectionFrame(detectedMidis: const <int>{}, rms: rms);
    }

    final real = List<double>.filled(fftSize, 0);
    final imag = List<double>.filled(fftSize, 0);
    for (var i = 0; i < fftSize; i++) {
      final window = 0.5 - 0.5 * math.cos((2 * math.pi * i) / (fftSize - 1));
      real[i] = frame[i] * window;
    }

    _fft(real, imag);

    final magnitudes = List<double>.filled(fftSize ~/ 2, 0);
    var globalPeak = 0.0;
    for (var i = 1; i < magnitudes.length; i++) {
      final magnitude = math.sqrt(real[i] * real[i] + imag[i] * imag[i]);
      magnitudes[i] = magnitude;
      if (magnitude > globalPeak) {
        globalPeak = magnitude;
      }
    }

    if (globalPeak <= 0) {
      return PitchDetectionFrame(detectedMidis: const <int>{}, rms: rms);
    }

    final candidates = <_PitchCandidate>[];
    final confidenceByMidi = <int, double>{};
    final sortedCandidates = candidateMidis.toList()..sort();
    for (final midi in sortedCandidates) {
      final targetBin = _midiToFrequency(midi) * fftSize / sampleRate;
      if (targetBin < 1 || targetBin >= magnitudes.length - 1) {
        continue;
      }

      final fundamental = _peakEnergyAround(magnitudes, targetBin, radius: 1);
      final harmonic2 = _peakEnergyAround(magnitudes, targetBin * 2, radius: 2);
      final harmonic3 = _peakEnergyAround(magnitudes, targetBin * 3, radius: 2);
      final weightedEnergy = fundamental + harmonic2 * 0.25 + harmonic3 * 0.15;
      final localNoise = _localNoiseFloor(magnitudes, targetBin);
      final neighborEnergy = math.max(
        _candidateNeighborEnergy(magnitudes, midi - 1),
        _candidateNeighborEnergy(magnitudes, midi + 1),
      );
      final lowerOctaveEnergy = _candidateNeighborEnergy(magnitudes, midi - 12);
      final confidence = math.min(
        1.0,
        math.max(
          fundamental / (globalPeak <= 0 ? 1 : globalPeak),
          fundamental / (localNoise * 5.0),
        ),
      );
      confidenceByMidi[midi] = confidence.clamp(0.0, 1.0);

      final strongEnoughConfidence = confidence >= calibration.noteThreshold;
      final clearFundamental =
          fundamental >= weightedEnergy * 0.28 &&
          fundamental >= localNoise * 2.2;
      final strongAgainstPeak = weightedEnergy >= globalPeak * 0.28;
      final strongAgainstNoise = weightedEnergy >= localNoise * 5.2;
      final strongAgainstNeighbors =
          neighborEnergy <= 0 || weightedEnergy >= neighborEnergy * 1.35;
      final notJustHigherHarmonic =
          lowerOctaveEnergy <= 0 || weightedEnergy >= lowerOctaveEnergy * 1.10;
      if (strongEnoughConfidence &&
          clearFundamental &&
          strongAgainstPeak &&
          strongAgainstNoise &&
          strongAgainstNeighbors &&
          notJustHigherHarmonic) {
        candidates.add(
          _PitchCandidate(
            midi: midi,
            confidence: confidence,
            fundamental: fundamental,
            weightedEnergy: weightedEnergy,
          ),
        );
      }
    }

    final detected = _filterLikelyOctaveHarmonics(candidates);
    detected.sort((a, b) {
      final confidenceCompare = (confidenceByMidi[b] ?? 0).compareTo(
        confidenceByMidi[a] ?? 0,
      );
      if (confidenceCompare != 0) {
        return confidenceCompare;
      }
      return a.compareTo(b);
    });
    final detectedLimit = math.max(
      1,
      math.min(maxDetectedNotes, candidateMidis.length),
    );
    final limitedDetected = detected.take(detectedLimit).toSet();

    return PitchDetectionFrame(
      detectedMidis: limitedDetected,
      rms: rms,
      confidenceByMidi: confidenceByMidi,
    );
  }

  List<int> _filterLikelyOctaveHarmonics(List<_PitchCandidate> candidates) {
    if (candidates.length < 2) {
      return candidates.map((candidate) => candidate.midi).toList();
    }

    final byMidi = <int, _PitchCandidate>{
      for (final candidate in candidates) candidate.midi: candidate,
    };
    final filtered = <int>[];
    for (final candidate in candidates) {
      final lowerOctave = byMidi[candidate.midi - 12];
      if (lowerOctave != null) {
        final looksLikeLowerOvertone =
            candidate.fundamental <= lowerOctave.weightedEnergy * 0.75 &&
            candidate.confidence <= lowerOctave.confidence * 1.20;
        if (looksLikeLowerOvertone) {
          continue;
        }
      }
      filtered.add(candidate.midi);
    }
    return filtered;
  }

  double _candidateNeighborEnergy(List<double> magnitudes, int midi) {
    if (midi < 0 || midi > 127) {
      return 0;
    }
    final targetBin = _midiToFrequency(midi) * fftSize / sampleRate;
    if (targetBin < 1 || targetBin >= magnitudes.length - 1) {
      return 0;
    }
    return _peakEnergyAround(magnitudes, targetBin, radius: 1);
  }

  double _peakEnergyAround(
    List<double> magnitudes,
    double targetBin, {
    required int radius,
  }) {
    if (!targetBin.isFinite) {
      return 0;
    }
    final center = targetBin.round();
    if (center <= 0 || center >= magnitudes.length) {
      return 0;
    }

    var peak = 0.0;
    final start = math.max(1, center - radius);
    final end = math.min(magnitudes.length - 1, center + radius);
    for (var i = start; i <= end; i++) {
      if (magnitudes[i] > peak) {
        peak = magnitudes[i];
      }
    }
    return peak;
  }

  double _localNoiseFloor(List<double> magnitudes, double targetBin) {
    final center = targetBin.round();
    final samples = <double>[];
    final start = math.max(1, center - 16);
    final end = math.min(magnitudes.length - 1, center + 16);
    for (var i = start; i <= end; i++) {
      if ((i - center).abs() <= 2) {
        continue;
      }
      samples.add(magnitudes[i]);
    }
    if (samples.isEmpty) {
      return 1e-9;
    }
    samples.sort();
    return samples[samples.length ~/ 2].clamp(1e-9, double.infinity);
  }

  double _computeRms(List<double> frame) {
    var energy = 0.0;
    for (final sample in frame) {
      energy += sample * sample;
    }
    return math.sqrt(energy / frame.length);
  }

  double _midiToFrequency(int midi) {
    return 440.0 * math.pow(2.0, (midi - 69) / 12.0);
  }

  void _fft(List<double> real, List<double> imag) {
    final n = real.length;
    var j = 0;
    for (var i = 0; i < n; i++) {
      if (i < j) {
        final realTemp = real[i];
        real[i] = real[j];
        real[j] = realTemp;

        final imagTemp = imag[i];
        imag[i] = imag[j];
        imag[j] = imagTemp;
      }

      var m = n >> 1;
      while (m >= 1 && j >= m) {
        j -= m;
        m >>= 1;
      }
      j += m;
    }

    for (var len = 2; len <= n; len <<= 1) {
      final angle = -2 * math.pi / len;
      final wLenCos = math.cos(angle);
      final wLenSin = math.sin(angle);
      for (var i = 0; i < n; i += len) {
        var wCos = 1.0;
        var wSin = 0.0;
        for (var k = 0; k < len ~/ 2; k++) {
          final evenIndex = i + k;
          final oddIndex = evenIndex + len ~/ 2;

          final oddReal = real[oddIndex] * wCos - imag[oddIndex] * wSin;
          final oddImag = real[oddIndex] * wSin + imag[oddIndex] * wCos;

          real[oddIndex] = real[evenIndex] - oddReal;
          imag[oddIndex] = imag[evenIndex] - oddImag;
          real[evenIndex] += oddReal;
          imag[evenIndex] += oddImag;

          final nextWCos = wCos * wLenCos - wSin * wLenSin;
          wSin = wCos * wLenSin + wSin * wLenCos;
          wCos = nextWCos;
        }
      }
    }
  }
}

class _PitchCandidate {
  const _PitchCandidate({
    required this.midi,
    required this.confidence,
    required this.fundamental,
    required this.weightedEnergy,
  });

  final int midi;
  final double confidence;
  final double fundamental;
  final double weightedEnergy;
}
