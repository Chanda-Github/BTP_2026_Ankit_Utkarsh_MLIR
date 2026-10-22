// Tsetlin Machine 'iris' -- 8 inputs, 10 clauses. Dialects: func, arith.
module {
  func.func @tm_infer(%x0: i1, %x1: i1, %x2: i1, %x3: i1, %x4: i1, %x5: i1, %x6: i1, %x7: i1) -> i1 {
    %true = arith.constant true
    %c0_i32 = arith.constant 0 : i32
    %nx0 = arith.xori %x0, %true : i1
    %nx1 = arith.xori %x1, %true : i1
    %nx2 = arith.xori %x2, %true : i1
    %nx3 = arith.xori %x3, %true : i1
    %nx4 = arith.xori %x4, %true : i1
    %nx5 = arith.xori %x5, %true : i1
    %nx6 = arith.xori %x6, %true : i1
    %nx7 = arith.xori %x7, %true : i1
    %cl0 = arith.andi %x0, %x3 : i1
    %cl0_w = arith.extui %cl0 : i1 to i32   // sl_low & sw_high
    %cl1 = arith.andi %x4, %x6 : i1
    %cl1_w = arith.extui %cl1 : i1 to i32   // pl_low & pw_low
    %cl2 = arith.andi %x1, %x5 : i1
    %cl2_w = arith.extui %cl2 : i1 to i32   // sl_high & pl_high
    %cl3 = arith.andi %x2, %x7 : i1
    %cl3_w = arith.extui %cl3 : i1 to i32   // sw_low & pw_high
    %cl4 = arith.andi %x5, %x6 : i1
    %cl4_w = arith.extui %cl4 : i1 to i32   // pl_high & pw_low
    %cl5 = arith.andi %nx0, %nx3 : i1
    %cl5_w = arith.extui %cl5 : i1 to i32   // not_sl_low & not_sw_high
    %cl6 = arith.andi %nx4, %nx6 : i1
    %cl6_w = arith.extui %cl6 : i1 to i32   // not_pl_low & not_pw_low
    %cl7 = arith.andi %nx1, %nx5 : i1
    %cl7_w = arith.extui %cl7 : i1 to i32   // not_sl_high & not_pl_high
    %cl8 = arith.andi %nx2, %nx7 : i1
    %cl8_w = arith.extui %cl8 : i1 to i32   // not_sw_low & not_pw_high
    %cl9 = arith.andi %nx5, %nx6 : i1
    %cl9_w = arith.extui %cl9 : i1 to i32   // not_pl_high & not_pw_low
    %pos0 = arith.addi %cl0_w, %cl1_w : i32
    %pos1 = arith.addi %pos0, %cl2_w : i32
    %pos2 = arith.addi %pos1, %cl3_w : i32
    %pos3 = arith.addi %pos2, %cl4_w : i32
    %neg0 = arith.addi %cl5_w, %cl6_w : i32
    %neg1 = arith.addi %neg0, %cl7_w : i32
    %neg2 = arith.addi %neg1, %cl8_w : i32
    %neg3 = arith.addi %neg2, %cl9_w : i32
    %diff = arith.subi %pos3, %neg3 : i32
    %decision = arith.cmpi sge, %diff, %c0_i32 : i32
    return %decision : i1
  }
}
