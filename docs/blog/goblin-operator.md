# i stuck a goblin inside a k8s cluster

could i create a small LLM agent with limited permissions, that can still be useful?

[yes i can, and i did!](https://github.com/sguldemond/goblin-operator)

![goblin-scout](images/goblin-scout.png)

the idea is that when an issue occurs in the middle of the night, the goblin pings you on telegram (or slack, whatever).
you see the proposed solution and you can chat with the goblin about it.
OR you chat some more with it to come up with some fix, accept it and get back to sleep.
OR you decide this needs deeper investigation, and get you a** out of bed.

i've been toying with the idea to build an k8s operator for a little bit,
started some time back with an idea for a flight radar/tracker,
which was kind of a cool idea, but it also wasn't really doing enough for me.

(on that subject, there is such a difference when you have some kind of fire inside,
some project idea that you can't let go.
my workflow has always been,
getting inspired,
start thinking about what i could and want to build,
start designing and get to a PoC/MVP,
build a prototype.
with AI this workflow has been greatly sped up)

back to my the little creature inside my k8s cluster, the core of the concept is:
a small AI agent inside a cluster that can assess a range of issues,
and potentially act on them with some limited patching work.
in the process i would tick of a few cool things:
k8s operator + AI agent + Telegram bot

the flow:

- controller listens for issue regarding pods (e.g. oomkilled, stuck in pending, etc).
- a "remeditation CR" is created, which on its turn spins up a "goblin scout"
- this scout is a small program that gets fed with the context of the issue first
- the scout proposes a solution, from this point on you can communicate with this goblin
- it will e.g. purpose a patch, and only with explicit consent from the human will it be applied
- issue gets fixed, remeditation CR gets closed!

the telegram part is just an interface to communicate with the scout, you can also open up a shell to the scout container.

again a link to the code here, in case you missed the funny hyperlink on top:

[github.com/sguldemond/goblin-operator](https://github.com/sguldemond/goblin-operator)

wowowo, its a work in progress, and will probably be abandoned, so don't come knocking, cya!