#!/usr/bin/env python3
from __future__ import annotations

import argparse
import getpass
import json
import mimetypes
import os
import sys
import time
import uuid
import urllib.error
import urllib.request
from pathlib import Path
from typing import Sequence

import hero_run_pipeline as run_pipeline


ROOT = Path("/Users/hehe/Documents/AIProject/AFK-RPG")
RAW_DIR = ROOT / "assets" / "generated" / "_openai_raw" / "hero_run_video"
REVIEW_DIR = ROOT / "assets" / "generated" / "hero_run_review"
LOG_PATH = ROOT / "文档" / "hero_run_video_openai生成日志_v1.jsonl"
REVIEW_PATH = ROOT / "文档" / "hero_run_video_review_v1.md"
VIDEOS_API_URL = "https://api.openai.com/v1/videos"
VIDEO_STATUS_URL = "https://api.openai.com/v1/videos/{video_id}"
VIDEO_CONTENT_URL = "https://api.openai.com/v1/videos/{video_id}/content"
DEFAULT_STAND_REF = ROOT / "assets" / "generated" / "formal_replacement_samples" / "characters" / "hero_formal_stand_v1.png"
DEFAULT_ACTION_REF = ROOT / "assets" / "generated" / "formal_replacement_samples" / "characters" / "hero_formal_action_v1.png"

BASE_PROMPT = (
	"Single stylized new guofeng wuxia game hero, fictional chibi martial traveler, same hero identity as the reference board, "
	"green-gray layered robe, short cape, visible topknot, waist sash, boots, one dao sword, right-facing three-quarter side view. "
	"Run in place with a clear loopable stride, keep the whole body in frame at all times, fixed camera, fixed focal length, fixed distance, "
	"no camera pan, no zoom, no cut, no environment change, no extra characters, no UI, no text, solid flat chroma-green studio backdrop, "
	"no letterbox bars, no vignette, no floating dust, no floor props. "
	"Prioritize readable leg phases and stable silhouette for sprite keyframe extraction."
)


def _load_api_key() -> str:
	env_value = os.environ.get("OPENAI_API_KEY", "").strip()
	if env_value:
		return env_value
	prompt_value = getpass.getpass("Enter OPENAI_API_KEY: ").strip()
	if not prompt_value:
		raise SystemExit("OPENAI_API_KEY is required.")
	return prompt_value


def _parse_size(size: str) -> tuple[int, int]:
	width, height = size.lower().split("x", 1)
	return int(width), int(height)


def _contain_size(src_width: int, src_height: int, dst_width: int, dst_height: int) -> tuple[int, int]:
	scale = min(dst_width / float(src_width), dst_height / float(src_height))
	return max(1, int(round(src_width * scale))), max(1, int(round(src_height * scale)))


