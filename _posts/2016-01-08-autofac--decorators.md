---
title: "Autofac & Decorators"
categories: [DI,C#,Programming]
date: 2016-01-08 20:33
---

Today I was setting up an infrastructure for a new project and I met the same problem I used to met couple times before - configuring injection of `CommandDispatcher` with decorators in Autofac don't look well nor it's easy to read. So I wrote extension methods to simplify future usage of decorators in Autofac. 

<!--more-->

## The Autofac way!

According to Autofac's [documentation](http://docs.autofac.org/en/latest/advanced/adapters-decorators.html#decorators) the official way to register decorators looks like this:

{% highlight csharp linenos %}
builder.RegisterType<CommandDispatcher>()
       .Named<ICommandDispatcher>("baseCommandDispatcher");

builder.RegisterDecorator<ICommandDispatcher>(
	(c, inner) => new TransactionalCommandDispatcher(inner),
	fromKey: "baseCommandDispatcher"
);

var container = builder.Build();

var dispatcher = container.Resolve<ICommandDispatcher>();
{% endhighlight %}

It looks very messy and complicates registration of more sophisticated structures. What I especially don't like is this line:

> `	(c, inner) => new TransactionalCommandDispatcher(inner),`

If decorator has more dependencies than only decorated type this part of code will look terrible.

## How I want to do that?

I wanted to make the registration of many levels of decorators as simple as possible:

{% highlight csharp linenos %}
builder.RegisterDecorated<CommandDispatcher, ICommandDispatcher>(
           typeof(TransactionalCommandDispatcherDecorator),
           typeof(LoggingCommandDispatcherDecorator)
       .As<ICommandDispatcher>();

var container = builder.Build();

var dispatcher = container.Resolve<ICommandDispatcher>();
{% endhighlight %}

The only thing I need to do is to call method `RegisterDecorated<TBase, TInterface>` on builder, specify base type that will be decorated and interface of the type (and decorators). As parameters I can put any number of decorators. Decorators will be registered in the order specified in parameters.

And at the end when I'll call `dispatcher.Execute(cmd);` I expect this call-stack:

{% highlight csharp %}
LoggingCommandDispatcherDecorator.Execute
    -> TransactionalCommandDispatcherDecorator.Execute
        -> CommandDispatcher.Execute
{% endhighlight %}

## How to do that?

Simply, using similar approach that is suggested by Autofac documentation - registration of named types:

{% highlight csharp linenos %}
public static class BuilderExtensions
{
    public static void RegisterDecorated<TBase, TInterface>(this ContainerBuilder builder, params Type[] decorators)
        where TBase : TInterface
    {
        builder.RegisterDecorated<TBase, TInterface>(typeof(TInterface).Name, decorators);
    }

    public static void RegisterDecorated<TBase, TInterface>(this ContainerBuilder builder, string keyBase, params Type[] decorators)
        where TBase : TInterface
    {
        // ... - argument checking

        var numOfDecorators = decorators.Length;

        builder.RegisterType<TBase>().Named<TInterface>($"{keyBase}-0");

        for (int i = 1; i < numOfDecorators; i++)
        {
            var decorator = decorators[i - 1];

            var currentKey = $"{keyBase}-{i}";
            var previousKey = $"{keyBase}-{i - 1}";

            builder.RegisterType(decorator)
                .WithParameter(
                    (parameterInfo, _) => parameterInfo.ParameterType == typeof(TInterface),
                    (_, context) => context.ResolveNamed<TInterface>(previousKey)
                ).Named<TInterface>(currentKey);
        }

        builder.RegisterType(decorators.Last())
            .WithParameter(
                (parameterInfo, _) => parameterInfo.ParameterType == typeof(TInterface),
                (_, context) => context.ResolveNamed<TInterface>($"{keyBase}-{numOfDecorators - 1}")
            ).As<TInterface>();
    }
}
{% endhighlight %}

What is happening? I'm simply registering base type with name: `{InterfaceTypeName}-0` and following decorators as `{InterfaceTypeName-i}`. Last decorator is registered as interface that will requested to be injected. In this particular case it looks as follows:

| Type | | Name |
|------|-|------|
| `CommandDispatcher` |  -> |`ICommandDispatcher-0` |
| `TransactionalCommandDispatcherDecorator` | -> | `ICommandDispatcher-1` |
| `LoggingCommandDispatcherDecorator` | |  |

If for some reason default value of `keyBase` (name of `TInterace`) don't work in your case, you can easily specify other value during registration.
In this approach all external dependencies will be resolved as usually at every level of this decorator chain.

The full code is available [HERE](https://github.com/mat3u/AutofacDecorators/blob/master/Program.cs).