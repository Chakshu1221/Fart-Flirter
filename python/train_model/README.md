# Fart Flirter — ML Training Pipeline

This folder contains everything you need to train the `fart_classifier.tflite`
model that powers on-device inference in the Flutter app.

---

## 1. Prerequisites

```bash
cd python/train_model
pip install -r requirements.txt
```

---

## 2. Collect Your Dataset

Create this folder structure:

```
python/train_model/data/
  fart/          ← .wav files of actual fart sounds
  non_fart/      ← .wav files of speech, claps, noise, etc.
```

**Minimum:** 50–100 samples per class.  
**Recommended:** 200+ per class for reliable accuracy.

### Where to get fart sounds
- Record real ones 🙃
- Free SFX sites: freesound.org, zapsplat.com → search "fart"
- YouTube SFX compilations (download as WAV)

### Negative samples (non_fart)
- Speech clips (any language)
- Hand claps, sneezes, coughs
- Background noise (wind, street, keyboard)
- Burps (model should reject these too)

**Format:** Mono WAV, any sample rate (script resamples to 44100 Hz automatically).

---

## 3. Preprocess

```bash
python preprocess.py
```

Outputs `processed/X_train.npy`, `y_train.npy`, `X_val.npy`, `y_val.npy`.  
Each sample is a `(40, 128, 1)` MFCC tensor.

---

## 4. Train

```bash
python train.py
```

- Trains a small CNN (~200 KB after quantisation)
- EarlyStopping kicks in around epoch 15–30
- Best model saved to `saved_model/fart_model.keras`

Target: **≥ 90% validation accuracy** before converting.

---

## 5. Convert to TFLite

```bash
python convert_to_tflite.py
```

Writes the quantised model directly to:
```
assets/models/fart_classifier.tflite
```

The Flutter app will pick it up automatically on next build.

---

## 6. Verify in App

Run the Flutter app. On the home screen you should see:
> "Hold the button and let it rip 💨"

If you see "Model load failed…" the `.tflite` path is wrong — check `pubspec.yaml` assets.

---

## Model Architecture Summary

```
Input (1, 40, 128, 1)
  → Conv2D(32, 3×3) → BatchNorm → MaxPool(2×2) → Dropout(0.25)
  → Conv2D(64, 3×3) → BatchNorm → MaxPool(2×2) → Dropout(0.25)
  → Conv2D(64, 3×3) → BatchNorm → GlobalAvgPool
  → Dense(128) → Dropout(0.4)
  → Dense(2, softmax)   [non_fart, fart]
```

**Model size (quantised):** ~150–250 KB  
**Inference time (mid-range phone):** < 50 ms

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Low accuracy (< 80%) | Add more diverse samples; try data augmentation (pitch shift, time stretch) |
| Model always predicts non_fart | Check class balance; add more fart samples |
| TFLite conversion error | Ensure TF ≥ 2.13 and model saved with `.keras` extension |
| App crashes on inference | Verify input shape matches `(1, 40, 128, 1)` in `fart_classifier_service.dart` |