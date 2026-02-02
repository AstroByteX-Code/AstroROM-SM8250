LOG_INFO "Disabling Recommended apps menu.."
{
    sed -i "/omcagent/d" "res/values/arrays.xml"
} || ERROR_EXIT "Failed to disable recommended apps"
