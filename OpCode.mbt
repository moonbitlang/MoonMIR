
pub(all) enum OpCode {
  Addb; Addw; Addl; Addq; Add(Int);
  Subb; Subw; Subl; Subq; Sub(Int);
  Mulb; Mulw; Mull; Mulq; Mul(Int);
  Divb; Divw; Divl; Divq; Div(Int);
  Remb; Remw; Reml; Remq; Rem(Int);
  FAddS; FAddD;
  FSubS; FSubD;
  FMulS; FMulD;
  FDivS; FDivD;
  FRemS; FRemD;
  FNegS; FNegD;

  Loadb; Loadw; Loadl; Loadq; Load(Int);
  FLoadS; FLoadD;

  Storeb; Storew; Storel; Storeq; Store(Int);
  FStoreS; FStoreD;

  Movb; Movw; Movl; Movq; Mov(Int);
  FMovS; FMovD;

  Beq; Bne; Bgt; Bge; Blt; Ble;
  Bequ; Bneu; Bgtu; Bgeu; Bltu; Bleu;
  Jmp;

  Eq; Ne; Gt; Ge; Lt; Le;
  Equ; Neu; Gtu; Geu; Ltu; Leu;

  FeqS; FneS; FgtS; FgeS; FltS; FleS;
  FeqD; FneD; FgtD; FgeD; FltD; FleD;

  And; Or; Xor; Shl; LShr; AShr;
  Call; Ret;
  Nop;
  Intrinsic(String);
} derive(Show)

//pub impl Show for OpCode with output(self, logger) {
//  let s = match self {
//    Intrinsic(name) => name
//  }
//  logger.write_string(s)
//}
//
