import json
import os
import random
import time
import urllib.parse
import urllib.request


COMFYUI_URL = "http://127.0.0.1:8188"
CHECKPOINT = "anything-v5-PrtRE.safetensors"
OUTPUT_DIR = r"D:\GodotProject\桌面挂机\ComfyUI+LoRA\04_output\samples_20260320"

GLOBAL_PREFIX = (
    "masterpiece, best quality, semi realistic 2d game concept art, "
    "wasteland industrial fantasy, furnace core technology, "
    "dark steel, rust red glow, furnace orange embers, cold blue energy, "
    "clean silhouette, readable design, game asset concept, "
)

NEGATIVE_PROMPT = (
    "worst quality, low quality, blurry, deformed, text, watermark, signature, "
    "modern city, bright cartoon, cute chibi, photorealistic, 3d render, "
    "extra limbs, duplicate, frame, border"
)

ASSETS = [
    {
        "id": "BG-01",
        "filename": "chapter1_ruins_border_concept.png",
        "width": 1024,
        "height": 576,
        "prompt": (
            "side scrolling game background concept, ruins border chapter, broken city wall, "
            "collapsed barricades, scrap metal, dead road signs, green ash fog, distant ruined skyline, "
            "dark wasteland atmosphere, layered 2d composition"
        ),
    },
    {
        "id": "BG-02",
        "filename": "chapter2_scorched_mine_concept.png",
        "width": 1024,
        "height": 576,
        "prompt": (
            "side scrolling game background concept, scorched mine chapter, magma cracks, old rail tracks, "
            "forge pipes, steam valves, glowing furnace vents, high heat industrial wasteland, layered 2d composition"
        ),
    },
    {
        "id": "BOSS-01",
        "filename": "boss_iron_beast_concept.png",
        "width": 768,
        "height": 768,
        "prompt": (
            "boss character concept, iron claw beast, mutated heavy experiment beast, armored forelimbs, "
            "industrial plating, furnace scars, massive silhouette, wasteland monster design, full body"
        ),
    },
    {
        "id": "BOSS-02",
        "filename": "boss_magma_overseer_concept.png",
        "width": 768,
        "height": 768,
        "prompt": (
            "boss character concept, magma overseer, humanoid industrial supervisor, furnace core chest, "
            "molten armor cracks, heavy mining authority silhouette, red orange heat glow, full body"
        ),
    },
    {
        "id": "ICON-01",
        "filename": "icon_whirlwind_concept.png",
        "width": 512,
        "height": 512,
        "prompt": (
            "game skill icon concept, whirlwind slash, metallic spiral blade arc, furnace sparks, "
            "blue grey steel with orange ember highlights, centered icon, dark transparent style background"
        ),
    },
    {
        "id": "ICON-02",
        "filename": "icon_chain_lightning_concept.png",
        "width": 512,
        "height": 512,
        "prompt": (
            "game skill icon concept, chain lightning, blue white electric arcs chaining between furnace nodes, "
            "industrial energy emblem, centered icon, dark transparent style background"
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
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    seed = random.randint(1, 2**31 - 1)
    filename_prefix = f"desktopidle_{asset['id']}"
    full_prompt = GLOBAL_PREFIX + asset["prompt"]

    print(f"[{index}/{total}] generating {asset['filename']} ({asset['width']}x{asset['height']})")
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

    output_path = os.path.join(OUTPUT_DIR, asset["filename"])
    with open(output_path, "wb") as f:
        f.write(image_data)

    print(f"  saved -> {output_path}")


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
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
