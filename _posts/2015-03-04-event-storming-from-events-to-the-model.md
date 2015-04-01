---
layout: post
title: Event Storming - from events to the model
categories: ["Event Storming", DDD, Modelling]
date: 2015-03-04 22:34
---

I bet that all of us, developers, at least once started thinking about a domain model from designing data structures. This way of modelling applied to the complex domain almost always leads us to the solution that is not really effective in dealing with business cases. Moreover it is far from representing the real business domain - it represents a projection that is focused on our data store. The classical way of "producing" models for business domains treats events as a side effects of technical flows, not as a domain's first class citizens. In the "event storming" domain modelling starts from events, which are assumed to be key points of **business workflows**. The rest of the domain is built to support events.

<!--more-->

# TL;DR

1. Define events in the system
2. Define sources (commands, process managers) and actors
3. Group commands around aggregates
4. Implement...

Post-it, long piece of paper and people...

# Let’s play
Generally speaking "event storming" is about extracting domain from events which describe it. In most of the complex domains there are events that represent important changes in the state of our domain, simply begin with them. We'll need the following things:


* **Unlimited modelling** space - sounds impossible, but in most cases very long piece of paper will be more than enough. White board is also OK, but it is hard to "serialize" it after the meeting.
* **Post-its in various colours** - one colour represents one class of objects.
* **People who know the questions, and those who know the answers** - in fact, in most cases, stakeholders will be assumed here, but the guy that is doing an actual work in the company may be useful too.
* **A room without chairs** - sitting = sleeping, it's hard to go asleep during a meeting without chairs :). The key point here is to engage everyone into the work.

I'm assuming that there will be at least one person in the room who knows what event storming is, and this person will be the moderator. It's a good practice for moderator to place the first event on the modelling space. Simply put one post-it with the event name, a chosen colour will represent events. The modelling space represented by a long piece of paper should have a direction which will represent the time, so we can arrange events chronologically.

But what event actually is? There is a "simple" definition:

> Domain event is something that happened that domain experts care about.

Let business experts put events that are in their region of interest on the paper, and let them argue about how the business works (but don't let them kill each other)! They should work out the clean description of the business flow. The value here is to clarify complex workflows by finding common points. If they are not approaching common point, they must have found the misconception in their business - it is an opportunity to improve. Or maybe they are simply talking about the same thing from completely different perspectives. If one expert is responsible for invoicing and another one for delivery - they can talk about the same thing, but in two separated subdomains, so that thing looks completely different for each of them.

When all events are in place we can go to the next phase.

# Reverse engineering

Starting from the events we want to get to the point in which we have all important structures clearly visible on the modelling space. When we will think about events that are happening all the time around us everything has a more or less obvious cause. Similarly, in the domain, nothing happens without cause. We need to find all causes for events.

Event can be triggered by a command, by time or even by another event - so basically every event has the source. Obviously, event may also have more than one source i.e.: `AssessmentCompletedEvent` may be triggered by time when Assessment's end date expires or by user which manually completes it in the application. Our task is to discover sources of events. In this phase we need to put on the modelling space all commands, process managers and actors that are involved in generating events.

_Command_ is a well-known pattern and even with a bunch of rules of thumb that comes from [DDD](http://www.domaindrivendesign.org/) there is no reason to define it again.

_Process Manager_ is a simple creature that executes commands when event is raised, so if we need to execute command in reaction to event we need the Process Manager to do this work for us.

_Actor_ is an external source of activity - users, external systems and even time (here are some controversies) may be treated as an actor.

The moment we have defined all sources for our events, we can group commands around aggregates changed by them. Basically that should be iterative process where we are deciding which command modifies which aggregate. From my perspective this might be the most difficult part of the modelling as designing good aggregate is always hard & tricky!

# Implement!

The process described above should generate something :) that theoretically should be easy to express as a code. We have domain aggregates, commands that operates on them and events that represents state changes in aggregates. Every artefact that we generate before can be easily represented by building block from DDD and match to CQRS/ES architecture. There is nothing better to do than implement this model.

# Is Event Storming good for my project?

From my point of view any **domain** can be modelled in this way.

# Bibliography

1. [Ziobrando's Event Storming Posts](http://ziobrando.blogspot.com/search/label/EventStorming)
