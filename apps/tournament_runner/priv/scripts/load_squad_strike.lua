-- Press button to wake-up controller if needed.
press("x")

-- Load FP1
load_amiibo_binary(amiibo1)
move_pointer("pointer.png", {30..65}, {120..140})
press("a")
wait("200ms")
press("a")
wait("5s")

-- Load FP2
load_amiibo_binary(amiibo2)
move_pointer("pointer.png", {30..65}, {248..270})
press("a")
wait("200ms")
press("a")
wait("5s")

-- Load FP3
load_amiibo_binary(amiibo3)
move_pointer("pointer.png", {30..65}, {385..400})
press("a")
wait("200ms")
press("a")
wait("5s")

-- Load FP4
load_amiibo_binary(amiibo4)
move_pointer("pointer.png", {595..605}, {385..400})
press("a")
wait("200ms")
press("a")
wait("5s")

-- Load FP5
load_amiibo_binary(amiibo5)
move_pointer("pointer.png", {595..615}, {248..270})
press("a")
wait("200ms")
press("a")
wait("5s")

-- Load FP6
load_amiibo_binary(amiibo6)
move_pointer("pointer.png", {595..615}, {120..140})
press("a")
wait("200ms")
press("a")
wait("5s")

-- Move pointer out of the way to count the loaded FPs.
press("up", "400ms")

-- Clear the amiibo to avoid problems later.
clear_amiibo()