-- Press button to wake-up controller if needed.
press("x")
-- Move to P1 type selector.
press("down", "500ms")
wait("1s")
-- Load amiibo
load_amiibo_binary(amiibo1)
-- Advance to amiibo input.
press("a")
wait("200ms")
press("a")
-- Wait a bit to avoid getting the ready prompt too soon.
wait("2s")
-- Wait for amiibo to be read.
wait_until_found("ready_to_fight.png", "4s")
-- Load amiibo
clear_amiibo()
load_amiibo_binary(amiibo2)
-- Move to P2 type selector.
press("right", "950ms")
wait("1s")
-- Advance to amiibo input.
press("a")
-- Wait a bit to avoid getting the ready prompt too soon.
wait("2s")
-- Wait for amiibo to be read.
wait_until_found("ready_to_fight.png", "4s")
-- Start the match.
press("plus")
-- Clear the amiibo to avoid problems later.
clear_amiibo()
