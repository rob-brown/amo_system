-- Focus on first game.
-- Assumes this is the desired game.
press("home")
wait("1500ms")
-- Open game
press("a")
wait("2s")
-- Select first player account.
press("a", "500ms")
-- Wait a long time for game to launch.
wait_until_found("kirby.png", "40s")
-- Skip intro video to title screen.
press("a")
wait("2s")
-- Advance to game menu.
press("a")
wait("4s")
-- Select Smash mode.
press("a")
wait("1s")
-- Navigate to Squad Strike menu.
press("down")
press("left")
press("a")
wait("4s")
-- Select first rule set.
press("a")
wait("4s")
-- Select 3-on-3 mode.
press("a")
wait("2s")
