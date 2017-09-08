---
title: HATEOAS - introduction
categories: [Architecture, REST, HATEOAS]
date: 2017-09-08 21:14
---

# HATEOAS - introduction

In a couple of my previous projects, I was on the way to make *true [REST][REST]* API. By "true REST" (irony assumed) I mean REST on the third level of [Richardson Maturity Model][RICHARDSON]. After those projects, I'm amazed by idea of [**HATEOAS**][WIKI] (even if resulting API is not the REST at all).

<small>In following examples I'll use JSON as data representation, but the serialization method is orthogonal to the problem. In fact, XML will be even more suitable to represent links.</small>

## HATEOAS?

> **H**ypermedia **A**s **T**he **E**ngine **O**f **A**pplication **S**tate - is a constraint of the REST application architecture. An application provides additional information to navigate the REST interfaces dynamically by including links in the responses.

In fact, it is **that** thing which differentiates the REST from the rest of the world. In RPC you have to exactly know where is your endpoint, where should you send the data and how following operations are named. In REST you have to know only the root endpoint which should respond you with enough data to explore application's resources. Consecutively all responses should contain links to next resources or actions. Sample HATEOAS-enabled application might return following document:

```json
{
    "serverTime": "2017-09-10T12:20:22",
    ...
    "_links": [
        { "rel": "books", "href": "/v2/books", "method": "GET" },
        { "rel": "authors", "href": "/v1/authors", "method": "GET" }
    ]
}
```

We can see here that application offer us two resources `orders` and `authors`.
Retrieved JSON contains special node `_links`, which contains a set of links to these resources. Each link consists of three important elements:

* `rel` - name of the relation
* `href` - URI to the resource
* `method` - HTTP method used to access this relation

First two elements are similar to the attributes of the [anchor tag (`<a>`)][ANCHOR] from HTML which is also representing (if used correctly) navigation link to another resource. The third one is an extension that is used when creating smart clients.

When asking root endpoint of the server you immediately know where are located resources and which are available to you. If they were moved or renamed your application is not stuck with 404 until someone will fix the link in configuration or even in implementation - the worst case. What is really important, those links are contextual and should represent what requesting user can see or do. For example, if you are an *Administrator*, the response may contain an additional link to users resource:

```json
{ "rel": "users", "href": "/admin/v1/users", "method": "GET" }
```

As you can see the response is easily understandable and could be used without any problems by a client application. What is important those links are designed to be accessed by machines rather by humans.

How can it be useful? I'm not moving my resources anywhere! My API is stable! Let's explore how it can be used.

## Sooo, how it can be useful for me?
I'm going to show you two examples from my previous projects. They might be not suitable for you, but I hope it will show you how useful HATEOAS is.

## The Crawler
In the first project in which I was using HATEOAS (and REST in fact) for months I was implementing rich REST API with links, E-Tags and tons of other stuff from scratch in Node.js (not my decision ;). When I was writing the whole infrastructure to support HATEOAS I have a strange feeling that it might be overkill and no one will ever use it. Fortunately, I was responsible to write one of core components that benefit from HATEOAS.

But one of our use case required to search documents, and we have chosen ElasticSearch to do the work. But ES wasn't out main data storage, so there was requirement to synchronize all documents to ES. The first thought is to push the changed document to some queue and put it in ES. For good reasons, we were not using any queues at all in the infrastructure. This post is not a place to discuss that. The idea that was already battle-tested by our *Architect* in previous projects was to poll data rather push it.

The main component that was doing the work was a **Crawler**. The idea was simple:

1. Connect to synchronization endpoint:

```
> GET /books?afterId=6453
  302 Location: /v1/books?afterId=6453

> GET /v1/books?afterId=6453
```

2. Service responds with a **page** of recently updated documents and link to next page:

```json
{
    "members": [...],
    "_links": [
        { "rel": "next", "href": "/v1/books?afterId=6521", "method": "GET" },
        ...
    ]
}
```
Is possible that the page will be empty and the `next` link may be the same as initial one. The crawling process will be continued.

3. Push documents to ES and go to next page
4. Go to point 1

Crawler was stateful to make sure that its restarts are not breaking synchronization process. It might be seen as overkill but it creates a vast number of use cases, to mention a couple:

1. 3rd party may write their own crawlers and can access all data anytime!
1. New crawlers pushing data to another service may be started anytime, existing one can be restarted from document with id=0,
1. The crawler doesn't have to understand documents so it can be used by number of services because it understands hypermedia,
1. Any changes in deployment of the service can be hidden under `302` pointing to new `Location`. Next page will be taken from a new address.

> **Please note** that the real implementation was much more complicated, it was utilizing parallel synchronization, document transformation and many other tricks to make it efficient. But the main idea of links between resources was working as presented here.

## Hypermedia-driven UI
While the previous example might be a little bit exotic for many of you the one I'll show now should be very well known. Let's imagine that you are writing simple document management system, your task is to add `[DELETE]` button to the document preview form. The button should be only enabled if a document is not deleted (you can see deleted documents) and a user has rights to do so. What will be the naïve (and most common) implementation? It will look like this:

```javascript
<Button action={this.deleteThisThing} enabled={!this.resource.isDeleted && this.user.roles.contains(ROLE.editor) && otherCondition && !blaBlaBla}>Delete</Button>
```

 Have you ever had a feeling that when writing such code you are missing the point? This code is very error prone, if the logic that decides who can delete the document or under what circumstances will change, then a developer will be responsible to find all places where this logic is duplicated and change it. If he'll skip one place or change this logic in a different way, we have a bug. This is the expensive way of writing software, which on the first sight seems to be the cheap one!

This is what I was doing for years in my projects, but always I had that feeling that there is a better option. And, yes, no surprise - HATEOAS! Using links to determine what action should be available to the user and which is illegal, simplifies a lot in client applications. The front-end implementation is then fairly simple:

``` javascript
<Button action={this.getDeleteHandler(this.resource.links.get("delete")) enabled={this.resource.links.has("delete")}}>
```

This can be even wrapped with some better abstraction to make it more readable. What is even more interesting, the user will not be able to perform such operation by simply enabling control that is triggering it, because this control won't have a URI and method to perform this action. It doesn't know where to send the request to do this operation. That is why I'm generating handler rather just passing it.

You still have to check this on the server side, but with some reasonable effort, it could be done using the same code that was used to generate hypermedia.

## Conclusion
As you can see HATEOAS can remove a lot of business logic that was duplicated in your client application (potentially in many of them) and also makes them insensitive to changes in the structure of resources. Resources can be even extracted to separated ~~micro~~service.

In next post, I'll show how to implement simple HATEOAS-enabled API in ASP.NET.

#### Not covered
1. Reliable URIs - relative vs absolute
1. API versioning - URI or Headers?

## Bibliography

1. [Richardson Maturity Model][RICHARDSON]
1. [REST - Roy Fielding][REST]
1. [HATEOAS - Wikipedia][WIKI]

[RICHARDSON]: https://martinfowler.com/articles/richardsonMaturityModel.html
[ANCHOR]: https://www.w3.org/TR/html4/struct/links.html#adef-href
[REST]: http://www.ics.uci.edu/~fielding/pubs/dissertation/rest_arch_style.htm
[WIKI]: https://en.wikipedia.org/wiki/HATEOAS
