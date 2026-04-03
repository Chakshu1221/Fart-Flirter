"""
generate_dummy_model.py
───────────────────────
Run this script ONCE to generate a working (untrained) TFLite model
so you can test the Flutter app's UI and pipeline immediately —
without needing a real dataset yet.

The model will accept audio and return predictions, but they will be
random (50/50) until you train it with real data using train.py.

Usage:
  pip install tensorflow
  python generate_dummy_model.py

Output:
  assets/models/fart_classifier.tflite   ← ready to use in Flutter
"""

import os
import sys
import shutil
from pathlib import Path

try:
    import tensorflow as tf
except ImportError:
    print("ERROR: TensorFlow not found.")
    print("Run:  pip install tensorflow")
    sys.exit(1)

print(f"TensorFlow {tf.__version__} found ✅")

# ── Build model (same architecture as train.py) ───────────────────────────────
INPUT_SHAPE = (40, 128, 1)

inputs  = tf.keras.Input(shape=INPUT_SHAPE, name="mfcc_input")
x       = tf.keras.layers.Conv2D(32, (3, 3), padding="same", activation="relu")(inputs)
x       = tf.keras.layers.BatchNormalization()(x)
x       = tf.keras.layers.MaxPooling2D((2, 2))(x)
x       = tf.keras.layers.Dropout(0.25)(x)
x       = tf.keras.layers.Conv2D(64, (3, 3), padding="same", activation="relu")(x)
x       = tf.keras.layers.BatchNormalization()(x)
x       = tf.keras.layers.MaxPooling2D((2, 2))(x)
x       = tf.keras.layers.Dropout(0.25)(x)
x       = tf.keras.layers.Conv2D(64, (3, 3), padding="same", activation="relu")(x)
x       = tf.keras.layers.BatchNormalization()(x)
x       = tf.keras.layers.GlobalAveragePooling2D()(x)
x       = tf.keras.layers.Dense(128, activation="relu")(x)
x       = tf.keras.layers.Dropout(0.4)(x)
outputs = tf.keras.layers.Dense(2, activation="softmax", name="output")(x)

model = tf.keras.Model(inputs, outputs, name="fart_classifier")
print("Model built ✅")

# ── Convert to TFLite ─────────────────────────────────────────────────────────
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()

# Save into Flutter assets folder inside this repo (absolute robust path)
base_dir = Path(__file__).resolve().parent
flutter_assets_dir = base_dir / "assets" / "models"
# Also keep an extra copy at root assets/ (for repository logic if expected there)
root_assets_dir = Path(__file__).resolve().parents[1] / "assets" / "models"

out_path = flutter_assets_dir / "fart_classifier.tflite"
out_path.parent.mkdir(parents=True, exist_ok=True)
with open(out_path, "wb") as f:
    f.write(tflite_model)

# copy to root assets if not the same path
root_out_path = root_assets_dir / "fart_classifier.tflite"
root_out_path.parent.mkdir(parents=True, exist_ok=True)
shutil.copy2(out_path, root_out_path)

size_kb = len(tflite_model) / 1024
print(f"Saved → {out_path}  ({size_kb:.1f} KB) ✅")
print(f"Copied → {root_out_path} ✅")

# ── Verify shapes ─────────────────────────────────────────────────────────────
interp = tf.lite.Interpreter(model_content=tflite_model)
interp.allocate_tensors()
inp_detail = interp.get_input_details()[0]
out_detail = interp.get_output_details()[0]

print(f"\nVerification:")
print(f"  Input  shape : {inp_detail['shape']}  dtype: {inp_detail['dtype'].__name__}")
print(f"  Output shape : {out_detail['shape']}  dtype: {out_detail['dtype'].__name__}")

import numpy as np
dummy_input = np.zeros(inp_detail["shape"], dtype=np.float32)
interp.set_tensor(inp_detail["index"], dummy_input)
interp.invoke()
probs = interp.get_tensor(out_detail["index"])
print(f"  Sample output: non_fart={probs[0][0]:.3f}, fart={probs[0][1]:.3f}")

print("\n✅ Done! The .tflite file is ready.")
print("   NOTE: This is an UNTRAINED model. Predictions are random.")
print("   Train it properly with python/train_model/train.py once you have data.")