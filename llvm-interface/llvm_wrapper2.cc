#include "llvm-c/Core.h"
#include "llvm-c/TargetMachine.h"
#include "llvm/Analysis/TargetTransformInfo.h"
#include "llvm/IR/DataLayout.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/IR/Module.h"
#include "llvm/TargetParser/SubtargetFeature.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/TargetParser/Host.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Target/CodeGenCWrappers.h"
#include "llvm/Target/TargetMachine.h"
#include <cstring>
#include <optional>

using namespace llvm;

static TargetMachine *unwrap(LLVMTargetMachineRef P) {
  return reinterpret_cast<TargetMachine *>(P);
}
static Target *unwrap(LLVMTargetRef P) {
  return reinterpret_cast<Target*>(P);
}
static LLVMTargetMachineRef wrap(const TargetMachine *P) {
  return reinterpret_cast<LLVMTargetMachineRef>(const_cast<TargetMachine *>(P));
}
static LLVMTargetRef wrap(const Target * P) {
  return reinterpret_cast<LLVMTargetRef>(const_cast<Target*>(P));
}

extern "C"
LLVMTargetMachineRef LLVMCreateTargetMachineWithABI(LLVMTargetRef T,
        const char *Triple, const char *CPU, const char *Features,
        const char *ABI, LLVMCodeGenOptLevel Level, LLVMRelocMode Reloc,
        LLVMCodeModel CodeModel) {
  std::optional<Reloc::Model> RM;
  switch (Reloc){
    case LLVMRelocStatic:
      RM = Reloc::Static;
      break;
    case LLVMRelocPIC:
      RM = Reloc::PIC_;
      break;
    case LLVMRelocDynamicNoPic:
      RM = Reloc::DynamicNoPIC;
      break;
    case LLVMRelocROPI:
      RM = Reloc::ROPI;
      break;
    case LLVMRelocRWPI:
      RM = Reloc::RWPI;
      break;
    case LLVMRelocROPI_RWPI:
      RM = Reloc::ROPI_RWPI;
      break;
    default:
      break;
  }

  bool JIT;
  std::optional<CodeModel::Model> CM = unwrap(CodeModel, JIT);

  CodeGenOptLevel OL;
  switch (Level) {
    case LLVMCodeGenLevelNone:
      OL = CodeGenOptLevel::None;
      break;
    case LLVMCodeGenLevelLess:
      OL = CodeGenOptLevel::Less;
      break;
    case LLVMCodeGenLevelAggressive:
      OL = CodeGenOptLevel::Aggressive;
      break;
    default:
      OL = CodeGenOptLevel::Default;
      break;
  }

  TargetOptions opt;
  opt.MCOptions.ABIName = ABI;
  return wrap(unwrap(T)->createTargetMachine(Triple, CPU, Features, opt, RM, CM,
                                             OL, JIT));
}

