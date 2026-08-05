#include <Character.h>
#include <Debug.h>
#include <GameWorld.h>
#include <Globals.h>
#include <PlayerInterface.h>
#include <Windows.h>

static bool g_openEditor = false;
static bool g_timerStarted = false;

static void CALLBACK TimerProc(HWND, UINT, UINT_PTR, DWORD);

static bool isKenshiForeground() {
  HWND fg = GetForegroundWindow();
  if (!fg)
    return false;

  DWORD pid = 0;
  GetWindowThreadProcessId(fg, &pid);
  return pid == GetCurrentProcessId();
}

static DWORD WINAPI PollThread(LPVOID) {
  bool wasDown = false;

  while (true) {
    Sleep(50);
    if (!isKenshiForeground())
      continue;

    bool alt = (GetAsyncKeyState(VK_MENU) & 0x8000) != 0;
    bool v = (GetAsyncKeyState('V') & 0x8000) != 0;
    bool down = alt && v;

    if (down && !wasDown) {
      g_openEditor = true;

      if (!g_timerStarted) {
        HWND hwnd = GetForegroundWindow();
        if (hwnd) {
          UINT_PTR result = SetTimer(hwnd, 1, 50, TimerProc);
          if (result) {
            g_timerStarted = true;
            DebugLog("Timer started on game HWND");
          } else {
            DebugLog("SetTimer failed");
          }
        }
      }
    }

    wasDown = down;
  }
}

static void CALLBACK TimerProc(HWND, UINT, UINT_PTR, DWORD) {
  if (!g_openEditor)
    return;
  g_openEditor = false;

  GameWorld *gameWorld = ou;
  if (!gameWorld || !gameWorld->player)
    return;

  if (!gameWorld->player->selectedCharacter)
    return;

  Character *character = gameWorld->player->selectedCharacter.getCharacter();
  if (!character) {
    DebugLog("No Character Selected");
    return;
  }

  if (character->isInCombatMode(true, true)) {
    DebugLog("Character in Combat");
    return;
  }

  DebugLog("Opening Character Editor");
  ou->player->activateCharacterEditMode(character);
}

__declspec(dllexport) void startPlugin() {
  HANDLE h = CreateThread(nullptr, 0, PollThread, nullptr, 0, nullptr);
  if (h)
    CloseHandle(h);

  DebugLog("Kenshi-Compact loaded");
}
