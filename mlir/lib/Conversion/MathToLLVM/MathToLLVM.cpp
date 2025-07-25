//===- MathToLLVM.cpp - Math to LLVM dialect conversion -------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "mlir/Conversion/MathToLLVM/MathToLLVM.h"

#include "mlir/Conversion/ArithCommon/AttrToLLVMConverter.h"
#include "mlir/Conversion/ConvertToLLVM/ToLLVMInterface.h"
#include "mlir/Conversion/LLVMCommon/ConversionTarget.h"
#include "mlir/Conversion/LLVMCommon/Pattern.h"
#include "mlir/Conversion/LLVMCommon/VectorPattern.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/Dialect/Math/IR/Math.h"
#include "mlir/IR/TypeUtilities.h"
#include "mlir/Pass/Pass.h"

#include "llvm/ADT/FloatingPointMode.h"

namespace mlir {
#define GEN_PASS_DEF_CONVERTMATHTOLLVMPASS
#include "mlir/Conversion/Passes.h.inc"
} // namespace mlir

using namespace mlir;

namespace {

template <typename SourceOp, typename TargetOp>
using ConvertFastMath = arith::AttrConvertFastMathToLLVM<SourceOp, TargetOp>;

template <typename SourceOp, typename TargetOp>
using ConvertFMFMathToLLVMPattern =
    VectorConvertToLLVMPattern<SourceOp, TargetOp, ConvertFastMath>;

using AbsFOpLowering = ConvertFMFMathToLLVMPattern<math::AbsFOp, LLVM::FAbsOp>;
using CeilOpLowering = ConvertFMFMathToLLVMPattern<math::CeilOp, LLVM::FCeilOp>;
using CopySignOpLowering =
    ConvertFMFMathToLLVMPattern<math::CopySignOp, LLVM::CopySignOp>;
using CosOpLowering = ConvertFMFMathToLLVMPattern<math::CosOp, LLVM::CosOp>;
using CoshOpLowering = ConvertFMFMathToLLVMPattern<math::CoshOp, LLVM::CoshOp>;
using AcosOpLowering = ConvertFMFMathToLLVMPattern<math::AcosOp, LLVM::ACosOp>;
using CtPopFOpLowering =
    VectorConvertToLLVMPattern<math::CtPopOp, LLVM::CtPopOp>;
using Exp2OpLowering = ConvertFMFMathToLLVMPattern<math::Exp2Op, LLVM::Exp2Op>;
using ExpOpLowering = ConvertFMFMathToLLVMPattern<math::ExpOp, LLVM::ExpOp>;
using FloorOpLowering =
    ConvertFMFMathToLLVMPattern<math::FloorOp, LLVM::FFloorOp>;
using FmaOpLowering = ConvertFMFMathToLLVMPattern<math::FmaOp, LLVM::FMAOp>;
using Log10OpLowering =
    ConvertFMFMathToLLVMPattern<math::Log10Op, LLVM::Log10Op>;
using Log2OpLowering = ConvertFMFMathToLLVMPattern<math::Log2Op, LLVM::Log2Op>;
using LogOpLowering = ConvertFMFMathToLLVMPattern<math::LogOp, LLVM::LogOp>;
using PowFOpLowering = ConvertFMFMathToLLVMPattern<math::PowFOp, LLVM::PowOp>;
using FPowIOpLowering =
    ConvertFMFMathToLLVMPattern<math::FPowIOp, LLVM::PowIOp>;
using RoundEvenOpLowering =
    ConvertFMFMathToLLVMPattern<math::RoundEvenOp, LLVM::RoundEvenOp>;
using RoundOpLowering =
    ConvertFMFMathToLLVMPattern<math::RoundOp, LLVM::RoundOp>;
using SinOpLowering = ConvertFMFMathToLLVMPattern<math::SinOp, LLVM::SinOp>;
using SinhOpLowering = ConvertFMFMathToLLVMPattern<math::SinhOp, LLVM::SinhOp>;
using ASinOpLowering = ConvertFMFMathToLLVMPattern<math::AsinOp, LLVM::ASinOp>;
using SqrtOpLowering = ConvertFMFMathToLLVMPattern<math::SqrtOp, LLVM::SqrtOp>;
using FTruncOpLowering =
    ConvertFMFMathToLLVMPattern<math::TruncOp, LLVM::FTruncOp>;
using TanOpLowering = ConvertFMFMathToLLVMPattern<math::TanOp, LLVM::TanOp>;
using TanhOpLowering = ConvertFMFMathToLLVMPattern<math::TanhOp, LLVM::TanhOp>;
using ATanOpLowering = ConvertFMFMathToLLVMPattern<math::AtanOp, LLVM::ATanOp>;
using ATan2OpLowering =
    ConvertFMFMathToLLVMPattern<math::Atan2Op, LLVM::ATan2Op>;
// A `CtLz/CtTz/absi(a)` is converted into `CtLz/CtTz/absi(a, false)`.
// TODO: Result and operand types match for `absi` as opposed to `ct*z`, so it
// may be better to separate the patterns.
template <typename MathOp, typename LLVMOp>
struct IntOpWithFlagLowering : public ConvertOpToLLVMPattern<MathOp> {
  using ConvertOpToLLVMPattern<MathOp>::ConvertOpToLLVMPattern;
  using Super = IntOpWithFlagLowering<MathOp, LLVMOp>;

