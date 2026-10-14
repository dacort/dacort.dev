---
title: "Greenfield vs. Brownfield: Verifiable vs. Unverifiable"
date: 2026-10-14T08:20:00-07:00
draft: false

tags: ["ai", "careers"]
showToc: false

cover:
  image: "cover.png"
  alt: "Split cartoon illustration under the headline \"Greenfield vs. Brownfield.\" On the left, on green grass under a bright sun, a smiling person cheers at a laptop next to a \"25m\" timer badge, with a dashed arrow up to a finished desktop app and phone app marked with a green checkmark. On the right, a frowning person stands ankle-deep in brown mud staring at a phone, surrounded by five pull request cards (one awaiting review, four blocked) tangled together by lines, with an hourglass nearby."
  relative: true
  hidden: true
---

> _This post is an experiment in a new AI-assisted voice to blog capture mechanism._

This is a follow-on post to [this one](/posts/software-doesnt-matter-anymore/). I want to dive a little bit more into greenfield, AI native coding versus brownfield coding, a term Adam Jacob used in [his presentation](https://youtu.be/BL561UDdeoA).

It's not about AI being great or bad at greenfield or brownfield. It's more about how developers in greenfield situations are learning entirely differently.

## Throwing tokens at it

Anthropic just released [a post](https://www.anthropic.com/engineering/redesigning-source-control) about how they rebuilt their source control, and so many different things around it, all by throwing Mythos at it. They said they had done a version of this earlier, threw Mythos at it, and it was 4x faster and used 20x less memory.

- In May they were merging ~2,500 changes a day. By September, 30,000+.
- A team of seven built it, and the migration took about five months.

This is essentially how companies are going to build now. They're going to say, hey, this doesn't fit our use case, throw a boatload of tokens (a yacht-load? a tanker-load?) at the problem, and just fix it. And seven people, which is not an insignificant number. (The post doesn't say how many tokens.)

That really changes how everything is happening, right?

I think Anthropic had it a little bit easier, though, because they rebuilt the entire source control thing from scratch and shifted over from one system to another. So it was entirely greenfield.

(Okay, mostly. They still had to ingest all their git history, but "same history in, same history out" is easy to check, so that part was verifiable.)

## Greenfield: 25 minutes on a Friday

I experienced this myself last week. It was Friday at 5:30 and I sat down, and I was like, I've been at my 2TB limit on Dropbox for a while, and I'm the only one that uses it.

> Build me a secure, shareable clone of Dropbox for Mac and iOS.

And I shit you not, 25 minutes later, I had a Mac client and an iOS client, and I could run it on my local NAS if I wanted to.

Obviously, there's a lot more to making that a real product. But the fact that I can do that on a $20 plan, in less than half an hour, with literally a one-line prompt, is ridiculous.

Does it work at scale? The bar doesn't apply there. Like I mentioned in my last post, we can start off with rough edges and refine them over time. It's easier to do that process.

## Brownfield: five PRs and a lot of chasing

Somebody I know just left and started a new AI native company, and they were talking about, oh, hey, my software factory does everything now.

Well, you know what my day looked like? I had five open pull requests across five different repositories, all part of changing a large existing repository of data transformations. All blocked by one person having to review the first one, and then by me having to chase down four or five other people to get approvals on all the other ones.

In an AI native world, that probably looks very different. But where I'm at, we're not quite there yet. It's still the human in the loop that's actually causing the issues.

And in brownfield, you've also got this corpus of technical patterns (it's not technical debt) that have built up over years, sometimes decades. Converting that into a greenfield code base, I don't think that's a solved problem yet.

## Verifiable vs. unverifiable

I think tokens can solve a lot of technical challenges, but they can't solve the integration pieces yet. Sure, the AI can go and figure out how to do it, but knowing that it's right? The trust isn't there yet, and part of that is because the unit and integration tests aren't there in the brownfield repository.

So I think it's still two root causes:

1. The human in the loop: reviews, approvals, chasing people down.
2. Verification: knowing the change is right.

And that second one is really key. I struggle with this a lot with infrastructure or data ETL changes. Yes, you can test with mock data or do a dry run. But often, at a certain scale, until you're in production, it's hard to know where some of these things will break. Unless you have a really good pre-existing test harness, right?
