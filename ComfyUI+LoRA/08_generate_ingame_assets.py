import json
import os
import random
import time
import urllib.parse
import urllib.request


COMFYUI_URL = "http://127.0.0.1:8188"
CHECKPOINT = "anything-v5-PrtRE.safetensors"
PROJECT_ASSET_ROOT = r"D:\GodotProject\桌面挂机\assets\generated"

GLOBAL_PREFIX = (
    "masterpiece, best quality, semi realistic 2d game art, "
    "dark iron wasteland, industrial ruins, furnace core energy, "
    "dark steel, rust red, furnace orange, cold blue highlights, "
    "readable silhouette, game ready concept, "
)

NEGATIVE_PROMPT = (
    "worst quality, low quality, blurry, text, watermark, signature, frame, border, "
    "cute chibi, bright cartoon, photorealistic, 3d render, modern city, "
    "extra limbs, duplicate, bad anatomy, cluttered composition"
)

ASSETS = [
    {
        "id": "CHAPTER_BG_01",
        "filename": "chapter_1_ruins.png",
        "subdir": "backgrounds",
        "width": 1024,
        "height": 576,
        "prompt": (
            "side scrolling action game background, ruined frontier, clear gameplay lane in foreground, "
            "broken barricades, ruined highway signs, collapsed industrial wall, drifting ash fog, "
            "distant dead city silhouette, dark and oppressive but readable composition"
        ),
    },
    {
        "id": "CHAPTER_BG_02",
        "filename": "chapter_2_mine.png",
        "subdir": "backgrounds",
        "width": 1024,
        "height": 576,
        "prompt": (
            "side scrolling action game background, scorched mine, clear gameplay lane in foreground, "
            "molten cracks, mine rails, pressure pipes, forge towers, furnace vents, drifting steam, "
            "industrial heat atmosphere, readable layered composition"
        ),
    },
    {
        "id": "SKILL_ICON_01",
        "filename": "core_whirlwind.png",
        "subdir": "icons",
        "width": 512,
        "height": 512,
        "prompt": (
            "game skill icon, whirlwind slash, spiral blade storm, metallic wind arc, orange sparks, "
            "blue steel rim light, centered composition, dark transparent style backdrop"
        ),
    },
    {
        "id": "SKILL_ICON_02",
        "filename": "core_deep_wound.png",
        "subdir": "icons",
        "width": 512,
        "height": 512,
        "prompt": (
            "game skill icon, deep wound, crimson slash mark, bleeding wound emblem, torn metal and blood streaks, "
            "red black palette, centered composition, dark transparent style backdrop"
        ),
    },
    {
        "id": "SKILL_ICON_03",
        "filename": "core_chain_lightning.png",
        "subdir": "icons",
        "width": 512,
        "height": 512,
        "prompt": (
            "game skill icon, chain lightning, blue white electric arcs chaining between furnace nodes, "
            "industrial energy sigil, centered composition, dark transparent style backdrop"
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
        "4": {
            "class_type": "CheckpointLoaderSimple",
            "inputs": {"ckpt_name": CHECKPOINT},
        },
        "5": {
            "class_type": "EmptyLatentImage",
            "inputs": {"width": width, "height": height, "batch_size": 1},
        },
        "6": {
            "class_type": "CLIPTextEncode",
            "inputs": {"text": prompt_text, "clip": ["4", 1]},
        },
        "7": {
            "class_type": "CLIPTextEncode",
            "inputs": {"text": NEGATIVE_PROMPT, "clip": ["4", 1]},
        },
        "8": {
            "class_type": "VAEDecode",
            "inputs": {"samples": ["3", 0], "vae": ["4", 2]},
        },
        "9": {
            "class_type": "SaveImage",
            "inputs": {"filename_prefix": filename_prefix, "images": ["8", 0]},
        },
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
    params = urllib.parse.urlencode(
        {"filename": filename, "subfolder": subfolder, "type": output_type}
    )
    resp = urllib.request.urlopen(f"{COMFYUI_URL}/view?{params}", timeout=30)
    return resp.read()


def generate_asset(asset, index, total):
    output_dir = os.path.join(PROJECT_ASSET_ROOT, asset["subdir"])
    os.makedirs(output_dir, exist_ok=True)

    seed = random.randint(1, 2**31 - 1)
    full_prompt = GLOBAL_PREFIX + asset["prompt"]
    filename_prefix = f"ingame_{asset['id']}"

    print(f"[{index}/{total}] generating {asset['filename']}")
    workflow = build_workflow(full_prompt, asset["width"], asset["height"], seed, filename_prefix)
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

    output_path = os.path.join(output_dir, asset["filename"])
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
