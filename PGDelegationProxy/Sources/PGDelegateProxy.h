//
//  TRDelegateContainer.h
//  TRFramework
//
//  Created by Pedro Gomes on 07/11/2013.
//  Copyright (c) 2013 Phluid Labs Global Resources.  All Rights Reserved.  Proprietary and confidential information of TRGR.  Disclosure, use, or reproduction without written authorization of TRGR is prohibited. All rights reserved.
//

#import <Foundation/Foundation.h>

// Notes: You can define TR_DELEGATE_CONTAINER_DEBUG somewhere in your application if you need to disable async invocation
// the upside of this is that it will make debugging easier, as it'll preserve the stack trace for each call
// (pdcgomes 03.01.2014)

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
extern NSString *const kPGDelegateContainerNonConformantObjectException;
extern NSString *const kPGDelegateContainerObjectDoesNotImplementRequiredSelectorException;
extern NSString *const kPGDelegateContainerConfigurationException;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
@class PGDelegateProxy;
@interface NSObject (PGDelegateProxy)

@property (nonatomic, readonly) PGDelegateProxy *delegateProxy;

- (NSUInteger)delegatesCount;

- (void)pg_registerDelegate:(id)delegate;
- (void)pg_deregisterDelegate:(id)delegate;

- (void)pg_notifyDelegatesWithBlock:(void (^)(id delegate))block;
- (void)pg_notifyDelegatesWithBlock:(void (^)(id delegate))block callbackQueue:(dispatch_queue_t)callbackQueue;

- (void)pg_notifyDelegatesWithBlockAndWait:(void (^)(id delegate))block;

- (id)pg_firstDelegateRespondingToSelector:(SEL)selector;

@end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
@interface PGDelegateProxy : NSObject

- (instancetype)initWithProtocol:(Protocol *)protocol;

- (void)configureWithProtocol:(Protocol *)protocol;

- (NSUInteger)delegatesCount;

- (void)registerDelegate:(id)delegate;
- (void)deregisterDelegate:(id)delegate;

- (void)notifyDelegatesWithBlock:(void (^)(id delegate))block;
- (void)notifyDelegatesWithBlock:(void (^)(id))block completionHandler:(dispatch_block_t)completionHandler;

- (void)notifyDelegatesWithBlock:(void (^)(id delegate))block callbackQueue:(dispatch_queue_t)callbackQueue;
- (void)notifyDelegatesWithBlock:(void (^)(id delegate))block callbackQueue:(dispatch_queue_t)callbackQueue completionHandler:(dispatch_block_t)completionHandler;

- (void)notifyDelegatesWithBlockAndWait:(void (^)(id delegate))block;

- (id)firstDelegateRespondingToSelector:(SEL)selector;

@end

////////////////////////////////////////////////////////////////////////////////
// Helper Macros
////////////////////////////////////////////////////////////////////////////////

/**
 * To suppress compiler warnings, we can use this macro to declare protocol conformance for a specific protocol
 * To prevent naming clashes, the category name is prefixed with a uuid
 * This macro should normally only be used in private contexts (either implementation files or internal/private headers)
 */
#define PGDelegateProxyConformToProtocol(_protocolName_) \
@interface PGDelegateProxy(EB40AEB26C6B48349E84BB5AEEC722DA##_protocolName_) <_protocolName_> \
@end

