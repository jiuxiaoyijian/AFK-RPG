import json
import os
import random
import time
import urllib.parse
import urllib.request


COMFYUI_URL = "http://127.0.0.1:8188"
CHECKPOINT = "anything-v5-PrtRE.safetensors"
PROJECT_ASSET_ROOT = r"D:\GodotProject\桌面挂机\assets\generated\icons"

GLOBAL_PREFIX = (
    "masterpiece, best quality, stylized game icon, dark iron wasteland, industrial relic aesthetic, "
    "centered composition, transparent background, readable symbol, "
)

NEGATIVE_PROMPT = (
    "worst quality, blurry, low quality, text, watermark, signature, realistic photo, 3d render, "
    "cute cartoon, cluttered background, complex scene"
)

ASSETS = [
    {
        "id": "EQUIP_WEAPON",
        "filename": "equip_weapon.png",
        "width": 256,
        "height": 256,
        "prompt": "game icon, rugged wasteland blade weapon, scrap metal sword with furnace glow edge",
    },
    {
        "id": "EQUIP_HELMET",
        "filename": "equip_helmet.png",
        "width": 256,
        "height": 256,
        "prompt": "game icon, industrial scout helmet with visor and metal plating",
    },
    {
        "id": "EQUIP_ARMOR",
        "filename": "equip_armor.png",
        "width": 256,
        "height": 256,
        "prompt": "game icon, patched heavy armor chestplate with furnace core straps",
    },
    {
        "id": "EQUIP_GLOVES",
        "filename": "equip_gloves.png",
        "width": 256,
        "height": 256,
        "prompt": "game icon, combat gloves with wired knuckles and industrial wraps",
    },
    {
        "id": "DROP_LEGENDARY",
        "filename": "drop_legendary.png",
        "width": 256,
        "height": 256,
        "prompt": "game icon, legendary furnace core emblem, molten golden relic shard",
    },
    {
        "id": "DROP_STORE",
        "filename": "drop_store.png",
        "width": 256,
        "height": 256,
        "prompt": "game icon, reward crate with blue energy seal and metal clasps",
    },
    {
        "id": "DROP_SALVAGE",
        "filename": "drop_salvage.png",
        "width": 256,
        "height": 256,
        "prompt": "game icon, scrap pile with broken metal parts and orange sparks",
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
    workflow = build_workflow(asset["prompt"], asset["width"], asset["height"], seed, f"icon_{asset['id']}")
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
