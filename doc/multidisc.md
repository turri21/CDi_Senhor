# State of Multi Disc support

Due to being restricted to SLAVE 2.0, instead of the actual required SLAVE 3.2, the front panel is not working.
Ejecting a disc is not possible via button press.

But maybe it doesn't need to.
According to the chapter "Multi Disc Applications" from the Green Book,
this is not how it works, because pressing Eject usually resets the player.

Instead, the application needs to eject the disc by itself like this

    int cdfile = open("/cd@", _READ);
	DEBUG(ss_eject(cdfile));
	printf("ejected\n");

    sleep(1);

	DEBUG(ss_mount(cdfile,0));
	printf("mounted\n");

