# Flashing OpenWRT firmware to Xiaomi Mi Router 4C

It's a very simple project that I did just for fun. I know that there're probably thousands of much better routers that you can use instead of Xiaomi Mi Router 4C, but since it's dirt cheap I figured that it could be very fun to tinkle with it and see if OpenWRT can make it somewhat better (spoiler: it will!). There are existing tools and scripts to flash OpenWRT to this router, so you can use them and don't ask me why I even bothered. No particular reason other than remembering that I once knew Ruby and it's probably the time to bring it back to my memory.

It's highly possible that there won't be any further updates of this repository because... well, why? I don't feel like using some cheap crappy router for years or something. Nor that I'm planning to own it for so long anyway.

**Disclaimer: I can't (and won't) be responsible for any damage you will do to your router by following these instructions!**

*But, really... Would you even care if you damage the router that costs less than a bottle of decent beer?*

### Requirements

I hate when doing simple things requires you to install a crapload of dependencies. So, I managed to narrow it down to just two dependencies - Linux and Docker.

* Some modern Linux with latest Docker installed
* Some modern web browser to work with router's web UI

Everything was done and tested on Manjaro Linux, but should work with little to no change on other Linux distros and probably other OSes too. Feel free to tell me how it worked for you on some other system.

### Building the latest firmware using Image Builder

You can just take a pre-build firmware from [OpenWRT download page](https://openwrt.org/toh/views/toh_fwdownload?dataflt%5BModel*%7E%5D=Mi+Router+4C) and use it (don't forget to set the image path in [router.rb](router.rb) if you do that though), but since its `snapshot` kind of distribution and doesn't have LuCI web UI, we'll build our own package, it's not complicated at all.

```console
$ docker run --rm -v "$(pwd)":/home/build/openwrt/bin -it openwrtorg/imagebuilder:ramips-mt76x8-master sh -c "make PROFILE=xiaomi_mi-router-4c PACKAGES='luci' image"
```

After that you'll have `target` directory with your customized OpenWRT image.

### Flashing OpenWRT firmware to router

Before flashing the router, you need to go through initial setup (if you haven't done that already) and set your password at the beginning of the [router.rb](router.rb) file. Then, run the following command:

```console
$ docker run --rm -ti -v $(pwd):/flash ruby:2.7-alpine sh -c "cd /flash && ruby router.rb"
```

After the command will finish, wait for router to change blue LED to orange (it means that flashing was finished and router was rebooted) and then to blue again (not blinking). Then change your NIC IP to `192.168.1.2` and open [http://192.168.1.1](http://192.168.1.1)

### Going back to original firmware

**This method will restore the firmware flashed with this instruction only since it preserves the original bootloader! If you altered the bootloader by following some other manuals - this method won't work!**

Connect you router via the second LAN interface (the interface with two dots, `..`) to your computer, set your computer NIC IP to `192.168.31.2`. Place stock firmware named as `stable.bin` to the same folder from which you will run the following command:

```console
$ docker run --rm -ti -v $(pwd)/stable.bin:/tftpboot/stable.bin --net=host --cap-add=NET_ADMIN andyshinn/dnsmasq -p 0 -M stable.bin -u root -I lo -F 192.168.31.1,192.168.31.1 --enable-tftp --tftp-root=/tftpboot --log-dhcp --no-daemon
```

Now, hold `Reset` and power on the router. Hold `Reset` until orange dot start to blink then release it. In the terminal window with the running docker you will see that your router is getting IP and the `stable.bin`. Wait for the router to start blinking blue LED rapidly - it means that it finished restoring the firmware and you need to powercycle the router. Do it and wait for router to start displaying non-blinking blue LED. It means that everything is fine and you can open [http://192.168.31.1](http://192.168.31.1) to do your initial configuration as usual.

### Links

Here's the links that I used as a reference (and to take some portions of code) or recommend to read about this stuff:

* https://4pda.ru/forum/index.php?showtopic=905966&st=5420#entry95773951
* https://forum.openwrt.org/t/openwrt-for-xiaomi-mi-router-4c/72175
* https://github.com/acecilia/OpenWRTInvasion
