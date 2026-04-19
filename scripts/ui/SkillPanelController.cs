using System.Collections.Generic;
using System.Linq;
using Godot;
using DesktopIdle.Autoload;
using DesktopIdle.Models;
using DesktopIdle.UI.Components;

namespace DesktopIdle.UI;

/// <summary>
/// Skill panel: 4 active skill slots + passive skill list.
/// 点击槽位 → 弹出技能选择子面板 → 装备 / 卸下。
/// </summary>
public partial class SkillPanelController : Control
{
    private readonly Button[] _skillSlots = new Button[4];
    private readonly Label[] _slotLabels = new Label[4];
    private VBoxContainer _passiveList = null!;
    private ConfigDB _db = null!;

    public override void _Ready()
    {
        _db = GetNode<ConfigDB>("/root/ConfigDB");

        SetAnchorsPreset(LayoutPreset.FullRect);
        MouseFilter = MouseFilterEnum.Ignore;

        BuildUI();

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EquipmentChanged += _ => Refresh();
    }

    private void BuildUI()
    {
        var chrome = new PanelChrome
        {
            PanelId = "skills",
            Title = "技 能",
            Subtitle = "主动 / 被动",
            AccentColor = UIStyle.NavSkills,
            PanelWidth = UIStyle.PanelWidthStandard,
            PanelHeight = 480,
        };
        AddChild(chrome);

        var content = new VBoxContainer();
        content.SizeFlagsVertical = SizeFlags.ExpandFill;
        content.AddThemeConstantOverride("separation", UIStyle.Spacing16);
        chrome.Body.AddChild(content);

        content.AddChild(new SectionHeader("主动技能位", "点击切换技能"));

        var slotsRow = new HBoxContainer();
        slotsRow.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        slotsRow.Alignment = BoxContainer.AlignmentMode.Center;
        content.AddChild(slotsRow);

        for (int i = 0; i < 4; i++)
        {
            var slotIdx = i;
            var btn = new Button
            {
                CustomMinimumSize = new Vector2(120, 88),
                FocusMode = FocusModeEnum.None,
                ClipText = true,
            };
            UIStyle.ApplyStateButton(btn, UIStyle.NavSkills);
            btn.Pressed += () => OpenSkillPicker(slotIdx);
            slotsRow.AddChild(btn);

            var indexLabel = new Label
            {
                Text = $"槽 {slotIdx + 1}",
                Position = new Vector2(8, 6),
            };
            indexLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontTiny);
            indexLabel.AddThemeColorOverride("font_color", UIStyle.TextMuted);
            indexLabel.MouseFilter = MouseFilterEnum.Ignore;
            btn.AddChild(indexLabel);

            var nameLabel = new Label
            {
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                Position = new Vector2(0, 32),
                Size = new Vector2(120, 48),
            };
            nameLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
            nameLabel.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
            nameLabel.MouseFilter = MouseFilterEnum.Ignore;
            btn.AddChild(nameLabel);

            _skillSlots[i] = btn;
            _slotLabels[i] = nameLabel;
        }

        content.AddChild(new SectionHeader("被动技能", "自动生效"));

        var scroll = new ScrollContainer
        {
            SizeFlagsVertical = SizeFlags.ExpandFill,
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
        };
        content.AddChild(scroll);

        _passiveList = new VBoxContainer();
        _passiveList.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        _passiveList.AddThemeConstantOverride("separation", UIStyle.Spacing4);
        scroll.AddChild(_passiveList);

