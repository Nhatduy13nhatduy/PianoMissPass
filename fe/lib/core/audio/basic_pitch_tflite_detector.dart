import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'microphone_note_detector.dart';

class BasicPitchTfliteDetector implements MicrophoneNoteDetector {
  BasicPitchTfliteDetector({
    this.modelAssetPath = 'assets/ml/basic_pitch.tflite',
    this.threads = 2,
    this.noteThreshold = 0.42,
    this.onsetThreshold = 0.30,
    this.tailFramesToInspect = 8,
    this.defaultHopSamples = 2048,
    this.maxDetectedNotes = 8,
  });

  final String modelAssetPath;
  final int threads;
  final double noteThreshold;
  final double onsetThreshold;
  final int tailFramesToInspect;
  final int defaultHopSamples;
  final int maxDetectedNotes;
  static const double _dynamicTopScoreFactor = 0.42;
  static const double _semitoneConflictFactor = 0.84;
  static const double _octaveConflictFactor = 0.72;
  static const int _lowestPianoMidi = 21;
  static const int _highestPianoMidi = 108;

  Interpreter? _interpreter;
  final List<double> _sampleBuffer = <double>[];
  int _inputSampleCount = 43844;
  int _hopSampleCount = 2048;
  int _pendingHopSamples = 0;

  @override
  String get debugName => 'Basic Pitch TFLite';

  @override
  int get sampleRate => 22050;

  @override
  int get bufferSize => math.min(_inputSampleCount, 4096);

  @override
  Future<bool> initialize() async {
    try {
      final options = InterpreterOptions()..threads = threads;
      final interpreter = await Interpreter.fromAsset(
        modelAssetPath,
        options: options,
      );
      _interpreter = interpreter;

      final inputShape = interpreter.getInputTensor(0).shape;
      _inputSampleCount = _resolveInputSampleCount(inputShape);
      _hopSampleCount = math.min(defaultHopSamples, _inputSampleCount);
      _sampleBuffer.clear();
      _pendingHopSamples = 0;
      return true;
    } catch (error) {
      debugPrint('Basic Pitch TFLite init failed: $error');
      await dispose();
      return false;
    }
  }

