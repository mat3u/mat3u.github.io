---
title: k-means - Dive into F#
categories: ["Functional Programming", F#]
date: 2015-02-08 20:11
---

Some time ago I've started to learn F#, and couple days ago I had an opportunity to write something that actually works. I was implementing [group of algorithms](https://www.cs.drexel.edu/~salvucci/publications/Salvucci-ETRA00.pdf) which are detecting eye movement events in signal recorded by Eye Tracker. During this work I've implemented classic ML algorithm: [k-means](http://en.wikipedia.org/wiki/K-means_clustering). I've tried to make it as generic as possible.

You can find the full source code of this algorithm (and tests) **[here](https://gist.github.com/mat3u/73d195385aa00f2d12f5)**.

<!--more-->

k-means is very simple yet effective clusterization algorithm which requires just one parameter: `k` - number of groups.

Pseudocode for this algorithm: 

> 1. Initialize vector of centroids with `k` random points,
> 2. Assign points to closest centroid,
> 3. Calculate new vector of centroids by calculating centroid for each group created in step 2,
> 4. If stop criteria is not met go to point 2

# Interface

To clarify the interface of the algorithm I've created three types to constrain functions that will concretize my algorithm for particular data type:

{% highlight fsharp linenos %}
type Distance<'elem, 'cost when 'cost : comparison> = 'elem -> 'elem -> 'cost
type Centroid<'elem> = 'elem seq -> 'elem
type Initializator<'elem> = int -> 'elem seq -> 'elem seq
{% endhighlight %}

`Distance` as the name says it's a function that for given two object calculates the distance between them, for example for points it could be euclidean distance, and for texts Hamming distance. In this particular implementation I'm not expecting distance to be given in any particular type, it have to be comparable. It is not defined in this interface, but distance function have to fulfill [general requirements for distance functions](http://en.wikipedia.org/wiki/Distance#General_case).

`Centroid` calculates centroid (center of the mass) of group of objects, again for group of 2D points it could be average of *Xs* and *Ys*: $$c_x = \frac{1}{n}\sum^{n}_{i}{X_i}$$, $$c_y = \frac{1}{n}\sum^{n}_{i}{Y_i}$$ and in result centroid will became: $(c_x, c_y)$.

`Initializator` generates initial vector of centroids.

# Initialization

There is many ways to initialize vector of centroids, in my solution I'm choosing `k` random points from dataset:
{% highlight fsharp linenos %}
let randomSubset' (rng: System.Random) k data =
    let n = Seq.length data

    match k with
    | 0 -> Seq.empty
    | k -> seq {
        for k in [1..k] do
        let p = Seq.nth (rng.Next(n)) data
        yield p
    }

let randomSubset k data =
    randomSubset' (new System.Random()) k data
{% endhighlight %}

I split this function into two parts: first of all I created `randomSubset'` function in which I can explicitely inject a Random Number Generator. I did this because I've started writing this code from tests and in this way I was able to make tests repetitive. Then for simplicity of usage I created `randomSubset` which is injecting the default RNG. 

I've used here a simple convention of `f'` and `f` as pair of generic and concretized function.

Unfortunatelly if `n` is not much larger than `k` there is possibility that the same point will be returned more than once (it depends on implementation of RNG), but for my purposes (k~60, n~10M) this is not an issue.

# Calculating new centroids

{% highlight fsharp linenos %}
let closest (distance: Distance<'elem, 'cost>)
            (centroids: 'elem list) element =
    centroids |> List.minBy (fun c -> distance c element)

let findNewCentroids (distance: Distance<'elem, 'cost>)
                     (centroid: Centroid<'elem>)
                     data centroids =
    let closestCentroid = centroids |> Seq.toList |> closest distance
    data
    |> Seq.groupBy (fun e -> closestCentroid e)
    |> Seq.map (fun (c, e) -> centroid e)
{% endhighlight %}

First function calculates for particular element in dataset distances to all centroids and selects one that have minimal distance. Second function finds closest centroids for each element in dataset and performs grouping by assigned centroid. Then for each group is calculated new centroid. This `findNewCentroids` function is the heart of the algorithm.

# Stop criterion

{% highlight fsharp linenos %}
let checkStop current next =
    let c = current |> Seq.sort
    let n = next |> Seq.sort
    Seq.exists2 (fun a b -> (distance a b) <> (distance a a)) c n |> not
{% endhighlight %}

The algorithm has converged if vector of centroids has not changed after iteration. To check this fact I'm using one of features of distance function: $$ D(x,y) = 0 \iff x = y $$, and I'm checking if there is a pair of elements in current and new vector that have distance not equal 0 (I'm assuming here that vectors are somehow sorted):

$$ (\exists j)(D(C_{i+1, j}, C_{i,j}) \neq 0 $$

I decided to hardcode this function, and not let specify it from outside because it is a criterion that is described by original algorithm definition. If you'll use this code and need to use different stop criterion just pass it as parameter of `execute'` function.

# Iterations

{% highlight fsharp linenos %}
let execute' (randSubset: Initializator<'elem>)
             (distance: Distance<'elem, 'cost>)
             (centroid: Centroid<'elem>)
             (k: int)
             (data: 'elem seq) = 
    // let checkStop = ...

    let update = findNewCentroids distance centroid
    let rec epoch data current =
        let next = update data current

        let stop = checkStop current next

        match stop with
        | true -> current
        | false -> epoch data next

    let initial = randSubset k data
    epoch data initial
{% endhighlight %}

And in the last part of algorithm I'm recursively iterate checking if stop criterion is met. When is met I can return `current` vector of centroids.

# How to use it?

The usage is very simple, just look at the test method I wrote to check if my algorithm is working as expected:

{% highlight fsharp linenos %}
let avg = Seq.average
let distance a b = abs(a - b)

[<Test>]
let ``Should find centroids of given groups`` () =
    let centroids = seq [1.0;5.0;9.0]
    let precision = 0.1
    let data = seq {
        for c in centroids do
        let n = [-1.0 .. precision .. 1.0] |> List.map (fun f -> f + c)
        yield! n
    }
    let randomizer = kMeans.randomSubset' (System.Random(50))
    
    let newCentroids = kMeans.execute' randomizer distance avg 3 data
    let result = newCentroids |> Seq.sort |> Seq.toList

    Assert.AreEqual(1.0, result.[0], 0.1)
    Assert.AreEqual(5.0, result.[1], 0.1)
    Assert.AreEqual(9.0, result.[2], 0.1)
{% endhighlight %}

This test generates some data around given points then pass them to algorithm and checks if returned vector is equal to original one. The number 3 in the invocation is the `k` parameter.

There is also `execute` function that has provided default initialization function, so there is only need to apply `Distance` and `Centroid`. In test I've used again version with `'` to be able to specify RNG explicitely.

In the test I'm using simplest distance for real numbers: $$ abs(a-b) $$ and for calculating centroid I'm using average of values, and basically that'a all you need to do for real numbers. I believe that functions for other types won't be much more complicated.


This is the end of story - simple algorithm for complex data processing. I suppose my F# may be better, so I'm waiting for comments.
