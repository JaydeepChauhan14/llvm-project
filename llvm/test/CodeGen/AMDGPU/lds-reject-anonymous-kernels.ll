; RUN: not opt -S -mtriple=amdgcn-- -amdgpu-lower-module-lds < %s 2>&1 | FileCheck %s
; RUN: not opt -S -mtriple=amdgcn-- -passes=amdgpu-lower-module-lds < %s 2>&1 | FileCheck %s

@var1 = addrspace(3) global i32 poison, align 8

; CHECK: LLVM ERROR: anonymous kernels cannot use LDS variables
define amdgpu_kernel void @0() {
  %val0 = load i32, ptr addrspace(3) @var1
  %val1 = add i32 %val0, 4
  store i32 %val1, ptr addrspace(3) @var1
  ret void
}
