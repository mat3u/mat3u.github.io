---
title: Domain Events - how to handle reality!
categories: [DDD, Events, Architecture]
date: 2017-01-23 20:01:12
---

<!--more-->

# What it is not?
# What it really is?

There is a great definition of what really domain event is:

> Domain Event is something that happened that domain experts care about. - Anonymous

As you can see this definition is strictly non-technical and that is the beauty of Domain Events. This is a technical concept with deep technical effects in application and architecture itself and still can be defined without any technical references. It is like that because the main value that it introduces to the application comes from the understanding of the problem at the business level. The good event is comaptible with the mental model of the problem of domain expert. The technical consequences - like doing something in reaction on event - works well only when events are modelled correctly.

![D(t0) -> D(t1) + Event](https://dl.dropboxusercontent.com/u/137842/mattstasch.net/Domain_Events/events_domain.png)

In the context of DDD and CQRS we can see domain event as the *product* of changing domain (like in chemistry). Let's say, we are sending a command to our system to publish the _Agreement_. We can expect that the state of the domain will be changed and the rest of the world will be notified with event `AgreementPublished`. In reaction to this event we can send mails or talk with some other service to say how fortunate we are because our Agreement was published. What is even better we don't have to do anything, someone else can consume our event and add their side-effect to this operation.

The sample above allowes us to distile a couple of basic rules that are defining how to work with domain events. First of all we have to remember that **every change in the domain should generate the event** - every (period). It means that everything that happened in the domain will be represented as event. Even if we are not planning to handle this event we should raise it, someone else will.

The second rule that emerges is fact that **when reading the state of the domain (Query) we must not generate any domain event** as domain is not changing. It might be a case for other type of events, but not for domain events. This is also interconnected with the theory behind READ side in CQRS and keeping it idempotent.

Third consequence of the fact that domain event is a *product* of chaning domain is the immutability of the source of event. It is a manifest of something that already has happened and as **it belongs to the past, we can't change it** (usually).


# How to use it in my application?
# Where are the benefits?

## Decoupling domain logic from side-effects
## Decomposition of complexity
## Events as Audit Log
## Time Machine - Event Sourcing
## Modelling using events - Event Storming

# What are the typical issues with this pattern?
As every complex pattern this also have some common misunderstandings and misconceptions. I'll try briefly to show you those I've already met and I'll start with those that are most common.

## It is command not an event!

## Your event handler is fat!

## Your event is fat also!

## You (don't) know who is listening!

## This event comes from everywhere!

# Summary

Bla bla bla
