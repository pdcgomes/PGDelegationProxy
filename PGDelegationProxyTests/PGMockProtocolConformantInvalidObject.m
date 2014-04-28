//
//  TRMockProtocolConformantInvalidObject.m
//  Chowderios
//
//  Created by Pedro Gomes on 04/12/2013.
//  Copyright (c) 2013 Phluid Labs Global Resources.  All Rights Reserved.  Proprietary and confidential information of TRGR.  Disclosure, use, or reproduction without written authorization of TRGR is prohibited. All rights reserved.
//

#import "PGMockProtocolConformantInvalidObject.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wprotocol"
@implementation PGMockProtocolConformantInvalidObject

- (void)mockRequiredMethod
{
    
}

- (void)mockRequiredMethodWithObject:(id)arg1
{
    
}

// Deliberately not implementing (pdcgomes 04.12.2013)
//- (void)mockRequiredMethodWithObject:(id)arg1 andObject:(id)arg2
//{
//    
//}

@end
#pragma clang diagnostic pop