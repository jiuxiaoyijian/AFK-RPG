# AFK-RPG 主角跑步视频参考生成评审 v1

## 目标

- 使用 OpenAI Videos API 生成主角跑步参考视频，仅作为动作节奏与关键姿势参考，不直接入包
- 用 `hero_formal_stand_v1` + `hero_formal_action_v1` 合成参考板，作为 `input_reference` 上传
- 后续从视频中抽取关键姿势，再重新生成透明 PNG 正式帧

## 当前参数

- `model`: `sora-2`
- `size`: `1280x720`
- `seconds`: `4`
- `quality_label`: `concept`
- `input_reference_board`: `assets/generated/_openai_raw/hero_run_video/hero_run_reference_board__1280x720.png`

## 注意

- 参考 OpenAI 官方文档，当前用 `input_reference` 而不是 `characters`，因为主角是人形角色，`characters` 的人类相似度工作流默认受限
- 视频 API 当前允许的时长与分辨率以官方接口为准，本脚本默认落在 `Create video` 参考页可见的安全区间
- `quality_label` 只作为本地评审标签，不写入 API 请求体

## Prompt

Single stylized new guofeng wuxia game hero, fictional chibi martial traveler, same hero identity as the reference board, green-gray layered robe, short cape, visible topknot, waist sash, boots, one dao sword, right-facing three-quarter side view. Run in place with a clear loopable stride, keep the whole body in frame at all times, fixed camera, fixed focal length, fixed distance, no camera pan, no zoom, no cut, no environment change, no extra characters, no UI, no text, simple pale parchment studio backdrop. Prioritize readable leg phases and stable silhouette for sprite keyframe extraction.