  LogicalResult
  matchAndRewrite(MathOp op, typename MathOp::Adaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    const auto &typeConverter = *this->getTypeConverter();
    auto operandType = adaptor.getOperand().getType();
    auto llvmOperandType = typeConverter.convertType(operandType);
    if (!llvmOperandType)
      return failure();

    auto loc = op.getLoc();
    auto resultType = op.getResult().getType();
    auto llvmResultType = typeConverter.convertType(resultType);
    if (!llvmResultType)
      return failure();

    if (!isa<LLVM::LLVMArrayType>(llvmOperandType)) {
      rewriter.replaceOpWithNewOp<LLVMOp>(op, llvmResultType,
                                          adaptor.getOperand(), false);
      return success();
    }

    if (!isa<VectorType>(llvmResultType))
      return failure();

    return LLVM::detail::handleMultidimensionalVectors(
        op.getOperation(), adaptor.getOperands(), typeConverter,
        [&](Type llvm1DVectorTy, ValueRange operands) {
          return LLVMOp::create(rewriter, loc, llvm1DVectorTy, operands[0],
                                false);
        },
        rewriter);
  }
};

using CountLeadingZerosOpLowering =
    IntOpWithFlagLowering<math::CountLeadingZerosOp, LLVM::CountLeadingZerosOp>;
using CountTrailingZerosOpLowering =
    IntOpWithFlagLowering<math::CountTrailingZerosOp,
                          LLVM::CountTrailingZerosOp>;
using AbsIOpLowering = IntOpWithFlagLowering<math::AbsIOp, LLVM::AbsOp>;

// A `expm1` is converted into `exp - 1`.
struct ExpM1OpLowering : public ConvertOpToLLVMPattern<math::ExpM1Op> {
  using ConvertOpToLLVMPattern<math::ExpM1Op>::ConvertOpToLLVMPattern;

