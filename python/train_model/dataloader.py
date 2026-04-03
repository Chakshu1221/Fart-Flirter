import os
import requests
from tqdm import tqdm
from pydub import AudioSegment

# =========================
# CONFIG
# =========================
API_KEY = "52J62Olh0KH1zHfkkr6Gv4or3haSjQZWEJPzBU7g"

BASE_DIR = "python/train_model/data"
FART_DIR = os.path.join(BASE_DIR, "fart")
NON_FART_DIR = os.path.join(BASE_DIR, "non_fart")

FART_QUERY = "fart"
NON_FART_QUERY = "noise"

NUM_FART = 0
NUM_NON_FART = 100

# =========================
# SETUP
# =========================
headers = {
    "Authorization": f"Token {API_KEY}"
}

os.makedirs(FART_DIR, exist_ok=True)
os.makedirs(NON_FART_DIR, exist_ok=True)

# =========================
# SEARCH API
# =========================
def search_sounds(query, page=1):
    url = "https://freesound.org/apiv2/search/text/"
    params = {
        "query": query,
        "filter": "duration:[0.5 TO 5]",
        "fields": "id,name,previews",
        "page": page,
        "page_size": 50
    }
    response = requests.get(url, headers=headers, params=params)
    return response.json()

# =========================
# DOWNLOAD FILE
# =========================
def download_file(url, filepath):
    response = requests.get(url, stream=True)
    with open(filepath, 'wb') as f:
        for chunk in response.iter_content(1024):
            f.write(chunk)

# =========================
# CONVERT TO WAV (16kHz mono)
# =========================
def convert_to_wav(input_path, output_path):
    try:
        audio = AudioSegment.from_file(input_path)
        audio = audio.set_frame_rate(16000).set_channels(1)
        audio.export(output_path, format="wav")
        os.remove(input_path)  # remove mp3 after conversion
    except Exception as e:
        print(f"Conversion failed: {e}")

# =========================
# DOWNLOAD + PROCESS
# =========================
def download_category(query, save_dir, target_count):
    downloaded = 0
    page = 1

    while downloaded < target_count:
        data = search_sounds(query, page)

        if "results" not in data:
            print("No results found.")
            break

        for sound in data["results"]:
            if downloaded >= target_count:
                break

            try:
                preview_url = sound["previews"]["preview-hq-mp3"]
                mp3_path = os.path.join(save_dir, f"{sound['id']}.mp3")
                wav_path = os.path.join(save_dir, f"{sound['id']}.wav")

                # Download
                download_file(preview_url, mp3_path)

                # Convert
                convert_to_wav(mp3_path, wav_path)

                downloaded += 1
                print(f"{save_dir}: {downloaded}/{target_count}")

            except Exception as e:
                print(f"Error: {e}")

        page += 1

    print(f"✅ Done: {save_dir}")

# =========================
# MAIN
# =========================
def main():
    print("🚀 Downloading FART sounds...")
    download_category(FART_QUERY, FART_DIR, NUM_FART)

    print("\n🚀 Downloading NON-FART sounds...")
    download_category(NON_FART_QUERY, NON_FART_DIR, NUM_NON_FART)

    print("\n🎉 ALL DONE! Dataset ready.")

# =========================
# RUN
# =========================
if __name__ == "__main__":
    main()
