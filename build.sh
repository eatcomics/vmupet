rm vmupet.vms
rm vmupet.vmi
~/waterbear/target/release/waterbear assemble ./main.s -o vmupet.vms
~/waterbear/target/release/waterbear vmi vmupet.vms --game

if test -f "./vmupet.vms"; then
	if test -f "vmupet.vmi"; then
		# ~/evmu/ElysianVMU -b ~/evmu/american.bin -r ~/projects/vmupet/vmupet.vms
		~/evmu/ElysianVMU -r ~/projects/vmupet/vmupet.vms
	fi
fi