  LogicalResult
  matchAndRewrite(math::ExpM1Op op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    const auto &typeConverter = *this->getTypeConverter();
    auto operandType = adaptor.getOperand().getType();
    auto llvmOperandType = typeConverter.convertType(operandType);
    if (!llvmOperandType)
      return failure();

    auto loc = op.getLoc();
    auto resultType = op.getResult().getType();
    auto floatType = cast<FloatType>(
        typeConverter.convertType(getElementTypeOrSelf(resultType)));
    auto floatOne = rewriter.getFloatAttr(floatType, 1.0);
    ConvertFastMath<math::ExpM1Op, LLVM::ExpOp> expAttrs(op);
    ConvertFastMath<math::ExpM1Op, LLVM::FSubOp> subAttrs(op);

    if (!isa<LLVM::LLVMArrayType>(llvmOperandType)) {
      LLVM::ConstantOp one;
      if (LLVM::isCompatibleVectorType(llvmOperandType)) {
        one = LLVM::ConstantOp::create(
            rewriter, loc, llvmOperandType,
            SplatElementsAttr::get(cast<ShapedType>(llvmOperandType),
                                   floatOne));
      } else {
        one =
            LLVM::ConstantOp::create(rewriter, loc, llvmOperandType, floatOne);
      }
      auto exp = LLVM::ExpOp::create(rewriter, loc, adaptor.getOperand(),
                                     expAttrs.getAttrs());
      rewriter.replaceOpWithNewOp<LLVM::FSubOp>(
          op, llvmOperandType, ValueRange{exp, one}, subAttrs.getAttrs());
      return success();
    }

    if (!isa<VectorType>(resultType))
      return rewriter.notifyMatchFailure(op, "expected vector result type");

    return LLVM::detail::handleMultidimensionalVectors(
        op.getOperation(), adaptor.getOperands(), typeConverter,
        [&](Type llvm1DVectorTy, ValueRange operands) {
          auto numElements = LLVM::getVectorNumElements(llvm1DVectorTy);
          auto splatAttr = SplatElementsAttr::get(
              mlir::VectorType::get({numElements.getKnownMinValue()}, floatType,
                                    {numElements.isScalable()}),
              floatOne);
          auto one = LLVM::ConstantOp::create(rewriter, loc, llvm1DVectorTy,
                                              splatAttr);
          auto exp = LLVM::ExpOp::create(rewriter, loc, llvm1DVectorTy,
                                         operands[0], expAttrs.getAttrs());
          return LLVM::FSubOp::create(rewriter, loc, llvm1DVectorTy,
                                      ValueRange{exp, one},
                                      subAttrs.getAttrs());
        },
        rewriter);
  }
};

// A `log1p` is converted into `log(1 + ...)`.
struct Log1pOpLowering : public ConvertOpToLLVMPattern<math::Log1pOp> {
  using ConvertOpToLLVMPattern<math::Log1pOp>::ConvertOpToLLVMPattern;

  LogicalResult
  matchAndRewrite(math::Log1pOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    const auto &typeConverter = *this->getTypeConverter();
    auto operandType = adaptor.getOperand().getType();
    auto llvmOperandType = typeConverter.convertType(operandType);
    if (!llvmOperandType)
      return rewriter.notifyMatchFailure(op, "unsupported operand type");

    auto loc = op.getLoc();
    auto resultType = op.getResult().getType();
    auto floatType = cast<FloatType>(
        typeConverter.convertType(getElementTypeOrSelf(resultType)));
    auto floatOne = rewriter.getFloatAttr(floatType, 1.0);
    ConvertFastMath<math::Log1pOp, LLVM::FAddOp> addAttrs(op);
    ConvertFastMath<math::Log1pOp, LLVM::LogOp> logAttrs(op);

    if (!isa<LLVM::LLVMArrayType>(llvmOperandType)) {
      LLVM::ConstantOp one =
          isa<VectorType>(llvmOperandType)
              ? LLVM::ConstantOp::create(
                    rewriter, loc, llvmOperandType,
                    SplatElementsAttr::get(cast<ShapedType>(llvmOperandType),
                                           floatOne))
              : LLVM::ConstantOp::create(rewriter, loc, llvmOperandType,
                                         floatOne);

      auto add = LLVM::FAddOp::create(rewriter, loc, llvmOperandType,
                                      ValueRange{one, adaptor.getOperand()},
                                      addAttrs.getAttrs());
      rewriter.replaceOpWithNewOp<LLVM::LogOp>(
          op, llvmOperandType, ValueRange{add}, logAttrs.getAttrs());
      return success();
    }

    if (!isa<VectorType>(resultType))
      return rewriter.notifyMatchFailure(op, "expected vector result type");

    return LLVM::detail::handleMultidimensionalVectors(
        op.getOperation(), adaptor.getOperands(), typeConverter,
        [&](Type llvm1DVectorTy, ValueRange operands) {
          auto numElements = LLVM::getVectorNumElements(llvm1DVectorTy);
          auto splatAttr = SplatElementsAttr::get(
              mlir::VectorType::get({numElements.getKnownMinValue()}, floatType,
                                    {numElements.isScalable()}),
              floatOne);
          auto one = LLVM::ConstantOp::create(rewriter, loc, llvm1DVectorTy,
                                              splatAttr);
          auto add = LLVM::FAddOp::create(rewriter, loc, llvm1DVectorTy,
                                          ValueRange{one, operands[0]},
                                          addAttrs.getAttrs());
          return LLVM::LogOp::create(rewriter, loc, llvm1DVectorTy,
                                     ValueRange{add}, logAttrs.getAttrs());
        },
        rewriter);
  }
};

// A `rsqrt` is converted into `1 / sqrt`.
struct RsqrtOpLowering : public ConvertOpToLLVMPattern<math::RsqrtOp> {
  using ConvertOpToLLVMPattern<math::RsqrtOp>::ConvertOpToLLVMPattern;

