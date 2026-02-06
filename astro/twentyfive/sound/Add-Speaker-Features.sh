# ==============================================================================
#
# MOD_NAME="Add speaker features from paradigm."
# MOD_AUTHOR="Sameer Al Sahab"
# MOD_DESC="Add some special effects and voice booster from paradigm."
#
# ==============================================================================
if GET_FEATURE DEVICE_HAVE_DUAL_SPEAKER; then

FF "AUDIO_CONFIG_SOUNDALIVE_VERSION" "eq_custom,uhq_onoff,karaoke,adapt,spk_stereo,dvfs_20_percent,dvfs_max_45_percent,voice_boost"

ADD_FROM_FW "pa3q" "system" "lib64/libvoice_booster.so"
ADD_FROM_FW "pa3q" "system" "lib64/lib_sag_ai_sound_sep_v1.00.so"
ADD_FROM_FW "pa3q" "system" "lib64/lib_SAG_EQ_ver2060.so"
ADD_FROM_FW "pa3q" "system" "lib64/libSAG_VM_Energy_v300.so"
ADD_FROM_FW "pa3q" "system" "lib64/libSAG_VM_Score_V300.so"
ADD_FROM_FW "pa3q" "system" "lib64/lib_SoundAlive_play_plus_ver900.so"
ADD_FROM_FW "pa3q" "system" "etc/audio_effects_common.conf"

echo "/system/lib64/lib_sag_ai_sound_sep_v1.00.so" >> "$WORKSPACE/system/system/etc/irremovable_list.txt"

fi
