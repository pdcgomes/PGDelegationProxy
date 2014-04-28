//
//  TRDelegateContainer.m
//  TRXFramework
//
//  Created by Pedro Gomes on 07/11/2013.
//  Copyright (c) 2013 Phluid Labs Global Resources.  All Rights Reserved.  Proprietary and confidential information of TRGR.  Disclosure, use, or reproduction without written authorization of TRGR is prohibited. All rights reserved.
//

#import <objc/runtime.h>
#import "PGDelegateProxy.h"

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
const void *kPGDelegateProxyKey = "com.tr.framework.delegate-container";
static NSString *const kTRDelegateProxyToken = @"com.tr.framework.delegate-container.token";

NSString *const kPGDelegateContainerNonConformantObjectException                    = @"PGDelegateContainerNonConformantObjectException";
NSString *const kPGDelegateContainerObjectDoesNotImplementRequiredSelectorException = @"PGDelegateContainerObjectDoesNotImplementRequiredSelectorException";
NSString *const kPGDelegateContainerConfigurationException                          = @"PGDelegateContainerConfigurationException";

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
void dispatch_main_sync_reentrant(dispatch_block_t block)
{
    [NSThread isMainThread] == YES ? block() : dispatch_sync(dispatch_get_main_queue(), block);
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
@interface PGDelegateProxy ()

@property (nonatomic, retain) Protocol *protocol;
@property (nonatomic, strong) NSMutableDictionary *methodSignatures;
@property (nonatomic, strong) NSMutableDictionary *methodResponderCache;
@property (nonatomic, strong) NSMutableSet *requiredMethods;

- (void)_performCleanup;

@end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
@interface TRWeakObjectWrapper : NSObject

@property (nonatomic, weak) id object;

- (id)initWithObject:(id)object;
- (id)initWithClass:(Class)class hash:(NSUInteger)hash;

@end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
@implementation TRWeakObjectWrapper
{
@public
    Class       _wrappedObjectClass;
    NSUInteger  _wrappedObjectHash;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (id)initWithObject:(id)object
{
    if((self = [super init])) {
        _object              = object;
        _wrappedObjectClass  = [object class];
        _wrappedObjectHash   = [object hash];
        
        //        PGLogTrace(PGLogContextDefault, @"<wrapper: object(%p) class = %@, hash = %ld>", object, NSStringFromClass(_wrappedObjectClass), _wrappedObjectHash);
    }
    return self;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (id)initWithClass:(Class)aClass hash:(NSUInteger)hash
{
    if((self = [super init])) {
        _wrappedObjectClass  = aClass;
        _wrappedObjectHash   = hash;
    }
    return self;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (NSUInteger)hash
{
    return _wrappedObjectHash;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (BOOL)isEqual:(id)object
{
    if(!object) {
        return NO;
    }
    
    if(!self.object) {
        return ([object isKindOfClass:_wrappedObjectClass] &&
                [object hash] == _wrappedObjectHash);
    }
    return [object isEqual:self.object];
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (BOOL)isKindOfClass:(Class)aClass
{
    return aClass == _wrappedObjectClass;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (NSString *)description
{
    if(_object) {
        return [_object description];
    }
    return [NSString stringWithFormat:@"<%@: %p, nil wrapped object, class (%@), hash (%lu)>",
            NSStringFromClass([self class]),
            self,
            NSStringFromClass(self->_wrappedObjectClass),
            (unsigned long)self->_wrappedObjectHash];
}

@end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//@interface NSObject (TRDelegateContainerInternal)
//
//@property (nonatomic, readonly) TRDelegateContainer *delegateContainer;
//
//@end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
@implementation NSObject (TRDelegateProxy)

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (NSUInteger)delegatesCount
{
    return [self.delegateProxy delegatesCount];
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (PGDelegateProxy *)delegateProxy
{
    PGDelegateProxy *proxy = nil;
    @synchronized(kTRDelegateProxyToken) {
        proxy = objc_getAssociatedObject(self, kPGDelegateProxyKey);
        if(!proxy) {
            proxy = [[PGDelegateProxy alloc] init];
            objc_setAssociatedObject(self, kPGDelegateProxyKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    return proxy;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)pg_registerDelegate:(id)delegate
{
    [self.delegateProxy registerDelegate:delegate];
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)pg_deregisterDelegate:(id)delegate
{
    [self.delegateProxy deregisterDelegate:delegate];
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)pg_notifyDelegatesWithBlock:(void (^)(id delegate))block
{
    [self.delegateProxy notifyDelegatesWithBlock:block];
}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)pg_notifyDelegatesWithBlock:(void (^)(id delegate))block callbackQueue:(dispatch_queue_t)callbackQueue
{
    [self.delegateProxy notifyDelegatesWithBlock:block callbackQueue:callbackQueue];
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)pg_notifyDelegatesWithBlockAndWait:(void (^)(id delegate))block
{
    [self.delegateProxy notifyDelegatesWithBlockAndWait:block];
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (id)pg_firstDelegateRespondingToSelector:(SEL)selector
{
    return [self.delegateProxy firstDelegateRespondingToSelector:selector];
}

@end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
@implementation PGDelegateProxy
{
    NSMutableSet        *_delegates;
    dispatch_queue_t    _lockQueue;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (instancetype)init
{
    if((self = [super init])) {
        _delegates = [NSMutableSet set];
        _lockQueue = dispatch_queue_create("com.tr.framework.delegate-container.lock", NULL);
        _methodSignatures = [NSMutableDictionary dictionary];
        _methodResponderCache = [NSMutableDictionary dictionary];
        _requiredMethods = [NSMutableSet set];
    }
    return self;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (instancetype)initWithProtocol:(Protocol *)protocol
{
    if((self = [self init])) {
        _protocol = protocol;
        [self _createMethodLookupTableForProtocol:protocol];
    }
    return self;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)configureWithProtocol:(Protocol *)protocol
{
    if(self.delegatesCount > 0) {
        [[NSException exceptionWithName:kPGDelegateContainerConfigurationException
                                reason:@"Protocol configuration when delegates are already registered isn't currently supported."
                                       @"Please ensure you perform all necessary configuration steps prior to registering any delegates."
                              userInfo:nil] raise];
        return;
    }

    self.protocol = protocol;

    [self.methodSignatures removeAllObjects];
    [self.methodResponderCache removeAllObjects];
    [self.requiredMethods removeAllObjects];
    [self _createMethodLookupTableForProtocol:protocol];
}

#pragma mark - NSObject

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (BOOL)conformsToProtocol:(Protocol *)protocol
{
    return protocol_isEqual(protocol, self.protocol);
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (BOOL)respondsToSelector:(SEL)aSelector
{
    NSString *selectorName = NSStringFromSelector(aSelector);
    if(self.methodSignatures[selectorName] != nil) {
        return YES;
    }
    
    // You cannot test whether an object inherits a method from its superclass by sending respondsToSelector: to the object using the super keyword.
    // This method will still be testing the object as a whole, not just the superclass’s implementation.
    // Therefore, sending respondsToSelector: to super is equivalent to sending it to self.
    // Instead, you must invoke the NSObject class method instancesRespondToSelector: directly on the object’s superclass,
    // as illustrated in the following code fragment.
    // Taken from Apple's NSObject: - respondsToSelector: documentation (pdcgomes 05.12.2013)
    return [NSObject instancesRespondToSelector:aSelector];
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    NSString *selectorName = NSStringFromSelector(aSelector);
    NSMethodSignature *methodSignature = self.methodSignatures[selectorName];
    if(methodSignature != nil) {
        return methodSignature;
    }
    
//    PGLogTrace(PGLogContextDefault, @"<[delegate_container (%p)]: unrecognized selector (%@). Did you forget to configure the delegation protocol ?>",
//               self,
//               NSStringFromSelector(aSelector));
    return [super methodSignatureForSelector:aSelector]; // default NSObject implementation should raise NSInvalidArgumentException (pdcgomes 04.12.2013)
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    // TODO: implement variant where the method has a return type != void
    // we have a few approaches we can use:
    // a) pick the first selector that implements the method and fetch the result from it           *** this is what's currently implemented
    // b) query all responders, if they provide different results, aggregate them and deliver them
    //    quite an interesting idea, but I don't really see a reason to do it (pdcgomes 05.12.2013)
    __unused NSString *selectorName = NSStringFromSelector(anInvocation.selector);
    NSAssert(self.methodSignatures[selectorName] != nil && self.methodResponderCache[selectorName] != nil,
             @"<[TRDelegateProxy (%p)]: forwardInvocation: proxy doesn't implement selector (%@)>", self, selectorName);

    [anInvocation retainArguments]; // This is important! (pdcgomes 05.12.2013)

    BOOL methodHasVoidReturnType = (strcmp([anInvocation.methodSignature methodReturnType], @encode(void)) == 0);
    if(methodHasVoidReturnType == NO) {
        id firstResponder = [self firstDelegateRespondingToSelector:anInvocation.selector];
        if(firstResponder == nil) {
            return;
        }
        dispatch_main_sync_reentrant(^{
            [anInvocation invokeWithTarget:firstResponder];
        });
        return;
    }

#ifdef TR_DELEGATE_CONTAINER_DEBUG
    [self notifyDelegatesWithInvocationDebug:anInvocation
                               callbackQueue:dispatch_get_main_queue()
                           completionHandler:^{
                           }];
#else
    [self notifyDelegatesWithInvocation:anInvocation
                          callbackQueue:dispatch_get_main_queue()
                      completionHandler:^{
                      }];
#endif

//    __weak typeof(self) weakSelf = self;
//    dispatch_async(_lockQueue, ^{
//        [weakSelf notifyDelegatesWithInvocation:anInvocation
//                                  callbackQueue:dispatch_get_main_queue()
//                              completionHandler:^{
//                }];
//    });
}

#pragma mark - Public Methods

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (NSUInteger)delegatesCount
{
    __block NSUInteger count = 0;
    dispatch_sync(_lockQueue, ^{
        count = [_delegates count];
    });
    return count;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)registerDelegate:(id)delegate
{
    if(!delegate) {
        return;
    }

    // TODO: assert if the object doesn't conform to the registered protocol (pdcgomes 04.12.2013)
//    NSAssert(self.protocol == nil || [delegate conformsToProtocol:self.protocol] == YES,
//             @"<[delegate_container (%@): attempted to register a delegate (%@) that is not conformant to the declared protocol (%@)]>",
//             self, delegate, NSStringFromProtocol(self.protocol));
    
    BOOL canRegisterDelegate = (self.protocol == nil || [delegate conformsToProtocol:self.protocol] == YES);
    if(canRegisterDelegate == NO) {
        NSString *reason = [NSString stringWithFormat:@"Attempted to register a delegate (%@) that is not conformant to the declared protocol (%@)",
                            delegate,
                            NSStringFromProtocol(self.protocol)];
        NSException *exception = [NSException exceptionWithName:kPGDelegateContainerNonConformantObjectException
                                                         reason:reason
                                                       userInfo:nil];
        [exception raise];
    }
    
    __block NSException *outException = nil;
    dispatch_sync(_lockQueue, ^{
        TRWeakObjectWrapper *wrapper = [[TRWeakObjectWrapper alloc] initWithObject:delegate];
        [_delegates addObject:wrapper];
        
        @try {
            [self _createMethodResponderCacheForDelegate:delegate];
//            [self _performCleanup];
        }
        @catch(NSException *exception) {
            outException = exception;
        }
    });
    
    // Important: GCD is a C level API; it does not catch exceptions generated by higher level languages.
    // Your application must catch all exceptions before returning from a block submitted to a dispatch queue.
    // from Apple's documentation (pdcgomes 04.12.2013)
    if(outException) {
        [outException raise];
    }
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)deregisterDelegate:(id)delegate
{
    if(!delegate) {
        return;
    }

    TRWeakObjectWrapper *wrapper = [[TRWeakObjectWrapper alloc] initWithClass:[delegate class] hash:[delegate hash]];

    __weak typeof(self) weakSelf = self;
    dispatch_sync(_lockQueue, ^{
        [_delegates removeObject:wrapper];
        [weakSelf _removeDelegateFromMethodResponderCache:delegate];
    });
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)notifyDelegatesWithBlock:(void (^)(id delegate))block
{
    [self notifyDelegatesWithBlock:block callbackQueue:dispatch_get_main_queue() completionHandler:nil];
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)notifyDelegatesWithBlock:(void (^)(id))block completionHandler:(dispatch_block_t)completionHandler
{
    [self notifyDelegatesWithBlock:block callbackQueue:dispatch_get_main_queue() completionHandler:completionHandler];
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)notifyDelegatesWithBlock:(void (^)(id delegate))block callbackQueue:(dispatch_queue_t)callbackQueue
{
    [self notifyDelegatesWithBlock:block callbackQueue:callbackQueue completionHandler:nil];
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)notifyDelegatesWithBlock:(void (^)(id delegate))block callbackQueue:(dispatch_queue_t)callbackQueue completionHandler:(dispatch_block_t)completionHandler;
{
    __weak typeof(self) weakSelf = self;
    dispatch_async(_lockQueue, ^{
        
        __block BOOL requiresCleanup = NO;
        dispatch_group_t group = dispatch_group_create();
        
        NSSet *delegates = [_delegates copy];
        [delegates enumerateObjectsUsingBlock:^(TRWeakObjectWrapper *wrapper, BOOL *stop) {
            if(wrapper.object) {
                
                dispatch_group_enter(group);
                dispatch_group_async(group, callbackQueue, ^{
                    block(wrapper.object);
                    dispatch_group_leave(group);
                });
            }
            else {
                requiresCleanup = YES;
            }
        }];
        
        dispatch_group_notify(group, callbackQueue, ^{
            if(completionHandler != nil) {
                completionHandler();
            }
            if(requiresCleanup == YES) {
                [weakSelf _performCleanup];
            }
        });
    });
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)notifyDelegatesWithBlockAndWait:(void (^)(id delegate))block
{
    __block NSSet *safeDelegates = nil;
    NSSet *delegates = _delegates;
    dispatch_sync(_lockQueue, ^{
        safeDelegates = [delegates copy];
    });
    
    __block BOOL requiresCleanup = NO;
    [delegates enumerateObjectsUsingBlock:^(TRWeakObjectWrapper *wrapper, BOOL *stop) {
        if(wrapper.object) {
            block(wrapper.object);
        }
        else {
            requiresCleanup = YES;
        }
    }];
    
    if(requiresCleanup) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(_lockQueue, ^{
            [weakSelf _performCleanup];
        });
    }
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)notifyDelegatesWithInvocation:(NSInvocation *)invocation callbackQueue:(dispatch_queue_t)callbackQueue completionHandler:(dispatch_block_t)completionHandler
{
    __weak typeof(self) weakSelf = self;
    dispatch_async(_lockQueue, ^{
        __block BOOL requiresCleanup = NO;
        dispatch_group_t group = dispatch_group_create();
        
        NSString *selectorName = NSStringFromSelector(invocation.selector);
        NSSet *responders = weakSelf.methodResponderCache[selectorName];
        [responders enumerateObjectsUsingBlock:^(TRWeakObjectWrapper *wrapper, BOOL *stop) {
            if(wrapper.object) {
                dispatch_group_enter(group);
                dispatch_group_async(group, callbackQueue, ^{
                    [invocation invokeWithTarget:wrapper.object];
                    dispatch_group_leave(group);
                });
            }
            else {
                requiresCleanup = YES;
            }
        }];
        
        dispatch_group_notify(group, callbackQueue, ^{
            if(completionHandler != nil) {
                completionHandler();
            }
            if(requiresCleanup == YES) {
                [weakSelf _performCleanup];
            }
        });
    });
}

////////////////////////////////////////////////////////////////////////////////
// Used when TR_DELEGATE_CONTAINER_DEBUG is defined, this runs everything synchronously
// which should help with debugging (pdcgomes 19.12.2013)
////////////////////////////////////////////////////////////////////////////////
- (void)notifyDelegatesWithInvocationDebug:(NSInvocation *)invocation callbackQueue:(dispatch_queue_t)callbackQueue completionHandler:(dispatch_block_t)completionHandler
{
    NSString *selectorName = NSStringFromSelector(invocation.selector);
    
    __block BOOL requiresCleanup = NO;
    __block NSSet *responders = nil;
    dispatch_sync(_lockQueue, ^{
        responders = [self.methodResponderCache[selectorName] copy];
    });
    
    [responders enumerateObjectsUsingBlock:^(TRWeakObjectWrapper *wrapper, BOOL *stop) {
        if(wrapper.object) {
            [invocation invokeWithTarget:wrapper.object];
        }
        else {
            requiresCleanup = YES;
        }
    }];
    
    if(completionHandler != nil) {
        completionHandler();
    }
    if(requiresCleanup == YES) {
        [self _performCleanup];
    }
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (id)firstDelegateRespondingToSelector:(SEL)selector
{
    __block id firstResponder = nil;
    dispatch_sync(_lockQueue, ^{
        [self _performCleanup];
        
        NSSet *delegates = [_delegates copy];
        [delegates enumerateObjectsUsingBlock:^(TRWeakObjectWrapper *wrapper, BOOL *stop) {
            if(wrapper.object) {
                if([wrapper.object respondsToSelector:selector]) {
                    firstResponder = wrapper.object;
                    *stop = YES;
                }
            }
        }];
    });
    return firstResponder;
}

#pragma mark - Private Methods

////////////////////////////////////////////////////////////////////////////////
// TODO: we need a better way to determine when to call performCleanup
////////////////////////////////////////////////////////////////////////////////
- (void)_performCleanup
{
    NSSet *delegates = [_delegates copy];
    [delegates enumerateObjectsUsingBlock:^(TRWeakObjectWrapper *wrapper, BOOL *stop) {
        if(!wrapper.object) {
//            PGLogTrace(PGLogContextDefault, @"<delegate_container: object of class %@ (hash:%lu) has been deallocated>",
//                  NSStringFromClass(wrapper->_wrappedObjectClass),
//                  (unsigned long)wrapper->_wrappedObjectHash);
            [_delegates removeObject:wrapper];
            
            [self.methodResponderCache enumerateKeysAndObjectsUsingBlock:^(NSString *selectorName, NSMutableSet *responders, BOOL *stop) {
                [responders removeObject:wrapper];
            }];
        }
    }];
}

#pragma mark - Helper Methods

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
#define kIsRequiredMethodIndex (0)
#define kIsInstanceMethodIndex (1)
- (void)_createMethodLookupTableForProtocol:(Protocol *)protocol
{
    // We want to extract all the methods from the protocol declaration
    // There's no api call to list them all, we always need to provide some optional arguments such as:
    // isRequired:
    // isInstanceMethod
    // We don't currently support protocol class methods as we (as far as I know) have no
    // way of determining if a particular NSInvocation/SELECTOR refers to a class method or not
    // this would be a problem if a protocol specifies two methods (instance and class) with the same signature
    // (pdcgomes 04.12.2013)
    NSMutableArray *options = [NSMutableArray arrayWithArray:
                               @[@(YES), @(YES),
                                 @(NO),  @(YES)]];
    while(options.count > 0) {
        @autoreleasepool {
            BOOL isRequired       = [options[kIsRequiredMethodIndex] boolValue];
            BOOL isInstanceMethod = [options[kIsInstanceMethodIndex] boolValue];
            [options removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)]];
            
            unsigned int count = 0;
            struct objc_method_description *methods = protocol_copyMethodDescriptionList(protocol, isRequired, isInstanceMethod, &count);
            for(int i = 0; i < count; i++) {
                struct objc_method_description methodDescription = methods[i];
                SEL selector = methodDescription.name;
                NSString *selectorName = NSStringFromSelector(selector);
                NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:methodDescription.types];
                self.methodSignatures[selectorName] = signature;
                self.methodResponderCache[selectorName] = [NSMutableSet setWithCapacity:2];
                
                if(isRequired == YES) {
                    [self.requiredMethods addObject:selectorName];
                }
            }
            free(methods);
        }
    }
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)_createMethodResponderCacheForDelegate:(id)delegate
{
    [self.methodSignatures enumerateKeysAndObjectsUsingBlock:^(NSString *selectorName, NSMethodSignature *signature, BOOL *stop) {
        if([delegate respondsToSelector:NSSelectorFromString(selectorName)] == YES) {
            TRWeakObjectWrapper *wrapper = [[TRWeakObjectWrapper alloc] initWithObject:delegate];
            [self.methodResponderCache[selectorName] addObject:wrapper];
        }
        else {
            if(self.protocol != nil &&
               [self.requiredMethods containsObject:selectorName]) {
                NSString *reason = [NSString stringWithFormat:@"Attempted to register a delegate (%@) that does not implement a required selector (%@) from the declared protocol (%@)",
                                    delegate,
                                    selectorName,
                                    NSStringFromProtocol(self.protocol)];
                NSException *exception = [NSException exceptionWithName:kPGDelegateContainerObjectDoesNotImplementRequiredSelectorException
                                                                 reason:reason
                                                               userInfo:nil];
                [exception raise];
            }
        }
    }];
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)_removeDelegateFromMethodResponderCache:(id)delegate
{
    TRWeakObjectWrapper *wrapper = [[TRWeakObjectWrapper alloc] initWithClass:[delegate class] hash:[delegate hash]];

    [self.methodResponderCache enumerateKeysAndObjectsUsingBlock:^(NSString *selectorName, NSMutableSet *responders, BOOL *stop) {
        [responders removeObject:wrapper];
    }];
}

@end
