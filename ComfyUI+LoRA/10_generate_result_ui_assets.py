import json
import os
import random
import time
import urllib.parse
import urllib.request


COMFYUI_URL = "http://127.0.0.1:8188"
CHECKPOINT = "anything-v5-PrtRE.safetensors"
PROJECT_ASSET_ROOT = r"D:\GodotProject\桌面挂机\assets\generated\ui"

GLOBAL_PREFIX = (
    "masterpiece, best quality, stylized game ui asset, dark iron wasteland, industrial relic design, "
    "clean centered composition, transparent background, readable game interface art, "
)

NEGATIVE_PROMPT = (
    "worst quality, blurry, low quality, text, watermark, signature, borderless photograph, "
    "cute cartoon, chibi, 3d render, photorealistic, cluttered, busy background"
)

ASSETS = [
    {
        "id": "RESULT_CARD",
        "filename": "result_card_bg.png",
        "width": 768,
        "height": 384,
        "prompt": (
            "horizontal result card background, dark metal plate, furnace orange edge glow, cold blue energy lines, "
            "industrial reward panel, empty center area for text"
        ),
    },
    {
        "id": "RESULT_BOSS",
        "filename": "result_boss_bg.png",
        "width": 768,
        "height": 256,
        "prompt": (
            "horizontal boss reward banner background, heavy industrial metal crest, molten core highlight, "
            "victory reward header panel, dark steel and furnace orange"
        ),
    },
    {
        "id": "FRAME_COMMON",
        "filename": "frame_common.png",
        "width": 256,
        "height": 256,
        "prompt": (
            "square equipment frame, dark gunmetal border, subtle industrial bolts, common rarity, "
            "transparent center, ui frame"
        ),
    },
    {
        "id": "FRAME_RARE",
        "filename": "frame_rare.png",
        "width": 256,
        "height": 256,
        "prompt": (
            "square equipment frame, blue energy border, industrial metallic corners, rare rarity, "
            "transparent center, ui frame"
        ),
    },
    {
        "id": "FRAME_EPIC",
        "filename": "frame_epic.png",
        "width": 256,
        "height": 256,
        "prompt": (
            "square equipment frame, purple arc energy border, industrial runic metal corners, epic rarity, "
            "transparent center, ui frame"
        ),
    },
    {
        "id": "FRAME_LEGENDARY",
        "filename": "frame_legendary.png",
        "width": 256,
        "height": 256,
        "prompt": (
            "square equipment frame, golden furnace glow border, engraved heavy metal corners, legendary rarity, "
            "transparent center, ui frame"
        ),
    },
    {
        "id": "FRAME_ANCIENT",
        "filename": "frame_ancient.png",
        "width": 256,
        "height": 256,
        "prompt": (
            "square equipment frame, orange red ancient molten border, cracked relic metal corners, ancient rarity, "
            "transparent center, ui frame"
        ),
    },
]


def build_workflow(prompt_text, width, height, seed, filename_prefix):
    return {
        "3": {
            "class_type": "KSampler",
            "inputs": {
                "seed": seed,
                "steps": 28,
                "cfg": 7.5,
                "sampler_name": "euler_ancestral",
                "scheduler": "normal",
                "denoise": 1.0,
                "model": ["4", 0],
                "positive": ["6", 0],
                "negative": ["7", 0],
                "latent_image": ["5", 0],
            },
        },
        "4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": CHECKPOINT}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"width": width, "height": height, "batch_size": 1}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"text": GLOBAL_PREFIX + prompt_text, "clip": ["4", 1]}},
        "7": {"class_type": "CLIPTextEncode", "inputs": {"text": NEGATIVE_PROMPT, "clip": ["4", 1]}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
        "9": {"class_type": "SaveImage", "inputs": {"filename_prefix": filename_prefix, "images": ["8", 0]}},
    }


def queue_prompt(workflow):
    data = json.dumps({"prompt": workflow}).encode("utf-8")
    req = urllib.request.Request(
        f"{COMFYUI_URL}/prompt",
        data=data,
        headers={"Content-Type": "application/json"},
    )
    resp = urllib.request.urlopen(req, timeout=30)
    return json.loads(resp.read())["prompt_id"]


def wait_for_completion(prompt_id, timeout=300):
    start = time.time()
    while time.time() - start < timeout:
        try:
            resp = urllib.request.urlopen(f"{COMFYUI_URL}/history/{prompt_id}", timeout=10)
            history = json.loads(resp.read())
            if prompt_id in history:
                return history[prompt_id]
        except Exception:
            pass
        time.sleep(2)
    raise TimeoutError(f"Generation timed out after {timeout}s")


def download_image(filename, subfolder, output_type="output"):
    params = urllib.parse.urlencode({"filename": filename, "subfolder": subfolder, "type": output_type})
    resp = urllib.request.urlopen(f"{COMFYUI_URL}/view?{params}", timeout=30)
    return resp.read()


def generate_asset(asset, index, total):
    os.makedirs(PROJECT_ASSET_ROOT, exist_ok=True)
    seed = random.randint(1, 2**31 - 1)
    print(f"[{index}/{total}] generating {asset['filename']}")
    workflow = build_workflow(asset["prompt"], asset["width"], asset["height"], seed, f"ui_{asset['id']}")
    prompt_id = queue_prompt(workflow)
    result = wait_for_completion(prompt_id)

    images_info = None
    for node_output in result.get("outputs", {}).values():
        if "images" in node_output:
            images_info = node_output["images"]
            break
    if not images_info:
        raise RuntimeError(f"No images found for {asset['id']}")

    image_info = images_info[0]
    image_data = download_image(
        image_info["filename"],
        image_info.get("subfolder", ""),
        image_info.get("type", "output"),
    )
    output_path = os.path.join(PROJECT_ASSET_ROOT, asset["filename"])
    with open(output_path, "wb") as f:
        f.write(image_data)
    print(f"  saved -> {output_path}")


def main():
    success = []
    failed = []
    for index, asset in enumerate(ASSETS, start=1):
        try:
            generate_asset(asset, index, len(ASSETS))
            success.append(asset["id"])
        except Exception as exc:
            print(f"  failed -> {asset['id']}: {exc}")
            failed.append(asset["id"])
    print("\n=== Summary ===")
    print(f"Success: {len(success)} -> {', '.join(success) if success else 'none'}")
    print(f"Failed : {len(failed)} -> {', '.join(failed) if failed else 'none'}")


if __name__ == "__main__":
    main()
