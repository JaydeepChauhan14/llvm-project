; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt < %s -passes=instcombine -S -data-layout="e-m:e-i64:64-f80:128-n8:16:32:64-S128" | FileCheck %s

@a = global [1000 x float] zeroinitializer, align 16
@b = global [1000 x float] zeroinitializer, align 16

define void @_Z3foov() {
; CHECK-LABEL: @_Z3foov(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br label [[FOR_COND:%.*]]
; CHECK:       for.cond:
; CHECK-NEXT:    [[I_0:%.*]] = phi i32 [ 0, [[ENTRY:%.*]] ], [ [[INC:%.*]], [[FOR_BODY:%.*]] ]
; CHECK-NEXT:    [[CMP:%.*]] = icmp samesign ult i32 [[I_0]], 1000
; CHECK-NEXT:    br i1 [[CMP]], label [[FOR_BODY]], label [[FOR_COND_CLEANUP:%.*]]
; CHECK:       for.cond.cleanup:
; CHECK-NEXT:    ret void
; CHECK:       for.body:
; CHECK-NEXT:    [[TMP0:%.*]] = zext nneg i32 [[I_0]] to i64
; CHECK-NEXT:    [[ARRAYIDX:%.*]] = getelementptr inbounds nuw [1000 x float], ptr @a, i64 0, i64 [[TMP0]]
; CHECK-NEXT:    [[ARRAYIDX2:%.*]] = getelementptr inbounds nuw [1000 x float], ptr @b, i64 0, i64 [[TMP0]]
; CHECK-NEXT:    [[TMP1:%.*]] = load float, ptr [[ARRAYIDX]], align 4
; CHECK-NEXT:    [[TMP2:%.*]] = load float, ptr [[ARRAYIDX2]], align 4
; CHECK-NEXT:    [[CMP_I:%.*]] = fcmp fast olt float [[TMP1]], [[TMP2]]
; CHECK-NEXT:    [[DOTV:%.*]] = select i1 [[CMP_I]], float [[TMP2]], float [[TMP1]]
; CHECK-NEXT:    store float [[DOTV]], ptr [[ARRAYIDX]], align 4
; CHECK-NEXT:    [[INC]] = add nuw nsw i32 [[I_0]], 1
; CHECK-NEXT:    br label [[FOR_COND]]
;
entry:
  br label %for.cond

for.cond:                                         ; preds = %for.body, %entry
  %i.0 = phi i32 [ 0, %entry ], [ %inc, %for.body ]
  %cmp = icmp ult i32 %i.0, 1000
  br i1 %cmp, label %for.body, label %for.cond.cleanup

for.cond.cleanup:                                 ; preds = %for.cond
  ret void

for.body:                                         ; preds = %for.cond
  %0 = zext i32 %i.0 to i64
  %arrayidx = getelementptr inbounds [1000 x float], ptr @a, i64 0, i64 %0
  %arrayidx2 = getelementptr inbounds [1000 x float], ptr @b, i64 0, i64 %0
  %1 = load float, ptr %arrayidx, align 4
  %2 = load float, ptr %arrayidx2, align 4
  %cmp.i = fcmp fast olt float %1, %2
  %__b.__a.i = select i1 %cmp.i, ptr %arrayidx2, ptr %arrayidx
  %3 = load i32, ptr %__b.__a.i, align 4
  store i32 %3, ptr %arrayidx, align 4
  %inc = add nuw nsw i32 %i.0, 1
  br label %for.cond
}

define i32 @store_bitcasted_load(i1 %cond, ptr dereferenceable(4) %addr1, ptr dereferenceable(4) %addr2) {
; CHECK-LABEL: @store_bitcasted_load(
; CHECK-NEXT:    [[SEL:%.*]] = select i1 [[COND:%.*]], ptr [[ADDR1:%.*]], ptr [[ADDR2:%.*]]
; CHECK-NEXT:    [[LD:%.*]] = load i32, ptr [[SEL]], align 4
; CHECK-NEXT:    ret i32 [[LD]]
;
  %sel = select i1 %cond, ptr %addr1, ptr %addr2
  %ld = load i32, ptr %sel
  ret i32 %ld
}

define void @bitcasted_store(i1 %cond, ptr %loadaddr1, ptr %loadaddr2, ptr %storeaddr) {
; CHECK-LABEL: @bitcasted_store(
; CHECK-NEXT:    [[SEL:%.*]] = select i1 [[COND:%.*]], ptr [[LOADADDR1:%.*]], ptr [[LOADADDR2:%.*]]
; CHECK-NEXT:    [[LD:%.*]] = load i32, ptr [[SEL]], align 4
; CHECK-NEXT:    store i32 [[LD]], ptr [[STOREADDR:%.*]], align 4
; CHECK-NEXT:    ret void
;
  %sel = select i1 %cond, ptr %loadaddr1, ptr %loadaddr2
  %ld = load i32, ptr %sel
  store i32 %ld, ptr %storeaddr
  ret void
}

define void @bitcasted_minmax_with_select_of_pointers(ptr %loadaddr1, ptr %loadaddr2, ptr %storeaddr) {
; CHECK-LABEL: @bitcasted_minmax_with_select_of_pointers(
; CHECK-NEXT:    [[LD1:%.*]] = load float, ptr [[LOADADDR1:%.*]], align 4
; CHECK-NEXT:    [[LD2:%.*]] = load float, ptr [[LOADADDR2:%.*]], align 4
; CHECK-NEXT:    [[COND:%.*]] = fcmp ogt float [[LD1]], [[LD2]]
; CHECK-NEXT:    [[LD_V:%.*]] = select i1 [[COND]], float [[LD1]], float [[LD2]]
; CHECK-NEXT:    store float [[LD_V]], ptr [[STOREADDR:%.*]], align 4
; CHECK-NEXT:    ret void
;
  %ld1 = load float, ptr %loadaddr1, align 4
  %ld2 = load float, ptr %loadaddr2, align 4
  %cond = fcmp ogt float %ld1, %ld2
  %sel = select i1 %cond, ptr %loadaddr1, ptr %loadaddr2
  %ld = load i32, ptr %sel, align 4
  store i32 %ld, ptr %storeaddr, align 4
  ret void
}
