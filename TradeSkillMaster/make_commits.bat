@echo off
REM ==============================================================
REM  TSM 3.3.5a backport - assemble logical commits
REM  Run this from anywhere; it cd-s into the addon (repo) root.
REM  Author: Keoo  (Discord: https://discord.gg/sKpJbUrsvR)
REM ==============================================================
cd /d "%~dp0"

REM --- make sure we are in a git repo ---
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo [ERROR] This folder is not a git repository: %CD%
    pause
    exit /b 1
)

echo.
echo === Commit 1/6: ruRU login crash fix ===
git add "Core/Service/Crafting/PlayerProfessions.lua"
git commit -m "fix(crafting): guard nil player/profession in GetProfessionSkill (ruRU login crash)"

echo.
echo === Commit 2/6: main window font crash fix ===
git add "LibTSMService/Source/UI/Theme.lua" "LibTSMWoW/Source/UI/FontObject.lua"
git commit -m "fix(ui): lazy-init font set + drop zero-width font assert (main window crash on 3.3.5a)"

echo.
echo === Commit 3/6: Discord icon in title bar ===
git add "LibTSMUI/Source/Frames/ApplicationFrame.lua" "Core/UI/MainUI/Core.lua"
git commit -m "feat(ui): add Discord button to main window title bar (backslash texture path for 3.3.5a)"

echo.
echo === Commit 4/6: authorship / Discord link ===
git add "TradeSkillMaster.toc" "TradeSkillMaster.lua" "README.md"
git commit -m "chore: set authorship to Keoo and add Discord link"

echo.
echo === Commit 5/6: WotLK compat bootstrap ===
git add "Compat/WrathBootstrap.lua" "Compat/TSMDebug.lua" "Compat/TSMDebugCommands.lua"
git commit -m "chore(compat): WotLK 3.3.5a bootstrap and debug helpers"

echo.
echo === Commit 6/6: remaining backport fixes (catch-all) ===
git add -A
git commit -m "fix: backport UI and scan fixes (sniper, full scan/anti-afk, auctioning, dashboard, reports, browse, scan tab)"

echo.
echo === Done. Review with: git log --oneline ===
git log --oneline -8
echo.
echo Now push with:  git push
pause
