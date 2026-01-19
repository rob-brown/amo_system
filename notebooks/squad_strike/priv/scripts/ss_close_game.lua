-- If on Switch 2 and the last action was a screenshot,
-- then must wait for the screenshot banner to disappear.
-- Otherwise, this will jump to the photos menu.
wait("3s")
-- Go to home screen.
-- If on home screen, focus on running game.
press("home")
wait("700ms")
-- Trigger game close.
press("x")
wait("700ms")
-- Ackknowledge game close.
press("a")
wait("1s")
