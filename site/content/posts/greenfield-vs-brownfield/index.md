---
title: "Greenfield vs. Brownfield: Verifiable vs. Unverifiable"
date: 2026-10-14T08:20:00-07:00
draft: false

tags: ["ai", "careers"]
showToc: false

cover:
  image: "cover.png"
  alt: "TODO — written once the cover image exists"
  relative: true
  hidden: true
---

> _This post is an experiment in a new AI-assisted voice to blog capture mechanism._

This is a follow-on post to [this one here](/posts/software-doesnt-matter-anymore/). I want to dive a little bit more into AI native coding, or greenfield coding, versus brownfield coding, which is a term that Adam Jacob used in [his presentation](https://youtu.be/BL561UDdeoA).

It's not about AI being great or bad at greenfield or brownfield. It's more about how developers that are in greenfield situations are learning entirely differently.

## Throwing tokens at it

Anthropic just released [a post](https://www.anthropic.com/engineering/redesigning-source-control) about how they basically rebuilt their source control. They rebuilt so many different things around their source control, all by throwing Mythos at it. They actually said that they had done a version of this earlier, and they threw Mythos at it, and it was 4x faster and used 20x less memory.

- In May they were merging ~2,500 changes a day. By September, 30,000+.
- A team of seven built it, and the migration took about five months.

This is essentially how companies are going to build now. They're going to say, hey, this doesn't fit our use case. We're going to throw a boatload of tokens (a yacht-load? a tanker-load?) at the problem, and seven people, which is not an insignificant number of people to work on this, and just fix it. (The post doesn't say how many tokens. I'm guessing it's a lot.)

That really changes how everything is happening, right?

I think Anthropic had it a little bit easier, though, because they rebuilt the entire source control thing from scratch and they shifted over from one system to another. So it was entirely greenfield.

(Okay, mostly. They still had to ingest all their git history and keep its ordering intact. But "same history in, same history out" is easy to check, so that part was verifiable.)

## Greenfield: 25 minutes on a Friday

I experienced this a little bit myself last week. It was Friday at 5:30 and I sat down and I was like, you know, I've been at my 2TB limit on Dropbox for a while. I'm the only one that uses it.

> Build me a secure, shareable clone of Dropbox for Mac and iOS.

And I shit you not, 25 minutes later, I had a Mac client and an iOS client. I could run it on a server, my local NAS if I wanted to.

Obviously, there's a lot more to making that a real product. But the fact that I can sit down and do that on a $20 plan, in less than half an hour, with literally a one-line prompt, is ridiculous.

Does it work at scale? The bar doesn't apply there. Like I mentioned in my last post, we can start off with rough edges and refine them over time. It's easier to do that process.

## Brownfield: five PRs and a lot of chasing

Somebody that I know just left and started a new AI native company, and they were talking about, oh, hey, my software factory does everything now.

Well, you know what my day looked like? I sat down, I had five open pull requests across five different repositories, all part of changing a large existing repository of data transformations. All blocked by one person having to review the first pull request, and then subsequently blocked by me having to chase down four or five other people to get pull request approvals on all the other ones.

In an AI native world, that probably looks very, very different. But where I'm at, we're not quite there yet. It's still the human in the loop that's actually causing the issues.

And in brownfield, you've also got this corpus of... it's not technical debt, but this corpus of technical patterns that have built up over years and sometimes decades. Converting that brownfield code base into a greenfield one, I don't think that's a solved problem yet.

## Verifiable vs. unverifiable

I think tokens can solve a lot of technical challenges. But they can't solve the integration pieces yet. Sure, the AI can go and figure out how to do it, but knowing that it's right? The trust isn't there yet. And part of that is because the unit tests and integration tests aren't there in the brownfield repository.

So I think it's still two root causes:

1. The human in the loop: reviews, approvals, chasing people down.
2. Verification: knowing the change is right.

And that second one is really key. I struggle with this a lot with infrastructure changes, or data ETL changes. Yes, you can do some testing with mock data, or you can do a dry run. But often, when you're at a certain scale, until you're in production, it's hard to know where some of these things will break. Unless you have a really good pre-existing test harness, right?
