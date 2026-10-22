module {
  llvm.func @tm_infer(%arg0: i1, %arg1: i1) -> i1 {
    %0 = llvm.mlir.constant(true) : i1
    %1 = llvm.mlir.constant(0 : i32) : i32
    %2 = llvm.xor %arg0, %0  : i1
    %3 = llvm.xor %arg1, %0  : i1
    %4 = llvm.and %arg0, %3  : i1
    %5 = llvm.zext %4 : i1 to i32
    %6 = llvm.and %2, %arg1  : i1
    %7 = llvm.zext %6 : i1 to i32
    %8 = llvm.and %arg0, %arg1  : i1
    %9 = llvm.zext %8 : i1 to i32
    %10 = llvm.and %2, %3  : i1
    %11 = llvm.zext %10 : i1 to i32
    %12 = llvm.add %5, %7  : i32
    %13 = llvm.add %9, %11  : i32
    %14 = llvm.sub %12, %13  : i32
    %15 = llvm.icmp "sge" %14, %1 : i32
    llvm.return %15 : i1
  }
}

