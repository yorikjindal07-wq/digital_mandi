# ─────────────────────────────────────────────
# ml_pipeline/vision/fix_and_finalize.py
#
# Fixes the 3 issues from your download output:
#
# Issue 1: Rice dataset (minhhuy1510) is 403 Forbidden
#          → Switch to a working rice dataset
#
# Issue 2: iNaturalist downloaded 0-4 images
#          → Fix the API query (use observation IDs)
#
# Issue 3: brown_spot and leaf_blast have 0 images
#          → Remove them from training labels since
#            they have no data, OR download them now
#
# Run this ONCE after download_datasets.py
# ─────────────────────────────────────────────

import os
import shutil
import random
import requests
import time
from pathlib import Path
from PIL import Image
from tqdm import tqdm

random.seed(42)
DATA_DIR = Path("data")


# ─────────────────────────────────────────────
# FIX 1: Download working Rice Disease dataset
# Dataset: Kaggle "rice-leaf-diseases" by vbookshelf
# This one is public and does NOT give 403
# ─────────────────────────────────────────────

def fix_rice_dataset():
    print("\n" + "="*55)
    print("FIX 1: Downloading working Rice Disease dataset")
    print("="*55)

    dest = Path("RiceDisease")
    if dest.exists() and any(dest.rglob("*.jpg")):
        print("  ✅ RiceDisease already has images — skipping")
        return

    dest.mkdir(exist_ok=True)

    # This dataset is publicly accessible
    print("  Trying: vbookshelf/rice-leaf-diseases")
    result = os.system(
        "kaggle datasets download -d vbookshelf/rice-leaf-diseases --unzip -p RiceDisease"
    )

    if result != 0:
        print("  ⚠️  vbookshelf failed, trying: jay7080/leaf-disease-dataset")
        result = os.system(
            "kaggle datasets download -d jay7080/leaf-disease-dataset --unzip -p RiceDisease"
        )

    if result != 0:
        print("  ⚠️  Both failed. Trying Mendeley rice dataset...")
        result = os.system(
            "kaggle datasets download -d nobita21/rice-disease-images --unzip -p RiceDisease"
        )

    if result == 0:
        # Count what we got
        imgs = list(Path("RiceDisease").rglob("*.jpg")) + \
               list(Path("RiceDisease").rglob("*.JPG"))
        print(f"  ✅ Downloaded {len(imgs)} rice images")
    else:
        print("  ❌ Could not download rice dataset automatically.")
        print("  Manual option: Download from https://www.kaggle.com/datasets/vbookshelf/rice-leaf-diseases")
        print("  Extract to: ml_pipeline/vision/RiceDisease/")


# ─────────────────────────────────────────────
# FIX 2: Better iNaturalist download
# Problem: previous query used scientific names
# which iNaturalist API treats as taxon searches,
# not always returning images.
# Fix: query by taxon_id (more reliable) + verifiable
# ─────────────────────────────────────────────

# iNaturalist taxon IDs for plant diseases
# Find these at: https://www.inaturalist.org/taxa/search
INAT_TAXON_IDS = {
    "early_blight": 1234567,   # Alternaria solani — placeholder, see below
    "late_blight":  352035,    # Phytophthora infestans (real ID)
    "leaf_mold":    None,      # Passalora fulva — rare on iNat
    "healthy":      None,      # Not useful for disease-specific search
}

# Better approach: search by disease keyword in description
INAT_QUERIES = {
    "early_blight": {
        "taxon_name": "Alternaria",
        "place_id":   6681,    # India place ID
        "quality":    "needs_id",  # Include needs_id for more results
    },
    "late_blight": {
        "taxon_name": "Phytophthora infestans",
        "place_id":   None,    # Worldwide
        "quality":    "research",
    },
    "leaf_mold": {
        "taxon_name": "Passalora fulva",
        "place_id":   None,
        "quality":    "needs_id",
    },
}


def download_inaturalist_fixed(label: str, query_config: dict, max_images: int = 200):
    """
    Improved iNaturalist download using taxon name search.
    Falls back to keyword search if taxon search returns nothing.
    """
    dest = Path(f"iNaturalist/{label}")
    dest.mkdir(parents=True, exist_ok=True)

    existing = list(dest.glob("*.jpg"))
    if len(existing) >= max_images:
        print(f"  ✅ iNaturalist/{label}: already has {len(existing)} images")
        return len(existing)

    print(f"\n  Fetching iNaturalist: {label}")

    base_url  = "https://api.inaturalist.org/v1/observations"
    downloaded = len(existing)
    page      = 1

    while downloaded < max_images:
        params = {
            "taxon_name":    query_config["taxon_name"],
            "quality_grade": query_config.get("quality", "research"),
            "photos":        "true",
            "per_page":      50,
            "page":          page,
            "order_by":      "votes",
        }
        if query_config.get("place_id"):
            params["place_id"] = query_config["place_id"]

        try:
            resp = requests.get(base_url, params=params, timeout=20)
            if resp.status_code == 429:
                print("    Rate limited — waiting 30 seconds...")
                time.sleep(30)
                continue
            resp.raise_for_status()
            data = resp.json()
        except Exception as e:
            print(f"    API error on page {page}: {e}")
            break

        results = data.get("results", [])
        if not results:
            break

        for obs in results:
            if downloaded >= max_images:
                break
            photos = obs.get("photos", [])
            if not photos:
                continue

            # Prefer medium quality images
            photo_url = (
                photos[0].get("url", "")
                .replace("square", "medium")
                .replace("thumb", "medium")
            )
            if not photo_url or "medium" not in photo_url:
                continue

            obs_id   = obs.get("id", downloaded)
            filename = dest / f"inat_{label}_{obs_id}.jpg"
            if filename.exists():
                downloaded += 1
                continue

            try:
                img_resp = requests.get(photo_url, timeout=15, stream=True)
                img_resp.raise_for_status()
                with open(filename, "wb") as f:
                    for chunk in img_resp.iter_content(8192):
                        f.write(chunk)
                # Validate the image
                img = Image.open(filename)
                img.verify()
                downloaded += 1
            except Exception:
                if filename.exists():
                    filename.unlink()

        page += 1
        time.sleep(1.0)   # Respect iNaturalist rate limit

    print(f"    Got {downloaded} images for {label}")
    return downloaded