  LogicalResult
  matchAndRewrite(math::RsqrtOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    const auto &typeConverter = *this->getTypeConverter();
    auto operandType = adaptor.getOperand().getType();
    auto llvmOperandType = typeConverter.convertType(operandType);
    if (!llvmOperandType)
      return failure();

    auto loc = op.getLoc();
    auto resultType = op.getResult().getType();
    auto floatType = cast<FloatType>(
        typeConverter.convertType(getElementTypeOrSelf(resultType)));
    auto floatOne = rewriter.getFloatAttr(floatType, 1.0);
    ConvertFastMath<math::RsqrtOp, LLVM::SqrtOp> sqrtAttrs(op);
    ConvertFastMath<math::RsqrtOp, LLVM::FDivOp> divAttrs(op);

    if (!isa<LLVM::LLVMArrayType>(llvmOperandType)) {
      LLVM::ConstantOp one;
      if (isa<VectorType>(llvmOperandType)) {
        one = LLVM::ConstantOp::create(
            rewriter, loc, llvmOperandType,
            SplatElementsAttr::get(cast<ShapedType>(llvmOperandType),
                                   floatOne));
      } else {
        one =
            LLVM::ConstantOp::create(rewriter, loc, llvmOperandType, floatOne);
      }
      auto sqrt = LLVM::SqrtOp::create(rewriter, loc, adaptor.getOperand(),
                                       sqrtAttrs.getAttrs());
      rewriter.replaceOpWithNewOp<LLVM::FDivOp>(
          op, llvmOperandType, ValueRange{one, sqrt}, divAttrs.getAttrs());
      return success();
    }

    if (!isa<VectorType>(resultType))
      return failure();

    return LLVM::detail::handleMultidimensionalVectors(
        op.getOperation(), adaptor.getOperands(), typeConverter,
        [&](Type llvm1DVectorTy, ValueRange operands) {
          auto numElements = LLVM::getVectorNumElements(llvm1DVectorTy);
          auto splatAttr = SplatElementsAttr::get(
              mlir::VectorType::get({numElements.getKnownMinValue()}, floatType,
                                    {numElements.isScalable()}),
              floatOne);
          auto one = LLVM::ConstantOp::create(rewriter, loc, llvm1DVectorTy,
                                              splatAttr);
          auto sqrt = LLVM::SqrtOp::create(rewriter, loc, llvm1DVectorTy,
                                           operands[0], sqrtAttrs.getAttrs());
          return LLVM::FDivOp::create(rewriter, loc, llvm1DVectorTy,
                                      ValueRange{one, sqrt},
                                      divAttrs.getAttrs());
        },
        rewriter);
  }
};

struct IsNaNOpLowering : public ConvertOpToLLVMPattern<math::IsNaNOp> {
  using ConvertOpToLLVMPattern<math::IsNaNOp>::ConvertOpToLLVMPattern;

