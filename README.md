PGDelegationProxy
=================

## Motivation (a bit long, sorry)

What is it?

Are you familiar with the delegation pattern? How about notification center? Yes? Then you already need everything you need to know about this.
As much as I love the flexibility and ease of use of NSNotificationCenter it can, and more often than not, will promote sloppy design and 
hard to debug code. It's ease of use can also be its achilles heel as it can be just to tempting to patch a seemingly impossible design problem
by issuing a notification here, another one and assume someone, somewhere will pick them up and do the right thing. I mean, why wouldn't you do it? That's why the api is there in the first place, right? Right? It's perfectly possible to have properly designed interfaces and have clearly defined data flows using NSNotificationCenter, but the lack of contract always annoyed me.

Over the years I've found that even though some of these concepts are decades old and actually fairly common in other worlds (Java, .NET), people
still make the same mistakes over and over again.
There's more to software design than just writing code. Desigining an elegant system, comprised of various individual components that work together
through clearly defined interfaces is fundamental. You need to have a full understanding of your systems at all times, things can't just sort of happen by accident. I see a lot of projects there are basically just a bunch of hacks where things work mostly by coincidence and afterthought, not by design. Inconsistent interfaces and paradigms, random usage of state variables, inconsistent naming conventions, inconsistent style, they all hint out that there might be fundamental problems lurking.

Most people deal with many of the systems' provided frameworks daily, but don't really approach the design of their application in the same way.
I never understood why that happens. I've seen many many projects (hopefully with some exceptions) where things do work, sort of, by accident or coincidence.
They are more or less hacked. There's no consistent design. Consistency is key. It's important in your coding style, it's important in your APIs, it's important in how you design your systems and components.

Apple tends to be very good at this. A lot of people how write third party libraries that you and me use daily understand that too.
Why don't you approach the design of your next project as a set of many different components where each one communicates with the outside world through
a set of clearly defined interfaces and nothing else?

But I digress.
The reality is that delegation, although not the only option, is a very good pattern that promotes decoupling and gives us precisely the means of communicating that I just talked about.
The problem is that, as you start moving away from the typical model where view controllers encapsulate most of the business logic, and start creating
services and other pieces that do deferred processing and work mostly in an asynchronous fashion, and futhermore, you understand that singletons (no, I don't think they're always evil) aren't the only solution to solve what's fundamentally a problem with managing and identifying dependencies, then you also need to start thinking about how you can notify multiple parties of interesting events.
People traditionally solve this problem using NSNotificationCenter, but I've always disliked that approach. Notifications fly all over the place, anyone can intercept them and do whatever with them (see comments above). There's no contract. There's a name and there's an optional userInfo dictionary. What's the payload? What if it changes over time? How do I know what notifications to subscribe to? Well, you either have a very clear and well maintained place where people clearly define the notification names and the keys that you should inspect, and that makes it less awful, or you just suck it up and hack away.
What about having header files defining an API where you declare the available callbacks?

Well, that's precisely what this does. You can register multiple delegates (think of them as observers for now). All they have to do is to conform to the protocol.
If you do understand the delegate pattern (and frankly, if you've done even the most basic UITableView based application, you already sort of understand it), then you already know how to use this.
Of course there's more to it. Understanding the value of multiple delegation and when to use it may only become apparent further down the line, maybe you need to make a few mistakes and have them bite in the butt to start appreciating different solutions (I certainly did).
There's a bit more to it. Some methods may have non-void return type. This is supported, but for the lack of a real-world use case, for the time being 
we only take the return value of the first delegate. In the future we might support aggregation of different results. More on that later.

## Requirements

Requires ARC. Nothing else.

## Usage

### NSObject Category 

For convenience, there's an informal protocol that exposes a ```delegationProxy``` property. When accessed, it will lazily initialize and associate the delegation proxy with the receiver.
If you do this, you *must* manually invoke ```- (void)configureWithProtocol:(Protocol *)protocol```.
When that's done, you are free to invoke whatever method you declared in your custom protocol.
A caveat though, simply calling ```[self.delegationProxy customService:self didReportSomethingInteresting:info]``` will generally have the compiler emit warnings.
I currently provide a workaround for this. You can simply add the following macro ```PGDelegateProxyConformToProtocol(__protocol_name__)``` before your classe's implementation (ideally in your implementation file). This will make the DelegationProxy class conform to your custom protocol and make the compiler happy.

### Manual lifecycle

Alternatively you can simply create and instance of PGDelegateProxy as you normally would. You should use the designated initialiser ```- (instancetype)initWithProtocol:(Protocol *)protocol```

### Delegate registration/deregistration

To register a delegate you can simply call ```- (void)registerDelegate:(id)delegate``` on the DelegationProxy. Conversely, you should call ```- (void)deregisterDelegate:(id)delegate``` to deregister a previously registered delegate.
The deregistration step is **recommended** but **optional**. The DelegationProxy is smart enough to perform some simple internal cleanup and will eventually get rid of deallocated registered delegate objects.

As a convenience, the aforementioned informal protocol also exposes a few other convenience methods: 

```- (void)pg_registerDelegate:(id)delegate``` 

```- (void)pg_deregisterDelegate:(id)delegate```

These simply invoke ```- (void)registerDelegate:(id)delegate``` on the default ```delegateProxy``` instance. They also promote consistency throughout your code.
You are, however, completely free to specify whatever interface you'de like, as long as ultimately you call the registration/deregistration methods somewhere.


## Notes

This is not a new project, it has been around for a couple of years and has been designed and improved based on real world needs. The code hasn't been entirely modernised, which would explain a few inconsistencies here and there, but nothing major.

Coupled with ideas such as Dependency Injection, Single Principle Responsibility among others, this simple but powerful concept serves as the basis for remarkably powerful and flexible architectures.


