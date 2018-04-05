---
title: HATEOAS in ASP.NET WebAPI2
categories: [Architecture, REST, HATEOAS]
date: 2017-11-24 08:19
---

In [previous post]({{ site.baseurl }}{% post_url 2017-09-08-HATEOAS-introduction %}) I've described how HATEOAS works from the theoretical point of view. In this post I'll show you very naïve implementation in ASP.NET WebAPI2.

<!--more-->

ASP.NET WebAPI 2 does not offer any native support for hypermedia and when I was using it recently there were no comprehensive library (or I didn't find it) that would offer everything one may need to work with Hypermedia. Yet, there are some libraries that may be useful. One of them is [Hyprlinkr (by Ploeh)](https://github.com/ploeh/Hyprlinkr), it is a helper library that is focused on creating links to particular methods in controllers in safe and convenient way. I'll be using it in following examples.

HATEOAS is orthogonal to the data returned from the server, but it is in the most examples presented along RESTful resources, so I'm going to use resources in the following examples as well. I'll be using JSON as serialization format.

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

I'll be using second one in my examples. I don't feel if there is any significant difference between those implementations in terms of practical usage. It is my good feeling that second one for some reason is more popular - no idea why.

## Links and resources

First thing we need to do is to define class that will hold link information. It will be simple container for data that will serialize to `{"rel": ..., "href": ..., "method": ...}`:

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

I've introduced fabrication method just to make it more readable. To create new link just write: `Link.To("self", uri)` instead of `new Link("self", uri")`.

Second thing we need is the place in resource to store collection of links. To achieve that I'll create a base class for our resources (representations). I'll define it as abstract class called `Resource`:

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

I've added `[DataContract]` attribute to the class definition to control the name of the `Links` property during serialization, but this could be achieved in many ways. Having such "infrastructure" we can define our first "real" resource representation:

```csharp
public class InvoiceResource : Resource {
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
        Link.To("self", 
                Uri.GetLink<InvoicesController>(c => Get(id)))
    );

    representation.Links.Add(
        Link.To("add-payment",
                Uri.GetLink<InvoicesController>(c => AddPayment(id, null)), 
                HttpMethods.Put)
    );

    return representation;
}
```
> `Uri.GetLink<TController>(expr)` method comes from [Hyprlinkr](https://github.com/ploeh/Hyprlinkr) library and it is the easiest way to get URI to endpoint I've seen for WebAPI 2. 
> You can notice that second argument in `add-payment` relation URI is `null` - this is actual Payment object value (not needed to create URI). I don't see any workaround at the moment for this problem.

In this example adding links to the resource is easy but not succinct. I can improve that by creating extension method:

```csharp
public static class ResourceExtensions
{
    public static TResource LinksTo<TResource>(
        this TResource resource,
        string rel, 
        Uri href, 
        string method = null)
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
        .LinksTo("self", 
                 Uri.GetLink<InvoicesController>(c => Get(id)))
        .LinksTo("add-payment", 
                 Uri.GetLink<InvoicesController>(c => AddPayment(id, null)),
                 HttpMethods.Put);
}
```

At this point, our endpoint is sending hypermedia along with our resource to the client, but there are still some issues with this code.

#### In this code relations are added to the representation by hand. Is that OK?

Well, as I said this is naïve implementation of hypermedia. In my real projects the decision if particular relation should be added or not depends on security policy, the state of the resource and context of execution. The more realistic case would look like this:

```csharp
public InvoiceResource Get(Id id) {
    var invoice = _invoiceRepository.GetById(id);

    // Handle 404, 403, 401 ...

    var representation = TranslateToResource(invoice)
        .LinksTo("self", Uri.GetLink<InvoicesController>(c => Get(id)));

    if (!invoice.IsPaid) {
        representation = representation.LinksTo(
            "add-payment", 
            Uri.GetLink<InvoicesController>(c => AddPayment(id, null)), 
            HttpMethods.Put
        );
    }

    if (userSecurityPolicy.IsSomeImportantUserRole) {
        representation = representation.LinksTo(
            "cancel", 
            Uri.GetLink<InvoicesController>(c => Cancel(id)), 
            HttpMethods.Delete
        );
    }

    return representation;
}
```

In this example I'm still exposing some business rules in controller which should be just application layer. In real life to make it clear and consistent between many layers of application I'm using some abstracted source of truth that could be used then to automagically create those links. This source is used to provide links (part of API layers) but decouples logic required to make a decision.

#### In many examples in internet links are added automatically in generic enrichers/middlewares separated from the endpoint. Is that OK?

I'd say that it is OK for simple implementations. In real projects those links are derived from the context of the resource, highly depends on the state of the resource or on rights that current user have to requested resource. That is why I'm seeing middlewares as very limiting in such case. Especially if those middlewares are generic for many resource it would be hard to capture the real complexity of the domain.

#### How to represent a collection of resources?

Actually, the collection is also a resource:

```csharp
[DataContract]
public class ResourceCollection<TResource> : Resource
    where TResource : Resource
{
    [DataMember(Name = "members")]
    public ICollection<TResource> Members { get; set; }
}
```
Collection can have their own links, like `create` or if this is just single page of results it might be a link to the next page.
Aaaand, yes... all members in collection are resources too, so all of them should have their own links that depends on their internal state ;). That's a lot of links and potentially a lot of ifs.

### Conclusion

That is all about this simple hypermedia implementation in WebAPI 2. As you could see the implementation is very simple and gives you very strong tool that pushes your API to next level of Richardson Maturity Model.
