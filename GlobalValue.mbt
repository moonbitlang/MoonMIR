
pub(all) struct GlobalValue {
  label: String
  content: GlobalValueContent

  mod: Module
  llvm_gv: &@IR.GlobalValue
}

pub(all) enum GlobalValueContent {
  String(String)
  Zero(Int) // size in bytes
  Data(Array[GlobalValueData])
}

pub(all) enum GlobalValueData {
  Quad(UInt64)
  Word(UInt)
  Half(UInt16)
  Byte(Byte)
}

pub fn GlobalValue::new(mod: Module, llvm_gv: &@IR.GlobalValue) -> GlobalValue raise IRTranslateError {
  let label = llvm_gv.getName().unwrap()
  let llvm_mod = llvm_gv.getModule()
  let data_layout = llvm_mod.getDataLayout()
  match llvm_gv.asGlobalValueEnum() {
    GlobalVariable({ initializer: None, initializerTy, ..}) => {
      let size = data_layout.getTypeAllocSize(initializerTy)
      GlobalValue::{
        label,
        content: Zero(size),
        mod,
        llvm_gv,
      }
    }
    GlobalVariable({ initializer: Some(initializer), ..}) => {
      let content = match initializer.asConstantEnum() {
        ConstantInt({ vty, value, ..}) => {
          match vty.asIntegerTypeEnum() {
            Int1Type(_) => Data([Byte(value.to_byte())])
            Int8Type(_) => Data([Byte(value.to_byte())])
            Int16Type(_) => Data([Half(value.to_uint16())])
            Int32Type(_) => Data([Word(value.to_int().reinterpret_as_uint())])
            Int64Type(_) => Data([Quad(value.reinterpret_as_uint64())])
          }
        }
        ConstantFP({ vty, value, ..}) => {
          match vty.asFPTypeEnum() {
            FloatType(_) => {
              let bits = value.to_float().reinterpret_as_uint()
              Data([Word(bits)])
            }
            DoubleType(_) => {
              let bits = value.reinterpret_as_uint64()
              Data([Quad(bits)])
            }
            ty => raise IRTranslateError("Unsupported floating point type \{ty} in global constant.")
          }
        }
        ConstantPointerNull(_) => Data([Quad(0)])
        ConstantString({ data, ..}) => String(data)
        ConstantArray(_) => raise IRTranslateError("ConstantArray in global constant is not supported yet.")
        ConstantStruct(_) => raise IRTranslateError("ConstantStruct in global constant is not supported yet.")
        _ => raise IRTranslateError("Unsupported constant type in global constant.")
      }
      GlobalValue::{
        label,
        content,
        mod,
        llvm_gv,
      }
    }
    GlobalConstant({ value, ..}) => {
      let content = match value.asConstantEnum() {
        ConstantInt({ vty, value, ..}) => {
          match vty.asIntegerTypeEnum() {
            Int1Type(_) => Data([Byte(value.to_byte())])
            Int8Type(_) => Data([Byte(value.to_byte())])
            Int16Type(_) => Data([Half(value.to_uint16())])
            Int32Type(_) => Data([Word(value.to_int().reinterpret_as_uint())])
            Int64Type(_) => Data([Quad(value.reinterpret_as_uint64())])
          }
        }
        ConstantFP({ vty, value, ..}) => {
          match vty.asFPTypeEnum() {
            FloatType(_) => {
              let bits = value.to_float().reinterpret_as_uint()
              Data([Word(bits)])
            }
            DoubleType(_) => {
              let bits = value.reinterpret_as_uint64()
              Data([Quad(bits)])
            }
            ty => raise IRTranslateError("Unsupported floating point type \{ty} in global constant.")
          }
        }
        ConstantPointerNull(_) => Data([Quad(0)])
        ConstantString({ data, ..}) => String(data)
        ConstantArray(_) => raise IRTranslateError("ConstantArray in global constant is not supported yet.")
        ConstantStruct(_) => raise IRTranslateError("ConstantStruct in global constant is not supported yet.")
        _ => raise IRTranslateError("Unsupported constant type in global constant.")
      }
      GlobalValue::{
        label,
        content,
        mod,
        llvm_gv,
      }
    }
    _ => {
      raise IRTranslateError("`from_llvm_gv` cannot be applied on Function value.")
    }
  }
}

pub impl Show for GlobalValue with output(self, logger) {
  logger.write_string("global \{self.label} {")
  match self.content {
    String(s) => {
      logger.write_string("  \"\{s}\"")
    }
    Zero(size) => {
      logger.write_string("  .zero \{size}")
    }
    Data(data) => {
      for d in data {
        match d {
          Quad(q) => {
            logger.write_string("  .quad \{q}")
          }
          Word(w) => {
            logger.write_string("  .word \{w}")
          }
          Half(h) => {
            logger.write_string("  .half \{h}")
          }
          Byte(b) => {
            logger.write_string("  .byte \{b}")
          }
        }
      }
    }
  }
  logger.write_string("}\n")
}
