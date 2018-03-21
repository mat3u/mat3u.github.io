---
title: "HATEOAS - Where my application actually is?"
categories: [HATEOAS, Architecture, REST]
date: 2018-03-21 08:49
---


Building software that is *HATEOAS* enabled is a challenging task. There is limited number of frameworks/libraries that supports the fight. Additionally,  good design of our domain should be even better - to build relevant link we need to introspect the state of the domain and context of request. And this is just the tip of an iceberg.

In this part of the series I’ll be talking about the links - how do we know how this link should actually look like? How do we even know how our application is visible to the world?

<!--more-->

## How to build link that actually points to our application ;) 
This problem may sound funny, but it is real! Let’s look at following example:

Standard case right now, backend application with *HATEOAS* and SPA client. From the backend we are naively returning relative (to our service) links to resources (I’ll skip versioning for simplicity):

```json
{
    "members": [...],
    "_links": [
        { "rel": "next", "href": "/books?afterId=6521", "method": "GET" },
        ...
    ]
}
```

Now, our application is visible under `http://testing.local` and everything is working fine. Unless it goes to production and is hosted under `https://company.com/product/`. Aaaaand… is broken! Why?

Well, developers has done a good job (sic!) and used `url.resolve(config.baseUrl, link[‘next’].href)` instead of nasty hack `config.baseUrl + link[‘next’].href`. In result resolve translates our `https://company.com/product and /books?after…` to `https://company.com/books?after…` . Wow, what? Why is that? Because this is how browsers are doing it to avoid ambiguity (you can find the algorithm [here](https://softwareengineering.stackexchange.com/a/324408)). 

It may seem like a bug not a feature to use resolve, but let’s look at it from the perspective of growing system: you can return in href anything that follows those well known rules and get predictable results according to well known algorithm. Alternatively, you can base on custom algorithm (concat in this case) that may vary between services/clients - I’m not arguing that it is not OK for small projects, but still can be source of security breach.

So, should I change my `href` to `/product/books?afterId=6521`? Well, if you want to stick with relative links: YES (or no)! In each case you have to know how your service is exposed to the world!

## How to determine where am I?

Like for all questions stated in this post for this one also is a couple of potential answers:

### Put PREFIX/BASE_PATH in the configuration
As simple as, add `config.uriPrefix` and use it to build the URIs. It is very simple and not bad for small systems. Has a couple of obvious cons: works only for single prefix, you need to prepare this parameter before deployment and redeploy if presented system structure was changed on LB level.

It is important that in case of REST, resources should have unique (and single) URI as resource ID - and aforementioned limitation may be useful to enforce this rule.

### Take it from the outside of the service (e.g. from the Load Balancer).

Unfortunately, I don’t know about any standardized way to do so. There is [`Forwarded`](https://tools.ietf.org/html/rfc7239#section-4) header which is designed to send to you information that may be lost due to proxy on pipe. But… it is not sending all data that was lost :). It can send the content of the `Host` header that was sent by client, it can send protocol, but if your service is not mounted to the root of the host you are doomed (or you have to mitigate this problem manually).

In one of my previous projects a custom header `X-Forwarded-BasePath` was used along with other `X-Forwarded-*` headers. Having such set of headers makes it pretty easy to determine how URI should look a like:

`<X-Forwarded-Proto>://<X-Forwarded-Host>:<X-Forwarded-Port or derive from X-Forwarded-Proto>`**`/<X-Forwarded-BasePath>/<relative in app path>`**

In case of relative link you can use just **emphasised parts** - resulting link will be relative to root of the external host - not relative to your application - it is very important to keep this in mind when using such links.

The configuration was as simple as adding this header on the external gateway of the system (while dropping any `X-Forwarded-*` header that some malicious client might send) and pass those headers on the way. Example for nginx:

```nginx
proxy_set_header  Host                  $http_host;
proxy_pass_header X-Forwarded-Proto;
proxy_set_header  X-Forwarded-Host      $http_host;
proxy_set_header  X-Forwarded-For       $proxy_add_x_forwarded_for;
Proxy_set_header  X-Forwarded-BasePath  "${http_x_forwarded_basepath}/api/mnt/point";
```

Funny is that Forwared header has worse support in tooling (i.e. [nginx](https://www.nginx.com/resources/wiki/start/topics/examples/forwarded/)) than its non-standardized predecessor: `X-Forwarded-*`.

## Should I use absolute or relative URI?

There is no obvious winner. Relative URIs are less agile than absolute ones. If you want to point to different service with completely different URI - it is straightforward with absolute link while complex with relative ones. But this possibility in case of full links also may be spoiled by creative developers/attackers.

If you are tight on bandwidth, full links adds a lot of repetitive data to the response, but if you are already doing *HATEOAS* it is not your case, right?

Right now, I’m using full links by default in my projects - no (known) issues.

## It is widely implemented in every web framework, right?

Well, there is no standard implementation for ASP.NET Core and for ASP.NET WebAPI 2 - maybe there are some libraries I don’t know. Django and couple of Node.js web frameworks supports those headers by libraries, Spring has support for the “standardier” headers (`X-Forwarded-*` except `BasePath`).

This is why I’ve written my own piece of code to do the job:

```csharp
public class ForwardedHandler : DelegatingHandler
{
    public const string ProtoHeader = "X-Forwarded-Proto";
    public const string HostHeader = "X-Forwarded-Host";
    public const string PortHeader = "X-Forwarded-Port";

    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var builder = new UriBuilder(request.RequestUri);

        if (request.Headers.Contains(ProtoHeader))
        {
            var proto = request.Headers.GetValues(ProtoHeader).First();
            builder.Scheme = proto;
            builder.Port = GetPort(proto);
        }

        int port;
        if (request.Headers.Contains(PortHeader) && int.TryParse(request.Headers.GetValues(PortHeader).First(), out port))
        {
            builder.Port = port;
        }

        if (request.Headers.Contains(HostHeader))
        {
            builder.Host = request.Headers.GetValues(HostHeader).First();
        }

        request.RequestUri = builder.Uri;

        return base.SendAsync(request, cancellationToken);
    }

    private int GetPort(string value)
    {
        switch (value)
        {
            case "https":
                return 443;
            default:
                return 80;
        }
    }
}
```

To register this handler just call following code during API configuration:

```csharp
config.MessageHandlers.Add(new ForwardedHandler());
```

Code should look very similar in case of .NET Core.

This code is fixing just part of the problem, it is not supporting X-Forwarded-BasePath, to do so I’ve written extension for [Hyprlinkr](https://github.com/ploeh/Hyprlinkr) library:

```csharp
public static class HyprlinkrExtensions
{
    public const string BasePathHeader = "X-Forwarded-BasePath";

    public static Uri GetFullUri<T>(this RouteLinker linker, Expression<Action<T>> method)
    {
        var uri = linker.GetUri<T>(method);

        return ExtendWithBasePath(linker, uri);
    }

    public static async Task<Uri> GetFullUriAsync<T, TResult>(this RouteLinker linker, Expression<Func<T, Task<TResult>>> method)
    {
        var uri = await linker.GetUriAsync(method);

        return ExtendWithBasePath(linker, uri);
    }

    private static Uri ExtendWithBasePath(RouteLinker linker, Uri uri)
    {
        if (!linker.Request.Headers.Contains(BasePathHeader))
        {
            return uri;
        }

        var basePath = linker.Request.Headers.GetValues(BasePathHeader).First();
        var builder = new UriBuilder(uri);

        builder.Path = Path.Combine(basePath, builder.Path.TrimStart('/'));

        return builder.Uri;
    }
}
```

I’m not very happy with names of methods, but the code does what it should.

That’s all for this post, in next posts I’ll write more about challenges with *HATEOAS* implementation, and there is a lot of interesting problems.
