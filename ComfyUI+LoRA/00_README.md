# ComfyUI + LoRA 工作区说明

本目录用于维护 `桌面挂机` 项目的本地美术资源工作流。

它的定位不是 Godot 游戏工程本体，而是独立的 AI 美术生产工作区，主要负责：

- 训练集维护
- LoRA 训练配置管理
- ComfyUI 工作流维护
- 测试 prompt 与出图验收
- 美术资源生成规范沉淀

## 当前职责分工

- 当前主 Agent：继续专注 `桌面挂机` 项目实现、文档和功能开发
- 独立 LoRA 子 Agent：专注本地 LoRA 流程建议、工具链和训练组织方式

## 推荐目录结构

- `00_reference`
  用于存放风格参考图、色板、世界观参考图、Boss 参考、UI 参考。

- `01_dataset`
  原始训练集。

- `01_dataset/style`
  世界风格、材质、氛围图。

- `01_dataset/hero`
  主角与人形主视觉。

- `01_dataset/enemies`
  敌人、精英、Boss。

- `01_dataset/items_icons`
  装备图标、技能图标、资源图标、结果卡图标。

- `01_dataset/backgrounds`
  场景背景、章节横版背景分层参考。

- `02_processed`
  裁剪、重命名、统一尺寸后的训练集副本。

- `03_configs`
  Kohya / OneTrainer / 其它训练工具的配置文件。

- `04_output`
  训练输出。

- `04_output/loras`
  训练得到的 LoRA 权重文件。

- `04_output/logs`
  训练日志、记录截图、loss 曲线导出等。

- `05_workflows`
  ComfyUI 工作流 JSON、批处理工作流、出图模板。

- `06_test_prompts`
  测试 prompt、负面词、验收 prompt 套件。

## 推荐维护顺序

1. 先看 `01_LoRA流程搭建与本地执行清单.md`
2. 再按 `02_训练集规范.md` 收集与整理数据
3. 然后再开始建立训练配置与 ComfyUI 工作流

## 当前建议

本项目不建议一开始训练一套“全能 LoRA”。

建议先分成：

- `style`：整体世界风格
- `hero`：主角/人形角色
- `enemies`：敌人与 Boss
- `items_icons`：图标与结果卡
- `backgrounds`：章节背景

这样更利于后续组合调用，也更容易定位训练失败原因。
