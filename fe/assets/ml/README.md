Place your exported Basic Pitch TensorFlow Lite model here as:

`assets/ml/basic_pitch.tflite`

The microphone input adapter will try to use this model first.
If the asset is missing or fails to load, the app automatically falls back to
the current FFT-based detector so microphone mode can still run.
