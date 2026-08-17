---
title: "rebuilding this blog with only claude code prompts"
date: 2026-08-12
tags: [meta, ai, claude code]
---

lets capture the moment we're in, in a few years this is going to feel ancient again.

i didn't like the framework for the blog, mkdocs. mkdocs is fine, but doesn't work well for a blog.
not trying to do anything fancy, i do really like having my posts in markdown,
so ended up going for hugo. still with the pre-ai thinking, "oh man, i have to redo the entire blog..."

list of my claude code prompts since the rewrite untill now:

- **go ahead and rebuild my blog into a hugo blog, i want to be able to test it locally thats the goal for now. use the PaperModX theme**
- make titles like Posts, Tags and Search all lower case in the headers. also light theme by default, also drop the RSS feed, add LinkedIn
- https://www.linkedin.com/in/stan-syfert-56291b120/ _(sent mid-turn, correcting the LinkedIn URL I'd guessed)_
- when i click through it now it links to my live website
- possible to make this a drop in replacement for mkdocs and serve it on gh pages as is, without changing gh pages settings?
- can we use this as a logo, add to it to the home page, somehow add it as favicon etc _(with the goblin image attached)_
- i missed the gh pages stuff, ready to deploy?
- _(answering my deploy question, no option selected)_ and merge with main to make it work.
- looks good, drop the mkdocs stuff
- did you change the papermodx repo? whats with the dirty thing? _(sent mid-turn)_
- commit and push it
- align the goblin to the right, so its aligned with hello world _(with the screenshot attached)_
- _(answering my alignment question)_ Left, above the title
- are you able to align the goblin inside its frame more centrally? are you able to see that on the bottom it has more black space? _(sent mid-turn)_
- is it supported to make the links to my GitHub and LinkedIn more explicit, with a word next to the logo?
- give me a list of my prompts since this one: "go ahead and rebuild my blog into a hugo blog...

before:

![the mkdocs blog, terminal theme](/images/blog-before-mkdocs.png)

after:

![the hugo blog, with the goblin](/images/blog-after-hugo.png)
