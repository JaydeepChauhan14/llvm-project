; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py UTC_ARGS: --version 4
; RUN: llc < %s -mtriple=s390x-ibm-zos | FileCheck --check-prefix=CHECK %s

; The current function's frame address is the address of
; the optional back chain slot.
define ptr @fp0() nounwind {
; CHECK-LABEL: fp0:
; CHECK:         la 3,2048(4)
; CHECK-NEXT:    b 2(7)
entry:
  %0 = tail call ptr @llvm.frameaddress(i32 0)
  ret ptr %0
}

; Check that the frame address is correct in a presence
; of a stack frame.
define ptr @fp0f() nounwind {
; CHECK-LABEL: fp0f:
; CHECK:         stmg 6,7,1904(4)
; CHECK-NEXT:    aghi 4,-160
; CHECK-NEXT:    la 3,2048(4)
; CHECK-NEXT:    lg 7,2072(4)
; CHECK-NEXT:    aghi 4,160
; CHECK-NEXT:    b 2(7)
entry:
  %0 = alloca i64, align 8
  %1 = tail call ptr @llvm.frameaddress(i32 0)
  ret ptr %1
}

; Check the caller's frame address.
define ptr @fpcaller() nounwind "backchain" {
; CHECK-LABEL: fpcaller:
; CHECK:         stmg 4,7,2048(4)
; CHECK-NEXT:    lg 3,2048(4)
; CHECK-NEXT:    lmg 4,7,2048(4)
; CHECK-NEXT:    b 2(7)
entry:
  %0 = tail call ptr @llvm.frameaddress(i32 1)
  ret ptr %0
}

; Check the caller's frame address.
define ptr @fpcallercaller() nounwind "backchain" {
; CHECK-LABEL: fpcallercaller:
; CHECK:         stmg 4,7,2048(4)
; CHECK-NEXT:    lg 1,2048(4)
; CHECK-NEXT:    lg 3,0(1)
; CHECK-NEXT:    lmg 4,7,2048(4)
; CHECK-NEXT:    b 2(7)
entry:
  %0 = tail call ptr @llvm.frameaddress(i32 2)
  ret ptr %0
}

declare ptr @llvm.frameaddress(i32) nounwind readnone
