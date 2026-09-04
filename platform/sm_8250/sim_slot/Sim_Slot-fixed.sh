LOG_BEGIN "Adding SIM Slot property..."

# Set SIM slot count to 2
BPROP "system" "ro.telephony.sim_slots.count" "2"
LOG_INFO "Configured ro.telephony.sim_slots.count = 2"

LOG_END "SIM Slot patch applied successfully"
