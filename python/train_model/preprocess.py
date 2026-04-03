"""
preprocess.py
─────────────
Converts a dataset of .wav files into numpy MFCC arrays ready for training.

Dataset structure expected:
  data/
    fart/        ← positive samples (.wav)
    non_fart/    ← negative samples (.wav)

Output:
  processed/X_train.npy   shape (N, 40, 128, 1)
  processed/y_train.npy   shape (N,)
  processed/X_val.npy
  processed/y_val.npy
"""

import os
import numpy as np
import librosa
from sklearn.model_selection import train_test_split
from pathlib import Path

# ── Hyper-parameters (must match audio_processor.dart) ─────────────────────
SAMPLE_RATE   = 44100
DURATION      = 5.0        # seconds — clips longer than this are trimmed
NUM_MFCC      = 40
NUM_FRAMES    = 128
HOP_LENGTH    = int(SAMPLE_RATE * DURATION / NUM_FRAMES)   # ≈ 1723 for 5s
N_FFT         = 512
# All paths are anchored to repo root (Fart-Flirter)
SCRIPT_DIR    = Path(__file__).resolve().parent
REPO_ROOT     = SCRIPT_DIR.parents[1]   # /workspaces/Fart-Flirter
DATA_DIR      = REPO_ROOT / "python" / "train_model" / "data"
if not DATA_DIR.exists():
    # fallback: root-level data/ for future layout
    DATA_DIR = REPO_ROOT / "data"
    print(f"⚠️  DATA_DIR fallback to {DATA_DIR}")
OUT_DIR       = REPO_ROOT / "processed"
VAL_SPLIT     = 0.2
RANDOM_SEED   = 42

CLASSES = {"fart": 1, "non_fart": 0}


def load_audio(path: Path) -> np.ndarray:
    """Load audio file, resample to SAMPLE_RATE, trim/pad to DURATION."""
    y, sr = librosa.load(str(path), sr=SAMPLE_RATE, mono=True)
    target_len = int(SAMPLE_RATE * DURATION)
    if len(y) > target_len:
        y = y[:target_len]
    else:
        y = np.pad(y, (0, target_len - len(y)))
    return y


def extract_mfcc(y: np.ndarray) -> np.ndarray:
    """Return MFCC array of shape (NUM_MFCC, NUM_FRAMES, 1)."""
    mfcc = librosa.feature.mfcc(
        y=y,
        sr=SAMPLE_RATE,
        n_mfcc=NUM_MFCC,
        n_fft=N_FFT,
        hop_length=HOP_LENGTH,
    )
    # Trim or pad time axis to NUM_FRAMES
    if mfcc.shape[1] > NUM_FRAMES:
        mfcc = mfcc[:, :NUM_FRAMES]
    else:
        pad = NUM_FRAMES - mfcc.shape[1]
        mfcc = np.pad(mfcc, ((0, 0), (0, pad)))

    # Add channel dim → (40, 128, 1)
    return mfcc[..., np.newaxis].astype(np.float32)


def build_dataset():
    X, y = [], []
    for class_name, label in CLASSES.items():
        class_dir = DATA_DIR / class_name
        if not class_dir.exists():
            print(f"⚠️  Missing directory: {class_dir}")
            continue
        files = list(class_dir.glob("*.wav"))
        print(f"  {class_name}: {len(files)} files")
        for fp in files:
            try:
                audio = load_audio(fp)
                feat  = extract_mfcc(audio)
                X.append(feat)
                y.append(label)
            except Exception as e:
                print(f"  ⚠️  Skipping {fp.name}: {e}")

    return np.array(X, dtype=np.float32), np.array(y, dtype=np.int32)


def main():
    print("🔬 Preprocessing dataset…")
    X, y = build_dataset()
    print(f"  Total samples: {len(X)}  |  Shape: {X.shape}")

    split = VAL_SPLIT
    if len(X) < 10:
        split = 0.5

    X_train, X_val, y_train, y_val = train_test_split(
        X, y, test_size=split, random_state=RANDOM_SEED, stratify=y if len(np.unique(y)) > 1 else None
    )

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    np.save(OUT_DIR / "X_train.npy", X_train)
    np.save(OUT_DIR / "y_train.npy", y_train)
    np.save(OUT_DIR / "X_val.npy",   X_val)
    np.save(OUT_DIR / "y_val.npy",   y_val)

    print(f"✅  Saved to {OUT_DIR}/")
    print(f"   Train: {len(X_train)}  |  Val: {len(X_val)}")


if __name__ == "__main__":
    main()