        Refresh();
    }

    public override void _Notification(int what)
    {
        if (what == NotificationVisibilityChanged && Visible) Refresh();
    }

    private void Refresh()
    {
        var gm = GameManager.Instance;
        for (int i = 0; i < 4; i++)
        {
            string? id = gm.EquippedSkillIds[i];
            _slotLabels[i].Text = string.IsNullOrEmpty(id) ? "[空]" : LookupSkillName(id);
            _slotLabels[i].AddThemeColorOverride("font_color",
                string.IsNullOrEmpty(id) ? UIStyle.TextMuted : UIStyle.TextPrimary);
        }

        foreach (var c in _passiveList.GetChildren()) c.QueueFree();
        foreach (var skill in _db.Skills.Where(s => s.SkillType == "passive"))
            _passiveList.AddChild(new KeyValueRow(skill.Name, skill.Description, UIStyle.TextSecondary));

        if (_db.Skills.All(s => s.SkillType != "passive"))
            _passiveList.AddChild(new EmptyState("尚无被动技能", "提升弟子等级解锁"));
    }

    private string LookupSkillName(string id)
    {
        var def = _db.Skills.FirstOrDefault(s => s.Id == id);
        return def != null ? def.Name : id;
    }

    private void OpenSkillPicker(int slotIdx)
    {
        var available = _db.Skills.Where(s => s.SkillType == "active" || s.SkillType == "core").ToList();
        if (available.Count == 0)
        {
            ConfirmDialog.Show(this, "暂无可装备技能", "尚未解锁任何主动技能。", () => { }, confirmText: "好的", cancelText: "");
            return;
        }

        var picker = new SkillPickerPopup(slotIdx, available, GameManager.Instance.EquippedSkillIds[slotIdx], OnSkillPicked);
        AddChild(picker);
    }

    private void OnSkillPicked(int slotIdx, string? skillId)
    {
        var gm = GameManager.Instance;

        if (skillId != null)
        {
            for (int i = 0; i < 4; i++)
                if (i != slotIdx && gm.EquippedSkillIds[i] == skillId)
                    gm.EquippedSkillIds[i] = null!;
        }
        gm.EquippedSkillIds[slotIdx] = skillId!;
        Refresh();

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.EquipmentChanged, $"skill_{slotIdx}");
    }

    /// <summary>
    /// 嵌套 popup：列出所有可用主动技能让玩家挑一个填入指定槽位。
    /// </summary>
    private partial class SkillPickerPopup : Control
    {
        private readonly int _slotIdx;
        private readonly List<SkillDef> _options;
        private readonly string? _currentId;
        private readonly System.Action<int, string?> _onPick;

        public SkillPickerPopup(int slotIdx, List<SkillDef> options, string? currentId, System.Action<int, string?> onPick)
        {
            _slotIdx = slotIdx;
            _options = options;
            _currentId = currentId;
            _onPick = onPick;
        }

        public override void _Ready()
        {
            SetAnchorsPreset(LayoutPreset.FullRect);
            MouseFilter = MouseFilterEnum.Stop;
            ZIndex = 50;

            var backdrop = new ColorRect { Color = new Color(0, 0, 0, 0.55f) };
            backdrop.SetAnchorsPreset(LayoutPreset.FullRect);
            backdrop.GuiInput += ev =>
            {
                if (ev is InputEventMouseButton { Pressed: true, ButtonIndex: MouseButton.Left }) QueueFree();
            };
            AddChild(backdrop);

            var card = new Panel();
            card.SetAnchorsPreset(LayoutPreset.Center);
            card.CustomMinimumSize = new Vector2(440, 360);
            card.Size = new Vector2(440, 360);
            card.OffsetLeft = -220;
            card.OffsetTop = -180;
            card.OffsetRight = 220;
            card.OffsetBottom = 180;
            card.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(UIStyle.BgPanel, UIStyle.NavSkills, 2, 8));
            card.MouseFilter = MouseFilterEnum.Stop;
            AddChild(card);

            var vbox = new VBoxContainer();
            vbox.SetAnchorsPreset(LayoutPreset.FullRect);
            vbox.OffsetLeft = UIStyle.Spacing16;
            vbox.OffsetRight = -UIStyle.Spacing16;
            vbox.OffsetTop = UIStyle.Spacing16;
            vbox.OffsetBottom = -UIStyle.Spacing16;
            vbox.AddThemeConstantOverride("separation", UIStyle.Spacing12);
            card.AddChild(vbox);

            var title = new Label
            {
                Text = $"为槽位 {_slotIdx + 1} 选择技能",
                HorizontalAlignment = HorizontalAlignment.Center,
            };
            title.AddThemeFontSizeOverride("font_size", UIStyle.FontHeader);
            title.AddThemeColorOverride("font_color", UIStyle.NavSkills);
            vbox.AddChild(title);

            var scroll = new ScrollContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
            vbox.AddChild(scroll);

            var list = new VBoxContainer();
            list.SizeFlagsHorizontal = SizeFlags.ExpandFill;
            list.AddThemeConstantOverride("separation", UIStyle.Spacing4);
            scroll.AddChild(list);

            foreach (var sk in _options)
            {
                var btn = new Button
                {
                    Text = $"{(sk.Id == _currentId ? "● " : "  ")}{sk.Name}  —  {sk.Description}",
                    Alignment = HorizontalAlignment.Left,
                    CustomMinimumSize = new Vector2(0, 36),
                };
                UIStyle.ApplyStateButton(btn, sk.Id == _currentId ? UIStyle.Accent : UIStyle.NavSkills.Darkened(0.3f));
                var captured = sk.Id;
                btn.Pressed += () => { _onPick(_slotIdx, captured); QueueFree(); };
                list.AddChild(btn);
            }

            var btnRow = new HBoxContainer();
            btnRow.Alignment = BoxContainer.AlignmentMode.Center;
            btnRow.AddThemeConstantOverride("separation", UIStyle.Spacing12);
            vbox.AddChild(btnRow);

            var clearBtn = new IconButton("卸下技能", IconButton.ButtonVariant.Danger)
            {
                CustomMinimumSize = new Vector2(120, UIStyle.ButtonHeight),
            };
            clearBtn.Pressed += () => { _onPick(_slotIdx, null); QueueFree(); };
            btnRow.AddChild(clearBtn);

            var cancelBtn = new IconButton("取消", IconButton.ButtonVariant.Secondary)
            {
                CustomMinimumSize = new Vector2(120, UIStyle.ButtonHeight),
            };
            cancelBtn.Pressed += QueueFree;
            btnRow.AddChild(cancelBtn);
        }

        public override void _UnhandledInput(InputEvent ev)
        {
            if (ev is InputEventKey { Pressed: true, Keycode: Key.Escape })
            {
                QueueFree();
                GetViewport().SetInputAsHandled();
            }
        }
    }
}
