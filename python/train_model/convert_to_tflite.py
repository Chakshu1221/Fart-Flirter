"""
convert_to_tflite.py
────────────────────
Converts the trained Keras model to a quantised TFLite file.

Usage:
  python convert_to_tflite.py

Output:
  ../../assets/models/fart_classifier.tflite   ← drop-in for Flutter
"""

import numpy as np
import tensorflow as tf
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[1]  # /workspaces/Fart-Flirter

# Support both repo and legacy nested path arrangements
Keras_candidates = [
    REPO_ROOT / "saved_model" / "fart_model.keras",
    REPO_ROOT / "python" / "train_model" / "saved_model" / "fart_model.keras",
]
KERAS_MODEL = next((p for p in Keras_candidates if p.exists()), Keras_candidates[0])
if not KERAS_MODEL.exists():
    raise FileNotFoundError(
        f"Could not find Keras model file in expected locations:\n"
        f"  1) {Keras_candidates[0]}\n"
        f"  2) {Keras_candidates[1]}\n"
        f"Run training first: python python/train_model/train.py"
    )

TFLITE_OUT = REPO_ROOT / "assets" / "models" / "fart_classifier.tflite"  # root output path
PROCESSED_DIR = REPO_ROOT / "processed"


def representative_dataset():
    """
    Feed a sample of training data so TFLite can calibrate INT8 quantisation.
    Only needed for full-integer quantisation.
    """
    X = np.load(PROCESSED_DIR / "X_train.npy")
    for i in range(min(100, len(X))):
        yield [X[i:i+1]]   # shape (1, 40, 128, 1)


def convert():
    print(f"📦 Loading {KERAS_MODEL}…")
    model = tf.keras.models.load_model(str(KERAS_MODEL))

    converter = tf.lite.TFLiteConverter.from_keras_model(model)

    # ── Dynamic-range quantisation (float32 → int8 weights only) ─────────────
    # Reduces model size ~4× with minimal accuracy loss.
    # Switch to FULL_INT8 if you need the fastest inference on ARM.
    converter.optimizations = [tf.lite.Optimize.DEFAULT]

    # Uncomment for full INT8 quantisation (requires representative_dataset):
    # converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    # converter.inference_input_type  = tf.int8
    # converter.inference_output_type = tf.int8
    # converter.representative_dataset = representative_dataset

    tflite_model = converter.convert()

    TFLITE_OUT.parent.mkdir(parents=True, exist_ok=True)
    TFLITE_OUT.write_bytes(tflite_model)

    size_kb = TFLITE_OUT.stat().st_size / 1024
    print(f"✅  Saved {TFLITE_OUT}  ({size_kb:.1f} KB)")

    # ── Quick sanity-check inference ─────────────────────────────────────────
    interpreter = tf.lite.Interpreter(model_path=str(TFLITE_OUT))
    interpreter.allocate_tensors()
    inp  = interpreter.get_input_details()[0]
    out  = interpreter.get_output_details()[0]
    print(f"   Input  shape : {inp['shape']}  dtype: {inp['dtype']}")
    print(f"   Output shape : {out['shape']}  dtype: {out['dtype']}")

    # Run one dummy inference
    dummy = np.zeros(inp['shape'], dtype=np.float32)
    interpreter.set_tensor(inp['index'], dummy)
    interpreter.invoke()
    probs = interpreter.get_tensor(out['index'])
    print(f"   Dummy output : {probs}  (non_fart, fart)")


if __name__ == "__main__":
    convert()