  @override
  PitchDetectionFrame? addSamples(
    List<double> samples, {
    required Set<int> candidateMidis,
    required MicrophoneCalibration calibration,
  }) {
    final interpreter = _interpreter;
    if (interpreter == null || samples.isEmpty) {
      return null;
    }

    _sampleBuffer.addAll(samples);
    _pendingHopSamples += samples.length;
    if (_sampleBuffer.length < _inputSampleCount) {
      return null;
    }
    if (_pendingHopSamples < _hopSampleCount) {
      return null;
    }

    _pendingHopSamples = 0;
    final frame = _sampleBuffer.sublist(
      _sampleBuffer.length - _inputSampleCount,
    );
    final keepFrom = math.max(0, _sampleBuffer.length - _inputSampleCount);
    if (keepFrom > 0) {
      _sampleBuffer.removeRange(0, keepFrom);
    }

    final rms = _computeRms(frame);
    if (rms < calibration.rmsGate || candidateMidis.isEmpty) {
      return PitchDetectionFrame(detectedMidis: const <int>{}, rms: rms);
    }

    try {
      final input = _buildInputTensor(
        frame,
        interpreter.getInputTensor(0).shape,
      );
      final outputTensors = interpreter.getOutputTensors();
      final outputs = <int, Object>{};
      for (var i = 0; i < outputTensors.length; i++) {
        outputs[i] = _allocateTensor(outputTensors[i].shape);
      }

      interpreter.runForMultipleInputs(<Object>[input], outputs);

      final outputMatrices = outputTensors.indexed
          .map((entry) {
            final (index, tensor) = entry;
            final matrix = _extractTimeFrequencyMatrix(outputs[index]!);
            if (matrix == null) {
              return null;
            }
            return _BasicPitchOutputMatrix(
              name: tensor.name,
              matrix: matrix,
            );
          })
          .whereType<_BasicPitchOutputMatrix>()
          .toList(growable: false);
      final noteMatrix = _selectNoteMatrix(outputMatrices);
      final onsetMatrix = _selectOnsetMatrix(
        outputMatrices,
        primary: noteMatrix,
      );
      if (noteMatrix == null) {
        return PitchDetectionFrame(detectedMidis: const <int>{}, rms: rms);
      }

      final confidenceByMidi = <int, double>{};
      final onsetConfidenceByMidi = <int, double>{};
      final weightedScoreByMidi = <int, double>{};
      for (final midi in _pianoCandidateMidis(candidateMidis)) {
        final pitchIndex = midi - _lowestPianoMidi;
        if (pitchIndex < 0 || pitchIndex >= noteMatrix.first.length) {
          continue;
        }

        final notePeak = _tailPeak(noteMatrix, pitchIndex);
        final onsetPeak = onsetMatrix == null
            ? 0.0
            : _tailPeak(onsetMatrix, pitchIndex);
        confidenceByMidi[midi] = notePeak.clamp(0.0, 1.0);
        onsetConfidenceByMidi[midi] = onsetPeak.clamp(0.0, 1.0);
        weightedScoreByMidi[midi] = _weightedPitchScore(notePeak, onsetPeak);
      }

      final detected = _postProcessDetectedMidis(
        candidateMidis: candidateMidis,
        confidenceByMidi: confidenceByMidi,
        onsetConfidenceByMidi: onsetConfidenceByMidi,
        weightedScoreByMidi: weightedScoreByMidi,
        calibration: calibration,
      );
      final noiseFloor = _estimateNoiseFloor(
        noteMatrix,
        candidateMidis: candidateMidis,
      );

      return PitchDetectionFrame(
        detectedMidis: detected,
        rms: rms,
        noiseFloor: noiseFloor,
        confidenceByMidi: confidenceByMidi,
        onsetConfidenceByMidi: onsetConfidenceByMidi,
      );
    } catch (error) {
      debugPrint('Basic Pitch inference failed: $error');
      return PitchDetectionFrame(detectedMidis: const <int>{}, rms: rms);
    }
  }

  @override
  void reset() {
    _sampleBuffer.clear();
    _pendingHopSamples = 0;
  }

