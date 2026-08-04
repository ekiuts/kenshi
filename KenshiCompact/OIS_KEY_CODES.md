# OIS Key Code Reference

The KenshiLua `onKeyDown` callback passes the raw **OIS key code** cast to an
integer, **not** an ASCII value and **not** a Windows virtual-key code. Using an
ASCII or VK value (e.g. `78` for "N", `120` for F9) will silently never match.

The `key_code` argument received by your handler is compared directly against the
values in the table below.

```lua
local function on_key_down(key_code)
    if key_code == 53 then  -- /
        -- do something
    end
end
registerHandler("onKeyDown", on_key_down)
```

## Key codes

| Key            | OIS constant    | Code (dec) | Code (hex) |
| -------------- | --------------- | ---------- | ---------- |
| (unassigned)   | KC_UNASSIGNED   | 0          | 0x00       |
| Escape         | KC_ESCAPE       | 1          | 0x01       |
| 1              | KC_1            | 2          | 0x02       |
| 2              | KC_2            | 3          | 0x03       |
| 3              | KC_3            | 4          | 0x04       |
| 4              | KC_4            | 5          | 0x05       |
| 5              | KC_5            | 6          | 0x06       |
| 6              | KC_6            | 7          | 0x07       |
| 7              | KC_7            | 8          | 0x08       |
| 8              | KC_8            | 9          | 0x09       |
| 9              | KC_9            | 10         | 0x0A       |
| 0              | KC_0            | 11         | 0x0B       |
| Minus          | KC_MINUS        | 12         | 0x0C       |
| Equals         | KC_EQUALS       | 13         | 0x0D       |
| Backspace      | KC_BACK         | 14         | 0x0E       |
| Tab            | KC_TAB          | 15         | 0x0F       |
| Q              | KC_Q            | 16         | 0x10       |
| W              | KC_W            | 17         | 0x11       |
| E              | KC_E            | 18         | 0x12       |
| R              | KC_R            | 19         | 0x13       |
| T              | KC_T            | 20         | 0x14       |
| Y              | KC_Y            | 21         | 0x15       |
| U              | KC_U            | 22         | 0x16       |
| I              | KC_I            | 23         | 0x17       |
| O              | KC_O            | 24         | 0x18       |
| P              | KC_P            | 25         | 0x19       |
| [              | KC_LBRACKET     | 26         | 0x1A       |
| ]              | KC_RBRACKET     | 27         | 0x1B       |
| Return (Enter) | KC_RETURN       | 28         | 0x1C       |
| Left Ctrl      | KC_LCONTROL     | 29         | 0x1D       |
| A              | KC_A            | 30         | 0x1E       |
| S              | KC_S            | 31         | 0x1F       |
| D              | KC_D            | 32         | 0x20       |
| F              | KC_F            | 33         | 0x21       |
| G              | KC_G            | 34         | 0x22       |
| H              | KC_H            | 35         | 0x23       |
| J              | KC_J            | 36         | 0x24       |
| K              | KC_K            | 37         | 0x25       |
| L              | KC_L            | 38         | 0x26       |
| ;              | KC_SEMICOLON    | 39         | 0x27       |
| '              | KC_APOSTROPHE   | 40         | 0x28       |
| ` (grave)      | KC_GRAVE        | 41         | 0x29       |
| Left Shift     | KC_LSHIFT       | 42         | 0x2A       |
| \              | KC_BACKSLASH    | 43         | 0x2B       |
| Z              | KC_Z            | 44         | 0x2C       |
| X              | KC_X            | 45         | 0x2D       |
| C              | KC_C            | 46         | 0x2E       |
| V              | KC_V            | 47         | 0x2F       |
| B              | KC_B            | 48         | 0x30       |
| N              | KC_N            | 49         | 0x31       |
| M              | KC_M            | 50         | 0x32       |
| ,              | KC_COMMA        | 51         | 0x33       |
| .              | KC_PERIOD       | 52         | 0x34       |
| /              | KC_SLASH        | 53         | 0x35       |
| Right Shift    | KC_RSHIFT       | 54         | 0x36       |
| * (numpad)     | KC_MULTIPLY     | 55         | 0x37       |
| Left Alt       | KC_LMENU        | 56         | 0x38       |
| Space          | KC_SPACE        | 57         | 0x39       |
| Caps Lock      | KC_CAPITAL      | 58         | 0x3A       |
| F1             | KC_F1           | 59         | 0x3B       |
| F2             | KC_F2           | 60         | 0x3C       |
| F3             | KC_F3           | 61         | 0x3D       |
| F4             | KC_F4           | 62         | 0x3E       |
| F5             | KC_F5           | 63         | 0x3F       |
| F6             | KC_F6           | 64         | 0x40       |
| F7             | KC_F7           | 65         | 0x41       |
| F8             | KC_F8           | 66         | 0x42       |
| F9             | KC_F9           | 67         | 0x43       |
| F10            | KC_F10          | 68         | 0x44       |
| Num Lock       | KC_NUMLOCK      | 69         | 0x45       |
| Scroll Lock    | KC_SCROLL       | 70         | 0x46       |
| NumPad 7       | KC_NUMPAD7      | 71         | 0x47       |
| NumPad 8       | KC_NUMPAD8      | 72         | 0x48       |
| NumPad 9       | KC_NUMPAD9      | 73         | 0x49       |
| - (numpad)     | KC_SUBTRACT     | 74         | 0x4A       |
| NumPad 4       | KC_NUMPAD4      | 75         | 0x4B       |
| NumPad 5       | KC_NUMPAD5      | 76         | 0x4C       |
| NumPad 6       | KC_NUMPAD6      | 77         | 0x4D       |
| + (numpad)     | KC_ADD          | 78         | 0x4E       |
| NumPad 1       | KC_NUMPAD1      | 79         | 0x4F       |
| NumPad 2       | KC_NUMPAD2      | 80         | 0x50       |
| NumPad 3       | KC_NUMPAD3      | 81         | 0x51       |
| NumPad 0       | KC_NUMPAD0      | 82         | 0x52       |
| . (numpad)     | KC_DECIMAL      | 83         | 0x53       |
| OEM 102        | KC_OEM_102      | 86         | 0x56       |
| F11            | KC_F11          | 87         | 0x57       |
| F12            | KC_F12          | 88         | 0x58       |
| F13            | KC_F13          | 100        | 0x64       |
| F14            | KC_F14          | 101        | 0x65       |
| F15            | KC_F15          | 102        | 0x66       |
| Kana           | KC_KANA         | 112        | 0x70       |
| / ? (BR)       | KC_ABNT_C1      | 115        | 0x73       |
| Convert        | KC_CONVERT      | 121        | 0x79       |
| NoConvert      | KC_NOCONVERT    | 123        | 0x7B       |
| Yen            | KC_YEN          | 125        | 0x7D       |
| NumPad . (BR)  | KC_ABNT_C2      | 126        | 0x7E       |
| = (numpad)     | KC_NUMPADEQUALS | 141        | 0x8D       |
| Prev Track     | KC_PREVTRACK    | 144        | 0x90       |
| @              | KC_AT           | 145        | 0x91       |
| :              | KC_COLON        | 146        | 0x92       |
| _              | KC_UNDERLINE    | 147        | 0x93       |
| Kanji          | KC_KANJI        | 148        | 0x94       |
| Stop           | KC_STOP         | 149        | 0x95       |
| AX             | KC_AX           | 150        | 0x96       |
| Unlabeled      | KC_UNLABELED    | 151        | 0x97       |
| Next Track     | KC_NEXTTRACK    | 153        | 0x99       |
| NumPad Enter   | KC_NUMPADENTER  | 156        | 0x9C       |
| Right Ctrl     | KC_RCONTROL     | 157        | 0x9D       |
| Mute           | KC_MUTE         | 160        | 0xA0       |
| Calculator     | KC_CALCULATOR   | 161        | 0xA1       |
| Play/Pause     | KC_PLAYPAUSE    | 162        | 0xA2       |
| Media Stop     | KC_MEDIASTOP    | 164        | 0xA4       |
| 2 (AZERTY)     | KC_TWOSUPERIOR  | 170        | 0xAA       |
| Volume Down    | KC_VOLUMEDOWN   | 174        | 0xAE       |
| Volume Up      | KC_VOLUMEUP     | 176        | 0xB0       |
| Web Home       | KC_WEBHOME      | 178        | 0xB2       |
| , (numpad)     | KC_NUMPADCOMMA  | 179        | 0xB3       |
| / (numpad)     | KC_DIVIDE       | 181        | 0xB5       |
| SysRq / PrtScr | KC_SYSRQ        | 183        | 0xB7       |
| Right Alt      | KC_RMENU        | 184        | 0xB8       |
| Pause          | KC_PAUSE        | 197        | 0xC5       |
| Home           | KC_HOME         | 199        | 0xC7       |
| Up Arrow       | KC_UP           | 200        | 0xC8       |
| Page Up        | KC_PGUP         | 201        | 0xC9       |
| Left Arrow     | KC_LEFT         | 203        | 0xCB       |
| Right Arrow    | KC_RIGHT        | 205        | 0xCD       |
| End            | KC_END          | 207        | 0xCF       |
| Down Arrow     | KC_DOWN         | 208        | 0xD0       |
| Page Down      | KC_PGDOWN       | 209        | 0xD1       |
| Insert         | KC_INSERT       | 210        | 0xD2       |
| Delete         | KC_DELETE       | 211        | 0xD3       |
| Left Windows   | KC_LWIN         | 219        | 0xDB       |
| Right Windows  | KC_RWIN         | 220        | 0xDC       |
| Apps / Menu    | KC_APPS         | 221        | 0xDD       |
| Power          | KC_POWER        | 222        | 0xDE       |
| Sleep          | KC_SLEEP        | 223        | 0xDF       |
| Wake           | KC_WAKE         | 227        | 0xE3       |
| Web Search     | KC_WEBSEARCH    | 229        | 0xE5       |
| Web Favorites  | KC_WEBFAVORITES | 230        | 0xE6       |
| Web Refresh    | KC_WEBREFRESH   | 231        | 0xE7       |
| Web Stop       | KC_WEBSTOP      | 232        | 0xE8       |
| Web Forward    | KC_WEBFORWARD   | 233        | 0xE9       |
| Web Back       | KC_WEBBACK      | 234        | 0xEA       |
| My Computer    | KC_MYCOMPUTER   | 235        | 0xEB       |
| Mail           | KC_MAIL         | 236        | 0xEC       |
| Media Select   | KC_MEDIASELECT  | 237        | 0xED       |

## Modifiers

The `onKeyDown` callback only delivers the bare key code, so modifier state must be queried separately. Use the `getInputHandler()` global inside your handler and check the `.ctrl`, `.shift`, and `.alt` booleans:

```lua
local function on_key_down(key_code)
    local ih = getInputHandler()
    if key_code == KC_SLASH and ih and ih.shift then  -- Shift + /
        -- do something
    end
end
registerHandler("onKeyDown", on_key_down)
```

## Keys used by this mod

This mod responds to the following key code in
`scripts/init/open_character_editor.lua`:

| Key | Code (dec) | Location              |
| --- | ---------- | --------------------- |
| /   | 53         | `local KC_SLASH = 53` |

Note: To use a modifier combination instead (e.g. Shift + /), see the Modifiers section above.
