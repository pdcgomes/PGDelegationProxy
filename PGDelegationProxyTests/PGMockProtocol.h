//
//  TRMockProtocol.h
//  Chowderios
//
//  Created by Pedro Gomes on 04/12/2013.
//  Copyright (c) 2013 Phluid Labs Global Resources.  All Rights Reserved.  Proprietary and confidential information of TRGR.  Disclosure, use, or reproduction without written authorization of TRGR is prohibited. All rights reserved.
//

#import <Foundation/Foundation.h>

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
@protocol PGMockProtocol <NSObject>

@required

+ (void)mockRequiredClassMethod;

- (void)mockRequiredMethod;
- (void)mockRequiredMethodWithObject:(id)arg1;
- (void)mockRequiredMethodWithObject:(id)arg1 andObject:(id)arg2;

@optional

+ (void)mockOptionalClassMethod;

- (void)mockOptionalInstanceMethod;
- (void)mockOptionalInstanceMethodWithObject:(id)arg1;
- (void)mockOptionalInstanceMethodWithObject:(id)arg1 andObject:(id)arg2;

- (NSString *)mockOptionalInstanceMethodWithNonVoidReturnType;

@end
