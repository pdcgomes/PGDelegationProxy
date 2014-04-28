//
//  TRDelegatesContainerTests.m
//  Chowderios
//
//  Created by Pedro Gomes on 04/12/2013.
//  Copyright (c) 2013 Phluid Labs Global Resources.  All Rights Reserved.  Proprietary and confidential information of TRGR.  Disclosure, use, or reproduction without written authorization of TRGR is prohibited. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "PGDelegateProxy.h"
#import "PGMockProtocol.h"
#import "PGMockProtocolConformingObject.h"
#import "PGMockProtocolConformantInvalidObject.h"
#import "PGMockProtocolNonConformingObject.h"
#import "PGMockProtocolPartiallyConformingObject.h"
#import "PGUnitTestingMacros.h"

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
PGDelegateProxyConformToProtocol(PGMockProtocol);

@interface NSObject (TRInvalidMethods)

- (void)mockInvalidMethod;

@end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
@interface PGDelegatesContainerTests : XCTestCase

@property (nonatomic, strong) PGDelegateProxy *delegateProxy;

@end

@implementation PGDelegatesContainerTests

- (void)setUp
{
    [super setUp];
    self.delegateProxy = [[PGDelegateProxy alloc] initWithProtocol:@protocol(PGMockProtocol)];
}

- (void)tearDown
{
    [super tearDown];
    self.delegateProxy = nil;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)DECLARE_TEST_METHOD(validConformantObject)
{
    NSUInteger expectedCallbackCounter = 6;
    __block NSUInteger callbackCounter = 0;
    
    __strong PGMockProtocolConformingObject *conformantObject = [[PGMockProtocolConformingObject alloc] init];
    conformantObject.onInvocationBlock = ^{
        callbackCounter++;
    };

    @try {
        [self.delegateProxy registerDelegate:conformantObject];
        
        [self.delegateProxy mockRequiredMethod];
        [self.delegateProxy mockRequiredMethodWithObject:@""];
        [self.delegateProxy mockRequiredMethodWithObject:@"" andObject:@""];
        
        [self.delegateProxy mockOptionalInstanceMethod];
        [self.delegateProxy mockOptionalInstanceMethodWithObject:@""];
        [self.delegateProxy mockOptionalInstanceMethodWithObject:@"" andObject:@""];
    }
    @catch (NSException *exception) {
        XCTFail(@"");
        return;
    }
    
    NSUInteger iteration = 1;
    NSUInteger maxIterations = 3;

    // Because of the async nature of the callbacks from the delegate proxy, we need to wait (pdcgomes 04.12.2013)
    while(callbackCounter <= expectedCallbackCounter &&
          iteration <= maxIterations) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        iteration++;
    }
    XCTAssertEqual(expectedCallbackCounter, callbackCounter, @"");
    conformantObject = nil;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)DECLARE_TEST_METHOD(validMultipleConformantObjects)
{
    NSUInteger numberOfMockObjects = 32;
    NSUInteger expectedCallbackCounter = numberOfMockObjects * 6;
    __block NSUInteger callbackCounter = 0;
    
    NSMutableArray *objects = [NSMutableArray arrayWithCapacity:numberOfMockObjects];
    
    for(int i = 0; i < numberOfMockObjects; i++) {
        PGMockProtocolConformingObject *object = [[PGMockProtocolConformingObject alloc] init];
        object.onInvocationBlock = ^{
            callbackCounter++;
        };
        [objects addObject:object];
    }
    
    @try {
        [objects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [self.delegateProxy registerDelegate:obj];
        }];
        
        [self.delegateProxy mockRequiredMethod];
        [self.delegateProxy mockRequiredMethodWithObject:@""];
        [self.delegateProxy mockRequiredMethodWithObject:@"" andObject:@""];
        
        [self.delegateProxy mockOptionalInstanceMethod];
        [self.delegateProxy mockOptionalInstanceMethodWithObject:@""];
        [self.delegateProxy mockOptionalInstanceMethodWithObject:@"" andObject:@""];
    }
    @catch (NSException *exception) {
        XCTFail(@"");
        return;
    }
    
    NSUInteger iteration = 1;
    NSUInteger maxIterations = 3;
    
    // Because of the async nature of the callbacks from the delegate proxy, we need to wait (pdcgomes 04.12.2013)
    while(callbackCounter <= expectedCallbackCounter &&
          iteration <= maxIterations) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        iteration++;
    }
    XCTAssertEqual(expectedCallbackCounter, callbackCounter, @"");
    objects = nil;
}

