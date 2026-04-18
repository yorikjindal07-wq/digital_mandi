# Digital Mandi — AI-Powered Offline Smart Farming Assistant

> A production-grade, fully offline Android app that helps Indian farmers detect
> crop diseases, get crop recommendations, chat with an AI assistant in Hindi/Punjabi,
> and receive treatment guidance — all without internet access.

---

## Project Architecture

```
digital_mandi/
├── plant_disease_app/          Flutter Android App (100% offline-capable)
│   ├── lib/
│   │   ├── core/               Constants, theme, localizations
│   │   ├── data/               SQLite local database
│   │   ├── models/             Data models (Prediction, Crop, Chat, Report)
│   │   ├── providers/          AppProvider (global state)
│   │   ├── services/           ML, Chatbot, TTS, STT, Sync services
│   │   ├── screens/            Home, Camera, Result, Chat, Crop, Weather, History
│   │   └── widgets/            Reusable UI widgets
│   └── assets/
│       ├── model/              TFLite model files (vision + crop)
│       └── data/               JSON data assets
│
├── ml_pipeline/vision/         PyTorch training + TFLite export
│   ├── model.py                DiseaseModel (ResNet18) + CropModel (MLP)
│   ├── dataset.py              DataLoader with heavy augmentation
│   ├── train.py                Disease detection training (progressive unfreeze)
│   ├── train_crop_model.py     Crop recommendation training
│   └── export_pipeline.py      PyTorch → ONNX → TFLite with INT8 quant
│
└── backend/                    FastAPI (optional cloud sync)
    ├── app/main.py
    └── app/api/routes.py
```

---

## Features

| Feature | Description | Works Offline |
|---------|-------------|---------------|
| Disease Detection | Camera → TFLite ResNet18 → disease label + treatment | ✅ |
| Crop Recommendation | Soil/climate inputs → ML model → top 3 crops | ✅ |
| AI Chatbot | Keyword-intent → knowledge base → localised response | ✅ |
| Voice Input (STT) | On-device speech recognition (speech_to_text) | ✅ |
| Voice Output (TTS) | Android TTS in Hindi, Punjabi, English | ✅ |
| Weather History | Preloaded seasonal data for 4 Indian regions | ✅ |
| Report History | SQLite local storage of all scans | ✅ |
| Multilingual UI | English, Hindi, Punjabi (expandable) | ✅ |
| Backend Sync | POST reports when internet available | ❌ (optional) |

---

## Quick Start

### Prerequisites
- Flutter 3.22+ (`flutter --version`)
- Android Studio / VS Code with Flutter extension
- Python 3.10+ (for ML pipeline)
- Android device or emulator (API 21+)

---

### Step 1 — Clone and set up Flutter app

```bash
cd plant_disease_app
flutter pub get
```

### Step 2 — Add TFLite model files

The TFLite model files are not in the repo (too large).
**Option A: Use a pre-trained model (for testing)**

Download the PlantVillage TFLite model and place it at:
```
plant_disease_app/assets/model/vision_model.tflite
```

For the crop model, a dummy 7→22 output model works for UI testing.

**Option B: Train your own model (for production)**

See the ML Pipeline section below.

### Step 3 — Run the app

```bash
cd plant_disease_app
flutter run
```

For release APK:
```bash
flutter build apk --release --target-platform android-arm64
```
The APK will be at `build/app/outputs/flutter-apk/app-release.apk`

---

## ML Pipeline — Train and Export Models

### Setup Python environment

```bash
cd ml_pipeline
pip install -r requirements.txt
```

### Dataset setup

**Disease Detection:**
Download PlantVillage dataset from Kaggle:
https://www.kaggle.com/datasets/arjuntejaswi/plant-village

Organise into:
```
ml_pipeline/vision/data/
  train/
    early_blight/   (1000+ images)
    healthy/        (1000+ images)
    late_blight/    (1000+ images)
    leaf_mold/      (1000+ images)
  val/
    early_blight/   (200+ images)
    ... (same structure)
```

**Crop Recommendation:**
Download from: https://www.kaggle.com/datasets/atharvaingle/crop-recommendation-dataset
Save as: `ml_pipeline/vision/data/Crop_recommendation.csv`

### Train disease detection model

```bash
cd ml_pipeline/vision
python train.py
```

Expected output:
- Training for 30 epochs with 3 progressive unfreezing phases
- Best model saved to `best_vision_model.pth`
- Training curves saved to `training_curves.png`
- Target: >92% validation accuracy

### Train crop recommendation model

```bash
python train_crop_model.py
```

Expected: >97% accuracy (tabular data is easy for MLP).

### Export to TFLite

```bash
# Full pipeline: PyTorch → ONNX → TF SavedModel → TFLite INT8
python export_pipeline.py --checkpoint best_vision_model.pth --data-dir data

# Crop model
python export_pipeline.py --crop-model
```

### Copy models to Flutter app

```bash
cp vision_model.tflite ../plant_disease_app/assets/model/
cp crop_model.tflite   ../plant_disease_app/assets/model/
```

---

## Backend (Optional — Cloud Sync)

The backend is only needed for syncing reports when internet is available.
The Flutter app works completely without it.

```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

API docs available at: http://localhost:8000/docs

Update `AppConstants.backendBaseUrl` in `lib/core/constants.dart` to point to
your server IP.

---

## Adding a New Language

1. Add the language code to `AppConstants.supportedLanguages` in `constants.dart`
2. Add translations to `AppLocalizations._strings` in `localization.dart`
3. Add translations to `chatbot_responses.json` and `treatments.json`
4. Add the BCP-47 locale mapping in `TTSService._languageToLocale()`
5. Add font assets in `pubspec.yaml` if the language needs a custom font

---

## Adding a New Disease Class

1. Add images to `data/train/<disease_name>/` and `data/val/<disease_name>/`
2. Retrain with `python train.py`
3. Re-export with `python export_pipeline.py`
4. Add the disease label to `AppConstants.diseaseLabels`
5. Add treatment data to `assets/data/treatments.json`
6. Add chatbot knowledge to `assets/data/chatbot_responses.json`

---

## Performance Benchmarks (Target)

| Model | Size | Accuracy | Inference (Pixel 6) |
|-------|------|----------|---------------------|
| Disease (ResNet18 INT8) | ~12 MB | >92% | ~80ms |
| Disease (EfficientNet-B0 INT8) | ~5 MB | >93% | ~55ms |
| Crop (MLP INT8) | <50 KB | >97% | <5ms |

---

## Production Checklist

- [ ] Replace debug baseUrl in `constants.dart` with production URL
- [ ] Enable ProGuard in `android/app/build.gradle.kts`
- [ ] Sign APK with release keystore
- [ ] Test on low-end device (2GB RAM, Snapdragon 450)
- [ ] Test full offline mode (airplane mode from fresh install)
- [ ] Add crash reporting (Firebase Crashlytics)
- [ ] Add model update mechanism (federated API endpoint)
- [ ] Localisation testing with native speakers
- [ ] Accessibility audit (large text, contrast ratios)

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter 3.22 (Dart) |
| State Management | Provider |
| Local Database | SQLite (sqflite) |
| ML Runtime | TFLite (tflite_flutter) |
| Speech Input | speech_to_text (on-device) |
| Speech Output | flutter_tts (Android TTS) |
| Training | PyTorch + torchvision |
| Model Export | ONNX + TFLite INT8 |
| Backend | FastAPI + SQLAlchemy |
| Connectivity | connectivity_plus |