def _make_reference_board(size: str, stand_ref: Path, action_ref: Path) -> Path:
	width, height = _parse_size(size)
	board = run_pipeline.make_canvas(width, height, (237, 231, 219, 255))

	left_w, left_h, left_pixels = run_pipeline.load_rgba_png(stand_ref)
	right_w, right_h, right_pixels = run_pipeline.load_rgba_png(action_ref)

	gutter = max(24, width // 24)
	panel_width = max(1, (width - gutter * 3) // 2)
	panel_height = max(1, height - gutter * 2)

	left_target_w, left_target_h = _contain_size(left_w, left_h, panel_width, panel_height)
	right_target_w, right_target_h = _contain_size(right_w, right_h, panel_width, panel_height)

	left_scaled = run_pipeline.resize_rgba_nearest(left_pixels, left_w, left_h, left_target_w, left_target_h)
	right_scaled = run_pipeline.resize_rgba_nearest(right_pixels, right_w, right_h, right_target_w, right_target_h)

	run_pipeline.blit_rgba(
		board,
		width,
		height,
		left_scaled,
		left_target_w,
		left_target_h,
		gutter + (panel_width - left_target_w) // 2,
		gutter + (panel_height - left_target_h) // 2,
	)
	run_pipeline.blit_rgba(
		board,
		width,
		height,
		right_scaled,
		right_target_w,
		right_target_h,
		gutter * 2 + panel_width + (panel_width - right_target_w) // 2,
		gutter + (panel_height - right_target_h) // 2,
	)

	board_path = RAW_DIR / f"hero_run_reference_board__{size}.png"
	run_pipeline.save_rgba_png(board_path, width, height, board)
	return board_path


def _build_prompt(prompt_suffix: str) -> str:
	suffix = prompt_suffix.strip()
	if not suffix:
		return BASE_PROMPT
	return f"{BASE_PROMPT} {suffix}"


def _encode_multipart(fields: dict[str, str], file_field_name: str, file_path: Path) -> tuple[bytes, str]:
	boundary = f"----AFKRPGHeroRun{uuid.uuid4().hex}"
	lines: list[bytes] = []
	for key, value in fields.items():
		lines.append(f"--{boundary}\r\n".encode("utf-8"))
		lines.append(f'Content-Disposition: form-data; name="{key}"\r\n\r\n'.encode("utf-8"))
		lines.append(value.encode("utf-8"))
		lines.append(b"\r\n")
	mime_type = mimetypes.guess_type(file_path.name)[0] or "application/octet-stream"
	lines.append(f"--{boundary}\r\n".encode("utf-8"))
	lines.append(
		f'Content-Disposition: form-data; name="{file_field_name}"; filename="{file_path.name}"\r\n'.encode("utf-8")
	)
	lines.append(f"Content-Type: {mime_type}\r\n\r\n".encode("utf-8"))
	lines.append(file_path.read_bytes())
	lines.append(b"\r\n")
	lines.append(f"--{boundary}--\r\n".encode("utf-8"))
	body = b"".join(lines)
	return body, f"multipart/form-data; boundary={boundary}"


def _request_json(url: str, api_key: str) -> dict:
	request = urllib.request.Request(
		url,
		headers={"Authorization": f"Bearer {api_key}"},
		method="GET",
	)
	with urllib.request.urlopen(request, timeout=600) as response:
		return json.loads(response.read().decode("utf-8"))


def _create_video_job(
	api_key: str,
	model: str,
	size: str,
	seconds: str,
	prompt: str,
	reference_board: Path,
) -> dict:
	fields = {
		"model": model,
		"size": size,
		"seconds": seconds,
		"prompt": prompt,
	}
	body, content_type = _encode_multipart(fields, "input_reference", reference_board)
	request = urllib.request.Request(
		VIDEOS_API_URL,
		data=body,
		headers={
			"Authorization": f"Bearer {api_key}",
			"Content-Type": content_type,
		},
		method="POST",
	)
	try:
		with urllib.request.urlopen(request, timeout=600) as response:
			return json.loads(response.read().decode("utf-8"))
	except urllib.error.HTTPError as exc:
		detail = exc.read().decode("utf-8", errors="replace")
		raise RuntimeError(f"Video generation failed: {exc.code} {detail}") from exc


def _poll_video_job(api_key: str, video_id: str, poll_seconds: float) -> dict:
	while True:
		payload = _request_json(VIDEO_STATUS_URL.format(video_id=video_id), api_key)
		status = str(payload.get("status", ""))
		if status in {"completed", "failed", "expired", "cancelled"}:
			return payload
		time.sleep(poll_seconds)


def _download_variant(api_key: str, video_id: str, output_path: Path, variant: str) -> None:
	url = VIDEO_CONTENT_URL.format(video_id=video_id)
	if variant != "video":
		url = f"{url}?variant={variant}"
	request = urllib.request.Request(
		url,
		headers={"Authorization": f"Bearer {api_key}"},
		method="GET",
	)
	with urllib.request.urlopen(request, timeout=600) as response:
		output_path.parent.mkdir(parents=True, exist_ok=True)
		output_path.write_bytes(response.read())


def _append_log(entry: dict) -> None:
	LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
	with LOG_PATH.open("a", encoding="utf-8") as handle:
		handle.write(json.dumps(entry, ensure_ascii=False) + "\n")


def _write_review(prompt: str, board_path: Path, args: argparse.Namespace) -> None:
	lines = [
		"# AFK-RPG 主角跑步视频参考生成评审 v1",
		"",
		"## 目标",
		"",
		"- 使用 OpenAI Videos API 生成主角跑步参考视频，仅作为动作节奏与关键姿势参考，不直接入包",
		"- 用 `hero_formal_stand_v1` + `hero_formal_action_v1` 合成参考板，作为 `input_reference` 上传",
		"- 后续从视频中抽取关键姿势，再重新生成透明 PNG 正式帧",
		"",
		"## 当前参数",
		"",
		f"- `model`: `{args.model}`",
		f"- `size`: `{args.size}`",
		f"- `seconds`: `{args.seconds}`",
		f"- `quality_label`: `{args.quality_label}`",
		f"- `input_reference_board`: `{board_path.relative_to(ROOT)}`",
		"",
		"## 注意",
		"",
		"- 参考 OpenAI 官方文档，当前用 `input_reference` 而不是 `characters`，因为主角是人形角色，`characters` 的人类相似度工作流默认受限",
		"- 视频 API 当前允许的时长与分辨率以官方接口为准，本脚本默认落在 `Create video` 参考页可见的安全区间",
		"- `quality_label` 只作为本地评审标签，不写入 API 请求体",
		"",
		"## Prompt",
		"",
		prompt,
		"",
	]
	REVIEW_PATH.write_text("\n".join(lines), encoding="utf-8")


def _parse_args(argv: Sequence[str]) -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Generate a hero run reference video via the OpenAI Videos API.")
	parser.add_argument("--model", choices=["sora-2", "sora-2-pro"], default="sora-2")
	parser.add_argument("--size", choices=["720x1280", "1280x720", "1024x1792", "1792x1024"], default="1280x720")
	parser.add_argument("--seconds", choices=["4", "8", "12"], default="4")
	parser.add_argument("--quality-label", default="concept")
	parser.add_argument("--prompt-suffix", default="")
	parser.add_argument("--poll-seconds", type=float, default=10.0)
	parser.add_argument("--skip-generate", action="store_true")
	parser.add_argument("--stand-ref", default=str(DEFAULT_STAND_REF))
	parser.add_argument("--action-ref", default=str(DEFAULT_ACTION_REF))
	return parser.parse_args(argv)


def main(argv: Sequence[str]) -> int:
	args = _parse_args(argv)
	RAW_DIR.mkdir(parents=True, exist_ok=True)
	REVIEW_DIR.mkdir(parents=True, exist_ok=True)
	stand_ref = Path(args.stand_ref)
	action_ref = Path(args.action_ref)
	if not stand_ref.exists() or not action_ref.exists():
		raise SystemExit("Both stand and action reference images must exist.")

	prompt = _build_prompt(args.prompt_suffix)
	board_path = _make_reference_board(args.size, stand_ref, action_ref)
	_write_review(prompt, board_path, args)
	if args.skip_generate:
		print(f"Wrote reference board to {board_path.relative_to(ROOT)}")
		print(f"Wrote review notes to {REVIEW_PATH.relative_to(ROOT)}")
		return 0

	api_key = _load_api_key()
	video = _create_video_job(api_key, args.model, args.size, args.seconds, prompt, board_path)
	video_id = str(video["id"])
	final_status = _poll_video_job(api_key, video_id, args.poll_seconds)
	status = str(final_status.get("status", ""))
	entry = {
		"video_id": video_id,
		"status": status,
		"model": args.model,
		"size": args.size,
		"seconds": args.seconds,
		"quality_label": args.quality_label,
		"reference_board": str(board_path.relative_to(ROOT)),
		"prompt": prompt,
	}
	if status != "completed":
		entry["error"] = final_status.get("error")
		_append_log(entry)
		raise SystemExit(f"Video generation did not complete successfully: {status}")

	video_path = RAW_DIR / f"{video_id}.mp4"
	thumbnail_path: Path | None = RAW_DIR / f"{video_id}__thumbnail.webp"
	spritesheet_path: Path | None = RAW_DIR / f"{video_id}__spritesheet.jpg"
	_download_variant(api_key, video_id, video_path, "video")
	try:
		_download_variant(api_key, video_id, thumbnail_path, "thumbnail")
	except Exception:
		thumbnail_path = None
	try:
		_download_variant(api_key, video_id, spritesheet_path, "spritesheet")
	except Exception:
		spritesheet_path = None

	entry["video_path"] = str(video_path.relative_to(ROOT))
	if thumbnail_path is not None:
		entry["thumbnail_path"] = str(thumbnail_path.relative_to(ROOT))
	if spritesheet_path is not None:
		entry["spritesheet_path"] = str(spritesheet_path.relative_to(ROOT))
	_append_log(entry)
	print(f"Saved video to {video_path.relative_to(ROOT)}")
	return 0


if __name__ == "__main__":
	raise SystemExit(main(sys.argv[1:]))
