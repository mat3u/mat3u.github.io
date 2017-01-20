---
title: "Better QueryDispatcher"
categories: [CQRS, Architecture]
date: 2017-01-20 20:45
---

Since I wrote the [post about CQRS](/2015/04/CQRS-Simple-architecture) I was asked couple times how to use presented `QueryDispatcher` and why its usage is so ugly. In the moment I was writing that post, my idea was to show the simplest implementation of a complex idea. Hoped to make simple, yet working implementation. I wanted to make it a good example how to start, but without adding non-essential complexity to the problem discussed. I've never assumed that this will be production ready solution (actually it might be ;). In this post I'll try to show the better implementation of `QueryDispatcher` that is easier to use in our code.

<!--more-->

The main problem in that `QueryDispatcher` was the way how its execution looked like:

<script src="https://gist.github.com/mat3u/0e0e99fdb1e0a01010cb4353974d421d.js?file=CallingOldDispatcher.cs"></script>

Yep, it's quite verbose ;). What can we do with it? We can change `IQueryDispatcher` interface and implementation below to force C# compiler to infer as much as possible from `query` object itself. The rest we'll have to do manually. The result we are expecting will look like this:

<script src="https://gist.github.com/mat3u/0e0e99fdb1e0a01010cb4353974d421d.js?file=CallingNewDispatcher.cs"></script>

## Magic

It could be done in couple ways, let have a look on the one I like the most:

<script src="https://gist.github.com/mat3u/0e0e99fdb1e0a01010cb4353974d421d.js?file=BetterQueryDispatcher.cs"></script>

As you can see the `Execute` method of the dispatcher is now concretized only with single generic type `TResult`. The type of the query is now gone. We are accepting `IQuery<T>` interface as the only argument, so we are unable to use this beautiful `Resolve<>` method from Autofac. We need to do more magic, and this is quite ugly magic - REFLECTION ;). We have to construct manually type of the requested handler using the `MakeGenericType` method. This is done in line 12 - we have to provide all generic types that were previously available out of the box.

This is not the end of the magic. In next statements, we are using an interesting property of `dynamic` type to call directly (line 21) method `Execute` of an actual handler. This magic is done to avoid calling it using reflection. Additionally, we are making possible to throw exceptions from the handler without wrapping it into `TargetInvocationException`. This code will be executed as any regular code we write.

Method `TryResolve` (non-generic version) is returning the constructed object as `System.Object`. Why are we unable to cast this type to the type described in `handlerType`? Actually, we don't have at the compile-time enough information to do so. The type of the `query` object is `IQuery<TResult>` so there is no way to construct in regular code (without reflection) correct type that can be used for casting, it would require access to `TQuery`. Happily, `dynamic` types can be used to wrap this object and call on them `Execute` method that couldn't be ensured at compile time (compilator is not able to verify if this code is correct without using `dynamic`).

So, we have a right handler, we can now call it. Ok,i but we just have to cast `query` object to `dynamic`.

> Ok...wait what?!

This is because `IQueryHandler<TQuery,TResult>` is expecting `TQuery` as the parameter of `Execute` method and without casting we'll call it with `IQuery<TResult>`, so this object will be too general for the method. What is interesting by casting it do `dynamic` we make .NET runtime to cast it to the right type during the call.

## Is that slow?

As you may hear, reflction is not the fastest way to execute C# code ;). Yes, this code is much slower than the previous implementation. I did some experiments:

I've compared old implementation with the new one, by calling it 10K times with randomly selected query (from 2 queries), and I've repeated tests 10 times. Results were recorded with `Stopwatch`.

> So, how slow it is?

Let's assume that execution time of old implementation is **1**, then the new one is **43.45**. Wow, it's slow! Actually, _average time of 95% of measurements was still under 2ms_ on my machine.

> To make things clear: it is significantly slower, but still not comparable to the time consumed by database query!

Can we do something about it? Sure, we can. The first thing that I think is slow is the construction of the type (line 12), we can use memoization to cache constructed types and avoid constructing it in each call. An implementation might look like this:

<script src="https://gist.github.com/mat3u/0e0e99fdb1e0a01010cb4353974d421d.js?file=StaticallyCachedQueryDispatcher.cs"></script>

Is it any better? The average time for this one (from 95% of measurements) is **3.15**. Obviously, the first call with an unknown `query` is long, but after 10K repeats average time is more than good.

Any drawbacks of this implementation? It is consuming memory even for rarely used queries, but this is just an information about a relation Type-Type, not the `Type` object itself. As applications have some limited number of query objects, so the memory footprint should not be significant. The second problem might be a race condition during reading cache. The only drawback I can see here is that it is possible that same type will be created many times. But as the `Type` object created will be exactly the same, even if we'll overwrite existing item in the dictionary the information will not be lost. I'm assuming both issues to not be a big problem.

Can it be any better? I'm pretty sure that being limited to reasonable language constructs (readable, so no IL emission) it is impossible to make it much faster. But maybe I'm missing something? If you have any ideas I'd happy to hear about it!
