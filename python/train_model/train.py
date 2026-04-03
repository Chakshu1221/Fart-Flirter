"""
train.py
────────
Trains a CNN classifier on MFCC spectrograms.

Run after preprocess.py:
  python train.py

Output:
  saved_model/fart_model.keras   ← best weights saved by callback
"""

import numpy as np
import tensorflow as tf
from pathlib import Path

PROCESSED_DIR = Path("processed")
MODEL_DIR     = Path("saved_model")
MODEL_DIR.mkdir(parents=True, exist_ok=True)

BATCH_SIZE = 32
EPOCHS     = 40

# Input shape: (40 MFCC coeffs, 128 frames, 1 channel)
INPUT_SHAPE = (40, 128, 1)
NUM_CLASSES = 2   # [non_fart, fart]


def build_model() -> tf.keras.Model:
    """
    Lightweight CNN suitable for mobile TFLite conversion.

    Architecture:
      Conv2D(32) → BatchNorm → MaxPool → Dropout
      Conv2D(64) → BatchNorm → MaxPool → Dropout
      Conv2D(64) → BatchNorm → GlobalAvgPool
      Dense(128) → Dropout → Dense(2, softmax)
    """
    inputs = tf.keras.Input(shape=INPUT_SHAPE, name="mfcc_input")

    x = tf.keras.layers.Conv2D(32, (3, 3), padding="same", activation="relu")(inputs)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.MaxPooling2D((2, 2))(x)
    x = tf.keras.layers.Dropout(0.25)(x)

    x = tf.keras.layers.Conv2D(64, (3, 3), padding="same", activation="relu")(x)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.MaxPooling2D((2, 2))(x)
    x = tf.keras.layers.Dropout(0.25)(x)

    x = tf.keras.layers.Conv2D(64, (3, 3), padding="same", activation="relu")(x)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)

    x = tf.keras.layers.Dense(128, activation="relu")(x)
    x = tf.keras.layers.Dropout(0.4)(x)
    outputs = tf.keras.layers.Dense(NUM_CLASSES, activation="softmax", name="output")(x)

    return tf.keras.Model(inputs, outputs, name="fart_classifier")


def main():
    # ── Load data ─────────────────────────────────────────────────────────────
    X_train = np.load(PROCESSED_DIR / "X_train.npy")
    y_train = np.load(PROCESSED_DIR / "y_train.npy")
    X_val   = np.load(PROCESSED_DIR / "X_val.npy")
    y_val   = np.load(PROCESSED_DIR / "y_val.npy")

    print(f"Train: {X_train.shape}  |  Val: {X_val.shape}")

    # ── Build & compile ───────────────────────────────────────────────────────
    model = build_model()
    model.summary()

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )

    # ── Callbacks ─────────────────────────────────────────────────────────────
    callbacks = [
        tf.keras.callbacks.ModelCheckpoint(
            str(MODEL_DIR / "fart_model.keras"),
            save_best_only=True,
            monitor="val_accuracy",
            verbose=1,
        ),
        tf.keras.callbacks.EarlyStopping(
            patience=8, restore_best_weights=True, verbose=1
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            factor=0.5, patience=4, verbose=1
        ),
    ]

    # ── Train ─────────────────────────────────────────────────────────────────
    model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        batch_size=BATCH_SIZE,
        epochs=EPOCHS,
        callbacks=callbacks,
    )

    print(f"\n✅  Best model saved to {MODEL_DIR}/fart_model.keras")
    print("    Run convert_to_tflite.py next.")


if __name__ == "__main__":
    main()