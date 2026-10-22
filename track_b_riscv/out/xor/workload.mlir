// Tsetlin Machine 'xor' -- 2 inputs, 4 clauses. Dialects: func, arith.
module {
  func.func @tm_infer(%x0: i1, %x1: i1) -> i1 {
    %true = arith.constant true
    %c0_i32 = arith.constant 0 : i32
    %nx0 = arith.xori %x0, %true : i1
    %nx1 = arith.xori %x1, %true : i1
    %cl0 = arith.andi %x0, %nx1 : i1
    %cl0_w = arith.extui %cl0 : i1 to i32   // x1 & not_x2
    %cl1 = arith.andi %nx0, %x1 : i1
    %cl1_w = arith.extui %cl1 : i1 to i32   // not_x1 & x2
    %cl2 = arith.andi %x0, %x1 : i1
    %cl2_w = arith.extui %cl2 : i1 to i32   // x1 & x2
    %cl3 = arith.andi %nx0, %nx1 : i1
    %cl3_w = arith.extui %cl3 : i1 to i32   // not_x1 & not_x2
    %pos0 = arith.addi %cl0_w, %cl1_w : i32
    %neg0 = arith.addi %cl2_w, %cl3_w : i32
    %diff = arith.subi %pos0, %neg0 : i32
    %decision = arith.cmpi sge, %diff, %c0_i32 : i32
    return %decision : i1
  }
}
