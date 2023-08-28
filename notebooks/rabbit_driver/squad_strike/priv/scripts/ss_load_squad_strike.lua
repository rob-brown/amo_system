-- Press button to wake-up controller if needed.
press("x")

-- Load FP1
load_amiibo_binary(amiibo1)
move_pointer("ss_pointer.png", {30, 125}, {65, 140})
press("a")
wait("200ms")
press("a")
wait("5s")

-- Load FP2
load_amiibo_binary(amiibo2)
move_pointer("ss_pointer.png", {30, 253}, {65, 270})
press("a")
wait("200ms")
press("a")
wait("5s")

-- Load FP3
load_amiibo_binary(amiibo3)
move_pointer("ss_pointer.png", {30, 385}, {65, 400})
press("a")
wait("200ms")
press("a")
wait("5s")

-- Load FP4
load_amiibo_binary(amiibo4)
move_pointer("ss_pointer.png", {595, 385}, {605, 400})
press("a")
wait("200ms")
press("a")
wait("5s")

-- Load FP5
load_amiibo_binary(amiibo5)
move_pointer("ss_pointer.png", {595, 253}, {615, 270})
press("a")
wait("200ms")
press("a")
wait("5s")

-- Load FP6
load_amiibo_binary(amiibo6)
move_pointer("ss_pointer.png", {595, 125}, {615, 140})
press("a")
wait("200ms")
press("a")
wait("5s")

-- Move pointer out of the way to count the loaded FPs.
press("up", "400ms")

-- Take a screenshot to later check if any matchups loaded wrong.
press("capture")

-- Clear the amiibo to avoid problems later.
clear_amiibo()
