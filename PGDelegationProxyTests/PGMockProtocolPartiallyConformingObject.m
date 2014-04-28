//
//  TRMockProtocolPartiallyConformantObject.m
//  Chowderios
//
//  Created by Pedro Gomes on 04/12/2013.
//  Copyright (c) 2013 Phluid Labs Global Resources.  All Rights Reserved.  Proprietary and confidential information of TRGR.  Disclosure, use, or reproduction without written authorization of TRGR is prohibited. All rights reserved.
//

#import "PGMockProtocolPartiallyConformingObject.h"

@implementation PGMockProtocolPartiallyConformingObject 

+ (void)mockRequiredClassMethod
{
//    PGLogTrace(PGLogContextDefault, @"[%@ (%p)]: %@", NSStringFromClass([self class]), self, NSStringFromSelector(_cmd));
}

- (void)mockRequiredMethod
{
//    PGLogTrace(PGLogContextDefault, @"[%@ (%p)]: %@", NSStringFromClass([self class]), self, NSStringFromSelector(_cmd));

    [self _callback];
}

- (void)mockRequiredMethodWithObject:(id)arg1
{
//    PGLogTrace(PGLogContextDefault, @"[%@ (%p)]: %@", NSStringFromClass([self class]), self, NSStringFromSelector(_cmd));

    [self _callback];
}

- (void)mockRequiredMethodWithObject:(id)arg1 andObject:(id)arg2
{
//    PGLogTrace(PGLogContextDefault, @"[%@ (%p)]: %@", NSStringFromClass([self class]), self, NSStringFromSelector(_cmd));

    [self _callback];
}

- (NSString *)mockOptionalInstanceMethodWithNonVoidReturnType
{
//    PGLogTrace(PGLogContextDefault, @"[%@ (%p)]: %@", NSStringFromClass([self class]), self, NSStringFromSelector(_cmd));
    
    return [NSString stringWithFormat:@"%@ (%p)", NSStringFromClass([self class]), self] ;
}

- (void)_callback
{
    if(self.onInvocationBlock) {
        self.onInvocationBlock();
    }
}

@end
