//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef __IMPL_FUNCTION
#define __IMPL_FUNCTION(x) __CLC_CONCAT(__clc_, x)
#endif

_CLC_OVERLOAD _CLC_DEF __RETTYPE FUNCTION(__CLC_GENTYPE base, uint offset,
                                          uint count) {
  return __IMPL_FUNCTION(FUNCTION)(base, offset, count);
}