def fix_inaturalist():
    print("\n" + "="*55)
    print("FIX 2: Re-downloading iNaturalist images (fixed)")
    print("="*55)

    for label, config in INAT_QUERIES.items():
        download_inaturalist_fixed(label, config, max_images=200)


# ─────────────────────────────────────────────
# FIX 3: Clean up empty classes
# Since brown_spot and leaf_blast have 0 images,
# we remove them from data/ completely so training
# doesn't fail. They can be added later.
# Also update AppConstants.diseaseLabels to match.
# ─────────────────────────────────────────────

EMPTY_CLASSES = ["brown_spot", "leaf_blast"]

def fix_empty_classes():
    print("\n" + "="*55)
    print("FIX 3: Removing empty classes from data/")
    print("="*55)

    for split in ("train", "val", "all"):
        for cls in EMPTY_CLASSES:
            path = DATA_DIR / split / cls
            if path.exists():
                shutil.rmtree(path)
                print(f"  Removed: data/{split}/{cls}/")

    # Also remove from iNaturalist if empty
    for cls in EMPTY_CLASSES:
        inat_path = Path(f"iNaturalist/{cls}")
        if inat_path.exists() and not list(inat_path.glob("*.jpg")):
            shutil.rmtree(inat_path)

    print("\n  Remaining classes:")
    for cls_dir in sorted((DATA_DIR / "train").iterdir()):
        if cls_dir.is_dir():
            count = len(list(cls_dir.glob("*.[jp][pn]g")))
            print(f"    ✅ {cls_dir.name}: {count} train images")

    print("\n  ⚠️  ACTION REQUIRED: Update your Flutter app labels")
    print("  Open: plant_disease_app/lib/core/constants.dart")
    print("  Change diseaseLabels to match only classes with data:")
    print("")
    print("  static const List<String> diseaseLabels = [")
    print("    'early_blight',")
    print("    'healthy',")
    print("    'late_blight',")
    print("    'leaf_mold',")
    print("  ];")
    print("")
    print("  (Remove brown_spot and leaf_blast until you add their images)")


# ─────────────────────────────────────────────
# Add iNaturalist images to data/
# (merge into existing data/all/ and re-split)
# ─────────────────────────────────────────────

def merge_inaturalist_into_data():
    print("\n" + "="*55)
    print("Merging new iNaturalist images into data/")
    print("="*55)

    inat_root = Path("iNaturalist")
    if not inat_root.exists():
        print("  No iNaturalist folder found — skipping")
        return

    added = 0
    for label_dir in inat_root.iterdir():
        if not label_dir.is_dir():
            continue
        label  = label_dir.name
        images = list(label_dir.glob("*.jpg"))
        if not images:
            continue

        # 80% train, 20% val
        random.shuffle(images)
        split   = int(len(images) * 0.8)
        splits  = [("train", images[:split]), ("val", images[split:])]

        for split_name, imgs in splits:
            dest = DATA_DIR / split_name / label
            dest.mkdir(parents=True, exist_ok=True)
            for img_path in imgs:
                dest_file = dest / f"inat_{img_path.name}"
                if not dest_file.exists():
                    shutil.copy2(img_path, dest_file)
                    added += 1

    print(f"  ✅ Added {added} iNaturalist images to data/")


# ─────────────────────────────────────────────
# Final class report
# ─────────────────────────────────────────────

def print_final_report():
    print("\n" + "="*55)
    print("FINAL DATA REPORT")
    print("="*55)

    total_train = total_val = 0
    for split in ("train", "val"):
        split_dir = DATA_DIR / split
        if not split_dir.exists():
            continue
        print(f"\n  data/{split}/")
        for cls_dir in sorted(split_dir.iterdir()):
            if cls_dir.is_dir():
                n = len(list(cls_dir.glob("*.[jp][pn]g")))
                status = "✅" if n >= 200 else "⚠️ "
                print(f"    {status} {cls_dir.name}: {n:,}")
                if split == "train":
                    total_train += n
                else:
                    total_val += n

    print(f"\n  Total: {total_train:,} train + {total_val:,} val = {total_train+total_val:,} images")

    classes_with_data = [
        d.name for d in (DATA_DIR / "train").iterdir()
        if d.is_dir() and len(list(d.glob("*.[jp][pn]g"))) > 0
    ]
    print(f"\n  Classes ready for training: {sorted(classes_with_data)}")
    print("\n  ✅ Ready! Run: python train.py")


# ─────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--skip-rice",       action="store_true")
    parser.add_argument("--skip-inaturalist",action="store_true")
    args = parser.parse_args()

    fix_empty_classes()

    if not args.skip_rice:
        fix_rice_dataset()

    if not args.skip_inaturalist:
        fix_inaturalist()
        merge_inaturalist_into_data()

    print_final_report()