  @override
  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
    _sampleBuffer.clear();
    _pendingHopSamples = 0;
  }

  int _resolveInputSampleCount(List<int> shape) {
    if (shape.isEmpty) {
      return 43844;
    }
    if (shape.length == 2) {
      return shape[1];
    }
    if (shape.length >= 3) {
      return shape[1] * shape[2];
    }
    return shape.last;
  }

  Object _buildInputTensor(List<double> frame, List<int> shape) {
    if (shape.length == 2) {
      return <List<double>>[frame];
    }
    if (shape.length == 3 && shape[2] == 1) {
      return <List<List<double>>>[
        frame.map((sample) => <double>[sample]).toList(growable: false),
      ];
    }
    return <List<double>>[frame];
  }

  Object _allocateTensor(List<int> shape) {
    if (shape.isEmpty) {
      return 0.0;
    }
    return _allocateTensorRecursive(shape, 0);
  }

  Object _allocateTensorRecursive(List<int> shape, int depth) {
    final length = shape[depth];
    if (depth == shape.length - 1) {
      return List<double>.filled(length, 0);
    }
    return List<Object>.generate(
      length,
      (_) => _allocateTensorRecursive(shape, depth + 1),
      growable: false,
    );
  }

  List<List<double>>? _extractTimeFrequencyMatrix(Object raw) {
    dynamic value = raw;
    while (value is List && value.length == 1 && value.first is List) {
      value = value.first;
    }

    if (value is! List || value.isEmpty || value.first is! List) {
      return null;
    }

    final rows = <List<double>>[];
    for (final row in value) {
      if (row is! List) {
        return null;
      }
      rows.add(
        row
            .whereType<num>()
            .map((item) => item.toDouble())
            .toList(growable: false),
      );
    }
    if (rows.isEmpty || rows.first.isEmpty) {
      return null;
    }
    return rows;
  }

  List<List<double>>? _selectNoteMatrix(
    List<_BasicPitchOutputMatrix> outputs,
  ) {
    final named = _findOutputByName(outputs, 'note');
    if (named != null) {
      return named.matrix;
    }

    // This exported Basic Pitch model keeps semantic output names in metadata,
    // but some runtimes expose only StatefulPartitionedCall:N tensor names.
    final knownTensor = _findOutputByTensorSuffix(outputs, ':1');
    if (knownTensor != null) {
      return knownTensor.matrix;
    }

    final pitchOutputs = _pianoWidthOutputs(outputs);
    if (pitchOutputs.length >= 2) {
      return pitchOutputs[1].matrix;
    }
    return pitchOutputs.isEmpty ? null : pitchOutputs.first.matrix;
  }

  List<List<double>>? _selectOnsetMatrix(
    List<_BasicPitchOutputMatrix> outputs, {
    required List<List<double>>? primary,
  }) {
    final named = _findOutputByName(outputs, 'onset', excluding: primary);
    if (named != null) {
      return named.matrix;
    }

    final knownTensor = _findOutputByTensorSuffix(
      outputs,
      ':2',
      excluding: primary,
    );
    if (knownTensor != null) {
      return knownTensor.matrix;
    }

    final pitchOutputs = _pianoWidthOutputs(outputs)
        .where((output) => !identical(output.matrix, primary))
        .toList(growable: false);
    return pitchOutputs.isEmpty ? null : pitchOutputs.first.matrix;
  }

  _BasicPitchOutputMatrix? _findOutputByName(
    List<_BasicPitchOutputMatrix> outputs,
    String semanticName, {
    List<List<double>>? excluding,
  }) {
    for (final output in outputs) {
      final normalizedName = output.name.toLowerCase();
      if (!identical(output.matrix, excluding) &&
          output.matrix.first.length == 88 &&
          normalizedName.contains(semanticName)) {
        return output;
      }
    }
    return null;
  }

  _BasicPitchOutputMatrix? _findOutputByTensorSuffix(
    List<_BasicPitchOutputMatrix> outputs,
    String suffix, {
    List<List<double>>? excluding,
  }) {
    for (final output in outputs) {
      if (!identical(output.matrix, excluding) &&
          output.matrix.first.length == 88 &&
          output.name.endsWith(suffix)) {
        return output;
      }
    }
    return null;
  }

  List<_BasicPitchOutputMatrix> _pianoWidthOutputs(
    List<_BasicPitchOutputMatrix> outputs,
  ) {
    return outputs
        .where((output) => output.matrix.first.length == 88)
        .toList(growable: false);
  }

  Set<int> _postProcessDetectedMidis({
    required Set<int> candidateMidis,
    required Map<int, double> confidenceByMidi,
    required Map<int, double> onsetConfidenceByMidi,
    required Map<int, double> weightedScoreByMidi,
    required MicrophoneCalibration calibration,
  }) {
    if (candidateMidis.isEmpty) {
      return const <int>{};
    }

    final topWeightedScore = weightedScoreByMidi.values.fold<double>(
      0,
      (best, value) => value > best ? value : best,
    );
    final dynamicThreshold = topWeightedScore * _dynamicTopScoreFactor;

    final prelimDetected = <int>{};
    for (final midi in _pianoCandidateMidis(candidateMidis)) {
      final noteConfidence = confidenceByMidi[midi] ?? 0;
      final onsetConfidence = onsetConfidenceByMidi[midi] ?? 0;
      final weightedScore = weightedScoreByMidi[midi] ?? 0;
      final passesAbsolute =
          noteConfidence >= calibration.noteThreshold ||
          onsetConfidence >= calibration.onsetThreshold ||
          weightedScore >= calibration.noteThreshold * 0.9;
      final passesRelative = weightedScore >= dynamicThreshold;
      if (passesAbsolute && passesRelative) {
        prelimDetected.add(midi);
      }
    }

    final sortedDetected = prelimDetected.toList()
      ..sort((a, b) {
        final scoreCompare = (weightedScoreByMidi[b] ?? 0).compareTo(
          weightedScoreByMidi[a] ?? 0,
        );
        if (scoreCompare != 0) {
          return scoreCompare;
        }
        return a.compareTo(b);
      });

    final filtered = <int>{};
    for (final midi in sortedDetected) {
      if (_isSuppressedByNeighborConflict(
        midi,
        selectedMidis: filtered,
        weightedScoreByMidi: weightedScoreByMidi,
      )) {
        continue;
      }
      filtered.add(midi);
      if (filtered.length >= maxDetectedNotes) {
        break;
      }
    }

    return filtered;
  }

  bool _isSuppressedByNeighborConflict(
    int midi, {
    required Set<int> selectedMidis,
    required Map<int, double> weightedScoreByMidi,
  }) {
    final midiScore = weightedScoreByMidi[midi] ?? 0;
    for (final selectedMidi in selectedMidis) {
      final selectedScore = weightedScoreByMidi[selectedMidi] ?? 0;
      final interval = (midi - selectedMidi).abs();
      if (interval == 1 &&
          midiScore <= selectedScore * _semitoneConflictFactor) {
        return true;
      }
      if (interval == 12 &&
          midiScore <= selectedScore * _octaveConflictFactor) {
        return true;
      }
    }
    return false;
  }

  double _weightedPitchScore(double notePeak, double onsetPeak) {
    return (notePeak * 0.72) + (onsetPeak * 0.28);
  }

  double _estimateNoiseFloor(
    List<List<double>> noteMatrix, {
    required Set<int> candidateMidis,
  }) {
    if (noteMatrix.isEmpty || candidateMidis.isEmpty) {
      return 0;
    }

    final values = <double>[];
    final start = math.max(0, noteMatrix.length - tailFramesToInspect);
    for (var i = start; i < noteMatrix.length; i++) {
      final row = noteMatrix[i];
      for (final midi in candidateMidis) {
        final pitchIndex = midi - _lowestPianoMidi;
        if (pitchIndex < 0 || pitchIndex >= row.length) {
          continue;
        }
        values.add(row[pitchIndex]);
      }
    }
    if (values.isEmpty) {
      return 0;
    }
    values.sort();
    return values[values.length ~/ 2].clamp(0.0, 1.0);
  }

  double _tailPeak(List<List<double>> matrix, int pitchIndex) {
    if (matrix.isEmpty) {
      return 0;
    }
    final start = math.max(0, matrix.length - tailFramesToInspect);
    var peak = 0.0;
    for (var i = start; i < matrix.length; i++) {
      final row = matrix[i];
      if (pitchIndex >= row.length) {
        continue;
      }
      if (row[pitchIndex] > peak) {
        peak = row[pitchIndex];
      }
    }
    return peak;
  }

  double _computeRms(List<double> frame) {
    var energy = 0.0;
    for (final sample in frame) {
      energy += sample * sample;
    }
    return math.sqrt(energy / frame.length);
  }

  Iterable<int> _pianoCandidateMidis(Set<int> candidateMidis) {
    return candidateMidis.where(
      (midi) => midi >= _lowestPianoMidi && midi <= _highestPianoMidi,
    );
  }
}

class _BasicPitchOutputMatrix {
  const _BasicPitchOutputMatrix({
    required this.name,
    required this.matrix,
  });

  final String name;
  final List<List<double>> matrix;
}
