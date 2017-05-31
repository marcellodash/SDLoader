@echo off
D:\neogeo\asw\asw main -L -quiet
..\tools\overlay main.p top-sp1_original.bin top-sp1_patched.bin
D:\neogeo\sgcc\flip top-sp1_patched.bin top-sp1_patched.bin
copy top-sp1_patched.bin D:\mess\roms\neocdz\top-sp1.bin