  LogicalResult
  matchAndRewrite(math::IsNaNOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    const auto &typeConverter = *this->getTypeConverter();
    auto operandType =
        typeConverter.convertType(adaptor.getOperand().getType());
    auto resultType = typeConverter.convertType(op.getResult().getType());
    if (!operandType || !resultType)
      return failure();

    rewriter.replaceOpWithNewOp<LLVM::IsFPClass>(
        op, resultType, adaptor.getOperand(), llvm::fcNan);
    return success();
  }
};

struct IsFiniteOpLowering : public ConvertOpToLLVMPattern<math::IsFiniteOp> {
  using ConvertOpToLLVMPattern<math::IsFiniteOp>::ConvertOpToLLVMPattern;

  LogicalResult
  matchAndRewrite(math::IsFiniteOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    const auto &typeConverter = *this->getTypeConverter();
    auto operandType =
        typeConverter.convertType(adaptor.getOperand().getType());
    auto resultType = typeConverter.convertType(op.getResult().getType());
    if (!operandType || !resultType)
      return failure();

    rewriter.replaceOpWithNewOp<LLVM::IsFPClass>(
        op, resultType, adaptor.getOperand(), llvm::fcFinite);
    return success();
  }
};

struct ConvertMathToLLVMPass
    : public impl::ConvertMathToLLVMPassBase<ConvertMathToLLVMPass> {
  using Base::Base;

  void runOnOperation() override {
    RewritePatternSet patterns(&getContext());
    LLVMTypeConverter converter(&getContext());
    populateMathToLLVMConversionPatterns(converter, patterns, approximateLog1p);
    LLVMConversionTarget target(getContext());
    if (failed(applyPartialConversion(getOperation(), target,
                                      std::move(patterns))))
      signalPassFailure();
  }
};
} // namespace

void mlir::populateMathToLLVMConversionPatterns(
    const LLVMTypeConverter &converter, RewritePatternSet &patterns,
    bool approximateLog1p, PatternBenefit benefit) {
  if (approximateLog1p)
    patterns.add<Log1pOpLowering>(converter, benefit);
  // clang-format off
  patterns.add<
    IsNaNOpLowering,
    IsFiniteOpLowering,
    AbsFOpLowering,
    AbsIOpLowering,
    CeilOpLowering,
    CopySignOpLowering,
    CosOpLowering,
    CoshOpLowering,
    AcosOpLowering,
    CountLeadingZerosOpLowering,
    CountTrailingZerosOpLowering,
    CtPopFOpLowering,
    Exp2OpLowering,
    ExpM1OpLowering,
    ExpOpLowering,
    FPowIOpLowering,
    FloorOpLowering,
    FmaOpLowering,
    Log10OpLowering,
    Log2OpLowering,
    LogOpLowering,
    PowFOpLowering,
    RoundEvenOpLowering,
    RoundOpLowering,
    RsqrtOpLowering,
    SinOpLowering,
    SinhOpLowering,
    ASinOpLowering,
    SqrtOpLowering,
    FTruncOpLowering,
    TanOpLowering,
    TanhOpLowering,
    ATanOpLowering,
    ATan2OpLowering
  >(converter, benefit);
  // clang-format on
}

//===----------------------------------------------------------------------===//
// ConvertToLLVMPatternInterface implementation
//===----------------------------------------------------------------------===//

namespace {
/// Implement the interface to convert Math to LLVM.
struct MathToLLVMDialectInterface : public ConvertToLLVMPatternInterface {
  using ConvertToLLVMPatternInterface::ConvertToLLVMPatternInterface;
  void loadDependentDialects(MLIRContext *context) const final {
    context->loadDialect<LLVM::LLVMDialect>();
  }

  /// Hook for derived dialect interface to provide conversion patterns
  /// and mark dialect legal for the conversion target.
  void populateConvertToLLVMConversionPatterns(
      ConversionTarget &target, LLVMTypeConverter &typeConverter,
      RewritePatternSet &patterns) const final {
    populateMathToLLVMConversionPatterns(typeConverter, patterns);
  }
};
} // namespace

void mlir::registerConvertMathToLLVMInterface(DialectRegistry &registry) {
  registry.addExtension(+[](MLIRContext *ctx, math::MathDialect *dialect) {
    dialect->addInterfaces<MathToLLVMDialectInterface>();
  });
}
