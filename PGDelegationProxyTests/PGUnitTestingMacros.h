//
//  TRUnitTestingMacros.h
//  Chowderios
//
//  Created by Pedro Gomes on 17/12/2013.
//  Copyright (c) 2013 Phluid Labs Global Resources.  All Rights Reserved.  Proprietary and confidential information of TRGR.  Disclosure, use, or reproduction without written authorization of TRGR is prohibited. All rights reserved.
//

#import <Foundation/Foundation.h>

// You can use this to declare unit testing methods, they will be named:
// test{index}_methodName where {index} is automatically incremented whenever the macro is expanded
// this ensures that unit tests run in the order they've been specified
// WARNING: this will not work if you include the file in a precompiled header prefix (pdcgomes 17.12.2013)

#define CONCAT_INNER(a, b) test##a##_##b
#define CONCAT(a, b) CONCAT_INNER(a, b)
#define DECLARE_TEST_METHOD(_testName_) CONCAT(__COUNTER__, _testName_)
