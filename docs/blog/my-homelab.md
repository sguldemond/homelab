# my homelab

(04-05-2026)

my homelab setup is currently powered by three 2012-2014 era intel based macs.
the fact that i'm using these computers gives me great joy. especially the macbook pro, running coreos and functioning as the worker node in my k3s cluster. this computer i bought new in 2014 from apple.com, right before i started my software engineering studies. i used it as for my entire studies and a bit after. it had some issues, but it remained very usable for a long time. for wife used it for a little bit as well after me. the main reason to retire it, was the battery. i replaced it once myself, but this replacement battery didn't hold for many years.

its quite usefull to have a laptop as server since it has a built in screen and keyboard, so its very easy to get it going. the other two machines are a 2014 mac mini, my brothers, which i took to repair for him. the hdd died i determined, which i replaced with the old 2012 macbook pro hdd of my wife. also i had some extra memory laying around which was meant to fix that 2012 macbook pro, but that didn't work out. lastly i added a another mac mini, which i bought second hand on marktplaats (dutch ebay). these three together for my homelab. not a lot of computer power or memory, no bios options for network boots, or any other server features, but i love it.

it works you know! you stick an bootable usb in there, hold the alt-key on boot and thats it. you install your os, and you let it boot, no fuzz. the two mac minis have a built-in ethernet nic, the macbook doesn't, but they all have these old school thunderbolt interfaces. so the macbook is connected to my lab lan via thunderbolt to ethernet cable and one mac mini functions as a router so it has two network nics, the built-in + one thunderbolt nic.

i was running opnsense of the router mac mini for a bit, but it being bsd based, did not play nicely with the thunderbolt nic at all, it would work for a bit and then stop. now the machine itself runs proxmox, with a vyos router and a ubuntu management vm. the vyos one it fun, since its a declarative os, so all changes are made via the terminal and stored in a `config.boot` file, which it boots from everytime and which you can easily backup.

the entire setup is totally unstable, because i'm changing it all the time, as it should be. i currently run k3s with ovn-kubernetes cni and metallb load balancer in bgp mode using the vyos.