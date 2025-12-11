// Stub file for tflite_flutter on web platform
// This allows the code to compile on web even though tflite_flutter doesn't support it

class Interpreter {
  Interpreter.fromAsset(String assetName, {InterpreterOptions? options}) {
    throw UnsupportedError('TensorFlow Lite is not supported on web platform');
  }
  
  void run(Object input, Object output) {
    throw UnsupportedError('TensorFlow Lite is not supported on web platform');
  }
  
  void close() {}
}

class InterpreterOptions {
  InterpreterOptions();
}