////////////////////////////////////////////////////////////////////////////////
// The purpose of this test is to make sure that we cleanup internal caches
// for delegates that get deallocated
////////////////////////////////////////////////////////////////////////////////
- (void)DECLARE_TEST_METHOD(validMultipleConformantObjectsWhereSomeGetDeallocated)
{
    NSUInteger numberOfMockObjects = 32;
    NSUInteger numberOfObjectsToDeallocate = 8;
    NSUInteger expectedCallbackCounter = numberOfMockObjects * 6 - (numberOfObjectsToDeallocate * 6);
    __block NSUInteger callbackCounter = 0;
    
    NSMutableArray *objects = [NSMutableArray arrayWithCapacity:numberOfMockObjects];
    
    for(int i = 0; i < numberOfMockObjects; i++) {
        PGMockProtocolConformingObject *object = [[PGMockProtocolConformingObject alloc] init];
        object.onInvocationBlock = ^{
            callbackCounter++;
        };
        [objects addObject:object];
    }
    
    @try {
        [objects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [self.delegateProxy registerDelegate:obj];
        }];
        
        [objects removeObjectsInRange:NSMakeRange(0, numberOfObjectsToDeallocate)];
        // hopefully arc will cleanup after us (pdcgomes 04.12.2013)
        
        [self.delegateProxy mockRequiredMethod];
        [self.delegateProxy mockRequiredMethodWithObject:@""];
        [self.delegateProxy mockRequiredMethodWithObject:@"" andObject:@""];
        
        [self.delegateProxy mockOptionalInstanceMethod];
        [self.delegateProxy mockOptionalInstanceMethodWithObject:@""];
        [self.delegateProxy mockOptionalInstanceMethodWithObject:@"" andObject:@""];
    }
    @catch (NSException *exception) {
        XCTFail(@"");
        return;
    }
    
    NSUInteger iteration = 1;
    NSUInteger maxIterations = 3;
    
    // Because of the async nature of the callbacks from the delegate proxy, we need to wait (pdcgomes 04.12.2013)
    while(callbackCounter <= expectedCallbackCounter &&
          iteration <= maxIterations) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        iteration++;
    }
    XCTAssertEqual(expectedCallbackCounter, callbackCounter, @"");
    objects = nil;
    
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)DECLARE_TEST_METHOD(invalidConformantObject)
{
    __strong PGMockProtocolConformantInvalidObject *invalidConformantObject = [[PGMockProtocolConformantInvalidObject alloc] init];
    
    @try {
        [self.delegateProxy registerDelegate:invalidConformantObject];
    }
    @catch (NSException *exception) {
        XCTAssertTrue([exception.name isEqualToString:kPGDelegateContainerObjectDoesNotImplementRequiredSelectorException], @"");
        return;
    }
    @finally {
        invalidConformantObject = nil;
    }
    
    XCTFail(@"Test failed");

}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)DECLARE_TEST_METHOD(nonConformantObject)
{
    __strong PGMockProtocolNonConformingObject *nonConformantObject = [[PGMockProtocolNonConformingObject alloc] init];
    
    @try {
        [self.delegateProxy registerDelegate:nonConformantObject];
    }
    @catch (NSException *exception) {
        XCTAssertTrue([exception.name isEqualToString:kPGDelegateContainerNonConformantObjectException], @"");
        return;
    }
    @finally {
        nonConformantObject = nil;
    }

    XCTFail(@"Test failed");
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)DECLARE_TEST_METHOD(partiallyConformantObject)
{
    NSUInteger expectedCallbackCounter = 3; // The PartiallyConformant object only implements the required methods (pdcgomes 04.12.2013)
    __block NSUInteger callbackCounter = 0;

    
    __strong PGMockProtocolPartiallyConformingObject *conformantObject = [[PGMockProtocolPartiallyConformingObject alloc] init];
    conformantObject.onInvocationBlock = ^{
        callbackCounter++;
    };
    
    @try {
        [self.delegateProxy registerDelegate:conformantObject];
        
        [self.delegateProxy mockRequiredMethod];
        [self.delegateProxy mockRequiredMethodWithObject:@""];
        [self.delegateProxy mockRequiredMethodWithObject:@"" andObject:@""];
        
        [self.delegateProxy mockOptionalInstanceMethod];
        [self.delegateProxy mockOptionalInstanceMethodWithObject:@""];
        [self.delegateProxy mockOptionalInstanceMethodWithObject:@"" andObject:@""];
    }
    @catch (NSException *exception) {
        XCTFail(@"");
        return;
    }
    
    NSUInteger iteration = 1;
    NSUInteger maxIterations = 3;
    
    // Because of the async nature of the callbacks from the delegate proxy, we need to wait (pdcgomes 04.12.2013)
    while(callbackCounter <= expectedCallbackCounter &&
          iteration <= maxIterations) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        iteration++;
    }
    XCTAssertEqual(expectedCallbackCounter, callbackCounter, @"");
    conformantObject = nil;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)DECLARE_TEST_METHOD(reconfiguration)
{
    NSUInteger expectedCallbackCounter = 6;
    __block NSUInteger callbackCounter = 0;
    
    __strong PGMockProtocolConformingObject *conformantObject = [[PGMockProtocolConformingObject alloc] init];
    conformantObject.onInvocationBlock = ^{
        callbackCounter++;
    };
    
    @try {
        [self.delegateProxy configureWithProtocol:@protocol(PGMockProtocol)];
        
        [self.delegateProxy registerDelegate:conformantObject];
        
        [self.delegateProxy mockRequiredMethod];
        [self.delegateProxy mockRequiredMethodWithObject:@""];
        [self.delegateProxy mockRequiredMethodWithObject:@"" andObject:@""];
        
        [self.delegateProxy mockOptionalInstanceMethod];
        [self.delegateProxy mockOptionalInstanceMethodWithObject:@""];
        [self.delegateProxy mockOptionalInstanceMethodWithObject:@"" andObject:@""];
    }
    @catch (NSException *exception) {
        XCTFail(@"Test failed. Unexpected exception (%@)", exception);
        return;
    }
    
    NSUInteger iteration = 1;
    NSUInteger maxIterations = 3;
    
    // Because of the async nature of the callbacks from the delegate proxy, we need to wait (pdcgomes 04.12.2013)
    while(callbackCounter <= expectedCallbackCounter &&
          iteration <= maxIterations) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        iteration++;
    }
    XCTAssertEqual(expectedCallbackCounter, callbackCounter, @"");
    conformantObject = nil;
    
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)DECLARE_TEST_METHOD(configurationException)
{
    __strong PGMockProtocolConformingObject *conformantObject = [[PGMockProtocolConformingObject alloc] init];
 
    @try {
        [self.delegateProxy registerDelegate:conformantObject];
        [self.delegateProxy configureWithProtocol:@protocol(PGMockProtocol)];
    }
    @catch (NSException *exception) {
        XCTAssertTrue([exception.name isEqualToString:kPGDelegateContainerConfigurationException], @"");
        return;
    }
    
    XCTFail(@"Test failed");
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)DECLARE_TEST_METHOD(methodWithReturnType)
{
    PGMockProtocolConformingObject *conformantObject = [[PGMockProtocolConformingObject alloc] init];
    PGMockProtocolPartiallyConformingObject *partiallyConformantObject = [[PGMockProtocolPartiallyConformingObject alloc] init];
    
    [self.delegateProxy registerDelegate:conformantObject];
    [self.delegateProxy registerDelegate:partiallyConformantObject];
    
    NSString *result = [self.delegateProxy mockOptionalInstanceMethodWithNonVoidReturnType];
    XCTAssertTrue(result != nil, @"Result unexpectedly nil!");
}

@end
