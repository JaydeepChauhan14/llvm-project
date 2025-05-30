! This test checks lowering of OpenACC data directive.

! RUN: bbc -fopenacc -emit-hlfir --openacc-unwrap-fir-box=true --openacc-generate-default-bounds=true %s -o - | FileCheck %s

subroutine acc_data
  real, dimension(10, 10) :: a, b, c
  real, pointer :: d, e
  logical :: ifCondition = .TRUE.

! CHECK: %[[A:.*]] = fir.alloca !fir.array<10x10xf32> {{{.*}}uniq_name = "{{.*}}Ea"}
! CHECK:%[[DECLA:.*]]:2 = hlfir.declare %[[A]]
! CHECK: %[[B:.*]] = fir.alloca !fir.array<10x10xf32> {{{.*}}uniq_name = "{{.*}}Eb"}
! CHECK:%[[DECLB:.*]]:2 = hlfir.declare %[[B]]
! CHECK: %[[C:.*]] = fir.alloca !fir.array<10x10xf32> {{{.*}}uniq_name = "{{.*}}Ec"}
! CHECK:%[[DECLC:.*]]:2 = hlfir.declare %[[C]]
! CHECK: %[[D:.*]] = fir.alloca !fir.box<!fir.ptr<f32>> {bindc_name = "d", uniq_name = "{{.*}}Ed"}
! CHECK:%[[DECLD:.*]]:2 = hlfir.declare %[[D]]
! CHECK: %[[E:.*]] = fir.alloca !fir.box<!fir.ptr<f32>> {bindc_name = "e", uniq_name = "{{.*}}Ee"}
! CHECK:%[[DECLE:.*]]:2 = hlfir.declare %[[E]]

  !$acc data if(.TRUE.) copy(a)
  !$acc end data

