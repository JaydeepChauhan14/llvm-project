//===-- RISCVRegisterInfo.h - RISC-V Register Information Impl --*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains the RISC-V implementation of the TargetRegisterInfo class.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_RISCV_RISCVREGISTERINFO_H
#define LLVM_LIB_TARGET_RISCV_RISCVREGISTERINFO_H

#include "llvm/CodeGen/TargetRegisterInfo.h"
#include "llvm/TargetParser/RISCVTargetParser.h"

#define GET_REGINFO_HEADER
#include "RISCVGenRegisterInfo.inc"

namespace llvm {

namespace RISCVRI {
enum : uint8_t {
  // The IsVRegClass value of this RegisterClass.
  IsVRegClassShift = 0,
  IsVRegClassShiftMask = 0b1 << IsVRegClassShift,
  // The VLMul value of this RegisterClass. This value is valid iff IsVRegClass
  // is true.
  VLMulShift = IsVRegClassShift + 1,
  VLMulShiftMask = 0b11 << VLMulShift,

  // The NF value of this RegisterClass. This value is valid iff IsVRegClass is
  // true.
  NFShift = VLMulShift + 2,
  NFShiftMask = 0b111 << NFShift,
};

/// \returns the IsVRegClass for the register class.
static inline bool isVRegClass(uint8_t TSFlags) {
  return (TSFlags & IsVRegClassShiftMask) >> IsVRegClassShift;
}

/// \returns the LMUL for the register class.
static inline RISCVVType::VLMUL getLMul(uint8_t TSFlags) {
  return static_cast<RISCVVType::VLMUL>((TSFlags & VLMulShiftMask) >>
                                        VLMulShift);
}

/// \returns the NF for the register class.
static inline unsigned getNF(uint8_t TSFlags) {
  return static_cast<unsigned>((TSFlags & NFShiftMask) >> NFShift) + 1;
}
} // namespace RISCVRI

struct RISCVRegisterInfo : public RISCVGenRegisterInfo {

  RISCVRegisterInfo(unsigned HwMode);

  const uint32_t *getCallPreservedMask(const MachineFunction &MF,
                                       CallingConv::ID) const override;

  unsigned getCSRFirstUseCost() const override {
    // The cost will be compared against BlockFrequency where entry has the
    // value of 1 << 14. A value of 5 will choose to spill or split cold
    // path instead of using a callee-saved register.
    return 5;
  }

  const MCPhysReg *getCalleeSavedRegs(const MachineFunction *MF) const override;

  const MCPhysReg *getIPRACSRegs(const MachineFunction *MF) const override;

  BitVector getReservedRegs(const MachineFunction &MF) const override;
  bool isAsmClobberable(const MachineFunction &MF,
                        MCRegister PhysReg) const override;

  const uint32_t *getNoPreservedMask() const override;

  // Update DestReg to have the value SrcReg plus an offset.  This is
  // used during frame layout, and we may need to ensure that if we
  // split the offset internally that the DestReg is always aligned,
  // assuming that source reg was.
  void adjustReg(MachineBasicBlock &MBB, MachineBasicBlock::iterator II,
                 const DebugLoc &DL, Register DestReg, Register SrcReg,
                 StackOffset Offset, MachineInstr::MIFlag Flag,
                 MaybeAlign RequiredAlign) const;

  bool eliminateFrameIndex(MachineBasicBlock::iterator MI, int SPAdj,
                           unsigned FIOperandNum,
                           RegScavenger *RS = nullptr) const override;

  bool requiresVirtualBaseRegisters(const MachineFunction &MF) const override;

  bool needsFrameBaseReg(MachineInstr *MI, int64_t Offset) const override;

  bool isFrameOffsetLegal(const MachineInstr *MI, Register BaseReg,
                          int64_t Offset) const override;

  Register materializeFrameBaseRegister(MachineBasicBlock *MBB, int FrameIdx,
                                        int64_t Offset) const override;

  void resolveFrameIndex(MachineInstr &MI, Register BaseReg,
                         int64_t Offset) const override;

  int64_t getFrameIndexInstrOffset(const MachineInstr *MI,
                                   int Idx) const override;

  void lowerVSPILL(MachineBasicBlock::iterator II) const;
  void lowerVRELOAD(MachineBasicBlock::iterator II) const;

  Register getFrameRegister(const MachineFunction &MF) const override;

  StringRef getRegAsmName(MCRegister Reg) const override;

  bool requiresRegisterScavenging(const MachineFunction &MF) const override {
    return true;
  }

  bool requiresFrameIndexScavenging(const MachineFunction &MF) const override {
    return true;
  }

  const TargetRegisterClass *
  getPointerRegClass(const MachineFunction &MF,
                     unsigned Kind = 0) const override {
    return &RISCV::GPRRegClass;
  }

  const TargetRegisterClass *
  getLargestLegalSuperClass(const TargetRegisterClass *RC,
                            const MachineFunction &) const override;

  void getOffsetOpcodes(const StackOffset &Offset,
                        SmallVectorImpl<uint64_t> &Ops) const override;

  unsigned getRegisterCostTableIndex(const MachineFunction &MF) const override;

  float getSpillWeightScaleFactor(const TargetRegisterClass *RC) const override;

  bool getRegAllocationHints(Register VirtReg, ArrayRef<MCPhysReg> Order,
                             SmallVectorImpl<MCPhysReg> &Hints,
                             const MachineFunction &MF, const VirtRegMap *VRM,
                             const LiveRegMatrix *Matrix) const override;

  static bool isVRRegClass(const TargetRegisterClass *RC) {
    return RISCVRI::isVRegClass(RC->TSFlags) &&
           RISCVRI::getNF(RC->TSFlags) == 1;
  }

  static bool isVRNRegClass(const TargetRegisterClass *RC) {
    return RISCVRI::isVRegClass(RC->TSFlags) && RISCVRI::getNF(RC->TSFlags) > 1;
  }

  static bool isRVVRegClass(const TargetRegisterClass *RC) {
    return RISCVRI::isVRegClass(RC->TSFlags);
  }
};
} // namespace llvm

#endif
