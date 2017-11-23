---
title: HATEOAS in ASP.NET WebAPI2
categories: [Architecture, REST, HATEOAS]
date: 2017-11-21 20:19
---

In [previous post]({{ site.baseurl }}{% post_url 2017-09-08-HATEOAS-introduction %}) I've described how HATEOAS works from the theoretical point of view. In this post I'll show you first, very naïve implementation in ASP.NET WebAPI2.

<!--more-->

ASP.NET WebAPI 2 does not offer any native support for Hypermedia and when I was using it recently there were no comprehensive library (or I didn't found it) that would offer everything one may need to work with Hypermedia. Yet, there are some libraries that may be useful. One of them is [Hyprlinkr (by Ploeh)](https://github.com/ploeh/Hyprlinkr), it is the helper library that is focused on creating links in safe and convenient way. I'll be using it in following examples.

HATEOAS is orthogonal to the data representation that is returned from the server, but it is in the most cases presented with RESTful resources, so I'm going to use resources in the following examples with JSON representation.

There are at least two options how hypermedia in JSON could be represented:

```json
{
    "data": {
        "id": 234,
        "name": "Matt Stasch"
     },
    "links": [
        {...}
    ]
}
```

or:

```json
{
    "id": 234,
    "name": "Matt Stasch",

    "_links": [
        {...}
    ]
}
```

I'll be using second one in my examples. I don't feel if there is any significant difference between those implementations in terms of practical usage.

## Links and resources

First thing we need to do is to define class that will hold link information:

```csharp
public class Link
{
    protected Link(string rel, string href, string method = null)
    {
        // Validation

        Rel = rel;
        Href = href;
        Method = method ?? "GET";
    }

    public string Rel { get; }
    public string Href { get; }
    public string Method { get; }

    public static Link To(string relation, Uri href, string method)
    {
        return new Link(relation, href.ToString(), method);
    }

    // other factory methods
}
```

I've introduced fabrication method just to make it more readable in later usage but in fact this class is just a container for data. To create new link just write: `Link.To("self", uri)`. Second thing we need is the base class for our resources (in fact representations). I'll define it as abstract class called `Resource`:

```csharp
[DataContract]
public abstract class Resource
{
    protected Resource()
    {
        Links = new List<Link>();
    }

    [DataMember(Name = "_links")]
    public ICollection<Link> Links { get; }
}
```

I've added `[DataContract]` attribute to the class definition to control the name of the only property during serialization, but this could be achieved in many different ways. Having such "infrastructure" we can define our first "real" resource representation:

```csharp
public class InvoiceResorce : Resource {
    public Id Id {get; set;}
    public Customer To { get; set; }
    public ProductList Products { get;set; }
}
```

We can return this resource from our controller in following way:

```csharp
public InvoiceResource Get(Id id) {
    var invoice = _invoiceRepository.GetById(id);

    // Handle 404, 403, 401 ...

    var representation = TranslateToResource(invoice);

    representation.Links.Add(
        Link.To("self", Uri.GetLink<InvoicesController>(c => Get(id)))
    );

    representation.Links.Add(
        Link.To("add-payment", Uri.GetLink<InvoicesController>(c => AddPayment(id, null)), HttpMethods.Put)
    );

    return representation;
}
```
> `Uri.GetLink<TController>(expr)` method comes from Hyprlinkr library and it is the easiest way to get URI to endpoint I've seen for WebAPI 2. You can notice that I've to put `null` as second argument in `add-payment` relation - this is actual Payment object value (not needed to create URI). I don't see any workaround at the moment for this problem.

In this example adding links to the resource is quite readable but still messy, Simple thing needed to fix that is to create extension method to simplify it:

```csharp
public static class ResourceExtensions
{
    public static TResource LinksTo<TResource>(this TResource resource, string rel, Uri href, string method = null)
        where TResource : Resource
    {
        resource.Links.Add(Link.To(rel, href, method));

        return resource;
    } 
}
```

And in result we can refactor code above to the following form:

```csharp
public InvoiceResource Get(Id id) {
    var invoice = _invoiceRepository.GetById(id);

    // Handle 404, 403, 401 ...

    return TranslateToResource(invoice)
        .LinksTo("self", Uri.GetLink<InvoicesController>(c => Get(id)))
        .LinksTo("add-payment", Uri.GetLink<InvoicesController>(c => AddPayment(id, null)), HttpMethods.Put);
}
```

At this point you are ready to send hypermedia to your clients, but there are still domr issues with this code.

#### In this code relations are added to the representation by hand. Is that OK?

Well, as I said this is naïve implementation of hypermedia. In my real projects the decision if particular relation should be added to returned representation depends on some security policy, the state of the resource and so on, so the more realistic case would look like this:

```csharp
public InvoiceResource Get(Id id) {
    var invoice = _invoiceRepository.GetById(id);

    // Handle 404, 403, 401 ...

    var representation = TranslateToResource(invoice)
        .LinksTo("self", Uri.GetLink<InvoicesController>(c => Get(id)));

    if (!invoice.IsPaid) {
        representation = representation.LinksTo("add-payment", Uri.GetLink<InvoicesController>(c => AddPayment(id, null)), HttpMethods.Put);
    }

    if (userSecurityPolicy.IsSomeImportantUserRole) {
        representation = representation.LinksTo("cancel", Uri.GetLink<InvoicesController>(c => Cancel(id)), HttpMethods.Delete);
    }

    return representation;
}
```

To make it consistent between many layers of application I'm using some abstracted source of truth that could be used then to automagically create those links.

#### How to represent collection of resources?

Actually collection is also a resource:

```csharp
[DataContract]
public class ResourceCollection<TResource> : Resource
    where TResource : Resource
{
    [DataMember(Name = "members")]
    public ICollection<TResource> Members { get; set; }
}
```
Collection can have their own links, like `create` or if this is just one page of results link to the next page.
Aaaand, yes... all members in collection are resources too, so all of them should have their own links that depends on their internal state ;). That's a lot of links and potentially a lot of ifs.

That is all in terms of this simple implementation in WebAPI 2. There are still some issues to be addressed in next posts, so stay tuned!