! CHECK:      %[[IF1:.*]] = arith.constant true
! CHECK:     %[[COPYIN:.*]] = acc.copyin varPtr(%[[DECLA]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {dataClause = #acc<data_clause acc_copy>, name = "a"}
! CHECK:      acc.data if(%[[IF1]]) dataOperands(%[[COPYIN]] : !fir.ref<!fir.array<10x10xf32>>)  {
! CHECK:        acc.terminator
! CHECK-NEXT: }{{$}}
! CHECK:acc.copyout accPtr(%[[COPYIN]] : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) to varPtr(%[[DECLA]]#0 : !fir.ref<!fir.array<10x10xf32>>) {dataClause = #acc<data_clause acc_copy>, name = "a"}

  !$acc data copy(a) if(ifCondition)
  !$acc end data

! CHECK:     %[[COPYIN:.*]] = acc.copyin varPtr(%[[DECLA]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {dataClause = #acc<data_clause acc_copy>, name = "a"}
! CHECK:      %[[IFCOND:.*]] = fir.load %{{.*}} : !fir.ref<!fir.logical<4>>
! CHECK:      %[[IF2:.*]] = fir.convert %[[IFCOND]] : (!fir.logical<4>) -> i1
! CHECK:      acc.data if(%[[IF2]]) dataOperands(%[[COPYIN]] : !fir.ref<!fir.array<10x10xf32>>) {
! CHECK:        acc.terminator
! CHECK-NEXT: }{{$}}
! CHECK:acc.copyout accPtr(%[[COPYIN]] : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) to varPtr(%[[DECLA]]#0 : !fir.ref<!fir.array<10x10xf32>>) {dataClause = #acc<data_clause acc_copy>, name = "a"}

  !$acc data copy(a, b, c)
  !$acc end data

! CHECK:     %[[COPYIN_A:.*]] = acc.copyin varPtr(%[[DECLA]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {dataClause = #acc<data_clause acc_copy>, name = "a"}
! CHECK:     %[[COPYIN_B:.*]] = acc.copyin varPtr(%[[DECLB]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {dataClause = #acc<data_clause acc_copy>, name = "b"}
! CHECK:     %[[COPYIN_C:.*]] = acc.copyin varPtr(%[[DECLC]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {dataClause = #acc<data_clause acc_copy>, name = "c"}
! CHECK:      acc.data dataOperands(%[[COPYIN_A]], %[[COPYIN_B]], %[[COPYIN_C]] : !fir.ref<!fir.array<10x10xf32>>, !fir.ref<!fir.array<10x10xf32>>, !fir.ref<!fir.array<10x10xf32>>) {
! CHECK:        acc.terminator
! CHECK-NEXT: }{{$}}
! CHECK:acc.copyout accPtr(%[[COPYIN_A]] : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) to varPtr(%[[DECLA]]#0 : !fir.ref<!fir.array<10x10xf32>>) {dataClause = #acc<data_clause acc_copy>, name = "a"}
! CHECK:acc.copyout accPtr(%[[COPYIN_B]] : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) to varPtr(%[[DECLB]]#0 : !fir.ref<!fir.array<10x10xf32>>) {dataClause = #acc<data_clause acc_copy>, name = "b"}
! CHECK:acc.copyout accPtr(%[[COPYIN_C]] : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) to varPtr(%[[DECLC]]#0 : !fir.ref<!fir.array<10x10xf32>>) {dataClause = #acc<data_clause acc_copy>, name = "c"}

  !$acc data copy(a) copy(b) copy(c)
  !$acc end data

! CHECK:     %[[COPYIN_A:.*]] = acc.copyin varPtr(%[[DECLA]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {dataClause = #acc<data_clause acc_copy>, name = "a"}
! CHECK:     %[[COPYIN_B:.*]] = acc.copyin varPtr(%[[DECLB]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {dataClause = #acc<data_clause acc_copy>, name = "b"}
! CHECK:     %[[COPYIN_C:.*]] = acc.copyin varPtr(%[[DECLC]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {dataClause = #acc<data_clause acc_copy>, name = "c"}
! CHECK:      acc.data dataOperands(%[[COPYIN_A]], %[[COPYIN_B]], %[[COPYIN_C]] : !fir.ref<!fir.array<10x10xf32>>, !fir.ref<!fir.array<10x10xf32>>, !fir.ref<!fir.array<10x10xf32>>) {
! CHECK:        acc.terminator
! CHECK-NEXT: }{{$}}
! CHECK:acc.copyout accPtr(%[[COPYIN_A]] : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) to varPtr(%[[DECLA]]#0 : !fir.ref<!fir.array<10x10xf32>>) {dataClause = #acc<data_clause acc_copy>, name = "a"}
! CHECK:acc.copyout accPtr(%[[COPYIN_B]] : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) to varPtr(%[[DECLB]]#0 : !fir.ref<!fir.array<10x10xf32>>) {dataClause = #acc<data_clause acc_copy>, name = "b"}
! CHECK:acc.copyout accPtr(%[[COPYIN_C]] : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) to varPtr(%[[DECLC]]#0 : !fir.ref<!fir.array<10x10xf32>>) {dataClause = #acc<data_clause acc_copy>, name = "c"}

  !$acc data copyin(a) copyin(readonly: b, c)
  !$acc end data

! CHECK:     %[[COPYIN_A:.*]] = acc.copyin varPtr(%[[DECLA]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {name = "a"}
! CHECK:     %[[COPYIN_B:.*]] = acc.copyin varPtr(%[[DECLB]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {dataClause = #acc<data_clause acc_copyin_readonly>, name = "b"}
! CHECK:     %[[COPYIN_C:.*]] = acc.copyin varPtr(%[[DECLC]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {dataClause = #acc<data_clause acc_copyin_readonly>, name = "c"}
! CHECK:      acc.data dataOperands(%[[COPYIN_A]], %[[COPYIN_B]], %[[COPYIN_C]] : !fir.ref<!fir.array<10x10xf32>>, !fir.ref<!fir.array<10x10xf32>>, !fir.ref<!fir.array<10x10xf32>>) {
! CHECK:        acc.terminator
! CHECK-NEXT: }{{$}}
! CHECK: acc.delete accPtr(%[[COPYIN_A]] : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) {dataClause = #acc<data_clause acc_copyin>, name = "a"}
! CHECK: acc.delete accPtr(%[[COPYIN_B]] : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) {dataClause = #acc<data_clause acc_copyin_readonly>, name = "b"}
! CHECK: acc.delete accPtr(%[[COPYIN_C]] : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) {dataClause = #acc<data_clause acc_copyin_readonly>, name = "c"}

  !$acc data copyout(a) copyout(zero: b) copyout(c)
  !$acc end data

! CHECK:     %[[CREATE_A:.*]] = acc.create varPtr(%[[DECLA]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {dataClause = #acc<data_clause acc_copyout>, name = "a"}
! CHECK:     %[[CREATE_B:.*]] = acc.create varPtr(%[[DECLB]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {dataClause = #acc<data_clause acc_copyout_zero>, name = "b"}
! CHECK:     %[[CREATE_C:.*]] = acc.create varPtr(%[[DECLC]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {dataClause = #acc<data_clause acc_copyout>, name = "c"}
! CHECK:      acc.data dataOperands(%[[CREATE_A]], %[[CREATE_B]], %[[CREATE_C]] : !fir.ref<!fir.array<10x10xf32>>, !fir.ref<!fir.array<10x10xf32>>, !fir.ref<!fir.array<10x10xf32>>) {
! CHECK:        acc.terminator
! CHECK-NEXT: }{{$}}
! CHECK:acc.copyout accPtr(%[[CREATE_A]] : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) to varPtr(%[[DECLA]]#0 : !fir.ref<!fir.array<10x10xf32>>) {name = "a"}
! CHECK:acc.copyout accPtr(%[[CREATE_B]] : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) to varPtr(%[[DECLB]]#0 : !fir.ref<!fir.array<10x10xf32>>) {dataClause = #acc<data_clause acc_copyout_zero>, name = "b"}
! CHECK:acc.copyout accPtr(%[[CREATE_C]] : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) to varPtr(%[[DECLC]]#0 : !fir.ref<!fir.array<10x10xf32>>) {name = "c"}

  !$acc data create(a, b) create(zero: c)
  !$acc end data

! CHECK:     %[[CREATE_A:.*]] = acc.create varPtr(%[[DECLA]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {name = "a"}
! CHECK:     %[[CREATE_B:.*]] = acc.create varPtr(%[[DECLB]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {name = "b"}
! CHECK:     %[[CREATE_C:.*]] = acc.create varPtr(%[[DECLC]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {dataClause = #acc<data_clause acc_create_zero>, name = "c"}
! CHECK:      acc.data dataOperands(%[[CREATE_A]], %[[CREATE_B]], %[[CREATE_C]] : !fir.ref<!fir.array<10x10xf32>>, !fir.ref<!fir.array<10x10xf32>>, !fir.ref<!fir.array<10x10xf32>>) {
! CHECK:        acc.terminator
! CHECK-NEXT: }{{$}}
! CHECK: acc.delete accPtr(%[[CREATE_A]] : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) {dataClause = #acc<data_clause acc_create>, name = "a"}
! CHECK: acc.delete accPtr(%[[CREATE_B]] : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) {dataClause = #acc<data_clause acc_create>, name = "b"}
! CHECK: acc.delete accPtr(%[[CREATE_C]] : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) {dataClause = #acc<data_clause acc_create_zero>, name = "c"}

  !$acc data create(c) copy(b) create(a)
  !$acc end data
! CHECK:%[[CREATE_C:.*]] = acc.create varPtr(%[[DECLC]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {name = "c"}
! CHECK:%[[COPY_B:.*]] = acc.copyin varPtr(%[[DECLB]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {dataClause = #acc<data_clause acc_copy>, name = "b"}
! CHECK:%[[CREATE_A:.*]] = acc.create varPtr(%[[DECLA]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {name = "a"}
! CHECK: acc.data dataOperands(%[[CREATE_C]], %[[COPY_B]], %[[CREATE_A]] : !fir.ref<!fir.array<10x10xf32>>, !fir.ref<!fir.array<10x10xf32>>, !fir.ref<!fir.array<10x10xf32>>) {

  !$acc data no_create(a, b) create(zero: c)
  !$acc end data

! CHECK:     %[[NO_CREATE_A:.*]] = acc.nocreate varPtr(%[[DECLA]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {name = "a"}
! CHECK:     %[[NO_CREATE_B:.*]] = acc.nocreate varPtr(%[[DECLB]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {name = "b"}
! CHECK:     %[[CREATE_C:.*]] = acc.create varPtr(%[[DECLC]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {dataClause = #acc<data_clause acc_create_zero>, name = "c"}
! CHECK:      acc.data dataOperands(%[[NO_CREATE_A]], %[[NO_CREATE_B]], %[[CREATE_C]] : !fir.ref<!fir.array<10x10xf32>>, !fir.ref<!fir.array<10x10xf32>>, !fir.ref<!fir.array<10x10xf32>>) {
! CHECK:        acc.terminator
! CHECK-NEXT: }{{$}}
! CHECK: acc.delete accPtr(%[[CREATE_C]] : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) {dataClause = #acc<data_clause acc_create_zero>, name = "c"}

  !$acc data present(a, b, c)
  !$acc end data

! CHECK:     %[[PRESENT_A:.*]] = acc.present varPtr(%[[DECLA]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {name = "a"}
! CHECK:     %[[PRESENT_B:.*]] = acc.present varPtr(%[[DECLB]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {name = "b"}
! CHECK:     %[[PRESENT_C:.*]] = acc.present varPtr(%[[DECLC]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {name = "c"}
! CHECK:      acc.data dataOperands(%[[PRESENT_A]], %[[PRESENT_B]], %[[PRESENT_C]] : !fir.ref<!fir.array<10x10xf32>>, !fir.ref<!fir.array<10x10xf32>>, !fir.ref<!fir.array<10x10xf32>>) {
! CHECK:        acc.terminator
! CHECK-NEXT: }{{$}}

  !$acc data deviceptr(b, c)
  !$acc end data

! CHECK:     %[[DEVICEPTR_B:.*]] = acc.deviceptr varPtr(%[[DECLB]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {name = "b"}
! CHECK:     %[[DEVICEPTR_C:.*]] = acc.deviceptr varPtr(%[[DECLC]]#0 : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) -> !fir.ref<!fir.array<10x10xf32>> {name = "c"}
! CHECK:      acc.data dataOperands(%[[DEVICEPTR_B]], %[[DEVICEPTR_C]] : !fir.ref<!fir.array<10x10xf32>>, !fir.ref<!fir.array<10x10xf32>>) {
! CHECK:        acc.terminator
! CHECK-NEXT: }{{$}}

  !$acc data attach(d, e)
  !$acc end data

! CHECK:      %[[ATTACH_D:.*]] = acc.attach varPtr(%{{.*}} : !fir.ptr<f32>) -> !fir.ptr<f32> {name = "d"}
! CHECK:      %[[ATTACH_E:.*]] = acc.attach varPtr(%{{.*}} : !fir.ptr<f32>) -> !fir.ptr<f32> {name = "e"}
! CHECK:      acc.data dataOperands(%[[ATTACH_D]], %[[ATTACH_E]] : !fir.ptr<f32>, !fir.ptr<f32>) {
! CHECK:        acc.terminator
! CHECK-NEXT: }{{$}}
! CHECK: acc.detach accPtr(%[[ATTACH_D]] : !fir.ptr<f32>) {dataClause = #acc<data_clause acc_attach>, name = "d"}
! CHECK: acc.detach accPtr(%[[ATTACH_E]] : !fir.ptr<f32>) {dataClause = #acc<data_clause acc_attach>, name = "e"}

  !$acc data present(a) async
  !$acc end data

! CHECK: acc.data async dataOperands(%{{.*}}) {
! CHECK: }

  !$acc data copy(a) async(1)
  !$acc end data

! CHECK: %[[COPYIN:.*]] = acc.copyin varPtr(%{{.*}} : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) async(%[[ASYNC:.*]] : i32) -> !fir.ref<!fir.array<10x10xf32>> {dataClause = #acc<data_clause acc_copy>, name = "a"}
! CHECK: acc.data async(%[[ASYNC]] : i32) dataOperands(%[[COPYIN]] : !fir.ref<!fir.array<10x10xf32>>) {
! CHECK: }{{$}}
! CHECK: acc.copyout accPtr(%[[COPYIN]] : !fir.ref<!fir.array<10x10xf32>>) bounds(%{{.*}}, %{{.*}}) async(%[[ASYNC]] : i32) to varPtr(%{{.*}} : !fir.ref<!fir.array<10x10xf32>>) {dataClause = #acc<data_clause acc_copy>, name = "a"}

  !$acc data present(a) wait
  !$acc end data

! CHECK: acc.data dataOperands(%{{.*}}) wait {
! CHECK: }

  !$acc data present(a) wait(1)
  !$acc end data

! CHECK: acc.data dataOperands(%{{.*}}) wait({%{{.*}} : i32}) {
! CHECK: }{{$}}

  !$acc data present(a) wait(devnum: 0: 1)
  !$acc end data

! CHECK: acc.data dataOperands(%{{.*}}) wait({devnum: %{{.*}} : i32, %{{.*}} : i32}) {
! CHECK: }{{$}}

  !$acc data default(none)
  !$acc end data

! CHECK: acc.data {
! CHECK:   acc.terminator
! CHECK: } attributes {defaultAttr = #acc<defaultvalue none>}

  !$acc data default(present)
  !$acc end data

! CHECK: acc.data {
! CHECK:   acc.terminator
! CHECK: } attributes {defaultAttr = #acc<defaultvalue present>}

  !$acc data
  !$acc end data
! CHECK-NOT: acc.data

end subroutine acc_data
